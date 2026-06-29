# The 7-Step Onboarding Playbook — Annotated

This is the canonical playbook for adding an agent to an OpenClaw deployment that's already running. Follow it for agents 2, 3, 4… 10. The playbook gets faster every time.

---

## Pre-flight (do once before the playbook)

- [ ] OpenClaw running on the VPS (verified via `docker ps` + first agent in Discord)
- [ ] You have a Discord server you own (or admin access)
- [ ] LLM API key already in `~/openclaw/.env` and working

If those aren't true, you're not onboarding — you're provisioning. Go back to Phase 1-6 of SKILL.md.

---

## The 7 steps (timed: ~7 min total per agent once warmed up)

### Step 1 — Pick the role (60s)

**What:** Decide what this agent does in one sentence.

**How:**
- If the role matches a starter (RFI / Submittal / Comms), use the file from `assets/SOUL-*.md`.
- If not, use `assets/SOUL.md.template` and fill in the role, responsibilities, boundaries, voice, and escalation rules.
- If you can't articulate the role in one sentence, you don't have enough spec — go back to the user and clarify.

**Output:** A SOUL.md draft on your laptop, ready to push to the VPS.

**COO callback:** This is Specification Engineering. The role is the spec. If the spec is fuzzy, the agent's behavior will be too.

### Step 2 — Edit SOUL.md live (60s)

**What:** Add 1-2 user-specific lines to make the agent feel real to the user.

**Where to edit:**
- `# Constraints` — what the agent must NEVER do in this user's context (e.g. "never contact contractor X without principal review")
- `# Examples` — one example tuned to the user's domain (use real terminology from their world)

**Why live:** Watching the SOUL.md get tweaked in real time makes the abstraction concrete. The user sees that the agent's identity is editable text, not magic.

### Step 3 — Append agent entry to openclaw.json (90s)

**What:** Add a new agent block under `"agents":` in `~/.openclaw/openclaw.json` on the VPS.

**Source snippet:** `assets/agent-entry.json` — copy and replace 4 placeholders:

```json
"<AGENT_NAME>": {
  "model": { "primary": "anthropic/claude-sonnet-4.7" },
  "heartbeat": { "every": "<HEARTBEAT_MIN>m" },
  "skills": [],
  "mcp_servers": [],
  "channels": {
    "discord": {
      "bot_token_env": "<DISCORD_TOKEN_VAR>",
      "default_channel_id": "<CHANNEL_ID>"
    }
  }
}
```

Replace:
- `<AGENT_NAME>` → slug like `submittal_reviewer`
- `<HEARTBEAT_MIN>` → e.g. `60`
- `<DISCORD_TOKEN_VAR>` → e.g. `DISCORD_BOT_TOKEN_AGENT_2`
- `<CHANNEL_ID>` → the Discord channel's numeric ID

**Critical:** Watch the trailing commas. JSON breaks if you append a block without a comma after the previous one, or with a trailing comma after the last one.

**How to push the edit:**
```bash
# Edit locally first
ssh openclaw-vps 'cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.$(date +%s)'
scp ~/local/openclaw.json openclaw-vps:~/.openclaw/openclaw.json
# OR edit in place via SSH:
ssh openclaw-vps 'nano ~/.openclaw/openclaw.json'
```

### Step 4 — Add env vars + Discord channel (90s)

**What:** Two parallel actions:

**4a. Add new bot token to `.env`:**
```bash
ssh openclaw-vps 'echo "DISCORD_BOT_TOKEN_AGENT_2=<the-new-token>" >> ~/openclaw/.env && \
  chmod 600 ~/openclaw/.env'
```

**4b. In Discord:**
1. Create the new channel: `#<role>-agent`
2. Right-click the channel → Edit Channel → Permissions → grant the new bot user View Channel + Send Messages
3. Make sure the bot is also a member of the channel (it should be, after the OAuth invite)

**Common slowdown:** This is the step with the most clicking around in Discord. Consider pre-creating channels before the workshop if you know the agent names in advance.

### Step 5 — Sync skills (30s)

**What:** Push any new canonical skills to the agent workspace.

```bash
ssh openclaw-vps 'bash ~/openclaw/sync_skills.sh'
```

For agent 2-3 you usually have nothing new to sync. Run it anyway — it's idempotent and confirms the script works.

### Step 6 — Restart gateway (30s active, ~30s wait)

**What:** Reload `openclaw.json` so the new agent block takes effect.

```bash
ssh openclaw-vps 'cd ~/openclaw && docker compose restart openclaw-gateway'
```

Wait ~30s for healthy. Verify:
```bash
ssh openclaw-vps 'docker ps --format "{{.Names}} {{.Status}}"'
```
Should show `Up X seconds (healthy)`.

**Use the wait time to narrate.** This is good demo time — explain heartbeat scheduling, why agents wake on intervals not always-on, what "healthy" means.

### Step 7 — Trigger from Discord + verify (60s)

**What:** Confirm the new agent works.

In the new agent's Discord channel, post:
```
@<bot-name> hello, introduce yourself. What's your role?
```

Watch for response within 30-60s. If it responds in-character per its SOUL.md → ✅ done.

If silent:
1. Check `docker logs --tail 30 openclaw-openclaw-gateway-1 2>&1 | grep <bot-name>` — look for `logged in` and any errors
2. See `troubleshooting.md` § "Agent silent on first @mention"

---

## After agent is online: give it a real task

Don't stop at hello-world. Drop a real task in the channel:
- For RFI Triager: "Read this RFI text and classify it." (paste a real one)
- For Submittal Reviewer: "Compare this product cut sheet against spec section 09 51 13."
- For Comms Drafter: "Draft a client message about this delay."

Watching the agent do REAL work is what makes the demo land. Hello messages don't.

---

## Speed tips for repeated runs

The first agent takes ~10 min. The third takes ~5. Things that make it faster:

1. **Snippet manager** — keep `agent-entry.json` in Raycast/Alfred/Notes with placeholder hotkeys
2. **Pre-staged SOUL.md drafts** — generate the 3 you'll need before the workshop, save in `~/.openclaw/staging/` on your laptop
3. **Pre-created Discord channels + bots** — Phase A of the workshop pre-work covers this
4. **One terminal split-screen with Discord** — see cause and effect in the same window
5. **Pre-canned trigger messages** — copy-paste, don't type live

---

## When NOT to use this playbook

- **First agent on a fresh VPS** — that's Phase 1-6 of SKILL.md, not the onboarding playbook
- **Removing an agent** — different procedure (delete agent block, restart, archive workspace files)
- **Updating an existing agent's SOUL.md** — just edit the file, then `docker compose restart` (no openclaw.json change needed)
- **Adding skills to an existing agent** — drop skill in `~/.openclaw/canonical/skills/`, run `sync_skills.sh`, restart
