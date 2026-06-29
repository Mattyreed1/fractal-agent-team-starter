# Fractal Agent Team Starter

The simplest public starter for setting up a Fractal-style AI agent team.

Open one folder in Claude Code, paste one setup prompt, and build from there. No mystery nested project folders. No global config surprises.

## What this helps you set up

- A clean Claude Code workspace for your agent team
- Local project instructions (`CLAUDE.md`, `USER.md`, `projects/`)
- Optional skills from [`fractal-agent-skills`](https://github.com/Mattyreed1/fractal-agent-skills)
- Optional shared memory/task backend from [`fractal-agent-team-memory`](https://github.com/Mattyreed1/fractal-agent-team-memory)
- Optional n8n + Notion MCP connections
- Optional Hetzner VPS setup for hosting agents with OpenClaw

## Recommended setup

### 1. Create the folder you want to use

Example: `FractalAgentTeam` in Documents.

This folder is your agent team's home. Claude should configure **this folder itself**, not create another project inside it.

### 2. Open that folder in Claude Code

Claude Code → `File → Open Folder` → select your `FractalAgentTeam` folder.

### 3. Paste this

```text
Set me up for a Fractal agent team. Use this folder as the project folder. The starter repo is https://github.com/Mattyreed1/fractal-agent-team-starter. Do not create a nested project folder. Walk me through the simplest setup.
```

Claude will:

- confirm it is in the right folder,
- copy the starter files into the current folder if needed,
- create/update `CLAUDE.md`, `USER.md`, and `projects/`,
- recommend the safest default path:
  - **yes** to Fractal agent skills,
  - **yes** to Convex team memory,
  - **not yet** to n8n/Notion unless you already have those accounts ready,
  - **not yet** to Hetzner/OpenClaw until local setup works.


## Best first-run path

For most people, do this in order:

1. **Local workspace** — get Claude Code using the current folder correctly.
2. **Fractal agent skills** — add reusable operating patterns.
3. **Convex team memory** — add shared notes/tasks/status.
4. **One real workflow** — prove value locally.
5. **Hetzner VPS + OpenClaw** — move to always-on hosting after the local loop works.
6. **n8n/Notion** — add integrations when you have a real workflow that needs them.

Do not set up everything on day one. That is how agent projects become spicy.

## The golden rule

> The folder you open in Claude Code is the project. Setup must configure that folder. It must not create `EA/`, `.workshop-starter/`, or another nested working directory unless you explicitly ask for it.

## Setup options

### Minimal local agent workspace

Best if you only want a clean Claude Code assistant/project.

Creates:

```text
CLAUDE.md
USER.md
projects/
.claude/skills/
```

### Add Fractal agent skills

Uses [`fractal-agent-skills`](https://github.com/Mattyreed1/fractal-agent-skills) for reusable workflows like:

- deep deliberation,
- agent collaboration,
- research,
- content workflows,
- skill creation.

### Add team memory

Uses [`fractal-agent-team-memory`](https://github.com/Mattyreed1/fractal-agent-team-memory) as the standard Convex backend for:

- shared notes,
- tasks,
- agent heartbeat/status,
- simple cross-agent coordination.

### Add automation tools

Optional MCP wiring for:

- [n8n](https://n8n.io) workflows,
- [Notion](https://notion.so) pages/databases.

### Add VPS hosting

Use this after local setup and memory work. Hetzner is the standard VPS host and OpenClaw is the agent runtime.

The setup skill walks through:

- SSH key setup,
- Hetzner CX22 VPS creation,
- Docker install,
- OpenClaw install,
- agent files,
- Discord routing,
- basic verification.

## What is inside this repo

| Path | Purpose |
|---|---|
| `claude-skills/claude-code-setup` | Main setup wizard |
| `claude-skills/openclaw-vps-setup` | Hetzner + OpenClaw hosting setup |
| `claude-skills/n8n` | n8n workflow-building skill |
| `claude-skills/notion` | Notion read/write skill |
| `examples/` | Example agent identity files |
| `docs/` | Extra setup/reference docs |

## Terminal setup alternative

If you prefer terminal:

```bash
git clone https://github.com/Mattyreed1/fractal-agent-team-starter.git FractalAgentTeam
cd FractalAgentTeam
bash install.sh
```

Then open the same folder in Claude Code and say:

```text
Check my setup.
```

## Built by

[Matty Reed](https://www.linkedin.com/in/mattyreed1) / [Fractal AI](https://fractalai.agency)

## License

MIT.


## Where users usually trip

- **Wrong folder open:** setup must configure the folder Claude Code has open. If Claude creates a nested folder, stop and correct it.
- **Too many integrations at once:** start with local + skills + memory. Add n8n, Notion, and VPS only when needed.
- **Convex looks stuck:** use `npx convex dev --once` for first setup. Plain `npx convex dev` watches forever.
- **Secrets in chat:** API keys and tokens go into local config files only. Do not paste them into docs or GitHub.
- **No verification:** every setup step should end with a tiny proof: file exists, command works, URL resolves, or agent can answer from the new context.
