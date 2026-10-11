import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "engine_bridge.py"
RUNTIME = ROOT / "download_runtime.py"

spec = importlib.util.spec_from_file_location("engine_bridge", BRIDGE)
mod = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(mod)

runtime_spec = importlib.util.spec_from_file_location("download_runtime_test", RUNTIME)
runtime = importlib.util.module_from_spec(runtime_spec)
assert runtime_spec.loader
runtime_spec.loader.exec_module(runtime)


class BridgeTests(unittest.TestCase):
    def test_other_output_folder_cannot_verify_this_task(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            selected = root / "selected"
            selected.mkdir()

            def unrelated_write(*args, **kwargs):
                (root / "another-task.jpg").write_bytes(b"other task output")
                return 0, "", False

            with patch.object(mod, "run_streaming_subprocess", side_effect=unrelated_write):
                ok, _, kind, details = mod.run_xhs(
                    root, "https://xhslink.com/demo", root, None, 10,
                    verification_root=selected,
                )
            self.assertFalse(ok)
            self.assertEqual(kind, "verification")
            self.assertEqual(details["verified_files"], 0)

    def test_engine_lock_excludes_other_process_and_releases_on_cancel(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            env = {**os.environ, "SYDOWNLOAD_APP_SUPPORT": temp}
            prefix = f"import sys,time; from pathlib import Path; sys.path.insert(0,{str(ROOT)!r}); from engine_bridge import engine_state_lock\n"
            first_code = prefix + f"with engine_state_lock():\n Path({str(root / 'first')!r}).touch()\n time.sleep(60)\n"
            second_code = prefix + f"with engine_state_lock('queued-task'):\n Path({str(root / 'second')!r}).touch()\n"
            first = subprocess.Popen([sys.executable, "-c", first_code], env=env)
            second = None
            try:
                deadline = time.monotonic() + 5
                while not (root / "first").exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue((root / "first").exists())
                with patch.dict(os.environ, {"SYDOWNLOAD_APP_SUPPORT": temp}):
                    busy = mod.handle({"command": "settings_get", "engine": "xiaohongshu"})
                self.assertFalse(busy["ok"])
                self.assertEqual(busy["details"]["error_kind"], "busy")
                second = subprocess.Popen([sys.executable, "-c", second_code], env=env, stdout=subprocess.PIPE, text=True)
                time.sleep(0.2)
                self.assertIsNone(second.poll())
                self.assertFalse((root / "second").exists())
                first.terminate()
                first.wait(timeout=5)
                output, _ = second.communicate(timeout=5)
                self.assertEqual(second.returncode, 0)
                self.assertEqual([json.loads(line)["phase"] for line in output.splitlines()], ["waiting", "running"])
                self.assertTrue((root / "second").exists())
            finally:
                for process in (first, second):
                    if process is not None and process.poll() is None:
                        process.kill()
                        process.wait(timeout=5)

    def test_detector(self):
        self.assertEqual(mod.detect_platform("https://xhslink.com/a"), "xiaohongshu")
        self.assertEqual(mod.detect_platform("https://v.douyin.com/a"), "douyin")
        self.assertEqual(mod.detect_platform("https://www.tiktok.com/@a/video/1"), "unknown")
        self.assertEqual(mod.detect_platform("https://example.com"), "unknown")

    def test_ping_protocol(self):
        req = {"id": "00000000-0000-0000-0000-000000000001", "command": "ping"}
        proc = subprocess.run(
            [sys.executable, str(BRIDGE), "--once"],
            input=json.dumps(req) + "\n",
            text=True,
            capture_output=True,
            check=True,
        )
        data = json.loads(proc.stdout.strip())
        self.assertTrue(data["ok"])
        self.assertEqual(data["message"], "pong")

    def test_validate_without_engine_is_graceful(self):
        req = {
            "id": "00000000-0000-0000-0000-000000000002",
            "command": "validate",
            "url": "https://v.douyin.com/demo",
        }
        data = mod.handle(req)
        self.assertFalse(data["ok"])
        self.assertEqual(data["platform"], "douyin")
        self.assertIn("引擎", data["message"])

    def test_failure_classification(self):
        self.assertEqual(runtime.classify_error("HTTP 403 cookie invalid"), "auth")
        self.assertEqual(runtime.classify_error("429 too many requests"), "rate_limited")
        self.assertEqual(runtime.classify_error("connection reset by peer"), "network")
        self.assertEqual(runtime.classify_error("task timed out"), "timeout")
        self.assertEqual(runtime.classify_error("No space left on device"), "disk")

    def test_progress_reporter_parses_upstream_percentage(self):
        with tempfile.TemporaryDirectory() as temp:
            reporter = runtime.ProgressReporter("progress-test", Path(temp), {})
            reporter.observe_text("Downloading media 42.5%")
            self.assertAlmostEqual(reporter.last_progress, 0.425)

    def test_output_verification_detects_real_file_write(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            before = runtime.snapshot_artifacts(root)
            target = root / "download.mp4"
            target.write_bytes(b"real-media-bytes")
            ok, message, details = runtime.verify_output(before, root)
            self.assertTrue(ok, message)
            self.assertEqual(details["verification"], "written")
            self.assertEqual(details["verified_files"], 1)
            self.assertGreater(details["verified_bytes"], 0)

    def test_output_verification_rejects_false_success(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            before = runtime.snapshot_artifacts(root)
            ok, _, details = runtime.verify_output(before, root)
            self.assertFalse(ok)
            self.assertEqual(details["verification"], "missing")

    def test_output_verification_distinguishes_skip_reasons(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            before = runtime.snapshot_artifacts(root)

            ok, _, details = runtime.verify_output(
                before,
                root,
                log="作品 123 存在下载记录，跳过处理",
            )
            self.assertTrue(ok)
            self.assertEqual(details["verification"], "skipped_record")

            ok, _, details = runtime.verify_output(
                before,
                root,
                log="demo.mp4 文件已存在，跳过下载",
            )
            self.assertTrue(ok)
            self.assertEqual(details["verification"], "existing")

            ok, _, details = runtime.verify_output(
                before,
                root,
                log="视频作品下载功能已关闭，跳过下载",
            )
            self.assertFalse(ok)
            self.assertEqual(details["verification"], "disabled")

    def test_subprocess_timeout_terminates_work(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            reporter = runtime.ProgressReporter("timeout-test", root, {})
            code, _, timed_out = runtime.run_streaming_subprocess(
                [sys.executable, "-c", "import time; time.sleep(5)"],
                cwd=root,
                env=os.environ.copy(),
                reporter=reporter,
                timeout_seconds=0.2,
            )
            self.assertTrue(timed_out)
            self.assertNotEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
