#!/bin/bash
# Claude Code voice kit (macOS): hands-free dictation ("Oye Claude") and spoken answers.
# Everything runs locally: whisper.cpp for speech-to-text, Piper for text-to-speech.
# Safe to run again: it only downloads or rewires what is missing or out of date.

set -e

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Claude voice kit: macOS only for now, skipping."
    exit 0
fi

VOICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
WHISPER_DIR="$HOME/.local/share/whisper-models"
PIPER_HOME="$HOME/.local/share/piper"
PIPER_VERSION="1.8.0"   # claude-speak-synth relies on this version's Python API

backup_if_real() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "Backing up existing $target to $target.backup"
        cp -R "$target" "$target.backup"
    fi
}

# download URL DEST SHA256: skipped when DEST already has the expected checksum.
download() {
    local url="$1" dest="$2" sum="$3"
    if [ -f "$dest" ] && [ "$(shasum -a 256 "$dest" | cut -d' ' -f1)" = "$sum" ]; then
        return
    fi
    echo "Downloading $(basename "$dest")..."
    mkdir -p "$(dirname "$dest")"
    curl -fL --progress-bar -o "$dest.part" "$url"
    if [ "$(shasum -a 256 "$dest.part" | cut -d' ' -f1)" != "$sum" ]; then
        rm -f "$dest.part"
        echo "Checksum mismatch for $(basename "$dest"), aborting." >&2
        exit 1
    fi
    mv "$dest.part" "$dest"
}

echo "Installing Claude voice kit..."

# 1. Tools
if ! command -v brew >/dev/null 2>&1; then
    echo "brew is required for the voice kit (whisper-cpp, sox, switchaudio-osx, jq)." >&2
    exit 1
fi
for formula in whisper-cpp sox switchaudio-osx jq; do
    brew list --formula "$formula" >/dev/null 2>&1 || brew install "$formula"
done
command -v python3 >/dev/null 2>&1 || brew install python

# 2. Piper (neural TTS) in its own virtualenv
if [ ! -x "$PIPER_HOME/venv/bin/python" ]; then
    python3 -m venv "$PIPER_HOME/venv"
fi
if ! "$PIPER_HOME/venv/bin/pip" show piper-tts 2>/dev/null | grep -qx "Version: $PIPER_VERSION"; then
    echo "Installing piper-tts $PIPER_VERSION..."
    "$PIPER_HOME/venv/bin/pip" install --quiet "piper-tts==$PIPER_VERSION"
fi

# 3. Models (~1.7 GB, verified by checksum)
download "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin" \
    "$WHISPER_DIR/ggml-large-v3-turbo.bin" 1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69
download "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin" \
    "$WHISPER_DIR/ggml-silero-v5.1.2.bin" 29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf
PIPER_VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/sharvard/medium"
download "$PIPER_VOICE_URL/es_ES-sharvard-medium.onnx" \
    "$PIPER_HOME/voices/es_ES-sharvard-medium.onnx" 40febfb1679c69a4505ff311dc136e121e3419a13a290ef264fdf43ddedd0fb1
download "$PIPER_VOICE_URL/es_ES-sharvard-medium.onnx.json" \
    "$PIPER_HOME/voices/es_ES-sharvard-medium.onnx.json" 7438c9b699c72b0c3388dae1b68d3f364dc66a2150fe554a1c11f03372957b2c

# 4. Scripts, hook, slash command and pronunciation dictionary (symlinked, so git pull updates them)
mkdir -p "$BIN_DIR" "$HOME/.claude/hooks" "$HOME/.claude/commands" "$HOME/.config/claude-voice"
for script in "$VOICE_DIR"/bin/*; do
    backup_if_real "$BIN_DIR/$(basename "$script")"
    ln -sf "$script" "$BIN_DIR/$(basename "$script")"
done
backup_if_real "$HOME/.claude/hooks/on-stop-say.sh"
ln -sf "$VOICE_DIR/hooks/on-stop-say.sh" "$HOME/.claude/hooks/on-stop-say.sh"
backup_if_real "$HOME/.claude/commands/claude-voice.md"
ln -sf "$VOICE_DIR/commands/claude-voice.md" "$HOME/.claude/commands/claude-voice.md"
backup_if_real "$HOME/.config/claude-voice/pronunciations.txt"
ln -sf "$VOICE_DIR/pronunciations.txt" "$HOME/.config/claude-voice/pronunciations.txt"

# 5. Hooks in ~/.claude/settings.json: drop any previous copy of ours, then add the current one
SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
TMP=$(mktemp)
jq '
  def without($pattern): [ (. // [])[] | .hooks = ((.hooks // []) | map(select((.command // "") | test($pattern) | not))) | select(.hooks | length > 0) ];
  .hooks.Stop = ((.hooks.Stop | without("on-stop-say\\.sh"))
    + [{"matcher": "", "hooks": [{"type": "command", "command": "bash \"$HOME/.claude/hooks/on-stop-say.sh\"", "timeout": 10}]}])
  | .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit | without("claude-speak\"? stop"))
    + [{"matcher": "", "hooks": [{"type": "command", "command": "\"$HOME/.local/bin/claude-speak\" stop; exit 0", "timeout": 5}]}])
' "$SETTINGS" > "$TMP" || { rm -f "$TMP"; echo "Could not update $SETTINGS (jq failed); hooks NOT installed." >&2; exit 1; }
# Write through the file instead of mv, so a symlinked settings.json keeps pointing where it did.
cat "$TMP" > "$SETTINGS" && rm -f "$TMP"
echo "Voice hooks wired into $SETTINGS"

cat <<'EOF'

Claude voice kit installed. Remaining manual steps:
  1. System Settings > Privacy & Security: allow your terminal app under Microphone
     and Accessibility (Accessibility lets dictation press Cmd+V and Enter).
  2. Calibrate the microphone:            claude-voice --calibrate
  3. In Claude Code, open /hooks (or restart it) to load the new hooks.
  4. Use it:  /claude-voice on | off | status      /claude-voice summary on | off

Personal overrides go in ~/.config/claude-voice.conf, for example:
  CLAUDE_VOICE_APP=ghostty                     # app that must be focused to paste
  CLAUDE_VOICE_HEADSET_RE="corsair|airpods"    # outputs where you can talk over the reading
EOF
