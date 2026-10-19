#!/usr/bin/env bash
# Claude Code statusline
#   Línea 1: powerline (user → dir → branch) + ccusage (costos/burn) + contexto (del JSON nativo)
#   Línea 2: barras de rate limits del plan (5h y 7d) con % y reset
# Caracteres Unicode (, █, ░, ↺, 🧠) van LITERALES para no depender de \u en printf.

input=$(cat)

# ---------- helpers ----------
round() {                     # round <num> -> entero (vía awk: el printf de bash 3.2 de macOS revienta con floats)
  awk -v n="${1:-0}" 'BEGIN{printf "%.0f", n+0}' 2>/dev/null
}

bar() {                       # bar <pct> -> barra de fondo sólido coloreado (espacios con bg)
  local pct=$1 width=10 filled empty bg
  pct=$(round "$pct"); [[ -z "$pct" ]] && pct=0   # normaliza floats: la aritmética entera revienta con 28.999..%
  filled=$(( (pct * width + 50) / 100 ))
  (( filled > width )) && filled=$width
  (( filled < 0 )) && filled=0
  empty=$(( width - filled ))
  if   (( pct >= 80 )); then bg=196   # rojo
  elif (( pct >= 50 )); then bg=220   # amarillo
  else                       bg=70;   # verde
  fi
  local out=''
  (( filled > 0 )) && out+=$(printf '\033[48;5;%sm%*s' "$bg" "$filled" '')
  (( empty  > 0 )) && out+=$(printf '\033[48;5;238m%*s' "$empty" '')
  out+=$(printf '\033[0m')
  printf '%s' "$out"
}

color_for() {                 # color_for <pct> -> verde/amarillo/rojo
  local pct=$1
  pct=$(round "$pct"); [[ -z "$pct" ]] && pct=0
  if   (( pct >= 80 )); then printf '31'    # rojo
  elif (( pct >= 50 )); then printf '33'    # amarillo
  else                       printf '32'; fi # verde
}

group() {                     # group <n> -> miles con coma (bash puro, sin depender de locale)
  local n=$1 sign='' out=''
  [[ $n == -* ]] && sign='-' && n=${n#-}
  while (( ${#n} > 3 )); do
    out=",${n: -3}${out}"
    n=${n:0:${#n}-3}
  done
  printf '%s%s%s' "$sign" "$n" "$out"
}

# ---------- datos del JSON ----------
dir=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
user=$(whoami)
disp_dir="${dir/#$HOME/\~}"   # abrevia el home a ~ SOLO para mostrar; cd/git usan la ruta real

# Glyphs por bytes UTF-8 (octal): NO usar literales, se pierden al editar el archivo
SEP=$(printf '\356\202\260')          # U+E0B0 flechita separadora
GIT=$(printf '\356\202\240')          # U+E0A0 icono de rama git
ROBOT=$(printf '\360\237\244\226')    # U+1F916 🤖 icono de modelo
SYM_STAGED=$(printf '\342\234\232')   # U+271A ✚ cambios staged
SYM_UNSTAGED=$(printf '\302\261')     # U+00B1 ± cambios sin stage / untracked

# ---------- rama + estado git (replica agnoster: limpio=verde, con cambios=amarillo) ----------
branch=''; git_dirty=''; git_sym=''
gitout=$(cd "$dir" 2>/dev/null && git --no-optional-locks status --porcelain=v1 --branch 2>/dev/null)
if [[ -n "$gitout" ]]; then
  bline="${gitout%%$'\n'*}"                               # "## main...origin/main [ahead 1]"
  branch="${bline#\#\# }"; branch="${branch%%...*}"; branch="${branch%% *}"
  staged=''; unstaged=''
  while IFS= read -r l; do
    [[ "$l" == '## '* || -z "$l" ]] && continue
    [[ "${l:0:1}" == '?' ]] && { unstaged=1; continue; }   # untracked = cambio (default agnoster)
    [[ "${l:0:1}" != ' ' ]] && staged=1                    # col 1 (índice) -> staged
    [[ "${l:1:1}" != ' ' ]] && unstaged=1                  # col 2 (working tree) -> sin stage
  done <<<"$gitout"
  [[ -n "$staged" || -n "$unstaged" ]] && git_dirty=1
  [[ -n "$staged"   ]] && git_sym+="$SYM_STAGED"
  [[ -n "$unstaged" ]] && git_sym+="$SYM_UNSTAGED"
fi
session=$(jq -r '.session_id // empty' <<<"$input")

# ---------- cache de últimos valores buenos ----------
# Claude Code NO siempre manda context_window/rate_limits (sesión nueva, refrescos intermedios).
# Cuando faltan, caemos al último valor conocido en vez de mostrar 0.
#   - rate_limits: globales de la cuenta (5h/7d) -> valen entre sesiones, fallback siempre
#   - context_window: es por sesión -> fallback solo si la sesión cacheada coincide
CACHE="$HOME/.claude/.statusline-cache"
c_session='' c_ctx_pct='' c_ctx_tok='' c_h5_pct='' c_h5_reset='' c_d7_pct='' c_d7_reset=''
[[ -r "$CACHE" ]] && read -r c_session c_ctx_pct c_ctx_tok c_h5_pct c_h5_reset c_d7_pct c_d7_reset < "$CACHE"

# ---------- línea 1: powerline ----------
out=''
prev_bg=''
if [[ "$user" != "$LOGNAME" ]] || [[ -n "$SSH_CLIENT" ]]; then
  out=$(printf '\033[48;5;33m\033[38;5;0m %s ' "$user")
  prev_bg=33
fi
if [[ -n "$prev_bg" ]]; then
  out+=$(printf '\033[48;5;24m\033[38;5;%sm%s\033[38;5;15m %s ' "$prev_bg" "$SEP" "$disp_dir")
else
  out=$(printf '\033[48;5;24m\033[38;5;15m %s ' "$disp_dir")
fi
prev_bg=24
if [[ -n "$branch" ]]; then
  if [[ -n "$git_dirty" ]]; then bbg=3; else bbg=2; fi    # 3=amarillo(dirty) 2=verde(clean): paleta del tema, como agnoster
  blabel="$branch"; [[ -n "$git_sym" ]] && blabel="$branch $git_sym"
  out+=$(printf '\033[48;5;%sm\033[38;5;%sm%s\033[38;5;0m %s %s ' "$bbg" "$prev_bg" "$SEP" "$GIT" "$blabel")
  prev_bg=$bbg
fi
out+=$(printf '\033[0m\033[38;5;%sm%s\033[0m' "$prev_bg" "$SEP")

# modelo desde el JSON nativo (sin ccusage: con suscripción los costos/burn no aplican)
model=$(jq -r '.model.display_name // empty' <<<"$input")
model_seg=''
[[ -n "$model" ]] && model_seg=$(printf ' %s \033[38;5;245m%s\033[0m' "$ROBOT" "$model")

# contexto desde el JSON nativo de Claude Code (fuente de verdad, sin parpadeos)
ctx_pct=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
ctx_tok=$(jq -r '.context_window.total_input_tokens // empty' <<<"$input")
# fallback de contexto SOLO dentro de la misma sesión (una sesión nueva arranca en ~0 de verdad)
if [[ -z "$ctx_pct" ]]; then [[ -n "$session" && "$session" == "$c_session" ]] && ctx_pct=$c_ctx_pct || ctx_pct=0; fi
if [[ -z "$ctx_tok" ]]; then [[ -n "$session" && "$session" == "$c_session" ]] && ctx_tok=$c_ctx_tok || ctx_tok=0; fi
ctx_pct=$(round "${ctx_pct:-0}"); ctx_tok=${ctx_tok:-0}
# mismo gris (245) que el modelo, sin colorear por % (a pedido del user); el emoji 🧠 conserva su color propio
ctx_seg=$(printf ' \033[38;5;245m| 🧠 %s (%s%%)\033[0m' "$(group "$ctx_tok")" "$ctx_pct")

line1="$out${model_seg}${ctx_seg}"

# ---------- línea 2: barras de rate limits ----------
h5_pct=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
h5_reset=$(jq -r '.rate_limits.five_hour.resets_at // empty' <<<"$input")
d7_pct=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")
d7_reset=$(jq -r '.rate_limits.seven_day.resets_at // empty' <<<"$input")
# rate limits globales de la cuenta -> si faltan, último valor conocido (vale entre sesiones)
[[ -z "$h5_pct"   ]] && h5_pct=${c_h5_pct:-0}
[[ -z "$h5_reset" ]] && h5_reset=${c_h5_reset:-0}
[[ -z "$d7_pct"   ]] && d7_pct=${c_d7_pct:-0}
[[ -z "$d7_reset" ]] && d7_reset=${c_d7_reset:-0}
h5_pct=$(round "${h5_pct:-0}"); d7_pct=$(round "${d7_pct:-0}")

# guardamos el último estado bueno para el próximo render / la próxima sesión
printf '%s %s %s %s %s %s %s\n' "${session:-$c_session}" "$ctx_pct" "$ctx_tok" "$h5_pct" "$h5_reset" "$d7_pct" "$d7_reset" >"$CACHE" 2>/dev/null

# date portable: GNU date (Linux) usa -d "@epoch"; BSD date (macOS) usa -r epoch
epoch_to() {                  # epoch_to <epoch> <formato>
  date -d "@$1" "$2" 2>/dev/null || date -r "$1" "$2" 2>/dev/null
}
h5_t=$(epoch_to "$h5_reset" "+%H:%M")
d7_t=$(epoch_to "$d7_reset" "+%a %d %H:%M")

line2=$(printf '\033[90m5h \033[0m%s %s%% \033[90m(↺%s)\033[0m   \033[90m7d \033[0m%s %s%% \033[90m(↺%s)\033[0m' \
  "$(bar "$h5_pct")" "$h5_pct" "$h5_t" \
  "$(bar "$d7_pct")" "$d7_pct" "$d7_t")

# cuenta activa: "Personal" en #FC186C + email de ~/.claude.json
acct_email=$(jq -r '.oauthAccount.emailAddress // empty' "$HOME/.claude.json" 2>/dev/null)
line2+=$(printf '   👤 \033[1;38;2;252;24;108mPersonal\033[0m')
[[ -n "$acct_email" ]] && line2+=$(printf ' \033[38;5;245m%s\033[0m' "$acct_email")

printf '%s\n%s' "$line1" "$line2"
