# GitHub CI/CD

## Included workflows

- `.github/workflows/ci.yml`
  - Runs on `push` to `main`/`master` and on every pull request
  - Executes `flutter pub get`, `flutter analyze`, and `flutter test`
- `.github/workflows/release.yml`
  - Supports manual runs with `workflow_dispatch`
  - Builds release artifacts automatically when a tag matching `v*` is pushed
  - Publishes build outputs to GitHub Actions artifacts
  - Attaches artifacts to GitHub Releases for tag builds

## Output artifacts

- Android
  - `app-release.apk`
  - `app-release.aab`
- Windows
  - `windows-x86_64-*.zip`
- macOS
  - `macos-arm64-*.zip`
- iOS
  - Defaults to an unsigned `Runner.app` zip when signing secrets are not configured
  - Exports a signed `.ipa` when signing secrets are configured

## Optional iOS signing secrets

If you want GitHub Actions to export a signed IPA, configure these repository secrets:

- `IOS_CERT_BASE64`
  - Base64 encoded `.p12` signing certificate
- `IOS_CERT_PASSWORD`
  - Password for the `.p12` certificate
- `IOS_PROFILE_BASE64`
  - Base64 encoded provisioning profile
- `IOS_TEAM_ID`
  - Apple Developer Team ID

You can also configure this repository variable:

- `IOS_EXPORT_METHOD`
  - Export method passed to Xcode export options
  - Typical values: `development`, `ad-hoc`, `app-store`, `enterprise`

## Suggested release flow

1. Push code to GitHub.
2. Open the `Actions` tab and run `Build Release Artifacts`, or push a tag like `v1.0.0`.
3. Download the packaged artifacts from the workflow run, or use the generated GitHub Release on tag builds.
