---
name: openclaw-vps-setup
description: >-
  Provision a fresh Hetzner VPS from scratch to run an OpenClaw multi-agent
  stack with Discord chat as the visible I/O layer. Walks through SSH key
  setup, Docker install, OpenClaw clone, the 4-Layer Agent Architecture
  (shared DNA + TEAM, per-agent SOUL + AGENTS + MEMORY), Discord plugin wiring,
  and the repeatable 7-step playbook for onboarding additional agents. Use
  when setting up YOUR OWN VPS for AI agents from zero. Triggers on "set up
  my VPS", "deploy openclaw", "provision agent infrastructure", "onboard a
  new agent", "add a molty", "add an agent to my VPS", "set up a fresh
  hetzner box". DOES NOT manage an existing OpenClaw instance — for that,
  use the `molty` skill.
license: MIT
metadata:
  version: 0.2.0
  audience: non-coder operators using Claude Code to provision their own agent infra
---

# OpenClaw VPS Setup

Spin up a fresh Hetzner VPS, install OpenClaw in Docker, set up the 4-Layer Agent Architecture (DNA as the team's shared SOUL + TEAM as the shared coordination rulebook, plus per-agent SOUL + AGENTS + HEARTBEAT + MEMORY files for each individual agent), deploy the first Molty agent into a dedicated Discord channel, then onboard 2-3 more using the same playbook each time. Designed for operators who have Claude Code installed but no ops experience.

## Triggers

| Trigger phrase | Maps to |
|----------------|---------|
| "set up my VPS" / "provision my agent infra" / "deploy openclaw" | Full Phase 1-6 setup |
| "onboard a new agent" / "add a molty" / "add an agent to my VPS" | The 7-step onboarding playbook |
| "fresh hetzner box for openclaw" | Phase 1-2 only (provision + Docker) |
| "wire discord into openclaw" | Phase 5 only |
| "check my agents" / "openclaw maintenance" | Maintenance section |

## When NOT to use this skill

| Situation | Use instead |
|-----------|-------------|
| Managing an already-deployed OpenClaw instance (logs, restarts, debugging) | `molty` |
| Translating a Claude Code skill to run on the VPS | `skill-translate` |
| Setting up Slack instead of Discord | Adapt Phase 5 — see `references/slack-alternative.md` |

## Architecture overview

```
Your laptop                Hetzner VPS (€5/mo)            Discord
  Claude Code  ──ssh──▶    Docker                          server
  + this skill              └─ openclaw-gateway            ├─ #agent-1
                                ├─ Agent 1 ──── reads ───▶ │
                                ├─ Agent 2 ──── reads ───▶ ├─ #agent-2
                                └─ Agent 3 ──── reads ───▶ └─ #agent-3
                                   │
                              ~/.openclaw/
                              ├─ shared/         ◄── ALL agents read these
                              │   ├─ DNA.md          (team culture)
                              │   └─ TEAM.md         (coordination rules)
                              └─ workspace/<agent>/   ◄── private to each agent
                                  ├─ SOUL.md         (personality)
                                  ├─ AGENTS.md       (ops config)
                                  ├─ HEARTBEAT.md    (per-wake routine)
                                  ├─ MEMORY.md       (this agent's append-only log)
                                  └─ WORKING.md      (current task state)
```

This MVP omits Convex blackboard, custom wake-worker, and other advanced patterns. Add later — see `references/runbook.md` § "What this MVP does NOT include".

## The 4-Layer Agent Architecture

Every agent on this team has 4 files loaded into context every wake. Same model whether you have 1 agent or 10.

The key insight: **DNA is the team's shared SOUL.** It's the identity layer all agents inherit before they're anything specific. Each agent's individual SOUL.md sits on top of that shared DNA and adds the personal layer — voice, role, what makes THIS agent distinct.

| Layer | File | Per-agent? | Purpose |
|-------|------|------------|---------|
| 1. **DNA** | `DNA.md` | **Shared** | The team's shared SOUL — identity all agents inherit (culture, anti-slop, non-negotiables) |
| 2. **SOUL** | `SOUL.md` | Unique | This agent's personal layer on top of the shared DNA — voice, role, personality |
| 3. **AGENTS** | `AGENTS.md` | Unique | Tools, tier, hard rules, heartbeat protocol |
| 4. **TEAM** | `TEAM.md` | **Shared** | Handoff protocol, decision protocol, quality bar |

Plus a **per-agent memory file**:
- **`MEMORY.md`** — each agent's private append-only log. Lives in that agent's workspace, only that agent reads and writes it.

**Cross-agent coordination happens in Discord, not in shared files.** Agent A finishes a piece of work and `@mentions` Agent B in B's channel; B sees it on next wake. This MVP intentionally has no file-based shared memory layer — that comes later via the OB1 extension (see Extension Points). Until then, the source of truth for cross-agent handoffs is Discord, and each agent's private MEMORY.md is for its own continuity, not the team's.

This pattern is the take-home model:
- **Shared identity stack**: DNA (team SOUL) + TEAM (coordination contract) — same for every agent.
- **Per-agent stack on top**: SOUL (your personal layer over DNA) + AGENTS (ops) + HEARTBEAT (wake routine) + MEMORY (private continuity log).
- **Live coordination**: Discord channels — one per agent, `@mentions` for handoffs.

Without this layering, agents are isolated chatbots that feel different from each other and forget the team they belong to. With it, they're a coordinated team — every agent recognizably part of the same team (DNA), but with its own face (SOUL).

## Pre-flight checklist

Before invoking the skill, the user needs:

- [ ] Hetzner Cloud account + valid payment method (no VPS yet — we provision live)
- [ ] Discord account + a server they own (or admin permission on one)
- [ ] An LLM API key (Anthropic, OpenAI, or OpenRouter — Anthropic recommended for Claude Sonnet)
- [ ] SSH key on their machine (we generate one if missing)
- [ ] Claude Code installed and working

If any of these are missing, prompt the user to set them up before proceeding. Don't try to substitute or skip.

## Phase 1 — Provision the VPS (Hetzner)

Goal: a running Linux server they can `ssh` into.

**Step 1.1 — Generate an SSH key (skip if they already have one).**

Check if `~/.ssh/id_ed25519_openclaw.pub` exists. If not, run:
```bash
ssh-keygen -t ed25519 -C "openclaw-vps" -f ~/.ssh/id_ed25519_openclaw -N ""
```
Then display the public key:
```bash
cat ~/.ssh/id_ed25519_openclaw.pub
```
Tell the user: "Copy that whole line — you'll paste it into Hetzner in the next step."

**Step 1.2 — Add the key to Hetzner (web UI, ~2 min).**

Walk the user through this exactly:
1. Open https://console.hetzner.cloud (sign up if needed; verify email).
2. Top-right project menu → if no project exists, create one called "openclaw".
3. Left sidebar → **Security** → **SSH Keys** tab → **Add SSH Key** button.
4. Paste the public key from Step 1.1. Name it "openclaw-mac" (or similar). Save.

**Step 1.3 — Create the server (~2 min).**

1. Left sidebar → **Servers** → **Add Server**.
2. **Location:** pick the data center geographically closest to them.
3. **Image:** Ubuntu 24.04.
4. **Type:** under "Shared vCPU" tab, pick **CX22** (€5/mo, 2 vCPU, 4GB RAM, 40GB disk).
5. **Networking:** IPv4 + IPv6 (default is fine).
6. **SSH Key:** check the box for the key you just added.
7. **Name:** "openclaw-vps".
8. **Create & Buy Now**.

Wait ~30s for status to show "Running". Copy the **public IPv4** address — they'll need it for SSH.

**Step 1.4 — Add SSH config entry on user's Mac.**

Append to `~/.ssh/config` (create the file if missing):
```
Host openclaw-vps
  HostName <PASTE_IP_HERE>
  User root
  IdentityFile ~/.ssh/id_ed25519_openclaw
  AddKeysToAgent yes
```

**Step 1.5 — Verify SSH connection.**

```bash
ssh -o ConnectTimeout=10 openclaw-vps 'echo ok && uname -a'
```
Should return `ok` and Linux info. If "Permission denied" → see `references/troubleshooting.md` § SSH.

**Step 1.6 — Create non-root user (security).**

Running as `root` is a foot-gun. Create `deploy`:
```bash
ssh openclaw-vps 'adduser --disabled-password --gecos "" deploy && \
  usermod -aG sudo deploy && \
  mkdir -p /home/deploy/.ssh && \
  cp ~/.ssh/authorized_keys /home/deploy/.ssh/ && \
  chown -R deploy:deploy /home/deploy/.ssh && \
  chmod 600 /home/deploy/.ssh/authorized_keys'
```
Then update `~/.ssh/config` — change `User root` to `User deploy`. Verify: `ssh openclaw-vps 'whoami'` returns `deploy`.

✅ **Phase 1 complete = `ssh openclaw-vps` lands you in a `deploy` shell.**

## Phase 2 — Install Docker + clone OpenClaw

**Step 2.1 — Install Docker (one-liner, ~30s).**
```bash
ssh openclaw-vps 'curl -fsSL https://get.docker.com | sudo sh && \
  sudo usermod -aG docker deploy'
```

**Step 2.2 — Reconnect SSH** so the docker group takes effect:
```bash
ssh openclaw-vps 'docker --version'
```
Should print version without `sudo`. If "permission denied" → reconnect once more.

**Step 2.3 — Clone OpenClaw + create the directory skeleton.**
```bash
ssh openclaw-vps 'git clone https://github.com/openclaw/openclaw.git ~/openclaw && \
  mkdir -p ~/.openclaw/shared ~/.openclaw/workspace'
```

**Step 2.4 — Pull the OpenClaw image (pinned to known-good tag).**
```bash
ssh openclaw-vps 'docker pull ghcr.io/openclaw/openclaw:2026.4.23'
```
DO NOT use `:2026.4.24` — known to hang at startup. See `troubleshooting.md`.

✅ **Phase 2 complete = Docker working + OpenClaw cloned + image pulled.**

## Phase 3 — Set up the SHARED layers

Goal: DNA and TEAM — the two files all agents will inherit. Per-agent files (SOUL, AGENTS, HEARTBEAT, MEMORY) come in Phase 4.

**Step 3.1 — Copy shared templates from this skill to the VPS.**

```bash
# From your laptop (where this skill lives):
SKILL=~/.claude/skills/openclaw-vps-setup
ssh openclaw-vps 'mkdir -p ~/.openclaw/shared'
scp $SKILL/assets/DNA.md openclaw-vps:~/.openclaw/shared/DNA.md
scp $SKILL/assets/TEAM.md openclaw-vps:~/.openclaw/shared/TEAM.md
```

**Step 3.2 — Lightly customize `TEAM.md`.**

Update the "Team roster" table at the top — leave the rows blank for now (you'll fill them as agents come online). The handoff and decision protocols use Discord `@mentions` as the coordination mechanism and work as-is.

**Step 3.3 — Review `DNA.md`.**

The default DNA is reasonable for most teams. If the user wants to add team-specific values or rules, edit it now. Keep it tight — under 100 lines.

> **Note:** No shared `MEMORY.md` or `KNOWLEDGE.md` in this MVP. Each agent gets its own private `MEMORY.md` during onboarding (Phase 4). Cross-agent coordination happens via Discord. The OB1 extension (Extension Points) is the planned upgrade path for structured shared memory.

✅ **Phase 3 complete = 2 shared files exist on VPS in `~/.openclaw/shared/`: `DNA.md` + `TEAM.md`.**

## Phase 4 — Configure the first agent (SOUL + AGENTS)

Goal: a working `openclaw.json` + per-agent `SOUL.md` + per-agent `AGENTS.md` for agent #1.

**Step 4.1 — Pick agent #1's role** with the user. AEC starters provided in `assets/`:
- `SOUL-rfi-triager.md` (RFI Triager)
- `SOUL-submittal-reviewer.md` (Submittal Reviewer)
- `SOUL-comms-drafter.md` (Client Comms Drafter)
- `SOUL.md.template` (blank — fill in for any role)

**Step 4.2 — Push the SOUL.md.**

```bash
SLUG=rfi_triager  # or whatever role
ssh openclaw-vps "mkdir -p ~/.openclaw/workspace/$SLUG"
scp $SKILL/assets/SOUL-rfi-triager.md openclaw-vps:~/.openclaw/workspace/$SLUG/SOUL.md
```
For custom roles, copy `SOUL.md.template`, edit `<PLACEHOLDERS>`, then push.

**Step 4.3 — Push the AGENTS.md (per-agent ops config).**

```bash
scp $SKILL/assets/AGENTS.md.template openclaw-vps:~/.openclaw/workspace/$SLUG/AGENTS.md
```
Then edit it on the VPS to fill in:
- `<AGENT_NAME>` → the slug (e.g. `rfi_triager`)
- `<MCP_SERVERS>` → e.g. `notion`, or `[]` if none
- `<TIER>` → `LOW`, `MEDIUM`, or `HIGH`
- `<HEARTBEAT_MIN>` → e.g. `60`
- Channel name (set in Phase 5)

**Step 4.4 — Push the HEARTBEAT.md.**

```bash
scp $SKILL/assets/HEARTBEAT.md.template openclaw-vps:~/.openclaw/workspace/$SLUG/HEARTBEAT.md
```
Edit `<AGENT_NAME>` and `<HEARTBEAT_MIN>` placeholders.

**Step 4.5 — Push the agent's MEMORY.md (private memory file).**

```bash
scp $SKILL/assets/workspace/MEMORY.md.template openclaw-vps:~/.openclaw/workspace/$SLUG/MEMORY.md
```
Edit `<AGENT_NAME>` placeholder. Each agent has its own MEMORY.md — never share one across agents. Cross-agent coordination happens via Discord, not this file.

**Step 4.6 — Render `openclaw.json`** from `assets/openclaw.json`. Edit:
- Replace `<AGENT_NAME>` with the chosen role slug (e.g. `rfi_triager`)
- Set the model (default `anthropic/claude-sonnet-4.7`)
- `heartbeat_minutes` (default 60)
- Discord token env var name + channel ID (will be set in Phase 5; placeholder for now)

Push: `scp /tmp/openclaw.json openclaw-vps:~/.openclaw/openclaw.json`

✅ **Phase 4 complete = agent #1's SOUL, AGENTS, HEARTBEAT, MEMORY exist on VPS + entry in openclaw.json.**

## Phase 5 — Wire Discord

Goal: agent #1's chat I/O lands in a dedicated, locked-down Discord channel where ONLY the user and the team's other agent bots can talk to it. No random server members.

**Security model: defense in depth.** Two layers enforce who can reach the bot:
1. **Channel-level (Discord-native):** the agent channel is private; only the user + agent bots have View/Send. Other server members can't see it.
2. **Bot-level (OpenClaw `allowFrom`):** even if someone is mistakenly added to the channel, the bot's `allowFrom` list whitelists Discord user IDs and silently ignores everyone else.

Set both. Either alone is brittle; together they're solid.

**Step 5.1 — Create the Discord bot** (web UI, ~3 min):
1. Open https://discord.com/developers/applications → **New Application** → name it `<role>-agent` (e.g. `rfi-triager-agent`).
2. **Bot** tab in left sidebar → **Add Bot** → confirm.
3. Scroll down to **Privileged Gateway Intents** → toggle on **Message Content Intent**. Save.
4. Scroll up → **Reset Token** → copy the token (starts with `M...`). Keep it safe; you'll only see it once.

**Step 5.2 — Invite the bot to the user's server.**
1. **OAuth2** tab → **URL Generator**.
2. **Scopes:** check `bot`.
3. **Bot Permissions:** check `Send Messages`, `Read Message History`, `View Channels`.
4. Copy the URL at the bottom, open in browser, select the user's server, click **Authorize**.

**Step 5.3 — Create the dedicated PRIVATE channel.**

In Discord (the user's server):
1. Next to "Text Channels", click `+` → **Create Channel**.
2. Channel type: **Text**. Name: `<role>-agent` (e.g. `rfi-triager-agent`).
3. Toggle **Private Channel** ON. Click **Next**.
4. On the "Add members or roles" screen: leave it **empty** for now (we'll add members in step 5.3.5). Click **Create Channel**.
5. Right-click the new channel → **Edit Channel** → **Permissions**:
   - `@everyone` is automatically denied — leave it that way.
   - Click `+` next to "Members" → search for and add **yourself** (your Discord user). Grant `View Channel`, `Read Message History`, `Send Messages` (green checks).
   - Click `+` again → add the **agent's bot user** (the one you invited in Step 5.2). Grant the same three permissions.
   - (If onboarding more than one agent in the same server) Also add each OTHER agent's bot user with the same permissions — agents need read access to each other's channels to do handoffs.
6. Save.

Net result: only you + the agent bots can view or post in this channel. Other members of your Discord server cannot see it.

**Step 5.4 — Capture the IDs you'll need for the allowlist.**

Make sure Discord Developer Mode is on: User Settings → Advanced → toggle ON **Developer Mode**. Then collect:

| What | How |
|---|---|
| **Channel ID** | Right-click the new agent channel → **Copy Channel ID** (numeric, e.g. `1478105074587668671`) |
| **Your Discord user ID** | Click your username at the bottom-left of Discord → in the popout, right-click your name → **Copy User ID**. Save it — you'll reuse this for every agent. |
| **Each agent bot's user ID** | Right-click the bot user in the channel's member list (or in the server member list) → **Copy User ID**. For agent #1 you only need this one bot's ID; for later agents, you'll need each agent's bot ID. |

> Tip: keep a sticky note (or a scratch `.txt`) with your user ID + every agent bot ID. You'll wire the same set of IDs into every agent's `allowFrom`.

**Step 5.5 — Wire the token + channel + allowlist into `.env` and `openclaw.json`.**

```bash
ssh openclaw-vps 'echo "DISCORD_BOT_TOKEN_AGENT_1=<paste-token>" >> ~/openclaw/.env && \
  echo "ANTHROPIC_API_KEY=<paste-key>" >> ~/openclaw/.env && \
  chmod 600 ~/openclaw/.env'
```

In `~/.openclaw/openclaw.json`, the agent's `channels.discord` block must include `default_channel_id`, `groupPolicy: "allowlist"`, and `allowFrom`:

```json
"channels": {
  "discord": {
    "bot_token_env": "DISCORD_BOT_TOKEN_AGENT_1",
    "default_channel_id": "<channel-id-from-step-5.4>",
    "groupPolicy": "allowlist",
    "allowFrom": [
      "discord:<your-user-id>",
      "discord:<every-other-agent-bot-user-id>"
    ]
  }
}
```

Allowlist rules:
- Prefix every entry with `discord:` followed by the numeric user ID (e.g. `discord:1234567890123456789`). Plain usernames work too but they're fragile — IDs are stable.
- Include **your** Discord user ID so you can talk to the bot.
- Include **every OTHER agent bot's** Discord user ID so teammates can hand off via `@mention`. Don't include this bot's OWN ID — a bot doesn't message itself.
- `groupPolicy: "allowlist"` tells OpenClaw to ignore any message from a sender NOT in `allowFrom`, even if they're in the channel.

For the first agent (you're solo so far), `allowFrom` is just `["discord:<your-user-id>"]`. You'll grow this list each time you onboard another agent — see the 7-step playbook below.

✅ **Phase 5 complete = bot exists, private channel exists, token stored, channel ID wired, `allowFrom` populated. Only allowlisted IDs can reach this bot.**

## Phase 6 — Boot + verify

**Step 6.1 — Sync canonical skills** (if any to sync; safe to run with none):
```bash
scp $SKILL/scripts/sync_skills.sh openclaw-vps:~/openclaw/sync_skills.sh
ssh openclaw-vps 'chmod +x ~/openclaw/sync_skills.sh && bash ~/openclaw/sync_skills.sh'
```

**Step 6.2 — Boot the gateway:**
```bash
ssh openclaw-vps 'cd ~/openclaw && OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:2026.4.23 docker compose up -d openclaw-gateway'
```
Wait 60-90s for first boot (plugin runtime install).

**Step 6.3 — Verify health:**
```bash
ssh openclaw-vps 'docker ps --format "{{.Names}} {{.Status}}"'
ssh openclaw-vps 'docker logs --tail 30 openclaw-openclaw-gateway-1 2>&1 | tail -30'
```
Look for `Up X seconds (healthy)` and a `[discord] logged in` line.

**Step 6.4 — Trigger the agent.** In Discord, post in the agent's channel:
```
@<bot-name> hello, introduce yourself. What's your role?
```

**Step 6.5 — Watch for response** within 30-60s. If silent → see `references/troubleshooting.md` § "Agent silent on first @mention".

✅ **Phase 6 complete = first agent posting in Discord, in-character per its SOUL+AGENTS+DNA+TEAM context.**

## The 7-Step Onboarding Playbook (additional agents)

Run this for each new agent (~7 min each once muscle memory). Keep `assets/agent-entry.json` snippet on hand.

| Step | Action | Time |
|------|--------|------|
| 1 | **Pick role.** Show user a SOUL.md draft from `assets/` (or copy `SOUL.md.template` and fill in) | 60s |
| 2 | **Edit SOUL.md + AGENTS.md + HEARTBEAT.md** for the new agent. Push all three plus a fresh `MEMORY.md` (from `assets/workspace/MEMORY.md.template`) to `~/.openclaw/workspace/<slug>/` | 90s |
| 3 | **Create the Discord bot + private channel** for the new agent (Phase 5 Steps 5.1-5.4). Capture the new bot's user ID. | 3 min |
| 4 | **Append agent entry** to `~/.openclaw/openclaw.json` from `assets/agent-entry.json` snippet — replace `<AGENT_NAME>`, `<DISCORD_TOKEN_VAR>`, `<CHANNEL_ID>`, `<HEARTBEAT_MIN>`, AND set `allowFrom` to `[discord:<your-user-id>, discord:<bot_1_id>, ..., discord:<bot_N_id>]` (your ID + every OTHER existing agent's bot ID — not the new bot's own ID) | 90s |
| 5 | **Update every other agent's `allowFrom`** in `openclaw.json` to include the new bot's user ID. Without this, existing agents can't accept handoffs from the new one. | 60s |
| 6 | **Add new env var** to `~/openclaw/.env` (new bot token) and invite each OTHER agent's bot into the new private channel (so they can read it for handoffs) | 60s |
| 7 | **Restart gateway:** `ssh openclaw-vps 'cd ~/openclaw && docker compose restart openclaw-gateway'` then `@mention` the new agent in its channel. Verify response. | 90s |

The new agent inherits the shared `DNA.md` and `TEAM.md` — no need to recreate those. That's the leverage. It also gets its own private `MEMORY.md` in `workspace/<agent>/` (copied from `assets/workspace/MEMORY.md.template`).

For the long-form runbook with annotations, see `references/onboarding-playbook.md`.

## Maintenance

| Op | Command |
|----|---------|
| Live logs | `ssh openclaw-vps 'docker logs -f openclaw-openclaw-gateway-1 --tail 50'` |
| Search errors | `ssh openclaw-vps 'docker logs openclaw-openclaw-gateway-1 2>&1 \| grep -i error \| tail -20'` |
| Restart gateway | `ssh openclaw-vps 'cd ~/openclaw && docker compose restart openclaw-gateway'` |
| Stop everything | `ssh openclaw-vps 'cd ~/openclaw && docker compose down'` (does NOT shut down the VPS) |
| Update OpenClaw image | See `references/runbook.md` § "Image swap procedure" |
| Sync new/updated skills | `bash ~/openclaw/sync_skills.sh` (run on VPS) |
| Read an agent's memory | `ssh openclaw-vps 'cat ~/.openclaw/workspace/<agent>/MEMORY.md'` |
| Edit shared team contract | `ssh openclaw-vps 'nano ~/.openclaw/shared/TEAM.md'` |

## Anti-Patterns

| Avoid | Why | Instead |
|-------|-----|---------|
| Putting bot tokens directly in `openclaw.json` | Secrets leak into version control | Use `<VAR>_env: TOKEN_NAME` reference, store in `.env` |
| Pulling `ghcr.io/openclaw/openclaw:2026.4.24` | Hangs at startup (upstream bug) | Stay on `:2026.4.23` until upstream fixes 4.24 |
| Running OpenClaw as `root` inside the container | Permission conflicts; security risk | Default config uses `node` user — leave it alone |
| `shutdown now` on the VPS | Kills the whole server | `docker compose down` for containers only |
| Reusing the same Discord bot token across agents | Each agent should have its own identity for visibility | One bot per agent, one channel per agent |
| Leaving the agent channel public (visible to `@everyone`) | Anyone in the server can talk to the bot — including in shared servers with teammates or accidental invitees | Private channel; only user + agent bots have View + Send permissions |
| Omitting `allowFrom` (or leaving `groupPolicy` unset) | Bot responds to anyone who can reach the channel, even if channel perms get changed later | Always set `groupPolicy: "allowlist"` + populate `allowFrom` with user ID + every other agent bot ID |
| Adding usernames (not IDs) to `allowFrom` | Names change with display name updates and break the allowlist silently | Use numeric Discord user IDs prefixed with `discord:` (e.g. `discord:1234567890123456789`) |
| Forgetting to update other agents' `allowFrom` when onboarding a new agent | New agent can post in chat but other agents silently ignore its handoffs | Step 5 of the 7-step playbook: every existing agent's `allowFrom` must include the new bot's user ID |
| Adding agents without restarting gateway | Config not reloaded; new agent silent | Always `docker compose restart` after `openclaw.json` edits |
| Letting agents modify shared `DNA.md` or `TEAM.md` | These are the human's stable team contracts; agent edits cause drift across the whole team | Only the team owner edits these. Each agent appends to its OWN private `MEMORY.md` for its own continuity. |
| Adding a shared `MEMORY.md` or `KNOWLEDGE.md` | Becomes a noisy junk drawer that drowns each agent in irrelevant context | Cross-agent coordination uses Discord `@mentions`. For structured shared memory, wait for the OB1 extension (see Extension Points). |
| Per-agent SOUL.md without DNA.md inherited | Agents become inconsistent — each one feels different | Always set up shared layers (Phase 3) BEFORE per-agent (Phase 4) |

## Verification

After Phase 6 + each onboarding loop:

- [ ] `ssh openclaw-vps 'echo ok'` returns `ok`
- [ ] `docker ps` shows `openclaw-openclaw-gateway-1` as `Up` and `(healthy)`
- [ ] `~/openclaw/.env` has `chmod 600`
- [ ] `~/.openclaw/shared/` contains `DNA.md` and `TEAM.md` (only)
- [ ] `~/.openclaw/workspace/<agent>/` contains `SOUL.md`, `AGENTS.md`, `HEARTBEAT.md`, `MEMORY.md` for each agent
- [ ] Each agent's Discord channel shows at least one bot message
- [ ] Triggering an agent in its channel produces a reply within 60s

## Asset & script reference

| Path | Purpose |
|------|---------|
| `assets/openclaw.json` | Template config — vanilla, single-agent starter |
| `assets/agent-entry.json` | Snippet to paste into `openclaw.json` for each new agent |
| `assets/.env.example` | Env var template — Discord tokens, LLM keys |
| `assets/DNA.md` | **SHARED** team culture (Layer 1) |
| `assets/TEAM.md` | **SHARED** coordination rules (Layer 4) |
| `assets/AGENTS.md.template` | Per-agent operational config (Layer 3) |
| `assets/SOUL.md.template` | Per-agent personality (Layer 2 — blank fill-in) |
| `assets/SOUL-rfi-triager.md` | AEC starter — RFI triage agent SOUL |
| `assets/SOUL-submittal-reviewer.md` | AEC starter — submittal review agent SOUL |
| `assets/SOUL-comms-drafter.md` | AEC starter — client comms drafter SOUL |
| `assets/HEARTBEAT.md.template` | Per-agent wake routine (~50 lines) |
| `assets/workspace/MEMORY.md.template` | Per-agent append-only memory log (private to each agent) |
| `scripts/sync_skills.sh` | Distributes canonical skills to workspace |
| `scripts/onboard_agent.sh` | Helper that runs steps 5-6 of the onboarding playbook |
| `references/runbook.md` | Long-form playbook for non-CC users |
| `references/troubleshooting.md` | Common failures + fixes |
| `references/onboarding-playbook.md` | Annotated 7-step playbook |

## When to call other skills

| If user says... | Invoke |
|-----------------|--------|
| "Send my new skill to the VPS" / "deploy this skill to my agents" | `skill-translate` THEN `molty` (translate first, then sync) |
| "What's wrong with my running molty?" / "check the logs" / "fix the gateway" | `molty` |
| "Set up an agent team for content publishing" / "design 5 agents for my biz" | This skill (provision) — define the 5 SOULs + AGENTS during Phase 4 + 7-step playbook |

## Extension Points

1. **Slack instead of Discord** — full Phase 5 replacement in `references/slack-alternative.md`. Uses OpenClaw's `extensions/slack` plugin via Socket Mode (bot token `xoxb-…` + app-level token `xapp-…`).
2. **OB1 shared memory layer** — install the [OB1 OpenClaw extension](https://github.com/NateBJones-Projects/OB1) for a structured, queryable shared memory across agents. Replaces ad-hoc Discord-only coordination with first-class team memory, knowledge, and handoff primitives. This is the canonical upgrade path from the MVP's per-agent `MEMORY.md` + Discord setup; install once OB1's first stable release is out.
3. **Wake worker (systemd)** — immediate notification-driven wakes (vs polling on heartbeat). Advanced; not needed under ~5 agents.
4. **Per-agent MCP servers** — wire Notion, n8n, Calendar, etc. to specific agents. Add to `mcporter.json` and reference in agent's `mcp_servers` array.
5. **Mem0 / Letta integration** — graduate from file-based shared memory to a dedicated memory service when scale demands it.

## Supersession

These instructions reflect OpenClaw v2026.4.23 patterns as of May 2026. If upstream changes the config schema, image tags, or plugin API, prioritize the upstream docs and update this skill.
