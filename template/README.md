# __GAME_NAME__

A Roblox game **built by AI** with the roblox-workflow kit. The humans describe; Claude builds, tests
and opens pull requests; GitHub checks everything and publishes to the TEST game automatically.
Long-form handbook: `docs/` in the `roblox-workflow` repo. AI rules: [`CLAUDE.md`](CLAUDE.md).

## How to work on this game (all in VS Code)

1. Open VS Code in this folder and open the **Claude Code** panel.
2. Say **"Start a session"**. Claude updates the code, opens Roblox Studio and starts Rojo.
   Your only click: in Studio, **Plugins → Rojo → Connect**.
3. Say what you want, e.g. *"Add a pond in the middle of the map with lily pads. Test it in Studio."*
   Claude builds it and play-tests it in Studio by itself. Press **F5** in Studio to try it yourself.
4. Say **"Ship it"**, then **"Merge it"**. About a minute later it's on the TEST game.
   Claude gives you a line to paste in Discord so your teammate knows.

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
