# Fractal AI Workshop EA Starter

Your Claude Code Executive Assistant. Talks to your n8n, your Notion, and your AI agent VPS.

Built for the **Fractal AI Workshop** with [Matty Reed](https://www.linkedin.com/in/mattyreed1).

---

## Setup — All in Claude Code, no terminal

### Before you paste anything

1. **Create a folder called `EA`** somewhere you'll remember (e.g. in your Documents folder). This is your EA's home — it's where deliverables, notes, and configs will live.
2. **Open Claude Code Desktop.**
3. **Open that EA folder** in Claude Code: `File → Open Folder` → pick the `EA` folder you just created.

### Now paste this in the chat

> *Set me up for the Fractal AI Workshop. The repo is at github.com/Mattyreed1/fractal-ai-workshop-ea-starter. Clone it and walk me through the setup.*

Claude Code will:

1. Clone the starter repo as `.workshop-starter` inside your EA folder (hidden, out of the way)
2. Install 3 skills globally into `~/.claude/skills/` (so they work in any project)
3. Ask you for your **n8n URL + API key** (walks you through where to find them)
4. Ask you for your **Notion integration token** (walks you through creating one)
5. Wire both MCP servers in `~/.claude.json`
6. Create three files inside your EA folder:
   - `CLAUDE.md` — instructions Claude reads every session
   - `USER.md` — a starter file about you (fill in placeholders later)
   - `projects/` — folder for deliverables
7. Tell you to quit + reopen Claude Code

Total: ~15 minutes. No terminal commands.

### After restart

Open the EA folder again in Claude Code, then paste:

> *Check my setup*

Confirms everything is wired and ready.

From then on, **every time you want to work with your EA, open Claude Code and open the EA folder.** That's the entry point.

---

## What's inside

| Skill | What it does |
|-------|--------------|
| **`n8n`** | Master skill + 8 sub-skills covering nodes, expressions, code, validation, and template publishing. Lets your CC build n8n workflows by talking. |
| **`notion`** | Read/write Notion pages and databases. Search, query, create, update, append. |
| **`openclaw-vps-setup`** | Provisions a Hetzner VPS, installs OpenClaw in Docker, sets up the 4-Layer Agent Architecture, deploys agents into Discord channels. The take-home from Workshop Build #2. |
| **`claude-code-setup`** | The setup wizard above — walks Claude Code through installing the other skills + wiring the MCP servers. |

---

## What you'll need

- **Claude Code Desktop** ([download](https://claude.ai/code))
- **Node.js** ([download](https://nodejs.org)) — required for the MCP servers
- **n8n account** — Cloud or self-hosted ([free signup](https://n8n.partnerlinks.io/6w47oeg6f6v0))
- **Notion account** ([signup](https://notion.so/signup))

For the **Workshop Build #2** (post-workshop):
- A Hetzner Cloud account (the `openclaw-vps-setup` skill walks you through provisioning)

---

## How to use it after setup

```
You: build an n8n workflow that takes incoming RFIs from a webhook and posts a summary to my Notion project DB
Claude Code: [reads the n8n + notion skills, designs the workflow, builds it via MCP, tests, confirms]
```

```
You: set up my VPS and onboard an RFI triage agent
Claude Code: [reads openclaw-vps-setup skill, walks through provisioning, installs OpenClaw, deploys the agent]
```

```
You: save today's meeting notes to my Notion in the project page for Acme
Claude Code: [searches Notion, finds the page, appends formatted notes]
```

---

## The 90-day plan

After the workshop, see [`docs/90-day-plan.md`](docs/90-day-plan.md):

- **Week 1:** One real task automated, your VPS running, one agent online
- **Month 1:** 2-3 more agents onboarded, shared memory layer in regular use
- **Quarter 1:** Walk into your next role with a working agent team

---

## Already a power user?

If you prefer terminal:

```bash
git clone https://github.com/Mattyreed1/fractal-ai-workshop-ea-starter.git ~/fractal-ai-workshop-ea-starter
cd ~/fractal-ai-workshop-ea-starter
bash install.sh
```

Then wire the MCP servers manually per `claude-skills/claude-code-setup/SKILL.md` Steps 4-5, and restart Claude Code.

The Claude Code wizard path above handles all of this automatically.

---

## License

MIT. Fork it, modify it, sell it.

## Built by

[Matty Reed](https://www.linkedin.com/in/mattyreed1) / [Fractal AI](https://fractalai.agency)
