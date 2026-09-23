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
| **Claude Code** | The AI that builds the games | https://claude.ai/code (install, then run `claude` once to log in) |
| **Rokit** | Installs Rojo, Lune, selene, StyLua, Wally per project | https://github.com/rojo-rbx/rokit#installation (then `rokit self-install`) |
| **Roblox Studio** | Engine; the AI play-tests here | https://create.roblox.com |
| **VS Code** (optional) | To read code yourself | https://code.visualstudio.com |

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
2. Open the **Assistant** panel → **⋯** menu → **Manage MCP Servers**.
3. Under **Quick connect**, turn on **Claude Code**.
4. In a terminal: `claude mcp list` should list the Roblox Studio server.

If quick connect doesn't show Claude Code, add it by hand:
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

1. One person creates a group (communities → Create) and invites the other.
2. **Configure → Roles**: give both of you a role that can **edit group experiences**.

The games belong to the group, so nobody loses access and revenue can be split.
(No group yet? One person owns the games and adds the other as a Collaborator in Creator Hub.)

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

### B3. Claude on GitHub (lets you order features from a GitHub issue, even on your phone)

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
