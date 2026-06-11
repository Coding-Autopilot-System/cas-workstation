[CmdletBinding()]
param(
    [string]$TraceabilityPath,
    [string]$RequirementsPath
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $TraceabilityPath) { $TraceabilityPath = Join-Path $repoRoot "docs\traceability.json" }
if (-not $RequirementsPath) { $RequirementsPath = Join-Path $repoRoot ".planning\REQUIREMENTS.md" }

foreach ($path in @($TraceabilityPath, $RequirementsPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required governance input is missing: $path"
    }
}

$traceability = Get-Content -LiteralPath $TraceabilityPath -Raw | ConvertFrom-Json
$requirementsContent = Get-Content -LiteralPath $RequirementsPath -Raw
$v2Index = $requirementsContent.IndexOf("## v2 Requirements")
$v1Content = if ($v2Index -ge 0) { $requirementsContent.Substring(0, $v2Index) } else { $requirementsContent }
$requirementIds = @([regex]::Matches($v1Content, '\*\*([A-Z]+-\d{2})\*\*:') | ForEach-Object { $_.Groups[1].Value })
$entries = @($traceability.requirements)
$entryIds = @($entries | ForEach-Object { $_.id })

$duplicates = @($entryIds | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
if ($duplicates.Count -gt 0) {
    throw "Duplicate traceability requirement IDs: $($duplicates -join ', ')"
}

$missing = @($requirementIds | Where-Object { $_ -notin $entryIds })
$unknown = @($entryIds | Where-Object { $_ -notin $requirementIds })
if ($missing.Count -gt 0 -or $unknown.Count -gt 0) {
    throw "Traceability mismatch. Missing: $($missing -join ', '); Unknown: $($unknown -join ', ')"
}

foreach ($entry in $entries) {
    if (-not $entry.phase -or $entry.phase -lt 1 -or $entry.phase -gt 7) {
        throw "Requirement '$($entry.id)' has invalid phase '$($entry.phase)'."
    }
    if ($entry.status -notin @("pending", "planned", "verified")) {
        throw "Requirement '$($entry.id)' has invalid status '$($entry.status)'."
    }
    foreach ($reference in @($entry.adrs) + @($entry.tests)) {
        if ([string]::IsNullOrWhiteSpace([string]$reference)) {
            continue
        }
        if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $reference) -PathType Leaf)) {
            throw "Requirement '$($entry.id)' references missing file '$reference'."
        }
    }
}

[pscustomobject]@{
    schemaVersion = $traceability.schemaVersion
    requirementCount = $entries.Count
    verifiedCount = @($entries | Where-Object status -eq "verified").Count
}
