# install.ps1 - Cross-agent skill installer for Windows
# Usage: 
#   Local (cloned):   .\install.ps1 [-Mode Copy|Link]
#   Remote (one-line): irm https://raw.githubusercontent.com/hiadamhere/skills/main/install.ps1 | iex

param (
    [ValidateSet("Copy", "Link")]
    [string]$Mode
)

$GithubUser = "hiadamhere"
$GithubRepo = "skills" # public catalog repo (remote mode fetches published files only)
$Branch = "main"
$RawBaseUrl = "https://raw.githubusercontent.com/$GithubUser/$GithubRepo/$Branch/skills"

# Check if script folder exists to determine if running locally
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
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
}

# 2. Ensure global directories exist
$GeminiSkillsDir = Join-Path $env:USERPROFILE ".gemini\config\skills"
$ClaudeSkillsDir = Join-Path $env:USERPROFILE ".claude\skills"
$CodexDir = Join-Path $env:USERPROFILE ".codex"

$null = New-Item -ItemType Directory -Force -Path $GeminiSkillsDir
$null = New-Item -ItemType Directory -Force -Path $ClaudeSkillsDir
$null = New-Item -ItemType Directory -Force -Path $CodexDir

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


# Helper function to deploy a folder (Copy or Link)
function Deploy-Folder {
    param (
        [string]$Source,
        [string]$Destination,
        [string]$Mode
    )

    if (Test-Path $Destination) {
        Remove-Item $Destination -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($Mode -eq "Link") {
        try {
            New-Item -ItemType SymbolicLink -Path $Destination -Value $Source -Force -ErrorAction Stop | Out-Null
            Write-Host "[+] Linked: $(Split-Path $Destination -Leaf)" -ForegroundColor Green
        }
        catch {
            Write-Warning "Symlink failed (requires Developer Mode or Administrator). Falling back to Copy mode..."
            Copy-Item -Path $Source -Destination $Destination -Recurse -Force
            Write-Host "[+] Copied: $(Split-Path $Destination -Leaf) (Fallback)" -ForegroundColor Green
        }
    }
    else {
        Copy-Item -Path $Source -Destination $Destination -Recurse -Force
        Write-Host "[+] Copied: $(Split-Path $Destination -Leaf)" -ForegroundColor Green
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

# 3. Main Deploy Logic
if ($IsRemote) {
    # Download files dynamically in parallel using background jobs
    Write-Host "Downloading files in parallel..." -ForegroundColor Yellow
    $Jobs = foreach ($Skill in $SkillsManifest.skills) {
        foreach ($File in $Skill.files) {
            $Url = "$RawBaseUrl/$File"
            $GeminiDest = Join-Path $GeminiSkillsDir $File
            $ClaudeDest = Join-Path $ClaudeSkillsDir $File
            
            Start-Job -ScriptBlock {
                param($Url, $GDest, $CDest)
                $ParentG = Split-Path $GDest -Parent
                $null = New-Item -ItemType Directory -Force -Path $ParentG
                $ParentC = Split-Path $CDest -Parent
                $null = New-Item -ItemType Directory -Force -Path $ParentC
                
                try {
                    Invoke-RestMethod -Uri $Url -OutFile $GDest -ErrorAction Stop
                    Invoke-RestMethod -Uri $Url -OutFile $CDest -ErrorAction Stop
                } catch {
                    throw "Failed to download $Url"
                }
            } -ArgumentList $Url, $GeminiDest, $ClaudeDest | Out-Null
        }
    }
    Get-Job | Wait-Job | Out-Null
    Get-Job | Remove-Job
    Write-Host "[+] Downloaded skills dynamically from manifest" -ForegroundColor Green
} else {
    # Local installation
    Get-ChildItem -Directory -Path $SkillsDir | ForEach-Object {
        $SkillName = $_.Name
        $SourcePath = $_.FullName
        Deploy-Folder -Source $SourcePath -Destination (Join-Path $GeminiSkillsDir $SkillName) -Mode $Mode
        Deploy-Folder -Source $SourcePath -Destination (Join-Path $ClaudeSkillsDir $SkillName) -Mode $Mode
    }
}

# 4. OpenAI Codex CLI Deployment
$CodexAgentsFile = Join-Path $CodexDir "AGENTS.md"
$Header = "`r`n`r`n# --- Imported from msaf-architect skill ($Mode Mode) ---"
$Body = ""

if ($IsRemote) {
    $SkillUrl = "$RawBaseUrl/msaf-architect/SKILL.md"
    try {
        $Body = Invoke-RestMethod -Uri $SkillUrl -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to download Codex instructions."
    }
} else {
    $MsafSkill = Join-Path $SkillsDir "msaf-architect\SKILL.md"
    if (Test-Path $MsafSkill) {
        $Body = Get-Content $MsafSkill -Raw
    }
}

if ($Body) {
    if (Test-Path $CodexAgentsFile) {
        $ExistingContent = Get-Content $CodexAgentsFile -Raw
        if ($ExistingContent -match "Imported from msaf-architect skill") {
            $Pattern = "(?s)# --- Imported from msaf-architect skill.*"
            $ExistingContent = $ExistingContent -replace $Pattern, ""
            Set-Content -Path $CodexAgentsFile -Value $ExistingContent -Force
        }
    }
    Add-Content -Path $CodexAgentsFile -Value "$Header`r`n$Body"
    Write-Host "[+] OpenAI Codex: Updated global AGENTS.md" -ForegroundColor Green
}

Write-Host "`r`nDone! All skills successfully installed in $Mode mode." -ForegroundColor Cyan
