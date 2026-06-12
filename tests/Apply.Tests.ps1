BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:repoRoot "scripts\Cas.Workstation.psm1") -Force
    $script:root = Join-Path $TestDrive "cas"
    $script:config = Join-Path $script:root "config"
    $script:plan = [pscustomobject]@{
        schemaVersion = "1.0.0"
        planId = "sha256:$('a' * 64)"
        correlationId = "sha256:$('a' * 64)"
        mode = "repair"
        profile = "core"
        rootPath = $script:root
        configPath = $script:config
        desiredStateDigest = "sha256:$('b' * 64)"
        operations = @(
            [pscustomobject]@{ id = "repo:one"; kind = "repository"; target = (Join-Path $script:root one); risk = "medium"; action = "update"; command = "git fetch"; source = "https://example.invalid/one.git"; reason = "drift"; defaultBranch = "main" },
            [pscustomobject]@{ id = "tool:done"; kind = "tool"; target = "done"; risk = "low"; action = "skip"; command = "none"; source = "inventory"; reason = "satisfied" }
        )
    }
}

Describe "CAS journaled plan apply" {
    It "persists correlated success and skip outcomes" {
        $journal = Invoke-CasOperationPlan -Plan $script:plan -ConfigPath $script:config -MaxRetries 0 -OperationHandler { param($operation) }
        $paths = Get-CasOperationFilePaths -Plan $script:plan -ConfigPath $script:config
        $events = @(Get-Content $paths.events | ForEach-Object { $_ | ConvertFrom-Json })

        $journal.status | Should -Be "succeeded"
        $journal.operations.status | Should -Contain "succeeded"
        $journal.operations.status | Should -Contain "skipped"
        @($events.correlationId | Sort-Object -Unique).Count | Should -Be 1
        $events.outcome | Should -Contain "succeeded"
    }

    It "stops after bounded failure and leaves actionable durable guidance" {
        $journal = Invoke-CasOperationPlan -Plan $script:plan -ConfigPath (Join-Path $script:root failure) -MaxRetries 1 -OperationHandler { param($operation) throw "synthetic failure" }

        $journal.status | Should -Be "failed"
        $journal.operations[0].attempts | Should -Be 2
        $journal.operations[0].guidance | Should -Match "resume"
        $journal.operations[1].status | Should -Be "pending"
    }

    It "resumes failed work without replaying completed work" {
        $config = Join-Path $script:root resume
        $script:attempts = 0
        $failed = Invoke-CasOperationPlan -Plan $script:plan -ConfigPath $config -MaxRetries 0 -OperationHandler { param($operation) $script:attempts++; throw "first failure" }
        $resumed = Invoke-CasOperationPlan -Plan $script:plan -ConfigPath $config -MaxRetries 0 -Resume -OperationHandler { param($operation) $script:attempts++ }

        $failed.status | Should -Be "failed"
        $resumed.status | Should -Be "succeeded"
        $script:attempts | Should -Be 2
    }
}
