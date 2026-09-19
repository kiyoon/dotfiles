#!/usr/bin/env python3
"""Offline tests for scripts/agent-usage.py: formatting, dir discovery, credential and expiry handling."""
import base64
import hashlib
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
SCRIPT = pathlib.Path(__file__).resolve().parent.parent / "agent-usage.py"
spec = importlib.util.spec_from_file_location("agent_usage", SCRIPT)
au = importlib.util.module_from_spec(spec)
spec.loader.exec_module(au)


def fake_jwt(**claims):
    body = base64.urlsafe_b64encode(json.dumps(claims).encode()).rstrip(b"=").decode()
    return f"eyJhbGciOiJub25lIn0.{body}.sig"


def write_codex_auth(home, exp, email="a@b.c", account_id="acct-1"):
    os.makedirs(home, exist_ok=True)
    tokens = {"access_token": fake_jwt(exp=exp), "id_token": fake_jwt(email=email),
              "refresh_token": "r", "account_id": account_id}
    with open(os.path.join(home, "auth.json"), "w") as f:
        json.dump({"tokens": tokens, "last_refresh": "2026-09-05T03:49:21Z"}, f)


def write_claude_store(config_dir, exp_ms, plan="max", tier="default_claude_max_20x"):
    os.makedirs(config_dir, exist_ok=True)
    store = {"claudeAiOauth": {"accessToken": "sk-ant-oat01-x", "refreshToken": "r", "expiresAt": exp_ms,
                               "scopes": ["user:profile", "user:inference"],
                               "subscriptionType": plan, "rateLimitTier": tier}}
    with open(os.path.join(config_dir, ".credentials.json"), "w") as f:
        json.dump(store, f)


def codex_window(pct, seconds, reset_in):
    return {"used_percent": pct, "limit_window_seconds": seconds,
            "reset_after_seconds": reset_in, "reset_at": int(time.time()) + reset_in}


def iso_in(seconds):
    return (au.datetime.datetime.now(au.datetime.timezone.utc)
            + au.datetime.timedelta(seconds=seconds)).isoformat()


def claude_bucket(pct, resets_at):
    return {"utilization": pct, "resets_at": resets_at, "limit_dollars": None,
            "used_dollars": None, "remaining_dollars": None, "locked_reason": None}


def claude_response():
    """Shape of GET /api/oauth/usage as of 2026-09 (trimmed), with a model-scoped weekly
    limit that /usage does not draw and a codenamed bucket."""
    session_reset, week_reset = iso_in(4 * 3600 + 90), iso_in(4 * 86400 + 4 * 3600 + 90)
    return {
        "five_hour": claude_bucket(5.0, session_reset),
        "seven_day": claude_bucket(40.0, week_reset),
        "seven_day_oauth_apps": None, "seven_day_opus": None, "seven_day_sonnet": None,
        "nimbus_quill": claude_bucket(0.0, None),
        "extra_usage": {"is_enabled": False, "monthly_limit": None, "used_credits": None,
                        "utilization": None, "user_disabled": True, "spend_limit_reached": False},
        "limits": [
            {"kind": "session", "group": "session", "percent": 5, "severity": "normal",
             "resets_at": session_reset, "scope": None, "is_active": False},
            {"kind": "weekly_all", "group": "weekly", "percent": 40, "severity": "normal",
             "resets_at": week_reset, "scope": None, "is_active": False},
            {"kind": "weekly_scoped", "group": "weekly", "percent": 60, "severity": "normal",
             "resets_at": week_reset, "scope": {"model": {"id": None, "display_name": "Fable"},
                                                "surface": None}, "is_active": True},
        ],
        "spend": {"used": {"amount_minor": 0, "currency": "USD", "exponent": 2}, "limit": None,
                  "percent": 0, "enabled": False, "balance": None},
        "seven_day_breakdown": {"rows": [{"key": "claude_code", "display_name": "Claude Code", "percent": 100},
                                         {"key": "chat", "display_name": "Chats", "percent": 0}]},
    }


class FormattingTests(unittest.TestCase):
    def test_window_label(self):
        self.assertEqual(au.window_label(18000), "5h")
        self.assertEqual(au.window_label(604800), "weekly")
        self.assertEqual(au.window_label(172800), "2d")

    def test_countdown(self):
        now = time.time()
        self.assertEqual(au.countdown(now - 5), "now")
        self.assertEqual(au.countdown(now + 20 * 60 + 5), "20m")
        self.assertEqual(au.countdown(now + 3 * 3600 + 5), "3h")
        self.assertEqual(au.countdown(now + 3 * 3600 + 15 * 60 + 5), "3h 15m")
        self.assertEqual(au.countdown(now + 2 * 86400 + 4 * 3600 + 5), "2d 4h")

    def test_bar(self):
        self.assertEqual(au.bar(0), "[" + "░" * 20 + "]")
        self.assertEqual(au.bar(50), "[" + "█" * 10 + "░" * 10 + "]")
        self.assertEqual(au.bar(100), "[" + "█" * 20 + "]")

    def test_iso_epoch_and_money(self):
        self.assertAlmostEqual(au.iso_epoch("1970-01-01T00:00:10+00:00"), 10.0)
        self.assertAlmostEqual(au.iso_epoch("1970-01-01T00:00:10Z"), 10.0)
        self.assertIsNone(au.iso_epoch(None))
        self.assertIsNone(au.iso_epoch("soon"))
        self.assertEqual(au.money({"amount_minor": 1234, "currency": "USD", "exponent": 2}), "$12.34")
        self.assertEqual(au.money({"amount_minor": 500, "currency": "EUR", "exponent": 2}), "5.00 EUR")


class CodexTests(unittest.TestCase):
    def test_windows_includes_spark(self):
        data = {
            "rate_limit": {"primary_window": codex_window(51, 604800, 100), "secondary_window": None},
            "additional_rate_limits": [{
                "limit_name": "GPT-5.3-Codex-Spark",
                "rate_limit": {"primary_window": codex_window(0, 18000, 50),
                               "secondary_window": codex_window(0, 604800, 60)},
            }],
        }
        self.assertEqual([label for label, _ in au.windows(data)],
                         ["weekly", "spark 5h", "spark weekly"])

    def test_render_ok_and_error(self):
        ok = {"provider": "codex", "home": "/h/.codex", "email": "me@x.y", "data": {
            "email": "me@x.y", "plan_type": "team",
            "rate_limit": {"limit_reached": True,
                           "primary_window": codex_window(100, 18000, 1230),  # 20.5 min: safe from truncation
                           "secondary_window": codex_window(40, 604800, 3600 * 30)},
            "rate_limit_reached_type": {"type": "workspace_member_credits_depleted"},
            "rate_limit_reset_credits": {"available_count": 3},
        }}
        bad = {"provider": "codex", "home": "/h/.codex-old", "email": "old@x.y", "error": "access token expired"}
        out = au.render([ok, bad], current={"/h/.codex"})
        self.assertIn("→ codex", out)
        self.assertIn("LIMIT REACHED (workspace member credits depleted)", out)
        self.assertIn("100% used  resets in 20m", out)
        self.assertIn("reset credits: 3 available", out)
        self.assertIn("codex-old  old@x.y  [error] access token expired", out)

    def test_codex_homes_discovers_codex_dash_dirs_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            write_codex_auth(os.path.join(tmp, ".codex"), exp=time.time() + 3600)
            write_codex_auth(os.path.join(tmp, ".codex-work"), exp=time.time() + 3600)
            os.makedirs(os.path.join(tmp, ".codexbar"))  # not a Codex home
            os.makedirs(os.path.join(tmp, ".codex-empty"))  # no auth.json
            with mock.patch.dict(os.environ, {"HOME": tmp}, clear=False):
                os.environ.pop("CODEX_HOMES", None)
                self.assertEqual(au.codex_homes(),
                                 [os.path.join(tmp, ".codex"), os.path.join(tmp, ".codex-work")])
                os.environ["CODEX_HOMES"] = os.path.join(tmp, ".codex-work")
                self.assertEqual(au.codex_homes(), [os.path.join(tmp, ".codex-work")])

    def test_expired_token_is_reported_without_network(self):
        with tempfile.TemporaryDirectory() as tmp:
            write_codex_auth(tmp, exp=time.time() - 60)
            with mock.patch.object(au.urllib.request, "urlopen", side_effect=AssertionError("no network")):
                r = au.fetch("codex", tmp, timeout=1)
        self.assertEqual(r["email"], "a@b.c")
        self.assertIn("access token expired (last refresh 2026-09-05)", r["error"])

    def test_missing_auth_is_reported(self):
        r = au.fetch_codex("/nonexistent/home", timeout=1)
        self.assertIn("cannot read auth.json", r["error"])


class ClaudeTests(unittest.TestCase):
    def test_keychain_service_names_match_claude_code(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {"HOME": tmp}):
            default = os.path.join(tmp, ".claude")
            custom = os.path.join(tmp, ".claude-work")
            digest = hashlib.sha256(custom.encode()).hexdigest()[:8]
            self.assertEqual(au.claude_keychain_services(custom), [f"Claude Code-credentials-{digest}"])
            # default dir: plain name first, hashed one if CLAUDE_CONFIG_DIR was set to it explicitly
            self.assertEqual(au.claude_keychain_services(default)[0], "Claude Code-credentials")
            self.assertEqual(len(au.claude_keychain_services(default)), 2)

    def test_claude_dirs_discovery(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {"HOME": tmp}), \
                mock.patch.object(au, "read_keychain", return_value=None):
            os.environ.pop("CLAUDE_CONFIG_DIRS", None)
            os.makedirs(os.path.join(tmp, ".claude"))  # listed even without credentials (error is shown)
            write_claude_store(os.path.join(tmp, ".claude-work"), exp_ms=(time.time() + 3600) * 1000)
            os.makedirs(os.path.join(tmp, ".claude-plugins"))  # no credentials: not an account
            with open(os.path.join(tmp, ".claude-notes"), "w") as f:
                f.write("x")  # a file, not a dir
            self.assertEqual(au.claude_dirs(), [os.path.join(tmp, ".claude"), os.path.join(tmp, ".claude-work")])
            os.environ["CLAUDE_CONFIG_DIRS"] = os.path.join(tmp, ".claude-plugins")
            self.assertEqual(au.claude_dirs(), [os.path.join(tmp, ".claude-plugins")])

    def test_keychain_is_preferred_over_file(self):
        store = {"claudeAiOauth": {"accessToken": "from-keychain", "expiresAt": (time.time() + 60) * 1000}}
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {"HOME": tmp}), \
                mock.patch.object(au, "read_keychain", return_value=json.dumps(store)) as rk:
            d = os.path.join(tmp, ".claude")
            write_claude_store(d, exp_ms=0)
            self.assertEqual(au.load_claude_auth(d)["access"], "from-keychain")
            rk.assert_called_once_with("Claude Code-credentials")

    def test_plan_and_email_come_from_stored_credentials_and_claude_json(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {"HOME": tmp}), \
                mock.patch.object(au, "read_keychain", return_value=None):
            d = os.path.join(tmp, ".claude")
            write_claude_store(d, exp_ms=(time.time() + 3600) * 1000)
            with open(os.path.join(tmp, ".claude.json"), "w") as f:
                json.dump({"oauthAccount": {"emailAddress": "me@x.y"}}, f)
            auth = au.load_claude_auth(d)
            self.assertEqual((auth["email"], auth["plan"]), ("me@x.y", "max 20x"))
            # custom dir keeps its own .claude.json
            custom = os.path.join(tmp, ".claude-work")
            write_claude_store(custom, exp_ms=(time.time() + 3600) * 1000, plan="pro", tier="default_claude_pro")
            with open(os.path.join(custom, ".claude.json"), "w") as f:
                json.dump({"oauthAccount": {"emailAddress": "work@x.y"}}, f)
            auth = au.load_claude_auth(custom)
            self.assertEqual((auth["email"], auth["plan"]), ("work@x.y", "pro"))

    def test_expired_token_is_reported_without_network(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {"HOME": tmp}), \
                mock.patch.object(au, "read_keychain", return_value=None), \
                mock.patch.object(au.urllib.request, "urlopen", side_effect=AssertionError("no network")):
            d = os.path.join(tmp, ".claude")
            write_claude_store(d, exp_ms=(time.time() - 60) * 1000)
            r = au.fetch("claude", d, timeout=1)
        self.assertEqual(r["plan"], "max 20x")
        self.assertIn("access token expired", r["error"])

    def test_missing_credentials_are_reported(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(au, "read_keychain", return_value=None):
            r = au.fetch_claude(tmp, timeout=1)
        self.assertIn("no Claude Code credentials", r["error"])

    def test_request_headers(self):
        captured = {}

        def fake_urlopen(req, timeout):
            captured.update(req.headers)
            raise AssertionError("stop")

        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {"HOME": tmp}), \
                mock.patch.object(au, "read_keychain", return_value=None), \
                mock.patch.object(au.urllib.request, "urlopen", fake_urlopen):
            d = os.path.join(tmp, ".claude")
            write_claude_store(d, exp_ms=(time.time() + 3600) * 1000)
            au.fetch_claude(d, timeout=1)
        self.assertEqual(captured["Authorization"], "Bearer sk-ant-oat01-x")
        self.assertEqual(captured["Anthropic-beta"], "oauth-2025-04-20")

    def test_rows_show_every_limit_once(self):
        rows = au.claude_rows(claude_response())
        self.assertEqual([(label, pct, note) for label, pct, _, note in rows],
                         [("session", 5, ""), ("weekly", 40, ""), ("weekly (Fable)", 60, "active"),
                          ("nimbus_quill", 0, "")])
        self.assertIsNone(rows[3][2])  # no reset for that bucket
        self.assertEqual(au.claude_extras(claude_response()),
                         ["extra usage: off (user disabled)", "weekly by product: Claude Code 100%"])

    def test_rows_fall_back_to_buckets_without_limits_list(self):
        d = {"five_hour": claude_bucket(12.0, iso_in(600)), "seven_day": claude_bucket(50.0, iso_in(86400)),
             "seven_day_sonnet": claude_bucket(70.0, iso_in(86400)), "seven_day_opus": None,
             "extra_usage": {"is_enabled": True, "monthly_limit": 5000, "used_credits": 1234, "utilization": 24.7}}
        rows = au.claude_rows(d)
        self.assertEqual([(label, pct) for label, pct, _, _ in rows],
                         [("session", 12), ("weekly", 50), ("weekly (Sonnet)", 70)])
        self.assertEqual(au.claude_extras(d), ["extra usage: $12.34 / $50.00 spent (25%)"])

    def test_render_claude(self):
        ok = {"provider": "claude", "home": "/h/.claude", "email": "me@x.y", "plan": "max 20x",
              "data": claude_response()}
        out = au.render([ok], current={"/h/.claude"})
        self.assertIn("→ claude  me@x.y  (max 20x)", out)
        self.assertIn("weekly (Fable)  [████████████░░░░░░░░]  60% used  resets in 4d 4h  active", out)
        self.assertIn("nimbus_quill    [░░░░░░░░░░░░░░░░░░░░]   0% used\n", out)
        self.assertNotIn("LIMIT REACHED", out)
        maxed = claude_response()
        maxed["limits"][0]["percent"] = 100
        out = au.render([{**ok, "data": maxed}], current=set())
        self.assertIn("(max 20x)  LIMIT REACHED (session)", out)


class TargetTests(unittest.TestCase):
    def test_positional_dirs_are_classified_by_auth_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            codex = os.path.join(tmp, "codex-home")
            write_codex_auth(codex, exp=time.time() + 3600)
            claude = os.path.join(tmp, "claude-dir")
            os.makedirs(claude)
            self.assertEqual(au.targets([codex, claude], True, True), [("codex", codex), ("claude", claude)])
            self.assertEqual(au.targets([codex, claude], True, False), [("claude", claude)])
            self.assertEqual(au.targets([codex, claude], False, True), [("codex", codex)])

    def test_default_targets_list_claude_then_codex(self):
        with mock.patch.object(au, "claude_dirs", return_value=["/h/.claude"]), \
                mock.patch.object(au, "codex_homes", return_value=["/h/.codex", "/h/.codex-x"]):
            self.assertEqual(au.targets([], True, True),
                             [("claude", "/h/.claude"), ("codex", "/h/.codex"), ("codex", "/h/.codex-x")])
            self.assertEqual(au.targets([], False, True), [("codex", "/h/.codex"), ("codex", "/h/.codex-x")])


if __name__ == "__main__":
    unittest.main()
