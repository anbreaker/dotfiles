# Dotfiles

Personal zsh, terminal and Claude Code configuration.

## What's included

- `.zshrc` - Main zsh config (oh-my-zsh + agnoster theme)
- `.p10k.zsh` - Powerlevel10k config (optional)
- `Basic.terminal` - Terminal.app profile (colors, font, cursor)
- `ghostty/config.ghostty` - Ghostty terminal config
- `claude/statusline.sh` - Claude Code statusline (powerline + rate limits bar)
- `herdr/config.toml` - Herdr config (theme, notifications), linked to `~/.config/herdr/config.toml`
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
- `jq` is needed for the Claude Code statusline wiring; if missing, `install.sh` offers to install it
  (see [Herdr config, plugins and package managers](#herdr-config-plugins-and-package-managers)), or run
  `sudo apt install jq` yourself and re-run `install.sh`, or add the `statusLine` block manually (see
  below).
- Tested on Ubuntu. Debian-based distros (e.g. Parrot) use the same `apt-get` path, and Arch uses
  `pacman`; the optional installs below are detected by package manager, not by distro name.
  Parrot and Arch are not tested.
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

#### Herdr config, plugins and package managers

Everything here is **optional**: each step asks `[y/N]` (default No), only when stdin is a TTY, and
on decline, non-interactive runs or failure it prints the exact manual command and continues. A step that
is already done (config already linked, plugin already installed) is skipped without asking.

- **Config** — if `herdr` is installed, `install.sh` asks before linking `herdr/config.toml` to
  `~/.config/herdr/config.toml`. Accepting replaces any existing config with this repo's theme/panel
  settings (a real existing file is backed up to `config.toml.backup` first). If the target already
  links to the repo file it prints "already linked" and does not ask. Rollback: delete the symlink.
- **Plugins** (pinned by commit, skipped if already in `herdr plugin list`):

  | Plugin | Purpose | Command |
  | --- | --- | --- |
  | `kryptamine/herdr-auto-title` | automatic tab titles; **builds with Go** | `herdr plugin install kryptamine/herdr-auto-title --ref 899ee4e4c827129c9920c105f250628ff967ca98` |
  | `persiyanov/herdr-reviewr` | code review pane | `herdr plugin install persiyanov/herdr-reviewr --ref 4c090225af706bf3aaa24b39fea890a72994f40f` |

  If `go` is missing, `install.sh` offers to install it first; without Go the auto-title plugin is skipped.
- **Package managers** — `jq` and `go` are installed through whichever of these is found, after showing
  the exact command and asking first:

  | OS | Manager | Command |
  | --- | --- | --- |
  | macOS | Homebrew | `brew install <pkg>` |
  | Ubuntu / Debian / Parrot | apt | `sudo apt-get install -y <pkg>` (Go is `golang`) |
  | Arch | pacman | `sudo pacman -S --noconfirm <pkg>` |
  | Windows | winget | `winget install -e --id GoLang.Go` |

- **Spaces vs sessions** — Herdr has two different levels, and the two opt-ins below act on different ones:

  | | Space (workspace) | Session |
  | --- | --- | --- |
  | What it is | a `herdr workspace`, created inside the session you are already in | a separate Herdr server (`herdr --session <name>`) |
  | Opt-in flag | `HERDR_AUTO_WORKSPACES=1` | `HERDR_SESSION_PER_PATH=1` |
  | Visibility | all spaces live side by side in the same session | each session only sees its own workspaces |
  | Defined in | `herdr/workspaces.zsh` | the auto-attach block in `.zshrc` |

  Both flags go in `~/.zshrc.local`, which `.zshrc` sources before the auto-attach block. Both default
  to off, and `install.sh` offers each one with its own `[y/N]` prompt (TTY only).

- **Per-directory sessions (opt-in)** — by default every new terminal runs plain `herdr` (one shared
  session), exactly as before. If you answer yes to the prompt in `install.sh` (or add
  `export HERDR_SESSION_PER_PATH=1` to `~/.zshrc.local` yourself), `.zshrc` runs
  `herdr --session <folder-slug>-<6-char-hash-of-path>` instead, so each project directory gets its
  own separate session (its own server) and reopening a terminal there reattaches to it. Workspaces
  are not shared between these sessions. `.zshrc` now sources
  `~/.zshrc.local` (if present) before the auto-attach block; keep personal settings there. On
  Windows this zsh variable does not apply (no code in `install.ps1`).
- **Auto-created spaces (opt-in)** — with `export HERDR_AUTO_WORKSPACES=1` in `~/.zshrc.local` (or by
  answering yes to the `install.sh` prompt), `.zshrc` sources `herdr/workspaces.zsh` (resolved through
  the `~/.zshrc` symlink, so it works from the repo). It needs **zsh and `jq`**, and only acts inside
  Herdr (`HERDR_ENV` set); without the flag nothing is defined. It adds two things, both creating
  spaces in the *current* session with `herdr workspace create`:
  - **`cd` hook** — when you `cd` into a different git root, a space labelled with the repo folder
    name is created, unless one with that label already exists. Moving around inside the same project
    does nothing.
  - **Agent wrapper** — `claude`, `agy`, `grok` and `opencode` launched interactively (no args, or
    flags only) from a project other than the current space's open a new space rooted there and run
    the agent in it. Same project, `-p/--print`, `--version`, `--help` and positional prompts or
    subcommands run in place. If a space with that label already exists, the wrapper **focuses it
    instead of creating a duplicate and does not launch the agent** (run it from that space). Bypass a
    single call with `command claude`.

  Known limitation: both mechanisms match spaces by **folder name only**, so two repos with the same
  basename in different paths share one space.

  Both use `--focus`, so Herdr **moves your focus to the new space**; delete `--focus` in
  `herdr/workspaces.zsh` to create spaces in the background. The helper `__herdr_agent_redirect <cmd> "$@"`
  is reusable: machine-specific wrappers (for example a `gemini` one with your own env or NVM setup)
  are not included and belong in `~/.zshrc.local`, calling that function and falling back to
  `command <cmd>`. Rollback: remove the flag and open a new terminal.
- **Windows is untested** — `windows/install.ps1` has the equivalent config link (assumes
  `%USERPROFILE%\.config\herdr`, with a `Read-Host` consent), the same two pinned plugins with a `Read-Host` consent, and Go via
  `winget` (`GoLang.Go`), but none of it has been run on a real Windows machine.
