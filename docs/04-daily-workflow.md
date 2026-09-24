# 04 · Daily workflow: BUILD → SHIP → PLAY

New to all of this? Read [00 · Start here](00-start-here.md) first.

```
 🐸  BUILD  →  SHIP  →  PLAY
```

**Every message you send Claude is about the game.** No "start", "pause" or "merge" messages: Claude does
setup, saving and checking by itself.

| Step | You | Claude |
|---|---|---|
| **Before** | Open **Roblox Studio** (start screen is enough) → **VS Code** in the game folder → Claude panel. Discord: *"I'm doing the fly shop"* | |
| **BUILD** | Say what you want (what the player sees/does, numbers, where) | First message of the session: gets the newest version, tells you what your teammate is working on, opens the game in Studio. Then builds it on its own branch, tests it in Studio, explains |
| | When the game shows up in Studio: **Plugins → Rojo → Connect** (don't reply, just click) | Notices by itself when Rojo is connected |
| | Optional: **F5** in Studio to play it yourself, give feedback | Adjusts. Saves your work online after every step |
| **SHIP** | **"Ship it"**, or put *"…and ship it"* into your request | Checks everything, pulls in your teammate's latest changes, merges, waits for the TEST game to update. Discord gets a message |
| **PLAY** | Play the TEST game together in the Roblox app | |

When you're done, just close VS Code. Unfinished work is already saved online (as a draft your teammate can see),
and next time Claude continues it.

## Fewest prompts: examples

| Instead of… | Say |
|---|---|
| "Start" → "Add a fly shop…" → "Ship it" (3 prompts) | "Add a fly shop next to spawn, flies cost 10 coins, and ship it." (1 prompt) |
| "Add X" → "done, I clicked connect" | Just click Connect. Claude notices |
| "Pause" at the end of the day | Nothing. Close VS Code |

Keep "…and ship it" for small, clear changes. For bigger or visual things, look first (F5), then say "ship it".

## The other words

| Say | When | Claude does |
|---|---|---|
| **"Share it"** | Your teammate should look before it goes on TEST | Stops at the pull request, gives you a link for Discord |
| **"What changed?"** | Anytime | Summarises what's new, in plain words |
| **"What did we decide about …?"** | Anytime | Answers from `DESIGN.md` |
| **"Undo that"** | You don't like the last change | Reverts it |
| **"Release to LIVE as v1.0.0"** | You both agreed in Discord | Publishes to the real game, labels the version ([07](07-publishing.md)) |

## Tips for good results

| ❌ Vague | ✅ Clear |
|---|---|
| "make it better" | "Frogs feel slow. Make them walk 30% faster and hop when they move." |
| "add a shop" | "Add a shop stand at spawn: flies for 10 coins, golden flies for 100 coins (10x growth)." |
| "fix the bug" | "When two players feed the same frog, both get charged. Only the owner should be able to feed it." |

- Say **what the player sees and does**, **numbers**, **where**. Claude tests in Studio by itself.
- Put several small things in **one** message rather than one message each.
- Claude asks design questions ("should frogs die if not fed?"). Answer them. The answer goes into `DESIGN.md`,
  so your teammate's Claude builds with the same rules.

## What stays human

| You | Why |
|---|---|
| Deciding what to build and whether it's fun | That's the game design |
| Rojo → Connect in Studio | Studio doesn't let programs press plugin buttons |
| Saying "ship it" / "release" | Nothing reaches TEST or LIVE without a human saying so |
| Roblox/GitHub settings, API keys, Robux | Account security |

## If Claude can't see Studio

Studio must be open **before** the Claude panel starts (start screen is enough). Fix without restarting: in the Claude
panel type **`/mcp`** → **Roblox_Studio** → **Reconnect**. First time on a PC: Studio → Assistant → ⋯ → Manage MCP Servers
→ **Enable Studio as MCP server** ([01 · A4](01-one-time-setup.md)).
