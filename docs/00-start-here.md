# 00 · Start here (plain-language guide)

This is for you if you've never done this before. You **don't need to know how to code** and you **don't need to learn Git**.
You talk to Claude in VS Code, and Claude does the technical work.

## The pieces, explained simply

| Piece | What it is | Do I touch it? |
|---|---|---|
| **VS Code** | The program where you talk to Claude (the Claude Code panel on the side) | ✅ This is where you work |
| **Claude** | Your builder. It writes the game, tests it, fixes it and saves it | ✅ You tell it what you want |
| **Roblox Studio** | Where the game runs so it can be tested. Claude plays it for you | Only one click per session (below) |
| **Rojo** | The "cable" between VS Code and Studio. Every change Claude makes appears in Studio instantly | Only that same one click |
| **GitHub** | The shared online save of the game, with full history. Both of you work on the same game through it | ❌ Claude handles it |
| **TEST game** | A private copy of the game on Roblox where you two play the newest version | ✅ Play it with the normal Roblox app |
| **LIVE game** | The real public game | Only when you both decide to release |
| **Discord** | Where you two talk: who's doing what, "I merged something" | ✅ As usual |

## The whole workflow in four words: START → BUILD → SHIP → PLAY

**0. Tell your teammate in Discord what you're doing.** *"I'm doing the fly shop."*

**1. START**
- Open **Roblox Studio**. The start screen is enough; don't open a game.
- Open **VS Code** → **File → Open Folder…** → `DocumentsProjectsRobloxGrowAFrog` → open the **Claude Code** panel
  (the Claude icon on the side, or at the top right of the editor).
- Say **"Start"**. Claude gets the newest version of the game, tells you what your teammate is working on, and
  **opens the game in Studio for you**. Then it asks for the one click:
  > In Studio: **Plugins** tab (top) → **Rojo** → **Connect**
- Leave Studio open in the background. You can close the extra start-screen window.

**2. BUILD**
Describe what you want like you'd explain it to a friend: what the player sees and does, numbers, and where.
> "Add a shop stand next to the spawn where players buy flies for 10 coins. Clicking your frog feeds it a fly and
> it grows by 5."

Claude builds it, then **tests it in Studio by itself**: it presses Play, walks the character, clicks buttons, reads
errors and takes screenshots. It fixes what's broken and tells you what it did.
Want to see it yourself? Click into Studio and press **F5** (Play), then **Shift+F5** to stop.
Don't like something? Just say it: *"Make the shop bigger and move it closer to the spawn."*

**3. SHIP**
Say **"Ship it"**. Claude checks everything, pulls in your teammate's latest changes, saves it to GitHub and adds it to
the game. About 2 minutes later it's on the **TEST game**, and your Discord channel gets a message automatically.

**4. PLAY**
Open the TEST game link (in the game's README) in your browser → **Play**. It opens in the normal Roblox app.
Play together, try it on your phone, check that saving works.

**Stopping before it's finished? Say "Pause".** Your unfinished work is saved online (your teammate can see it)
and next time "Start" offers to continue it.

## Working together without getting in each other's way

- **Say in Discord what you're working on.** Working on different things means your changes combine automatically.
- **"Start" tells you what your teammate is working on**, and Claude warns you if you're about to build something
  that overlaps with it.
- **Discord gets a message automatically** whenever the TEST game is updated.
- **Decisions are written down in `DESIGN.md`** (prices, rules, style), so both of your Claudes build the same game.
  Ask *"What did we decide about …?"* anytime.
- If you both changed the same thing, Claude notices and asks you what to keep. Nothing gets lost.
- Unsure what your teammate changed? Ask *"What changed?"*

## Common questions

**Do I need Rojo?** Yes. It's what makes Claude's changes appear in Studio. It's already installed.
Claude starts it for you; you only click **Connect** in Studio once per session.

**Do I build things in Studio?** No. Everything is made by Claude as files. Things you build by hand in Studio
are thrown away the next time the game is built. Studio is only for testing and watching.

**Do I publish from Studio?** Never. The TEST game updates automatically when you merge. LIVE updates only when you
both agree and tell Claude *"Release to LIVE"*.

**Something is broken or confusing?** Tell Claude exactly what you see: *"When I press Play I fall through the floor"*,
or *"There's a red error in Studio's Output window"*. Claude investigates.

**I closed Studio, or it says Rojo disconnected.** Say *"Start a session"* again, or *"Reconnect Studio."*

**Claude says it can't see Studio.** Make sure Studio is open, then close and reopen the Claude Code panel.
The very first time, Studio also needs its switch turned on: Studio → **Assistant** panel → **⋯** → **Manage MCP Servers**
→ **Enable Studio as MCP server** (on). The other toggles in that window: "Visual Studio Code" doesn't matter
(it's for a different AI), "Claude Code CLI" leave off (Claude is already connected by the setup).
Rule of thumb: **open Studio first, then Claude.**

## Words you might hear

| Word | Meaning |
|---|---|
| Branch | Claude's private work area for one change, so it doesn't disturb the main game until it's done |
| Pull request (PR) | "Here's my change, please check it", shown on GitHub |
| Merge | Accepting the change into the main game |
| `main` | The main version of the game. It always works |
| CI / checks | Automatic tests GitHub runs on every change |
| Deploy | Publishing the game to Roblox (TEST automatically, LIVE by hand) |
