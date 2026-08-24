#!/usr/bin/env python3
"""Turn a hermes session export (stdin) into a readable transcript digest.

`hermes sessions export` emits one large JSON document per session. Feeding a
byte-tail of that to the coach model hands it *malformed* JSON — it then burns
its whole run trying to re-parse the file instead of distilling the session.
This script parses the export properly and writes plain chronological text:
one line per message (role, content, tool calls, tool results), truncated per
line and capped overall so the coach always gets valid, readable evidence.
"""
import json
import sys

MAX_FIELD = 500          # per-field truncation
MAX_OUTPUT = 80_000      # keep the END of the session if over budget


def find_messages(obj):
    """Depth-first search for the first list of dicts that look like messages."""
    if isinstance(obj, list):
        if obj and isinstance(obj[0], dict) and "role" in obj[0]:
            return obj
        for item in obj:
            found = find_messages(item)
            if found:
                return found
    elif isinstance(obj, dict):
        for value in obj.values():
            found = find_messages(value)
            if found:
                return found
    return None


def trunc(text, limit=MAX_FIELD):
    text = " ".join(str(text).split())
    return text if len(text) <= limit else text[:limit] + "…"


def digest_message(msg):
    role = msg.get("role", "?")
    lines = []
    content = msg.get("content")
    if content:
        lines.append(f"[{role}] {trunc(content)}")
    elif msg.get("reasoning"):
        lines.append(f"[{role} thinking] {trunc(msg['reasoning'], 200)}")
    for call in msg.get("tool_calls") or []:
        fn = call.get("function") or {}
        lines.append(f"[{role}->tool] {fn.get('name', '?')} {trunc(fn.get('arguments', ''), 300)}")
    if role == "tool" and content:
        # already emitted above, but tag which tool answered
        lines[-1] = f"[tool:{msg.get('tool_name', '?')}] {trunc(content, 300)}"
    return lines


def main():
    out = []
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            doc = json.loads(line)
        except json.JSONDecodeError:
            continue
        for msg in find_messages(doc) or []:
            if isinstance(msg, dict):
                out.extend(digest_message(msg))
    text = "\n".join(out)
    if len(text) > MAX_OUTPUT:
        text = "(…start of session trimmed…)\n" + text[-MAX_OUTPUT:]
    sys.stdout.write(text + "\n")


if __name__ == "__main__":
    main()
