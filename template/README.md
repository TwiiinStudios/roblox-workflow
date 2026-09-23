# __GAME_NAME__

A Roblox game **built by AI** with the roblox-workflow kit. The humans describe; Claude builds, tests
and opens pull requests; GitHub checks everything and publishes to the TEST game automatically.
Long-form handbook: `docs/` in the `roblox-workflow` repo. AI rules: [`CLAUDE.md`](CLAUDE.md).

## How to get something built

**On your PC** (Claude Code in this folder, Studio open for AI playtesting):
> "Add a pond in the middle of the map with lily pads the frogs can sit on. Test it in Studio, then ship it."

**From anywhere** (phone, browser): open a GitHub issue:
> "@claude add a daily reward: 50 coins, streak doubles it up to 7 days"

Claude builds it on a branch and opens a PR. CI checks it, and Claude reviews it automatically.
You (or Claude, when you say so) merge it, and it's live on TEST about a minute later.

## First time on this project

```powershell
gh repo clone <owner>/__GAME_NAME__
cd __GAME_NAME__
rokit install
wally install
lune run tools/check.luau        # should end with "All good"
```

## Starting a session with in-Studio testing

```powershell
lune run tools/build.luau
rojo serve
```
Studio: **File → Open from File → `build/game.rbxl`** → **Plugins → Rojo → Connect**. Then start Claude Code in this folder.
Claude can now see the game, play-test it, take screenshots and read the console through the Studio MCP connection.

## Commands

| Command | What it does |
|---|---|
| `lune run tools/check.luau --fix` | Format + lint + world lint + tests + build (the same as CI) |
| `lune run tools/build.luau` | Builds `build/game.rbxl` from the files |
| `rojo serve` | Live-syncs files into Studio |
| `lune run tools/capture.luau` | Saves Studio-made things (in `Captured` folders) back into files |
| `lune run tools/publish.luau test` | Publishes to TEST from your PC (needs `.env`) |

## Where things live

| Folder | In Roblox |
|---|---|
| `src/server/` | `ServerScriptService.Server` (Services + World builders) |
| `src/client/` | `StarterPlayerScripts.Client` (Controllers, incl. UI) |
| `src/shared/` | `ReplicatedStorage.Shared` (Config, Remotes, helpers) |
| `world/Map/` | `Workspace.Map` (static map pieces) |
| `world/Lighting/` | `Lighting` |
| `assets/` | `ReplicatedStorage.Assets` |
| `*/Captured/` | Things made in Studio, saved by `tools/capture.luau` |

## Experiences

| | Universe ID | Place ID |
|---|---|---|
| TEST | see `deploy.json` | see `deploy.json` |
| LIVE | see `deploy.json` | see `deploy.json` |
