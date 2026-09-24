# 04 · Daily workflow

New to all of this? Read [00 · Start here](00-start-here.md) first. This page is the same loop with a bit more detail.

Everything happens in **VS Code** (Claude Code panel). Coordination happens in **Discord**. Studio only runs in the
background so Claude can test in it.

## The loop

```
 Discord: "I'm doing the fly shop"
      │
 VS Code → Claude: "Start a session"
      │   Claude: pulls latest main → builds → opens Studio → starts Rojo
      │   You: Studio → Plugins → Rojo → Connect   (the only click)
      ▼
 You: "Add a fly shop next to spawn… Test it in Studio."
      │   Claude: new branch → writes code/world/UI → checks → play-tests in Studio → fixes → reports
      │   You (optional): F5 in Studio, give feedback, repeat
      ▼
 You: "Ship it"   → Claude: commit → push → pull request → checks run on GitHub
 You: "Merge it"  → Claude: merge → Deploy → TEST updated (~1 min) → gives you a Discord line
      ▼
 Discord: "✅ On TEST: fly shop next to spawn"  → you both play TEST in the Roblox app
```

## What to say, and what Claude does

| You say | Claude does |
|---|---|
| **"Start a session"** | `git pull`, installs tools and packages, builds `build/game.rbxl`, opens it in Studio, starts `rojo serve`, asks you to click Connect, checks the Studio connection |
| **"Add / change … Test it in Studio."** | Makes a branch (e.g. `feature/fly-shop`), builds it, runs all checks, play-tests with the Studio MCP, fixes, and explains what it verified |
| **"Ship it"** | Commits, pushes, opens a pull request with a description, reports the link + a Discord line |
| **"Merge it"** | Waits for the checks, merges, waits for the TEST deploy, reports + a Discord line |
| **"What changed?"** | Pulls and summarises what your teammate merged |
| **"Release to LIVE as v0.1.0"** | Only when you both agreed: publishes to LIVE, tags the version ([07](07-publishing.md)) |

## Tips for good results

| ❌ Vague | ✅ Clear |
|---|---|
| "make it better" | "Frogs feel slow. Make them walk 30% faster and hop when they move." |
| "add a shop" | "Add a shop stand at spawn: flies for 10 coins, golden flies for 100 coins (10x growth)." |
| "fix the bug" | "When two players feed the same frog, both get charged. Only the owner should be able to feed it." |

- Say **what the player sees and does**, **numbers**, **where**, and end with **"Test it in Studio."**
- One thing at a time. Ship small changes often, rather than one giant change after a week.
- Claude asks you design questions ("should frogs die if not fed?"). Answer them. That's your job as the game designer.

## What stays human, on purpose

| You | Why |
|---|---|
| Deciding what to build and whether it's fun | That's the game design |
| The Rojo → Connect click | Studio doesn't let other programs press its buttons |
| "Merge it" | Quality gate: nothing reaches TEST without a human saying so |
| Releasing to LIVE | Real players, real data |
| Roblox/GitHub settings, API keys, Robux | Account security |

## Optional: from your phone

If the `CLAUDE_CODE_OAUTH_TOKEN` secret is set on the repo, you can also comment `@claude …` on a pull request on GitHub,
e.g. *"@claude make the shop button bigger"*, and Claude changes it there. Handy when you're away from your PC;
not needed day to day.
