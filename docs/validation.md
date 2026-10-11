# 本轮验证记录

## 已通过

- 使用已安装的 macOS 26.5 SDK，`SWIFT_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk CONFIGURATION=debug BUNDLE_RUNTIME=0 ./script/package_app.sh` 完成 Swift 编译、app 打包和 ad-hoc 签名验证。
- `codesign --verify --deep --strict dist/SYDownload.app`。
- 实际启动本次构建，设置 → 通用最初验证了未配置公钥时禁用检查更新；后续构建已内嵌生成的公钥。
- Command-Q 后按可执行文件路径确认构建版进程已退出；用户原有 `/Applications/SYDownload.app` 进程仍在。
- 修改一个未保存的小红书选项，Command-Q 显示保存/放弃/取消提示；取消退出后应用保持运行、脏状态与修改仍保留。
- 关闭最后一个窗口后再次 Command-Q，应用级提示仍可用；放弃临时改动后确认构建版进程退出。没有保存测试改动。
- `python3 -m unittest discover -s Bridge/tests -p 'test_*.py'`：11 项通过。
- `python3 script/test_release_tools.py`：框架内部链接允许、越界/断链拒绝，临时 Ed25519 密钥签名 appcast 后由 Sparkle 实际验签成功。
- Shell 语法检查、Python 编译检查、`git diff --check`。

## 环境限制与未覆盖项

本机仅有 Command Line Tools，默认 macOS 27 SDK 缺少 `SwiftUIMacros`。切换 26.5 SDK 后应用可编译，但 `swift test` 因 XCTest 缺失无法完成。已增加退出和更新配置回归测试，完整套件应在装有 Xcode 的环境或 GitHub Actions 运行。

Sparkle 密钥已生成并配置到 GitHub Actions Secret/Variable，尚未发布包含本次改动的 appcast；本次没有做真实两个版本间的下载、安装、重启测试。没有推送、发布 Release 或创建 PR。

开发 app 未内嵌下载引擎/Python（`BUNDLE_RUNTIME=0`）；没有重新验收真实媒体下载。未保存设置的“保存成功/保存失败”分支未做运行时验收。


## EXIF 原生功能验证

- `SWIFT_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk bash script/test_exif.sh`：生成带方向、既有日期/相机与额外 UserComment 的 JPEG、半透明 PNG；验证合法闰日、非法闰日/小时/编号、十进制 08、真实秒数与兼容秒数。
- 纯 JPEG 元数据修改后，SOS 到文件结尾数据相同；额外 EXIF 注释和方向保留。PNG 元数据修改后解码像素相同；运行时也校验位深、布局和像素数据。
- 原图副本模式源文件字节不变；已有输出跳过；PNG 转 JPEG 与 JPEG 原位替换前的备份字节精确一致；预览后源文件变化被拒绝。
- 实际 GUI 选择 `/private/tmp/SYDownload-EXIF-UI` 生成图片目录：默认真实秒数、切换末尾编号后 64 项禁用并解释原因、启用转换/相机信息后预览更新；成功 2 张、失败 0 张。
- 使用开发机 ExifTool 独立读取 GUI 输出，确认 DateTimeOriginal/CreateDate/ModifyDate、Make/Model 和方向正确。SHA-256 确认原 JPG/PNG 未变。
- 最终构建复验相机品牌连续输入 Canon 完整保留焦点，预览同步更新；修复扫描刷新期间禁用输入导致只录入首字符的问题。
- GUI 重跑已有目标跳过 2 张；切换下载页再返回后文件、选项和结果保留。
- EXIF 测试脚本已加入 CI。没有改动用户真实照片。

未覆盖：大目录长时间取消、磁盘空间不足/无权限、各厂商 RAW/HDR/私有元数据和第三方 XMP 冲突。当前仅支持单帧 JPEG/PNG，默认保留原图。完整 `swift test` 仍受本机 XCTest 缺失限制。


## 界面设计修订验证

全局导航、排版、配色、下载页与 EXIF 工作区重新整理；已实际检查六个导航页面，以及深色设置/EXIF。EXIF 原生表格勾选和选中行联动、非法秒数提示、相机字段连续输入和生成图片执行均已复验，详细记录与截图见 [设计审查](design-review.md)。没有启动真实媒体下载或改动用户照片。
