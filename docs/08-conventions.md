# 08 · Conventions

The AI follows these automatically (they're in every game's `CLAUDE.md`). They're here so humans know them
too, and so you can change them: edit this file **and** `template/CLAUDE.md` in the same PR.

## Branches

| Prefix | For | Example |
|---|---|---|
| `feature/` | new gameplay, world, UI | `feature/frog-feeding` |
| `fix/` | bug fixes | `fix/shop-double-charge` |
| `chore/` | tools, config, cleanup, docs | `chore/update-rojo` |

## Commits and PRs

- Commit message: short, present tense, what changed. *"Add fly shop stand at spawn"*.
- One PR per change. The description says **what** changed and **how it was verified**.
- CI green before merging. **Squash and merge.**

## Code style

Formatting and lint are automatic (StyLua, selene). Beyond that:

| Thing | Style | Example |
|---|---|---|
| Module files | PascalCase | `FrogService.luau` |
| Locals, functions | camelCase | `local frogSize` |
| Constants, Config keys | UPPER_SNAKE_CASE | `GROWTH_PER_FLY` |
| Remotes | VerbNoun | `FeedFrog`, `BuyItem` |

- `task.wait/spawn/delay`, never `wait/spawn/delay`.
- No magic numbers in logic. They go in `Config.luau`.
- Each module starts with a short `--[[ ]]` comment saying what it's for.

## Security (exploiters are real)

- The client can send anything. **Every remote handler validates** types, ranges, ownership, distance, cooldowns.
- The server decides money, items, stats, damage. The client only asks.
- No secrets in `src/shared` or `src/client` (clients can read them). Server secrets use Roblox **Secrets**
  (Game Settings → Security), never Git.

## Data

- One `DataService` owns DataStores. Prefer **ProfileStore** (Wally).
- Saved data has a `version` number, and migrations run when it changes.
- Test data changes on TEST first. LIVE data is sacred.

## World and assets

- Text first: builders (`src/server/World/`) and `.model.json` beat binary `.rbxm`.
- `.model.json` uses the explicit `CFrame`, never `Position` (lint enforces this).
- `Captured/` folders are written only by `tools/capture.luau`.

## Working with the AI

- **Humans own**: what to build, whether it's fun, merging, LIVE releases, money, keys, account settings.
- **AI owns**: how to build it, code, world, UI, tests, play-testing, PRs, fixing CI.
- Give the AI the **what + numbers + where**, and say "test it in Studio".
- If the AI asks you a design question, answer it. Don't say "you decide" for things that change how the game feels.
- Never paste API keys, passwords or cookies into a chat with the AI.

## Tool versions

Pinned in each game's `rokit.toml`. To upgrade: *"Update rojo to the latest version in this game and in the template."*
The other person runs `rokit install` after pulling (Claude does it at session start).
