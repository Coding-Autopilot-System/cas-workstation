[CmdletBinding()]
param(
    [ValidateSet("core", "full")]
    [string]$Profile = "full",
    [string]$RootPath
)

$ErrorActionPreference = "Stop"
$env:USERPROFILE = "C:\Users\KimHarjamaki"
$env:HOME = "C:\Users\KimHarjamaki"
$env:AZURE_CONFIG_DIR = "C:\Users\KimHarjamaki\.azure"

Import-Module (Join-Path $PSScriptRoot "scripts\Cas.Workstation.psm1") -Force

$manifest = Get-CasManifest
if (-not $RootPath) { $RootPath = Get-CasDefaultRootPath -Manifest $manifest }

Start-CasRuntime -Profile $Profile -RootPath $RootPath -Manifest $manifest

Write-Host "CAS Workstation runtime checks completed."
Write-Host "Use .\doctor.ps1 if you need a full readiness report."
