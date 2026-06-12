[CmdletBinding()]
param(
    [ValidateSet("core", "full")][string]$Profile = "full",
    [switch]$NonInteractive,
    [switch]$Apply,
    [switch]$Resume,
    [string]$RootPath,
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"
$env:USERPROFILE = "C:\Users\KimHarjamaki"
$env:HOME = "C:\Users\KimHarjamaki"
$env:AZURE_CONFIG_DIR = "C:\Users\KimHarjamaki\.azure"
Import-Module (Join-Path $PSScriptRoot "scripts\Cas.Workstation.psm1") -Force

$result = Invoke-CasWorkstationOperation -Mode repair -Profile $Profile -RootPath $RootPath -ConfigPath $ConfigPath -Apply:$Apply -Resume:$Resume
$result | ConvertTo-Json -Depth 30
