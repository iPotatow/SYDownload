#!/bin/zsh

APP="/Applications/SYDownload.app"

if [[ ! -d "$APP" && -d "$HOME/Applications/SYDownload.app" ]]; then
    APP="$HOME/Applications/SYDownload.app"
fi

if [[ ! -d "$APP" ]]; then
    echo "未找到 SYDownload.app"
    echo "请先将 SYDownload 拖入“应用程序”文件夹。"
    read -r "?按回车键退出…"
    exit 1
fi

/usr/bin/xattr -d com.apple.quarantine "$APP" 2>/dev/null || true
/usr/bin/open "$APP"
