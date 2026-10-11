# UI/UX 全文阅读覆盖记录

审查日期：2026-10-10 至 2026-10-11。对象为当前工作区，包括未提交文件。

共 65 个仓库文本文件、10,921 行；包含全部 32 个 Swift 源文件、7,245 行。所有输入文件均从第 1 行读到末尾，截断部分重新读取，结束时核对 SHA-256。此处记录阅读覆盖，不代表所有运行分支均已执行；验证边界见 [审查报告](ui-ux-audit.md)。

| 文件 | 全文覆盖行号 | SHA-256 |
| --- | --- | --- |
| [.codex/environments/environment.toml](../.codex/environments/environment.toml) | 1-10 | `01ca32d5bd29cdc842fdcdabc19d24813213ff3f9a83d05a7ffa35c76d3598b7` |
| [.github/release-assets/Install.command](../.github/release-assets/Install.command) | 1-24 | `dcaee6f81b33ce16bf6693f43f0f0b06398d05c41977c4a41160c761d0af89f5` |
| [.github/workflows/build-macos-app.yml](../.github/workflows/build-macos-app.yml) | 1-384 | `5414cefcc54a05aa445d05ffc347f3be3f1ff7b66716646fa15085ebe02c5a8a` |
| [.gitignore](../.gitignore) | 1-7 | `cf2b4dd4130f9d088e8303689b64ef28a86c0b37c6c7e09ca1113c4f2d1295fc` |
| [Bridge/download_runtime.py](../Bridge/download_runtime.py) | 1-356 | `8aa847233c52dba9de6106cd2f8609d6b3d29b45dd2ef08d25a79e71838dc019` |
| [Bridge/engine_bridge.py](../Bridge/engine_bridge.py) | 1-912 | `5100fd508aaa4da0d40b72e1cdf468772ddb42080f9583f3df059c8cd059aef8` |
| [Bridge/tests/test_bridge.py](../Bridge/tests/test_bridge.py) | 1-134 | `2254915e568c52ce7d4f78bfb34cb3367d74eb94217c7421f315170944680366` |
| [Bridge/tests/test_browser_cookie.py](../Bridge/tests/test_browser_cookie.py) | 1-75 | `0191e0fe6ea32f427280da7aad006ec5f34dd8d840492b56075fec170ef76efc` |
| [Package.resolved](../Package.resolved) | 1-15 | `bafbeb51ec7363950a15e3d6dc81233e647fe35bb22b32a7ee929c80bd13100e` |
| [Package.swift](../Package.swift) | 1-31 | `7214c5351597f385fa4071bd0129f2127dea1ecd994451dd4df6403625a13b10` |
| [README.md](../README.md) | 1-88 | `487c3ca95180fcff08ddc77c5a07334ee1f6509ca2c3eb989ca6c7661d6d02a4` |
| [Sources/SYDownloadApp/AppMain.swift](../Sources/SYDownloadApp/AppMain.swift) | 1-108 | `80915c16719e47013921fce3b03e3194fff0f1e63df2e7d393586f626bbb93ba` |
| [Sources/SYDownloadApp/CoreUI/CoreControls.swift](../Sources/SYDownloadApp/CoreUI/CoreControls.swift) | 1-267 | `7c08148ad128c29017ea508769596f54f30e5109a8691594565d36c71d6fecd3` |
| [Sources/SYDownloadApp/CoreUI/CoreFoundation.swift](../Sources/SYDownloadApp/CoreUI/CoreFoundation.swift) | 1-173 | `e59c1864c704c056c54b6e0201b334be305ecc07db108c56f78d65bcc119b41e` |
| [Sources/SYDownloadApp/CoreUI/CorePatterns.swift](../Sources/SYDownloadApp/CoreUI/CorePatterns.swift) | 1-197 | `e2fef2491a5a8f9a9cd4fb257a54594fb8cfa59e1aa61abfb4a92fc24523d413` |
| [Sources/SYDownloadApp/CoreUI/RemixIcon.swift](../Sources/SYDownloadApp/CoreUI/RemixIcon.swift) | 1-52 | `e2eb996077d73f005dfde60e72d4d745b7e459f93b887ea6f88f13da9ec1fab1` |
| [Sources/SYDownloadApp/Models/AppModel+HistoryUX.swift](../Sources/SYDownloadApp/Models/AppModel+HistoryUX.swift) | 1-14 | `9378c616465ba238091c50c9efb012d5459af1072a02d9bf33b63c21fae79ba3` |
| [Sources/SYDownloadApp/Models/AppModel.swift](../Sources/SYDownloadApp/Models/AppModel.swift) | 1-1465 | `ee4f985b42ec81cca0b747c71d3eb2309c2644fbc4ea7c9f6970e8f244a7f837` |
| [Sources/SYDownloadApp/Models/ExifEditorModel.swift](../Sources/SYDownloadApp/Models/ExifEditorModel.swift) | 1-108 | `72d3995cd4954b7ddb9173f0b7fa1aefea78547d63c79deecfe8da95fe7c427a` |
| [Sources/SYDownloadApp/Models/ExifProcessingTypes.swift](../Sources/SYDownloadApp/Models/ExifProcessingTypes.swift) | 1-63 | `dc0ccaf751602b2b04438e168b5cc6a3499205930690c95ec59ad3cdc09aefbb` |
| [Sources/SYDownloadApp/ResourceBundle.swift](../Sources/SYDownloadApp/ResourceBundle.swift) | 1-9 | `40a0186b93364cddcc0e6669f5ef528b5cd30558b05cff156b35170231394b0d` |
| [Sources/SYDownloadApp/SYDownloadAppDelegate.swift](../Sources/SYDownloadApp/SYDownloadAppDelegate.swift) | 1-48 | `000b779d2611c68a3c86c3d992766b31b7318b2f80ca707a3153bb9335af2e3d` |
| [Sources/SYDownloadApp/SYDownloadLayout.swift](../Sources/SYDownloadApp/SYDownloadLayout.swift) | 1-29 | `9e50dcde0fee10339ac49d32a1b39a7d2de8b27d32fb8ba02321caf4887ea089` |
| [Sources/SYDownloadApp/Services/AsyncSemaphore.swift](../Sources/SYDownloadApp/Services/AsyncSemaphore.swift) | 1-31 | `f6977901ec331a2e7fc610664610d7ed029423eb3a2ad0d34aa3e0b44add3c84` |
| [Sources/SYDownloadApp/Services/BridgeClient.swift](../Sources/SYDownloadApp/Services/BridgeClient.swift) | 1-317 | `3d42f4a0a009a5b7efbd063b05200233bf49822c01d0f40c2c678dd0f2180f37` |
| [Sources/SYDownloadApp/Services/ExifProcessingService.swift](../Sources/SYDownloadApp/Services/ExifProcessingService.swift) | 1-218 | `f065b7df690b4d2138c84e579ddbbed8160457a7bccca838d3db53b9b6535a31` |
| [Sources/SYDownloadApp/Services/PhotoLibraryService.swift](../Sources/SYDownloadApp/Services/PhotoLibraryService.swift) | 1-189 | `214c10b002395cc7b5a5e38296f2aabeba6525e3082effd054fca4072d8cff5b` |
| [Sources/SYDownloadApp/Services/SYDownloadUpdater.swift](../Sources/SYDownloadApp/Services/SYDownloadUpdater.swift) | 1-45 | `007478bc44b810e6c97de5687389af8cb1c95158618dad0a58f47c1249517251` |
| [Sources/SYDownloadApp/Views/AboutView.swift](../Sources/SYDownloadApp/Views/AboutView.swift) | 1-122 | `c3c9a7b68b4ccf1c0aa8f949873722c345b37d3c2dbd90b0def7ca7b5e92937c` |
| [Sources/SYDownloadApp/Views/ContentView.swift](../Sources/SYDownloadApp/Views/ContentView.swift) | 1-100 | `ac361db84f00627896007a8399c690da84e2cf186ec2aed1d48237f6de31840e` |
| [Sources/SYDownloadApp/Views/DesignComponents.swift](../Sources/SYDownloadApp/Views/DesignComponents.swift) | 1-168 | `7e08e87c95ac08e94ea9d223885cdd3363b328be2d33fccba32a66dbb9ab4c3c` |
| [Sources/SYDownloadApp/Views/DownloadView.swift](../Sources/SYDownloadApp/Views/DownloadView.swift) | 1-269 | `4a95c517cfd8083d82d4f276615f2c1e038407cf6424b89ea4ac8fcabab37a92` |
| [Sources/SYDownloadApp/Views/ExifEditorView.swift](../Sources/SYDownloadApp/Views/ExifEditorView.swift) | 1-124 | `ae401d838b4baa12e87458c0c1ee67331cd84bf62ad7054b4dba493978c6036e` |
| [Sources/SYDownloadApp/Views/ExifFileTable.swift](../Sources/SYDownloadApp/Views/ExifFileTable.swift) | 1-101 | `a0c4f6787d1eed5b696bf84f81ded640a2e84d5b4a0f0c10955baa8d72327497` |
| [Sources/SYDownloadApp/Views/ExifInspector.swift](../Sources/SYDownloadApp/Views/ExifInspector.swift) | 1-74 | `e69df822721c86f4aef4f0516ef7e148e48e467d3881a0c90359e5c8a3bfc485` |
| [Sources/SYDownloadApp/Views/HistoryView.swift](../Sources/SYDownloadApp/Views/HistoryView.swift) | 1-299 | `a4f6c3dd5778f6ddb01861fabb33957b4eb606974436455de74361becb7a417c` |
| [Sources/SYDownloadApp/Views/PhotosView.swift](../Sources/SYDownloadApp/Views/PhotosView.swift) | 1-698 | `5063647f7dc7efdf33fd0b5df8757d9c08762fd18b2d0796b354dd78ba3a7cc3` |
| [Sources/SYDownloadApp/Views/SettingsView.swift](../Sources/SYDownloadApp/Views/SettingsView.swift) | 1-1067 | `a85224568eb48c224f00ff38d186c5385903e97f517b665a37aeb0c4e807e01a` |
| [Sources/SYDownloadApp/Views/SidebarView.swift](../Sources/SYDownloadApp/Views/SidebarView.swift) | 1-118 | `d971aa44001df39b430a424fc8978a74fa11d5b8d99a020b694e853416a0d4ba` |
| [Sources/SYDownloadApp/Views/TasksView.swift](../Sources/SYDownloadApp/Views/TasksView.swift) | 1-538 | `bbdef40034b2511c11ae004f8639fc412ae086826487d5611634c4cdfb285b81` |
| [Sources/SYDownloadApp/Views/UIRefinementComponents.swift](../Sources/SYDownloadApp/Views/UIRefinementComponents.swift) | 1-79 | `60abf980f97adc33a21d454fab272c2959835a3c6a1c821e58762ca5b5ed00b9` |
| [Sources/SYDownloadCore/BridgeModels.swift](../Sources/SYDownloadCore/BridgeModels.swift) | 1-79 | `cfc27d97238951bd7b364d2c17e7cd54de345fa10571111e20a986318e0006c4` |
| [Sources/SYDownloadCore/PlatformDetector.swift](../Sources/SYDownloadCore/PlatformDetector.swift) | 1-76 | `457c3d40d4f34b3a1ef719fe91244c1c29bfbd811cc6dc769da9b53a08e3ca6e` |
| [Tests/SYDownloadAppTests/AppModelDownloadTests.swift](../Tests/SYDownloadAppTests/AppModelDownloadTests.swift) | 1-310 | `626b314901ec5925a9c096039d3cb9bc45116c1624efa3f48b834399e51ff837` |
| [Tests/SYDownloadAppTests/DownloadRuntimeTests.swift](../Tests/SYDownloadAppTests/DownloadRuntimeTests.swift) | 1-170 | `ab69926b80e0e5adaed74a8115f9f8f9df75bf3d48769599918b38fb0f6dd4d1` |
| [Tests/SYDownloadAppTests/UpdaterTests.swift](../Tests/SYDownloadAppTests/UpdaterTests.swift) | 1-65 | `4e84d1867cb718a6dfe22895d6738a3d648c94771ed7239553297a400484b72e` |
| [Tests/SYDownloadCoreTests/PlatformDetectorTests.swift](../Tests/SYDownloadCoreTests/PlatformDetectorTests.swift) | 1-49 | `3d326fba51215e37e013bc5f7cf5680446c9d2a7828e820ffacc9bf7b1835fd1` |
| [VERSION](../VERSION) | 1-1 | `19754aefd27e92de8c47211fbc5bb30d95e85a61128529c448e75c47e7c0db8d` |
| [docs/design-review.md](../docs/design-review.md) | 1-62 | `868ab14b525f0667999b5ed669f39effeeb7e30366edd22537cab01574eb355b` |
| [docs/photo-script-gui.md](../docs/photo-script-gui.md) | 1-56 | `98b4d678f0f657a9885be00571eb6cd80ae43c9be0f040fbad2e5509d1cf8143` |
| [docs/sparkle-updates.md](../docs/sparkle-updates.md) | 1-30 | `75b6a5a4528842de907179bf2411b94f2a006bf1fca11c2c422db7bb4528893f` |
| [docs/validation.md](../docs/validation.md) | 1-40 | `69d9882dbae01adf2a6a5dd997638290436566202200420bc8946a78de66f183` |
| [script/build_and_run.sh](../script/build_and_run.sh) | 1-24 | `6b1e15f79ff97d9e0ffad1fdb55c27e3afacc4e149af7ef2f7b919574d7c53c0` |
| [script/build_dmg.sh](../script/build_dmg.sh) | 1-59 | `c69d126f8c4d60490c1016c9fcd3d0e5f92c0bd9c48acc5079367c0e8c888bf7` |
| [script/bundle_runtime.sh](../script/bundle_runtime.sh) | 1-278 | `dbc987078952d550966dd0e741672fff3cbb0fe633242b3c2b393de438165326` |
| [script/create_dmg_background.swift](../script/create_dmg_background.swift) | 1-121 | `17ab2d0ef66addbd5a1dfa2a407ee20aff809508bc9b6e8ee4bbd64f008af1fc` |
| [script/fetch_engines.sh](../script/fetch_engines.sh) | 1-30 | `caf7c4edf7002a89beda8a9bc4be04200d2b19c8c061013b3491e442fcf0643b` |
| [script/generate_sparkle_appcast.py](../script/generate_sparkle_appcast.py) | 1-50 | `69fffc272025523dcdab6147f989b5df0f97fa95bac6b276c01057b7e01e0b30` |
| [script/package_app.sh](../script/package_app.sh) | 1-103 | `5766af4136ea7c2d2c9d961538b6ae5d664d0163bea027fdec4df8f572b0093d` |
| [script/setup_python.sh](../script/setup_python.sh) | 1-15 | `4b894337ce9828d83d718a71b878f09e1a7b2ce25f8b1633a43def94164f6c60` |
| [script/test_exif.sh](../script/test_exif.sh) | 1-11 | `fbb629ec26da675d4e440ca005848adf66a323c181abaca7bec6718529685f59` |
| [script/test_exif.swift](../script/test_exif.swift) | 1-107 | `c28505fdb1fe7a4616ae386a23203017422597294ee903936dfbae5479a7b5a2` |
| [script/test_release_tools.py](../script/test_release_tools.py) | 1-41 | `84f4792c23e8fee2ea08acc5852dbd497b85c79667b7355fcd9272352a8f8c40` |
| [script/verify_bundle_links.py](../script/verify_bundle_links.py) | 1-17 | `807cd7cff0f9947e1a31aa2ef1c114925f9dd3ed871faac4de98d2c262c45859` |
| [sparkle-public-key.txt](../sparkle-public-key.txt) | 1-1 | `0cfd669f050b62c76cdaab57e96f94078fabab7b391a6c86e921c426bfce75d3` |

## 资源和排除项

- 已视觉查看三张实际产品资源：SYDownloadIcon.png、XiaohongshuPlatformIcon.jpg、DouyinPlatformIcon.jpg；图标保持原样。
- 额外全文读取用户提供的仓库外 e.sh，仅比较功能需求，没有执行；不计入仓库输入文件数。
- `.git/`：版本库内部数据，不是应用界面实现。
- `.build/`、`dist/`：生成物及第三方依赖。本轮检查现有 dist 开发构建界面，但编译产物及 Sparkle 第三方实现不计作本项目源码。
- `Engines/`：被忽略的上游第三方引擎源码。本项目全部 Bridge 和打包时注入的适配改动均已全文阅读。
- `.swiftpm/`：IDE workspace、scheme 和用户状态，不属于产品界面。空文件、`.DS_Store`、`__pycache__` 也不计入。
- docs 历史截图：以往验证产物，不是当前 UI 实现，也不作为本轮验证通过的依据。
- 被删除的 SYDownloadStyledUpdateSheet.swift 在当前工作区不存在，已由 Sparkle 标准界面替代，不能算作仍生效的 UI 代码。
- 本轮新建的审查报告、覆盖记录和证据属于输出，不计入输入覆盖数。

机器可读清单：[ui-ux-code-coverage.json](ui-ux-code-coverage.json)。
