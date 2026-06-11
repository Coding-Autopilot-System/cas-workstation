BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:quality = Join-Path $script:repoRoot "Invoke-Quality.ps1"
}

Describe "CAS quality command" {
    It "emits machine-readable evidence for a focused successful run" {
        $artifactPath = Join-Path $TestDrive "quality"
        & $script:quality -ArtifactPath $artifactPath -SkipTests -SkipStaticAnalysis -SkipContracts
        $summary = Get-Content (Join-Path $artifactPath "summary.json") -Raw | ConvertFrom-Json
        $summary.status | Should -Be "passed"
        @($summary.checks).Count | Should -Be 1
    }

    It "fails closed when a required governance file is absent" {
        $source = Join-Path $script:repoRoot "docs\architecture\README.md"
        $temporary = "$source.quality-test"
        Move-Item $source $temporary
        try {
            { & $script:quality -ArtifactPath (Join-Path $TestDrive "failed") -SkipTests -SkipStaticAnalysis -SkipContracts } | Should -Throw "*Quality gate failed*"
        }
        finally {
            Move-Item $temporary $source
        }
    }
}

