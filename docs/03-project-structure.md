# 03 · Project structure

**Rule #1: the game is only what's in the files.** Nobody builds in Studio by hand. Studio is where the AI
*tests* and, rarely, *generates* things that are then saved back into files.

```
GrowAFrog/
├── src/
│   ├── server/                      → ServerScriptService.Server
│   │   ├── Main.server.luau         loads every Service
│   │   ├── Services/                one file per system (FrogService, DataService, WorldService, ...)
│   │   └── World/                   world builders, run at server start → Workspace.Generated
│   ├── client/                      → StarterPlayer.StarterPlayerScripts.Client
│   │   ├── Main.client.luau         loads every Controller
│   │   └── Controllers/             one file per client system, incl. all UI
│   └── shared/                      → ReplicatedStorage.Shared
│       ├── Config.luau              every tweakable number + asset IDs
│       ├── Remotes.luau             every RemoteEvent/Function
│       ├── Create.luau              helper to build instances in code
│       └── Format.luau              pure helpers (unit tested)
├── world/
│   ├── Map/                         → Workspace.Map (static pieces as .model.json)
│   │   └── Captured/                → things generated in Studio (.rbxm, written by capture tool)
│   └── Lighting/                    → Lighting (init.meta.json + Sky/Atmosphere .model.json)
├── assets/                          → ReplicatedStorage.Assets (.model.json)
│   └── Captured/                    → Studio-generated models (.rbxm)
├── tests/                           unit tests (*.spec.luau)
├── tools/                           build, check, test, capture, publish, lint-world
├── default.project.json             Rojo: which folder becomes what
├── capture.project.json             Rojo syncback: only the Captured folders
├── deploy.json                      TEST/LIVE IDs
├── CLAUDE.md                        the AI's operating manual for this game
└── .github/workflows/               CI, Deploy, Claude (@claude), Claude Review
```

## How each kind of thing gets built

| Want | The AI builds it as | Example file |
|---|---|---|
| A game system | Service (server) + Controller (client) | `src/server/Services/FrogService.luau` |
| UI (shop, HUD, menus) | Code in a Controller using `Create` | `src/client/Controllers/ShopController.luau` |
| Map layout, paths, trees, terrain | World builder, runs at server start | `src/server/World/Pond.luau` |
| Fixed pieces (baseplate, spawn) | `.model.json` | `world/Map/SpawnLocation.model.json` |
| Lighting / sky / fog | `init.meta.json` + `.model.json` | `world/Lighting/init.meta.json` |
| A frog model from parts | Code function or `.model.json` | `assets/Frog.model.json` |
| An AI-generated 3D mesh or texture | Studio MCP → `Captured` → `capture.luau` | `assets/Captured/FrogMesh.rbxm` |
| Creator Store model | Studio MCP `insert_asset` → `Captured` | `world/Map/Captured/Fountain.rbxm` |
| Balancing numbers | `Config.luau` | `GROWTH_PER_FLY = 5` |

Text files (`.luau`, `.json`) are preferred: they're readable, reviewable, and merge cleanly when two people
change them at once. `.rbxm` (binary) is used only when something can't be made from text.

## Example: a world builder

```lua
-- src/server/World/Pond.luau
local Create = require(game:GetService("ReplicatedStorage").Shared.Create)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

return function(parent: Folder)
	workspace.Terrain:FillCylinder(CFrame.new(0, -1, 0), 2, Config.POND_RADIUS, Enum.Material.Water)

	for i = 1, Config.LILY_PAD_COUNT do
		local angle = (i / Config.LILY_PAD_COUNT) * math.pi * 2
		Create("Part", {
			Name = `LilyPad{i}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 6, 6),
			CFrame = CFrame.new(math.cos(angle) * 15, 0.3, math.sin(angle) * 15) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(80, 160, 70),
			Anchored = true,
			Parent = parent,
		})
	end
end
```

## Example: a static piece (`.model.json`)

```json
{
	"className": "Part",
	"properties": {
		"Anchored": true,
		"Size": [20, 1, 20],
		"CFrame": { "CFrame": { "position": [40, 0.5, 0], "orientation": [[1, 0, 0], [0, 1, 0], [0, 0, 1]] } },
		"Material": "WoodPlanks",
		"Color": [0.55, 0.4, 0.25]
	}
}
```

> ⚠️ Rojo **silently ignores** `"Position"` in `.model.json` (the part lands at 0,0,0). Always use the `CFrame`
> form above. `tools/lint-world.luau` (part of `check`) fails if you forget.

## The Captured folders (things made inside Studio)

Some things can only be created inside Studio: AI-generated meshes and materials (Studio MCP `generate_mesh`,
`generate_material`), Creator Store assets (`insert_asset`), uploaded images. For those:

1. Claude generates or inserts it in Studio and moves it into **`Workspace.Map.Captured`** (placed in the world) or
   **`ReplicatedStorage.Assets.Captured`** (spawned by code).
2. Claude asks you to press **Ctrl+S** in Studio (the one tiny manual step).
3. Claude runs `lune run tools/capture.luau`: only those two folders are written to `.rbxm` files.
4. Commit. From now on it's part of every build.

`capture.luau` never touches anything else, so hand-written files are safe. Nothing in `Captured/` is edited by hand.

## Services, Controllers, Remotes, Config

- **Service** = server module with `Init(services)` (setup, grab other services) and `Start()` (connect events, loops).
- **Controller** = the same on the client.
- **Remotes**: add a name to `EVENTS` in `Remotes.luau`, then `Remotes.FeedFrog:FireServer(id)` on the client and
  `Remotes.FeedFrog.OnServerEvent:Connect(function(player, id) ... end)` on the server, which **validates `id`**.
- **Config**: every number anyone might tune (prices, speeds, rarities) and every asset ID.

## Packages (Wally)

Claude adds libraries to `wally.toml` (e.g. ProfileStore for saving data), runs `wally install`, and commits
`wally.toml` + `wally.lock`. They appear in `ReplicatedStorage.Packages` / `ServerStorage.ServerPackages`.
After pulling, run `wally install` (Claude does it for you in its sessions).
