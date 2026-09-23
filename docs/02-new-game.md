# 02 · Starting a new game

Just tell Claude (started in your `Roblox` folder):

> "New game: **GrowAFrog**. Create it from the template with a GitHub repo in TwiiinStudios."

Claude runs `roblox-workflow/scripts/new-game.ps1 -Name GrowAFrog -GitHub -GitHubOwner TwiiinStudios`, which:
copies the template → fills in the name → installs tools → runs all checks → first commit → private GitHub repo → push.

Then there are **4 things only a human can do** (Roblox and GitHub account actions). About 10 minutes:

## 1. Create two experiences (3 min)

| Experience | Purpose |
|---|---|
| `GrowAFrog [TEST]` | Every merged change lands here automatically. Play-test with friends. |
| `GrowAFrog` | LIVE: the real game. Only updated when you press the release button. |

They're separate experiences so **TEST can never touch LIVE player data** (DataStores are per experience).

In Studio: **File → New → Baseplate** → **File → Publish to Roblox As → New experience → Creator: your group**
→ name `GrowAFrog [TEST]`. Repeat for `GrowAFrog`. Then, for both: **Game Settings → Security →
Enable Studio Access to API Services** → Save. Keep both **private** until release.

## 2. Give Claude the IDs (1 min)

For each experience, copy from Creator Hub (**Creations → ⋯ on the experience**):
**Copy Universe ID** and the **Start Place ID** (also visible in the game's URL: `roblox.com/games/<PLACE ID>`).
Paste them to Claude:

> "TEST universe 7123456789 place 123456789012, LIVE universe 7123450000 place 123450000000. Put them in deploy.json and ship it."

## 3. Create the publishing key (4 min)

1. https://create.roblox.com → owner dropdown (top left) → **your group** → **Open Cloud → API Keys → Create API Key**.
2. Name `GrowAFrog deploy`. Under **Access Permissions** add **`universe-places`**, add both experiences, operation **Write**.
3. **Accepted IP addresses**: `0.0.0.0/0`. Save, then **copy the key** (shown once).
4. Store it in GitHub **yourself**. Never paste keys into a chat, including to Claude:
   ```powershell
   gh secret set ROBLOX_API_KEY --repo TwiiinStudios/GrowAFrog
   ```
   (paste the key, Enter). Optional for publishing from your PC: create a `.env` file with `ROBLOX_API_KEY=<key>`.

## 4. Claude on GitHub (1 min)

In Claude Code inside the game folder: `/install-github-app` (stores `CLAUDE_CODE_OAUTH_TOKEN` in this repo).
Needed per repo on the free GitHub plan.

## Check it works

Ask Claude: *"Trigger a TEST deploy and tell me when it's green."* Then open `GrowAFrog [TEST]` on Roblox and press Play.

## Checklist
- [ ] Repo on GitHub, both of you have access
- [ ] TEST + LIVE experiences exist, API access on, private
- [ ] `deploy.json` filled (by Claude)
- [ ] `ROBLOX_API_KEY` secret set (by you)
- [ ] Claude GitHub app / `CLAUDE_CODE_OAUTH_TOKEN` available to the repo
- [ ] First Deploy run green, TEST playable

Next: [04 · Daily workflow](04-daily-workflow.md).
