#!/usr/bin/env python3
"""XDownloader bridge between the SwiftUI shell and bundled Python engines.

Protocol: one JSON request per line, one JSON response per line.
The bridge keeps the native UI independent from upstream downloader internals.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import traceback
from typing import Any

sys.dont_write_bytecode = True

ENGINE_NAMES = {
    "xiaohongshu": "XHS-Downloader",
    "douyin": "TikTokDownloader",
    "tiktok": "TikTokDownloader",
}
ENV_NAMES = {
    "xiaohongshu": "XDOWNLOADER_XHS_ROOT",
    "douyin": "XDOWNLOADER_DOUK_ROOT",
    "tiktok": "XDOWNLOADER_DOUK_ROOT",
}


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
    """Repo root in development, Contents/Resources inside the packaged app."""
    return Path(__file__).resolve().parent.parent


def app_support_dir() -> Path:
    override = os.environ.get("XDOWNLOADER_APP_SUPPORT")
    target = (
        Path(override).expanduser()
        if override
        else Path.home() / "Library" / "Application Support" / "XDownloader"
    )
    target.mkdir(parents=True, exist_ok=True)
    return target


def cache_dir() -> Path:
    override = os.environ.get("XDOWNLOADER_CACHE")
    target = (
        Path(override).expanduser()
        if override
        else Path.home() / "Library" / "Caches" / "XDownloader"
    )
    target.mkdir(parents=True, exist_ok=True)
    return target


def engine_manifest() -> dict[str, Any]:
    path = project_root() / "engine-manifest.json"
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def engine_revision(name: str) -> str:
    engines = engine_manifest().get("engines", {})
    if isinstance(engines, dict):
        value = engines.get(name)
        if isinstance(value, str) and value:
            return value
    return "unversioned"


def bundled_engine_source(name: str) -> Path | None:
    source = project_root() / "engines" / name
    return source if (source / "main.py").is_file() else None


def stage_bundled_engine(name: str) -> Path | None:
    """Copy bundled engine source to Application Support before executing it.

    Upstream projects create configuration, Volume and generated JS files next
    to their source tree. The signed app bundle must remain immutable, so the
    engine source is treated as a template and executed from a writable,
    revisioned Application Support directory.
    """
    source = bundled_engine_source(name)
    if source is None:
        return None

    revision = engine_revision(name)
    destination = app_support_dir() / "engines" / name / revision
    marker = destination / ".xdownloader-staged"
    if (destination / "main.py").is_file() and marker.is_file():
        return destination

    destination.parent.mkdir(parents=True, exist_ok=True)
    incoming = destination.parent / f".{revision}.incoming-{os.getpid()}"
    shutil.rmtree(incoming, ignore_errors=True)
    shutil.copytree(
        source,
        incoming,
        symlinks=True,
        ignore=shutil.ignore_patterns(".git", "__pycache__", "*.pyc"),
    )
    marker_incoming = incoming / ".xdownloader-staged"
    marker_incoming.write_text(revision + "\n", encoding="utf-8")

    if destination.exists():
        shutil.rmtree(destination)
    incoming.replace(destination)
    return destination


def resolve_engine(platform: str) -> Path | None:
    name = ENGINE_NAMES.get(platform)
    if name is None:
        return None

    override = os.environ.get(ENV_NAMES.get(platform, ""), "")
    if override:
        root = Path(override).expanduser()
        return root if (root / "main.py").is_file() else None

    staged = stage_bundled_engine(name)
    if staged is not None:
        return staged

    # Development fallback used by script/fetch_engines.sh.
    dev = project_root() / "Engines" / name
    return dev if (dev / "main.py").is_file() else None


def response(
    request_id: str | None,
    ok: bool,
    platform: str | None,
    message: str,
    **details: Any,
) -> dict[str, Any]:
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
        key = ENV_NAMES[platform]
        return response(
            req.get("id"),
            False,
            platform,
            f"已识别 {platform}，但尚未找到对应引擎。",
            expected_env=key,
            app_support=app_support_dir(),
            cache=cache_dir(),
        )

    name = ENGINE_NAMES[platform]
    return response(
        req.get("id"),
        True,
        platform,
        "平台识别、内置 Python 和下载引擎均已就绪。",
        engine=engine,
        engine_revision=engine_revision(name),
        python=sys.executable,
        app_support=app_support_dir(),
        cache=cache_dir(),
    )


def run_xhs(engine: Path, url: str, output: Path) -> tuple[bool, str]:
    cmd = [
        sys.executable,
        str(engine / "main.py"),
        "-u",
        url,
        "-wp",
        str(output),
        "-l",
        "zh_CN",
    ]
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["PYTHONNOUSERSITE"] = "1"
    proc = subprocess.run(
        cmd,
        cwd=engine,
        capture_output=True,
        text=True,
        env=env,
    )
    text = (proc.stdout + "\n" + proc.stderr).strip()
    return proc.returncode == 0, text[-5000:]


async def run_douk_in_process(
    engine: Path,
    url: str,
    output: Path,
    platform: str,
) -> tuple[bool, str]:
    """Compatibility adapter around DouK's current internal single-work flow."""
    sys.path.insert(0, str(engine))
    old_cwd = Path.cwd()
    os.chdir(engine)
    try:
        from src.application import TikTokDownloader  # type: ignore
        from src.application.main_monitor import ClipboardMonitor  # type: ignore
        from src.config import Parameter  # type: ignore

        async with TikTokDownloader() as app:
            app.check_config()
            settings_data = app.settings.read()
            settings_data["root"] = str(output)
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
                await worker._handle_detail(ids, tiktok, record)
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
        return response(
            req.get("id"),
            False,
            platform,
            "对应下载引擎不存在或未能完成初始化。",
        )

    output_raw = req.get("outputDirectory") or str(
        Path.home() / "Downloads" / "XDownloader"
    )
    output = Path(output_raw).expanduser()
    output.mkdir(parents=True, exist_ok=True)

    try:
        if platform == "xiaohongshu":
            ok, log = run_xhs(engine, url, output)
        else:
            ok, log = asyncio.run(run_douk_in_process(engine, url, output, platform))
        return response(
            req.get("id"),
            ok,
            platform,
            "下载调用完成。" if ok else "下载引擎返回失败。",
            engine=engine,
            output=output,
            log=log,
        )
    except Exception as exc:
        return response(
            req.get("id"),
            False,
            platform,
            f"引擎调用异常：{exc}",
            traceback=traceback.format_exc()[-5000:],
        )


def handle(req: dict[str, Any]) -> dict[str, Any]:
    command = req.get("command")
    if command == "ping":
        return response(
            req.get("id"),
            True,
            None,
            "pong",
            python=sys.version.split()[0],
            executable=sys.executable,
        )
    if command == "detect":
        platform = detect_platform(req.get("url") or "")
        return response(
            req.get("id"),
            platform != "unknown",
            platform,
            f"识别结果：{platform}",
        )
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
            result = response(
                None,
                False,
                None,
                f"Bridge 错误：{exc}",
                traceback=traceback.format_exc(),
            )
        print(json.dumps(result, ensure_ascii=False), flush=True)
        if args.once:
            break
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
