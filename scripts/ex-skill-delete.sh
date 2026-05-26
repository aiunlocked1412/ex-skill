#!/usr/bin/env bash
# ex-skill-delete.sh — delete items listed in /tmp/ex-skill-index.tsv by index
# Usage:
#   ex-skill-delete.sh "1,3,5"     # delete by index list
#   ex-skill-delete.sh all         # delete EVERYTHING in the index
#   ex-skill-delete.sh --dry "1,3" # dry run, show what would be deleted
#
# Reads index from /tmp/ex-skill-index.tsv produced by ex-skill-scan.sh.

set -u

INDEX=/tmp/ex-skill-index.tsv

if [[ ! -f "$INDEX" ]]; then
  echo "❌ Index file not found: $INDEX — run ex-skill-scan.sh first." >&2
  exit 1
fi

DRY=0
if [[ "${1:-}" == "--dry" ]]; then
  DRY=1
  shift
fi

SEL="${1:-}"
if [[ -z "$SEL" ]]; then
  echo "❌ Usage: $0 [--dry] <indices|all>" >&2
  exit 1
fi

# Resolve selection -> array of indices
declare -a WANT=()
if [[ "$SEL" == "all" ]]; then
  while IFS=$'\t' read -r i _; do WANT+=("$i"); done < "$INDEX"
else
  IFS=',' read -ra raw <<< "$SEL"
  for x in "${raw[@]}"; do
    x="${x// /}"   # strip spaces
    [[ "$x" =~ ^[0-9]+$ ]] && WANT+=("$x")
  done
fi

if (( ${#WANT[@]} == 0 )); then
  echo "❌ No valid indices provided." >&2
  exit 1
fi

# colors
if [[ -t 1 ]]; then
  C_R=$'\033[0m'; C_RED=$'\033[31m'; C_GR=$'\033[32m'; C_YL=$'\033[33m'; C_DIM=$'\033[2m'
else
  C_R= C_RED= C_GR= C_YL= C_DIM=
fi

PLUGINS_JSON="${HOME}/.claude/plugins/installed_plugins.json"

delete_skill() {
  local path=$1 name=$2 extra=$3
  if [[ $DRY -eq 1 ]]; then
    echo "  ${C_YL}[dry]${C_R} would remove skill ${C_DIM}$path${C_R}"
    return
  fi
  if [[ "$extra" == "symlink" ]]; then
    rm -f "$path" && echo "  ${C_GR}✓${C_R} unlinked symlink: $name"
  else
    rm -rf "$path" && echo "  ${C_GR}✓${C_R} removed skill folder: $name"
  fi
}

delete_command() {
  local path=$1 name=$2
  if [[ $DRY -eq 1 ]]; then
    echo "  ${C_YL}[dry]${C_R} would remove command ${C_DIM}$path${C_R}"
    return
  fi
  rm -f "$path" && echo "  ${C_GR}✓${C_R} removed command: /$name"
}

delete_plugin() {
  local path=$1 name=$2
  if [[ $DRY -eq 1 ]]; then
    echo "  ${C_YL}[dry]${C_R} would uninstall plugin ${C_DIM}$name${C_R} ($path)"
    return
  fi
  # 1. remove cache dir (the installPath)
  if [[ -n "$path" && -d "$path" ]]; then
    rm -rf "$path"
  fi
  # 2. remove entry from installed_plugins.json (match by name before @)
  if [[ -f "$PLUGINS_JSON" ]]; then
    /usr/bin/python3 - "$PLUGINS_JSON" "$name" <<'PY'
import json, sys, os, shutil, time
path, name = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
plugins = data.get("plugins") or {}
removed = []
for key in list(plugins.keys()):
    if key.split("@", 1)[0] == name:
        removed.append(key)
        del plugins[key]
if removed:
    # backup once per run
    bak = path + ".bak"
    if not os.path.exists(bak):
        shutil.copy2(path, bak)
    data["plugins"] = plugins
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)
    print(f"  ✓ removed plugin entry: {name} ({', '.join(removed)})")
else:
    print(f"  ⚠ plugin entry not found in JSON: {name}")
PY
  fi
}

echo
echo "${C_RED}━━━ Deleting ${#WANT[@]} item(s) ━━━${C_R}"

# Iterate selection in input order
for want_idx in "${WANT[@]}"; do
  # find the row
  row=$(awk -F'\t' -v i="$want_idx" '$1==i {print; exit}' "$INDEX")
  if [[ -z "$row" ]]; then
    echo "  ${C_YL}⚠${C_R} index $want_idx not found in scan — skipping"
    continue
  fi
  IFS=$'\t' read -r ridx kind name scope path extra <<< "$row"
  case "$kind" in
    skill)   delete_skill   "$path" "$name" "$extra" ;;
    plugin)  delete_plugin  "$path" "$name"          ;;
    command) delete_command "$path" "$name"          ;;
    *)       echo "  ${C_YL}⚠${C_R} unknown kind: $kind" ;;
  esac
done

echo
if [[ $DRY -eq 1 ]]; then
  echo "${C_YL}Dry run complete. No files were changed.${C_R}"
else
  echo "${C_GR}Done.${C_R} Re-run ${C_DIM}/ex-skill${C_R} to refresh the list."
fi
