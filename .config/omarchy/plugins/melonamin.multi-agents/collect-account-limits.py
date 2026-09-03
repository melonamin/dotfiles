#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Collect one subscription's limits without scanning shared transcripts."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import select
import shutil
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


CLAUDE_USAGE_ENDPOINT = "https://api.anthropic.com/api/oauth/usage"


def number(value: Any) -> int:
    try:
        return round(float(value or 0))
    except Exception:
        return 0


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except Exception:
        return {}


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(value, separators=(",", ":")) + "\n", encoding="utf-8")
    temporary.replace(path)


def normalize_reset_at(value: Any) -> str:
    if value is None:
        return ""
    raw = str(value).strip()
    if not raw:
        return ""
    if raw.isdigit():
        timestamp = int(raw)
        if timestamp < 1_000_000_000_000:
            timestamp *= 1000
        try:
            return dt.datetime.fromtimestamp(timestamp / 1000, dt.timezone.utc).isoformat()
        except Exception:
            return raw
    try:
        return dt.datetime.fromisoformat(raw.replace("Z", "+00:00")).isoformat()
    except Exception:
        return raw


def parse_utilization(value: Any) -> float:
    try:
        return float(str(value).strip().replace("%", ""))
    except Exception:
        return float("nan")


def normalize_utilization(value: Any, percent_scale: bool) -> float:
    parsed = parse_utilization(value)
    if not parsed >= 0:
        return -1.0
    if percent_scale or parsed > 1:
        return min(1.0, parsed / 100.0)
    return min(1.0, parsed)


def plan_label(tier: str, subscription: str) -> str:
    if tier:
        match = re.search(r"max_(\d+x)", tier, re.IGNORECASE)
        if match:
            return "Max " + match.group(1)
    return subscription[:1].upper() + subscription[1:] if subscription else ""


def scoped_window(kind: str) -> str:
    text = kind.lower()
    if "month" in text:
        return "Monthly"
    if "week" in text or "day" in text:
        return "Weekly"
    if "hour" in text or "session" in text:
        return "Session"
    return ""


def parse_claude_limits(payload: dict[str, Any]) -> list[dict[str, Any]]:
    session = payload.get("five_hour") if isinstance(payload.get("five_hour"), dict) else None
    weekly = payload.get("seven_day_oauth_apps")
    if not isinstance(weekly, dict):
        weekly = payload.get("seven_day") if isinstance(payload.get("seven_day"), dict) else None

    raw_values: list[Any] = [
        session.get("utilization") if session else None,
        weekly.get("utilization") if weekly else None,
    ]
    scoped = payload.get("limits")
    if isinstance(scoped, list):
        raw_values.extend(entry.get("percent") for entry in scoped if isinstance(entry, dict))
    percent_scale = any(parse_utilization(value) >= 1 for value in raw_values)

    limits: list[dict[str, Any]] = []
    for bucket, label in ((session, "Session (5-hour)"), (weekly, "Weekly (7-day)")):
        if bucket is None:
            continue
        percent = normalize_utilization(bucket.get("utilization"), percent_scale)
        if percent >= 0:
            limits.append(
                {
                    "label": label,
                    "percent": percent,
                    "resetsAt": normalize_reset_at(bucket.get("resets_at")),
                }
            )

    seen: set[tuple[str, str]] = set()
    if isinstance(scoped, list):
        for entry in scoped:
            if not isinstance(entry, dict):
                continue
            scope = entry.get("scope")
            model = scope.get("model") if isinstance(scope, dict) else None
            if not isinstance(model, dict):
                continue
            name = str(model.get("display_name") or model.get("id") or "").strip()
            kind = str(entry.get("kind") or "").strip()
            if not name or (name, kind) in seen:
                continue
            percent = normalize_utilization(entry.get("percent"), percent_scale)
            if percent < 0:
                continue
            seen.add((name, kind))
            window = scoped_window(kind)
            title = f"{name} {window}" if window else name
            limits.append(
                {
                    "label": title,
                    "title": title,
                    "percent": percent,
                    "resetsAt": normalize_reset_at(entry.get("resets_at")),
                }
            )
    return limits


def limit_window_open(entry: dict[str, Any]) -> bool:
    raw = str(entry.get("resetsAt") or "")
    if not raw:
        return True
    try:
        reset = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if reset.tzinfo is None:
            reset = reset.replace(tzinfo=dt.timezone.utc)
        return reset > dt.datetime.now(dt.timezone.utc)
    except Exception:
        return True


def cached_limits(cache_file: Path, fallback_file: Path | None = None) -> tuple[list[dict[str, Any]], int]:
    cached = read_json(cache_file)
    if not cached and fallback_file is not None:
        cached = read_json(fallback_file)
    entries = cached.get("limits")
    limits = [entry for entry in entries or [] if isinstance(entry, dict) and limit_window_open(entry)]
    return limits, number(cached.get("fetchedAtMs"))


def collect_claude(args: argparse.Namespace, account_home: Path, cache_file: Path) -> dict[str, Any]:
    credentials = read_json(account_home / ".credentials.json")
    login = credentials.get("claudeAiOauth")
    login = login if isinstance(login, dict) else {}
    access_token = str(login.get("accessToken") or "")
    expires_at = number(login.get("expiresAt"))
    tier = plan_label(str(login.get("rateLimitTier") or ""), str(login.get("subscriptionType") or ""))

    stock_cache = None
    if args.account_id == "claude-1":
        stock_cache = Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")) / "omarchy" / "agent-usage" / "claude-limits.json"
    fallback, fetched_at = cached_limits(cache_file, stock_cache)

    result: dict[str, Any] = {
        "tierLabel": tier,
        "limits": fallback,
        "usageStatusText": "",
        "authHelpText": args.login_hint,
    }
    if not access_token:
        result["usageStatusText"] = "Waiting for auth"
        return result
    if expires_at > 0 and expires_at <= time.time() * 1000:
        result["usageStatusText"] = "Sign-in expired"
        result["authHelpText"] = (
            f"{args.name}'s saved sign-in expired"
            + (" — showing the last known limits." if fallback else ".")
            + f" {args.login_hint}"
        )
        return result
    if fallback and not args.force and time.time() - fetched_at / 1000 < 15:
        return result

    request = urllib.request.Request(
        CLAUDE_USAGE_ENDPOINT,
        headers={
            "Authorization": "Bearer " + access_token,
            "anthropic-beta": "oauth-2025-04-20",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = json.loads(response.read().decode("utf-8", errors="replace"))
        limits = parse_claude_limits(payload if isinstance(payload, dict) else {})
        if limits:
            result["limits"] = limits
            write_json(cache_file, {"fetchedAtMs": round(time.time() * 1000), "limits": limits})
        elif not fallback:
            result["usageStatusText"] = "Claude limits unavailable"
            result["authHelpText"] = "Anthropic's usage endpoint returned no limits."
    except urllib.error.HTTPError as error:
        if not fallback:
            result["usageStatusText"] = "Claude limits unavailable"
        if error.code == 429:
            result["authHelpText"] = "Anthropic is rate limiting usage checks; local combined usage remains available."
        else:
            result["authHelpText"] = f"Anthropic's usage endpoint returned status {error.code}."
    except Exception:
        if not fallback:
            result["usageStatusText"] = "Claude limits unavailable"
        result["authHelpText"] = "Could not reach Anthropic's usage endpoint; local combined usage remains available."
    return result


def rpc_request(process: subprocess.Popen[str], request_id: int, method: str, params: dict[str, Any] | None = None, timeout: float = 6) -> dict[str, Any]:
    assert process.stdin is not None
    assert process.stdout is not None
    payload: dict[str, Any] = {"id": request_id, "method": method}
    if params is not None:
        payload["params"] = params
    process.stdin.write(json.dumps(payload) + "\n")
    process.stdin.flush()
    deadline = time.time() + timeout
    while time.time() < deadline:
        ready, _, _ = select.select([process.stdout], [], [], 0.25)
        if not ready:
            continue
        line = process.stdout.readline()
        if not line:
            break
        try:
            message = json.loads(line)
        except Exception:
            continue
        if message.get("id") == request_id:
            return message
    raise TimeoutError(method)


def codex_limit_window(window: Any) -> dict[str, Any] | None:
    if not isinstance(window, dict) or window.get("usedPercent") is None:
        return None
    minutes = number(window.get("windowDurationMins"))
    if minutes == 10080:
        label = "Weekly (7-day)"
    elif minutes and minutes % 60 == 0:
        label = f"{minutes // 60}h window"
    elif minutes:
        label = f"{minutes}m window"
    else:
        label = "Limit"
    reset = number(window.get("resetsAt"))
    return {
        "label": label,
        "percent": float(window["usedPercent"]) / 100.0,
        "resetsAt": dt.datetime.fromtimestamp(reset, dt.timezone.utc).isoformat() if reset else "",
    }


def collect_codex(args: argparse.Namespace, account_home: Path) -> dict[str, Any]:
    result: dict[str, Any] = {
        "tierLabel": "",
        "limits": [],
        "usageStatusText": "",
        "authHelpText": args.login_hint,
    }
    if not (account_home / "auth.json").exists():
        result["usageStatusText"] = "Waiting for auth"
        return result
    codex = shutil.which("codex")
    if codex is None:
        result["usageStatusText"] = "Codex unavailable"
        result["authHelpText"] = "codex not found in PATH"
        return result

    environment = os.environ.copy()
    environment["CODEX_HOME"] = str(account_home)
    process: subprocess.Popen[str] | None = None
    try:
        process = subprocess.Popen(
            [codex, "-s", "read-only", "-a", "never", "app-server"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            env=environment,
        )
        rpc_request(process, 1, "initialize", {"clientInfo": {"name": "melonamin.multi-agents", "version": "0.1.0"}}, timeout=8)
        assert process.stdin is not None
        process.stdin.write(json.dumps({"method": "initialized", "params": {}}) + "\n")
        process.stdin.flush()
        account_message = rpc_request(process, 2, "account/read", timeout=5)
        limits_message = rpc_request(process, 3, "account/rateLimits/read", timeout=5)
        account = (account_message.get("result") or {}).get("account") or {}
        rate_limits = (limits_message.get("result") or {}).get("rateLimits") or {}
        plan = rate_limits.get("planType") or account.get("planType") or account.get("type") or ""
        result["tierLabel"] = str(plan)
        for window in (rate_limits.get("primary"), rate_limits.get("secondary")):
            parsed = codex_limit_window(window)
            if parsed is not None:
                result["limits"].append(parsed)
        if not account and not result["limits"]:
            result["usageStatusText"] = "Waiting for auth"
    except Exception as error:
        result["usageStatusText"] = "Codex limits unavailable"
        result["authHelpText"] = f"{args.login_hint} ({type(error).__name__})"
    finally:
        if process is not None:
            try:
                process.terminate()
                process.wait(timeout=1)
            except Exception:
                try:
                    process.kill()
                except Exception:
                    pass
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", choices=("claude", "codex"), required=True)
    parser.add_argument("--account-id", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--selector-label", required=True)
    parser.add_argument("--home", required=True)
    parser.add_argument("--sort-order", type=int, required=True)
    parser.add_argument("--launch-command", required=True)
    parser.add_argument("--login-hint", required=True)
    parser.add_argument("--cache-dir", required=True)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    account_home = Path(os.path.expandvars(os.path.expanduser(args.home))).resolve()
    cache_file = Path(args.cache_dir) / f"{args.account_id}-limits.json"
    details = (
        collect_claude(args, account_home, cache_file)
        if args.provider == "claude"
        else collect_codex(args, account_home)
    )
    record: dict[str, Any] = {
        "schemaVersion": 1,
        "id": args.account_id,
        "name": args.name,
        "providerKind": args.provider,
        "iconId": args.provider,
        "selectorLabel": args.selector_label,
        "viewKind": "account",
        "sortOrder": args.sort_order,
        "launchCommand": args.launch_command,
        "updatedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "ready": True,
        "hasLocalStats": False,
        "hasPromptStats": False,
        "recentDays": [],
        "modelUsage": {},
    }
    record.update(details)
    print(json.dumps(record, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
