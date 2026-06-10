[CmdletBinding()]
param(
    [ValidateSet("core", "full")]
    [string]$Profile = "full",
    [string]$RootPath,
    [string]$ConfigPath,
    [string]$JsonPath
)

$ErrorActionPreference = "Stop"
$env:USERPROFILE = "C:\Users\KimHarjamaki"
$env:HOME = "C:\Users\KimHarjamaki"
$env:AZURE_CONFIG_DIR = "C:\Users\KimHarjamaki\.azure"

Import-Module (Join-Path $PSScriptRoot "scripts\Cas.Workstation.psm1") -Force

$manifest = Get-CasManifest
if (-not $RootPath) { $RootPath = Get-CasDefaultRootPath -Manifest $manifest }
if (-not $ConfigPath) { $ConfigPath = Get-CasDefaultConfigPath -Manifest $manifest }

$report = Get-CasDoctorReport -Profile $Profile -RootPath $RootPath -ConfigPath $ConfigPath -Manifest $manifest
Write-CasDoctorReport -Report $report -JsonPath $JsonPath | Out-Null

Write-Host ""
Write-Host "CAS Workstation doctor"
Write-Host "Overall status: $($report.overallStatus)"
Write-Host ""
Write-Host "Tools:"
foreach ($tool in $report.tools) {
    $displayVersion = if ($tool.installedVersion) { $tool.installedVersion } else { "n/a" }
    Write-Host (" - {0}: {1} ({2})" -f $tool.displayName, $tool.status, $displayVersion)
}

Write-Host ""
Write-Host "Services:"
foreach ($service in $report.services) {
    Write-Host (" - {0}: {1}" -f $service.id, $service.message)
}

Write-Host ""
Write-Host "Repos:"
foreach ($repo in $report.repos) {
    Write-Host (" - {0}: {1}" -f $repo.id, $repo.status)
}

if ($report.recommendations.Count -gt 0) {
    Write-Host ""
    Write-Host "Recommendations:"
    foreach ($message in $report.recommendations) {
        Write-Host " - $message"
    }
}
