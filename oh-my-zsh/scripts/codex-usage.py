# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///

"""codex-usage: live Codex rate-limit usage for every Codex home, straight from the API.

This is the call `cdx usage` (bjesuiter/codex-switcher) makes,
GET https://chatgpt.com/backend-api/wham/usage, but authenticated with the tokens
Codex CLI already keeps in <home>/auth.json, so there is nothing to log in to.
It is the same data `/status` shows inside Codex, fetched fresh on every run.

Homes: ~/.codex plus every ~/.codex-* that has an auth.json. Override with
positional paths or CODEX_HOMES=path:path. The home a bare `codex` would use
($CODEX_HOME, else ~/.codex) is marked with an arrow.

Tokens are used as-is and never refreshed here: Codex CLI owns auth.json and its
refresh token, and rotating that behind the CLI's back is what forces re-logins.
An expired token is reported as such; starting codex in that home refreshes it.
"""
import argparse
import base64
import concurrent.futures
import glob
import json
import os
import sys
import time
import urllib.error
import urllib.request

URL = "https://chatgpt.com/backend-api/wham/usage"
BAR_WIDTH = 20


def default_homes():
    env = os.environ.get("CODEX_HOMES")
    if env:
        cands = [os.path.expanduser(p) for p in env.split(":") if p]
    else:
        home = os.path.expanduser("~")
        cands = [os.path.join(home, ".codex")] + sorted(glob.glob(os.path.join(home, ".codex-*")))
    return [c for c in cands if os.path.isfile(os.path.join(c, "auth.json"))]


def jwt_claims(token):
    try:
        part = token.split(".")[1]
        part += "=" * (-len(part) % 4)
        return json.loads(base64.urlsafe_b64decode(part))
    except Exception:
        return {}


def load_auth(home):
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


def fetch(home, timeout):
    try:
        auth = load_auth(home)
    except Exception as e:  # missing/invalid auth.json
        return {"home": home, "email": "", "error": f"cannot read auth.json: {e}"}
    if auth["exp"] and auth["exp"] <= time.time():
        return {"home": home, "email": auth["email"], "error":
                f"access token expired (last refresh {auth['last_refresh']}); "
                "start codex in this home once to refresh it"}
    req = urllib.request.Request(URL, headers={
        "Authorization": f"Bearer {auth['access']}",
        "ChatGPT-Account-Id": auth["account_id"],
        "User-Agent": "codex-usage",
        "Accept": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return {"home": home, "email": auth["email"], "data": json.loads(r.read().decode())}
    except urllib.error.HTTPError as e:
        hint = " (token rejected; start codex in this home once to refresh it)" if e.code == 401 else ""
        return {"home": home, "email": auth["email"], "error": f"HTTP {e.code} {e.reason}{hint}"}
    except Exception as e:
        return {"home": home, "email": auth["email"], "error": f"network error: {e}"}


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


def render(results, current):
    names = [os.path.basename(r["home"].rstrip("/")).lstrip(".") for r in results]
    emails = [(r.get("data") or {}).get("email") or r.get("email") or "" for r in results]
    name_w, email_w = max(map(len, names)), max(map(len, emails))
    lines = []
    for i, r in enumerate(results):
        marker = "→ " if r["home"] == current else "  "
        head = f"{marker}{names[i]:<{name_w}}  {emails[i]:<{email_w}}"
        if "error" in r:
            lines.append(f"{head}  [error] {r['error']}")
        else:
            d = r["data"]
            head += f"  ({d.get('plan_type') or '?'})"
            if (d.get("rate_limit") or {}).get("limit_reached"):
                reason = (d.get("rate_limit_reached_type") or {}).get("type")
                head += "  LIMIT REACHED" + (f" ({reason.replace('_', ' ')})" if reason else "")
            lines.append(head)
            ws = windows(d)
            label_w = max((len(label) for label, _ in ws), default=0)
            for label, w in ws:
                reset_at = w.get("reset_at") or time.time() + (w.get("reset_after_seconds") or 0)
                pct = int(round(w.get("used_percent") or 0))
                lines.append(f"    {label:<{label_w}}  {bar(pct)} {pct:>3d}% used  resets in {countdown(reset_at)}")
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
            if extras:
                lines.append("    " + "  ·  ".join(extras))
        if i < len(results) - 1:
            lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description="Live Codex rate-limit usage for every Codex home (no login).")
    ap.add_argument("homes", nargs="*", help="Codex home dirs (default: ~/.codex and ~/.codex-*)")
    ap.add_argument("--json", action="store_true", help="print the raw API response per home")
    ap.add_argument("--timeout", type=float, default=15, help="seconds per request (default 15)")
    args = ap.parse_args()

    homes = [os.path.abspath(os.path.expanduser(h)) for h in args.homes] or default_homes()
    if not homes:
        sys.exit("no Codex home with an auth.json found")
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(homes)) as pool:
        results = list(pool.map(lambda h: fetch(h, args.timeout), homes))

    current = os.path.abspath(os.path.expanduser(os.environ.get("CODEX_HOME") or "~/.codex"))
    if args.json:
        print(json.dumps({r["home"]: r.get("data") or {"error": r["error"]} for r in results},
                         indent=2, ensure_ascii=False))
    else:
        print(render(results, current))
    return 1 if any("error" in r for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
