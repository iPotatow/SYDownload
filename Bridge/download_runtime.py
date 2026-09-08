from __future__ import annotations

import asyncio
import json
import os
from pathlib import Path
import re
import select
import signal
import subprocess
import threading
import time
from typing import Any, Iterable

ARTIFACT_EXTENSIONS = {
    ".mp4", ".mov", ".m4v", ".webm",
    ".jpg", ".jpeg", ".png", ".webp", ".heic", ".gif",
    ".mp3", ".m4a", ".aac", ".wav", ".flac",
    ".txt", ".md", ".json", ".csv", ".xlsx", ".sqlite", ".db",
}
_PERCENT_RE = re.compile(r"(?<!\\d)(100|[1-9]?\\d)(?:\\.\\d+)?%")
_PRINT_LOCK = threading.Lock()
_ACTIVE_LOCK = threading.Lock()
_ACTIVE_PROCESS: subprocess.Popen[str] | None = None


def snapshot_artifacts(root: Path) -> dict[str, int]:
    result: dict[str, int] = {}
    if not root.exists():
        return result
    try:
        paths = root.rglob("*")
        for path in paths:
            try:
                if not path.is_file() or path.suffix.lower() not in ARTIFACT_EXTENSIONS:
                    continue
                size = path.stat().st_size
                if size > 0:
                    result[str(path)] = size
            except OSError:
                continue
    except OSError:
        return result
    return result


def changed_artifacts(before: dict[str, int], after: dict[str, int]) -> tuple[list[str], int]:
    changed: list[str] = []
    written = 0
    for path, size in after.items():
        previous = before.get(path, 0)
        if size > previous:
            changed.append(path)
            written += size - previous
    return changed, written


def flatten_identifiers(value: Any) -> list[str]:
    result: list[str] = []

    def visit(item: Any) -> None:
        if item is None:
            return
        if isinstance(item, dict):
            for child in item.values():
                visit(child)
            return
        if isinstance(item, (list, tuple, set)):
            for child in item:
                visit(child)
            return
        text = str(item).strip()
        if text:
            result.append(text)

    visit(value)
    return result


def verify_output(
    before: dict[str, int],
    output: Path,
    *,
    log: str = "",
    identifiers: Iterable[str] = (),
) -> tuple[bool, str, dict[str, Any]]:
    after = snapshot_artifacts(output)
    changed, written = changed_artifacts(before, after)
    if changed:
        return (
            True,
            f"已验证 {len(changed)} 个新增或更新文件。",
            {
                "verification": "written",
                "verified_files": len(changed),
                "verified_bytes": written,
            },
        )

    normalized = log.lower()
    existing_markers = (
        "已下载", "已经下载", "跳过", "重复", "已存在",
        "already downloaded", "already exists", "skip", "download record",
    )
    if any(marker in normalized for marker in existing_markers):
        return (
            True,
            "引擎确认文件已存在，未重复写入。",
            {"verification": "existing", "verified_files": 0, "verified_bytes": 0},
        )

    identifier_list = [item for item in identifiers if item]
    if identifier_list:
        for path, size in after.items():
            if size <= 0:
                continue
            lowered = path.lower()
            if any(identifier.lower() in lowered for identifier in identifier_list):
                return (
                    True,
                    "已找到与作品标识匹配的现有文件。",
                    {"verification": "existing", "verified_files": 1, "verified_bytes": 0},
                )

    return (
        False,
        "下载引擎结束，但未检测到新增、更新或可确认的现有下载文件。",
        {"verification": "missing", "verified_files": 0, "verified_bytes": 0},
    )


def classify_error(text: str) -> str:
    value = (text or "").lower()
    if any(term in value for term in ("cancel", "取消", "terminated", "signal 15")):
        return "cancelled"
    if any(term in value for term in ("timeout", "timed out", "超时")):
        return "timeout"
    if any(term in value for term in ("no space", "disk full", "permission denied", "只读", "空间不足", "磁盘")):
        return "disk"
    if any(term in value for term in ("429", "too many requests", "rate limit", "频繁", "风控", "risk control")):
        return "rate_limited"
    if any(term in value for term in ("cookie", "login", "unauthorized", "forbidden", "401", "403", "登录", "凭证")):
        return "auth"
    if any(term in value for term in ("404", "not found", "不存在", "已删除", "private")):
        return "not_found"
    if any(term in value for term in (
        "network", "connection", "connecterror", "connectionerror", "dns",
        "ssl", "httpx", "curl", "proxy", "网络", "连接失败",
    )):
        return "network"
    if any(term in value for term in ("未检测到新增", "verification", "校验")):
        return "verification"
    return "engine"


def emit_progress(payload: dict[str, Any]) -> None:
    with _PRINT_LOCK:
        print(json.dumps(payload, ensure_ascii=False), flush=True)


class ProgressReporter:
    def __init__(self, request_id: str | None, output: Path, baseline: dict[str, int] | None = None):
        self.request_id = request_id
        self.output = output
        self.baseline = baseline if baseline is not None else snapshot_artifacts(output)
        self.last_written = -1
        self.last_files = -1
        self.last_progress: float | None = None
        self.last_emit = 0.0

    def _measurement(self) -> tuple[int, int]:
        current = snapshot_artifacts(self.output)
        changed, written = changed_artifacts(self.baseline, current)
        return len(changed), written

    def emit(self, message: str, progress: float | None = None, *, force: bool = False) -> None:
        files, written = self._measurement()
        now = time.monotonic()
        normalized_progress = None if progress is None else max(0.0, min(float(progress), 1.0))
        unchanged = (
            files == self.last_files
            and written == self.last_written
            and normalized_progress == self.last_progress
        )
        if not force and unchanged and now - self.last_emit < 1.0:
            return
        payload: dict[str, Any] = {
            "id": self.request_id,
            "event": "progress",
            "message": message,
            "bytesWritten": written,
            "fileCount": files,
        }
        if normalized_progress is not None:
            payload["progress"] = normalized_progress
        emit_progress(payload)
        self.last_files = files
        self.last_written = written
        self.last_progress = normalized_progress
        self.last_emit = now

    def poll(self, message: str = "正在写入下载文件…") -> None:
        files, written = self._measurement()
        if files != self.last_files or written != self.last_written:
            self.emit(message, self.last_progress, force=True)

    def observe_text(self, text: str) -> None:
        matches = list(_PERCENT_RE.finditer(text))
        if matches:
            try:
                percent = float(matches[-1].group(0).rstrip("%")) / 100.0
            except ValueError:
                percent = None
            if percent is not None:
                self.emit("正在下载…", min(percent, 0.99), force=True)


async def monitor_progress(reporter: ProgressReporter, interval: float = 0.75) -> None:
    while True:
        await asyncio.sleep(interval)
        reporter.poll()


def _set_active_process(process: subprocess.Popen[str] | None) -> None:
    global _ACTIVE_PROCESS
    with _ACTIVE_LOCK:
        _ACTIVE_PROCESS = process


def terminate_process_tree(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except (OSError, ProcessLookupError):
        try:
            process.terminate()
        except OSError:
            return
    deadline = time.monotonic() + 1.5
    while process.poll() is None and time.monotonic() < deadline:
        time.sleep(0.05)
    if process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except (OSError, ProcessLookupError):
            try:
                process.kill()
            except OSError:
                pass


def _termination_handler(signum: int, _frame: Any) -> None:
    with _ACTIVE_LOCK:
        process = _ACTIVE_PROCESS
    if process is not None:
        terminate_process_tree(process)
    raise SystemExit(128 + signum)


def install_signal_handlers() -> None:
    for sig in (signal.SIGTERM, signal.SIGINT):
        try:
            signal.signal(sig, _termination_handler)
        except (ValueError, OSError):
            pass


def run_streaming_subprocess(
    cmd: list[str],
    *,
    cwd: Path,
    env: dict[str, str],
    reporter: ProgressReporter,
    timeout_seconds: float,
) -> tuple[int, str, bool]:
    process = subprocess.Popen(
        cmd,
        cwd=cwd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        start_new_session=True,
    )
    _set_active_process(process)
    started = time.monotonic()
    log_lines: list[str] = []
    timed_out = False
    try:
        assert process.stdout is not None
        while True:
            if timeout_seconds > 0 and time.monotonic() - started >= timeout_seconds:
                timed_out = True
                terminate_process_tree(process)
                break

            ready, _, _ = select.select([process.stdout], [], [], 0.25)
            if ready:
                line = process.stdout.readline()
                if line:
                    log_lines.append(line)
                    reporter.observe_text(line)
            reporter.poll()

            if process.poll() is not None:
                remainder = process.stdout.read()
                if remainder:
                    log_lines.append(remainder)
                    for line in remainder.splitlines():
                        reporter.observe_text(line)
                break

        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            terminate_process_tree(process)
            process.wait(timeout=2)
    finally:
        _set_active_process(None)

    return process.returncode if process.returncode is not None else -1, "".join(log_lines).strip(), timed_out


install_signal_handlers()
