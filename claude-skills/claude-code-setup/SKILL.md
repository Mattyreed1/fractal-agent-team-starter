---
name: claude-code-setup
description: Simple setup wizard for Fractal Agent Team Starter. Configures the current Claude Code project folder, optionally adds fractal-agent-skills, fractal-agent-team-memory/Convex, n8n, Notion, and Hetzner/OpenClaw VPS hosting. Triggered by "set me up", "help me get started", "check my setup".
metadata:
  version: 2.0.0
  audience: beginners
  focus: simplest-possible-agent-team-onboarding
---

# Fractal Agent Team Setup Wizard

Your job: make setup boring and hard to mess up.

## Non-negotiable setup rule

The folder currently open in Claude Code is the user's project folder.

Do **not** create a nested working project such as `EA/`, `.workshop-starter/`, `fractal-agent-team-starter/`, or `my-agent-project/` inside it unless the user explicitly asks.

If starter source files are needed and not present, clone/copy them through a temporary directory outside the project, then configure the current folder.

## Trigger phrases

Run this wizard when the user says:

- "set me up"
- "help me get started"
- "run setup"
- "check my setup"
- "set me up for a Fractal agent team"

## Step 0 — Confirm current folder

Run:

```bash
pwd
ls -la
```

If the folder looks like a system/home/root directory (`/`, `~`, Desktop root, Downloads root), stop and say:

> Open a dedicated folder in Claude Code first. Example: create `FractalAgentTeam`, then use File → Open Folder. I will configure that folder directly.

If the folder is a normal project folder, continue.

## Step 1 — Get starter files into the current folder if needed

If `claude-skills/claude-code-setup/SKILL.md` already exists, the starter is already present.

If not, copy the starter into the current folder without creating a nested project:

```bash
TMP=$(mktemp -d)
git clone --quiet https://github.com/Mattyreed1/fractal-agent-team-starter.git "$TMP/starter"
cp -R "$TMP/starter/claude-skills" ./
cp -R "$TMP/starter/docs" ./ 2>/dev/null || true
cp -R "$TMP/starter/examples" ./ 2>/dev/null || true
[ -f ./install.sh ] || cp "$TMP/starter/install.sh" ./install.sh
[ -f ./CLAUDE.md.example ] || cp "$TMP/starter/CLAUDE.md.example" ./CLAUDE.md.example 2>/dev/null || true
rm -rf "$TMP"
```

Verify:

```bash
[ -f ./claude-skills/claude-code-setup/SKILL.md ] && echo READY || echo FAILED
```

## Step 2 — Create the minimal workspace

Create only the basics first:

```bash
mkdir -p ./.claude/skills ./projects
for s in claude-code-setup openclaw-vps-setup n8n notion; do
  rm -rf "./.claude/skills/$s"
  cp -R "./claude-skills/$s" "./.claude/skills/$s"
done
[ -f ./USER.md ] || cat > ./USER.md <<'USER'
# USER.md

Fill this in:

- Name:
- Timezone:
- What you are building:
- Communication preferences:
- Current priorities:
USER
[ -f ./CLAUDE.md ] || cat > ./CLAUDE.md <<'CLAUDE'
# Fractal Agent Team

Use this folder as the project workspace. Do not create nested project folders unless explicitly asked.

Read `USER.md` for user context. Put deliverables in `projects/`.

## Setup status

- Fractal Agent Team Starter installed
- Optional add-ons: not configured yet
CLAUDE
```

Tell the user the minimal setup is done.

## Step 3 — Ask optional setup questions

Ask these as yes/no choices. Keep it simple.

Recommend this default path unless the user has a reason to change it:

1. Add Fractal agent skills from `fractal-agent-skills`? **Recommended: yes.**
2. Set up shared team memory with Convex using `fractal-agent-team-memory`? **Recommended: yes.**
3. Connect n8n? **Recommended: not yet unless they already use n8n.**
4. Connect Notion? **Recommended: not yet unless they already have a Notion integration ready.**
5. Set up a Hetzner VPS for OpenClaw agent hosting? **Recommended: after local setup works.**

Only configure what they say yes to. If they are unsure, choose the recommended path: skills + memory now, integrations/VPS later.

## Optional A — Add Fractal agent skills

If yes:

```bash
TMP=$(mktemp -d)
git clone --quiet https://github.com/Mattyreed1/fractal-agent-skills.git "$TMP/fractal-agent-skills"
mkdir -p ./.claude/skills
for s in "$TMP/fractal-agent-skills"/*; do
  [ -f "$s/SKILL.md" ] || continue
  name=$(basename "$s")
  rm -rf "./.claude/skills/$name"
  cp -R "$s" "./.claude/skills/$name"
done
rm -rf "$TMP"
```

Then add to `CLAUDE.md`:

```markdown
- Fractal agent skills installed in `.claude/skills/`.
```

## Optional B — Set up Convex team memory

If yes, use `fractal-agent-team-memory` as the standard backend.

1. Check Node:

```bash
node --version || echo NODE_MISSING
```

If missing, send user to https://nodejs.org and stop this optional step.

2. Copy memory starter into `memory-backend/`:

```bash
TMP=$(mktemp -d)
git clone --quiet https://github.com/Mattyreed1/fractal-agent-team-memory.git "$TMP/memory"
rm -rf ./memory-backend
cp -R "$TMP/memory" ./memory-backend
rm -rf ./memory-backend/.git "$TMP"
```

3. Install and deploy Convex:

```bash
cd memory-backend
npm install
npx convex dev --once
```

Explain: Convex opens a browser for login and creates the backend. `--once` configures and pushes once, then exits. When it shows a deployment URL, save it in `CLAUDE.md` under Setup status.

4. Add to `CLAUDE.md`:

```markdown
- Team memory backend lives in `memory-backend/`.
- Convex is the standard backend for shared notes, tasks, and agent status.
- Convex deployment URL: `<paste URL here>`.
```

## Optional C — Connect n8n

Ask for n8n URL and API key. Do not echo secrets. Store project-local in `./.mcp.json`.

Use this safe merge script. Replace `<N8N_URL>` and `<API_KEY>` before running. Preserve every existing key and only add/update `mcpServers.n8n`:

```bash
python3 - <<'PY'
import json
from pathlib import Path
path = Path('.mcp.json')
cfg = json.loads(path.read_text()) if path.exists() else {}
cfg.setdefault('mcpServers', {})
cfg['mcpServers']['n8n'] = {
  'type': 'stdio',
  'command': 'npx',
  'args': ['-y', 'n8n-mcp'],
  'env': {
    'MCP_MODE': 'stdio',
    'LOG_LEVEL': 'error',
    'DISABLE_CONSOLE_OUTPUT': 'true',
    'N8N_API_URL': 'https://<N8N_URL>',
    'N8N_API_KEY': '<API_KEY>'
  }
}
path.write_text(json.dumps(cfg, indent=2) + '\n')
print('n8n MCP server added')
PY
python3 -m json.tool .mcp.json >/dev/null && echo MCP_JSON_OK
```

## Optional D — Connect Notion

Ask for a Notion internal integration token. Do not echo secrets. Use this safe merge script. Replace `<TOKEN>` before running. Preserve every existing key and only add/update `mcpServers.notion`:

```bash
python3 - <<'PY'
import json
from pathlib import Path
path = Path('.mcp.json')
cfg = json.loads(path.read_text()) if path.exists() else {}
cfg.setdefault('mcpServers', {})
cfg['mcpServers']['notion'] = {
  'type': 'stdio',
  'command': 'npx',
  'args': ['-y', '@notionhq/notion-mcp-server'],
  'env': {
    'OPENAPI_MCP_HEADERS': '{"Authorization":"Bearer <TOKEN>","Notion-Version":"2022-06-28"}'
  }
}
path.write_text(json.dumps(cfg, indent=2) + '\n')
print('Notion MCP server added')
PY
python3 -m json.tool .mcp.json >/dev/null && echo MCP_JSON_OK
```

Remind the user they must share Notion pages/databases with the integration.

## Optional E — Hetzner VPS hosting

If yes, route to the `openclaw-vps-setup` skill.

Default stack:

- Hetzner CX22 Ubuntu VPS
- Docker
- OpenClaw
- Discord as visible I/O
- Convex backend from `fractal-agent-team-memory` when team memory is enabled

Do not rush this step. VPS setup is the first real production boundary.

## Final verification

Run:

```bash
pwd
find . -maxdepth 3 \( -path './.git' -o -path './node_modules' \) -prune -o -type f | sort | sed 's#^./##' | head -80
[ -f ./CLAUDE.md ] && echo CLAUDE_OK
[ -f ./USER.md ] && echo USER_OK
[ -d ./.claude/skills ] && echo SKILLS_OK
```

Tell the user:

- what was configured,
- what was skipped,
- the next single action.

If nothing else is needed, next action is: restart Claude Code, reopen this same folder, and say `check my setup`. Keep the next action singular; do not dump a long todo list.
