# XDownloader macOS Feasibility Spike

目标：验证一个原生 SwiftUI macOS App 能否稳定复用 XHS-Downloader 与 TikTokDownloader/DouK 的 Python 下载能力。

## 已实现

- SwiftUI 原生主窗口（macOS 14+）
- 小红书 / 抖音 / TikTok 链接自动识别
- Swift ↔ Python JSON Lines IPC
- 引擎定位与健康检查
- XHS：通过现有 CLI (`main.py -u ... -wp ...`) 调用真实下载链路
- DouK：把当前内部 `ClipboardMonitor/TikTok` 单作品处理链路隔离在一个兼容适配器中
- App 数据目录预留为 `~/Library/Application Support/XDownloader`
- 缓存目录预留为 `~/Library/Caches/XDownloader`
- Swift 与 Python 自动测试
- macOS 一键 build + `.app` staging 脚本
- GitHub Actions 自动编译 Apple Silicon / Intel 两份 macOS App Artifact

## GitHub Actions 构建

工作流：`.github/workflows/build-macos-app.yml`

触发方式：

- 推送到 `main` 分支且修改 App/Bridge/构建相关文件时自动触发
- 也可以在 GitHub Actions 页面手动运行 `Build macOS App`

构建通过后会上传两份 Artifact：

- `XDownloader-macOS-AppleSilicon.zip`
- `XDownloader-macOS-Intel.zip`

当前 Artifact 使用 ad-hoc 签名，仅用于可行性和真机验证；尚未做 Developer ID 签名与 Apple notarization。

## 为什么第一版不直接内嵌 Python

Spike 先用系统 `python3` 验证调用边界，避免同时引入 Python runtime、Node、ffmpeg、codesign/notarization 多个变量。验证通过后再把 Python runtime 和必要 sidecars 装入 App Bundle。

## macOS 本机运行

```bash
./script/fetch_engines.sh
./script/setup_python.sh
./script/build_and_run.sh
```

如果只需要生成 `.app` 而不启动：

```bash
CONFIGURATION=release ./script/package_app.sh
```

如果引擎放在其他目录：

```bash
export XDOWNLOADER_XHS_ROOT=/path/to/XHS-Downloader
export XDOWNLOADER_DOUK_ROOT=/path/to/TikTokDownloader
./script/build_and_run.sh
```

## 当前 Spike 的已知边界

1. Actions 现在可以在真实 macOS runner 上验证 SwiftUI/AppKit 编译并生成 `.app`。
2. DouK 当前没有完成的单链接 CLI，因此 Spike 使用其内部类调用；正式版应把这段收敛为稳定的上游 adapter/API。
3. Python runtime、两个下载引擎、Node.js 与 ffmpeg 暂不打入 App；涉及签名计算/直播的能力留到第二阶段。
4. 暂未做 Developer ID 签名、Hardened Runtime、notarization。
5. 当前只验证单任务主链路；任务队列、历史、Cookie UI、失败重试之后实现。

## 下一阶段通过标准

- XHS 真实链接下载成功
- 抖音真实链接下载成功
- TikTok 真实链接下载成功
- App Bundle 运行期间不写自身 `Contents/`
- 无终端窗口、无需手工启动 Python server
- 再开始内嵌 Python runtime / Node / ffmpeg 与签名公证
