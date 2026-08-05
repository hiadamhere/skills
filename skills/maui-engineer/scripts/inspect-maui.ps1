[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = "."
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path

function Get-RelativePath {
    param([string]$BasePath, [string]$TargetPath)
    $base = [Uri]((Join-Path ([IO.Path]::GetFullPath($BasePath)) '.') + [IO.Path]::DirectorySeparatorChar)
    $target = [Uri][IO.Path]::GetFullPath($TargetPath)
    return [Uri]::UnescapeDataString($base.MakeRelativeUri($target).ToString()).Replace('/', [IO.Path]::DirectorySeparatorChar)
}

function Invoke-DotNetText {
    param([string[]]$Arguments)
    try {
        $output = & dotnet @Arguments 2>&1
        return (($output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
    }
    catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

$globalJson = Get-ChildItem -LiteralPath $root -Filter global.json -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object FullName |
    Select-Object -First 1

$projects = foreach ($project in Get-ChildItem -LiteralPath $root -Filter *.csproj -File -Recurse -ErrorAction SilentlyContinue) {
    if ($project.FullName -match '[\\/](bin|obj)[\\/]') { continue }
    try {
        [xml]$xml = Get-Content -LiteralPath $project.FullName -Raw
        $properties = @($xml.Project.PropertyGroup)
        $packages = @($xml.Project.ItemGroup.PackageReference)
        [pscustomobject]@{
            Path = Get-RelativePath $root $project.FullName
            UseMaui = [string](($properties.UseMaui | Where-Object { $_ } | Select-Object -Last 1))
            TargetFramework = [string](($properties.TargetFramework | Where-Object { $_ } | Select-Object -Last 1))
            TargetFrameworks = [string](($properties.TargetFrameworks | Where-Object { $_ } | Select-Object -Last 1))
            MauiPackages = @($packages | Where-Object { $_.Include -like 'Microsoft.Maui*' } | ForEach-Object {
                [pscustomobject]@{ Name = [string]$_.Include; Version = [string]$_.Version }
            })
        }
    }
    catch {
        [pscustomobject]@{ Path = Get-RelativePath $root $project.FullName; ParseError = $_.Exception.Message }
    }
}

$globalJsonData = $null
if ($globalJson) {
    try { $globalJsonData = Get-Content -LiteralPath $globalJson.FullName -Raw | ConvertFrom-Json }
    catch { $globalJsonData = [pscustomobject]@{ ParseError = $_.Exception.Message } }
}

[pscustomobject]@{
    Root = $root
    DotNetVersion = Invoke-DotNetText @('--version')
    DotNetInfo = Invoke-DotNetText @('--info')
    Workloads = Invoke-DotNetText @('workload', 'list')
    GlobalJsonPath = if ($globalJson) { Get-RelativePath $root $globalJson.FullName } else { $null }
    GlobalJson = $globalJsonData
    Projects = @($projects)
} | ConvertTo-Json -Depth 8
