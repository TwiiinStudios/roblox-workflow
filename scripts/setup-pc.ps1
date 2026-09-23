<#
.SYNOPSIS
    Sets up (or checks) a Windows PC for the roblox-workflow. Safe to run again at any time.

.DESCRIPTION
    Installs what's missing (winget): Git, GitHub CLI, Rokit, Roblox Studio (+ VS Code with -WithVSCode).
    Trusts the Rokit tools the template uses, installs the Rojo Studio plugin, registers the Roblox Studio
    MCP server with Claude Code, creates Roblox\CLAUDE.md, and (with -GitHubOwner) clones every game repo.
    Ends with a list of what's done and what a human still has to do.

.EXAMPLE
    .\scripts\setup-pc.ps1
.EXAMPLE
    .\scripts\setup-pc.ps1 -GitHubOwner TwiiinStudios -GitName "Sam" -GitEmail "sam@example.com"
#>
param(
    # GitHub user/org whose game repos should be cloned next to roblox-workflow.
    [string]$GitHubOwner,
    # Set the git identity (only if not set yet).
    [string]$GitName,
    [string]$GitEmail,
    # Also install VS Code (optional, for reading code yourself).
    [switch]$WithVSCode
)

$ErrorActionPreference = 'Continue'
$kitRoot = Split-Path -Parent $PSScriptRoot
$gamesRoot = Split-Path -Parent $kitRoot
$template = Join-Path $kitRoot 'template'

$done = New-Object System.Collections.Generic.List[string]
$todo = New-Object System.Collections.Generic.List[string]

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user;$HOME\.rokit\bin"
}
function Run($exe, [string[]]$arguments) {
    & $exe @arguments 2>&1 | ForEach-Object { Write-Host "    $_" }
    return ($LASTEXITCODE -eq 0)
}
function Find-Studio {
    Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\RobloxStudioBeta.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
}

# 1. Programs ---------------------------------------------------------------
Step "Programs"
if (-not (Has 'winget')) {
    $todo.Add("Install 'App Installer' from the Microsoft Store (gives winget), then run this script again.")
} else {
    $apps = @(
        @{ Name = 'Git';           Id = 'Git.Git';                Present = { Has 'git' } },
        @{ Name = 'GitHub CLI';    Id = 'GitHub.cli';             Present = { Has 'gh' } },
        @{ Name = 'Rokit';         Id = 'Rojo.Rokit';             Present = { (Has 'rokit') -or (Test-Path "$HOME\.rokit\bin\rokit.exe") } },
        @{ Name = 'Roblox Studio'; Id = 'Roblox.RobloxStudio';    Present = { [bool](Find-Studio) } }
    )
    if ($WithVSCode) { $apps += @{ Name = 'VS Code'; Id = 'Microsoft.VisualStudioCode'; Present = { Has 'code' } } }

    foreach ($app in $apps) {
        if (& $app.Present) {
            $done.Add("$($app.Name) installed")
            continue
        }
        Write-Host "  installing $($app.Name)... (click Yes if Windows asks for permission)"
        $ok = Run 'winget' @('install', '--id', $app.Id, '-e', '--silent', '--accept-source-agreements', '--accept-package-agreements')
        Update-SessionPath
        if ($ok -or (& $app.Present)) { $done.Add("$($app.Name) installed now") }
        else { $todo.Add("Install $($app.Name) by hand (winget id $($app.Id)) and run this script again.") }
    }
}
Update-SessionPath

if (-not (Has 'claude')) {
    $todo.Add("Install Claude Code: winget install Anthropic.ClaudeCode   (then run 'claude' once to log in)")
} else {
    $done.Add("Claude Code installed")
}

# 2. Rokit + tools -------------------------------------------------------------
Step "Rokit tools"
if (Has 'rokit') {
    Run 'rokit' @('self-install') | Out-Null
    Update-SessionPath
    # Trust every tool the template pins, so 'rokit install' never stops to ask.
    $tools = Select-String -Path (Join-Path $template 'rokit.toml') -Pattern '"([\w-]+/[\w-]+)@' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
    Run 'rokit' (@('trust') + $tools) | Out-Null
    Push-Location $template
    $ok = Run 'rokit' @('install')
    Pop-Location
    if ($ok) { $done.Add("Rokit tools trusted and installed: $($tools -join ', ')") }
    else { $todo.Add("'rokit install' failed in template\ - see output above.") }
} else {
    $todo.Add("Rokit missing - run this script again after installing it.")
}

# 3. Git identity -----------------------------------------------------------------
Step "Git identity"
if (Has 'git') {
    if ($GitName -and -not (git config --global user.name)) { git config --global user.name $GitName }
    if ($GitEmail -and -not (git config --global user.email)) { git config --global user.email $GitEmail }
    git config --global init.defaultBranch main
    $name = git config --global user.name
    $email = git config --global user.email
    if ($name -and $email) { $done.Add("Git identity: $name <$email>") }
    else { $todo.Add("Tell Claude your name and GitHub email so it can run: git config --global user.name/user.email") }
}

# 4. GitHub login --------------------------------------------------------------------
Step "GitHub login"
$ghOk = $false
if (Has 'gh') {
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $ghOk = $true
        gh auth setup-git 2>&1 | Out-Null
        $done.Add("Logged in to GitHub as $(gh api user --jq .login)")
    } else {
        $todo.Add("Log in to GitHub: run   gh auth login   in a terminal (GitHub.com > HTTPS > web browser), then run this script again.")
    }
}

# 5. Rojo plugin for Studio ------------------------------------------------------------
Step "Rojo Studio plugin"
if ((Find-Studio) -and (Has 'rokit')) {
    Push-Location $template
    $ok = Run 'rojo' @('plugin', 'install')
    Pop-Location
    if ($ok) { $done.Add("Rojo plugin installed in Studio (restart Studio if it was open)") }
    else { $todo.Add("Rojo plugin install failed - see output above.") }
} else {
    $todo.Add("Rojo plugin: install Roblox Studio, open it once, then run this script again.")
}

# 6. Claude Code <-> Roblox Studio (MCP) -------------------------------------------------
Step "Claude Code <-> Roblox Studio (MCP)"
$mcpBat = Join-Path $env:LOCALAPPDATA 'Roblox\mcp.bat'
if (-not (Has 'claude')) {
    # already listed above
} elseif (-not (Test-Path $mcpBat)) {
    $todo.Add("Studio MCP: open Roblox Studio once (it creates $mcpBat), then run this script again.")
} else {
    $existing = claude mcp list 2>&1 | Out-String
    if ($existing -match 'Roblox[_ ]?Studio') {
        $done.Add("Roblox Studio MCP already registered in Claude Code")
    } else {
        $ok = Run 'claude' @('mcp', 'add', '--scope', 'user', 'Roblox_Studio', '--', 'cmd.exe', '/c', $mcpBat)
        if ($ok) { $done.Add("Roblox Studio MCP registered in Claude Code (restart Claude Code to load it)") }
        else { $todo.Add("Studio MCP: in Studio open Assistant > ... > Manage MCP Servers > Quick connect > Claude Code.") }
    }
}

# 7. Roblox\CLAUDE.md --------------------------------------------------------------
Step "Roblox\CLAUDE.md"
$rootClaude = Join-Path $gamesRoot 'CLAUDE.md'
$kitName = Split-Path -Leaf $kitRoot
if (Test-Path $rootClaude) {
    if ((Get-Content $rootClaude -Raw) -match [regex]::Escape("@$kitName/CLAUDE.md")) { $done.Add("$rootClaude links the workflow rules") }
    else { $todo.Add("$rootClaude exists but doesn't contain '@$kitName/CLAUDE.md' - add that line.") }
} else {
    [IO.File]::WriteAllText($rootClaude, "@$kitName/CLAUDE.md`n", (New-Object System.Text.UTF8Encoding($false)))
    $done.Add("Created $rootClaude")
}

# 8. Game repos ------------------------------------------------------------------------
if ($GitHubOwner) {
    Step "Game repos from $GitHubOwner"
    if (-not $ghOk) {
        $todo.Add("Clone games: log in to GitHub first, then run this script again with -GitHubOwner $GitHubOwner.")
    } else {
        $repos = gh repo list $GitHubOwner --limit 200 --json name,isArchived --jq '.[] | select(.isArchived | not) | .name' 2>$null
        foreach ($repo in $repos) {
            if ($repo -eq $kitName) { continue }
            $path = Join-Path $gamesRoot $repo
            if (-not (Test-Path $path)) {
                Run 'gh' @('repo', 'clone', "$GitHubOwner/$repo", $path) | Out-Null
            }
            if (Test-Path (Join-Path $path 'default.project.json')) {
                Push-Location $path
                Run 'rokit' @('install') | Out-Null
                if (Test-Path 'wally.toml') { Run 'wally' @('install') | Out-Null }
                Pop-Location
                $done.Add("Game ready: $path")
            } elseif (Test-Path $path) {
                $done.Add("Cloned (not a Rojo game, left as is): $path")
            }
        }
    }
}

# Summary ------------------------------------------------------------------------------
Write-Host "`n================ SUMMARY ================" -ForegroundColor Cyan
foreach ($line in $done) { Write-Host "  [done] $line" -ForegroundColor Green }
foreach ($line in $todo) { Write-Host "  [TODO] $line" -ForegroundColor Yellow }
if ($todo.Count -eq 0) {
    Write-Host "`nThis PC is ready. Restart Claude Code, open Roblox Studio, and say 'Start a session' inside a game folder." -ForegroundColor Green
}
