# uninstall.ps1 - Cross-agent skill uninstaller for Windows
# Usage:
#   .\uninstall.ps1 [-Scope Global|Folder] [-Path <target-folder>] [-Skills msaf-architect]

param (
    [string]$Scope,
    [string]$Path,
    [string]$Skills
)

if ($Scope -and $Scope -notin @("Global", "Folder")) {
    Write-Error "Invalid -Scope '$Scope'. Valid values: Global, Folder."
    exit 1
}

# 1. Determine Scope
if (-not $Scope) {
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "    AI Agent Custom Skill Uninstaller        " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "Select uninstallation scope:"
    Write-Host "[1] Global (user profile: standard agent config folders)"
    Write-Host "[2] Folder/Local (specific workspace: uninstalls from a custom repository/folder)"
    
    do {
        $scopeChoice = Read-Host "Select option (1 or 2)"
    } while ($scopeChoice -ne "1" -and $scopeChoice -ne "2")

    if ($scopeChoice -eq "1") { $Scope = "Global" }
    else { $Scope = "Folder" }
}

$TargetFolder = ""
if ($Scope -eq "Folder") {
    if ($Path) {
        $TargetFolder = $Path
    } else {
        Write-Host "`r`nUninstalling locally from a specific workspace folder..." -ForegroundColor Cyan
        $TargetFolder = Read-Host "Enter target folder path (default: .)"
        if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
            $TargetFolder = "."
        }
    }
    $TargetFolder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetFolder)
}

# 2. Resolve target directories
if ($Scope -eq "Folder") {
    $AgentsSkillsDir = Join-Path $TargetFolder ".agents\skills"
    $ClaudeSkillsDir = Join-Path $TargetFolder ".claude\skills"
} else {
    $AgentsSkillsDir = Join-Path $env:USERPROFILE ".agents\skills"
    $ClaudeSkillsDir = Join-Path $env:USERPROFILE ".claude\skills"
}

# 3. Discover installed skills
$InstalledSkills = @()
if (Test-Path $AgentsSkillsDir) {
    $InstalledSkills += Get-ChildItem -Directory -Path $AgentsSkillsDir | ForEach-Object { $_.Name }
}
if (Test-Path $ClaudeSkillsDir) {
    $InstalledSkills += Get-ChildItem -Directory -Path $ClaudeSkillsDir | ForEach-Object { $_.Name }
}
$InstalledSkills = $InstalledSkills | Select-Object -Unique

if ($InstalledSkills.Count -eq 0) {
    Write-Host "No skills found installed in this scope." -ForegroundColor Yellow
    exit 0
}

# 4. Determine which skills to uninstall
$SelectedSkills = @()
if ($Skills) {
    $SelectedSkills = $Skills.Split(",") | ForEach-Object { $_.Trim() }
} else {
    if ($InstalledSkills.Count -gt 1) {
        Write-Host "`r`nInstalled Skills found in scope:" -ForegroundColor Cyan
        Write-Host "[1] ALL"
        for ($i = 0; $i -lt $InstalledSkills.Count; $i++) {
            Write-Host "[$($i + 2)] $($InstalledSkills[$i])"
        }
        Write-Host "Select skills to uninstall (comma-separated numbers, or press Enter for ALL):"
        $skillsChoice = Read-Host "Choice"
        if (-not [string]::IsNullOrWhiteSpace($skillsChoice)) {
            $indices = $skillsChoice.Split(",") | ForEach-Object { [int]$_.Trim() }
            if ($indices -contains 1) {
                $SelectedSkills = $InstalledSkills
            } else {
                foreach ($idx in $indices) {
                    $realIdx = $idx - 2
                    if ($realIdx -ge 0 -and $realIdx -lt $InstalledSkills.Count) {
                        $SelectedSkills += $InstalledSkills[$realIdx]
                    }
                }
            }
        } else {
            $SelectedSkills = $InstalledSkills
        }
    } else {
        $SelectedSkills = $InstalledSkills
    }
}

if ($SelectedSkills.Count -eq 0) {
    Write-Host "No skills selected for uninstallation."
    exit 0
}

# 5. Remove the skills
foreach ($SkillName in $SelectedSkills) {
    $AgentsPath = Join-Path $AgentsSkillsDir $SkillName
    $ClaudePath = Join-Path $ClaudeSkillsDir $SkillName
    
    if (Test-Path $AgentsPath) {
        Remove-Item $AgentsPath -Recurse -Force
        Write-Host "[-] Uninstalled: $SkillName from Agents (Shared)" -ForegroundColor Yellow
    }
    if (Test-Path $ClaudePath) {
        Remove-Item $ClaudePath -Recurse -Force
        Write-Host "[-] Uninstalled: $SkillName from Claude" -ForegroundColor Yellow
    }
}

Write-Host "`r`nDone! Selected skills successfully uninstalled." -ForegroundColor Cyan
