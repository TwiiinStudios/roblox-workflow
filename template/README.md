# __GAME_NAME__

A Roblox game **built by AI** with the roblox-workflow kit. The humans describe; Claude builds, tests
and opens pull requests; GitHub checks everything and publishes to the TEST game automatically.
Long-form handbook: `docs/` in the `roblox-workflow` repo. AI rules: [`CLAUDE.md`](CLAUDE.md).

## 🐸 The workflow: START → BUILD → SHIP → PLAY

| | You | Claude |
|---|---|---|
| **0. Discord** | Post what you're working on | |
| **1. START** | Open **Roblox Studio** (start screen is enough), then VS Code in this folder → Claude panel → **"Start"** | Gets the newest version, tells you what your teammate is working on, opens the game in Studio |
| | In Studio: **Plugins → Rojo → Connect** (your only click) | |
| **2. BUILD** | Say what you want: what the player sees and does, numbers, where | Builds it, tests it in Studio, shows you. Repeat until you like it |
| **3. SHIP** | **"Ship it"** | Checks, saves, merges → on the TEST game about 2 minutes later, Discord gets a message |
| **4. PLAY** | Play the TEST game together in the Roblox app | |

Stopping before it's finished? **"Pause"**: saved online, continue next time with "Start".
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
