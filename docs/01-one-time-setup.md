# 01 · One-time setup

In this workflow **AI builds everything**: code, map, UI, lighting, models. Humans describe, check and decide.
The setup below is the only real manual work, and you do it once.

Do **Part A once per person** (each PC). Do **Part B once for the team**.

> **Fast path for Part A:** follow "New here?" in the [README](../README.md). Claude runs
> `scripts/setup-pc.ps1`, which does A1-A6 for you and lists anything left as `[TODO]`. You can re-run it any time
> to check a PC: `powershell -ExecutionPolicy Bypass -File roblox-workflow\scripts\setup-pc.ps1 -GitHubOwner <owner>`.
> The steps below are the manual reference.

---

## Part A: Each person, each PC (~20 minutes)

### A1. Install the programs

| Program | Why | Get it |
|---|---|---|
| **Git** | Version control | https://git-scm.com/download/win (defaults are fine) |
| **GitHub CLI** (`gh`) | Repos, PRs, secrets from the terminal | `winget install GitHub.cli` |
| **VS Code** + **Claude Code extension** | Where you work: you talk to Claude in its panel | https://code.visualstudio.com, then Extensions → "Claude Code" (Anthropic) → Install → log in |
| **Claude Code CLI** | Used by scripts (`claude mcp add`) | `winget install Anthropic.ClaudeCode` |
| **Rokit** | Installs Rojo, Lune, selene, StyLua, Wally per project | https://github.com/rojo-rbx/rokit#installation (then `rokit self-install`) |
| **Roblox Studio** | Engine; the AI play-tests here | https://create.roblox.com |

Restart the terminal, then check: `git --version`, `gh --version`, `claude --version`, `rokit --version`.

### A2. Tell Git who you are

```powershell
git config --global user.name "YourName"
git config --global user.email "you@example.com"     # your GitHub email (or the private noreply one)
git config --global init.defaultBranch main
```

### A3. Log in to GitHub

```powershell
gh auth login        # GitHub.com → HTTPS → Login with a web browser
```

### A4. Connect Claude Code to Roblox Studio (the Studio MCP server)

This lets Claude see the open game, run code in Studio, start play-tests, move a test character,
read the Output window and take screenshots.

1. Open Roblox Studio (latest version) and open any place.
2. Open the **Assistant** panel → **⋯** menu (top right of the panel) → **Manage MCP Servers**
   (the window is called *Assistant Settings*).
3. Set the switches like this:

   | Switch | Set to | Why |
   |---|---|---|
   | **Enable Studio as MCP server** | ✅ **On (required)** | Lets AI tools talk to Studio. Off = Claude only gets "Request timed out". |
   | Quick connect → **Visual Studio Code** | Doesn't matter | Connects VS Code's *own* AI (GitHub Copilot), not Claude. Harmless either way. |
   | Quick connect → **Claude Code CLI** | ❌ **Leave off** | `setup-pc.ps1` already connects Claude (also for the VS Code panel). Turning it on too can register Studio twice. |

   When it works, the line under the main switch changes from *"No clients connected"* to showing Claude as connected
   while a Claude session is running.
4. **Open Studio first, then open (or reopen) the Claude panel in VS Code.** Claude connects to Studio when it starts.
5. Check (optional): `claude mcp list` shows `Roblox_Studio: … ✔ Connected` while Studio is open.

To add the Claude Code side by hand (only if you didn't run `setup-pc.ps1`):
```powershell
claude mcp add --scope user Roblox_Studio -- cmd.exe /c '%LOCALAPPDATA%\Roblox\mcp.bat'
```
Studio must be **open** whenever Claude needs it. Official docs: https://create.roblox.com/docs/studio/mcp

### A5. Rojo plugin in Studio

Inside any game folder (after `rokit install`): `rojo plugin install`, then restart Studio.

### A6. Get the workflow kit and teach Claude about it

```powershell
cd $HOME\Documents\Projects\Roblox
gh repo clone TwiiinStudios/roblox-workflow
```

Create `Roblox\CLAUDE.md` (the folder **above** the games) containing exactly:

```
@roblox-workflow/CLAUDE.md
```

Claude Code reads `CLAUDE.md` files in parent folders, so every game under `Roblox\` automatically follows this workflow.

---

## Part B: Once for the team (~15 minutes)

### B1. Roblox Group

Roblox now calls groups **Communities**. Why one: the games belong to the community, not a personal account; roles give
the teammate exactly the rights they need; Robux lands in shared group funds and can be paid out (one-off or recurring %);
assets and the publishing API keys live under the community.

1. Have **100 Robux** (the cost of creating one).
2. roblox.com → **Communities** → **Create Community** → name (e.g. `TwiiinStudios`), description, square emblem
   (moderated) → pay → created.
3. The teammate opens the community page → **Join Community**.
4. Community page → **⋯ → Configure Community → Roles → Create Role**, e.g. `Developer`. Permissions:
   - ✅ edit/manage the community's experiences, ✅ view analytics
   - ❌ spend group funds, ❌ manage roles, ❌ kick/ban members (owner only)
5. **Members** → assign the teammate to `Developer`.

(No community? One person owns the games and adds the other as a Collaborator in Creator Hub. You can move later, but it's painful.)

### B2. GitHub Organization

Our org: **`TwiiinStudios`**. Every game repo lives there: `github.com/TwiiinStudios/GrowAFrog`.

| Role | Who | Can |
|---|---|---|
| **Owner** | rA9-001 | Everything: create repos, secrets (API keys), org settings, billing, members |
| **Member** | the friend | Push branches, open/merge PRs, `@claude`, run workflows in every repo |

For members to be able to push, the org's **base permission must be _Write_**
(Org → Settings → Member privileges → Base permissions → **Write**). The default is Read, which is clone-only.

Invite a member: Org → People → Invite member → role **Member**.

> Note: on the free plan anyone with Write can also run the Deploy workflow, including `target: live`.
> The rule "LIVE only when both agree" is a team agreement (and Claude never does it unasked). GitHub Team (paid)
> can enforce it with a protected `live` environment.

### B3. Claude on GitHub (optional: automatic PR reviews + `@claude` in PR comments)

In Claude Code, inside any game repo folder:
```
/install-github-app
```
Follow the prompts: install the Claude GitHub app on the organization (all repositories) and store the token secret.

> On the **free** GitHub plan, organization-level secrets can't be used by private repos, so secrets are set
> **per game repo** (`/install-github-app` or `gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo TwiiinStudios/<Game>`).
> On a paid plan (Team) you could set it once with `gh secret set ... --org TwiiinStudios --visibility all`.

### B4. Put this kit on GitHub

```powershell
cd $HOME\Documents\Projects\Roblox\roblox-workflow
gh repo create TwiiinStudios/roblox-workflow --private --source . --remote origin --push
```
The other person does step A6.

✅ Done forever. Next: [02 · Starting a new game](02-new-game.md).
