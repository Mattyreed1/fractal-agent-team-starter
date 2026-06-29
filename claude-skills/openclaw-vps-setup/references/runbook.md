# OpenClaw VPS Setup — Long-form Runbook

This is the human-readable companion to the SKILL.md procedures. Read this if you want to understand WHY each step matters, or if you're working without Claude Code.

---

## Mental model

You are setting up a **multi-agent harness** on a small Linux server. Each agent is a long-running AI that wakes on a schedule, checks for work in its Discord channel, does its job, and goes back to sleep. Agents share infrastructure (one VPS, one OpenClaw instance) but each has its own identity (SOUL.md), its own Discord bot user, and its own channel.

Why VPS instead of laptop?
- Always-on. Your laptop sleeps; the VPS doesn't.
- Cheap (~€5/mo for a small Hetzner box).
- Isolated from your daily work — agents can't burn your terminal.

Why Discord instead of Slack?
- Easier bot setup (token + invite vs Slack app manifests).
- Visible chat is a feature — you watch the agents work, not log files.
- One bot per agent = one identity in chat. Maps cleanly to "team of coworkers."

If you'd rather use Slack — common when the user's team already lives there — see `slack-alternative.md`. The Slack plugin is first-class in OpenClaw (Socket Mode, dual tokens, manifest-driven install); it's just ~2x more clicks in the Slack API console per agent.

Why OpenClaw?
- Open-source agent harness with built-in Discord plugin, Docker packaging, MCP support, skills system.
- Vanilla install runs fine without custom backend (no Convex, no wake-worker required).

---

## Phase 1 — Provision the VPS

**What's happening under the hood:** You're renting a small Linux machine in a Hetzner data center. Hetzner gives you root SSH access. We immediately create a non-root `deploy` user because running everything as root is a foot-gun.

**Why CX22?** It's the smallest box that comfortably runs Docker + 2-3 agents. €5/mo. CX11 is too small for the OpenClaw image's startup memory.

**Why Ubuntu 24.04?** Long-term support release with current Docker apt packages. Avoid Debian for this — package versions lag.

**Common pre-flight gotchas:**
- If `ssh-keygen` says the key already exists, don't overwrite — use the existing one.
- Hetzner's UI puts SSH keys under "Security" not "Access". Easy to miss.
- The IP address Hetzner gives you is the public IPv4. Note it down — you'll need it.

---

## Phase 2 — Install Docker + clone OpenClaw

**Why the official Docker install script?** Distro packages (`apt install docker.io`) lag behind upstream. The `get.docker.com` script always installs current Docker Engine + Docker Compose v2.

**Why pull the image upfront?** First boot takes 60-90s if the image isn't cached locally. Pulling separately gives you a clean checkpoint to verify the image downloaded before you start configuring.

**Pin to `:2026.4.23`.** Per upstream issue, `:2026.4.24` hangs at "starting channels and sidecars…" forever. Symptom: port 18789 bound, but `/healthz` never responds. Stay on `:2026.4.23` until the issue is fixed.

---

## Phase 3 — Set up shared DNA + TEAM layers

Create the shared `DNA.md` and `TEAM.md` files first. Every agent inherits these before its own SOUL/AGENTS files. This keeps the team coherent.

---

## Phase 4 — Configure the first agent

**What `openclaw.json` does:** Top-level config for OpenClaw. Defines:
- Gateway settings (port, bind address — keep `loopback` for security)
- Default model + heartbeat (inherited by agents that don't override)
- Environment variable references (NEVER put secrets here directly)
- Per-agent config (one entry per Molty)

**What `SOUL.md` does:** The agent's identity file. OpenClaw injects this into the agent's system prompt every wake. Think of it as "who are you, what do you do, what are your constraints, what's your tier of autonomy."

**SOUL template fallback:** SOUL.md has a 12-section structure for proper Fractal-AI agents. Don't reinvent it — use `assets/SOUL.md.template` and answer the five role questions in that template. The starters in `assets/SOUL-*.md` are simplified examples for the AEC use case.

**What `HEARTBEAT.md` does:** When an agent wakes (per its heartbeat schedule), OpenClaw shows it the heartbeat file as a "what to do this wake" pointer. Keep it slim — under 3KB. Heavy heartbeat files = more tokens per wake = more cost.

---

## Phase 5 — Wire Discord

**Why one bot per agent?** Each Discord bot is its own user identity in your server. Different name, different avatar, different last-online status. When 3 agents are working, you see 3 distinct identities in 3 channels — that's the visible-collaboration win. If you reused one bot for all agents, every message would say "MoltyBot" and you couldn't tell who's doing what.

**What "Message Content Intent" does:** By default, Discord bots only see messages that @mention them. Enabling Message Content Intent lets the bot see all messages in channels it's in. You need this so the agent can read context, not just respond when summoned. (Discord API rule, not OpenClaw.)

**Why `bot_token_env` instead of inline token?** Tokens in JSON are tokens in version control. Tokens in `.env` (with `chmod 600`) stay on the VPS only. The reference pattern (`bot_token_env: DISCORD_BOT_TOKEN_AGENT_1`) tells OpenClaw to read from the env at runtime.

**Channel ID vs channel name:** OpenClaw needs the numeric channel ID (e.g. `1493616741673074698`), not `#agent-name`. Names can change; IDs don't. Get IDs by enabling Developer Mode in Discord, then right-click → Copy Channel ID.

---

## Phase 6 — Boot + verify

**`sync_skills.sh`:** Copies skills from `~/.openclaw/canonical/skills/` to the agent workspace. Idempotent — safe to re-run. On first install with no canonical skills yet, the script logs that and exits cleanly.

**`docker compose up -d`:** `-d` runs detached (in background). First boot installs plugin runtime deps (browser, discord, etc.) — takes 60-90s. Subsequent restarts are <30s.

**Verifying health:** Three signals:
1. `docker ps` shows status `Up X seconds (healthy)`. The `(healthy)` is from the docker-compose healthcheck — wait for it.
2. `docker logs` shows no `ERROR` lines and a `[discord] logged in` line for your bot.
3. The bot appears as **online** in your Discord server's member list.

**If the bot doesn't respond on first message:** see `troubleshooting.md` § "Agent silent on first @mention".

---

## The 7-Step Onboarding Playbook — annotated

Each new agent takes ~7 min once you're warmed up. The point is **muscle memory** — repetition makes the playbook feel obvious by the third agent.

### Step 1 — Pick role (60s)

Either:
- Use a starter from `assets/SOUL-*.md` (RFI / Submittal / Comms)
- Use `assets/SOUL.md.template` for a custom role

The role determines everything downstream. Don't pick "general assistant" — that's the agent equivalent of an unfocused intern.

### Step 2 — Edit SOUL.md (60s)

Add 1-2 lines specific to the user's environment. For an AEC firm, that's stuff like the firm's preferred spec section format, named team members the agent can defer to, the firm's tone preferences.

### Step 3 — Append agent entry to openclaw.json (90s)

Use `assets/agent-entry.json` as a snippet. Replace 4 placeholders:
- `<AGENT_NAME>` → slug like `submittal_reviewer`
- `<HEARTBEAT_MIN>` → number, e.g. `60`
- `<DISCORD_TOKEN_VAR>` → e.g. `DISCORD_BOT_TOKEN_AGENT_2`
- `<CHANNEL_ID>` → numeric Discord channel ID

Watch for trailing comma issues — JSON is unforgiving.

### Step 4 — Add env var + Discord channel (90s)

In `~/openclaw/.env`, add the new bot token line. In Discord, create the channel + invite the new bot. This step has the most external clicks (Discord UI) so it tends to be the slowest.

### Step 5 — Sync skills (30s)

`bash ~/openclaw/sync_skills.sh` — even if no new skills, it's a no-op confirmation step.

### Step 6 — Restart gateway (30s active, ~30s wait)

`docker compose restart openclaw-gateway`. While it boots, narrate the COO concept: "agents wake on heartbeat, do one slot, sleep. No constant chatter, no token bleed."

### Step 7 — Trigger from Discord + verify (60s)

`@mention` the new bot in its channel. Watch for response within 30-60s. If silent, check `docker logs` for that agent's bot name — most failures are a typo in the bot token or channel ID.

---

## Image swap procedure

When upstream releases a new OpenClaw image and you want to upgrade:

1. **Snapshot config:** `cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.$(date +%s)`
2. **Snapshot env:** `cp ~/openclaw/.env ~/openclaw/.env.bak.$(date +%s)`
3. **Pull new image:** `docker pull ghcr.io/openclaw/openclaw:<new-tag>`
4. **Edit `~/openclaw/.env`** — change `OPENCLAW_IMAGE=` line.
5. **Recreate:** `cd ~/openclaw && docker compose up -d --force-recreate openclaw-gateway`
6. **Wait 4 min, check health:** `docker inspect -f '{{.State.Health.Status}}' openclaw-openclaw-gateway-1`
7. **If healthy:** verify all bots show `connected` in Discord member list.
8. **If unhealthy:** restore both files from backup AND swap image tag back. Schema migration is forward-only so partial rollback breaks things.

---

## Cost expectations

| Item | Monthly |
|------|---------|
| Hetzner CX22 VPS | €5 |
| Anthropic API tokens (3 agents, 60-min heartbeat) | ~$10-30 |
| Discord | $0 |
| **Total** | **~€15-30/mo** |

For comparison: a junior assistant at 10 hours/week × $25/hr = $1,000/mo. The economics work even if the agents only handle the simplest 5% of that workload.

---

## What this MVP does NOT include

By design, to keep setup under 30 min for a non-coder:

- **Convex blackboard** — Matty's setup uses this for shared state across agents. MVP uses Discord channels as the visible state instead. Add Convex when you have 5+ agents and need cross-agent queries.
- **Wake worker (systemd)** — immediate notification-driven wakes. MVP uses heartbeat polling only. Add when you need sub-second handoffs.
- **Per-agent auth profiles** — Matty's setup has each agent on its own OpenAI subscription token. MVP uses one shared API key. Add when you hit single-key rate limits.
- **MCP server matrix** — Matty's setup wires Notion/Calendar/n8n to specific agents. MVP starts with `mcp_servers: []` for each agent. Add per-agent as use cases emerge.
- **Auto-heal cron** — restart gateway if unhealthy. MVP relies on manual restart. Add when you go on vacation.

See `references/leveling-up.md` (TODO) for the upgrade path from MVP to production.
