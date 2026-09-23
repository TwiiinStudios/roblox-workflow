# roblox-workflow

Our studio's **AI-first workflow for making Roblox games**: humans describe, AI builds everything
(code, map, UI, lighting, models), tests it in Studio, and delivers it through GitHub. Every new game starts here.

```
Roblox/                      ← games folder (same layout on both PCs)
├── CLAUDE.md                ← one line: @roblox-workflow/CLAUDE.md  (Claude loads the rules automatically)
├── roblox-workflow/         ← THIS repo: docs + template + scripts
├── GrowAFrog/               ← a game repo made from template/
└── NextGame/
```

## New here? Set up your PC in 3 steps

1. Install Claude Code and log in once:
   ```powershell
   winget install Anthropic.ClaudeCode
   claude
   ```
2. Make the games folder and start Claude there:
   ```powershell
   mkdir $HOME\Documents\Projects\Roblox
   cd $HOME\Documents\Projects\Roblox
   claude
   ```
3. Say to Claude:
   > **Clone https://github.com/TwiiinStudios/roblox-workflow into this folder, read its CLAUDE.md, and set up my PC.**

Claude installs everything (Git, GitHub CLI, Rokit + tools, Roblox Studio, Rojo plugin, the Studio ↔ Claude connection),
clones all game repos, and walks you through the few clicks only a human can do (Windows install prompts,
GitHub login in the browser, logging in to Studio). Details: [01 · One-time setup](docs/01-one-time-setup.md).

## Team

| | |
|---|---|
| GitHub owner | `TwiiinStudios` |
| Roblox group | (fill in when created) |

## How it works

```
 You: "Add a fly shop next to spawn…"                    GitHub issue: "@claude add daily rewards"
        │                                                              │
        ▼                                                              ▼
 Claude Code on your PC                                   Claude in GitHub Actions
   writes files (code, world, UI) ──rojo serve──► Studio   writes files, runs checks
   play-tests via Studio MCP (play, walk, click,            │
   screenshots, console) and fixes what it finds            │
        │ "ship it"                                         │
        ▼                                                   ▼
                    Pull Request ──► CI checks ✔ + Claude Review 💬
                         │ merge (you, or Claude when you say so)
                         ▼
             Deploy action ──► TEST experience (automatic) ──► you play it
                                     │ "release to LIVE" (humans decide)
                                     ▼
                              LIVE experience ──► players
```

- **The game is only files.** Nothing is built by hand in Studio, so everything is reviewable, mergeable and rebuildable.
- **Studio is the AI's test lab.** Through Roblox's built-in MCP server, Claude plays the game, moves around,
  clicks, reads errors and looks at screenshots.
- **Humans decide:** what to build, whether it's fun, what gets merged, and when it goes LIVE.

## The handbook

| # | Doc | Read it when |
|---|---|---|
| 01 | [One-time setup](docs/01-one-time-setup.md) | New PC or new team member |
| 02 | [Starting a new game](docs/02-new-game.md) | New game idea |
| 03 | [Project structure](docs/03-project-structure.md) | How the AI builds each kind of thing |
| 04 | [Daily workflow](docs/04-daily-workflow.md) | Every day: working with Claude locally and on GitHub |
| 05 | [Working together](docs/05-working-together.md) | Two people, two AIs, conflicts |
| 06 | [Testing](docs/06-testing.md) | What the AI tests, what you test |
| 07 | [Publishing](docs/07-publishing.md) | TEST/LIVE, releases, rollbacks, API key |
| 08 | [Conventions](docs/08-conventions.md) | Rules for code, Git, security, humans vs AI |
| 09 | [Troubleshooting](docs/09-troubleshooting.md) | Something broke |
| 10 | [Cheat sheet](docs/10-cheatsheet.md) | What to say to Claude, on one page |

## Quick start

1. Once: [01 · One-time setup](docs/01-one-time-setup.md).
2. In the `Roblox` folder, run `claude` and say: *"New game: MyGame. Create it from the template with a GitHub repo in TwiiinStudios."*
3. Do the 4 human steps in [02](docs/02-new-game.md). Then *"Start a session"* and describe your game.

## What's in this repo

| Path | What |
|---|---|
| `docs/` | The handbook |
| `template/` | Starting point of every game, including its `CLAUDE.md` (the AI's operating manual) |
| `scripts/new-game.ps1` | Creates a game from the template (+ optional GitHub repo) |
| `CLAUDE.md` | Rules Claude follows for everything under `Roblox/` |

## Improving the workflow

Change docs and template **together** on a branch → PR → merge. To bring improvements into existing games:
*"Sync the latest template changes from roblox-workflow into this game."*
