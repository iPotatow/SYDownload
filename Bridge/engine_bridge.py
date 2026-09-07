#!/usr/bin/env python3
"""XDownloader feasibility bridge.

Protocol: one JSON request per line, one JSON response per line.
The bridge deliberately keeps the Swift UI independent from upstream Python internals.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path
import subprocess
import sys
import traceback
from typing import Any
from urllib.parse import urlparse


def detect_platform(text: str) -> str:
    value = (text or "").strip().lower()
    if "xiaohongshu.com" in value or "xhslink.com" in value:
        return "xiaohongshu"
    if "douyin.com" in value:
        return "douyin"
    if "tiktok.com" in value:
        return "tiktok"
    return "unknown"


def project_root() -> Path:
    return Path(__file__).resolve().parent.parent


def resolve_engine(platform: str) -> Path | None:
    env_map = {
        "xiaohongshu": "XDOWNLOADER_XHS_ROOT",
        "douyin": "XDOWNLOADER_DOUK_ROOT",
        "tiktok": "XDOWNLOADER_DOUK_ROOT",
    }
    default_map = {
        "xiaohongshu": project_root() / "Engines" / "XHS-Downloader",
        "douyin": project_root() / "Engines" / "TikTokDownloader",
        "tiktok": project_root() / "Engines" / "TikTokDownloader",
    }
    override = os.environ.get(env_map.get(platform, ""), "")
    root = Path(override).expanduser() if override else default_map.get(platform)
    return root if root and (root / "main.py").is_file() else None


def app_support_dir() -> Path:
    # On macOS this resolves to the standard user Application Support area.
    home = Path.home()
    target = home / "Library" / "Application Support" / "XDownloader"
    target.mkdir(parents=True, exist_ok=True)
    return target


def cache_dir() -> Path:
    target = Path.home() / "Library" / "Caches" / "XDownloader"
    target.mkdir(parents=True, exist_ok=True)
    return target


def response(request_id: str | None, ok: bool, platform: str | None, message: str, **details: Any) -> dict[str, Any]:
    return {
        "id": request_id,
        "ok": ok,
        "platform": platform,
        "message": message,
        "details": {k: str(v) for k, v in details.items()} or None,
    }


def validate(req: dict[str, Any]) -> dict[str, Any]:
    url = req.get("url") or ""
    platform = detect_platform(url)
    if platform == "unknown":
        return response(req.get("id"), False, platform, "无法识别链接平台。")
    engine = resolve_engine(platform)
    if engine is None:
        key = "XDOWNLOADER_XHS_ROOT" if platform == "xiaohongshu" else "XDOWNLOADER_DOUK_ROOT"
        return response(
            req.get("id"), False, platform,
            f"已识别 {platform}，但尚未找到对应引擎。",
            expected_env=key,
            expected_default=(project_root() / "Engines").as_posix(),
            app_support=app_support_dir(),
            cache=cache_dir(),
        )
    return response(
        req.get("id"), True, platform,
        "平台识别和引擎定位均通过。",
        engine=engine,
        python=sys.executable,
        app_support=app_support_dir(),
        cache=cache_dir(),
    )


def run_xhs(engine: Path, url: str, output: Path) -> tuple[bool, str]:
    cmd = [
        sys.executable,
        str(engine / "main.py"),
        "-u", url,
        "-wp", str(output),
        "-l", "zh_CN",
    ]
    proc = subprocess.run(cmd, cwd=engine, capture_output=True, text=True)
    text = (proc.stdout + "\n" + proc.stderr).strip()
    return proc.returncode == 0, text[-5000:]


async def run_douk_in_process(engine: Path, url: str, output: Path, platform: str) -> tuple[bool, str]:
    """Compatibility spike using DouK's current internal classes.

    DouK does not currently expose a finished CLI/API adapter for a single URL,
    so the spike intentionally isolates private API usage here. If upstream adds
    a public single-work API, only this function needs replacement.
    """
    sys.path.insert(0, str(engine))
    old_cwd = Path.cwd()
    os.chdir(engine)
    try:
        from src.application import TikTokDownloader  # type: ignore
        from src.application.main_monitor import ClipboardMonitor  # type: ignore

        async with TikTokDownloader() as app:
            app.check_config()
            # Override root before Parameter is built, using the existing settings object.
            settings_data = app.settings.read()
            settings_data["root"] = str(output)
            # Parameter is created directly so we do not persist the user's upstream settings.
            from src.config import Parameter  # type: ignore
            app.parameter = Parameter(
                app.settings,
                app.cookie,
                logger=app.logger,
                console=app.console,
                **settings_data,
                recorder=app.recorder,
            )
            app.parameter.set_headers_cookie()

            worker = ClipboardMonitor(app.parameter, app.database)
            tiktok = platform == "tiktok"
            link_object = worker.links_tiktok if tiktok else worker.links
            ids = await link_object.run(url)
            if not any(ids):
                return False, "DouK 未能从链接提取作品 ID。"

            root, params, logger = worker.record.run(app.parameter, blank=True)
            async with logger(root, console=worker.console, **params) as record:
                await worker._handle_detail(ids, tiktok, record)  # isolated private API spike
            app.close()
            return True, f"DouK 已处理作品 ID：{ids}"
    finally:
        os.chdir(old_cwd)
        try:
            sys.path.remove(str(engine))
        except ValueError:
            pass


def download(req: dict[str, Any]) -> dict[str, Any]:
    url = req.get("url") or ""
    platform = detect_platform(url)
    if platform == "unknown":
        return response(req.get("id"), False, platform, "无法识别链接平台。")

    engine = resolve_engine(platform)
    if engine is None:
        return response(req.get("id"), False, platform, "对应 Python 引擎不存在，请先放入 Engines 目录。")

    output_raw = req.get("outputDirectory") or str(Path.home() / "Downloads" / "XDownloader")
    output = Path(output_raw).expanduser()
    output.mkdir(parents=True, exist_ok=True)

    try:
        if platform == "xiaohongshu":
            ok, log = run_xhs(engine, url, output)
        else:
            ok, log = asyncio.run(run_douk_in_process(engine, url, output, platform))
        return response(
            req.get("id"), ok, platform,
            "下载调用完成。" if ok else "下载引擎返回失败。",
            engine=engine,
            output=output,
            log=log,
        )
    except Exception as exc:
        return response(
            req.get("id"), False, platform,
            f"引擎调用异常：{exc}",
            traceback=traceback.format_exc()[-5000:],
        )


def handle(req: dict[str, Any]) -> dict[str, Any]:
    command = req.get("command")
    if command == "ping":
        return response(req.get("id"), True, None, "pong", python=sys.version.split()[0])
    if command == "detect":
        platform = detect_platform(req.get("url") or "")
        return response(req.get("id"), platform != "unknown", platform, f"识别结果：{platform}")
    if command == "validate":
        return validate(req)
    if command == "download":
        return download(req)
    return response(req.get("id"), False, None, f"未知命令：{command}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true", help="process one request and exit")
    args = parser.parse_args()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            result = handle(req)
        except Exception as exc:
            result = response(None, False, None, f"Bridge 错误：{exc}", traceback=traceback.format_exc())
        print(json.dumps(result, ensure_ascii=False), flush=True)
        if args.once:
            break
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
