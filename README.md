# SYDownload macOS

原生 SwiftUI macOS 下载器，复用 XHS-Downloader 与 TikTokDownloader/DouK 的 Python 下载能力。

## 当前能力

- SwiftUI 原生界面（macOS 14+）
- 自动识别小红书 / 抖音 / TikTok 链接
- Swift ↔ Python JSON Lines IPC
- XHS 真实 CLI 下载链路
- DouK 单作品兼容适配器
- GitHub Actions 同时构建 Apple Silicon / Intel `.app`
- Release Artifact 内置 Python 3.12
- Release Artifact 内置 XHS-Downloader 与 TikTokDownloader/DouK 源码
- Release Artifact 内置两个引擎的 Python 依赖
- App 首次调用引擎时，把只读模板复制到 `~/Library/Application Support/SYDownload/engines/` 后运行，避免修改签名后的 `.app`

## 自包含 Artifact

`.github/workflows/build-macos-app.yml` 在 `main` 分支构建：

- `SYDownload-macOS-AppleSilicon.zip`
- `SYDownload-macOS-Intel.zip`

App Bundle 主要结构：

```text
SYDownload.app/Contents/
├── MacOS/SYDownload
└── Resources/
    ├── bridge/engine_bridge.py
    ├── python/                 # portable CPython 3.12 + site-packages
    ├── engines/
    │   ├── XHS-Downloader/
    │   └── TikTokDownloader/
    └── engine-manifest.json
```

当前固定上游版本：

- XHS-Downloader: `cc7c78088afc09082f54ea6263a9fd07c2fa510f`
- TikTokDownloader: `43e1abc4ab401b31560423450d01648e83c9b48a`

这样 Actions 每次构建使用相同引擎版本，不会因上游 master 突然变化而产生不可重复的 Artifact。

## 本机开发

快速开发模式仍可使用外部引擎和系统 Python：

```bash
./script/fetch_engines.sh
./script/setup_python.sh
./script/build_and_run.sh
```

要在 Mac 本机验证与 Actions 相同的完整自包含 Bundle，需要安装 `uv`，然后：

```bash
BUNDLE_RUNTIME=1 CONFIGURATION=release ./script/package_app.sh
```

## 数据目录

- 引擎运行副本与持久数据：`~/Library/Application Support/SYDownload/`
- 缓存：`~/Library/Caches/SYDownload/`
- 媒体文件：用户选择的下载目录（默认 `~/Downloads/SYDownload/`）
- `.app/Contents/` 运行期间保持只读

## 当前边界

1. Node.js 尚未内嵌；DouK 中依赖 Node/JSPyBridge 的签名能力仍需下一阶段验证。
2. ffmpeg 尚未内嵌；直播下载等依赖 ffmpeg 的能力暂不作为本阶段通过标准。
3. Artifact 目前使用 ad-hoc 签名，仅用于开发和真机验证；尚未做 Developer ID、Hardened Runtime 与 notarization。
4. DouK 仍通过内部类完成单链接处理；正式版应继续收敛成稳定 adapter。
5. 当前 UI 还是单任务 Spike，后续再加入解析预览、任务队列、进度、历史与 Cookie 管理。
