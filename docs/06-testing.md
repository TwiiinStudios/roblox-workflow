# 06 · Testing: what the AI checks, what you check

| Level | Who / how | Time | Catches |
|---|---|---|---|
| 1. `check.luau` | Claude, every change (format, lint, world lint, unit tests, build) | 5 s | Typos, broken builds, logic bugs in tested modules |
| 2. AI play-test in Studio | Claude via Studio MCP | 1-3 min | Runtime errors, broken features, things that look wrong |
| 3. Multiplayer in Studio | You or Claude: **Test → Clients and Servers** | 1 min | Remotes, trading, replication |
| 4. CI on the PR | GitHub, automatic | 1 min | Same as 1, on a clean machine, plus a downloadable `game.rbxl` |
| 5. Claude Review on the PR | GitHub, automatic | 2 min | Security holes, bugs, rule breaks |
| 6. TEST experience | Automatic after merge; you play it | 1-2 min | Real servers, DataStores, phones, playing together |
| 7. LIVE | Manual button | | Only ship what passed 6 |

## Level 2: how the AI play-tests

With Studio open on `build/game.rbxl`, Rojo connected, and the Studio MCP connected, Claude:

1. `start_stop_play` starts a play-test.
2. `get_console_output` reads errors and warnings.
3. `screen_capture` looks at the screen. Is the shop stand there? Does the UI fit?
4. `character_navigation` walks the character to the shop; `user_mouse_input` / `user_keyboard_input` click buttons and press keys.
5. `execute_luau` checks state, e.g. *did coins go from 100 to 90?*
6. Stops play, fixes problems, repeats.

You can ask for specific tests:
> "Play-test as a brand-new player: buy 3 flies, feed the frog, check the size goes from 1 to 16, and screenshot the UI."

## Level 1: unit tests for game logic

Claude puts formulas in pure modules and tests them, e.g.:

```lua
-- tests/FrogGrowth.spec.luau
local FrogGrowth = require("../src/shared/FrogGrowth")

return {
	["grows by flies x perFly"] = function()
		assert(FrogGrowth.sizeAfterFeeding(10, 2, 5, 1000) == 20)
	end,
	["never grows past the max"] = function()
		assert(FrogGrowth.sizeAfterFeeding(990, 5, 5, 1000) == 1000)
	end,
}
```
Good for prices, growth curves, rarity rolls, level math. These run in CI too, so a later change can't silently break them.

## Level 6: the TEST experience (you)

After a merge, open `GrowAFrog [TEST]` on Roblox (PC and phone). This is the only place where **DataStores**
(saving) work for real, and where you play together from two houses.
In local Studio (`build/game.rbxl`) data isn't saved: the game uses in-memory data there.

## Before releasing to LIVE (human checklist)

- [ ] Played TEST as a new player (no save) and as a returning player (save loads)
- [ ] Played TEST with 2+ players
- [ ] Tried it on a phone (touch controls, UI fits)
- [ ] No red errors in the in-game console (**F9**)
- [ ] It's fun 🙂
