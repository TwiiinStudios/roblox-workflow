# __GAME_NAME__: AI operating manual

This game is **built entirely by AI**. The humans (two friends) describe what they want; you design,
build, test and deliver it as pull requests. Keep human work to a minimum. When a human step is
truly unavoidable, ask for **one concrete action** (e.g. "press Ctrl+S in Studio"), never a vague task.

This file is self-contained: it's all you have when running in GitHub Actions. On a local PC,
`../roblox-workflow/` may also exist with the long-form handbook in `docs/`.

## 1. Source of truth = files in this repo

Nothing is built by hand in Studio. The game is **only** what these files say:

| What | Where | Becomes |
|---|---|---|
| Server code | `src/server/` (`Services/`, `World/`) | `ServerScriptService.Server` |
| Client code, including all UI | `src/client/` (`Controllers/`) | `StarterPlayerScripts.Client` |
| Shared code, config, remotes | `src/shared/` | `ReplicatedStorage.Shared` |
| Static map pieces | `world/Map/*.model.json` | `Workspace.Map` |
| Lighting, sky, atmosphere | `world/Lighting/init.meta.json` + `*.model.json` | `Lighting` |
| Models/props (text) | `assets/*.model.json` | `ReplicatedStorage.Assets` |
| Things made in Studio | `world/Map/Captured/`, `assets/Captured/` (`.rbxm`, written only by `tools/capture.luau`) | `Workspace.Map.Captured`, `ReplicatedStorage.Assets.Captured` |
| Unit tests | `tests/*.spec.luau` | nothing (run by Lune) |

Anything created in Studio outside the two `Captured` folders **is lost** on the next build.

## 2. How to build each kind of thing (in order of preference)

1. **Gameplay**: a Service in `src/server/Services/<Name>Service.luau` (`Init(services)` then `Start()`)
   and/or a Controller in `src/client/Controllers/<Name>Controller.luau`. The Main scripts auto-load them.
2. **Generated world** (layouts, paths, trees, fences, terrain, anything repeated or procedural):
   a builder in `src/server/World/<Name>.luau` returning `function(parent: Folder)`. `WorldService` runs
   all builders at server start into `Workspace.Generated`. Use `Shared.Create` to make instances.
   Terrain: `workspace.Terrain:FillBlock/FillBall/FillRegion` inside a builder.
3. **Static map pieces** that should be visible in Studio edit mode: `world/Map/<Name>.model.json`.
   ⚠️ Rojo **silently ignores** `Position`/`Orientation`. Always use the explicit form:
   `"CFrame": { "CFrame": { "position": [x, y, z], "orientation": [[1,0,0],[0,1,0],[0,0,1]] } }`
   Colors: `"Color": [r, g, b]` with 0-1 floats. Enums by name: `"Material": "Grass"`.
4. **Lighting**: `world/Lighting/init.meta.json` (`"className": "Lighting"` + properties); add `Sky`/`Atmosphere`/
   `ColorCorrectionEffect` as `world/Lighting/<Name>.model.json`.
5. **UI**: built in code by a client Controller with `Shared.Create`, parented to `player.PlayerGui`.
   Scale-based sizes (`UDim2.fromScale`), `UIAspectRatioConstraint`, `UIListLayout`/`UIPadding`, and big touch targets.
   It must work on phones.
6. **Models/props**: build from Parts in code (a function in a shared module) or as `assets/<Name>.model.json`.
7. **Only if impossible in files** (AI-generated meshes/textures, Creator Store assets, uploaded images/sounds):
   use the Roblox Studio MCP tools (`generate_mesh`, `generate_material`, `generate_procedural_model`, `search_asset`,
   `insert_asset`, `upload_image`), move the result into `Workspace.Map.Captured` or `ReplicatedStorage.Assets.Captured`,
   ask the human to press **Ctrl+S** in Studio, then run `lune run tools/capture.luau` and commit the new `.rbxm`.
   Never hand-edit anything in `Captured/`. Asset IDs used by code go in `src/shared/Config.luau`.

## 3. Routines the humans trigger by name

The humans work **only in VS Code** (Claude Code panel) and coordinate with each other on **Discord**, not GitHub Issues.
They may be beginners: explain in plain words, one step at a time, and never assume they know Git.

- **"Start a session"**: `git switch main` → `git pull` → `rokit install` → `wally install` →
  `lune run tools/build.luau` → start `rojo serve` in the background → open Studio with the game yourself
  (`Start-Process build/game.rbxl` in PowerShell; skip if Studio already shows it) → tell the human the one thing to do:
  *"In Studio, click the Plugins tab → Rojo → Connect."* → confirm through the Studio MCP (`list_roblox_studios`, then a
  quick `execute_luau` that `ServerScriptService.Server` exists) → say "Ready, what do you want to build?".
  If the Studio MCP tools are missing: (1) Studio must be open, (2) one-time switch in Studio: Assistant panel → ⋯ →
  Manage MCP Servers → **Enable Studio as MCP server**, (3) then close and reopen the Claude Code panel (MCP servers
  connect when Claude starts). Until then, continue without in-Studio tests and say so.
- **"Ship it"**: check passes → commit → push → `gh pr create` with what/why/verification → report the PR link and give
  a one-line message they can paste in Discord, e.g. `🐸 PR ready: fly shop next to spawn - <link>`.
- **"Merge it"**: wait for CI (`gh pr checks --watch`) → `gh pr merge --squash --delete-branch` → `git switch main; git pull`
  → wait for the Deploy run → give a Discord line: `✅ On TEST: fly shop next to spawn (pull main before your next change)`.
- **"What changed?"** (e.g. after the other person merged something): `git pull` and summarise the new commits on `main` in plain words.
- **"Release to LIVE as vX.Y.Z"** (only when said explicitly): `gh workflow run Deploy -f target=live` → watch it →
  tag `vX.Y.Z` on `main` → push the tag → `gh release create vX.Y.Z --generate-notes`.

## 4. Verify your work, every time

1. `lune run tools/check.luau --fix` (format, lint, world-file lint, unit tests, build) must end with "All good".
2. **In-Studio test** (local sessions with the Roblox Studio MCP tools available):
   - Have `rojo serve` running (start it in the background if it isn't), with Studio showing `build/game.rbxl`
     (open it yourself with `Start-Process build/game.rbxl`) and the Rojo plugin connected. If it isn't connected,
     ask the human once: *"In Studio, click Plugins → Rojo → Connect."*
   - `start_stop_play` → `get_console_output` (no errors or warnings from our scripts) → `screen_capture`
     (does it look right?) → `character_navigation` / `user_keyboard_input` / `user_mouse_input` to actually use the
     feature → stop play. Use `execute_luau` to inspect state (e.g. a player's coins) when needed.
   - Rebuild with `lune run tools/build.luau` only when Studio needs a fresh file. Rojo live-syncs code and world files.
3. In GitHub Actions (no Studio): rely on step 1, and write "In-Studio playtest: not done (CI)" in the PR.
4. Report honestly what you verified and how. Never claim a playtest you didn't run.

## 5. Git and delivery

- Branch from up-to-date `main`: `feature/…`, `fix/…`, `chore/…`. Small, focused commits with clear messages.
- Local sessions: commit, push and open or merge PRs only when the human asks (they may say "ship it" = commit, push, PR).
- PR description: what changed, how it was verified (check + which playtest steps), anything the human must do.
- Merge with `gh pr merge --squash --delete-branch` only after CI is green **and** a human asked you to merge.
- Merging to `main` auto-publishes to the TEST experience. **Never publish to LIVE** (`tools/publish.luau live`,
  `gh workflow run Deploy -f target=live`) unless a human explicitly asks for it in that message.
- Never touch `build/`, `Packages/`, `sourcemap.json`, `.env`. Never print or commit the Roblox API key.

## 6. Code rules

- `*.server.luau` = Script, `*.client.luau` = LocalScript, `.luau` = ModuleScript.
- All remotes are declared in `src/shared/Remotes.luau`. **The server validates every argument from clients**
  (type, range, ownership, cooldown). The server decides money, items, stats. Rate-limit spammable remotes.
- Tunable numbers and asset IDs live in `src/shared/Config.luau`.
- Pure logic (formulas, rolls, prices) goes in modules without Roblox APIs, with a `tests/<Name>.spec.luau`.
  Tests `require("../src/shared/<Name>")`, so tested modules must not `require(script...)`.
- `task.wait/spawn/delay`, never `wait/spawn/delay`. Disconnect connections you create per player on leave.
- Data: one `DataService` owns DataStores (prefer ProfileStore via Wally). Include a `version` in saved data.
  DataStores don't work in the local `build/game.rbxl`, so fall back to in-memory data when `game.GameId == 0`.
- Style: StyLua (tabs), selene clean, PascalCase modules, camelCase locals, UPPER_SNAKE constants, a short header
  comment per module.

## 7. Commands

| Command | Does |
|---|---|
| `lune run tools/check.luau --fix` | format + lint + world lint + tests + build (the same as CI) |
| `lune run tools/build.luau` | `build/game.rbxl` from the files |
| `rojo serve` | live-sync files into Studio |
| `lune run tools/test.luau` | unit tests |
| `lune run tools/capture.luau` | save Studio-made things from the `Captured` folders into files |
| `lune run tools/publish.luau test` | publish `build/game.rbxl` to TEST (needs `.env`) |
| `wally install` | install packages from `wally.toml` |
