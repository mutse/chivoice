# chivoice

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

## iPad 导航

窗口宽度达到 700 逻辑像素时使用侧边栏；达到 1000 时展开文字标签。
窄分屏与手机使用底部导航。设置子页面保留侧边栏。

## Cloudflare Workers AI Whisper

1. 在「设置」中选择「云端 STT」，打开「AI识别配置」。
2. 在「云端 STT 配置」选择 Cloudflare。
3. 填写 Cloudflare Account ID（32 位）和具有 Workers AI 权限的 API Token。
4. API 地址默认使用 `https://api.cloudflare.com/client/v4`，无需附加账户或模型路径。
5. 选择 Whisper Large v3 Turbo（默认）或 Whisper，点击「测试 STT 连接」。

连接测试会发送 1 秒静音 WAV，消耗少量 Workers AI 配额。录音结束后会使用选定模型转写。
Turbo 通过 JSON 发送 Base64 音频和识别语言；Whisper 发送二进制音频并自动识别语言。
配置沿用应用现有本地存储方式。切换服务后请填写对应服务的密钥。

接口参考：[Whisper](https://developers.cloudflare.com/workers-ai/models/whisper/)、
[Whisper Large v3 Turbo](https://developers.cloudflare.com/workers-ai/models/whisper-large-v3-turbo/)。
