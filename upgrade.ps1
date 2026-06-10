[CmdletBinding()]
param(
    [ValidateSet("core", "full")]
    [string]$Profile = "full",
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

New-CasDirectoryLayout -RootPath $RootPath -ConfigPath $ConfigPath -Manifest $manifest

foreach ($repo in Get-CasProfileRepos -Profile $Profile -Manifest $manifest) {
    Sync-CasRepo -Repo $repo -RootPath $RootPath -Manifest $manifest
}

New-CasClientConfigs -ConfigPath $ConfigPath -RootPath $RootPath -Manifest $manifest

Write-Host "CAS Workstation upgrade completed."
