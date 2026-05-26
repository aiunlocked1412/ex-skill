#!/usr/bin/env bash
# install.sh — standalone install of /ex-skill into ~/.claude/commands/
#
# Alternatively, install via the Claude Code plugin marketplace:
#   /plugin marketplace add aiunlocked1412/ex-skill
#   /plugin install ex-skill@ex-skill-marketplace
#
# This script is for users who don't want to use the plugin marketplace.
# It copies (or symlinks with --link) ex-skill.md + scripts into ~/.claude/commands/
# so that /ex-skill works in Claude Code.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.claude/commands"

MODE="copy"
if [[ "${1:-}" == "--link" ]]; then
  MODE="link"
fi

if [[ ! -d "$DEST" ]]; then
  echo "❌ $DEST does not exist — is Claude Code installed?" >&2
  exit 1
fi

echo "📦 Installing /ex-skill ($MODE mode)..."
echo "   from: $REPO_DIR"
echo "   to:   $DEST"
echo

# Map: src-relative-path → dest-filename (flat layout in ~/.claude/commands/)
declare -a PAIRS=(
  "commands/ex-skill.md|ex-skill.md"
  "scripts/ex-skill-scan.sh|ex-skill-scan.sh"
  "scripts/ex-skill-delete.sh|ex-skill-delete.sh"
)

for pair in "${PAIRS[@]}"; do
  src_rel="${pair%%|*}"
  dst_name="${pair##*|}"
  src="$REPO_DIR/$src_rel"
  dst="$DEST/$dst_name"

  if [[ ! -f "$src" ]]; then
    echo "  ✗ missing source: $src" >&2
    exit 1
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    echo "  ⚠ $dst_name already exists — backing up to $dst_name.bak"
    mv "$dst" "$dst.bak"
  fi

  if [[ "$MODE" == "link" ]]; then
    ln -s "$src" "$dst"
    echo "  ✓ linked $dst_name"
  else
    cp "$src" "$dst"
    echo "  ✓ copied $dst_name"
  fi
done

chmod +x "$DEST/ex-skill-scan.sh" "$DEST/ex-skill-delete.sh"

echo
echo "✅ Done. Open Claude Code and type /ex-skill to use it."
