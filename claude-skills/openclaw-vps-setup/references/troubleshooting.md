# Troubleshooting — OpenClaw VPS Setup

Common failures during initial setup and onboarding, with confirmed fixes.

---

## SSH

### `ssh openclaw-vps` → "Permission denied (publickey)"

**Cause:** Wrong key file or key not added to Hetzner.
**Fix:**
1. Verify the key Hetzner has matches `~/.ssh/id_ed25519_openclaw.pub`. Re-paste if needed.
2. Confirm `~/.ssh/config` `IdentityFile` line points at the right private key (no `.pub` suffix).
3. Verify permissions: `chmod 600 ~/.ssh/id_ed25519_openclaw`.

### `ssh openclaw-vps` → connection times out

**Cause:** Wrong IP, server not booted yet, or firewall blocking SSH.
**Fix:**
1. Check Hetzner console — is the server status "Running"?
2. Hetzner Cloud Firewall — the default policy allows SSH (port 22) inbound from anywhere. If you customized it, verify port 22 is open.
3. Verify IP: `ssh -v openclaw-vps 2>&1 | head -5` shows the IP it's trying.

---

## Docker

### `docker --version` → "command not found" after install script

**Cause:** Docker installed but shell hasn't reloaded group membership.
**Fix:** Disconnect SSH and reconnect. The `usermod -aG docker deploy` only takes effect on new sessions.

### `docker compose up` → "permission denied while trying to connect to the Docker daemon socket"

**Cause:** User not in docker group (or new session needed).
**Fix:** Same as above — reconnect SSH.

### `docker pull ghcr.io/openclaw/openclaw:2026.4.23` → "manifest unknown"

**Cause:** Tag mistyped or upstream removed it.
**Fix:**
1. Visit https://github.com/openclaw/openclaw/pkgs/container/openclaw and find a current tag.
2. Pin to a tag known to boot cleanly. Avoid `:2026.4.24` (known hang issue).

---

## Gateway boot

### Container starts but stays "unhealthy"

**Cause:** Plugin runtime install slow on first boot, or schema migration in progress.
**Fix:**
1. Wait 4 full minutes. First boot installs ~6 plugin packages (~60s) AND may rewrite `openclaw.json` to current schema (~30s).
2. Check logs: `docker logs --tail 80 openclaw-openclaw-gateway-1` — look for `gateway ready` or specific errors.
3. If `openclaw.json` was rewritten, verify your `<PLACEHOLDERS>` weren't kept — they need real values.

### Container exits immediately

**Cause:** Invalid `openclaw.json` (most common: malformed JSON, unknown config keys).
**Fix:**
1. Validate JSON: `ssh openclaw-vps 'python3 -c "import json; json.load(open(\"/home/deploy/.openclaw/openclaw.json\"))"'` — should be silent on success.
2. Check logs for specific error: `docker logs openclaw-openclaw-gateway-1 2>&1 | grep -i 'config\|invalid\|unknown'`.
3. Common gotchas:
   - `model` must be an object: `{"primary": "..."}` — NOT a string.
   - Don't use `providersMode` — not a valid key.
   - `gateway.bind` must be `"loopback"` (string, quoted).
   - Trailing commas in JSON break parsing.

### "starting channels and sidecars… " hangs forever

**Cause:** You're on `ghcr.io/openclaw/openclaw:2026.4.24` (known upstream hang).
**Fix:** Roll back to `:2026.4.23`:
```bash
sed -i 's|2026.4.24|2026.4.23|' ~/openclaw/.env
cd ~/openclaw && docker compose up -d --force-recreate openclaw-gateway
```
Schema migration is forward-only. If 4.24 already rewrote your config, restore from your `openclaw.json.bak.*` snapshot before swapping image.

---

## Discord

### Bot doesn't appear in your Discord server after invite

**Cause:** OAuth scope wrong, or you didn't complete the invite redirect.
**Fix:**
1. Re-generate invite URL: Discord Developer Portal → OAuth2 → URL Generator → scopes `bot`, permissions `Send Messages` + `Read Message History` + `View Channels`.
2. Open the URL in a browser, select your server, click Authorize.

### Bot appears in server but doesn't see messages

**Cause:** Message Content Intent not enabled.
**Fix:** Discord Developer Portal → Bot tab → toggle on "Message Content Intent". Save.

### Agent silent on first `@mention`

**Diagnosis order:**
1. **Is the bot showing as online in Discord?** No → bot token wrong or gateway not running. Check `docker ps`.
2. **Is the bot in the right channel?** Check channel member list.
3. **Are channel permissions correct?** Right-click channel → Edit Channel → Permissions → bot must have View Channel + Send Messages.
4. **Is YOUR user ID in the bot's `allowFrom`?** This is the most common silent-failure cause once allowlist is enabled. Check `openclaw.json` → the agent's `channels.discord.allowFrom` must include `discord:<your-user-id>`. If you're testing with a different account than the one in the allowlist, the bot will silently ignore you.
5. **Logs:** `docker logs --tail 100 openclaw-openclaw-gateway-1 2>&1 | grep -i discord` — look for `connected` lines for your bot name, and any `not in allowlist` / `sender rejected` warnings.
6. **Channel ID match:** The numeric ID in `openclaw.json` `default_channel_id` must EXACTLY match the channel you're posting in. Easy to mix up if you have multiple channels.
7. **Heartbeat hasn't fired yet:** With `every: 60m`, the agent might not wake until the next interval. For testing, lower to `every: 2m` temporarily.

### Agent online + responds to me, but ignores other agents' handoffs

**Cause:** The OTHER agent bot's user ID isn't in this agent's `allowFrom`. With `groupPolicy: "allowlist"`, OpenClaw silently rejects messages from any sender not on the list — including other agent bots.

**Fix:**
1. Get the sending agent's bot user ID: in Discord, right-click that bot in the member list → **Copy User ID**.
2. Edit `~/.openclaw/openclaw.json`: under the RECEIVING agent's `channels.discord.allowFrom`, add `"discord:<sender-bot-id>"`.
3. Restart the gateway: `docker compose restart openclaw-gateway`.

**Prevention:** Every time you onboard a new agent, update every OTHER agent's `allowFrom` with the new bot's user ID. This is Step 5 of the 7-step onboarding playbook.

### How do I find a Discord user ID?

1. Discord client → **User Settings** (gear icon, bottom left) → **Advanced** → toggle on **Developer Mode**.
2. Right-click any user (yourself, a teammate, a bot) anywhere their name appears (server member list, channel members, message author) → **Copy User ID**.
3. It's a long numeric string (e.g. `1234567890123456789`). In `openclaw.json`, prefix with `discord:` — e.g. `"discord:1234567890123456789"`.

### Bot says "logged in to discord" in logs but doesn't respond

Per the upstream OpenClaw 4.x snapshot bug, the log line `discord client initialized; awaiting gateway readiness` is captured ONCE at bot init and never updated. The bot may actually be fully connected. Verify with:
```bash
ssh openclaw-vps 'docker exec openclaw-openclaw-gateway-1 openclaw channels status --deep'
```
If the deep status shows `connected`, the log line is stale and the bot is fine — debug elsewhere (channel permissions, heartbeat timing).

---

## openclaw.json edits

### Edited `openclaw.json`, agent didn't pick up changes

**Cause:** Gateway loads config on boot. Edits require a restart.
**Fix:** `ssh openclaw-vps 'cd ~/openclaw && docker compose restart openclaw-gateway'`. Wait for healthy.

### Added a new agent, but it's not in the gateway logs

**Cause:** Either the agent block has a JSON syntax error, OR the gateway didn't restart cleanly.
**Fix:**
1. Validate JSON (see earlier).
2. Check restart status: `docker ps --format "{{.Names}} {{.Status}}"` — should be `Up X seconds (healthy)`.
3. Check the gateway log for the agent's name: `docker logs --tail 100 openclaw-openclaw-gateway-1 2>&1 | grep <agent_name>`.

---

## .env / secrets

### Gateway logs show "auth failed" or LLM errors

**Cause:** API key missing or wrong.
**Fix:**
1. Check `~/openclaw/.env` has the right env var name matching `openclaw.json` `env` block.
2. Verify the actual key is valid — try a curl test from your laptop with the same key.
3. Restart gateway after any `.env` change (env is read at container startup).

### `.env` permissions warning

**Cause:** File is world-readable.
**Fix:** `ssh openclaw-vps 'chmod 600 ~/openclaw/.env'`.

---

## Disk / quota

### `df -h` shows root partition >85% full

**Cause:** Old Docker images and logs accumulating.
**Fix:**
```bash
ssh openclaw-vps 'docker system df'  # see what's using space
ssh openclaw-vps 'docker image prune -a -f'  # remove unused images
ssh openclaw-vps 'docker logs openclaw-openclaw-gateway-1 --tail 0'  # truncate via re-attach (or use logrotate)
```
For long-term: configure `--log-opt max-size=10m --log-opt max-file=3` in docker-compose.yml.

---

## When to escalate (back to Matty / Claude Code)

If after 15 min of debugging you can't get past:
- Gateway won't go healthy after image swap
- Agents authenticate to Discord but never respond, even with `every: 2m`
- `openclaw.json` edits don't take effect after restart

…stop and bring the symptoms back to Claude Code with the relevant log lines. The `molty` skill has deeper diagnostic patterns for an already-deployed instance.
