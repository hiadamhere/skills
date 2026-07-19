# install.ps1 - Cross-agent skill installer for Windows
# Usage: 
#   Local (cloned):   .\install.ps1 [-Mode Copy|Link]
#   Remote (one-line): irm https://raw.githubusercontent.com/hiadamhere/skills/main/install.ps1 | iex

param (
    [string]$Mode,
    [string]$Scope,
    [string]$Path,
    [string]$Skills
)

# NOTE: do NOT put a [ValidateSet(...)] attribute on $Mode or $Scope. When this script is
# piped to Invoke-Expression (irm ... | iex), PowerShell applies the attribute to
# variables while their values are still empty and aborts.
# Validate manually instead so the remote one-liner keeps working.
if ($Mode -and $Mode -notin @("Copy", "Link")) {
    Write-Error "Invalid -Mode '$Mode'. Valid values: Copy, Link."
    exit 1
}
if ($Scope -and $Scope -notin @("Global", "Folder")) {
    Write-Error "Invalid -Scope '$Scope'. Valid values: Global, Folder."
    exit 1
}

$GithubUser = "hiadamhere"
$GithubRepo = "skills" # public catalog repo (remote mode fetches published files only)
$Branch = "main"
# $RawBaseUrl is built below from $Ref -- a pinned commit SHA for remote installs.

# Check if script folder exists to determine if running locally.
# $MyInvocation.MyCommand.Path is $null when this script is piped to iex
# (irm ... | iex); guard it so Split-Path never receives a null argument
# (a terminating parameter-binding error that -ErrorAction cannot suppress).
$ScriptPath = $MyInvocation.MyCommand.Path
$RepoDir = if ($ScriptPath) { Split-Path -Parent $ScriptPath } else { $null }
if (-not $RepoDir -or -not (Test-Path (Join-Path $RepoDir "skills"))) {
    $IsRemote = $true
} else {
    $IsRemote = $false
    $SkillsDir = Join-Path $RepoDir "skills"
}

# Resolve the ref to install from. Remote installs pin to a single commit SHA so
# a push landing mid-install can't serve a manifest from one commit and files
# from another -- every remote install is a consistent snapshot. Fall back to the
# branch ref on any API failure (e.g. rate limit) so the install still proceeds.
$Ref = $Branch
if ($IsRemote) {
    try {
        $commitInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$GithubUser/$GithubRepo/commits/$Branch" -Headers @{ "User-Agent" = "skills-installer" } -ErrorAction Stop
        if ($commitInfo.sha) {
            $Ref = $commitInfo.sha
            Write-Host "Pinned to commit $($Ref.Substring(0, 7)) for a consistent snapshot." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Warning "Could not resolve '$Branch' to a commit SHA ($($_.Exception.Message)). Falling back to '$Branch' refs; this install may not be a consistent snapshot."
    }
}
$RawBaseUrl = "https://raw.githubusercontent.com/$GithubUser/$GithubRepo/$Ref/skills"

# 1. Handle Remote vs Local Setup
if ($IsRemote) {
    Write-Host "Running in REMOTE mode (fetching files from GitHub)..." -ForegroundColor Yellow
    if ($Mode -eq "Link") {
        Write-Warning "Symlink mode is not available in remote execution. Defaulting to Copy (Download) mode."
    }
    $Mode = "Copy"
    $Scope = "Global"
} else {
    Write-Host "Running in LOCAL mode (using cloned repository files)..." -ForegroundColor Cyan
    # Prompt for mode if not specified
    if (-not $Mode) {
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "    AI Agent Custom Skill Installer          " -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "How would you like to install the skills?"
        Write-Host "[1] Copy Mode (Self-contained: files copied, safe to move/delete repo later)"
        Write-Host "[2] Symlink Mode (Recommended: live updates from 'git pull', requires Developer Mode/Admin)"
        
        do {
            $choice = Read-Host "Select option (1 or 2)"
        } while ($choice -ne "1" -and $choice -ne "2")

        if ($choice -eq "1") { $Mode = "Copy" }
        else { $Mode = "Link" }
    }
    
    # Prompt for scope if not specified
    if (-not $Scope) {
        Write-Host "`r`nSelect installation scope:" -ForegroundColor Cyan
        Write-Host "[1] Global (user profile: standard agent config folders)"
        Write-Host "[2] Folder/Local (specific workspace: installs inside a custom repository/folder)"
        
        do {
            $scopeChoice = Read-Host "Select option (1 or 2)"
        } while ($scopeChoice -ne "1" -and $scopeChoice -ne "2")

        if ($scopeChoice -eq "1") { $Scope = "Global" }
        else { $Scope = "Folder" }
    }
}

$TargetFolder = ""
if ($Scope -eq "Folder") {
    if ($Path) {
        $TargetFolder = $Path
    } else {
        Write-Host "`r`nInstalling locally to a specific workspace folder..." -ForegroundColor Cyan
        $TargetFolder = Read-Host "Enter target folder path (default: .)"
        if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
            $TargetFolder = "."
        }
    }
    $TargetFolder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetFolder)
}

# 2. Ensure target directories exist
if ($Scope -eq "Folder") {
    $AgentsSkillsDir = Join-Path $TargetFolder ".agents\skills"
    $ClaudeSkillsDir = Join-Path $TargetFolder ".claude\skills"
} else {
    $AgentsSkillsDir = Join-Path $env:USERPROFILE ".agents\skills"
    $ClaudeSkillsDir = Join-Path $env:USERPROFILE ".claude\skills"
}

$null = New-Item -ItemType Directory -Force -Path $AgentsSkillsDir
$null = New-Item -ItemType Directory -Force -Path $ClaudeSkillsDir

# Manifest: remote mode fetches from GitHub; local mode reads the clone (no network)
if ($IsRemote) {
    $ManifestUrl = "https://raw.githubusercontent.com/$GithubUser/$GithubRepo/$Ref/skills.json"
    try {
        $SkillsManifest = Invoke-RestMethod -Uri $ManifestUrl -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to download catalog manifest from $ManifestUrl"
        exit 1
    }
} else {
    $SkillsManifest = Get-Content (Join-Path $RepoDir "skills.json") -Raw | ConvertFrom-Json
}

# 3. Determine Selected Skills
$AvailableSkills = @()
if ($IsRemote) {
    $AvailableSkills = $SkillsManifest.skills | ForEach-Object { $_.name }
} else {
    $AvailableSkills = Get-ChildItem -Directory -Path $SkillsDir | ForEach-Object { $_.Name }
}

$SelectedSkills = @()
if ($Skills) {
    $SelectedSkills = $Skills.Split(",") | ForEach-Object { $_.Trim() }
    # Filter valid ones
    $SelectedSkills = $SelectedSkills | Where-Object { $_ -in $AvailableSkills }
    if ($SelectedSkills.Count -eq 0) {
        Write-Error "None of the specified skills '$Skills' are available in the catalog."
        exit 1
    }
} else {
    if ($AvailableSkills.Count -gt 1) {
        Write-Host "`r`nAvailable Skills in Catalog:" -ForegroundColor Cyan
        Write-Host "[1] ALL"
        for ($i = 0; $i -lt $AvailableSkills.Count; $i++) {
            Write-Host "[$($i + 2)] $($AvailableSkills[$i])"
        }
        Write-Host "Select skills to install (comma-separated numbers, or press Enter for ALL):"
        $skillsChoice = Read-Host "Choice"
        if (-not [string]::IsNullOrWhiteSpace($skillsChoice)) {
            $indices = $skillsChoice.Split(",") | ForEach-Object { [int]$_.Trim() }
            if ($indices -contains 1) {
                $SelectedSkills = $AvailableSkills
            } else {
                foreach ($idx in $indices) {
                    $realIdx = $idx - 2
                    if ($realIdx -ge 0 -and $realIdx -lt $AvailableSkills.Count) {
                        $SelectedSkills += $AvailableSkills[$realIdx]
                    }
                }
            }
        } else {
            $SelectedSkills = $AvailableSkills
        }
    } else {
        $SelectedSkills = $AvailableSkills
    }
}


# Helper function to deploy a folder (Copy or Link)
function Deploy-Folder {
    param (
        [string]$Source,
        [string]$Destination,
        [string]$Mode,
        [string]$AgentLabel
    )

    if (Test-Path $Destination) {
        Remove-Item $Destination -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($Mode -eq "Link") {
        try {
            New-Item -ItemType SymbolicLink -Path $Destination -Value $Source -Force -ErrorAction Stop | Out-Null
            Write-Host "[+] Linked: $(Split-Path $Destination -Leaf) -> $AgentLabel" -ForegroundColor Green
        }
        catch {
            Write-Warning "Symlink failed (requires Developer Mode or Administrator). Falling back to Copy mode..."
            Copy-Item -Path $Source -Destination $Destination -Recurse -Force
            Write-Host "[+] Copied: $(Split-Path $Destination -Leaf) -> $AgentLabel (Fallback)" -ForegroundColor Green
        }
    }
    else {
        Copy-Item -Path $Source -Destination $Destination -Recurse -Force
        Write-Host "[+] Copied: $(Split-Path $Destination -Leaf) -> $AgentLabel" -ForegroundColor Green
    }
}

# Helper function to download file from url
function Download-File {
    param (
        [string]$Url,
        [string]$Destination
    )
    $ParentDir = Split-Path $Destination -Parent
    $null = New-Item -ItemType Directory -Force -Path $ParentDir
    try {
        Invoke-RestMethod -Uri $Url -OutFile $Destination -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to download $Url to $Destination. Error: $_"
    }
}

# 4. Main Deploy Logic
if ($IsRemote) {
    # Build the download worklist: each file is fetched once, then copied to the
    # second target dir (halves network traffic vs. downloading per destination).
    $Downloads = foreach ($Skill in $SkillsManifest.skills) {
        if ($Skill.name -in $SelectedSkills) {
            foreach ($File in $Skill.files) {
                [pscustomobject]@{
                    Url        = "$RawBaseUrl/$File"
                    AgentsDest = Join-Path $AgentsSkillsDir $File
                    ClaudeDest = Join-Path $ClaudeSkillsDir $File
                }
            }
        }
    }

    # Kick off one background job per file. NOTE: capture the Start-Job objects into
    # $Jobs (do NOT pipe to Out-Null here, or $Jobs is empty and the wait below never
    # runs — the original bug that made the installer report success before, and
    # regardless of, any download completing).
    Write-Host "Downloading files in parallel..." -ForegroundColor Yellow
    $Jobs = foreach ($D in $Downloads) {
        Start-Job -ScriptBlock {
            param($Url, $ADest, $CDest)
            $null = New-Item -ItemType Directory -Force -Path (Split-Path $ADest -Parent)
            $null = New-Item -ItemType Directory -Force -Path (Split-Path $CDest -Parent)
            Invoke-RestMethod -Uri $Url -OutFile $ADest -ErrorAction Stop
            Copy-Item -LiteralPath $ADest -Destination $CDest -Force
        } -ArgumentList $D.Url, $D.AgentsDest, $D.ClaudeDest
    }

    # Wait on OUR jobs only (Get-Job | Wait-Job would also block on the user's own
    # pre-existing session jobs), drain them, and remove them so none are left
    # running or orphaned in the session.
    if ($Jobs) {
        $Jobs | Wait-Job | Out-Null
        $Jobs | Receive-Job -ErrorAction SilentlyContinue | Out-Null
        $Jobs | Remove-Job -Force
    }

    # Disk state — not job exit state — is the source of truth for success: a file
    # present and non-empty in BOTH target dirs is installed. This ignores spurious
    # background-job teardown noise while still catching genuinely dropped files, any
    # of which get one sequential retry before the install is declared a failure.
    $Failed = foreach ($D in $Downloads) {
        foreach ($Dest in @($D.AgentsDest, $D.ClaudeDest)) {
            $ok = (Test-Path -LiteralPath $Dest) -and ((Get-Item -LiteralPath $Dest).Length -gt 0)
            if (-not $ok) {
                try {
                    $null = New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent)
                    Invoke-RestMethod -Uri $D.Url -OutFile $Dest -ErrorAction Stop
                } catch {}
                $ok = (Test-Path -LiteralPath $Dest) -and ((Get-Item -LiteralPath $Dest).Length -gt 0)
            }
            if (-not $ok) { $D.Url }
        }
    }
    $Failed = @($Failed | Select-Object -Unique)

    if ($Failed.Count -gt 0) {
        Write-Host ""
        Write-Error "Install failed: $($Failed.Count) file(s) could not be downloaded:"
        foreach ($Url in $Failed) { Write-Error "  - $Url" }
        exit 1
    }

    Write-Host "[+] Downloaded selected skills dynamically from manifest" -ForegroundColor Green
} else {
    # Local installation
    foreach ($SkillName in $SelectedSkills) {
        $SourcePath = Join-Path $SkillsDir $SkillName
        if (Test-Path $SourcePath) {
            Deploy-Folder -Source $SourcePath -Destination (Join-Path $AgentsSkillsDir $SkillName) -Mode $Mode -AgentLabel "Agents (Shared)"
            Deploy-Folder -Source $SourcePath -Destination (Join-Path $ClaudeSkillsDir $SkillName) -Mode $Mode -AgentLabel "Claude"
        }
    }
}

# Record what was installed so uninstall/upgrade (and a future --check-updates)
# can reason about it: the exact commit, how it was installed, and which skills.
$installedSha = if ($IsRemote) { $Ref } else { "local" }
$marker = [ordered]@{
    markerVersion = 1
    sha           = $installedSha
    ref           = $Branch
    remote        = [bool]$IsRemote
    mode          = $Mode
    scope         = $Scope
    date          = (Get-Date).ToString("o")
    skills        = @($SelectedSkills)
} | ConvertTo-Json
foreach ($dir in @($AgentsSkillsDir, $ClaudeSkillsDir)) {
    try { Set-Content -Path (Join-Path $dir ".installed.json") -Value $marker -Encoding UTF8 } catch {}
}

Write-Host "`r`nDone! All selected skills successfully installed in $Mode mode." -ForegroundColor Cyan
