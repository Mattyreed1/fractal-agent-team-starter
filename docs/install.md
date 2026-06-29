# Install Walkthrough

This is the detailed version of the README setup.

## Goal

Configure the folder you opened in Claude Code. Do not create a nested project folder.

## Beginner path: Claude Code only

1. Create a folder named `FractalAgentTeam` somewhere easy to find.
2. Open that folder in Claude Code: `File → Open Folder`.
3. Paste:

```text
Set me up for a Fractal agent team. Use this folder as the project folder. The starter repo is https://github.com/Mattyreed1/fractal-agent-team-starter. Do not create a nested project folder. Walk me through the simplest setup.
```

Claude should configure the current folder directly.

## Terminal path

```bash
git clone https://github.com/Mattyreed1/fractal-agent-team-starter.git FractalAgentTeam
cd FractalAgentTeam
bash install.sh
```

Then open `FractalAgentTeam` in Claude Code and say:

```text
Check my setup.
```

## What install.sh does

It is project-local:

- copies starter skills into `./.claude/skills/`,
- creates `projects/`,
- creates `USER.md` if missing,
- creates `CLAUDE.md` if missing.

It does **not** write to global `~/.claude/skills/`.

## Optional add-ons

After the minimal setup, Claude asks whether to add:

- [`fractal-agent-skills`](https://github.com/Mattyreed1/fractal-agent-skills),
- [`fractal-agent-team-memory`](https://github.com/Mattyreed1/fractal-agent-team-memory) with Convex,
- n8n MCP,
- Notion MCP,
- Hetzner VPS + OpenClaw hosting.

Say yes only to what you need now. Keep the first setup small.

## Troubleshooting

### Claude created a folder inside your folder

Stop and tell Claude:

```text
Do not use the nested folder. Configure the current folder directly. Move any useful files back to the current folder and delete the nested starter folder after confirming nothing user-created is inside it.
```

### Claude cannot find the setup skill

Run from the project folder:

```bash
bash install.sh
```

Then restart Claude Code and reopen the same folder.

### Node is missing

Install Node.js from https://nodejs.org, then rerun the optional Convex/n8n/Notion setup.
