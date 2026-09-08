#!/usr/bin/env python3
"""SYDownload bridge between the SwiftUI shell and bundled Python engines.

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
}
ENV_NAMES = {
    "xiaohongshu": "SYDOWNLOAD_XHS_ROOT",
    "douyin": "SYDOWNLOAD_DOUK_ROOT",
}
ENGINE_PLATFORMS = {
    "XHS-Downloader": "xiaohongshu",
    "TikTokDownloader": "douyin",
}
VISIBLE_SETTINGS = {
    "XHS-Downloader": (
        "image_download",
        "video_download",
        "live_download",
        "image_format",
        "video_preference",
        "note_format",
        "folder_name",
        "name_format",
        "folder_mode",
        "author_archive",
        "download_record",
        "write_mtime",
        "record_data",
        "cookie",
    ),
    "TikTokDownloader": (
        "music",
        "dynamic_cover",
        "static_cover",
        "original_quality",
        "folder_name",
        "folder_mode",
        "name_format",
        "desc_length",
        "name_length",
        "date_format",
        "split",
        "storage_format",
        "max_size",
        "cookie",
        "ffmpeg",
        "live_qualities",
    ),
}
FALLBACK_DEFAULTS = {
    "XHS-Downloader": {
        "mapping_data": {},
        "work_path": "",
        "folder_name": "Download",
        "name_format": "发布时间 作者昵称 作品标题",
        "impersonate": "chrome146",
        "cookie": "",
        "proxy": None,
        "proxy_download": False,
        "timeout": 10,
        "chunk": 1024 * 1024 * 2,
        "max_retry": 5,
        "record_data": False,
        "image_format": "JPEG",
        "image_download": True,
        "video_download": True,
        "live_download": False,
        "video_preference": "resolution",
        "folder_mode": False,
        "download_record": True,
        "author_archive": False,
        "write_mtime": False,
        "language": "zh_CN",
        "script_server": False,
        "note_format": "",
        "disclaimer_accepted": False,
    },
    "TikTokDownloader": {
        "accounts_urls": [{"mark": "", "url": "", "tab": "", "earliest": "", "latest": "", "enable": True}],
        "accounts_urls_tiktok": [{"mark": "", "url": "", "tab": "", "earliest": "", "latest": "", "enable": True}],
        "mix_urls": [{"mark": "", "url": "", "enable": True}],
        "mix_urls_tiktok": [{"mark": "", "url": "", "enable": True}],
        "owner_url": {"mark": "", "url": "", "uid": "", "sec_uid": "", "nickname": ""},
        "owner_url_tiktok": None,
        "root": "",
        "folder_name": "Download",
        "name_format": "create_time type nickname desc",
        "desc_length": 64,
        "name_length": 128,
        "date_format": "%Y-%m-%d %H:%M:%S",
        "split": "-",
        "folder_mode": False,
        "music": False,
        "truncate": 50,
        "storage_format": "",
        "cookie": "",
        "cookie_tiktok": "",
        "dynamic_cover": False,
        "static_cover": False,
        "proxy": "",
        "proxy_tiktok": "",
        "twc_tiktok": "",
        "download": True,
        "max_size": 0,
        "chunk": 1024 * 1024 * 2,
        "timeout": 10,
        "max_retry": 5,
        "max_pages": 0,
        "run_command": "",
        "ffmpeg": "",
        "live_qualities": "",
        "original_quality": False,
        "douyin_platform": True,
        "tiktok_platform": True,
        "browser_info": {
            "impersonate": "chrome146",
            "pc_libra_divert": "Mac",
            "browser_language": "zh-CN",
            "browser_platform": "MacIntel",
            "browser_name": "Chrome",
            "browser_version": "146.0.0.0",
            "engine_name": "Blink",
            "engine_version": "146.0.0.0",
            "os_name": "Mac OS",
            "os_version": "10.15.7",
            "webid": "",
        },
        "browser_info_tiktok": {
            "impersonate": "chrome146",
            "app_language": "zh-Hans",
            "browser_language": "zh-CN",
            "browser_name": "Mozilla",
            "browser_platform": "MacIntel",
            "browser_version": "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36",
            "language": "zh-Hans",
            "os": "mac",
            "priority_region": "US",
            "region": "US",
            "tz_name": "Asia/Shanghai",
            "webcast_language": "zh-Hans",
            "device_id": "",
        },
    },
}


def detect_platform(text: str) -> str:
    value = (text or "").strip().lower()
    if "xiaohongshu.com" in value or "xhslink.com" in value:
        return "xiaohongshu"
    if "douyin.com" in value:
        return "douyin"
    return "unknown"


def project_root() -> Path:
    """Repo root in development, Contents/Resources inside the packaged app."""
    return Path(__file__).resolve().parent.parent


def app_support_dir() -> Path:
    override = os.environ.get("SYDOWNLOAD_APP_SUPPORT")
    target = (
        Path(override).expanduser()
        if override
        else Path.home() / "Library" / "Application Support" / "SYDownload"
    )
    target.mkdir(parents=True, exist_ok=True)
    return target


def cache_dir() -> Path:
    override = os.environ.get("SYDOWNLOAD_CACHE")
    target = (
        Path(override).expanduser()
        if override
        else Path.home() / "Library" / "Caches" / "SYDownload"
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
    """Copy bundled engine source to Application Support before executing it."""
    source = bundled_engine_source(name)
    if source is None:
        return None

    revision = engine_revision(name)
    destination = app_support_dir() / "engines" / name / revision
    marker = destination / ".sydownload-staged"
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
    marker_incoming = incoming / ".sydownload-staged"
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


def read_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
        return value if isinstance(value, dict) else None
    except (OSError, json.JSONDecodeError, UnicodeDecodeError):
        return None


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=4) + "\n",
        encoding="utf-8",
    )


def stable_settings_path(name: str) -> Path:
    return app_support_dir() / "Config" / name / "settings.json"


def engine_settings_path(engine: Path) -> Path:
    return engine / "Volume" / "settings.json"


def upstream_defaults(name: str, engine: Path) -> dict[str, Any]:
    """Read the defaults from the bundled upstream settings class when possible."""
    old_cwd = Path.cwd()
    sys.path.insert(0, str(engine))
    os.chdir(engine)
    try:
        if name == "XHS-Downloader":
            from source.module.settings import Settings as UpstreamSettings  # type: ignore
        else:
            from src.config.settings import Settings as UpstreamSettings  # type: ignore
        value = getattr(UpstreamSettings, "default", {})
        if isinstance(value, dict):
            return json.loads(json.dumps(value, ensure_ascii=False))
    except Exception:
        pass
    finally:
        os.chdir(old_cwd)
        try:
            sys.path.remove(str(engine))
        except ValueError:
            pass
    return json.loads(json.dumps(FALLBACK_DEFAULTS[name], ensure_ascii=False))


def legacy_settings(name: str, engine: Path) -> dict[str, Any] | None:
    current = read_json(engine_settings_path(engine))
    if current is not None:
        return current

    root = app_support_dir() / "engines" / name
    if not root.is_dir():
        return None
    candidates = list(root.glob("*/Volume/settings.json"))
    candidates.sort(key=lambda p: p.stat().st_mtime if p.exists() else 0, reverse=True)
    for path in candidates:
        value = read_json(path)
        if value is not None:
            return value
    return None


def ensure_stable_settings(name: str, engine: Path) -> dict[str, Any]:
    path = stable_settings_path(name)
    defaults = upstream_defaults(name, engine)
    existing = read_json(path)
    if existing is None:
        existing = legacy_settings(name, engine) or {}
    merged = defaults
    merged.update(existing)
    write_json(path, merged)
    return merged


def sync_engine_settings(name: str, engine: Path) -> dict[str, Any]:
    data = ensure_stable_settings(name, engine)
    write_json(engine_settings_path(engine), data)
    return data


def update_engine_settings(name: str, engine: Path, values: dict[str, Any]) -> dict[str, Any]:
    data = ensure_stable_settings(name, engine)
    data.update(values)
    write_json(stable_settings_path(name), data)
    write_json(engine_settings_path(engine), data)
    return data


def capture_engine_settings(name: str, engine: Path) -> None:
    generated = read_json(engine_settings_path(engine))
    if generated is None:
        return
    stable = ensure_stable_settings(name, engine)
    stable.update(generated)
    write_json(stable_settings_path(name), stable)


def settings_engine(req: dict[str, Any]) -> tuple[str, str, Path] | None:
    platform = (req.get("engine") or "").strip().lower()
    name = ENGINE_NAMES.get(platform)
    if name is None:
        return None
    engine = resolve_engine(platform)
    if engine is None:
        return None
    return platform, name, engine


def settings_get(req: dict[str, Any]) -> dict[str, Any]:
    resolved = settings_engine(req)
    if resolved is None:
        return response(req.get("id"), False, None, "找不到对应下载引擎。")
    platform, name, engine = resolved
    data = sync_engine_settings(name, engine)
    details = {key: data.get(key, "") for key in VISIBLE_SETTINGS[name]}
    details["config_path"] = stable_settings_path(name)
    return response(req.get("id"), True, None, f"已读取{('小红书' if platform == 'xiaohongshu' else '抖音')}设置。", **details)


def settings_update(req: dict[str, Any]) -> dict[str, Any]:
    resolved = settings_engine(req)
    if resolved is None:
        return response(req.get("id"), False, None, "找不到对应下载引擎。")
    platform, name, engine = resolved
    raw = req.get("settingsJSON") or "{}"
    try:
        values = json.loads(raw)
    except json.JSONDecodeError:
        return response(req.get("id"), False, None, "设置数据不是有效 JSON。")
    if not isinstance(values, dict):
        return response(req.get("id"), False, None, "设置数据必须是 JSON 对象。")
    update_engine_settings(name, engine, values)
    return response(
        req.get("id"),
        True,
        None,
        f"已保存{('小红书' if platform == 'xiaohongshu' else '抖音')}设置。",
        config_path=stable_settings_path(name),
    )


def settings_reset(req: dict[str, Any]) -> dict[str, Any]:
    resolved = settings_engine(req)
    if resolved is None:
        return response(req.get("id"), False, None, "找不到对应下载引擎。")
    platform, name, engine = resolved
    defaults = upstream_defaults(name, engine)
    write_json(stable_settings_path(name), defaults)
    write_json(engine_settings_path(engine), defaults)
    return response(
        req.get("id"),
        True,
        None,
        f"已恢复{('小红书' if platform == 'xiaohongshu' else '抖音')}上游默认设置。",
        config_path=stable_settings_path(name),
    )


def settings_path(req: dict[str, Any]) -> dict[str, Any]:
    resolved = settings_engine(req)
    if resolved is None:
        return response(req.get("id"), False, None, "找不到对应下载引擎。")
    _, name, engine = resolved
    ensure_stable_settings(name, engine)
    return response(req.get("id"), True, None, "配置文件已就绪。", config_path=stable_settings_path(name))


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
    sync_engine_settings(name, engine)
    return response(
        req.get("id"),
        True,
        platform,
        "平台识别、内置 Python、下载引擎和配置均已就绪。",
        engine=engine,
        engine_revision=engine_revision(name),
        settings=stable_settings_path(name),
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
            ids = await worker.links.run(url)
            if not any(ids):
                return False, "DouK 未能从链接提取作品 ID。"

            root, params, logger = worker.record.run(app.parameter, blank=True)
            async with logger(root, console=worker.console, **params) as record:
                await worker._handle_detail(ids, False, record)
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
        Path.home() / "Downloads" / "SYDownload"
    )
    output = Path(output_raw).expanduser()
    output.mkdir(parents=True, exist_ok=True)

    name = ENGINE_NAMES[platform]
    path_key = "work_path" if platform == "xiaohongshu" else "root"
    update_engine_settings(name, engine, {path_key: str(output)})

    try:
        if platform == "xiaohongshu":
            ok, log = run_xhs(engine, url, output)
        else:
            ok, log = asyncio.run(run_douk_in_process(engine, url, output))
        capture_engine_settings(name, engine)
        return response(
            req.get("id"),
            ok,
            platform,
            "下载调用完成。" if ok else "下载引擎返回失败。",
            engine=engine,
            settings=stable_settings_path(name),
            output=output,
            log=log,
        )
    except Exception as exc:
        capture_engine_settings(name, engine)
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
    if command == "settings_get":
        return settings_get(req)
    if command == "settings_update":
        return settings_update(req)
    if command == "settings_reset":
        return settings_reset(req)
    if command == "settings_path":
        return settings_path(req)
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
