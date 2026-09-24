# 02 · Starting a new game

Takes about **20 minutes**, once per game. Example game: **GrowAFrog**.
Claude does everything it can; the steps marked 🧑 are Roblox/GitHub account actions only a human can do.

| # | Step | Who | Time |
|---|---|---|---|
| 1 | Create the repo from the template | Claude | 1 min |
| 2 | Create the TEST and LIVE experiences | 🧑 | 5 min |
| 3 | Experience settings | 🧑 | 5 min |
| 4 | Copy the IDs → give them to Claude | 🧑 → Claude | 2 min |
| 5 | Create the publishing API key and store it | 🧑 | 4 min |
| 6 | Turn on Claude for GitHub (optional) | 🧑 | 1 min |
| 6b | Discord messages when TEST/LIVE update (optional, recommended) | 🧑 | 2 min |
| 7 | First deploy + check | Claude, then 🧑 plays | 2 min |

---

## 1. Create the repo (Claude)

In Claude Code, started in your `Roblox` folder:

> "New game: **GrowAFrog**. Create it from the template with a GitHub repo in TwiiinStudios."

Claude runs `roblox-workflow/scripts/new-game.ps1 -Name GrowAFrog -GitHub -GitHubOwner TwiiinStudios`:
copy template → fill in the name → install tools → run all checks → first commit → private repo `TwiiinStudios/GrowAFrog` → push.

## 2. 🧑 Create two experiences

| Experience | Updated | Who plays | Saved data |
|---|---|---|---|
| `GrowAFrog [TEST]` | Automatically, ~1 min after every merge to `main` | You two (+ invited testers) | Test data, fine to wipe |
| `GrowAFrog` (LIVE) | Only when you both decide to release | Real players | Real progress, never touch |

They must be two separate **experiences** (not two places in one experience), because **DataStores belong
to an experience**. A bug on TEST can then never damage LIVE players' saves.

Do this **twice** (first `GrowAFrog [TEST]`, then `GrowAFrog`):

1. Roblox Studio → **New** → **Baseplate**.
2. **File → Publish to Roblox As…** → **Create new experience**.
3. **Creator: the community (group)**, not your own account. ⚠️ This is the most important choice. Moving it later is painful.
4. Name it → **Create**.
5. Close the place **without saving it to your PC**. Its contents don't matter: the Deploy action replaces them with the real game.

## 3. 🧑 Experience settings

In Studio: **File → Open from Roblox** → the experience → **Home → Game Settings**:

| Setting | TEST | LIVE | Why |
|---|---|---|---|
| Security → **Enable Studio Access to API Services** | ✅ On | ✅ On | DataStores (saving) work in Studio tests |
| Permissions → **Playability** | **Private** | **Private** until launch | Nobody stumbles on unfinished games |
| **Avatar** (R15/R6, scaling, animations), **max players/server size** | Same as LIVE | Your choice | These aren't part of the game files, so Git can't keep them in sync. Keep both identical by hand. |
| Name, icon, thumbnails, description, genre | Anything | Make them nice at launch | Only matters for LIVE |

Before LIVE goes **public**, Roblox requires the **Content Maturity questionnaire**
(Creator Hub → experience → Audience / Maturity). Do that at launch time, see [07 · Publishing](07-publishing.md).

If your teammate can't join the private TEST game: check the experience's Permissions and the group role's permissions.
Their role must have access to the group's experiences.

## 4. 🧑 → Claude: the IDs

For each experience: [create.roblox.com](https://create.roblox.com) → top-left dropdown: **the community** →
**Creations** → hover the experience → **⋯** →
- **Copy Universe ID**
- **Copy Start Place ID** (also the number in the game's URL: `roblox.com/games/<PLACE ID>/…`)

Paste all four to Claude (IDs are not secret):

> "TEST: universe 10767840551, place 125769981061146. LIVE: universe 10767840620, place 107254394835793."

Claude puts them in `deploy.json`, `LIVE_UNIVERSE_ID` in `src/shared/Config.luau` (so code knows when it runs on LIVE),
and the README's experiences table, then opens a PR.

## 5. 🧑 Publishing API key

1. [create.roblox.com](https://create.roblox.com) → top-left dropdown: **the community** → **Open Cloud → API Keys → Create API Key**.
2. **Name:** `GrowAFrog deploy` (one key per game, so you can revoke one without breaking the others).
3. **Access Permissions** → select API system **`universe-places`** → add **both** experiences → operation **Write**.
4. **Security → Accepted IP addresses:** `0.0.0.0/0` (GitHub's servers use changing IPs).
5. **Expiration:** none or long. **Save & Generate Key** → **copy the key** (shown only once).
6. Store it in the repo **yourself**. ⚠️ Never paste a key into a chat, including to Claude. In the Claude Code prompt type:
   ```
   ! gh secret set ROBLOX_API_KEY --repo TwiiinStudios/GrowAFrog
   ```
   paste the key, press Enter. (The `!` runs it as a normal terminal command; the key doesn't go to Claude.)
7. Optional, only if you want to publish from your own PC: create a file `.env` in the game folder containing
   `ROBLOX_API_KEY=<key>` (it's git-ignored).

Keep the key somewhere safe (e.g. a password manager) or just generate a new one if you ever need it again.

## 6. 🧑 Claude on GitHub

In Claude Code, inside the game folder: `/install-github-app` → choose **TwiiinStudios** → **All repositories** →
it stores `CLAUDE_CODE_OAUTH_TOKEN` in this repo. Needed **per repo** on the free GitHub plan (org-level secrets don't
reach private repos). Optional: enables the automatic PR review and `@claude` in PR comments. Everything else works without it.

## 6b. 🧑 Discord messages (optional, recommended)

The Deploy action posts to your Discord channel whenever TEST or LIVE is updated (and when publishing fails):
> 🧪 **GrowAFrog TEST updated** (version 12): Add fly shop next to spawn - by rA9-001

1. Discord: channel settings (⚙️ next to the channel) → **Integrations** → **Webhooks** → **New Webhook** → name it
   after the game → **Copy Webhook URL**. One webhook can be reused for all games.
2. Store it (don't paste it into the chat; anyone with the link can post in your channel). In the Claude prompt:
   ```
   ! gh secret set DISCORD_WEBHOOK_URL --repo TwiiinStudios/GrowAFrog
   ```
   Paste the URL, Enter. Without it, the step is simply skipped.

## 7. First deploy and check

> "Merge the IDs PR and check that TEST gets published."

Claude merges → the **Deploy** action publishes to TEST → Claude confirms the new version number.
🧑 Open `GrowAFrog [TEST]` on Roblox → **Play**. You should spawn on a grass baseplate: the whole pipeline works.

## Checklist

- [ ] Repo `TwiiinStudios/<Game>` exists, teammate has access (org base permission: Write)
- [ ] TEST + LIVE experiences created **under the community**
- [ ] API access on, both private, avatar/server settings identical
- [ ] IDs in `deploy.json`, `Config.luau`, README (Claude)
- [ ] `ROBLOX_API_KEY` secret set (you)
- [ ] `/install-github-app` done for the repo (you)
- [ ] Deploy green, TEST playable

Next: [04 · Daily workflow](04-daily-workflow.md).
