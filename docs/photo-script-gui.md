# e.sh GUI 化研究

分析对象：`/Users/apple/Documents/APP/脚本/e.sh`。这里只将脚本视为待分析内容，没有运行它，也没有改动用户照片。

## 原脚本行为

1. 固定处理 `/Users/apple/Downloads/未命名文件夹`，只扫描一层，小写 `.png`、`.jpg`、`.jpeg`。
2. 使用 macOS `sips` 将 PNG 转成同名 JPEG。JPEG 已存在时跳过转换；检测到输出文件后删除 PNG。JPEG 为有损格式，透明度无法保留。
3. 对文件路径匹配 `YYYY-MM-DD_HH.mm.ss_编号`，以年、月、日、小时、分钟和**编号**生成 EXIF 时间，忽略文件名原来的秒数。
4. 使用外部 `exiftool -overwrite_original` 改写 `DateTimeOriginal`、`CreateDate`、`ModifyDate`，并固定写入 Make=Apple、Model=iPhone 15 Pro，没有备份。

风险：编号 60 或更大无法作为合法秒；`printf %d` 的前导零可能触发八进制解释；日期缺少合法性验证；完整路径参与正则会误匹配父目录；只判断输出存在可能把失败残留当作成功；重跑已存在的 JPEG 仍会覆盖 EXIF。固定相机信息会改变原始来源记录，须让用户明确选择。

## 在 SYDownload 中放哪里

根据用户后续要求，新增独立侧栏入口“EXIF 编辑”，与“照片整理”并列；独立维护文件夹、扫描计划、选项和执行状态。两页可以共享图片扫描和 Quick Look 基础能力，但不共享会修改文件的任务状态。不要自动挂到下载完成回调：不同来源文件名不保证符合格式。

建议三步流程：

| 步骤 | GUI 内容 | 执行规则 |
| --- | --- | --- |
| 扫描与预览 | 原文件名、格式、原 EXIF、拟写入时间、冲突/跳过原因 | 只读扫描，必须先展示计划 |
| 配置 | PNG 转 JPEG、质量、秒数来源、日期写入项、可选相机品牌/型号、保留原件 | 默认保留原件；默认保留文件名真实秒；“编号作秒”作为兼容模式且限 0–59 |
| 执行与结果 | 逐文件进度、取消、成功/跳过/失败列表、打开输出文件夹 | 默认写入独立输出目录，原文件不变；只有显式选择替换后才修改原件 |

传统 EXIF 时间没有时区，本功能严格校验后按文件名的年月日时分秒直接写入，避免隐式 UTC 换算；不推断或新增 OffsetTimeOriginal。编号超过 59 应标记为冲突，不擅自修改分钟。仅匹配 `lastPathComponent` 并用 Calendar 严格回验闰年、月份和时分秒。

## 已实现：SwiftUI + ImageIO + Foundation

新增独立 `ExifEditorView`、`ExifEditorModel`、`ExifProcessingService` 和不可变 `ExifFilePlan`。运行不依赖 ExifTool、Perl、sips 或 shell。ExifTool 仅用于开发时独立验收生成文件。

- 文件夹选择与拖入；只扫描顶层 JPG/JPEG/PNG，拒绝符号链接、损坏或多帧图片。
- 左侧勾选文件并查看原值与拟写入值；右侧设置时间规则、转换质量、相机信息和保存方式。
- 日期默认保留文件名里的真实秒数；兼容脚本时使用末尾编号，十进制解析并限制 0–59。通过 Gregorian Calendar 严格回验日期，不对文件名时间进行时区换算。
- 写入 EXIF `DateTimeOriginal`、`DateTimeDigitized`（ExifTool 的 CreateDate）和 TIFF `DateTime`（ExifTool 的 ModifyDate）。仅勾选相机修改时写入 TIFF Make/Model。磁盘创建时间不在功能范围内；文件写出会有正常的磁盘修改时间变化。
- 默认保留原图，写入当前目录的“EXIF 输出”。PNG 转 JPEG 默认关闭，品牌/型号修改默认关闭。
- 可选择“备份原图，再替换”，执行前确认。每批创建独立备份目录，完整复制原文件；转换 PNG 时验证并提交 JPEG 后才移除 PNG。
- 逐文件显示成功、跳过、失败；可取消尚未提交的文件，已成功保存的结果保留。切换其他侧栏页面不会丢失工作区状态。

### 原生写入方式与边界

JPEG 使用 `CGImageDestinationCopyImageSource` 合并元数据，不重新编码图像。此 API 已自行完成输出，不额外调用 Finalize。测试比较 JPEG SOS 之后的数据，确认测试样本图像数据完全一致。

PNG 的 CopyImageSource 合并在测试中出现已有 eXIf 时间未更新，因此 PNG 使用 ImageIO 无损写出，再比较解码像素、位深和布局；不一致即拒绝保存。PNG 转 JPEG 使用指定质量并将透明区域填充白色，属于有损转换。

所有输出先写同目录隐藏临时文件，验证解码、选定标签、尺寸和方向；提交前再次读取源文件大小/修改时间，拒绝使用已失效的预览。同名目标不覆盖。替换模式先备份，失败不主动删除原图。不保证覆盖所有厂商私有元数据、HDR 附加数据或第三方 XMP 冲突；默认保留原图，真实相机样本仍需补充兼容性验收。

参考：[Apple ImageIO](https://developer.apple.com/documentation/imageio/cgimagedestination)、[元数据属性映射](https://developer.apple.com/documentation/imageio/cgimagemetadatasetvaluematchingimageproperty(_:_:_:_:))。

## 验收样例

合法文件名、闰日/非法日期、编号 0/08/59/60/100、大小写扩展名、空格/中文文件名、父目录含日期、同名 JPEG、透明 PNG、带方向的 JPEG、损坏文件、无权限目录、大目录中途取消、重复执行。读取导出文件确认像素可解码、方向正确、EXIF 只有所选项改变、取消后源文件与已有目标不受影响。

已使用生成图片完成原生流水线和实际 GUI 验证；未执行原脚本，也未修改用户照片。详见 `docs/validation.md`。

界面审查和视觉修订见 [设计审查](design-review.md)。
