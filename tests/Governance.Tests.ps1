BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:validator = Join-Path $script:repoRoot "scripts\Test-CasGovernance.ps1"
}

Describe "CAS governance traceability" {
    It "maps every v1 requirement exactly once" {
        $result = & $script:validator
        $result.requirementCount | Should -Be 35
    }

    It "rejects duplicate requirement IDs" {
        $source = Get-Content (Join-Path $script:repoRoot "docs\traceability.json") -Raw | ConvertFrom-Json
        $source.requirements += $source.requirements[0]
        $temp = Join-Path $TestDrive "duplicate.json"
        $source | ConvertTo-Json -Depth 10 | Set-Content $temp -Encoding UTF8
        { & $script:validator -TraceabilityPath $temp } | Should -Throw "*Duplicate*"
    }

    It "rejects missing referenced evidence files" {
        $source = Get-Content (Join-Path $script:repoRoot "docs\traceability.json") -Raw | ConvertFrom-Json
        $source.requirements[0].tests = @("tests/missing.Tests.ps1")
        $temp = Join-Path $TestDrive "missing-reference.json"
        $source | ConvertTo-Json -Depth 10 | Set-Content $temp -Encoding UTF8
        { & $script:validator -TraceabilityPath $temp } | Should -Throw "*missing file*"
    }
}
