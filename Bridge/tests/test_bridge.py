import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "engine_bridge.py"

spec = importlib.util.spec_from_file_location("engine_bridge", BRIDGE)
mod = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(mod)


class BridgeTests(unittest.TestCase):
    def test_detector(self):
        self.assertEqual(mod.detect_platform("https://xhslink.com/a"), "xiaohongshu")
        self.assertEqual(mod.detect_platform("https://v.douyin.com/a"), "douyin")
        self.assertEqual(mod.detect_platform("https://www.tiktok.com/@a/video/1"), "tiktok")
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


if __name__ == "__main__":
    unittest.main()
