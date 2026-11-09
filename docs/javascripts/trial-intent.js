/* Only explicitly marked setup commands and links represent trial intent. */
(() => {
  "use strict";
  if (window.__gthulhuTrialIntent) return;
  window.__gthulhuTrialIntent = true;

  const language = () => document.documentElement.lang.startsWith("zh") ? "zh" : "en";
  function emit(name, parameters) {
    if (location.hostname !== "gthulhu.org" || typeof window.gtag !== "function") return;
    try {
      window.gtag("event", name, { ...parameters, doc_language: language() });
    } catch (_) { /* Analytics must never interrupt the documentation. */ }
  }

  // Own copying only for annotated setup blocks. This avoids counting a click
  // before clipboard success or competing with Material's delegated handler.
  document.addEventListener("click", async (event) => {
    if (!(event.target instanceof Element)) return;
    const button = event.target.closest("button[data-clipboard-target]");
    const block = button?.closest("[data-trial-step][data-setup-method]");
    if (!block) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    if (button.disabled) return;
    const code = block.querySelector("code");
    if (!code) return;
    const title = button.title;
    const label = button.getAttribute("aria-label");
    button.disabled = true;
    let copied = false;
    try {
      // Material marks prompts and other non-copyable code with these classes.
      const content = code.cloneNode(true);
      content.querySelectorAll(".gp, .go, .linenos").forEach(node => node.remove());
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(content.textContent);
        copied = true;
      } else {
        const input = document.createElement("textarea");
        input.value = content.textContent;
        input.style.cssText = "position:fixed;left:-9999px";
        document.body.appendChild(input);
        try {
          input.select();
          copied = document.execCommand("copy");
        } finally {
          input.remove();
          button.focus();
        }
      }
    } catch (_) { /* Permission denied: show failure and emit no intent. */ }
    button.disabled = false;
    const message = language() === "zh"
      ? (copied ? "已複製" : "複製失敗，請手動複製")
      : (copied ? "Copied" : "Copy failed; please copy manually");
    button.title = message;
    button.setAttribute("aria-label", message);
    let status = document.getElementById("trial-copy-status");
    if (!status) {
      status = document.createElement("span");
      status.id = "trial-copy-status";
      status.className = "md-visually-hidden";
      status.setAttribute("role", "status");
      document.body.appendChild(status);
    }
    status.textContent = message;
    if (copied) emit("install_command_copy", {
      step_id: block.dataset.trialStep,
      setup_method: block.dataset.setupMethod
    });
    window.setTimeout(() => {
      button.title = title;
      if (label === null) button.removeAttribute("aria-label");
      else button.setAttribute("aria-label", label);
    }, 2000);
  }, true);

  function trackLink(event) {
    if (event.type === "auxclick" && event.button !== 1) return;
    if (!(event.target instanceof Element)) return;
    const link = event.target.closest("a[data-trial-resource], a[data-trial-feedback]");
    if (!link) return;
    if (link.dataset.trialResource) emit("setup_resource_click", {
      resource_id: link.dataset.trialResource,
      resource_type: link.dataset.resourceType
    });
    else emit("trial_feedback_open", { feedback_location: link.dataset.trialFeedback });
  }
  // Delegation also covers translated pages, keyboard clicks and instant navigation.
  document.addEventListener("click", trackLink);
  document.addEventListener("auxclick", trackLink);
})();
