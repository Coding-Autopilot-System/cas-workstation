[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [string]$RootPath,
    [string]$ConfigPath,
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
$env:USERPROFILE = "C:\Users\KimHarjamaki"
$env:HOME = "C:\Users\KimHarjamaki"
$env:AZURE_CONFIG_DIR = "C:\Users\KimHarjamaki\.azure"

Import-Module (Join-Path $PSScriptRoot "scripts\Cas.Workstation.psm1") -Force
$manifest = Get-CasManifest
if (-not $RootPath) { $RootPath = Get-CasDefaultRootPath -Manifest $manifest }
if (-not $ConfigPath) { $ConfigPath = Get-CasDefaultConfigPath -Manifest $manifest }

$targets = @($RootPath, $ConfigPath | ForEach-Object { Assert-CasSafeManagedPath -Path $_ })
if ($targets[0] -eq $targets[1] -or $targets[0].StartsWith($targets[1] + '\', [System.StringComparison]::OrdinalIgnoreCase) -or $targets[1].StartsWith($targets[0] + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "RootPath and ConfigPath must be separate, non-nested managed directories."
}
foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target)) { continue }
    if (-not (Test-CasManagedDirectory -Path $target -Manifest $manifest)) { throw "Refusing to remove unowned directory '$target'." }
    if (-not $Execute) { Write-Host "[preview] Would remove CAS managed directory: $target"; continue }
    if ($PSCmdlet.ShouldProcess($target, "Remove CAS Workstation managed directory")) { Remove-Item -LiteralPath $target -Recurse -Force }
}
Write-Host $(if ($Execute) { "CAS Workstation uninstall completed." } else { "CAS Workstation uninstall preview completed. Re-run with -Execute to remove managed directories." })