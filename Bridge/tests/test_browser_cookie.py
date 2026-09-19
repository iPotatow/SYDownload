import json
import sys
import types
import unittest
from pathlib import Path
from unittest import mock

BRIDGE_DIR = Path(__file__).resolve().parents[1]
if str(BRIDGE_DIR) not in sys.path:
    sys.path.insert(0, str(BRIDGE_DIR))

import engine_bridge


class BrowserCookieTests(unittest.TestCase):
    def test_reads_cookie_and_persists_engine_setting(self):
        fake_rookiepy = types.SimpleNamespace(
            chrome=lambda domains: [
                {"domain": ".xiaohongshu.com", "name": "a1", "value": "token"},
                {"domain": ".xiaohongshu.com", "name": "web_session", "value": "session"},
            ]
        )
        request = {
            "id": "cookie-test",
            "command": "browser_cookie",
            "engine": "xiaohongshu",
            "settingsJSON": json.dumps({"browser": "Chrome"}),
        }

        with mock.patch.object(
            engine_bridge,
            "settings_engine",
            return_value=("xiaohongshu", "XHS-Downloader", Path("/tmp/xhs")),
        ), mock.patch.object(engine_bridge, "update_engine_settings") as update, mock.patch.dict(
            sys.modules,
            {"rookiepy": fake_rookiepy},
        ):
            result = engine_bridge.browser_cookie(request)

        self.assertTrue(result["ok"])
        self.assertEqual(result["platform"], "xiaohongshu")
        self.assertEqual(result["details"]["browser"], "Chrome")
        self.assertEqual(result["details"]["cookie_count"], "2")
        self.assertEqual(
            result["details"]["cookie"],
            "a1=token; web_session=session",
        )
        update.assert_called_once_with(
            "XHS-Downloader",
            Path("/tmp/xhs"),
            {"cookie": "a1=token; web_session=session"},
        )

    def test_rejects_unknown_browser(self):
        request = {
            "id": "cookie-test",
            "command": "browser_cookie",
            "engine": "douyin",
            "settingsJSON": json.dumps({"browser": "UnknownBrowser"}),
        }

        with mock.patch.object(
            engine_bridge,
            "settings_engine",
            return_value=("douyin", "TikTokDownloader", Path("/tmp/douyin")),
        ):
            result = engine_bridge.browser_cookie(request)

        self.assertFalse(result["ok"])
        self.assertEqual(result["platform"], "douyin")
        self.assertIn("不支持的浏览器", result["message"])


if __name__ == "__main__":
    unittest.main()
