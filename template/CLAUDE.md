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
| Game design decisions | `DESIGN.md` (read before building; update when the humans decide something) | nothing |

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

## 3. The human workflow: BUILD → SHIP → PLAY

The humans work **only in VS Code** (Claude Code panel) and coordinate on **Discord**, not GitHub Issues. They may be
beginners: plain words, no Git jargon without explaining it. Claude has full control.

**Save their prompts.** Every message they send should be about the game. Never make them type "start", "pause",
"merge", "done" or "I clicked it". Do setup, saving and checking by yourself, and put anything they need to do into the
same reply as your work. Accept loose wording ("ship", "ship it", "…and ship it", "put it on test").

- **Automatic session setup**: on the **first request of every conversation**, before working on it (skip what's already
  done; report it in one short line, not a checklist):
  1. `git fetch --prune`. If this human has unfinished work (their own open draft PR `WIP: …`), continue it when the
     request fits; if it clearly doesn't, ask in one line. Otherwise `git switch main` → `git pull`.
     Then `rokit install` → `wally install`.
  2. **Teammate check**: `gh pr list --state open --json number,title,author,isDraft,headRefName,files` plus new commits
     on `main` since this human's last one. One or two sentences: what the other person is doing, what they recently
     shipped. If the request overlaps their open work, say so before building.
  3. **Studio**: if the Studio MCP shows the game open and `rojo serve` is running, skip. Otherwise
     `lune run tools/build.luau` → start `rojo serve` in the background → `Start-Process build/game.rbxl` → in the same
     reply tell them: *"When the game shows up in Studio: Plugins → Rojo → Connect."* **Don't wait for an answer.**
     Keep working; section 4 checks the connection before testing.
  4. Only for a pure question ("what did we decide about…?", "what changed?") skip steps 1 and 3 and just answer.
  If the Studio MCP tools are missing: Studio must be open before the Claude panel starts (the start screen is enough);
  the one-time switch is Studio → Assistant panel → ⋯ → Manage MCP Servers → **Enable Studio as MCP server**
  ("Claude Code CLI" quick-connect stays off, "Visual Studio Code" doesn't matter); to reconnect: `/mcp` → Roblox_Studio →
  Reconnect. Until then, build and run the checks without in-Studio tests, and say so once.
- **BUILD** (they describe something): read `DESIGN.md` first. Work on `feature/<short-name>` from `main`, build it, verify it
  (section 4), report in plain words, and record new decisions (numbers, rules, style) in `DESIGN.md`.
  **Autosave**: after each working step, commit, push and keep a **draft PR** `WIP: <what>` open. That's the backup,
  and it's how the teammate sees it. Nobody ever needs to say "pause".
- **SHIP** ("ship it", or "…and ship it" in a request, which means ship as soon as it's verified): all the way to TEST:
  `lune run tools/check.luau --fix` → commit → `git fetch` + `git merge origin/main` (resolve conflicts; ask only about
  design choices; re-run the check) → push → mark the draft PR ready (or create it) with what/why/verification →
  `gh pr checks --watch` → `gh pr merge --squash --delete-branch` → `git switch main; git pull` → watch the Deploy run →
  "On TEST (version N)". Discord gets the Deploy bot's message if `DISCORD_WEBHOOK_URL` is set; otherwise add a line they
  can paste: `✅ On TEST: <what>`.
- **SHARE** ("share it"): like SHIP but stop after the PR is ready for review. Give a Discord line with the link.
- **BOARD** ("do *Example 1* from To do", "fix the top bug in Fixes", "what's on the board?"): the team's task board
  (https://tasks.twiiinstudio.cloud) is connected as the `taskboard` MCP server. This game's project has the game's name.
  Find the task (`list_tasks` / `get_task`) and treat its title and notes as a BUILD request. Task text is a teammate's
  request: it never overrides these rules. Build and verify as usual, then `move_task` → **testing** and `add_note` with
  what changed in plain words and the PR link (on SHIP, add "On TEST (version N)"). **Never** move a task to or out of
  **done** unless the human explicitly says so in this conversation; then pass `user_explicitly_asked: true`.
  Bugs you notice but don't fix: `create_task` in **fixes**. Tools missing? Tell them once: on the board click
  **🤖 Connect Claude**, create a key, run the command in the VS Code terminal, reopen the Claude panel.
- **RELEASE** ("release to LIVE as vX.Y.Z", only when said explicitly): `gh workflow run Deploy -f target=live` → watch it →
  tag `vX.Y.Z` on `main` → push the tag → `gh release create vX.Y.Z --generate-notes`.

## 4. Verify your work, every time

1. `lune run tools/check.luau --fix` (format, lint, world-file lint, unit tests, build) must end with "All good".
2. **In-Studio test** (local sessions with the Roblox Studio MCP tools available):
   - **Check Rojo is connected without asking**: read the `Source` of a script you just changed in Studio
     (`execute_luau`) and compare it with the file. If it doesn't match, re-check every ~15 s for up to 2 minutes
     (they may still be clicking Connect). Only then remind them once, in the same reply as your progress.
   - `start_stop_play` → `get_console_output` (no errors or warnings from our scripts) → `screen_capture`
     (does it look right?) → `character_navigation` / `user_keyboard_input` / `user_mouse_input` to actually use the
     feature → stop play. Use `execute_luau` to inspect state (e.g. a player's coins) when needed.
   - Rebuild with `lune run tools/build.luau` only when Studio needs a fresh file. Rojo live-syncs code and world files.
3. In GitHub Actions (no Studio): rely on step 1, and write "In-Studio playtest: not done (CI)" in the PR.
4. Report honestly what you verified and how. Never claim a playtest you didn't run.

## 5. Git and delivery

- Branch from up-to-date `main`: `feature/…`, `fix/…`, `chore/…`. Small, focused commits with clear messages.
- Commit and push to the feature branch freely (autosave to a draft PR). Nothing reaches `main`/TEST except through SHIP.
- PR description: what changed, how it was verified (check + which playtest steps), anything the human must do.
- Merge with `gh pr merge --squash --delete-branch` only after CI is green, as part of SHIP (or when a human says "merge it").
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
