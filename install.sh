#!/usr/bin/env bash
# install.sh — install /ex-skill into ~/.claude/commands/
# Copies the 3 files (or symlinks them with --link) so /ex-skill is usable in Claude Code.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/commands"
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
echo "   from: $SRC"
echo "   to:   $DEST"
echo

for f in ex-skill.md ex-skill-scan.sh ex-skill-delete.sh; do
  src="$SRC/$f"
  dst="$DEST/$f"

  if [[ -e "$dst" || -L "$dst" ]]; then
    echo "  ⚠ $f already exists — backing up to $f.bak"
    mv "$dst" "$dst.bak"
  fi

  if [[ "$MODE" == "link" ]]; then
    ln -s "$src" "$dst"
    echo "  ✓ linked $f"
  else
    cp "$src" "$dst"
    echo "  ✓ copied $f"
  fi
done

chmod +x "$DEST/ex-skill-scan.sh" "$DEST/ex-skill-delete.sh"

echo
echo "✅ Done. Open Claude Code and type /ex-skill to use it."
