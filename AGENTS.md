# MiniBrowser project rules

## Canonical source

- The canonical repository is `https://github.com/quietarc-lab/ios-web-shell`.
- Keep application source, XcodeGen configuration, workflows, scripts, tests, documentation, and issue tracking in this repository.
- Treat `main` as the integration branch. Do not create an independent authoritative copy elsewhere.
- `MiniBrowser_Codex_Spec.md` is the baseline product specification. A later explicit user requirement may extend or override it; record lasting changes in repository documentation.

## Product constraints

- Support iPhone on iOS 26 or later only.
- Use SwiftUI with `WKWebView`; generate the Xcode project with XcodeGen.
- Development and static checks run on Windows 11. Do not require a local Mac.
- Build unsigned IPA files on a GitHub-hosted macOS runner. SideStore performs device signing and installation.
- Prioritize stability, then low resource use, few operations, debuggability, and simple UI.
- Implement the requested MVP directly. Do not add settings screens, tabs, search engines, or unrelated features.
- Do not change specified user operations or persistence behavior without an explicit requirement.

## Security and data handling

- Never log or commit Cookie values, passwords, authentication tokens, form contents, Apple credentials, certificates, provisioning profiles, pairing files, or device secrets.
- Cookie refresh may delete only cookies related to the current host and its parent domain. It must not clear LocalStorage or unrelated WebKit data.
- Changing User-Agent must retain cookies, LocalStorage, and navigation history.
- Returning from `セルラー再接続` must not reload the current page.
- Bookmarklet source must not be silently shortened or rewritten.

## Implementation and verification

- Preserve existing working behavior and unrelated user changes.
- Keep the Windows delivery workflow reusable across iOS applications; app name, artifact name, and destination filename must remain inputs.
- MiniBrowser delivery must replace only `%MINIBROWSER_DELIVERY_DIRECTORY%\MiniBrowser.ipa`.
- Before push, run `.\scripts\Static-Check.ps1`, `git diff --check`, and JavaScript syntax checks when injected scripts change.
- GitHub Actions must run XCTest on an iPhone Simulator, build with code signing disabled, validate the IPA ZIP structure, and deliver it through the Windows self-hosted runner.
- After delivery, verify `Payload/MiniBrowser.app`, minimum OS 26.0, absence of signature/provisioning entries, and SHA-256.
- Device-only behavior remains unconfirmed until tested on the reporting iPhone; do not close such work solely because Simulator tests pass.

## Resource usage policy

- Keep the canonical GitHub repository private. Do not propose making it public merely to reduce Actions charges unless the user explicitly reopens that privacy decision.
- Run the GitHub-hosted macOS IPA workflow only by manual dispatch after a coherent change set passes Windows checks. Do not trigger a macOS build for every intermediate push.
- Prefer one macOS build per device-test batch. Diagnose and fix Windows-detectable failures before dispatching another hosted run.
- The default Codex model is GPT-5.6 Luna with MAX reasoning for routine inspection, documentation, small known-pattern edits, and local verification.
- Escalate to GPT-5.6 Terra with High reasoning for ordinary multi-file SwiftUI work, networking/parsing/persistence changes, new tests, or CI failures.
- Escalate to GPT-5.6 Sol with High reasoning for crash logs, Swift concurrency or lifetime faults, ambiguous root causes, architecture, security/privacy work, and final review of high-risk changes.
- Escalate early when the same blocker survives two attempts, compiler/API behavior is uncertain, a crash or asynchronous path is involved, three or more subsystems are coupled, or data/security risk exists. Quota conservation must not override these safety triggers.
- Return later routine work to Luna/MAX after the high-risk portion is resolved. If the current task cannot change models in place, state that limitation before continuing risk-sensitive work and use an explicit model override or a separate task when available.

## Issues and change handoff

- Use GitHub Issues as the handoff point for development tasks, bugs, and device verification.
- A bug issue should contain reproduction steps, environment, evidence or logs, expected behavior, and completion criteria.
- A development issue should state the requested outcome, scope boundaries, and acceptance checks.
- Reference the relevant issue from commits when practical. Close an issue only after its acceptance criteria are satisfied.
- Keep `README.md` and `docs/IMPLEMENTATION_STATUS.md` aligned with meaningful implemented and delivered changes.
