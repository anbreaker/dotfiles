# Dotfiles

Personal zsh, terminal and Claude Code configuration.

## What's included

- `.zshrc` - Main zsh config (oh-my-zsh + agnoster theme)
- `.p10k.zsh` - Powerlevel10k config (optional)
- `Basic.terminal` - Terminal.app profile (colors, font, cursor)
- `ghostty/config.ghostty` - Ghostty terminal config
- `claude/statusline.sh` - Claude Code statusline (powerline + rate limits bar)
- `windows/` - PowerShell equivalent for Windows (Oh My Posh + PSReadLine + posh-git)

### Plugins

- git
- zsh-autosuggestions
- zsh-syntax-highlighting
- zsh-autocomplete

## Installation

```bash
git clone https://github.com/reibaj91/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

### Windows (PowerShell)

The macOS zsh stack maps to a PowerShell-native equivalent under `windows/`:

| macOS (zsh) | Windows (PowerShell) |
| --- | --- |
| oh-my-zsh + agnoster | Oh My Posh (`agnoster` theme) |
| zsh-autosuggestions / syntax-highlighting | PSReadLine (Predictive IntelliSense) |
| git plugin | posh-git |
| Homebrew | winget |
| Terminal.app / Ghostty | Windows Terminal |
| MesloLGS NF | MesloLGS Nerd Font Mono (same font, Windows face name) |
| Herdr | Herdr (Windows beta) |

```powershell
git clone https://github.com/reibaj91/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles
Set-ExecutionPolicy -Scope Process Bypass -Force
.\windows\install.ps1
```

`install.ps1` installs the packages via winget, the MesloLGS Nerd Font via Oh My Posh, links the
PowerShell profile, patches Windows Terminal (font + `BasicDotfiles` color scheme matching Ghostty),
and installs Herdr. Notes:

- Symlinking the profile needs Developer Mode or an elevated shell; otherwise it falls back to a copy.
- Herdr on Windows is a **beta/preview** (ConPTY, not the Unix PTY model); `herdr --remote` isn't in
  the beta. For a fully stable experience, run the Linux build inside WSL2.
- The Claude Code statusline (`claude/statusline.sh`) is a bash script and is **not** wired on Windows;
  it needs Git Bash to run there.

### Ubuntu / Debian (zsh)

`install.sh` detects Linux via `uname -s` and swaps out every macOS-only piece for a Linux-native
equivalent — no Homebrew required on Linux at all:

| macOS | Ubuntu / Debian |
| --- | --- |
| Homebrew bootstrap | skipped entirely (nothing in this repo needs it on Linux) |
| `brew install --cask font-meslo-lg-nerd-font` | `.ttf` files downloaded from `romkatv/powerlevel10k-media` into `~/.local/share/fonts` + `fc-cache -f` |
| `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` | `~/.config/ghostty/config` (XDG path) |
| `Basic.terminal` (Terminal.app) | skipped — no equivalent, use Ghostty |
| `brew install herdr` (silent) | asks `Install Herdr? [y/N]` before running `curl -fsSL https://herdr.dev/install.sh \| sh` |

```bash
git clone https://github.com/reibaj91/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

Notes:

- Ghostty itself isn't installed by the script (same as on macOS) — install it separately from
  https://ghostty.org before running `install.sh`, otherwise the config just sits there unused.
- `jq` is needed for the Claude Code statusline wiring. If missing, `install.sh` offers to install
  it via `sudo apt-get install jq` (prompts for confirmation, same pattern as the Herdr prompt).
  Answering "n" or running non-interactively skips it — add the `statusLine` block manually (see
  below) or re-run `install.sh` later.
- Tested on Ubuntu; other Debian-based distros with `apt` should work the same for the manual
  steps above, but the script itself doesn't special-case them beyond the generic `Linux` branch.
- Herdr installs silently on macOS (via brew) but **prompts for confirmation on Linux** before
  running its installer, since it changes how every new terminal behaves (auto-attach). Answering
  "n", pressing enter, or running `install.sh` non-interactively (no TTY on stdin) all skip it —
  the auto-attach block in `.zshrc` just no-ops until Herdr is installed manually later.

## Manual setup (if needed)

### Maven (optional)

If you use Maven, install it and the path in `.zshrc` will work:

```bash
brew install maven
```

Or download manually to `/usr/local/apache-maven`.

### Powerlevel10k (optional)

To enable p10k instead of agnoster, uncomment this line in `.zshrc`:

```bash
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
```

And change the theme:

```bash
ZSH_THEME="powerlevel10k/powerlevel10k"
```

### Claude Code statusline (optional)

`install.sh` symlinks `claude/statusline.sh` to `~/.claude/statusline.sh` and, if `jq` is
installed, wires it into `~/.claude/settings.json` automatically. If `jq` is missing, add this
manually to `~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "bash \"$HOME/.claude/statusline.sh\"" }
```

The script uses `jq` (JSON) and expects Claude Code's native `context_window` / `rate_limits`
fields in the statusline input — no extra setup needed beyond having `jq` installed.

### Nerd Font (required for the prompt)

The `agnoster` theme (and Powerlevel10k) render the prompt with Powerline glyphs — segment
separators, the git branch icon, etc. Without a patched font you'll see `?`-in-a-box placeholders.
Both the Terminal.app profile and the Ghostty config use `MesloLGS NF`. Install the Meslo Nerd Font
family if it's missing:

```bash
# macOS
brew install --cask font-meslo-lg-nerd-font
```

On Linux, `install.sh` downloads the four `MesloLGS NF` `.ttf` files straight from
`romkatv/powerlevel10k-media` into `~/.local/share/fonts` and runs `fc-cache -f` — no Homebrew cask
equivalent exists on Linux, so this is handled with a direct download instead.

### Ghostty (optional)

`install.sh` symlinks `ghostty/config.ghostty` to
`~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` on macOS, or `~/.config/ghostty/config`
on Linux (XDG path). Uses `MesloLGS NF` (see above); change `font-family` if you prefer a different
Nerd Font.

### Herdr (persistent sessions + AI agent notifications)

[Herdr](https://herdr.dev) is a terminal workspace manager: it keeps a persistent session running
in a background server, so closing a terminal window by accident doesn't kill your work, and it
tracks the status (`idle`/`working`/`blocked`) of AI coding agents running inside it, firing sound
notifications on state changes.

Requires `brew install herdr` on macOS, or `curl -fsSL https://herdr.dev/install.sh | sh` on Linux
(no Homebrew needed there). Two pieces:

1. **Auto-attach on every new terminal** — `.zshrc` has a guarded block (search for
   `Auto-attach a Herdr`) that `exec`s into `herdr` on any new interactive shell, unless you're
   already inside tmux/zellij/herdr. It attaches to the existing persistent session or creates one.
   Rollback: comment out or delete that block, then open a new terminal.

2. **Agent integrations** — `herdr integration install claude` (also available: `codex`,
   `opencode`, `cursor`, others — no Gemini CLI support as of this writing) wires each CLI's
   session into Herdr so it can report status and trigger notifications. This adds a single
   `SessionStart` hook to `~/.claude/settings.json` that is a no-op outside of Herdr (gated on
   `$HERDR_ENV`). Rollback: `herdr integration uninstall claude`.

`brew uninstall herdr` removes the binary but leaves the `.zshrc` block and the hook in place —
remove those manually if you uninstall.
