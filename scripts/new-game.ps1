<#
.SYNOPSIS
    Creates a new Roblox game project from the roblox-workflow template.

.DESCRIPTION
    Copies template/ into a new folder next to roblox-workflow (or -Destination),
    fills in the game name, installs the toolchain, runs the checks and makes the
    first git commit. With -GitHub it also creates a private GitHub repo and pushes.

    Works on an existing EMPTY folder too (e.g. one you already created).

.EXAMPLE
    .\scripts\new-game.ps1 -Name GrowAFrog

.EXAMPLE
    .\scripts\new-game.ps1 -Name LuckyDumpsters -GitHub -GitHubOwner MyStudioOrg
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')]
    [string]$Name,

    # Parent folder for the new project. Default: the folder that contains roblox-workflow.
    [string]$Destination,

    # Also create a private GitHub repo (needs `gh auth login` once) and push.
    [switch]$GitHub,

    # GitHub user or organisation to create the repo under. Default: your own account.
    [string]$GitHubOwner,

    # Org team that gets write access to the new repo (the org's base permission is Read).
    [string]$GitHubTeam = 'game-devs',

    # Create the git repo and stage the files, but don't make the first commit.
    [switch]$SkipCommit
)

$ErrorActionPreference = 'Stop'

$kitRoot = Split-Path -Parent $PSScriptRoot
$template = Join-Path $kitRoot 'template'
if (-not $Destination) { $Destination = Split-Path -Parent $kitRoot }
$target = Join-Path $Destination $Name

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Invoke-Native($exe, [string[]]$arguments) {
    # Many tools print progress to stderr; don't let Windows PowerShell treat that as an error.
    $ErrorActionPreference = 'Continue'
    & $exe @arguments 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { throw "$exe $($arguments -join ' ') failed (exit code $LASTEXITCODE)" }
}

# 0. Pre-flight: required tools and git identity
foreach ($tool in @('git', 'rokit') + $(if ($GitHub) { @('gh') } else { @() })) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "'$tool' is not installed. See docs\01-one-time-setup.md."
    }
}
if ($GitHub -and $SkipCommit) { throw "-GitHub needs a commit to push; don't combine it with -SkipCommit." }
if (-not $SkipCommit -and -not $env:GIT_AUTHOR_NAME) {
    $gitName = git config user.name
    $gitEmail = git config user.email
    if (-not $gitName -or -not $gitEmail) {
        throw "Git doesn't know who you are yet. Run once:`n  git config --global user.name ""Your Name""`n  git config --global user.email ""you@example.com""`n(See docs\01-one-time-setup.md.)"
    }
}

# 1. Target folder must be new or empty
if (Test-Path $target) {
    $existing = @(Get-ChildItem -Force $target)
    if ($existing.Count -gt 0) { throw "$target already exists and is not empty." }
} else {
    New-Item -ItemType Directory -Path $target | Out-Null
}

# 2. Copy the template (including dotfiles such as .github, .vscode, .gitignore)
Step "Copying template to $target"
Get-ChildItem -Force $template | Copy-Item -Destination $target -Recurse -Force

# 3. Fill in placeholders
Step "Filling in the game name"
$wallyName = "$(if ($GitHubOwner) { $GitHubOwner } else { 'studio' })/$Name".ToLower()
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
Get-ChildItem -Recurse -File -Force $target |
    Where-Object { $_.Extension -in '.luau', '.json', '.toml', '.md', '.yml', '.example' } |
    ForEach-Object {
        $text = [IO.File]::ReadAllText($_.FullName)
        $new = $text.Replace('__GAME_NAME__', $Name).Replace('__WALLY_NAME__', $wallyName)
        if ($new -ne $text) { [IO.File]::WriteAllText($_.FullName, $new, $utf8NoBom) }
    }

Push-Location $target
try {
    # 4. Toolchain + packages
    Step "Installing toolchain (rokit install)"
    Invoke-Native 'rokit' @('install')
    Step "Installing packages (wally install)"
    Invoke-Native 'wally' @('install')

    # 5. Prove everything works
    Step "Running checks"
    Invoke-Native 'lune' @('run', 'tools/check.luau')

    # 6. Git
    Step "Creating git repository"
    Invoke-Native 'git' @('init', '-b', 'main')
    Invoke-Native 'git' @('add', '-A')
    if (-not $SkipCommit) {
        Invoke-Native 'git' @('commit', '-m', "Create $Name from roblox-workflow template")
    }

    # 7. Optional GitHub repo
    if ($GitHub) {
        Step "Creating private GitHub repo and pushing"
        $repo = if ($GitHubOwner) { "$GitHubOwner/$Name" } else { $Name }
        Invoke-Native 'gh' @('repo', 'create', $repo, '--private', '--source', '.', '--remote', 'origin', '--push')
        if ($GitHubOwner -and $GitHubTeam) {
            Step "Giving the $GitHubTeam team write access"
            Invoke-Native 'gh' @('api', '--method', 'PUT', "orgs/$GitHubOwner/teams/$GitHubTeam/repos/$repo", '-f', 'permission=push', '--silent')
        }
    }
} finally {
    Pop-Location
}

Write-Host "`nDone! $Name is ready at $target" -ForegroundColor Green
Write-Host "Next: docs\02-new-game.md, section 'After the script' (Roblox places, deploy.json, API key)."
