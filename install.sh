#!/bin/bash

set -e

echo "Installing dotfiles..."

OS_TYPE="$(uname -s)"

if [ "$OS_TYPE" = "Darwin" ]; then
    # Bootstrap Homebrew (portable: Apple Silicon -> /opt/homebrew, Intel -> /usr/local)
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        echo "Homebrew not found. Installing..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
fi

# Nerd Font for Powerline glyphs (agnoster / p10k). Without it the prompt shows tofu boxes.
if [ "$OS_TYPE" = "Darwin" ]; then
    if command -v brew >/dev/null 2>&1; then
        if ! ls "$HOME/Library/Fonts"/MesloLGS* >/dev/null 2>&1 && ! ls "/Library/Fonts"/MesloLGS* >/dev/null 2>&1; then
            echo "Installing MesloLGS Nerd Font..."
            brew install --cask font-meslo-lg-nerd-font || echo "Font install failed; run: brew install --cask font-meslo-lg-nerd-font"
        fi
    else
        echo "brew unavailable: install MesloLGS NF manually or the prompt glyphs will be missing."
    fi
elif [ "$OS_TYPE" = "Linux" ]; then
    FONT_DIR="$HOME/.local/share/fonts"
    if ! ls "$FONT_DIR"/MesloLGS* >/dev/null 2>&1; then
        if command -v curl >/dev/null 2>&1 && command -v fc-cache >/dev/null 2>&1; then
            echo "Installing MesloLGS Nerd Font..."
            mkdir -p "$FONT_DIR"
            BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"
            for VARIANT in Regular Bold Italic "Bold%20Italic"; do
                FILE_NAME="MesloLGS NF ${VARIANT//%20/ }.ttf"
                curl -fsSL -o "$FONT_DIR/$FILE_NAME" "$BASE_URL/MesloLGS%20NF%20${VARIANT}.ttf" \
                    || echo "Failed to download $FILE_NAME"
            done
            fc-cache -f "$FONT_DIR" >/dev/null 2>&1
        else
            echo "curl/fontconfig unavailable: install MesloLGS NF manually or the prompt glyphs will be missing."
        fi
    fi
fi

# Install oh-my-zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install custom plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autocomplete" ]; then
    echo "Installing zsh-autocomplete..."
    git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete "$ZSH_CUSTOM/plugins/zsh-autocomplete"
fi

# Backup existing configs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Back up any existing real file (not a symlink) before we overwrite it
backup_if_real() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "Backing up existing $target to $target.backup"
        cp -R "$target" "$target.backup"
    fi
}

# Optionally install a package with the system package manager (brew / apt-get / pacman).
# Usage: pkg_install <label> <brew-pkg> <apt-pkg> <pacman-pkg>
# Asks for consent (default No) and only when stdin is a TTY. Returns 0 only if the user
# accepted and the install succeeded; otherwise warns with the manual command and returns 1.
pkg_install() {
    local label="$1" brew_pkg="$2" apt_pkg="$3" pacman_pkg="$4" cmd=""
    if [ "$OS_TYPE" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
        cmd="brew install $brew_pkg"
    elif command -v apt-get >/dev/null 2>&1; then
        cmd="sudo apt-get install -y $apt_pkg"
    elif command -v pacman >/dev/null 2>&1; then
        cmd="sudo pacman -S --noconfirm $pacman_pkg"
    else
        echo "No supported package manager (brew/apt-get/pacman) found: install $label manually."
        return 1
    fi

    local reply="n"
    if [ -t 0 ]; then
        read -r -p "Install $label via '$cmd'? [y/N] " reply
    else
        echo "Non-interactive shell: skipping $label install. Run '$cmd' manually if you want it."
        return 1
    fi
    case "$reply" in
        [Yy]*)
            $cmd || { echo "$label install failed; run: $cmd"; return 1; }
            ;;
        *)
            echo "Skipping $label. Install it manually with: $cmd"
            return 1
            ;;
    esac
}

backup_if_real "$HOME/.zshrc"
backup_if_real "$HOME/.p10k.zsh"

# Create symlinks
echo "Creating symlinks..."
ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$SCRIPT_DIR/.p10k.zsh" "$HOME/.p10k.zsh"

# Claude Code statusline
mkdir -p "$HOME/.claude"
ln -sf "$SCRIPT_DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"
if ! command -v jq >/dev/null 2>&1; then
    pkg_install jq jq jq jq || true
fi
if command -v jq >/dev/null 2>&1; then
    SETTINGS="$HOME/.claude/settings.json"
    [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
    TMP=$(mktemp)
    jq '.statusLine = {"type": "command", "command": "bash \"$HOME/.claude/statusline.sh\""}' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
    echo "Claude Code statusline wired into $SETTINGS"
else
    echo "jq not found: add this to ~/.claude/settings.json manually"
    echo '  "statusLine": { "type": "command", "command": "bash \"$HOME/.claude/statusline.sh\"" }'
fi

# Ghostty
if [ "$OS_TYPE" = "Darwin" ]; then
    GHOSTTY_CONFIG_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
    GHOSTTY_CONFIG_PATH="$GHOSTTY_CONFIG_DIR/config.ghostty"
else
    GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
    GHOSTTY_CONFIG_PATH="$GHOSTTY_CONFIG_DIR/config"
fi
mkdir -p "$GHOSTTY_CONFIG_DIR"
backup_if_real "$GHOSTTY_CONFIG_PATH"
ln -sf "$SCRIPT_DIR/ghostty/config.ghostty" "$GHOSTTY_CONFIG_PATH"

# Terminal.app profile (macOS only)
if [ "$OS_TYPE" = "Darwin" ]; then
    if command -v open >/dev/null 2>&1 && command -v defaults >/dev/null 2>&1; then
        open "$SCRIPT_DIR/Basic.terminal"
        sleep 1
        defaults write com.apple.Terminal "Default Window Settings" -string "Basic 1"
        defaults write com.apple.Terminal "Startup Window Settings" -string "Basic 1"
        echo "Terminal.app profile 'Basic' imported and set as default (check Terminal > Settings if the name differs)"
    fi
fi

# Herdr: persistent sessions + AI agent notifications (.zshrc auto-attaches new terminals to it)
if [ "$OS_TYPE" = "Darwin" ]; then
    if command -v brew >/dev/null 2>&1; then
        if ! command -v herdr >/dev/null 2>&1; then
            echo "Installing herdr..."
            brew install herdr || echo "herdr install failed; run: brew install herdr"
        fi
    else
        echo "brew unavailable: install herdr manually (https://herdr.dev) or the auto-attach in .zshrc will no-op."
    fi
elif [ "$OS_TYPE" = "Linux" ]; then
    if ! command -v herdr >/dev/null 2>&1; then
        # Herdr changes how every new terminal behaves (auto-attach exec in .zshrc), so on Linux
        # we ask first instead of installing it silently like the macOS/brew path does.
        HERDR_REPLY="n"
        if [ -t 0 ]; then
            read -r -p "Install Herdr (persistent terminal sessions + AI agent notifications, https://herdr.dev)? [y/N] " HERDR_REPLY
        else
            echo "Non-interactive shell: skipping Herdr install prompt. Run 'curl -fsSL https://herdr.dev/install.sh | sh' manually if you want it."
        fi
        case "$HERDR_REPLY" in
            [Yy]*)
                echo "Installing herdr..."
                curl -fsSL https://herdr.dev/install.sh | sh || echo "herdr install failed; run: curl -fsSL https://herdr.dev/install.sh | sh"
                # The installer drops the binary in ~/.local/bin, which may not be on PATH yet for this run;
                # without it every later `command -v herdr` step (config, plugins, sessions) would be skipped.
                if [ -x "$HOME/.local/bin/herdr" ]; then
                    export PATH="$HOME/.local/bin:$PATH"
                fi
                ;;
            *)
                echo "Skipping herdr. The auto-attach block in .zshrc will no-op until you install it manually (https://herdr.dev)."
                ;;
        esac
    fi
fi

if command -v herdr >/dev/null 2>&1; then
    # Herdr config (theme, notifications). A real file is backed up before being replaced by the symlink.
    mkdir -p "$HOME/.config/herdr"
    backup_if_real "$HOME/.config/herdr/config.toml"
    ln -sf "$SCRIPT_DIR/herdr/config.toml" "$HOME/.config/herdr/config.toml"
fi

# Herdr plugins, pinned by commit. Each one is optional and asks for consent (default No, TTY only).
# Herdr itself may still show its own confirmation; --yes is deliberately not passed.
# Usage: herdr_plugin_install <label> <owner/repo> <commit>
herdr_plugin_install() {
    local label="$1" repo="$2" ref="$3"
    local cmd="herdr plugin install $repo --ref $ref"
    if herdr plugin list 2>/dev/null | grep -q "github:$repo@"; then
        echo "Herdr plugin $label already installed."
        return 0
    fi
    local reply="n"
    if [ -t 0 ]; then
        read -r -p "Install Herdr plugin $label via '$cmd'? [y/N] " reply
    else
        echo "Non-interactive shell: skipping Herdr plugin $label. Run '$cmd' manually if you want it."
        return 0
    fi
    case "$reply" in
        [Yy]*) $cmd || echo "Herdr plugin $label install failed; run: $cmd" ;;
        *) echo "Skipping Herdr plugin $label. Install it manually with: $cmd" ;;
    esac
}

if command -v herdr >/dev/null 2>&1; then
    # auto-title builds from source and needs Go 1.24+ (distro packages are often older, e.g. Ubuntu 24.04 ships 1.22).
    go_is_recent_enough() {
        local ver
        ver="$(go version 2>/dev/null | sed -n 's/.*go\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')"
        [ -n "$ver" ] && [ "$(printf '%s\n1.24\n' "$ver" | sort -V | head -n1)" = "1.24" ]
    }
    AUTO_TITLE_CMD="herdr plugin install kryptamine/herdr-auto-title --ref 899ee4e4c827129c9920c105f250628ff967ca98"
    AUTO_TITLE_INSTALLED=0
    herdr plugin list 2>/dev/null | grep -q "github:kryptamine/herdr-auto-title@" && AUTO_TITLE_INSTALLED=1
    if [ "$AUTO_TITLE_INSTALLED" -eq 0 ] && ! command -v go >/dev/null 2>&1; then
        echo "The Herdr auto-title plugin needs Go 1.24+ to build."
        pkg_install Go go golang go || true
    fi
    if [ "$AUTO_TITLE_INSTALLED" -eq 1 ] || go_is_recent_enough; then
        herdr_plugin_install "auto-title (automatic tab titles)" kryptamine/herdr-auto-title 899ee4e4c827129c9920c105f250628ff967ca98
    else
        echo "Go 1.24+ not available (found: $(go version 2>/dev/null || echo none)): skipping Herdr plugin auto-title."
        echo "  Install a recent Go (https://go.dev/dl) and then run: $AUTO_TITLE_CMD"
    fi
    herdr_plugin_install "reviewr (code review pane)" persiyanov/herdr-reviewr 4c090225af706bf3aaa24b39fea890a72994f40f
fi

# Optional: one Herdr session per directory. Opt-in via HERDR_SESSION_PER_PATH in ~/.zshrc.local
# (sourced by .zshrc before the auto-attach block). Default behavior stays a single shared session.
if command -v herdr >/dev/null 2>&1; then
    SESSION_LINE='export HERDR_SESSION_PER_PATH=1'
    if grep -qsF "$SESSION_LINE" "$HOME/.zshrc.local"; then
        echo "Per-directory Herdr sessions already enabled in ~/.zshrc.local."
    elif [ -t 0 ]; then
        read -r -p "Use one Herdr session per directory (a new space for each project path)? [y/N] " SESSION_REPLY
        case "$SESSION_REPLY" in
            [Yy]*) echo "$SESSION_LINE" >> "$HOME/.zshrc.local" && echo "Enabled per-directory Herdr sessions in ~/.zshrc.local." \
                || echo "Could not write ~/.zshrc.local; add this line manually: $SESSION_LINE" ;;
            *) echo "Keeping a single shared Herdr session. To enable per-directory sessions later, add to ~/.zshrc.local: $SESSION_LINE" ;;
        esac
    else
        echo "Non-interactive shell: keeping a single shared Herdr session. To enable per-directory sessions, add to ~/.zshrc.local: $SESSION_LINE"
    fi
fi

if command -v herdr >/dev/null 2>&1 && command -v claude >/dev/null 2>&1; then
    herdr integration install claude || true
fi

# Claude Code voice kit (macOS): local dictation + spoken answers. Opt-in: it downloads ~1.7 GB
# of models and needs Microphone and Accessibility permissions.
if [ "$OS_TYPE" = "Darwin" ]; then
    VOICE_REPLY="n"
    if [ -t 0 ]; then
        read -r -p "Install the Claude Code voice kit (\"Oye Claude\" dictation + spoken answers, ~1.7 GB)? [y/N] " VOICE_REPLY
    else
        echo "Non-interactive shell: skipping the Claude voice kit. Run '$SCRIPT_DIR/claude/voice/install.sh' manually if you want it."
    fi
    case "$VOICE_REPLY" in
        [Yy]*) bash "$SCRIPT_DIR/claude/voice/install.sh" || echo "Voice kit install failed; rerun: $SCRIPT_DIR/claude/voice/install.sh" ;;
        *) echo "Skipping the Claude voice kit." ;;
    esac
fi

echo "Done! Restart your terminal or run: source ~/.zshrc"
