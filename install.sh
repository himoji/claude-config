#!/usr/bin/env bash
# Link this repo's Claude Code config into ~/.claude on a new machine.
#
#   git clone <this repo> ~/Documents/git/claude-config
#   ~/Documents/git/claude-config/install.sh
#
# Symlinks, not copies — edit on any machine, commit, pull elsewhere.
# Idempotent. Existing regular files are backed up to *.pre-link, never deleted.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"

  # Already pointing where we want it.
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf '  ok    %s\n' "${dst#$HOME/}"
    return
  fi

  # Real file in the way: keep a copy before replacing it.
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    cp "$dst" "$dst.pre-link"
    printf '  saved %s\n' "${dst#$HOME/}.pre-link"
  fi

  ln -sfn "$src" "$dst"
  printf '  link  %s\n' "${dst#$HOME/}"
}

echo "Linking $REPO -> $DEST"

for f in "$REPO"/agents/*.md; do
  link "$f" "$DEST/agents/$(basename "$f")"
done

link "$REPO/model-routing.md"   "$DEST/model-routing.md"
link "$REPO/model-routing.json" "$DEST/model-routing.json"
link "$REPO/RTK.md"             "$DEST/RTK.md"

# CLAUDE.md stays a real file: it is the one thing you may want to differ
# per machine. We only ensure the imports are present.
CLAUDE_MD="$DEST/CLAUDE.md"
touch "$CLAUDE_MD"
for import in "@RTK.md" "@model-routing.md"; do
  if grep -qxF "$import" "$CLAUDE_MD"; then
    printf '  ok    CLAUDE.md has %s\n' "$import"
  else
    printf '%s\n' "$import" >> "$CLAUDE_MD"
    printf '  add   CLAUDE.md += %s\n' "$import"
  fi
done

cat <<'EOF'

Done. Agent definitions load at session start — open a new session to pick them up.

NOT installed by this script (machine-specific, review by hand):
  settings.json  - hooks reference absolute paths; plugin marketplace paths differ
                   per machine. See settings.reference.json for the parts worth
                   copying: "model", "effortLevel", "permissions.deny".
EOF
