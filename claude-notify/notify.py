#!/usr/bin/env python3
"""Claude Code notification hook for macOS.

Local toast (osascript or terminal-notifier) + optional Bark push (https://day.app).

Usage: notify.py <Stop|Notification|...>

Reads JSON from stdin (Claude Code hook payload):
  cwd               -> current working directory
  transcript_path   -> path to JSONL transcript (Stop event)
  message           -> notification message (Notification event)

Environment variables (all optional):
  BARK_KEY            Bark device key. If unset, Bark push is skipped.
  BARK_SERVER         Bark server (default: https://api.day.app).
  BARK_GROUP          Notification group (default: ClaudeCode).
  BARK_SOUND          Notification sound (default: minuet).
  BARK_ICON           Custom icon URL.
  BARK_STOP_LEVEL     Level for Stop events (default: passive).
  BARK_NOTIFY_LEVEL   Level for Notification events (default: timeSensitive).
                      Valid: active | timeSensitive | passive | critical.
  CLAUDE_NOTIFY_OFF   If set to "1", suppress all notifications.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

TITLE_PREFIX = "ClaudeCode"
MAX_BODY_LEN = 200


def read_stdin_json() -> dict:
    try:
        raw = sys.stdin.read()
    except Exception:
        return {}
    if not raw.strip():
        return {}
    try:
        return json.loads(raw)
    except Exception:
        return {}


def last_assistant_text(transcript_path: str) -> str:
    p = Path(transcript_path)
    if not p.is_file():
        return ""
    try:
        with p.open("r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()[-30:]
    except Exception:
        return ""
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except Exception:
            continue
        msg = entry.get("message") or {}
        if msg.get("role") != "assistant":
            continue
        content = msg.get("content")
        text = ""
        if isinstance(content, str):
            text = content
        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    t = block.get("text", "")
                    if t.strip():
                        text = t
                        break
        if text.strip():
            return text
    return ""


def truncate(s: str, n: int) -> str:
    s = (s or "").strip()
    if len(s) <= n:
        return s
    return s[: n - 1] + "…"


def send_mac_notification(title: str, body: str) -> None:
    # Prefer terminal-notifier when available — clickable, supports group dedup.
    tn = shutil.which("terminal-notifier")
    if tn:
        try:
            subprocess.run(
                [tn, "-title", title, "-message", body,
                 "-sound", "Glass", "-group", "claude-code", "-ignoreDnD"],
                check=False, timeout=5,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            return
        except Exception:
            pass

    # Fallback to osascript — built-in, no install needed.
    def esc(s: str) -> str:
        return s.replace("\\", "\\\\").replace('"', '\\"')

    script = (
        f'display notification "{esc(body)}" '
        f'with title "{esc(title)}" sound name "Glass"'
    )
    try:
        subprocess.run(
            ["osascript", "-e", script],
            check=False, timeout=5,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


def send_bark_push(title: str, body: str, event: str) -> None:
    key = os.environ.get("BARK_KEY", "").strip()
    if not key:
        return

    server = os.environ.get("BARK_SERVER", "https://api.day.app").rstrip("/")

    if event == "Notification":
        level = os.environ.get("BARK_NOTIFY_LEVEL", "timeSensitive")
    elif event == "Stop":
        level = os.environ.get("BARK_STOP_LEVEL", "passive")
    else:
        level = "active"

    payload = {
        "title": title,
        "body": body or " ",
        "group": os.environ.get("BARK_GROUP", "ClaudeCode"),
        "level": level,
        "sound": os.environ.get("BARK_SOUND", "minuet"),
    }
    if icon := os.environ.get("BARK_ICON", "").strip():
        payload["icon"] = icon

    try:
        req = urllib.request.Request(
            f"{server}/{key}",
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            method="POST",
            headers={"Content-Type": "application/json; charset=utf-8"},
        )
        with urllib.request.urlopen(req, timeout=5) as r:
            r.read()
    except Exception:
        pass


def main() -> int:
    if os.environ.get("CLAUDE_NOTIFY_OFF") == "1":
        return 0

    event = sys.argv[1] if len(sys.argv) > 1 else "Stop"
    data = read_stdin_json()

    cwd = data.get("cwd") or ""
    project = os.path.basename(cwd) if cwd else ""

    if event == "Stop":
        title = f"{TITLE_PREFIX} - {project}" if project else TITLE_PREFIX
        body = ""
        transcript = data.get("transcript_path") or ""
        if transcript:
            body = last_assistant_text(transcript)
        if not body.strip():
            body = "Task completed, please review results."
    elif event == "Notification":
        title = f"{TITLE_PREFIX} - Needs Attention"
        if project:
            title = f"{title} - {project}"
        body = (data.get("message") or "").strip() \
            or "Claude is waiting for your input or approval."
    else:
        title = TITLE_PREFIX
        body = f"Event received: {event}"

    body = truncate(body, MAX_BODY_LEN)

    send_mac_notification(title, body)
    send_bark_push(title, body, event)
    return 0


if __name__ == "__main__":
    sys.exit(main())
