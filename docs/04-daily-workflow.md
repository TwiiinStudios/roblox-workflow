# 04 · Daily workflow: START → BUILD → SHIP → PLAY

New to all of this? Read [00 · Start here](00-start-here.md) first.

```
 🐸  START  →  BUILD  →  SHIP  →  PLAY          (+ PAUSE when you stop before it's finished)
```

| Step | You | Claude |
|---|---|---|
| **0. Discord** | Post what you're working on: *"I'm doing the fly shop"* | |
| **1. START** | Open **Roblox Studio** (start screen is enough) → VS Code in the game folder → Claude panel → **"Start"** | Gets the newest version of the game, tells you what your teammate is working on, builds the game, starts Rojo, opens the game in Studio |
| | In Studio: **Plugins → Rojo → Connect** | Checks it can see and control Studio |
| **2. BUILD** | Say what you want (what the player sees/does, numbers, where) | Builds it on its own branch, tests it in Studio (plays, walks, clicks, screenshots), fixes, explains. Writes decisions into `DESIGN.md` |
| | Optional: press **F5** in Studio to play it yourself, give feedback | Adjusts |
| **3. SHIP** | **"Ship it"** | Runs all checks, pulls in your teammate's latest changes, saves to GitHub, merges, waits for the TEST game to update. Discord gets a message automatically |
| **4. PLAY** | Play the TEST game together in the Roblox app | |

## The other words

| Say | When | Claude does |
|---|---|---|
| **"Pause"** | You stop before something is finished | Saves your unfinished work online as a draft (backed up, your teammate can see it), stops Rojo. Next "Start" offers to continue it |
| **"Share it"** | You want your teammate to look before it goes on TEST | Like Ship it, but stops at the pull request and gives you a link for Discord |
| **"What changed?"** | Your teammate shipped something | Summarises what's new in plain words |
| **"Release to LIVE as v1.0.0"** | You both agreed in Discord | Publishes to the real game, labels the version ([07](07-publishing.md)) |

Loose wording is fine: "start", "let's go", "ship", "done, ship it", "stop for today".

## Tips for good results

| ❌ Vague | ✅ Clear |
|---|---|
| "make it better" | "Frogs feel slow. Make them walk 30% faster and hop when they move." |
| "add a shop" | "Add a shop stand at spawn: flies for 10 coins, golden flies for 100 coins (10x growth)." |
| "fix the bug" | "When two players feed the same frog, both get charged. Only the owner should be able to feed it." |

- Say **what the player sees and does**, **numbers**, **where**. Claude tests in Studio by itself.
- One thing at a time; ship small things often.
- Claude asks design questions ("should frogs die if not fed?"). Answer them: you're the game designers.
  The answer goes into `DESIGN.md`, so your teammate's Claude builds with the same rules.

## What stays human

| You | Why |
|---|---|
| Deciding what to build and whether it's fun | That's the game design |
| Rojo → Connect in Studio | Studio doesn't let programs press plugin buttons |
| Saying "Ship it" / "Release" | Nothing reaches TEST or LIVE without a human saying so |
| Roblox/GitHub settings, API keys, Robux | Account security |

## If Claude can't see Studio

Studio must be open. In the Claude panel type **`/mcp`** → **Roblox_Studio** → **Reconnect** (or close and reopen the panel).
First time on a PC: Studio → Assistant → ⋯ → Manage MCP Servers → **Enable Studio as MCP server** ([01 · A4](01-one-time-setup.md)).
