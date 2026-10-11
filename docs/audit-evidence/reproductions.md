# 隔离复现记录

审查日期：2026-10-10 至 2026-10-11。以下是审查样例，不是完整测试套件。

## EXIF 模型

将当前 ExifProcessingTypes.swift、ExifProcessingService.swift 和 ExifEditorModel.swift 与临时 @main runner 一起编译，使用 macOS 26.5 SDK，读取 `/private/tmp/SYDownload-EXIF-UI` 中此前生成的三张测试图片。

步骤一：打开并等待扫描完成；排除一个文件；改变相机品牌并刷新；确认被排除的 URL 又进入 selected。

步骤二：切换 secondsSource 为 suffix；调用 refresh 后立即 cancel；确认 busy 为 false、readyCount 大于零，但 `_08.jpg` 的计划时间仍是 12:34:56，当前规则应为 12:34:08。

实际输出：

```text
REPRODUCED: refresh reselects manually excluded file
REPRODUCED: cancelled rescan leaves runnable old timestamp 2024:02:29 12:34:56, current rule requires 2024:02:29 12:34:08
No processing or image writes performed
```

没有调用 run/process，没有写入或删除图片。GUI 也复现排除一张后输入 Canon，选择数量从 2 恢复 3。

## 下载校验归属

直接导入本项目 `Bridge/download_runtime.py`，在 TemporaryDirectory 中：A 建立空 baseline；只创建 `task-b.jpg`，内容 27 bytes；使用 A 的 baseline 调用 verify_output。实际输出：

```text
REPRODUCED: task A reports written using only task B output
{'verification': 'written', 'verified_files': 1, 'verified_bytes': 27}
```

这是共享目录校验缺少任务归属的最小复现；没有发起真实网络下载，不代表已经完成真实引擎并发验收。

## 设置放弃失败

现有 dist 开发包未包含下载引擎。打开小红书设置显示“找不到对应下载引擎”；临时启用“每个作品使用独立文件夹”；切到下载，选择放弃更改；返回小红书设置。

实际状态：开关仍为 on，底栏显示“当前配置已保存”，保存按钮禁用。[AX 记录](settings-failed-discard.txt)保留了该状态。没有保存配置、读取浏览器 Cookie 或修改下载目录。完成后退出测试进程，清除临时内存字段。

## 照片整理

读取生成图片目录，包含顶层三张图片和 EXIF 输出子目录中的三张，实际显示六张；界面没有说明递归范围，同名预览无法从标签判断来源路径。切换下载页再返回照片整理，回到未选目录空态。没有执行删除。
