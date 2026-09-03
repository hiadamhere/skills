[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = "."
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path

# Plain string arithmetic, deliberately not [Uri].MakeRelativeUri: a Windows path ("C:\repo") parses as
# an ABSOLUTE uri because of the drive letter, but a Unix path ("/home/user/repo") has no scheme and
# parses as a RELATIVE one, so MakeRelativeUri threw "This operation is not supported for a relative URI"
# on every Linux and macOS run -- which for a MAUI tool means the platform iOS builds happen on.
function Get-RelativePath {
    param([string]$BasePath, [string]$TargetPath)
    $sep = [IO.Path]::DirectorySeparatorChar
    $base = [IO.Path]::GetFullPath($BasePath).TrimEnd($sep, [IO.Path]::AltDirectorySeparatorChar) + $sep
    $target = [IO.Path]::GetFullPath($TargetPath)
    # Windows paths are case-insensitive, Unix paths are not; comparing case-insensitively on Unix would
    # collapse two genuinely different directories.
    $comparison = if ($IsWindows -eq $false) { [StringComparison]::Ordinal } else { [StringComparison]::OrdinalIgnoreCase }
    if ($target.StartsWith($base, $comparison)) { return $target.Substring($base.Length) }
    return $target
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

# Read a property by element name. local-name() keeps this working whether or not
# the project declares the legacy MSBuild namespace, and reading InnerText rather
# than the dotted property path is what makes a CONDITIONED element readable --
# PowerShell hands back an XmlElement there, whose ToString() is the type name.
function Get-MsBuildPropertyList {
    param([xml]$Xml, [string]$Name)
    $nodes = $Xml.SelectNodes("//*[local-name()='PropertyGroup']/*[local-name()='$Name']")
    foreach ($node in $nodes) {
        [pscustomobject]@{
            Value     = $node.InnerText.Trim()
            Condition = [string]$node.GetAttribute('Condition')
        }
    }
}

# Last unconditioned value wins, mirroring MSBuild's own last-write-wins. This is
# a snapshot, not an MSBuild evaluation: conditions are NOT evaluated, so when a
# property is only ever set under a condition the value is returned with that
# condition attached rather than as a bare value -- reporting it bare would claim
# a setting that may not apply, and returning nothing would hide that it exists.
function Get-MsBuildProperty {
    param([xml]$Xml, [string]$Name)
    $all = @(Get-MsBuildPropertyList -Xml $Xml -Name $Name)
    if ($all.Count -eq 0) { return "" }
    $plain = @($all | Where-Object { -not $_.Condition })
    if ($plain.Count -gt 0) { return $plain[-1].Value }
    return "$($all[-1].Value) (when: $($all[-1].Condition))"
}

$globalJson = Get-ChildItem -LiteralPath $root -Filter global.json -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object FullName |
    Select-Object -First 1

$projects = foreach ($project in Get-ChildItem -LiteralPath $root -Filter *.csproj -File -Recurse -ErrorAction SilentlyContinue) {
    if ($project.FullName -match '[\\/](bin|obj)[\\/]') { continue }
    try {
        [xml]$xml = Get-Content -LiteralPath $project.FullName -Raw
        $packages = @($xml.Project.ItemGroup.PackageReference)
        [pscustomobject]@{
            Path = Get-RelativePath $root $project.FullName
            UseMaui = Get-MsBuildProperty -Xml $xml -Name 'UseMaui'
            MauiVersion = Get-MsBuildProperty -Xml $xml -Name 'MauiVersion'
            TargetFramework = Get-MsBuildProperty -Xml $xml -Name 'TargetFramework'
            TargetFrameworks = Get-MsBuildProperty -Xml $xml -Name 'TargetFrameworks'
            # Per-TFM in every MAUI template, so the condition is the useful half:
            # a bare value here would hide which platform each floor applies to.
            SupportedOSPlatformVersions = @(Get-MsBuildPropertyList -Xml $xml -Name 'SupportedOSPlatformVersion')
            TargetPlatformMinVersions = @(Get-MsBuildPropertyList -Xml $xml -Name 'TargetPlatformMinVersion')
            RuntimeIdentifiers = @(
                (Get-MsBuildPropertyList -Xml $xml -Name 'RuntimeIdentifier') +
                (Get-MsBuildPropertyList -Xml $xml -Name 'RuntimeIdentifiers')
            )
            # With central package management the Version attribute is absent here;
            # the pinned number then lives in Directory.Packages.props below.
            MauiPackages = @($packages | Where-Object { $_.Include -like 'Microsoft.Maui*' } | ForEach-Object {
                [pscustomobject]@{ Name = [string]$_.Include; Version = [string]$_.Version; VersionOverride = [string]$_.VersionOverride }
            })
        }
    }
    catch {
        [pscustomobject]@{ Path = Get-RelativePath $root $project.FullName; ParseError = $_.Exception.Message }
    }
}

# MSBuild-imported files that commonly carry the real version pins: MauiVersion /
# UseMaui in Directory.Build.props, central PackageVersion items in
# Directory.Packages.props. Projects only show what these files decide.
$buildProps = foreach ($file in Get-ChildItem -LiteralPath $root -Filter Directory.Build.props -File -Recurse -ErrorAction SilentlyContinue) {
    if ($file.FullName -match '[\\/](bin|obj)[\\/]') { continue }
    try {
        [xml]$xml = Get-Content -LiteralPath $file.FullName -Raw
        [pscustomobject]@{
            Path = Get-RelativePath $root $file.FullName
            UseMaui = Get-MsBuildProperty -Xml $xml -Name 'UseMaui'
            MauiVersion = Get-MsBuildProperty -Xml $xml -Name 'MauiVersion'
        }
    }
    catch {
        [pscustomobject]@{ Path = Get-RelativePath $root $file.FullName; ParseError = $_.Exception.Message }
    }
}

$packagesProps = foreach ($file in Get-ChildItem -LiteralPath $root -Filter Directory.Packages.props -File -Recurse -ErrorAction SilentlyContinue) {
    if ($file.FullName -match '[\\/](bin|obj)[\\/]') { continue }
    try {
        [xml]$xml = Get-Content -LiteralPath $file.FullName -Raw
        $versions = @($xml.Project.ItemGroup.PackageVersion)
        [pscustomobject]@{
            Path = Get-RelativePath $root $file.FullName
            ManagePackageVersionsCentrally = Get-MsBuildProperty -Xml $xml -Name 'ManagePackageVersionsCentrally'
            MauiPackageVersions = @($versions | Where-Object { $_.Include -like 'Microsoft.Maui*' } | ForEach-Object {
                [pscustomobject]@{ Name = [string]$_.Include; Version = [string]$_.Version }
            })
        }
    }
    catch {
        [pscustomobject]@{ Path = Get-RelativePath $root $file.FullName; ParseError = $_.Exception.Message }
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
    DirectoryBuildProps = @($buildProps)
    DirectoryPackagesProps = @($packagesProps)
    Projects = @($projects)
} | ConvertTo-Json -Depth 8
