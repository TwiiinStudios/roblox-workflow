# __GAME_NAME__

A Roblox game **built by AI** with the roblox-workflow kit. The humans describe; Claude builds, tests
and opens pull requests; GitHub checks everything and publishes to the TEST game automatically.
Long-form handbook: `docs/` in the `roblox-workflow` repo. AI rules: [`CLAUDE.md`](CLAUDE.md).

## 🐸 The workflow: BUILD → SHIP → PLAY

| | You |
|---|---|
| **Before** | Open **Roblox Studio** (start screen is enough) → **VS Code** in the game folder → Claude panel. Post in Discord what you're doing |
| **BUILD** | Say what you want. Claude gets everything ready by itself and opens the game in Studio. When it shows up: **Plugins → Rojo → Connect**. Claude builds and tests it; give feedback until you like it |
| **SHIP** | **"Ship it"**, or put "…and ship it" in your request → on the TEST game ~2 min later, Discord gets a message |
| **PLAY** | Play the TEST game together in the Roblox app |

Your work is saved online automatically. When you're done, just close VS Code.
Sometimes: **"Share it"** (teammate looks first) · **"What changed?"** · **"Release to LIVE as v1.0.0"** (only when you both agreed).

First time on this PC? Tell Claude in the `Roblox` folder: *"Set up my PC."*

## Commands (Claude runs these for you)

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
