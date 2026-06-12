BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:repoRoot "scripts\Cas.Workstation.psm1") -Force
    $script:manifest = Get-CasManifest
    $script:root = Join-Path $TestDrive cas
    $script:config = Join-Path $script:root config
    $script:inventory = [pscustomobject]@{ resources = @() }
}

Describe "CAS shared operational workflow" {
    It "uses the same deterministic planner for setup upgrade and repair" {
        foreach ($mode in @("setup", "upgrade", "repair")) {
            $plan = Invoke-CasWorkstationOperation -Mode $mode -Profile core -RootPath $script:root -ConfigPath $script:config -Inventory $script:inventory -Manifest $script:manifest
            $plan.mode | Should -Be $mode
            $plan.operations.Count | Should -BeGreaterThan 0
        }
    }

    It "keeps preview free of filesystem mutations" {
        $null = Invoke-CasWorkstationOperation -Mode setup -Profile core -RootPath $script:root -ConfigPath $script:config -Inventory $script:inventory -Manifest $script:manifest
        Test-Path $script:root | Should -BeFalse
    }

    It "declares the public golden-path repositories in the full profile" {
        $resolved = Resolve-CasDesiredState -Profile full -Manifest $script:manifest
        $ids = @($resolved.desiredState.resources | Where-Object category -eq repos | ForEach-Object id)
        foreach ($id in @("cas-platform", "cas-contracts", "cas-evals", "cas-reference-product")) {
            $ids | Should -Contain $id
        }
    }

    It "resumes the latest persisted failed plan through the shared workflow" {
        $config = Join-Path $script:root recovery
        $failed = Invoke-CasWorkstationOperation -Mode repair -Profile core -RootPath $script:root -ConfigPath $config -Inventory $script:inventory -Manifest $script:manifest -Apply -OperationHandler { param($operation) throw "synthetic" }
        $resumed = Invoke-CasWorkstationOperation -Mode repair -Profile core -RootPath $script:root -ConfigPath $config -Manifest $script:manifest -Apply -Resume -OperationHandler { param($operation) }

        $failed.status | Should -Be "failed"
        $resumed.status | Should -Be "succeeded"
    }
}
