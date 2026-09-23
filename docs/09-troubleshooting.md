# 09 · Troubleshooting

Almost everything here can be handed to Claude: *"CI is red on my PR, fix it."* The notes below explain the cause.

## Claude ↔ Studio (MCP)

**Claude says it has no Roblox Studio tools**
- Is Studio open (latest version)? The MCP server only exists while Studio runs.
- Assistant → ⋯ → Manage MCP Servers → Quick connect → Claude Code **on**.
- `claude mcp list` in a terminal should list it. Restart Claude Code after enabling.

**Claude is controlling the wrong Studio window**
Close other Studio windows, or tell Claude which one ("the one with build/game.rbxl"). It can list them with `list_roblox_studios`.

**Play-test screenshots don't show my change**
Rojo isn't connected (Plugins → Rojo → should say *Connected*), or `rojo serve` stopped. Ask Claude to restart it.
World builders (`src/server/World/`) only appear **during play**, not in edit mode.

## Rojo / Studio

**The Rojo plugin can't connect**
`rojo serve` must be running (Claude starts it). Only one per port: close old terminals. Plugin missing: `rojo plugin install`.

**Something I made in Studio disappeared**
Only the files are the game. Things made in Studio are lost unless they're in a `Captured` folder, saved (Ctrl+S),
and captured (`lune run tools/capture.luau`).

**A part from a `.model.json` is at 0,0,0**
It used `"Position"`. Rojo ignores that. Use the `CFrame` form. `lune run tools/lint-world.luau` finds these.

**DataStore errors in Studio**
Expected in the local `build/game.rbxl`. The game falls back to in-memory data. Test saving on the TEST experience.

## Tools

**`Failed to find tool 'rojo' in any project manifest file`**: you're not in a game folder. `cd` into it, then `rokit install`.
**`rokit install` asks to trust a tool**: yes for rojo-rbx, lune-org, kampfkarren, johnnymorganz, upliftgames.
**Format check failed**: `lune run tools/check.luau --fix`.

## Git

**Conflicts**: *"Merge main into my branch and resolve the conflicts."* ([05](05-working-together.md))
**Committed to `main` by accident (not pushed)**: *"Move my last commits from main to a new feature branch."*
**Throw away local changes**: `git restore .` (and `git clean -fd` for new files, careful).
**A secret got committed**: revoke it in Creator Hub first, then make a new one. Deleting the commit is not enough.

## GitHub Actions

| Symptom | Cause | Fix |
|---|---|---|
| CI red, works locally | Uncommitted file, or `wally.lock` not committed | `git status`; commit everything |
| Deploy: "skipping publish" warning | `ROBLOX_API_KEY` secret or `deploy.json` IDs missing | [02 steps 2-3](02-new-game.md) |
| Deploy: 401 / 403 | Key wrong/expired, missing `universe-places` Write, IP not `0.0.0.0/0` | New key → `gh secret set` |
| Deploy: 404 | Universe/place ID pair wrong | Fix `deploy.json` |
| Deploy: 409 | Two publishes at once | Wait, re-run |
| `@claude` does nothing | Claude app not installed on the repo/org, or `CLAUDE_CODE_OAUTH_TOKEN` missing, or the commenter lacks write access | [01 · B3](01-one-time-setup.md) |
| Claude on GitHub says a command isn't allowed | Not in `--allowedTools` in `.github/workflows/claude.yml` | Add it there |
