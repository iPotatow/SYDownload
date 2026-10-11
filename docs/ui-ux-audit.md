# SYDownload UI/UX 全量审查

后续状态：用户授权的修订已在 2026-10-11 实施，见 [修订记录与验证边界](ui-ux-fixes.md)。下文保留修订前审查快照。

审查日期：2026-10-10 至 2026-10-11。对象是当前工作区，包括此前尚未提交的修改。本轮只新增审查文档和验证证据，没有修改产品代码。

## 阅读覆盖与方法

已全文阅读 65 个仓库文本文件，共 10,921 行；其中包含全部 32 个 Swift 源文件，共 7,245 行。范围包括应用入口、窗口和菜单、六个页面、关于面板、共享组件、字体/色彩/布局、状态模型、照片/EXIF 服务、下载 Bridge、测试、安装和发布脚本、配置及文档。另全文读取用户提供的 e.sh，未执行。

每个文件从第一行读到末尾，分段输出核对连续覆盖；截断部分重读，结束时核对文件 SHA-256。文件清单及范围见 [全文覆盖记录](ui-ux-code-coverage.md)，机器记录见 [JSON 清单](ui-ux-code-coverage.json)。第三方依赖、生成物和 IDE 状态的排除理由均在清单中写明。“全文阅读”不等于所有运行分支均已验证。

完整阅读并应用：

- `redesign-existing-projects`：检查既有产品的一致性、层级、操作反馈和具体改进点。
- `apple-design`：检查桌面交互、焦点、状态反馈及减少动态效果；网页专用建议不套入原生应用。
- `build-macos-apps:swiftui-patterns`：连同 components-index、windowing、settings、commands-menus、split-inspectors 参考资料，检查窗口、命令、设置和工作区结构。
- `swiftui-pro`：连同全部九份参考资料，检查 API、视图、数据流、导航、设计、辅助功能、性能、Swift 与代码卫生。
- `build-macos-apps:appkit-interop`：连同 representables、window-panels、responder-menus、drag-drop-pasteboard，检查 AppKit 边界。
- `build-macos-apps:window-management`：连同 api-snippets，检查窗口和菜单行为。

不使用营销页版式、随机布局、网页字体或装饰动画作为本项目的审查标准。

## 品牌与设计基线

名称、原始应用图标、40 pt 侧栏品牌图标、16 pt 品牌文字、56 pt 品牌区域保持不变。保留 StarBox 紫色主题和主 surface 的上/右/下/左 8/8/8/0 pt 外边距、圆角及阴影。三张实际产品图标已视觉查看。

当前问题不是需要再次更换品牌，而是局部组件规格和操作状态没有真正统一。后续修订应在既有品牌、页面结构和原生控件基础上进行。

## 优先处理：状态、范围与结果可信度

### UX-01 · P1 · EXIF 修改规则会重新全选文件

位置：[ExifEditorModel.swift:53](../Sources/SYDownloadApp/Models/ExifEditorModel.swift#L53)、[ExifEditorView.swift:42](../Sources/SYDownloadApp/Views/ExifEditorView.swift#L42)。

现状：任何选项变化都会重新扫描；`finishScan` 把所有合法文件写入 `selected`，覆盖用户手动选择。实测先取消勾选一张，数量由 3 变 2，再输入相机品牌 Canon，数量恢复 3。单独编译当前模型也复现。

影响：用户排除的照片重新进入待处理范围，备份替换模式下尤其不符合预期。

建议：首次打开新目录时默认选中合法文件；同一目录刷新保留用户选择，并与新的合法文件集合求交集。规则变化不能擅自扩大处理范围。

### UX-02 · P1 · EXIF 取消重新扫描后旧计划仍可执行

位置：[ExifEditorModel.swift:33](../Sources/SYDownloadApp/Models/ExifEditorModel.swift#L33)、[ExifEditorModel.swift:68](../Sources/SYDownloadApp/Models/ExifEditorModel.swift#L68)、[ExifEditorModel.swift:74](../Sources/SYDownloadApp/Models/ExifEditorModel.swift#L74)。

现状：刷新保留旧 `plans`；取消只清除 busy。`run` 同时读取旧计划和当前选项，两者不一定属于同一次预览。隔离模型复现：由“文件名秒数”改为“末尾编号”后立即取消，当前规则应写 12:34:08，旧计划仍为 12:34:56，`readyCount > 0` 且不忙碌。没有执行图片写入。

建议：计划绑定目录、选项和 generation；只有当前规则对应的扫描成功后才允许执行。取消或失败后明确显示“预览待更新”，或者恢复与旧计划对应的选项。

### UX-03 · P1 · 照片整理更换目录后取消，目录与结果可能错配

位置：[PhotosView.swift:507](../Sources/SYDownloadApp/Views/PhotosView.swift#L507)、[PhotosView.swift:518](../Sources/SYDownloadApp/Views/PhotosView.swift#L518)。

代码确认：`openFolder` 立即换 `folderURL`，却保留旧 `scanResult`；`cancelScan` 不恢复旧目录，也不清除结果。因此 A 扫描完成后，开始读取 B 并取消，页面可能在 B 路径下展示 A 的文件；批量操作仍使用旧 URL。

建议：目录与扫描结果作为一个已提交快照整体更新；读取新目录时保持旧目录归属，或清空旧结果并禁用其操作。取消应回到明确且一致的状态。尚未做大目录 GUI 取消复现，不标记为运行验收通过。

### UX-04 · P1 · 放弃设置失败后显示“当前配置已保存”

位置：[AppModel.swift:1078](../Sources/SYDownloadApp/Models/AppModel.swift#L1078)、[SettingsView.swift:878](../Sources/SYDownloadApp/Views/SettingsView.swift#L878)。

现状：离页选择“放弃更改”后，重新读取失败仍清除 dirty 标记并离页。实际开发包缺少引擎时复现：临时打开“每个作品使用独立文件夹”，放弃并返回，开关仍为 on，而底栏显示“当前配置已保存”、保存按钮禁用。初始读取失败时同样会把未确认的数据描述为已保存。

建议：保留最近一次成功读取的快照，放弃时回滚到快照；无快照时应明确保留失败状态。读取失败不能清除未保存标记，底栏区分“尚未读取”“有更改”“已保存”。

证据：[失败放弃后的辅助功能状态](audit-evidence/settings-failed-discard.txt)。临时改动没有保存，验证后退出测试进程以清除内存状态。

### UX-05 · P1 · 并发任务的完成校验可能使用其他任务的文件

位置：[download_runtime.py:80](../Bridge/download_runtime.py#L80)、[engine_bridge.py:600](../Bridge/engine_bridge.py#L600)、[AppModel.swift:676](../Sources/SYDownloadApp/Models/AppModel.swift#L676)。

现状：最多三个并发任务对共享输出范围建立快照，任何文件增长都可触发 `verification=written`。隔离样例中 A 建立空快照后仅 B 写入文件，A 的 `verify_output` 返回成功、1 个文件、27 bytes。没有发起真实下载。

影响：任务界面可能把其他任务的写入计为本任务成功，进度和历史也可能被污染。

建议：以引擎返回的本任务文件清单/标识为依据校验，或使用任务独立暂存目录再提交。不能只靠共享目录前后差异证明任务完成。

## 操作闭环与工作区

| 编号 | 优先级 | 问题与证据 | 建议 |
| --- | --- | --- | --- |
| UX-06 | P2 | `ContentView.swift:91` 每次创建 PhotosView；`PhotosView.swift:9` 用局部 State 保存工作区。GUI 已复现：读取测试目录后切到下载再返回，目录和结果丢失。EXIF 则由 AppModel 保持状态，两页体验不同。 | 将照片工作区及任务生命周期放到稳定模型中；切页保留目录、结果和选择，明确取消/后台策略。 |
| UX-07 | P2 | `PhotoLibraryService.swift:53` 递归枚举子目录；`PhotosView.swift:66` 确认文案只说“当前文件夹”。实测顶层 3 张被读成 6 张，包含 EXIF 输出子目录，同名缩略图不显示相对路径。 | 明确“包含子文件夹”，显示相对路径；提供范围选择或排除输出/备份目录，删除确认与实际范围一致。 |
| UX-08 | P2 | `TasksView.swift:214,276,483` 对登录/磁盘错误仅提供修复设置入口，行菜单仅移除；修复后没有通用重试入口。`AppModel.swift:612` 重试仍使用任务原保存位置，修改全局目录不会修正旧任务目的地。代码确认，未启动真实失败任务。 | 设置修复后返回原任务，并提供明确重试；修改目的地要显式作用于该任务。保留查看错误/原链接入口。 |
| UX-09 | P2 | `TasksView.swift:342` 错误详情限制一行，没有完整详情面板、悬停全文或复制错误操作；菜单只提供恢复动作和移除。 | 让错误可展开或复制，短状态与完整诊断分开；恢复按钮旁保留可发现的详情入口。 |
| UX-10 | P2 | `ExifEditorView.swift:35` 只处理导入成功，失败被忽略；拖入无效路径虽被模型拒绝，已加载时反馈仍不突出。代码确认。 | 明确显示导入失败原因和重选入口；取消选择与实际失败分别处理。 |
| UX-11 | P2 | `ExifEditorView.swift:107` 只要 outcomes 非空就显示“打开结果”，即使全失败/全取消；没有核对结果目录存在，也没有用成功结果定位。 | 按成功输出或已确认存在的结果目录提供入口，失败时提供错误详情与重试。 |
| UX-12 | P2 | `ExifFileTable.swift:69` 对照仅含拍摄时间和相机，未展示同时改写的 CreateDate/ModifyDate、输出名称/位置、PNG 转 JPEG 的最终目标。`ExifInspector.swift:18` “创建及修改时间”可能被理解成磁盘文件时间，而实现改的是元数据。 | 补齐实际变更项与目标；明确“EXIF 创建时间 / 元数据修改时间”，保留有损转换说明。 |
| UX-13 | P2 | `PhotosView.swift:257` 日期勾选在删除过程中仍可改变；批次完成会清空选择，可能丢失处理中新增的选择。代码确认，未执行删除。 | 执行中冻结同一批次的范围，或保留不属于当前批次的新选择。 |
| UX-14 | P2 | `AppMain.swift:27` 替换 Cmd-N 但只切换模型并发送焦点通知，没有 openWindow；最后一个窗口关闭后无法靠该实现创建窗口。 | 使用明确窗口入口和 openWindow；用单窗口/多窗口语义决定共享模型与命令范围。当前仅代码风险，GUI 窗口复验被界面状态变化中断，不宣称已复现。 |

## 控件、视觉与辅助功能

| 编号 | 优先级 | 问题与证据 | 建议 |
| --- | --- | --- | --- |
| UI-01 | P2 | `UIRefinementComponents.swift:20` 任务操作列固定 124 pt；`TasksView.swift:460` 失败操作含自然宽度文字按钮、间距及 28 pt 菜单。CoreAction 又强制 horizontal fixedSize。“更改保存位置”等存在超列风险。 | 基于最长恢复操作检查最小窗口；为紧凑行提供专门样式，或将恢复动作放入菜单。不要直接全局放大按钮/挤占内容列。未用失败行 GUI 样例确认最终溢出形态。 |
| UI-02 | P2 | `ExifEditorView`、`ExifFileTable`、`ExifInspector` 大量直接使用 8/10/11/12 pt，8/10/14/20 等局部几何值，绕过共享 20/14/13/12 字体、10 pt 面板圆角及间距定义。代码和实际 EXIF 页面确认。 | 将文件名、数值、次级说明、分组标题映射到语义字体；确有紧凑需求时增加共享紧凑规格，而非整页自成体系。 |
| UI-03 | P2 | `CoreControls.swift:36` 图标操作声明 14 pt，但 `RemixIcon.swift:11` resizable 后固定到默认 16 pt，外层 font 无法统一它与原生 Image 的大小。 | 统一符号渲染入口和尺寸参数；区分品牌/平台图片与操作符号，保留真实产品图标。 |
| UI-04 | P2 | `SettingsView.swift:657,753` 给整个 Cookie 编辑器设置 accessibilityLabel。实际辅助功能树将“显示”“复制”“清除”三个按钮都命名为“小红书网页版 Cookie”，丢失动作名。 | 标签放在输入控件；按钮使用“显示小红书 Cookie”“复制小红书 Cookie”“清除小红书 Cookie”等独立名称。 |
| UI-05 | P2 | `SettingsView.swift:154` 命名字段用普通 Button 模拟多选；RemixIcon 隐藏于辅助功能树，实际 AX 中只显示字段按钮，没有选中值。移动按钮能读成“向前/后移动”，不能据此误报为完全无名。 | 用 Toggle/checkbox 表达选择状态；移动操作加上字段名和当前顺序，保留至少一项的约束说明。 |
| UI-06 | P3 | `TasksView.swift:115`、`HistoryView.swift:89` 搜索清除按钮仍用局部 plain 风格；命名字段移动按钮、Cookie 辅助动作也绕过共享控件规则。 | 定义输入内嵌按钮、行内图标、普通辅助动作的语义变体，统一命中区域/悬停/焦点，不强迫所有控件同一个高度。 |
| UI-07 | 待验证 | `CoreControls.swift:88` 侧栏自绘焦点边框只在未选中时显示，已选项的键盘焦点可能不明显。 | 用键盘和辅助功能设置复验选中项焦点；保留清晰的选择态与焦点态区分。尚未完成系统键盘导航配置下的复验，不作为已确认缺陷。 |

布局修订应优先解决内容、动作与状态之间的关系。照片/EXIF 可以有不同任务布局，但标题、说明、工具栏动作、选择与执行反馈需要遵守相同规则。不能通过删除特色图标、缩小品牌、移动 surface 外边距来“统一”。

## 已有实现中应保留的部分

- 原生 Picker、Table、系统按钮与菜单已有合理基础；省略号菜单已隐藏额外菜单箭头，当前历史顶部菜单可正常展开，无需重做菜单。
- 用户原有品牌图标、平台真实图标和紫色主题可以形成稳定识别，不需要换成新的符号体系。
- EXIF 独立功能入口、默认保留原图、备份替换确认、合法日期校验、冲突跳过、源文件变化检查是合理的操作边界。
- 下载的本地识别、状态分类、取消、超时和完成后校验方向合理；应修复归属与恢复闭环，而非移除反馈。
- 应用级退出代理解决了依赖窗口订阅的退出问题；本轮未回退该实现。
- Sparkle 使用标准更新界面；更新配置校验与原生入口保持一致，避免重新制作安装弹层。
- 大多数悬停动画已遵守 Reduce Motion；没有必要为了“高级感”增加装饰动画。

## 本轮验证与边界

实际界面检查覆盖下载、任务空态、历史操作菜单、照片整理、EXIF 工作区、通用/小红书设置及命名格式弹层。已复现 EXIF 自动全选、照片工作区丢失、递归包含输出目录、设置放弃失败仍标记已保存，以及 Cookie/命名字段的辅助功能状态问题。

另外直接编译当前 EXIF 模型/服务做隔离读取验证，复现取消后的计划与规则错配；用临时目录调用实际 Python 校验函数，复现其他任务文件可触发成功。复现摘要见 [验证记录](audit-evidence/reproductions.md)。

本轮没有修改产品代码，因此未重做完整构建；GUI 使用现有 dist 开发包，原生隔离验证使用 macOS 26.5 SDK。没有运行原脚本、启动真实下载、处理或删除真实照片、读取浏览器 Cookie、保存临时引擎设置、推送代码、发布 Release 或创建 PR。界面验证留下的临时设置未保存，测试进程已退出并重新启动。

尚未完成：失败任务长按钮的真实布局、大目录 GUI 取消、删除执行中的交互、关闭最后窗口后 Cmd-N、深色及各辅助功能系统设置的完整矩阵、真实下载的并发归属、Sparkle 两个版本之间的安装重启。已有文档中的往轮测试不替代这些验收。

后续修订顺序：先处理 UX-01 至 UX-05，再补工作区/恢复闭环；最后统一局部控件、字号和对照内容。每组修订只验证其实际影响路径，保持品牌和 surface 几何基线。
