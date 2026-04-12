# voxa

A new Flutter project.

## CI/CD

This repository now includes GitHub Actions workflows for Flutter CI and multi-platform packaging:

- `/.github/workflows/ci.yml`
  - runs dependency install, static analysis, and tests
- `/.github/workflows/release.yml`
  - builds Android, iOS, Windows (`x86_64`), and macOS (`arm64`) release artifacts
  - uploads build outputs as workflow artifacts
  - publishes them to GitHub Releases automatically when you push a `v*` tag

See [docs/github-actions-cicd.md](docs/github-actions-cicd.md) for the packaging details and optional iOS signing setup.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
