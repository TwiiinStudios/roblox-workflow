# 05 · Working together (two people, two Claudes, one Discord)

Each of you talks to your own Claude in your own VS Code. Both Claudes work on the same game through GitHub.
You two coordinate in **Discord**.

## The rules (that's all of them)

1. **Say in Discord what you're working on before you start.** *"I'm doing the fly shop."*
2. **Work on different things.** You do frogs, your teammate does the shop. Then your changes combine automatically.
3. **Small changes, merged often.** Ship and merge when something works, don't sit on it for a week.
4. **Discord is told automatically** when TEST changes (once the Discord webhook is set up, see [02](02-new-game.md)).
5. **Claude tells you what the other person is working on** with your first message, and gets their latest work.
6. **Unfinished work is saved online automatically** as a draft, so your teammate's Claude sees it and nothing is
   lost if your PC dies. When you're done, just close VS Code.
7. **Decisions go into `DESIGN.md`.** Claude writes them down, so both Claudes build the same game.

## What happens when you both work at the same time

**You changed different things → nothing to do**
Your fly shop and their egg hatching live in different files, and both merges just work.

**You both changed the same file, different parts → combined automatically**
You add a fly price to the settings file; they add an egg price. Both stay.

**You both changed the exact same thing → Claude asks you**
Example: you set flies to 10 coins, your teammate set them to 20. When you say "Ship it", Claude sees the
clash (*merge conflict*), keeps everything it can combine, and asks you about the rest:
> "Your teammate set FLY_PRICE to 20, you set it to 10. Which one?"

Decide together on Discord and answer Claude. Nothing gets lost.

**You want to try your teammate's change before it's merged**
> "Show me what my teammate is working on and play-test it."

## Things that can't be combined

Things Claude generated inside Studio (like an AI-made 3D frog mesh, stored as `.rbxm` files in `Captured/`
folders) can't be merged line by line. Only one person should work on a given generated asset at a time. Mention it in Discord.

## A good split for GrowAFrog (example)

| Person A | Person B |
|---|---|
| Frogs: growing, feeding, sizes | Shop and money |
| Saving player data | Eggs and hatching, rarities |
| The map: pond, paths, decoration | The UI: shop menu, HUD |

The shared settings file (`Config.luau`) gets touched by both. That's fine: it merges cleanly unless you change the same line.

## Checking each other's work

Every pull request is checked automatically by GitHub (and by Claude Review if the Claude token is set up).
The human part is simple: after a merge, **play TEST** and say in Discord what you think.
