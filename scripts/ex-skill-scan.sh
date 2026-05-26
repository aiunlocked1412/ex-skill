#!/usr/bin/env bash
# ex-skill-scan.sh — scan installed skills, plugins, slash commands
# Output: pretty ASCII box + machine-readable index file at /tmp/ex-skill-index.tsv
# TSV columns: idx<TAB>kind<TAB>name<TAB>scope<TAB>path<TAB>extra
#   kind  = skill | plugin | command
#   scope = user | project
#   extra = type (folder/symlink) for skills, version for plugins, "" for commands

set -u

# ── colors ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_CYAN=$'\033[36m'
  C_MAGENTA=$'\033[35m'
  C_YELLOW=$'\033[33m'
  C_GREEN=$'\033[32m'
  C_BLUE=$'\033[34m'
  C_GREY=$'\033[90m'
else
  C_RESET= C_BOLD= C_DIM= C_CYAN= C_MAGENTA= C_YELLOW= C_GREEN= C_BLUE= C_GREY=
fi

INDEX=/tmp/ex-skill-index.tsv
: > "$INDEX"

USER_HOME="${HOME}"
USER_CLAUDE="${USER_HOME}/.claude"
PROJECT_CLAUDE="$(pwd)/.claude"

idx=0
LAST_IDX=0

# ── helpers ─────────────────────────────────────────────────────────────────
add_row() {
  # add_row <kind> <name> <scope> <path> <extra> — sets LAST_IDX
  idx=$((idx + 1))
  LAST_IDX=$idx
  printf '%d\t%s\t%s\t%s\t%s\t%s\n' "$idx" "$1" "$2" "$3" "$4" "$5" >> "$INDEX"
}

# truncate string to N chars + "…" if longer
trunc() {
  local s=$1 n=$2
  if (( ${#s} > n )); then
    printf '%s…' "${s:0:n-1}"
  else
    printf '%s' "$s"
  fi
}

print_box_top() {
  printf '%s╭───────────────────────────────────────────────────────────────╮%s\n' "$C_CYAN" "$C_RESET"
  printf '%s│%s  %s📦 INSTALLED SKILLS / PLUGINS / COMMANDS%s                    %s│%s\n' "$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_CYAN" "$C_RESET"
  printf '%s├───────────────────────────────────────────────────────────────┤%s\n' "$C_CYAN" "$C_RESET"
}
print_box_bottom() {
  printf '%s╰───────────────────────────────────────────────────────────────╯%s\n' "$C_CYAN" "$C_RESET"
}
print_box_sep() {
  printf '%s├───────────────────────────────────────────────────────────────┤%s\n' "$C_CYAN" "$C_RESET"
}
print_box_line() {
  # print a content line, pad to fixed width 61
  local raw=$1 color=${2:-}
  # strip color codes for width calc
  local plain=$(printf '%b' "$raw" | sed -E $'s/\033\\[[0-9;]*m//g')
  local pad=$((61 - ${#plain}))
  (( pad < 0 )) && pad=0
  printf '%s│%s %b%*s%s│%s\n' "$C_CYAN" "$C_RESET" "$raw" "$pad" "" "$C_CYAN" "$C_RESET"
}

# ── 1. Skills ───────────────────────────────────────────────────────────────
declare -a SKILL_ROWS=()
scan_skills_in() {
  local root=$1 scope=$2
  [[ -d "$root" ]] || return
  shopt -s nullglob
  for entry in "$root"/*; do
    local name=$(basename "$entry")
    local type
    if [[ -L "$entry" ]]; then
      type="symlink"
    elif [[ -d "$entry" ]]; then
      type="folder"
    else
      continue
    fi
    # Verify it looks like a skill (has SKILL.md)
    if [[ -f "$entry/SKILL.md" ]]; then
      add_row "skill" "$name" "$scope" "$entry" "$type"
      SKILL_ROWS+=("$LAST_IDX|$name|$scope|$type")
    fi
  done
  shopt -u nullglob
}
scan_skills_in "$USER_CLAUDE/skills" "user"
scan_skills_in "$PROJECT_CLAUDE/skills" "project"

# ── 2. Plugins ──────────────────────────────────────────────────────────────
declare -a PLUGIN_ROWS=()
plugins_json="$USER_CLAUDE/plugins/installed_plugins.json"
if [[ -f "$plugins_json" ]]; then
  # Parse with python (always available on macOS)
  while IFS=$'\t' read -r pname pver ppath; do
    [[ -z "$pname" ]] && continue
    add_row "plugin" "$pname" "user" "$ppath" "$pver"
    PLUGIN_ROWS+=("$LAST_IDX|$pname|user|$pver")
  done < <(/usr/bin/python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    for key, entries in (data.get("plugins") or {}).items():
        # key looks like "boxbox@marketplace"
        name = key.split("@", 1)[0]
        for e in entries:
            ver = e.get("version", "unknown")
            path = e.get("installPath", "")
            print(f"{name}\t{ver}\t{path}")
except Exception as ex:
    sys.stderr.write(str(ex) + "\n")
' "$plugins_json")
fi

# ── 3. Slash commands ───────────────────────────────────────────────────────
declare -a CMD_ROWS=()
scan_cmds_in() {
  local root=$1 scope=$2
  [[ -d "$root" ]] || return
  shopt -s nullglob
  for f in "$root"/*.md; do
    local name=$(basename "$f" .md)
    add_row "command" "$name" "$scope" "$f" ""
    CMD_ROWS+=("$LAST_IDX|$name|$scope")
  done
  shopt -u nullglob
}
scan_cmds_in "$USER_CLAUDE/commands" "user"
scan_cmds_in "$PROJECT_CLAUDE/commands" "project"

# ── render ──────────────────────────────────────────────────────────────────
print_box_top

# SKILLS section
print_box_line "$(printf '%s✨ SKILLS (%d)%s' "$C_MAGENTA$C_BOLD" "${#SKILL_ROWS[@]}" "$C_RESET")"
if (( ${#SKILL_ROWS[@]} == 0 )); then
  print_box_line "$(printf '   %s(none)%s' "$C_GREY" "$C_RESET")"
else
  for row in "${SKILL_ROWS[@]}"; do
    IFS='|' read -r i n s t <<< "$row"
    name_p=$(trunc "$n" 30)
    print_box_line "$(printf ' %s%3d.%s %-30s %s[%s]%s %s%s%s' \
      "$C_YELLOW" "$i" "$C_RESET" \
      "$name_p" \
      "$C_DIM" "$t" "$C_RESET" \
      "$C_GREY" "$s" "$C_RESET")"
  done
fi

print_box_sep

# PLUGINS section
print_box_line "$(printf '%s🔌 PLUGINS (%d)%s' "$C_BLUE$C_BOLD" "${#PLUGIN_ROWS[@]}" "$C_RESET")"
if (( ${#PLUGIN_ROWS[@]} == 0 )); then
  print_box_line "$(printf '   %s(none)%s' "$C_GREY" "$C_RESET")"
else
  for row in "${PLUGIN_ROWS[@]}"; do
    IFS='|' read -r i n s v <<< "$row"
    name_p=$(trunc "$n" 30)
    print_box_line "$(printf ' %s%3d.%s %-30s %sv%s%s' \
      "$C_YELLOW" "$i" "$C_RESET" \
      "$name_p" \
      "$C_DIM" "$v" "$C_RESET")"
  done
fi

print_box_sep

# COMMANDS section
print_box_line "$(printf '%s⚡ SLASH COMMANDS (%d)%s' "$C_GREEN$C_BOLD" "${#CMD_ROWS[@]}" "$C_RESET")"
if (( ${#CMD_ROWS[@]} == 0 )); then
  print_box_line "$(printf '   %s(none)%s' "$C_GREY" "$C_RESET")"
else
  for row in "${CMD_ROWS[@]}"; do
    IFS='|' read -r i n s <<< "$row"
    name_p=$(trunc "$n" 30)
    print_box_line "$(printf ' %s%3d.%s %-30s %s/%s%s %s%s%s' \
      "$C_YELLOW" "$i" "$C_RESET" \
      "$name_p" \
      "$C_DIM" "$n" "$C_RESET" \
      "$C_GREY" "$s" "$C_RESET")"
  done
fi

print_box_bottom

total=$((${#SKILL_ROWS[@]} + ${#PLUGIN_ROWS[@]} + ${#CMD_ROWS[@]}))
printf '\n%s📊 Total: %d items%s   %sIndex saved to %s%s\n\n' \
  "$C_BOLD" "$total" "$C_RESET" \
  "$C_DIM" "$INDEX" "$C_RESET"
