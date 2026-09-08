import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

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
