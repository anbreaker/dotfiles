#!/usr/bin/env bash
# Stop hook — reads the final assistant message aloud.
# Cleaning and truncation happen in claude-speak (see claude-speak-normalize).
# Mute with: claude-voice-toggle summary off   (or /claude-voice summary off)
set -uo pipefail

FLAG="$HOME/.cache/claude-voice/no-summary"
[ -f "$FLAG" ] && exit 0

message="$(jq -r '.last_assistant_message // empty')"
[ -z "$message" ] && exit 0

export CLAUDE_SPEAK_MAX="${CLAUDE_SAY_MAX:-1500}"
if [ -n "${CLAUDE_SAY_DRY:-}" ]; then
  CLAUDE_SPEAK_DRY=1 "$HOME/.local/bin/claude-speak" "$message"
  exit 0
fi

nohup "$HOME/.local/bin/claude-speak" "$message" </dev/null >/dev/null 2>&1 &
exit 0
