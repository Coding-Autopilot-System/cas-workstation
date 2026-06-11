[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [string]$RootPath,
    [string]$ConfigPath,
    [string]$StatePath,
    [switch]$Apply
)

$ErrorActionPreference = "Stop"
$env:USERPROFILE = "C:\Users\KimHarjamaki"
$env:HOME = "C:\Users\KimHarjamaki"
$env:AZURE_CONFIG_DIR = "C:\Users\KimHarjamaki\.azure"

Import-Module (Join-Path $PSScriptRoot "scripts\Cas.Workstation.psm1") -Force

$manifest = Get-CasManifest
if (-not $RootPath) { $RootPath = Get-CasDefaultRootPath -Manifest $manifest }
if (-not $ConfigPath) { $ConfigPath = Get-CasDefaultConfigPath -Manifest $manifest }
if (-not $StatePath) { $StatePath = Get-CasManagedStatePath -ConfigPath $ConfigPath -Manifest $manifest }

$approvedRoots = @($RootPath, $ConfigPath)
$preview = Get-CasUninstallPreview -StatePath $StatePath -ApprovedRoots $approvedRoots
$preview.actions | Format-Table id, ownership, action, target -AutoSize

if (-not $Apply) {
    Write-Host "Preview only. Re-run with -Apply to request removal of ledger-owned resources."
    return
}

if ($PSCmdlet.ShouldProcess("$(@($preview.actions | Where-Object actionable).Count) ledger-owned resource(s)", "Apply CAS Workstation uninstall")) {
    Invoke-CasUninstall -Preview $preview -ApprovedRoots $approvedRoots -Confirm:$false | Out-Null
    Write-Host "CAS Workstation uninstall apply completed."
}
