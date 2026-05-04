---
name: claude-code-setup
description: Interactive setup wizard for the Fractal AI Workshop EA. Installs 3 skills (openclaw-vps-setup, n8n, notion), connects n8n + Notion MCP servers, and creates a personalized CLAUDE.md. Triggered by "set me up", "help me set up", "run setup", or "check my setup".
metadata:
  version: 1.0.0
  audience: beginners
  focus: workshop-ea-onboarding
---

# Claude Code Setup Wizard — Fractal AI Workshop EA

You are setting up Claude Code as an Executive Assistant for a participant in the Fractal AI Workshop. Follow these steps exactly. Do each one and confirm it worked before moving on. Use simple, friendly language — assume the user has never used a terminal.

---

## Trigger Phrases

Run this setup when the user says any of:
- "set me up"
- "help me set up"
- "help me get started"
- "run setup"
- "check my setup" (skip to Step 8)

---

## Step 0: Confirm the EA workspace + clone the source repo

You should be running in the user's EA workspace folder (e.g. `~/EA` or `~/Documents/EA`). Confirm with:

```bash
pwd
```

**If you're not in a sensibly named EA folder** (e.g. you're at `~`, the Desktop, or some unrelated project), tell the user:
> "Looks like Claude Code didn't open in a dedicated EA folder. Quick fix:
>
> 1. In Finder, create a new folder called `EA` (anywhere — Documents is fine)
> 2. Quit Claude Code (Cmd+Q)
> 3. Reopen Claude Code, choose **File → Open Folder**, and pick the EA folder you just created
> 4. Then paste the setup message again
>
> This way your EA has a clean home and we don't pollute your other projects."

Then stop and wait for them to do that.

**Once in the EA folder**, clone the starter repo as a hidden subdirectory (so it's out of the way but available):

```bash
[ -d ./.workshop-starter ] && (cd .workshop-starter && git pull --quiet) || git clone --quiet https://github.com/Mattyreed1/fractal-ai-workshop-ea-starter.git ./.workshop-starter
```

Verify the clone worked:
```bash
[ -d ./.workshop-starter/claude-skills ] && echo "READY" || echo "CLONE FAILED"
```

All references to `<REPO>` below mean `./.workshop-starter` (relative to the EA folder).

Tell the user:
> "I've got the workshop starter cloned. Let me get you set up."

---

## Step 1: Pre-flight Checks

Check Node.js (needed for the MCP servers):

```bash
node --version 2>/dev/null || echo "NOT_INSTALLED"
```

**If Node.js is not installed**, stop and tell the user:
> "I need Node.js installed before we can wire up your tools. Quick fix:
>
> 1. Go to https://nodejs.org
> 2. Click the big green button to download
> 3. Open the downloaded file and follow the installer
> 4. When it's done, come back here and say 'set me up' again"

Do NOT continue until Node.js is available.

Also check if Claude Code config file exists:

```bash
[ -f ~/.claude.json ] && echo "CONFIG_EXISTS" || echo "CONFIG_MISSING"
```

If missing, that's fine — Step 4 creates it.

Check if any of the 3 skills are already installed:

```bash
for s in openclaw-vps-setup n8n notion; do
  [ -e ~/.claude/skills/$s ] && echo "$s: present" || echo "$s: missing"
done
```

If all 3 are present AND `~/.claude.json` already has both `n8n` and `notion` MCP servers configured, jump to Step 8 (Verify).

---

## Step 2: Install the 3 Skills

Make sure the skills directory exists:

```bash
mkdir -p ~/.claude/skills
```

Copy each skill from the cloned repo:

```bash
cp -R ./.workshop-starter/claude-skills/openclaw-vps-setup ~/.claude/skills/
cp -R ./.workshop-starter/claude-skills/n8n ~/.claude/skills/
cp -R ./.workshop-starter/claude-skills/notion ~/.claude/skills/
```

Verify:
```bash
for s in openclaw-vps-setup n8n notion; do
  [ -f ~/.claude/skills/$s/SKILL.md ] && echo "$s: ✓" || echo "$s: ✗ MISSING"
done
```

Tell the user:
> "I installed 3 skills:
> - **n8n** — teaches me how to build n8n workflows for you
> - **notion** — teaches me how to read + write your Notion pages
> - **openclaw-vps-setup** — teaches me how to set up your own AI agent server (we'll use this in Build #2 of the workshop)"

---

## Step 3: Ask Setup Questions

Ask one at a time. Use the AskUserQuestion tool when you have it; otherwise just prompt directly.

**Q1.** What's your first name? (Used in your personalized CLAUDE.md.)

**Q2.** Do you have an n8n account?
- Yes, I use **n8n Cloud** (e.g. `yourname.app.n8n.cloud`)
- Yes, I run my own n8n server
- No, I need to sign up

If they need to sign up:
> "n8n is the workflow automation tool we'll use tomorrow. Free signup:
> https://n8n.partnerlinks.io/6w47oeg6f6v0
>
> Once you've signed up, come back and tell me your URL — should look like `yourname.app.n8n.cloud`."

Wait until they have a URL.

**Q3.** What's your n8n URL? (Example: `matt.app.n8n.cloud` — no `https://` prefix)

**Q4.** Do you have a Notion account? (Almost everyone does. If not: https://notion.so/signup, then come back.)

Save: `<NAME>`, `<N8N_URL>`, and the answer to Q4. We'll need an n8n API key (Step 4) and a Notion integration token (Step 5).

---

## Step 4: Wire the n8n MCP Server

Tell the user:
> "Now I need an API key from your n8n. Here's how to get one (takes 30 seconds):
>
> 1. Go to https://<N8N_URL>
> 2. Click your **profile picture** in the bottom-left corner
> 3. Click **Settings**
> 4. Click **API** in the left sidebar
> 5. Click **Create an API key**
> 6. Name it 'Claude Code'
> 7. Copy the key (starts with `eyJ...`) and paste it here"

Wait for them to paste their API key. **Don't echo it back in plain text** — confirm length only (e.g. "got it, that's a 200-character key").

Now add the MCP server to `~/.claude.json`. Use this approach:

```bash
python3 - <<'PY'
import json, os
path = os.path.expanduser("~/.claude.json")
try:
    with open(path) as f:
        cfg = json.load(f)
except FileNotFoundError:
    cfg = {}
cfg.setdefault("mcpServers", {})
cfg["mcpServers"]["n8n"] = {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "n8n-mcp"],
    "env": {
        "MCP_MODE": "stdio",
        "LOG_LEVEL": "error",
        "DISABLE_CONSOLE_OUTPUT": "true",
        "N8N_API_URL": "https://<N8N_URL>",
        "N8N_API_KEY": "<API_KEY>"
    }
}
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
print("n8n MCP server added")
PY
```

Replace `<N8N_URL>` and `<API_KEY>` with the actual values before running.

Verify:
```bash
python3 -c "import json; d=json.load(open('$HOME/.claude.json')); print('n8n' in d.get('mcpServers', {}))"
```

Should print `True`.

Tell the user:
> "n8n is wired. Claude Code can now create and edit workflows directly on your account."

---

## Step 5: Wire the Notion MCP Server

Tell the user:
> "Now Notion. I need an Internal Integration Token. Takes about a minute:
>
> 1. Go to https://www.notion.so/my-integrations
> 2. Click **+ New integration**
> 3. **Name** it 'Claude Code'
> 4. Pick the **workspace** you want me to access
> 5. Under **Capabilities**: keep all 3 content capabilities checked (Read, Update, Insert)
> 6. Click **Submit**
> 7. Copy the **Internal Integration Token** (starts with `ntn_...` or `secret_...`)
> 8. Paste it here"

Wait for the token. Confirm length only, don't echo.

> "One more important thing: I can only see Notion pages and databases that are **shared with this integration**. Any page you want me to access:
>
> - Open the page in Notion
> - Click the `...` menu (top-right)
> - Click **Connect to** → select **Claude Code**
>
> Do this for the pages/databases you want me to help with. You can do it now or any time later."

Now add the Notion MCP server:

```bash
python3 - <<'PY'
import json, os
path = os.path.expanduser("~/.claude.json")
with open(path) as f:
    cfg = json.load(f)
cfg.setdefault("mcpServers", {})
cfg["mcpServers"]["notion"] = {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@notionhq/notion-mcp-server"],
    "env": {
        "OPENAPI_MCP_HEADERS": '{"Authorization":"Bearer <TOKEN>","Notion-Version":"2022-06-28"}'
    }
}
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
print("notion MCP server added")
PY
```

Replace `<TOKEN>` with the actual token before running.

Verify:
```bash
python3 -c "import json; d=json.load(open('$HOME/.claude.json')); print('notion' in d.get('mcpServers', {}))"
```

Should print `True`.

Tell the user:
> "Notion is wired. Once you restart Claude Code, I'll be able to read + write to any page you share with the integration."

---

## Step 6: Create the EA workspace files

You'll create three project-local files in the current EA folder. These belong to the user's EA workspace and are theirs to edit any time.

### 6a. `CLAUDE.md` — your EA's instructions

Check if it exists:
```bash
[ -f ./CLAUDE.md ] && cat ./CLAUDE.md || echo "MISSING"
```

If it exists and has a "Fractal AI Workshop" section: ask if they want to update it.
If it doesn't exist OR doesn't have the section: write the file with this content (replace `<NAME>` and `<N8N_URL>`):

```markdown
# <NAME>'s Executive Assistant

I'm <NAME>'s Executive Assistant. This file is my operating manual.

## Who <NAME> is

See `USER.md` in this folder for personal context (background, preferences, current focus).

## Connected Tools

- **n8n:** https://<N8N_URL> — I can build, edit, and test workflows directly
- **Notion:** read + write any page/database <NAME> shares with the Claude Code integration

## My Skills

| Skill | When I use it |
|-------|---------------|
| `n8n` | Building workflows + sub-skills for code nodes, expressions, validation |
| `notion` | Reading/writing Notion pages and databases |
| `openclaw-vps-setup` | Setting up <NAME>'s VPS to host AI agents (Workshop Build #2) |

## Defaults

- Show the plan before building anything non-trivial
- Validate workflows before declaring done
- Keep explanations simple, plain prose
- Ask before destructive actions
- Save deliverables to the `projects/` folder unless told otherwise

## Layout

- `CLAUDE.md` — this file (my instructions)
- `USER.md` — about <NAME>
- `projects/` — where deliverables go
- `.workshop-starter/` — cloned starter repo (source of skills; out of the way)
```

Write it:
```bash
cat > ./CLAUDE.md <<'EOF'
[full content above with <NAME> + <N8N_URL> substituted]
EOF
```

### 6b. `USER.md` — about the user

Check if it exists:
```bash
[ -f ./USER.md ] && cat ./USER.md || echo "MISSING"
```

If it doesn't exist, write a starter file (replace `<NAME>`):

```markdown
# About <NAME>

> This file is loaded into context every Claude Code session. Edit freely.

## Identity

- **Name:** <NAME>
- **Domain:** [edit: e.g. AEC operator in NZ targeting a COO seat]
- **What I'm working on:** [edit: current focus or top priority]

## How I work

- [edit: e.g. "Mornings for deep work, afternoons for ops"]
- [edit: preferred communication style]

## Pet peeves

- [edit: things to avoid — e.g. emoji-laden replies, excessive bullet points, premature conclusions]

## Tools I use day-to-day

- n8n
- Notion
- [edit: add others — Slack, Gmail, etc.]

## People in my world (optional)

| Name | Role | When to involve |
|------|------|-----------------|
| [edit] | [edit] | [edit] |
```

Write it:
```bash
cat > ./USER.md <<'EOF'
[full content above with <NAME> substituted]
EOF
```

### 6c. `projects/` — where deliverables go

```bash
mkdir -p ./projects
```

Tell the user:
> "I created three things in your EA folder:
> - **`CLAUDE.md`** — my operating manual. Loaded into context every session.
> - **`USER.md`** — a starter file about you. I left placeholders — fill them in when you have 5 minutes. The more I know about your work, the better I help.
> - **`projects/`** — where I'll save deliverables (briefs, drafts, reports) unless you tell me otherwise.
>
> Open the EA folder in Finder any time to see what I'm doing."

---

## Step 7: Create Settings File

Check if `~/.claude/settings.json` already exists:

```bash
[ -f ~/.claude/settings.json ] && cat ~/.claude/settings.json || echo "MISSING"
```

If it exists and already includes `Read(~/.claude/skills/**)` in the allow array: skip this step.

If it exists but doesn't include the skill permissions: add them to the existing allow array. Don't overwrite other permissions.

If it doesn't exist: create it:

```json
{
  "permissions": {
    "allow": [
      "Read(~/.claude/skills/**)",
      "Read(~/.claude/**)"
    ]
  }
}
```

Tell the user:
> "Permissions set up. I can access your skills automatically going forward."

---

## Step 8: Verify Everything

Run all checks:

```bash
echo "--- Global: skills ---"
for s in openclaw-vps-setup n8n notion; do
  [ -f ~/.claude/skills/$s/SKILL.md ] && echo "$s: ✓" || echo "$s: ✗ MISSING"
done

echo "--- Global: files ---"
[ -f ~/.claude/settings.json ] && echo "settings.json: ✓" || echo "settings.json: ✗ MISSING"

echo "--- Global: MCP servers ---"
python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.claude.json'))); s=d.get('mcpServers',{}); print('n8n:', '✓' if 'n8n' in s else '✗'); print('notion:', '✓' if 'notion' in s else '✗')"

echo "--- EA workspace files ---"
[ -f ./CLAUDE.md ] && echo "CLAUDE.md: ✓" || echo "CLAUDE.md: ✗ MISSING"
[ -f ./USER.md ] && echo "USER.md: ✓" || echo "USER.md: ✗ MISSING"
[ -d ./projects ] && echo "projects/: ✓" || echo "projects/: ✗ MISSING"
[ -d ./.workshop-starter ] && echo ".workshop-starter/: ✓" || echo ".workshop-starter/: ✗ MISSING"
```

Report the results to the user. If anything's missing, offer to fix it.

---

## Step 9: Restart + What's Next

If everything checks out:

> "**You're all set!** Three things before our session tomorrow:
>
> **1. Restart Claude Code.** Quit completely (Cmd+Q on Mac, fully close on Windows) and reopen. The MCP connections only activate after a fresh start.
>
> **2. Verify after restart.** Open a new chat and paste:
>    > *Check my setup*
>
>    I'll confirm everything's wired.
>
> **3. Try one quick test.** After verification, ask me:
>    > *List my n8n workflows.*
>
>    or
>
>    > *Search my Notion for [something].*
>
>    If those return results, you're 100% ready for tomorrow."

If "check my setup" was the trigger and everything's already in place:
> "Looks good. You're ready for the workshop. See you tomorrow."

---

## Troubleshooting

### "n8n MCP isn't showing up"

Almost always: Claude Code wasn't fully restarted. Tell them to **fully quit** Claude Code (Cmd+Q on Mac, not just close the window), then reopen.

### "I don't have the API key starting with eyJ..."

n8n API keys begin with `eyJ` (it's a JWT). If theirs is different, they may have copied something else. Have them try Settings → API → Create new key.

### "Notion says 'page not found'"

The page hasn't been shared with the integration. Have them open the page in Notion → `...` → Connect to → select Claude Code.

### "Notion token starts with `secret_` not `ntn_`"

Both formats are valid. Older integrations use `secret_`, newer ones use `ntn_`. Either works.

### "It says 'command not found: npx'"

Node.js isn't on the PATH. Tell them to fully restart their computer after installing Node, then try again.

### Skills folder is wrong

If `cp` fails with "no such file or directory", check:
```bash
ls ~/fractal-ai-workshop-ea-starter/claude-skills/
```
Should show `openclaw-vps-setup`, `n8n`, `notion`. If not, the clone failed — re-clone.

---

## Key Reference

### File Locations

**Global (apply to all Claude Code projects on this machine):**
- Skills: `~/.claude/skills/{openclaw-vps-setup,n8n,notion}/`
- Settings: `~/.claude/settings.json`
- MCP config: `~/.claude.json`

**Project-local (in the user's EA workspace folder):**
- `CLAUDE.md` — instructions
- `USER.md` — about the user
- `projects/` — deliverables
- `.workshop-starter/` — hidden source repo (where skills were copied from)

### Signup Links (give to user as needed)

- Claude Code: https://claude.ai/code
- n8n Cloud: https://n8n.partnerlinks.io/6w47oeg6f6v0
- Notion: https://notion.so/signup
- Notion Integrations: https://www.notion.so/my-integrations
