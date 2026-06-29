#!/usr/bin/env bash
# Project-local installer for Fractal Agent Team Starter.
# Run from the folder you want to use as the agent team workspace.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$ROOT/.claude/skills"
mkdir -p "$TARGET" "$ROOT/projects"

printf 'Installing Fractal Agent Team Starter into this folder:\n  %s\n\n' "$ROOT"

for skill in "$ROOT/claude-skills"/*/; do
  name="$(basename "$skill")"
  dest="$TARGET/$name"
  rm -rf "$dest"
  cp -R "$skill" "$dest"
  printf '  ✓ %s\n' "$name"
done

if [ ! -f "$ROOT/USER.md" ]; then
  cat > "$ROOT/USER.md" <<'USER'
# USER.md

Fill this in:

- Name:
- Timezone:
- What you are building:
- Communication preferences:
- Current priorities:
USER
  echo '  ✓ USER.md'
fi

if [ ! -f "$ROOT/CLAUDE.md" ]; then
  cp "$ROOT/CLAUDE.md.example" "$ROOT/CLAUDE.md" 2>/dev/null || cat > "$ROOT/CLAUDE.md" <<'CLAUDE'
# Fractal Agent Team

Use this folder as the project workspace. Do not create nested project folders unless explicitly asked.

Read `USER.md` for user context. Put deliverables in `projects/`.
CLAUDE
  echo '  ✓ CLAUDE.md'
fi

echo ''
echo 'Done. Open this same folder in Claude Code and say: check my setup'
