// Run with: node --test tests/trial-intent.test.cjs
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const source = readFileSync(require('node:path').join(__dirname, '../docs/javascripts/trial-intent.js'), 'utf8');

function fixture({ hostname = 'gthulhu.org', language = 'en', fail = false, fallback = false } = {}) {
  class Element {
    constructor() { this.dataset = {}; this.title = 'Copy'; this.attrs = {}; this.style = {}; }
    closest(selector) {
      if (selector.startsWith('button')) return this === button ? button : null;
      if (selector.startsWith('[data-trial-step]')) return this === button ? block : null;
      return this === link ? link : null;
    }
    setAttribute(key, value) { this.attrs[key] = value; }
    getAttribute(key) { return this.attrs[key] ?? null; }
    removeAttribute(key) { delete this.attrs[key]; }
    focus() {}
    select() {}
    remove() {}
  }
  const button = new Element(), block = new Element(), link = new Element();
  block.dataset = { trialStep: 'build_gthulhu', setupMethod: 'bare_metal' };
  const content = { textContent: 'make', querySelectorAll: () => [] };
  block.querySelector = () => ({ cloneNode: () => content });
  const listeners = {}, events = [], writes = [];
  let status;
  const document = {
    documentElement: { lang: language },
    addEventListener(type, listener) { (listeners[type] ??= []).push(listener); },
    getElementById: () => status,
    createElement: () => new Element(),
    body: { appendChild(node) { if (node.id) status = node; } },
    execCommand() { writes.push('fallback'); return !fail; }
  };
  const window = { gtag: (...args) => events.push(args), setTimeout: () => {} };
  const context = vm.createContext({ window, document, Element,
    location: { hostname }, navigator: { clipboard: fallback ? undefined : {
      async writeText(text) { writes.push(text); if (fail) throw Error('denied'); }
    } }
  });
  vm.runInContext(source, context);
  async function dispatch(target, type = 'click', buttonNumber = 0) {
    let stopped = false;
    const event = { target, type, button: buttonNumber,
      preventDefault() {}, stopImmediatePropagation() { stopped = true; } };
    for (const listener of listeners[type] ?? []) {
      await listener(event);
      if (stopped) break;
    }
  }
  return { button, link, events, writes, window, context, dispatch, Element };
}

test('successful setup copy emits once, including after repeated script loading', async () => {
  const f = fixture();
  vm.runInContext(source, f.context);
  await f.dispatch(f.button);
  assert.equal(f.writes.length, 1);
  assert.equal(f.events.length, 1);
  assert.equal(f.events[0][1], 'install_command_copy');
  assert.equal(f.events[0][2].step_id, 'build_gthulhu');
  assert.deepEqual(Object.keys(f.events[0][2]).sort(), ['doc_language', 'setup_method', 'step_id']);
});
test('denied clipboard writes do not emit intent and allow retry', async () => {
  const f = fixture({ fail: true });
  await f.dispatch(f.button);
  assert.equal(f.events.length, 0);
  assert.equal(f.button.disabled, false);
  assert.match(f.button.title, /failed/);
});
test('legacy copy only emits after execCommand reports success', async () => {
  for (const fail of [false, true]) {
    const f = fixture({ fallback: true, fail });
    await f.dispatch(f.button);
    assert.equal(f.events.length, fail ? 0 : 1);
  }
});
test('unmarked code, generic links and non-elements emit nothing', async () => {
  const f = fixture();
  await f.dispatch(new f.Element());
  await f.dispatch({});
  assert.equal(f.events.length, 0);
  assert.equal(f.writes.length, 0);
});
test('resource keyboard click and middle click are counted, right click is not', async () => {
  const f = fixture({ language: 'zh-TW' });
  f.link.dataset = { trialResource: 'scheduler_releases', resourceType: 'release' };
  await f.dispatch(f.link); // Keyboard activation also dispatches click.
  await f.dispatch(f.link, 'auxclick', 1);
  await f.dispatch(f.link, 'auxclick', 2);
  assert.equal(f.events.length, 2);
  assert.equal(f.events[0][1], 'setup_resource_click');
  assert.equal(f.events[0][2].doc_language, 'zh');
});
test('feedback opening has its own event, not trial confirmation', async () => {
  const f = fixture();
  f.link.dataset = { trialFeedback: 'installation' };
  await f.dispatch(f.link);
  assert.equal(f.events[0][1], 'trial_feedback_open');
});
test('preview, missing or throwing analytics never prevents copying', async () => {
  for (const mode of ['preview', 'missing', 'throwing']) {
    const f = fixture({ hostname: mode === 'preview' ? 'localhost' : 'gthulhu.org' });
    if (mode === 'missing') delete f.window.gtag;
    if (mode === 'throwing') f.window.gtag = () => { throw Error('blocked'); };
    await f.dispatch(f.button);
    assert.equal(f.writes.length, 1);
    assert.equal(f.events.length, 0);
  }
});
