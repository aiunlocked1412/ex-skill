#!/usr/bin/env bash
# ex-skill-delete.sh — delete items listed in $EX_SKILL_INDEX by index
# Usage:
#   ex-skill-delete.sh "1,3,5"     # delete by index list
#   ex-skill-delete.sh all         # delete EVERYTHING in the index
#   ex-skill-delete.sh --dry "1,3" # dry run, show what would be deleted
#   ex-skill-delete.sh "1,3" --dry # --dry can appear in any position
#
# Reads index from $EX_SKILL_INDEX (default ~/.claude/cache/ex-skill-index.tsv)
# produced by ex-skill-scan.sh.

set -u

INDEX="${EX_SKILL_INDEX:-$HOME/.claude/cache/ex-skill-index.tsv}"

if [[ ! -f "$INDEX" ]]; then
  echo "❌ Index file not found: $INDEX — run ex-skill-scan.sh first." >&2
  exit 1
fi

# ── arg parsing: pull out --dry from anywhere; first non-flag arg = selection ─
DRY=0
SEL=""
for arg in "$@"; do
  case "$arg" in
    --dry) DRY=1 ;;
    *)
      if [[ -z "$SEL" ]]; then SEL="$arg"; fi
      ;;
  esac
done

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

# Resolve python interpreter (prefer $PATH)
PYTHON="$(command -v python3 || true)"
[[ -z "$PYTHON" && -x /usr/bin/python3 ]] && PYTHON=/usr/bin/python3

USER_CLAUDE="$HOME/.claude"
PLUGINS_JSON="$USER_CLAUDE/plugins/installed_plugins.json"
PLUGIN_CACHE_ROOT="$USER_CLAUDE/plugins/cache"

# Safety gate: refuse to rm -rf outside expected sandbox dirs.
# Allowed prefixes for skill/plugin/command paths:
#   $HOME/.claude/skills/ , $HOME/.claude/commands/ , $HOME/.claude/plugins/cache/
#   <cwd>/.claude/skills/ , <cwd>/.claude/commands/
safe_path() {
  local p=$1
  case "$p" in
    "$USER_CLAUDE"/skills/*|"$USER_CLAUDE"/commands/*|"$PLUGIN_CACHE_ROOT"/*) return 0 ;;
    "$PWD"/.claude/skills/*|"$PWD"/.claude/commands/*) return 0 ;;
  esac
  return 1
}

delete_skill() {
  local path=$1 name=$2 extra=$3
  if ! safe_path "$path"; then
    echo "  ${C_YL}⚠${C_R} refusing to delete outside sandbox: $path"
    return
  fi
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
  if ! safe_path "$path"; then
    echo "  ${C_YL}⚠${C_R} refusing to delete outside sandbox: $path"
    return
  fi
  if [[ $DRY -eq 1 ]]; then
    echo "  ${C_YL}[dry]${C_R} would remove command ${C_DIM}$path${C_R}"
    return
  fi
  rm -f "$path" && echo "  ${C_GR}✓${C_R} removed command: /$name"
}

# Track plugins we've already processed so multi-marketplace dupes don't loop twice
# (macOS bash 3.2 has no associative arrays — use a space-delimited string)
PLUGIN_DONE=" "

delete_plugin() {
  local first_path=$1 name=$2

  case "$PLUGIN_DONE" in
    *" $name "*) return ;;   # already handled
  esac
  PLUGIN_DONE+="$name "

  if [[ -z "$PYTHON" || ! -f "$PLUGINS_JSON" ]]; then
    echo "  ${C_YL}⚠${C_R} python3 or installed_plugins.json missing — skipping plugin $name"
    return
  fi

  if [[ $DRY -eq 1 ]]; then
    # Just enumerate what would be deleted
    "$PYTHON" - "$PLUGINS_JSON" "$name" "$PLUGIN_CACHE_ROOT" <<'PY'
import json, sys, os
path, name, cache_root = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = json.load(f)
plugins = data.get("plugins") or {}
for key, entries in plugins.items():
    if key.split("@", 1)[0] != name:
        continue
    for e in entries:
        ip = e.get("installPath", "")
        safe = ip.startswith(cache_root + os.sep) or ip == cache_root
        marker = "" if safe else "  ⚠ outside sandbox, will skip"
        print(f"  [dry] would uninstall plugin {name} ({key}) at {ip}{marker}")
PY
    return
  fi

  # Real delete — let python handle JSON edit + path-validated rm -rf
  "$PYTHON" - "$PLUGINS_JSON" "$name" "$PLUGIN_CACHE_ROOT" <<'PY'
import json, sys, os, shutil
path, name, cache_root = sys.argv[1], sys.argv[2], sys.argv[3]
cache_root = os.path.normpath(cache_root)

with open(path) as f:
    data = json.load(f)
plugins = data.get("plugins") or {}
removed_keys = []
cache_paths = []

for key in list(plugins.keys()):
    if key.split("@", 1)[0] != name:
        continue
    for e in plugins[key]:
        ip = e.get("installPath", "")
        if not ip:
            continue
        norm = os.path.normpath(ip)
        # safety: must live under PLUGIN_CACHE_ROOT
        if norm == cache_root or norm.startswith(cache_root + os.sep):
            cache_paths.append(norm)
        else:
            sys.stderr.write(f"  ⚠ skipping cache rm outside sandbox: {ip}\n")
    removed_keys.append(key)
    del plugins[key]

if not removed_keys:
    print(f"  ⚠ plugin entry not found in JSON: {name}")
    sys.exit(0)

# Remove every cache dir we collected
for cp in cache_paths:
    if os.path.isdir(cp):
        shutil.rmtree(cp, ignore_errors=True)

# Backup JSON once per run
bak = path + ".bak"
if not os.path.exists(bak):
    shutil.copy2(path, bak)
data["plugins"] = plugins
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
os.replace(tmp, path)

print(f"  ✓ removed plugin entry: {name} ({', '.join(removed_keys)})")
for cp in cache_paths:
    print(f"    └─ cache dir removed: {cp}")
PY
}

echo
echo "${C_RED}━━━ Deleting ${#WANT[@]} item(s) ━━━${C_R}"

# Iterate selection in input order
for want_idx in "${WANT[@]}"; do
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
