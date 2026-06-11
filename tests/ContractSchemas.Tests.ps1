BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:validator = Join-Path $script:repoRoot "scripts\Test-CasJsonSchema.ps1"
}

Describe "CAS JSON contract schemas" {
    It "validates all positive and negative fixtures" {
        { & $script:validator -AllFixtures } | Should -Not -Throw
    }

    It "fails closed for a missing schema" {
        $fixture = Join-Path $PSScriptRoot "fixtures\contracts\doctor.valid.json"
        { & $script:validator -SchemaPath "missing.schema.json" -InstancePath $fixture 2>$null } | Should -Throw
    }

    It "contains a positive and negative fixture for every schema" {
        $schemaNames = Get-ChildItem (Join-Path $script:repoRoot "schemas\*.schema.json") |
            ForEach-Object { $_.BaseName -replace "\.schema$", "" }
        foreach ($name in $schemaNames) {
            (Test-Path (Join-Path $PSScriptRoot "fixtures\contracts\$name.valid.json")) | Should -BeTrue
            (Test-Path (Join-Path $PSScriptRoot "fixtures\contracts\$name.invalid.json")) | Should -BeTrue
        }
    }
}
