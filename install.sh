#!/usr/bin/env bash
# Fallback installer: symlink this config into ~/.claude directly.
#
# PREFER THE PLUGIN. See README — installing model-routing as a plugin is the
# supported path, and it is what makes this repo portable to other machines.
# This script exists for the case where you want the files in ~/.claude without
# going through the plugin system at all.
#
#   ./install.sh            link into ~/.claude
#   ./install.sh --unlink   remove those links (run before installing the plugin)
#
# The two paths are MUTUALLY EXCLUSIVE. Running both gives you six duplicate
# agent names and the routing policy injected twice per session.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$REPO/plugins/model-routing"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
MODE="${1:-link}"

targets() {
  for f in "$PLUGIN"/agents/*.md; do
    printf '%s\t%s\n' "$f" "$DEST/agents/$(basename "$f")"
  done
  printf '%s\t%s\n' "$PLUGIN/model-routing.md"   "$DEST/model-routing.md"
  printf '%s\t%s\n' "$PLUGIN/model-routing.json" "$DEST/model-routing.json"
  printf '%s\t%s\n' "$REPO/RTK.md"               "$DEST/RTK.md"
}

if [ "$MODE" = "--unlink" ]; then
  echo "Unlinking from $DEST"
  while IFS=$'\t' read -r src dst; do
    # Only remove links we own. Never touch a real file the user wrote.
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      rm "$dst"; printf '  rm    %s\n' "${dst#$HOME/}"
    elif [ -e "$dst" ]; then
      printf '  keep  %s (not our symlink)\n' "${dst#$HOME/}"
    fi
  done < <(targets)

  CLAUDE_MD="$DEST/CLAUDE.md"
  if [ -f "$CLAUDE_MD" ] && grep -qxF '@model-routing.md' "$CLAUDE_MD"; then
    grep -vxF '@model-routing.md' "$CLAUDE_MD" > "$CLAUDE_MD.tmp" && mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    printf '  rm    CLAUDE.md -= @model-routing.md\n'
  fi
  echo "Done. Safe to install the plugin now."
  exit 0
fi

echo "Linking $REPO -> $DEST"
while IFS=$'\t' read -r src dst; do
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf '  ok    %s\n' "${dst#$HOME/}"; continue
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    cp "$dst" "$dst.pre-link"; printf '  saved %s\n' "${dst#$HOME/}.pre-link"
  fi
  ln -sfn "$src" "$dst"
  printf '  link  %s\n' "${dst#$HOME/}"
done < <(targets)

CLAUDE_MD="$DEST/CLAUDE.md"
touch "$CLAUDE_MD"
for import in "@RTK.md" "@model-routing.md"; do
  if grep -qxF "$import" "$CLAUDE_MD"; then
    printf '  ok    CLAUDE.md has %s\n' "$import"
  else
    printf '%s\n' "$import" >> "$CLAUDE_MD"; printf '  add   CLAUDE.md += %s\n' "$import"
  fi
done

cat <<'MSG'

Done. Agent definitions load at session start — open a new session.

Not installed here (machine-specific): settings.json. See settings.reference.json.
MSG
