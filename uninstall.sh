#!/usr/bin/env bash
# uninstall.sh — remove /ex-skill from ~/.claude/commands/

set -euo pipefail

DEST="$HOME/.claude/commands"

echo "🗑  Uninstalling /ex-skill from $DEST..."
echo

for f in ex-skill.md ex-skill-scan.sh ex-skill-delete.sh; do
  if [[ -e "$DEST/$f" || -L "$DEST/$f" ]]; then
    rm -f "$DEST/$f"
    echo "  ✓ removed $f"
  else
    echo "  · $f not found"
  fi
done

echo
echo "✅ Done."
