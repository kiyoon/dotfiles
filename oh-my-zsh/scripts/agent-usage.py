# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///

"""agent-usage: live rate-limit usage for every Claude Code account and Codex home, straight from the APIs.

Claude: GET https://api.anthropic.com/api/oauth/usage, the call Claude Code's /usage
makes, authenticated with the OAuth token Claude Code already stores in the macOS
keychain ("Claude Code-credentials"; a custom CLAUDE_CONFIG_DIR gets a hashed suffix)
or in <config dir>/.credentials.json. Everything the API returns is printed, not just
the bars /usage draws: the unified `limits` list (session, weekly, model- or
surface-scoped weeklies), any other non-null bucket (including codenamed ones), extra
usage / spend and the weekly breakdown by product.
Config dirs: ~/.claude plus every ~/.claude-* that has credentials. Override with
CLAUDE_CONFIG_DIRS=path:path.

Codex: GET https://chatgpt.com/backend-api/wham/usage, the call `cdx usage`
(bjesuiter/codex-switcher) and Codex's own /status make, authenticated with the
tokens Codex CLI keeps in <home>/auth.json.
Homes: ~/.codex plus every ~/.codex-* that has an auth.json. Override with
CODEX_HOMES=path:path.

Positional directories are Codex homes when they contain auth.json and Claude config
dirs otherwise. The dir a bare `claude` / `codex` would use ($CLAUDE_CONFIG_DIR, else
~/.claude; $CODEX_HOME, else ~/.codex) is marked with an arrow.

Tokens are used as-is and never refreshed here: each CLI owns its refresh token, and
rotating that behind the CLI's back is what forces re-logins. An expired token is
reported as such; starting the CLI in that home refreshes it.
"""
import argparse
import base64
import concurrent.futures
import datetime
import getpass
import glob
import hashlib
import json
import os
import subprocess
import sys
import time
import unicodedata
import urllib.error
import urllib.request

CLAUDE_URL = "https://api.anthropic.com/api/oauth/usage"
CLAUDE_OAUTH_BETA = "oauth-2025-04-20"  # anthropic-beta header Claude Code sends with OAuth tokens
CLAUDE_KEYCHAIN_SERVICE = "Claude Code-credentials"
CODEX_URL = "https://chatgpt.com/backend-api/wham/usage"
USER_AGENT = "agent-usage"
BAR_WIDTH = 20

# How /usage and the API name the top-level Claude buckets.
CLAUDE_BUCKET_LABELS = {
    "five_hour": "session",
    "seven_day": "weekly",
    "seven_day_sonnet": "weekly (Sonnet)",
    "seven_day_opus": "weekly (Opus)",
    "seven_day_oauth_apps": "weekly (OAuth apps)",
    "seven_day_cowork": "weekly (Cowork)",
}
CLAUDE_KIND_LABELS = {"session": "session", "weekly_all": "weekly"}


# ---------------------------------------------------------------------------
# discovery


def _env_paths(name):
    env = os.environ.get(name)
    if not env:
        return None
    return [os.path.expanduser(p) for p in env.split(":") if p]


def codex_homes():
    cands = _env_paths("CODEX_HOMES")
    if cands is None:
        home = os.path.expanduser("~")
        cands = [os.path.join(home, ".codex")] + sorted(glob.glob(os.path.join(home, ".codex-*")))
    return [c for c in cands if os.path.isfile(os.path.join(c, "auth.json"))]


def default_claude_dir():
    return os.path.join(os.path.expanduser("~"), ".claude")


def claude_dirs():
    cands = _env_paths("CLAUDE_CONFIG_DIRS")
    if cands is not None:
        return [c for c in cands if os.path.isdir(c)]
    out = []
    default = default_claude_dir()
    if os.path.isdir(default):
        out.append(default)  # always listed: missing credentials are reported, not hidden
    for cand in sorted(glob.glob(os.path.join(os.path.expanduser("~"), ".claude-*"))):
        if os.path.isdir(cand) and read_claude_store(cand) is not None:
            out.append(cand)
    return out


def current_dirs():
    return {
        os.path.abspath(os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR") or "~/.claude")),
        os.path.abspath(os.path.expanduser(os.environ.get("CODEX_HOME") or "~/.codex")),
    }


def classify(path):
    return "codex" if os.path.isfile(os.path.join(path, "auth.json")) else "claude"


# ---------------------------------------------------------------------------
# Claude credentials (read-only; mirrors Claude Code's secureStorage lookup)


def claude_keychain_services(config_dir):
    """Keychain service names Claude Code may have used for this config dir.

    The default dir (CLAUDE_CONFIG_DIR unset) has no suffix; any explicit
    CLAUDE_CONFIG_DIR gets "-" + first 8 hex chars of sha256(NFC path).
    """
    digest = hashlib.sha256(unicodedata.normalize("NFC", config_dir).encode()).hexdigest()[:8]
    names = [f"{CLAUDE_KEYCHAIN_SERVICE}-{digest}"]
    if config_dir == default_claude_dir():
        names.insert(0, CLAUDE_KEYCHAIN_SERVICE)
    return names


def read_keychain(service):
    """Secret of the macOS keychain item `service` for the current user, or None."""
    if sys.platform != "darwin":
        return None
    user = os.environ.get("USER") or getpass.getuser()
    try:
        r = subprocess.run(["security", "find-generic-password", "-a", user, "-w", "-s", service],
                           capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None
    out = r.stdout.strip()
    return out if r.returncode == 0 and out else None


def read_claude_store(config_dir):
    """Parsed credential store for a Claude config dir (keychain first, then .credentials.json), or None."""
    for service in claude_keychain_services(config_dir):
        raw = read_keychain(service)
        if raw:
            return json.loads(raw)
    path = os.path.join(config_dir, ".credentials.json")
    if os.path.isfile(path):
        with open(path) as f:
            return json.load(f)
    return None


def claude_global_config_path(config_dir):
    # Claude Code keeps .claude.json next to the config dir: $CLAUDE_CONFIG_DIR/.claude.json, else ~/.claude.json
    if config_dir == default_claude_dir():
        return os.path.join(os.path.expanduser("~"), ".claude.json")
    return os.path.join(config_dir, ".claude.json")


def load_claude_auth(config_dir):
    store = read_claude_store(config_dir)
    if store is None:
        raise RuntimeError(f"no Claude Code credentials (keychain item or .credentials.json); "
                           f"run claude with CLAUDE_CONFIG_DIR={config_dir} and /login")
    oauth = store.get("claudeAiOauth") or {}
    access = oauth.get("accessToken")
    if not access:
        raise RuntimeError("credentials have no claude.ai OAuth token (API-key login?)")
    account = {}
    try:
        with open(claude_global_config_path(config_dir)) as f:
            account = json.load(f).get("oauthAccount") or {}
    except (OSError, ValueError):
        pass
    plan = oauth.get("subscriptionType") or ""
    tier = oauth.get("rateLimitTier") or ""  # e.g. default_claude_max_20x
    if tier.rsplit("_", 1)[-1].endswith("x") and tier.rsplit("_", 1)[-1][:-1].isdigit():
        plan = f"{plan} {tier.rsplit('_', 1)[-1]}".strip()
    expires_at = oauth.get("expiresAt")
    return {
        "access": access,
        "email": account.get("emailAddress") or "",
        "plan": plan,
        "exp": expires_at / 1000 if expires_at else None,
    }


# ---------------------------------------------------------------------------
# Codex credentials


def jwt_claims(token):
    try:
        part = token.split(".")[1]
        part += "=" * (-len(part) % 4)
        return json.loads(base64.urlsafe_b64decode(part))
    except Exception:
        return {}


def load_codex_auth(home):
    with open(os.path.join(home, "auth.json")) as f:
        data = json.load(f)
    tokens = data.get("tokens") or {}
    access = tokens.get("access_token")
    if not access:
        raise RuntimeError("auth.json has no ChatGPT tokens (API-key login?)")
    id_claims = jwt_claims(tokens.get("id_token") or "")
    return {
        "access": access,
        "account_id": tokens.get("account_id") or "",
        "email": id_claims.get("email") or "",
        "exp": jwt_claims(access).get("exp"),
        "last_refresh": (data.get("last_refresh") or "?")[:10],
    }


# ---------------------------------------------------------------------------
# fetching


def _get(req, timeout, base, cli):
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return {**base, "data": json.loads(r.read().decode())}
    except urllib.error.HTTPError as e:
        hint = f" (token rejected; start {cli} in this home once to refresh it)" if e.code == 401 else ""
        return {**base, "error": f"HTTP {e.code} {e.reason}{hint}"}
    except Exception as e:
        return {**base, "error": f"network error: {e}"}


def fetch_claude(config_dir, timeout):
    base = {"provider": "claude", "home": config_dir, "email": "", "plan": ""}
    try:
        auth = load_claude_auth(config_dir)
    except Exception as e:  # missing/invalid credentials
        return {**base, "error": f"cannot read credentials: {e}"}
    base.update(email=auth["email"], plan=auth["plan"])
    if auth["exp"] and auth["exp"] <= time.time():
        return {**base, "error": "access token expired; start claude in this config dir once to refresh it"}
    req = urllib.request.Request(CLAUDE_URL, headers={
        "Authorization": f"Bearer {auth['access']}",
        "anthropic-beta": CLAUDE_OAUTH_BETA,
        "Content-Type": "application/json",
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    })
    return _get(req, timeout, base, "claude")


def fetch_codex(home, timeout):
    base = {"provider": "codex", "home": home, "email": ""}
    try:
        auth = load_codex_auth(home)
    except Exception as e:  # missing/invalid auth.json
        return {**base, "error": f"cannot read auth.json: {e}"}
    base["email"] = auth["email"]
    if auth["exp"] and auth["exp"] <= time.time():
        return {**base, "error": f"access token expired (last refresh {auth['last_refresh']}); "
                "start codex in this home once to refresh it"}
    req = urllib.request.Request(CODEX_URL, headers={
        "Authorization": f"Bearer {auth['access']}",
        "ChatGPT-Account-Id": auth["account_id"],
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    })
    return _get(req, timeout, base, "codex")


def fetch(provider, path, timeout):
    return (fetch_claude if provider == "claude" else fetch_codex)(path, timeout)


# ---------------------------------------------------------------------------
# formatting


def window_label(seconds):
    hours = seconds / 3600
    if hours >= 24:
        days = round(hours / 24)
        return "weekly" if days == 7 else f"{days}d"
    return f"{round(hours)}h"


def countdown(reset_at):
    diff = int(reset_at - time.time())
    if diff <= 0:
        return "now"
    d, rem = divmod(diff, 86400)
    h, rem = divmod(rem, 3600)
    m = rem // 60
    if d:
        return f"{d}d {h}h"
    if h:
        return f"{h}h {m}m" if m else f"{h}h"
    return f"{m}m"


def bar(pct):
    filled = max(0, min(BAR_WIDTH, round(pct / 100 * BAR_WIDTH)))
    return "[" + "█" * filled + "░" * (BAR_WIDTH - filled) + "]"


def iso_epoch(text):
    if not text:
        return None
    try:
        return datetime.datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def money(m):
    """{'amount_minor': 1234, 'currency': 'USD', 'exponent': 2} -> '$12.34'."""
    amount = m["amount_minor"] / 10 ** (m.get("exponent") or 2)
    cur = m.get("currency") or "USD"
    return f"${amount:.2f}" if cur == "USD" else f"{amount:.2f} {cur}"


# rows: (label, percent, reset epoch or None, note)


def windows(data):
    out = []
    rl = data.get("rate_limit") or {}
    for key in ("primary_window", "secondary_window"):
        if rl.get(key):
            out.append((window_label(rl[key]["limit_window_seconds"]), rl[key]))
    for extra in data.get("additional_rate_limits") or []:
        name = (extra.get("limit_name") or "extra").split("-")[-1].lower()
        erl = extra.get("rate_limit") or {}
        for key in ("primary_window", "secondary_window"):
            if erl.get(key):
                out.append((f"{name} {window_label(erl[key]['limit_window_seconds'])}", erl[key]))
    return out


def codex_report(d):
    flags = []
    if (d.get("rate_limit") or {}).get("limit_reached"):
        reason = (d.get("rate_limit_reached_type") or {}).get("type")
        flags.append("LIMIT REACHED" + (f" ({reason.replace('_', ' ')})" if reason else ""))
    rows = []
    for label, w in windows(d):
        reset_at = w.get("reset_at") or time.time() + (w.get("reset_after_seconds") or 0)
        rows.append((label, int(round(w.get("used_percent") or 0)), reset_at, ""))
    extras = []
    credits = d.get("credits") or {}
    if credits.get("unlimited"):
        extras.append("credits: unlimited")
    elif credits.get("has_credits") and credits.get("balance") not in (None, ""):
        try:
            extras.append(f"credits: ${float(credits['balance']):.2f}")
        except ValueError:
            extras.append(f"credits: {credits['balance']}")
    reset_credits = (d.get("rate_limit_reset_credits") or {}).get("available_count")
    if reset_credits:
        extras.append(f"reset credits: {reset_credits} available")
    return d.get("plan_type") or "", flags, rows, extras


def claude_limit_label(entry):
    kind = entry.get("kind") or "limit"
    if kind in CLAUDE_KIND_LABELS:
        return CLAUDE_KIND_LABELS[kind]
    scope = entry.get("scope") or {}
    model = scope.get("model") or {}
    target = model.get("display_name") or model.get("id") or scope.get("surface")
    base = "weekly" if kind.startswith("weekly") else kind.replace("_", " ")
    return f"{base} ({target})" if target else base


def claude_rows(d):
    """Every limit in the response: the unified `limits` list first, then any top-level
    bucket (five_hour, seven_day_*, codenamed ones) that is not the same limit again."""
    rows, seen = [], set()
    for entry in d.get("limits") or []:
        pct = int(round(entry.get("percent") or 0))
        notes = []
        if (entry.get("severity") or "normal") != "normal":
            notes.append(str(entry["severity"]))
        if entry.get("is_active"):
            notes.append("active")
        rows.append((claude_limit_label(entry), pct, iso_epoch(entry.get("resets_at")), " · ".join(notes)))
        seen.add((pct, (entry.get("resets_at") or "")[:19]))
    for key, val in d.items():
        if key == "extra_usage" or not isinstance(val, dict) or val.get("utilization") is None:
            continue
        pct = int(round(val["utilization"]))
        if (pct, (val.get("resets_at") or "")[:19]) in seen:
            continue
        notes = []
        if val.get("limit_dollars") is not None:
            notes.append(f"${val.get('used_dollars') or 0:.2f} / ${val['limit_dollars']:.2f}")
        if val.get("locked_reason"):
            notes.append(f"locked: {val['locked_reason']}")
        rows.append((CLAUDE_BUCKET_LABELS.get(key, key), pct, iso_epoch(val.get("resets_at")), " · ".join(notes)))
    return rows


def claude_extras(d):
    out = []
    eu = d.get("extra_usage")
    if isinstance(eu, dict):
        if not eu.get("is_enabled"):
            reason = eu.get("disabled_reason") or ("user disabled" if eu.get("user_disabled") else "")
            out.append("extra usage: off" + (f" ({reason})" if reason else ""))
        elif eu.get("monthly_limit") is None:
            out.append("extra usage: on, unlimited")
        else:
            used = (eu.get("used_credits") or 0) / 100
            pct = eu.get("utilization")
            out.append(f"extra usage: ${used:.2f} / ${eu['monthly_limit'] / 100:.2f} spent"
                       + (f" ({int(round(pct))}%)" if pct is not None else ""))
    balance = (d.get("spend") or {}).get("balance")
    if isinstance(balance, dict) and balance.get("amount_minor") is not None:
        out.append(f"credits: {money(balance)}")
    rows = (d.get("seven_day_breakdown") or {}).get("rows") or []
    parts = [f"{r.get('display_name') or r.get('key')} {int(round(r['percent']))}%"
             for r in rows if (r.get("percent") or 0) > 0]
    if parts:
        out.append("weekly by product: " + ", ".join(parts))
    return out


def claude_report(d, plan):
    rows = claude_rows(d)
    flags = [f"LIMIT REACHED ({label})" for label, pct, _, _ in rows if pct >= 100]
    if (d.get("extra_usage") or {}).get("spend_limit_reached"):
        flags.append("SPEND LIMIT REACHED")
    return plan, flags, rows, claude_extras(d)


def report(r):
    if r["provider"] == "claude":
        return claude_report(r["data"], r.get("plan") or "")
    plan, flags, rows, extras = codex_report(r["data"])
    return plan, flags, rows, extras


def display_name(path):
    return os.path.basename(path.rstrip("/")).lstrip(".")


def render(results, current):
    names = [display_name(r["home"]) for r in results]
    emails = [(r.get("data") or {}).get("email") or r.get("email") or "" for r in results]
    name_w, email_w = max(map(len, names)), max(map(len, emails))
    lines = []
    for i, r in enumerate(results):
        marker = "→ " if r["home"] in current else "  "
        head = f"{marker}{names[i]:<{name_w}}  {emails[i]:<{email_w}}"
        if "error" in r:
            lines.append(f"{head}  [error] {r['error']}")
        else:
            plan, flags, rows, extras = report(r)
            lines.append(head + f"  ({plan or '?'})" + "".join(f"  {flag}" for flag in flags))
            label_w = max((len(label) for label, *_ in rows), default=0)
            for label, pct, reset_at, note in rows:
                line = f"    {label:<{label_w}}  {bar(pct)} {pct:>3d}% used"
                if reset_at is not None:
                    line += f"  resets in {countdown(reset_at)}"
                if note:
                    line += f"  {note}"
                lines.append(line)
            if extras:
                lines.append("    " + "  ·  ".join(extras))
        if i < len(results) - 1:
            lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------


def targets(dirs, want_claude, want_codex):
    if dirs:
        out = [(classify(d), d) for d in dirs]
        return [(p, d) for p, d in out if (p == "claude" and want_claude) or (p == "codex" and want_codex)]
    out = []
    if want_claude:
        out += [("claude", d) for d in claude_dirs()]
    if want_codex:
        out += [("codex", h) for h in codex_homes()]
    return out


def main():
    ap = argparse.ArgumentParser(
        description="Live rate-limit usage for every Claude Code account and Codex home (no login).")
    ap.add_argument("dirs", nargs="*",
                    help="Codex homes (with auth.json) or Claude config dirs "
                         "(default: ~/.claude, ~/.claude-*, ~/.codex, ~/.codex-*)")
    ap.add_argument("--claude", action="store_true", help="only Claude accounts")
    ap.add_argument("--codex", action="store_true", help="only Codex homes")
    ap.add_argument("--json", action="store_true", help="print the raw API response per dir")
    ap.add_argument("--timeout", type=float, default=15, help="seconds per request (default 15)")
    args = ap.parse_args()

    dirs = [os.path.abspath(os.path.expanduser(d)) for d in args.dirs]
    want_claude = args.claude or not args.codex
    want_codex = args.codex or not args.claude
    todo = targets(dirs, want_claude, want_codex)
    if not todo:
        sys.exit("no Claude config dir with credentials or Codex home with an auth.json found")
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(todo)) as pool:
        results = list(pool.map(lambda t: fetch(t[0], t[1], args.timeout), todo))

    if args.json:
        print(json.dumps({r["home"]: r.get("data") or {"error": r["error"]} for r in results},
                         indent=2, ensure_ascii=False))
    else:
        print(render(results, current_dirs()))
    return 1 if any("error" in r for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
