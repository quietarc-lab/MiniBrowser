# Windows self-hosted runner setup

The workflow performs the iOS build only on GitHub's `macos-26` runner. The Windows runner waits for a job, downloads one small IPA artifact, validates it, and copies it to iCloud Drive. It does not poll GitHub or build the app.

## One-time setup

1. Create or select the GitHub repository that contains this project.
2. In that repository, open **Settings → Actions → Runners → New self-hosted runner**.
3. Choose **Windows / x64** and run GitHub's generated commands. GitHub recommends `C:\actions-runner` to avoid path and service-identity issues.
4. During configuration, add the custom label `ios-ipa-delivery`. For an iCloud destination, run under the signed-in Windows user: either use a service configured with that account, or create a logon task that starts a local wrapper (for example, `C:\actions-runner\Start-IpaDeliveryRunner.ps1`) hidden. The wrapper must read the user or machine `MINIBROWSER_DELIVERY_DIRECTORY` value and export it into the runner process before starting `run.cmd`.
5. Confirm that the runner has all four labels: `self-hosted`, `Windows`, `X64`, and `ios-ipa-delivery`.
6. Keep the runner current enough for Node 24-based actions (`actions/checkout@v6` requires runner 2.329.0 or later for all supported scenarios).
7. Set the user-level `MINIBROWSER_DELIVERY_DIRECTORY` environment variable to the existing folder that should receive delivered IPAs. The value is kept only on the runner PC and is never stored in this repository or printed by the workflow.
8. Confirm that the interactive runner account can write to that directory. The delivery script intentionally does not create or guess a replacement location.

For example, set the variable in a PowerShell session with `setx MINIBROWSER_DELIVERY_DIRECTORY "D:\IPA-Delivery"`, then start or restart the runner so it inherits the new value. If a scheduled task is used, configure `StartWhenAvailable`, automatic restart on failure, and `StopOnIdleEnd` disabled; otherwise an idle desktop can silently take the runner offline. Keep the wrapper and task machine-local because they contain environment-specific paths. The runner must be online before dispatching an IPA workflow. The macOS build can still finish while it is offline, but a queued delivery may need the delivery-only workflow below.

The registration token shown by GitHub is short-lived. Do not commit it, an Apple ID, a password, a certificate, a provisioning profile, a pairing file, or a device identifier.

## Reuse for another iOS app

Create a small caller workflow like `.github/workflows/minibrowser.yml` and change only `app_name` and `destination_filename` when the scheme/project follow the app-name convention. With direct uploads, the IPA filename is also the GitHub artifact name. Optional overrides remain available for unusual project names. Keep the reusable workflow and `scripts/Deliver-Ipa.ps1` unchanged.

When an unsigned IPA artifact already exists but Windows delivery was queued while the runner was offline, run `Deliver an existing unsigned IPA` manually. Enter the successful build run ID and its IPA artifact name; this Windows-only workflow downloads, validates, and replaces the requested file without consuming another macOS build.

## Safe local delivery test

After an IPA exists locally, run:

```powershell
.\scripts\Deliver-Ipa.ps1 `
  -SourceDirectory 'C:\path\to\artifact' `
  -SourceFileName 'AppA.ipa' `
  -DestinationFileName 'AppA.ipa'
```

The script validates the IPA structure, stages a temporary copy, compares SHA-256 before and after delivery, then overwrites only the requested destination filename.

Official references:

- [Adding self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners)
- [Using self-hosted runner labels](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/use-in-a-workflow)
