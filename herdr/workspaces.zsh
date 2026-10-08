# Herdr "spaces" (workspaces) created automatically inside the CURRENT Herdr session.
# A space is a `herdr workspace`; this is NOT the per-directory session feature
# (HERDR_SESSION_PER_PATH), which starts a separate Herdr server per directory.
#
# Opt-in: nothing below is defined unless HERDR_AUTO_WORKSPACES=1 (set it in ~/.zshrc.local,
# which .zshrc sources before this file). zsh only. Needs `herdr` and `jq`; without them
# everything here silently does nothing.
# Rollback: unset the flag (or remove the line sourcing this file from .zshrc).

[[ -n ${ZSH_VERSION:-} && ${HERDR_AUTO_WORKSPACES:-} == 1 ]] || return 0

# --- 1. chpwd hook: auto-create a workspace when you cd into another git project ----------
# Fires only when the git root changes (not on every cd inside the same project), to avoid
# piling up junk spaces. Skips creation when a workspace with that label already exists.
__herdr_ws_root() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

__herdr_workspace_autocreate() {
  { [[ -n "$HERDR_ENV" ]] && command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 } || return
  local root label
  root="$(__herdr_ws_root "$PWD")"
  [[ -z "$root" ]] && return
  [[ "$root" == "$__herdr_last_ws_root" ]] && return
  __herdr_last_ws_root="$root"
  label="${root:t}"
  herdr workspace list 2>/dev/null | jq -e --arg l "$label" '.result.workspaces[]? | select(.label == $l)' >/dev/null 2>&1 && return
  herdr workspace create --cwd "$root" --label "$label" --focus >/dev/null 2>&1
}
__herdr_last_ws_root="$(__herdr_ws_root "$PWD")"
autoload -Uz add-zsh-hook
add-zsh-hook chpwd __herdr_workspace_autocreate

# --- 2. Agent wrapper: one workspace per project when launching an agent -------------------
# Launching agy/claude/grok/opencode from a project (git toplevel, or cwd if not a repo)
# different from the current workspace's opens a new workspace rooted there and starts the
# agent in it. In the same project the agent runs normally.
# Only interactive sessions are redirected: no args or flags only (-c, --resume...);
# subcommands/positional prompts and -p/--print/--version/--help run in place.
# Bypass a single call with `command claude`.
# Machine-specific wrappers (e.g. gemini) can call __herdr_agent_redirect from ~/.zshrc.local.
__herdr_agent_redirect() {
  local kind=$1; shift
  [[ ${HERDR_ENV:-} == 1 && -t 0 && -t 1 ]] || return 1
  (( $+commands[herdr] && $+commands[jq] )) || return 1
  [[ -z ${1:-} || $1 == -* ]] || return 1
  local a
  for a in "$@"; do
    case $a in -p|--print|-v|--version|-h|--help) return 1 ;; esac
  done

  local target root
  target=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || target=$PWD
  root=${HERDR_WORKSPACE_ROOT:-}
  # Workspaces created before this existed lack the var: use the label as a hint.
  if [[ -z $root ]]; then
    [[ $(herdr workspace get "$HERDR_WORKSPACE_ID" 2>/dev/null | jq -r '.result.workspace.label') == ${target:t} ]] && root=$target
  fi
  [[ $root == $target ]] && return 1

  local ws pane
  ws=$(herdr workspace create --cwd "$target" --label "${target:t}" \
        --env "HERDR_WORKSPACE_ROOT=$target" --focus 2>/dev/null) || return 1
  pane=$(jq -r '.result.root_pane.pane_id // empty' <<<"$ws")
  [[ -n $pane ]] || return 1
  herdr pane run "$pane" "$kind${*:+ ${(j: :)${(q-)@}}}" >/dev/null || return 1
  print -P "%F{cyan}herdr:%f $kind opened in the new workspace %B${target:t}%b"
}

for __herdr_agent in agy claude grok opencode; do
  eval "$__herdr_agent() { __herdr_agent_redirect $__herdr_agent \"\$@\" || command $__herdr_agent \"\$@\"; }"
done
unset __herdr_agent
