[CmdletBinding()]
param(
    [ValidateSet("core", "full")]
    [string]$Profile = "full",
    [switch]$NonInteractive,
    [string]$RootPath,
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"
$env:USERPROFILE = "C:\Users\KimHarjamaki"
$env:HOME = "C:\Users\KimHarjamaki"
$env:AZURE_CONFIG_DIR = "C:\Users\KimHarjamaki\.azure"

Import-Module (Join-Path $PSScriptRoot "scripts\Cas.Workstation.psm1") -Force

$manifest = Get-CasManifest
if (-not $RootPath) { $RootPath = Get-CasDefaultRootPath -Manifest $manifest }
if (-not $ConfigPath) { $ConfigPath = Get-CasDefaultConfigPath -Manifest $manifest }

Write-Host "CAS Workstation setup"
Write-Host "Profile: $Profile"
Write-Host "RootPath: $RootPath"
Write-Host "ConfigPath: $ConfigPath"

New-CasDirectoryLayout -RootPath $RootPath -ConfigPath $ConfigPath -Manifest $manifest

foreach ($tool in Get-CasProfileToolDefinitions -Profile $Profile -Manifest $manifest) {
    Install-CasTool -Tool $tool
}

foreach ($repo in Get-CasProfileRepos -Profile $Profile -Manifest $manifest) {
    Sync-CasRepo -Repo $repo -RootPath $RootPath -Manifest $manifest
}

New-CasClientConfigs -ConfigPath $ConfigPath -RootPath $RootPath -Manifest $manifest

$doctorPath = Join-Path $ConfigPath "config\doctor.post-setup.json"
$report = Get-CasDoctorReport -Profile $Profile -RootPath $RootPath -ConfigPath $ConfigPath -Manifest $manifest
Write-CasDoctorReport -Report $report -JsonPath $doctorPath | Out-Null

if ($report.overallStatus -eq "ready") {
    Write-Host "CAS Workstation setup completed and the workstation is ready."
}
else {
    Write-Warning "Setup completed with follow-up actions. Run .\doctor.ps1 for details."
}
