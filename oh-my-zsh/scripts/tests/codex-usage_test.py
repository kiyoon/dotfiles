#!/usr/bin/env python3
"""Offline tests for scripts/codex-usage.py: formatting, home discovery, expiry handling."""
import base64
import importlib.util
import json
import os
import pathlib
import sys
import tempfile
import time
import unittest
from unittest import mock

sys.dont_write_bytecode = True  # keep __pycache__ out of the scripts dir
SCRIPT = pathlib.Path(__file__).resolve().parent.parent / "codex-usage.py"
spec = importlib.util.spec_from_file_location("codex_usage", SCRIPT)
cu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cu)


def fake_jwt(**claims):
    body = base64.urlsafe_b64encode(json.dumps(claims).encode()).rstrip(b"=").decode()
    return f"eyJhbGciOiJub25lIn0.{body}.sig"


def write_auth(home, exp, email="a@b.c", account_id="acct-1"):
    os.makedirs(home, exist_ok=True)
    tokens = {"access_token": fake_jwt(exp=exp), "id_token": fake_jwt(email=email),
              "refresh_token": "r", "account_id": account_id}
    with open(os.path.join(home, "auth.json"), "w") as f:
        json.dump({"tokens": tokens, "last_refresh": "2026-09-05T03:49:21Z"}, f)


def window(pct, seconds, reset_in):
    return {"used_percent": pct, "limit_window_seconds": seconds,
            "reset_after_seconds": reset_in, "reset_at": int(time.time()) + reset_in}


class FormattingTests(unittest.TestCase):
    def test_window_label(self):
        self.assertEqual(cu.window_label(18000), "5h")
        self.assertEqual(cu.window_label(604800), "weekly")
        self.assertEqual(cu.window_label(172800), "2d")

    def test_countdown(self):
        now = time.time()
        self.assertEqual(cu.countdown(now - 5), "now")
        self.assertEqual(cu.countdown(now + 20 * 60 + 5), "20m")
        self.assertEqual(cu.countdown(now + 3 * 3600 + 5), "3h")
        self.assertEqual(cu.countdown(now + 3 * 3600 + 15 * 60 + 5), "3h 15m")
        self.assertEqual(cu.countdown(now + 2 * 86400 + 4 * 3600 + 5), "2d 4h")

    def test_bar(self):
        self.assertEqual(cu.bar(0), "[" + "░" * 20 + "]")
        self.assertEqual(cu.bar(50), "[" + "█" * 10 + "░" * 10 + "]")
        self.assertEqual(cu.bar(100), "[" + "█" * 20 + "]")

    def test_windows_includes_spark(self):
        data = {
            "rate_limit": {"primary_window": window(51, 604800, 100), "secondary_window": None},
            "additional_rate_limits": [{
                "limit_name": "GPT-5.3-Codex-Spark",
                "rate_limit": {"primary_window": window(0, 18000, 50),
                               "secondary_window": window(0, 604800, 60)},
            }],
        }
        self.assertEqual([label for label, _ in cu.windows(data)],
                         ["weekly", "spark 5h", "spark weekly"])

    def test_render_ok_and_error(self):
        ok = {"home": "/h/.codex", "email": "me@x.y", "data": {
            "email": "me@x.y", "plan_type": "team",
            "rate_limit": {"limit_reached": True,
                           "primary_window": window(100, 18000, 1230),  # 20.5 min: safe from truncation
                           "secondary_window": window(40, 604800, 3600 * 30)},
            "rate_limit_reached_type": {"type": "workspace_member_credits_depleted"},
            "rate_limit_reset_credits": {"available_count": 3},
        }}
        bad = {"home": "/h/.codex-old", "email": "old@x.y", "error": "access token expired"}
        out = cu.render([ok, bad], current="/h/.codex")
        self.assertIn("→ codex", out)
        self.assertIn("LIMIT REACHED (workspace member credits depleted)", out)
        self.assertIn("100% used  resets in 20m", out)
        self.assertIn("reset credits: 3 available", out)
        self.assertIn("codex-old  old@x.y  [error] access token expired", out)


class HomeAndAuthTests(unittest.TestCase):
    def test_default_homes_discovers_codex_dash_dirs_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            write_auth(os.path.join(tmp, ".codex"), exp=time.time() + 3600)
            write_auth(os.path.join(tmp, ".codex-work"), exp=time.time() + 3600)
            os.makedirs(os.path.join(tmp, ".codexbar"))  # not a Codex home
            os.makedirs(os.path.join(tmp, ".codex-empty"))  # no auth.json
            with mock.patch.dict(os.environ, {"HOME": tmp}, clear=False):
                os.environ.pop("CODEX_HOMES", None)
                self.assertEqual(cu.default_homes(),
                                 [os.path.join(tmp, ".codex"), os.path.join(tmp, ".codex-work")])
                os.environ["CODEX_HOMES"] = os.path.join(tmp, ".codex-work")
                self.assertEqual(cu.default_homes(), [os.path.join(tmp, ".codex-work")])

    def test_expired_token_is_reported_without_network(self):
        with tempfile.TemporaryDirectory() as tmp:
            write_auth(tmp, exp=time.time() - 60)
            with mock.patch.object(cu.urllib.request, "urlopen", side_effect=AssertionError("no network")):
                r = cu.fetch(tmp, timeout=1)
        self.assertEqual(r["email"], "a@b.c")
        self.assertIn("access token expired (last refresh 2026-09-05)", r["error"])

    def test_missing_auth_is_reported(self):
        r = cu.fetch("/nonexistent/home", timeout=1)
        self.assertIn("cannot read auth.json", r["error"])


if __name__ == "__main__":
    unittest.main()
