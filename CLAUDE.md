# Roblox studio workflow: rules for Claude

Loaded for every folder under `Roblox/` (via `Roblox/CLAUDE.md` → `@roblox-workflow/CLAUDE.md`).

## The deal
Two friends make Roblox games. **You (AI) build everything**: code, map, UI, lighting, models, tests, PRs.
They describe, decide, merge and release. Minimise their manual work. When a human step is unavoidable,
ask for one concrete action. They're on Windows and work **only in VS Code** (Claude Code panel). They coordinate on
**Discord**, not GitHub Issues. At least one is a beginner: plain words, one step at a time, no Git jargon without
explaining it. `docs/00-start-here.md` is the beginner guide; point them to it.

## Where things are
- `roblox-workflow/docs/00..10-*.md`: the handbook (00 = beginner guide). Read the relevant doc before answering workflow questions.
- `roblox-workflow/template/`: every game starts from this. Its `CLAUDE.md` is the per-game operating manual.
- `roblox-workflow/scripts/new-game.ps1`: creates a game.

## "Set up my PC" (new team member, new PC, or "what do I need?")
Required: Windows + winget, Git, GitHub CLI (logged in), Rokit (+ the tools in `template/rokit.toml`), Roblox Studio,
the Rojo Studio plugin, the Roblox Studio MCP server registered in Claude Code, a git identity, `Roblox/CLAUDE.md`.
The script also installs VS Code and the Claude Code extension.
1. Ask for their GitHub owner/org if you don't know it (see the README's "Team" table).
2. Run `powershell -ExecutionPolicy Bypass -File roblox-workflow/scripts/setup-pc.ps1 -GitHubOwner <owner>`
   (add `-GitName "<name>" -GitEmail "<email>"` once they've told you). It installs what's missing, trusts the tools,
   installs the Rojo plugin, registers the Studio MCP server, creates `Roblox/CLAUDE.md`, clones and prepares every game repo,
   and prints a `[done]`/`[TODO]` summary. It's safe to re-run.
3. Walk them through each `[TODO]` one at a time. Only the human can do these: approve Windows install prompts,
   `gh auth login` (browser), open Roblox Studio once and log in. Re-run the script after each until there are no TODOs.
4. Finish with: "In VS Code: File → Open Folder → Roblox\GrowAFrog (or another game), reopen the Claude panel,
   and tell Claude what to build." and point them to `docs/00-start-here.md`.

## Starting a new game
From the `Roblox` folder run
`powershell -ExecutionPolicy Bypass -File roblox-workflow/scripts/new-game.ps1 -Name <PascalCase> [-GitHub -GitHubOwner <org>]`
(add `-GitHub` only if the user asked for a repo). Then walk them through the 4 human steps in `docs/02-new-game.md`,
doing everything you can yourself (e.g. writing their IDs into `deploy.json`).

## Inside a game
Follow that game's `CLAUDE.md` exactly: files are the only source of truth, the build order of preference,
verification (check + Studio MCP play-test), the workflow (automatic session setup, BUILD, SHIP, SHARE, RELEASE; never waste their prompts),
and the LIVE rule: **never publish to LIVE unless explicitly asked in that message.**
Never ask for, print or commit API keys or tokens. The humans set secrets themselves with `gh secret set`.

## Changing the workflow
Edit `roblox-workflow/` docs and template together so they never disagree. Test template changes by generating a
throwaway game in a temp folder and running `lune run tools/check.luau`. Then offer to sync the change into existing games.
