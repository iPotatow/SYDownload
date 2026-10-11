# Sparkle 更新发布

应用使用 Sparkle 2 的标准界面，接管版本检查、签名校验、下载、安装和重启。旧的 GitHub API + shell 替换安装器已移除，旧代理源设置不再使用。

默认 appcast 地址：
`https://github.com/iPotatow/SYDownload/releases/latest/download/appcast.xml`

## 首次配置（一次）

本项目的密钥已生成，私钥保存在本机登录钥匙串，Sparkle account 为 `com.sydownload.app`。公钥保存在仓库根目录 `sparkle-public-key.txt`，本机与 CI 打包默认读取这个文件，无须再配置公钥 Variable。

本仓库 Actions Secret `SPARKLE_PRIVATE_ED_KEY` 与 Variable `SPARKLE_PUBLIC_ED_KEY` 已配置，私钥未进入仓库。后续发布可直接使用签名流程。首次包含 Sparkle 的版本仍须手动安装。

如需迁移签名环境，可用 `generate_keys --account com.sydownload.app -x /安全的临时路径/key` 导出私钥，导入安全的 Secret 后移除导出文件；不要输出到日志。查看公钥使用同一工具的 `--account com.sydownload.app -p`，无需重新生成。

发布工作流在 ZIP 完成后用 `sign_update` 签名并生成 appcast，随 GitHub Release 上传。CI 私钥通过标准输入传入签名工具，不落盘；缺少私钥会阻止发布。公钥可选通过 `SPARKLE_PUBLIC_ED_KEY` 环境变量或 Actions Variable 覆盖，须确保与签名私钥匹配。本机使用钥匙串签名时向 `sign_update` 传入 `--account com.sydownload.app`。

可以用 `SPARKLE_FEED_URL` 覆盖打包时的 HTTPS feed 地址。本机开发可使用测试 HTTPS feed；更新仍必须由匹配的密钥签名。

## 验证

- `swift test` 检查配置与退出回归。
- `BUNDLE_RUNTIME=0 CONFIGURATION=debug ./script/package_app.sh` 验证框架嵌入、内部链接和 ad-hoc 签名。
- 首次发布包含公钥的版本必须手动安装。此前自制更新器发布的版本没有 Sparkle，不能凭空切换到新的更新协议。
- 真实端到端验收需要两个不同版本、有效签名和已发布 appcast：旧版检查 → 下载 → 安装重启 → 再次检查为最新；另测篡改 ZIP、取消退出及只读安装位置。
- 当前项目仍使用 ad-hoc 签名；Developer ID 和 notarization 是独立的发布配置工作。

框架的版本目录符号链接须保留；只拒绝断链或指向 app 之外的链接，不能沿用“禁止一切符号链接”的旧打包检查。

参考：[Sparkle 官方接入文档](https://sparkle-project.org/documentation/)、[程序化 SwiftUI 接入](https://sparkle-project.org/documentation/programmatic-setup/)。
