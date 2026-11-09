# Documentation trial-intent analytics

Status: implementation specification. This document does not install tracking code or change GA4 configuration.

## Objective

Identify which external entry points bring visitors who prepare to try Gthulhu. Separate documentation consumption, installation intent, and confirmed trials.

The site uses MkDocs Material, content.code.copy, suffix-based English/Chinese documentation, and the Google analytics provider configured in mkdocs.yml. Reuse that provider; do not initialize another GA tag.

## Event contract

| Event | Exact trigger | Parameters | Interpretation |
| --- | --- | --- | --- |
| page_view | Existing page tracking | Existing GA parameters | Documentation viewed; do not emit a second custom page-view event |
| install_command_copy | Successful clipboard copy of an explicitly annotated setup code block | step_id, setup_method, doc_language | Installation intent, not execution |
| setup_resource_click | Activation of an explicitly annotated release, deployment manifest, or setup example link | resource_id, resource_type, doc_language | Resource selected, not downloaded or installed |
| trial_feedback_open | Activation of an explicitly annotated trial-feedback link | feedback_location, doc_language | Feedback entry opened, not submitted |

All custom event names and parameters above are lower-case. Record each actual successful copy or link activation once. Repeated intentional actions may produce repeated events; reporting must deduplicate by session.

Allowed setup_method: bare_metal, kubernetes.
Allowed resource_type: release, manifest, example.
Allowed doc_language: en, zh.
Use fixed, reviewed values for step_id, resource_id and feedback_location; never derive them from user input or code text.

## Instrumentation locations

1. docs/installation.md and its Chinese counterpart: annotate only the code blocks for prerequisite verification, dependency installation, and building Gthulhu. Example step IDs: verify_kernel, install_dependencies_ubuntu, install_dependencies_opensuse, install_dependencies_cachyos, build_gthulhu. Set setup_method=bare_metal.
2. docs/k8s.md and its Chinese counterpart: annotate deployment commands and setup-resource links after inspecting their actual content. Set setup_method=kubernetes and assign stable IDs for the existing steps.
3. Annotate existing links to setup resources only where their purpose is installation. A generic repository link, navigation item, source-code reference or logo must not trigger setup_resource_click.
4. Add an English/Chinese feedback link near the end of installation and K8s deployment instructions. Direct it to the existing project Discussions destination. Ask visitors to optionally describe how they found Gthulhu, their workload and whether setup succeeded or where it failed. Opening this link only triggers trial_feedback_open.

Do not count every copied code block as installation intent. Reading API examples, troubleshooting snippets, or blog examples has different meaning. Keep attributes on selected blocks or wrappers, rather than matching command strings or translated headings.

## Frontend implementation requirements

- Add one JavaScript module under docs/javascripts/ and register it through extra_javascript in mkdocs.yml.
- Use explicit data attributes on selected code-block wrappers and resource links. Keep the same IDs in both languages.
- Integrate with the Material clipboard-success mechanism after verifying the installed theme implementation. A pointer click alone is insufficient: failed clipboard writes must not emit install_command_copy. Do not replace the theme's copy behavior or perform a second clipboard write.
- Handle navigation without duplicate listeners, including if Material instant navigation is enabled later. Support keyboard activation and dynamically rendered copy controls.
- Use the existing gtag event interface only when available and permitted by the site's analytics settings. Tracking must not break copy, navigation or rendering when analytics is blocked or absent.
- Do not reconfigure GA source attribution, add a second page_view, or add tracking parameters to internal navigation.
- Do not send copied commands, clipboard contents, form contents, email addresses, hostnames, cluster identifiers, arbitrary query strings, or full outbound URLs as custom parameters. Use the fixed IDs above.
- Exclude local development and preview hosts from custom event transmission; explicitly allow the production hostname gthulhu.org and verify whether any alternate hostname actually serves production before allowing it.

Illustrative payload after a verified successful copy:

```javascript
gtag("event", "install_command_copy", {
  step_id: "build_gthulhu",
  setup_method: "bare_metal",
  doc_language: "en"
});
```

## External entry-point attribution

Apply UTM parameters to external links controlled by maintainers. Link to the relevant case study or setup page.

| Placement | utm_source | utm_medium | utm_campaign | utm_content |
| --- | --- | --- | --- | --- |
| GitHub README | github | referral | free5gc_case | readme |
| free5GC integration article | free5gc | referral | free5gc_case | integration_article |
| LinkedIn benchmark post | linkedin | social | free5gc_case | benchmark_post |

Use consistent lower-case values. Do not modify search-engine links or add UTMs to links between pages on this site. Test that redirects preserve the external entry parameters.

Use Session source / medium, Session campaign and Session manual ad content to compare visits. First-user acquisition and event-level attribution answer different questions; do not mix them into the same session conversion calculation.

## GA4 setup and reporting

These are manual GA4 administration tasks, not changes made by a documentation merge:

1. Validate custom events and parameters in DebugView.
2. Register event-scoped custom dimensions for step_id, setup_method, resource_id, resource_type, feedback_location and doc_language.
3. Mark install_command_copy as a key event. Keep setup-resource selection and feedback-link opening separate from that primary intent metric.
4. Select install_command_copy specifically when viewing the session key-event rate; do not use an aggregate of unrelated key events.
5. Compare source/medium, campaign and entry placement using sessions, sessions containing install_command_copy, and their ratio. Use an exploration with session segments if the standard report does not expose the required combination.

Primary metric:

Installation-intent rate = sessions with at least one install_command_copy / all sessions for that entry point.

Report counts beside rates. Five copies in one session count as one intent session. A source with one successful session out of one is not established as superior to a larger source.

Optionally inspect an ordered journey from installation page view to command copy to setup-resource selection, but do not require this sequence for the primary metric: visitors can start directly on a setup page or obtain resources before copying commands.

The initial report measures same-session intent. A visitor who returns later, switches devices, or installs directly from GitHub may not be attributable to the original visit. Do not silently present this as complete acquisition attribution.

## Confirmed trials

Website events cannot prove a command ran or a scheduler started. Count voluntarily submitted reports with concrete installation/test results separately, record self-reported discovery source when supplied, and deduplicate repeated reports manually. A feedback-link click is not a submission.

This scope adds no runtime or installer telemetry. Runtime trial confirmation would require a separate design.

## Acceptance checks

- English and Chinese builds succeed; annotations survive code highlighting and localization.
- Successful copy on each selected setup method emits exactly one event with the expected fixed parameters.
- Failed copy, unannotated code copy, generic GitHub links, and ordinary internal navigation emit no custom trial-intent event.
- Resource and feedback links emit exactly one matching event for pointer and keyboard activation while preserving navigation.
- Revisiting pages does not multiply handlers or events.
- Analytics absent/blocked: no uncaught errors; copy and navigation still work.
- No duplicate GA initialization or custom page_view.
- Production allowlist prevents custom event transmission from previews and localhost.
- DebugView payloads contain only the allowed metadata.
- External UTM test visits retain source/medium, campaign and content; subsequent internal navigation introduces no new campaign parameters.
- Reports count sessions with intent rather than raw copy-event counts.
- Confirmed trials remain visibly separate from website intent.

## References

- [GA4 custom events](https://developers.google.com/analytics/devguides/collection/ga4/events)
- [GA4 event parameters and custom dimensions](https://developers.google.com/analytics/devguides/collection/ga4/event-parameters)
- [Traffic acquisition report](https://support.google.com/analytics/answer/12923437)
- [Manual campaign report](https://support.google.com/analytics/answer/14264492)
