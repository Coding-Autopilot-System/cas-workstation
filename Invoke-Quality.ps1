[CmdletBinding()]
param(
    [string]$ArtifactPath,
    [switch]$SkipTests,
    [switch]$SkipStaticAnalysis,
    [switch]$SkipContracts,
    [switch]$SkipGovernance
)

$ErrorActionPreference = "Stop"
if (-not $ArtifactPath) {
    $ArtifactPath = Join-Path $PSScriptRoot ".artifacts\quality"
}
$results = New-Object System.Collections.Generic.List[object]

function Add-QualityResult {
    param([string]$Name, [string]$Status, [string]$Detail)
    $results.Add([pscustomobject]@{ name = $Name; status = $Status; detail = $Detail })
}

function Invoke-QualityCheck {
    param([string]$Name, [scriptblock]$Action)
    try {
        & $Action
        Add-QualityResult -Name $Name -Status "passed" -Detail "Check passed."
    }
    catch {
        Add-QualityResult -Name $Name -Status "failed" -Detail $_.Exception.Message
    }
}

if (-not (Test-Path -LiteralPath $ArtifactPath)) {
    New-Item -ItemType Directory -Path $ArtifactPath -Force | Out-Null
}

if (-not $SkipTests) {
    Invoke-QualityCheck -Name "pester" -Action {
        Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
        $configuration = New-PesterConfiguration
        $configuration.Run.Path = Join-Path $PSScriptRoot "tests"
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = "Detailed"
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputPath = Join-Path $ArtifactPath "pester.xml"
        $testResult = Invoke-Pester -Configuration $configuration
        if ($testResult.FailedCount -gt 0) {
            throw "Pester reported $($testResult.FailedCount) failed test(s)."
        }
    }
}

if (-not $SkipStaticAnalysis) {
    Invoke-QualityCheck -Name "psscriptanalyzer" -Action {
        Import-Module PSScriptAnalyzer -MinimumVersion 1.20 -ErrorAction Stop
        $findings = @(Invoke-ScriptAnalyzer -Path $PSScriptRoot -Recurse -Settings (Join-Path $PSScriptRoot "PSScriptAnalyzerSettings.psd1"))
        $findings | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $ArtifactPath "psscriptanalyzer.json") -Encoding UTF8
        if ($findings.Count -gt 0) {
            throw "PSScriptAnalyzer reported $($findings.Count) blocking finding(s)."
        }
    }
}

if (-not $SkipContracts) {
    Invoke-QualityCheck -Name "contracts" -Action {
        & (Join-Path $PSScriptRoot "scripts\Test-CasJsonSchema.ps1") -AllFixtures
    }
}

if (-not $SkipGovernance) {
    Invoke-QualityCheck -Name "governance" -Action {
        & (Join-Path $PSScriptRoot "scripts\Test-CasGovernance.ps1") | Out-Null
        foreach ($required in @("README.md", "CONTRIBUTING.md", "docs\architecture\README.md", "docs\support-matrix.md")) {
            if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $required) -PathType Leaf)) {
                throw "Required documentation is missing: $required"
            }
        }
    }
}

$failed = @($results | Where-Object status -eq "failed")
$summary = [pscustomobject]@{
    schemaVersion = "1.0.0"
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    status = if ($failed.Count -eq 0) { "passed" } else { "failed" }
    checks = $results
}
$summaryPath = Join-Path $ArtifactPath "summary.json"
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if ($failed.Count -gt 0) {
    $details = $failed | ForEach-Object { "$($_.name): $($_.detail)" }
    throw "Quality gate failed. $($details -join '; ')"
}

Write-Output "Quality gate passed. Evidence: $summaryPath"
