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
$RawBaseUrl = "https://raw.githubusercontent.com/$GithubUser/$GithubRepo/$Branch/skills"

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
    $ManifestUrl = "https://raw.githubusercontent.com/$GithubUser/$GithubRepo/$Branch/skills.json"
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
    # Download files dynamically in parallel using background jobs
    Write-Host "Downloading files in parallel..." -ForegroundColor Yellow
    $Jobs = foreach ($Skill in $SkillsManifest.skills) {
        if ($Skill.name -in $SelectedSkills) {
            foreach ($File in $Skill.files) {
                $Url = "$RawBaseUrl/$File"
                $AgentsDest = Join-Path $AgentsSkillsDir $File
                $ClaudeDest = Join-Path $ClaudeSkillsDir $File
                
                Start-Job -ScriptBlock {
                    param($Url, $ADest, $CDest)
                    $ParentA = Split-Path $ADest -Parent; $null = New-Item -ItemType Directory -Force -Path $ParentA
                    $ParentC = Split-Path $CDest -Parent; $null = New-Item -ItemType Directory -Force -Path $ParentC
                    try {
                        Invoke-RestMethod -Uri $Url -OutFile $ADest -ErrorAction Stop
                        Invoke-RestMethod -Uri $Url -OutFile $CDest -ErrorAction Stop
                    } catch {
                        throw "Failed to download $Url"
                    }
                } -ArgumentList $Url, $AgentsDest, $ClaudeDest | Out-Null
            }
        }
    }
    if ($Jobs) {
        Get-Job | Wait-Job | Out-Null
        Get-Job | Remove-Job
        Write-Host "[+] Downloaded selected skills dynamically from manifest" -ForegroundColor Green
    }
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

Write-Host "`r`nDone! All selected skills successfully installed in $Mode mode." -ForegroundColor Cyan
