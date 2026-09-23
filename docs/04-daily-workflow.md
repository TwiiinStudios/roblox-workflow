# 04 · Daily workflow: building with AI

You have **two ways** to get things built. Use whichever fits the moment.

| | Mode A: Claude on your PC | Mode B: Claude on GitHub |
|---|---|---|
| Where | Claude Code in the game folder | A GitHub issue or PR comment with `@claude` |
| Studio play-testing by AI | ✅ yes (Studio MCP) | ❌ no, checks and unit tests only |
| Good for | Gameplay, world, UI, anything visual | Small changes, balancing, ideas from your phone |
| You need | PC with Studio open | Just a browser or phone |

---

## Mode A: Claude on your PC

### 1. Start the session (1 minute, the only routine manual step)

```powershell
cd $HOME\Documents\Projects\Roblox\GrowAFrog
claude
```
Say: **"Start a session."** Claude pulls `main`, runs `wally install`, builds `build/game.rbxl` and starts `rojo serve`.
It then asks you to **open `build/game.rbxl` in Studio and click Rojo → Connect**. Do that once; it stays connected
while Claude works.

### 2. Describe what you want

Be specific about **what** and **why**, not how. Claude handles the how.

> "Add feeding: players buy flies at a shop stand next to the spawn (10 coins each), then click their frog to feed it.
> Each fly grows the frog by 5, up to 1000. Show the frog's size above its head. Test it in Studio."

Claude will:
1. create a branch `feature/frog-feeding`,
2. write the code (FrogService, ShopController, Remotes, Config), the shop stand (a world builder) and the UI,
3. run `lune run tools/check.luau --fix`,
4. **play-test in Studio**: start play, walk to the shop, buy flies, click the frog, read the console, take screenshots,
5. fix what it finds, and repeat until it works,
6. tell you what it built and what it verified.

### 3. Look at it yourself (optional but recommended)

Press **F5** in Studio and play for a minute. Tell Claude what to change:
> "The shop stand is too far from spawn and the size label is too small on my phone-size window. Fix both."

### 4. Ship it

> "Ship it."

Claude commits, pushes and opens a PR. **CI** checks it and **Claude Review** comments on it.
> "Merge it when CI is green."

Merged → about 1 minute later it's on the **TEST** experience. Play it on Roblox, together, on any device.

### 5. Next task

> "Next: eggs that hatch into random frogs. Common 70%, rare 25%, legendary 5%."

Claude starts a new branch from the updated `main` by itself.

---

## Mode B: Claude on GitHub (from anywhere)

1. On GitHub: **Issues → New issue**.
2. Title: `Daily reward`. Body:
   > @claude add a daily login reward: 50 coins, doubled for each day in a row, max 7 days. Show a popup on join.
3. Claude reacts in the issue, works on a branch, and opens a **PR** linked to the issue.
4. CI + Claude Review run. Want changes? Comment on the PR:
   > @claude make the popup close automatically after 5 seconds
5. Happy? **Merge** (the green button), and it's on TEST.

Tip: for visual things, finish in Mode A. Tell your local Claude:
*"Check out PR #12 and play-test it in Studio."*

---

## What stays human (on purpose)

| Human job | Why |
|---|---|
| Deciding **what** to build and whether it's fun | That's the game design. It's yours. |
| Opening Studio + clicking Connect once per session | Studio is a desktop app |
| Pressing Ctrl+S when Claude captured a generated asset | Studio needs to save to disk |
| Merging to `main` (or saying "merge it") | Quality gate |
| **Releasing to LIVE** | Real players, real data |
| Money, keys, group and experience settings | Account security |

## Good requests vs. bad requests

| ❌ Vague | ✅ Clear |
|---|---|
| "make it better" | "Frogs feel slow. Make walking 30% faster and add a hop animation when they move." |
| "add a shop" | "Add a shop stand at spawn selling flies (10 coins) and golden flies (100 coins, 10x growth)." |
| "fix the bug" | "When two players feed the same frog, both get charged. Only the owner should be able to feed it." |

Mention: **what** the player sees and does, **numbers**, **where** in the world, and **"test it in Studio"**.
