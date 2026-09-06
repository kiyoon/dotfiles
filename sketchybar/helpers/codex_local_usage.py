#!/usr/bin/env python3
"""Estimate how much of the current Codex rate-limit window this Mac used.

Codex CLI appends one rollout per thread under ~/.codex/sessions/YYYY/MM/DD.
Every response leaves a `token_usage_record` line (CLI >= 0.153) and a
`token_count` event whose `rate_limits` carry the server's own window
boundaries (`resets_at`, `window_minutes`) and account-wide `used_percent`.

This script takes the window from the newest `rate_limits` observation for
one limit bucket (default `codex`, the weekly bar), sums this machine's
per-response tokens inside that window with price-like weights, converts them
to percent of the window with a per-model calibration, and writes a small JSON
that helpers/codexbar_usage_watcher renders as the bottom lane of the Codex
meter. Everything is local: no CodexBar, no network.

The watcher runs this only when a rollout changes (FSEvents), so idle means no
work at all. A run is cheap: a cache remembers each rollout's byte offset and
parsed events, only appended bytes are read, only the date directories inside
the retention window are listed (a full walk happens every few hours to catch
threads resumed after a long idle), and nothing is rewritten unless it changed.
"""

import argparse
import datetime
import fcntl
import json
import os
import sys
import time

DEFAULT_SESSIONS = os.path.expanduser("~/.codex/sessions")
DEFAULT_DIR = os.path.expanduser("~/.cache/sketchybar/codex_local_usage")
DEFAULT_OUTPUT = os.path.join(DEFAULT_DIR, "usage.json")
DEFAULT_CACHE = os.path.join(DEFAULT_DIR, "cache.json")
CACHE_VERSION = 1
# Longest window Codex reports is 7 days; keep one day of slack.
RETENTION_SECONDS = 8 * 86400
# Cheap runs list only the date dirs inside the retention window plus files
# already cached; a full walk (~20 ms for 4k files) catches threads resumed
# after a long idle. Codex names dirs YYYY/MM/DD by local creation date.
FULL_WALK_INTERVAL = 6 * 3600
# Price-like weights: uncached input, cached input, output (incl. reasoning).
WEIGHT_UNCACHED, WEIGHT_CACHED, WEIGHT_OUTPUT = 1.0, 0.1, 8.0
# Weighted units that move the weekly bar by one percent, measured on this
# account in 2026-08/09 (see README). Longest prefix match; "*" is the
# fallback for models not listed.
DEFAULT_CALIBRATION = {"gpt-5.6-sol": 5.0e6, "gpt-6-astra": 0.88e6, "*": 0.88e6}
# Spark models bill to their own bucket (limit_id codex_bengalfox), so they
# never move the weekly bar this script tracks.
EXCLUDED_MODEL_SUBSTRINGS = ("spark",)
# Observations of the same window jitter by a second between sessions.
RESET_TOLERANCE = 10


def parse_timestamp(value):
    """ISO-8601 UTC string (with optional fractional seconds) -> epoch seconds."""
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        return datetime.datetime.fromisoformat(text).timestamp()
    except ValueError:
        pass
    for fmt in ("%Y-%m-%dT%H:%M:%S.%f%z", "%Y-%m-%dT%H:%M:%S%z"):
        try:
            return datetime.datetime.strptime(text, fmt).timestamp()
        except ValueError:
            continue
    raise ValueError("unrecognised timestamp %r" % value)


def iso(epoch):
    return datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )


def parse_now(value):
    if value is None:
        return time.time()
    try:
        return float(value)
    except ValueError:
        return parse_timestamp(value)


def weighted(uncached, cached, output):
    return uncached * WEIGHT_UNCACHED + cached * WEIGHT_CACHED + output * WEIGHT_OUTPUT


def calibration_for(model, calibration):
    best = None
    for key in calibration:
        if key != "*" and model.startswith(key) and (best is None or len(key) > len(best)):
            best = key
    if best is None:
        best = "*"
    return calibration.get(best)


def is_excluded(model):
    lowered = model.lower()
    return any(part in lowered for part in EXCLUDED_MODEL_SUBSTRINGS)


def new_entry():
    return {
        "size": 0,
        "mtime": 0.0,
        "offset": 0,
        "model": None,
        "has_records": False,
        "last_sig": None,
        "events": [],
        "legacy": [],
        "limits": {},
    }


def usage_event(ts, model, usage):
    cached = int(usage.get("cached_input_tokens") or 0)
    uncached = int(usage.get("input_tokens") or 0) - cached
    output = int(usage.get("output_tokens") or 0)
    return [int(ts), model or "unknown", max(uncached, 0), cached, output]


def note_limits(entry, ts, rate_limits):
    limit_id = rate_limits.get("limit_id")
    if not limit_id:
        return
    for window in (rate_limits.get("primary"), rate_limits.get("secondary")):
        if not isinstance(window, dict):
            continue
        minutes = window.get("window_minutes")
        resets_at = window.get("resets_at")
        used = window.get("used_percent")
        if not minutes or resets_at is None or used is None:
            continue
        key = "%s|%d" % (limit_id, int(minutes))
        obs = {
            "ts": int(ts),
            "used_percent": float(used),
            "resets_at": int(resets_at),
            "window_minutes": int(minutes),
            "limit_id": limit_id,
        }
        current = entry["limits"].get(key)
        if current is None or obs["ts"] >= current["newest"]["ts"]:
            same_window = current is not None and abs(
                current["newest"]["resets_at"] - obs["resets_at"]
            ) <= RESET_TOLERANCE
            earliest = current["earliest"] if same_window else obs
            entry["limits"][key] = {"newest": obs, "earliest": earliest}


def handle_line(entry, line):
    obj = json.loads(line)
    kind = obj.get("type")
    payload = obj.get("payload") or {}
    if kind == "turn_context":
        model = payload.get("model")
        if model:
            entry["model"] = model
    elif kind == "token_usage_record":
        ts = parse_timestamp(obj["timestamp"])
        entry["events"].append(usage_event(ts, entry["model"], payload["usage"]))
        entry["has_records"] = True
    elif kind == "event_msg" and payload.get("type") == "token_count":
        ts = parse_timestamp(obj["timestamp"])
        rate_limits = payload.get("rate_limits")
        if isinstance(rate_limits, dict):
            note_limits(entry, ts, rate_limits)
        info = payload.get("info") or {}
        last = info.get("last_token_usage")
        if isinstance(last, dict) and not entry["has_records"]:
            # Older CLIs re-emit the same last_token_usage on rate-limit-only
            # updates; collapsing consecutive repeats keeps the fallback close
            # to the true per-response sum.
            sig = [last.get(k) for k in sorted(last)]
            if sig != entry["last_sig"]:
                entry["legacy"].append(usage_event(ts, entry["model"], last))
                entry["last_sig"] = sig


def parse_file(path, entry, stats):
    """Consume complete lines appended since entry['offset']."""
    with open(path, "rb") as handle:
        handle.seek(entry["offset"])
        for line in handle:
            if not line.endswith(b"\n"):
                break  # a writer is mid-line; pick it up next run
            entry["offset"] += len(line)
            stats["bytes_read"] += len(line)
            if (
                b"turn_context" not in line
                and b"token_usage_record" not in line
                and b"token_count" not in line
            ):
                continue
            try:
                handle_line(entry, line)
            except (ValueError, KeyError, TypeError, AttributeError):
                continue


def recent_date_dirs(sessions_dir, now):
    names = set()
    t = now - RETENTION_SECONDS
    while t <= now + 86400:  # include today (and tomorrow around midnight)
        names.add(datetime.datetime.fromtimestamp(t).strftime("%Y/%m/%d"))
        t += 86400
    return [os.path.join(sessions_dir, name) for name in sorted(names)]


def rollout_files(sessions_dir, cache, now, full):
    """Yield (path, size, mtime) for rollouts that may hold events in retention."""
    paths = set()
    if full:
        for root, _dirs, files in os.walk(sessions_dir):
            paths.update(os.path.join(root, f) for f in files if f.endswith(".jsonl"))
    else:
        for directory in recent_date_dirs(sessions_dir, now):
            try:
                names = os.listdir(directory)
            except OSError:
                continue
            paths.update(os.path.join(directory, f) for f in names if f.endswith(".jsonl"))
        paths.update(cache["files"])
    cutoff = now - RETENTION_SECONDS
    for path in paths:
        try:
            st = os.stat(path)
        except OSError:
            continue
        if st.st_mtime >= cutoff:
            yield path, st.st_size, st.st_mtime


def load_cache(path):
    try:
        with open(path) as handle:
            cache = json.load(handle)
        if cache.get("version") == CACHE_VERSION and isinstance(cache.get("files"), dict):
            return cache
    except (OSError, ValueError):
        pass
    return {"version": CACHE_VERSION, "files": {}}


def write_json(path, data):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = "%s.%d.tmp" % (path, os.getpid())
    with open(tmp, "w") as handle:
        json.dump(data, handle, separators=(",", ":"))
    os.replace(tmp, path)


def write_json_if_changed(path, data, volatile):
    """Skip the write when only the volatile fields differ, so an idle run
    leaves the file, its mtime and anything watching it alone."""
    try:
        with open(path) as handle:
            current = json.load(handle)
    except (OSError, ValueError):
        current = None
    if (
        isinstance(current, dict)
        and set(current) == set(data)
        and all(current[k] == v for k, v in data.items() if k not in volatile)
    ):
        return False
    write_json(path, data)
    return True


def update_cache(cache, sessions_dir, now, stats, full):
    """Parse what changed on disk; return whether the cache itself changed."""
    cutoff = now - RETENTION_SECONDS
    seen = set()
    changed = False
    for path, size, mtime in rollout_files(sessions_dir, cache, now, full):
        seen.add(path)
        stats["files_scanned"] += 1
        entry = cache["files"].get(path)
        if entry is None:
            entry = new_entry()
            cache["files"][path] = entry
        elif entry["size"] == size and entry["mtime"] == mtime:
            continue
        if size < entry["offset"]:
            # Truncated or rewritten: start over for this file.
            fresh = new_entry()
            fresh.update(size=size, mtime=mtime)
            entry = fresh
            cache["files"][path] = entry
        stats["files_parsed"] += 1
        changed = True
        parse_file(path, entry, stats)
        entry["size"] = size
        entry["mtime"] = mtime
        for key in ("events", "legacy"):
            entry[key] = [ev for ev in entry[key] if ev[0] >= cutoff]
    for path in list(cache["files"]):
        if path not in seen:
            del cache["files"][path]
            changed = True
    if full:
        cache["last_full_walk"] = now
        changed = True
    return changed


def newest_limits(cache, limit_id):
    """Per window length, the newest observation (and the earliest one of the
    same window) across all rollouts."""
    result = {}
    for entry in cache["files"].values():
        for key, obs in entry["limits"].items():
            if not key.startswith(limit_id + "|"):
                continue
            minutes = obs["newest"]["window_minutes"]
            current = result.get(minutes)
            if current is None or obs["newest"]["ts"] > current["newest"]["ts"]:
                earliest = obs["earliest"]
                if current is not None and abs(
                    current["newest"]["resets_at"] - obs["newest"]["resets_at"]
                ) <= RESET_TOLERANCE and current["earliest"]["ts"] < earliest["ts"]:
                    earliest = current["earliest"]
                result[minutes] = {"newest": obs["newest"], "earliest": earliest}
            elif abs(current["newest"]["resets_at"] - obs["newest"]["resets_at"]) <= RESET_TOLERANCE:
                if obs["earliest"]["ts"] < current["earliest"]["ts"]:
                    current["earliest"] = obs["earliest"]
    return result


def events_in_range(cache, start, end):
    for entry in cache["files"].values():
        source = entry["events"] if entry["has_records"] else entry["legacy"]
        for ev in source:
            if start <= ev[0] <= end:
                yield ev


def summarise_window(cache, obs, now, calibration):
    newest = obs["newest"]
    minutes = newest["window_minutes"]
    resets_at = newest["resets_at"]
    start = resets_at - minutes * 60
    stale = now > resets_at
    units_by_model = {}
    excluded = {}
    tokens = {"uncached_input": 0, "cached_input": 0, "output": 0}
    responses = 0
    if not stale:
        for _ts, model, uncached, cached, output in events_in_range(cache, start, now):
            units = weighted(uncached, cached, output)
            if is_excluded(model):
                excluded[model] = excluded.get(model, 0.0) + units
                continue
            responses += 1
            units_by_model[model] = units_by_model.get(model, 0.0) + units
            tokens["uncached_input"] += uncached
            tokens["cached_input"] += cached
            tokens["output"] += output
    percent_by_model = {}
    for model, units in units_by_model.items():
        per_percent = calibration_for(model, calibration)
        if per_percent:
            percent_by_model[model] = round(units / per_percent, 2)
    local_percent = round(sum(percent_by_model.values()), 2)

    implied = None
    earliest = obs["earliest"]
    rise = newest["used_percent"] - earliest["used_percent"]
    if not stale and rise >= 5 and newest["ts"] > earliest["ts"]:
        span_units = sum(
            weighted(ev[2], ev[3], ev[4])
            for ev in events_in_range(cache, earliest["ts"], newest["ts"])
            if not is_excluded(ev[1])
        )
        implied = round(span_units / rise)

    return {
        "window_minutes": minutes,
        "window_start": iso(start),
        "window_start_epoch": start,
        "resets_at": iso(resets_at),
        "resets_at_epoch": resets_at,
        "observed_used_percent": newest["used_percent"],
        "observed_at": iso(newest["ts"]),
        "stale": stale,
        "local_used_percent": local_percent,
        "percent_by_model": percent_by_model,
        "units_by_model": {m: round(u) for m, u in units_by_model.items()},
        "tokens": tokens,
        "responses": responses,
        "implied_units_per_percent": implied,
    }, excluded


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--sessions", default=DEFAULT_SESSIONS, help="Codex sessions dir")
    parser.add_argument("--limit-id", default="codex", help="rate-limit bucket to track")
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--cache", default=DEFAULT_CACHE)
    parser.add_argument("--calibration", help="JSON file {model_prefix: units_per_percent}")
    parser.add_argument("--now", help="override the clock (epoch seconds or ISO-8601), for tests")
    parser.add_argument("--full-walk", action="store_true", help="stat every rollout, not just recent date dirs")
    parser.add_argument("--print", action="store_true", help="print a summary and a stats= line")
    args = parser.parse_args(argv)

    started = time.time()
    now = parse_now(args.now)
    calibration = dict(DEFAULT_CALIBRATION)
    if args.calibration:
        with open(args.calibration) as handle:
            calibration.update(json.load(handle))

    os.makedirs(os.path.dirname(args.cache) or ".", exist_ok=True)
    # O_CREAT without truncation: taking the lock must not touch the file's mtime.
    lock = os.open(args.cache + ".lock", os.O_RDWR | os.O_CREAT, 0o644)
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 0  # another run is in progress

    stats = {"files_scanned": 0, "files_parsed": 0, "bytes_read": 0}
    cache = load_cache(args.cache)
    full = args.full_walk or now - cache.get("last_full_walk", 0) >= FULL_WALK_INTERVAL
    stats["full_walk"] = full
    error = None
    cache_changed = False
    if os.path.isdir(args.sessions):
        cache_changed = update_cache(cache, args.sessions, now, stats, full)
    else:
        error = "sessions dir not found: %s" % args.sessions

    windows = []
    excluded_total = {}
    limits = newest_limits(cache, args.limit_id)
    for minutes in sorted(limits):
        summary, excluded = summarise_window(cache, limits[minutes], now, calibration)
        windows.append(summary)
        for model, units in excluded.items():
            excluded_total[model] = round(excluded_total.get(model, 0.0) + units)

    stats["elapsed_ms"] = round((time.time() - started) * 1000)
    output = {
        "version": 1,
        "generated_at": iso(now),
        "sessions_dir": args.sessions,
        "limit_id": args.limit_id,
        "stale": bool(windows) and all(w["stale"] for w in windows),
        "windows": windows,
        "excluded_models": excluded_total,
        "calibration": calibration,
        "weights": {
            "uncached_input": WEIGHT_UNCACHED,
            "cached_input": WEIGHT_CACHED,
            "output": WEIGHT_OUTPUT,
        },
        "stats": stats,
        "error": error,
    }
    if cache_changed:
        write_json(args.cache, cache)
    stats["wrote_cache"] = cache_changed
    stats["wrote_output"] = write_json_if_changed(args.output, output, ("generated_at", "stats"))

    if args.print:
        if not windows:
            print("no %s rate-limit observations found" % args.limit_id)
        for w in windows:
            print(
                "%d-min window %s -> %s: local %.2f%% of observed %.0f%% (%d responses%s)"
                % (
                    w["window_minutes"],
                    w["window_start"],
                    w["resets_at"],
                    w["local_used_percent"],
                    w["observed_used_percent"],
                    w["responses"],
                    ", stale" if w["stale"] else "",
                )
            )
        print("stats=" + json.dumps(stats, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
