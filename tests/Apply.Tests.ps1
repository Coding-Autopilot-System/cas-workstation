BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:repoRoot "scripts\Cas.Workstation.psm1") -Force
    $script:root = Join-Path $TestDrive "cas"
    $script:config = Join-Path $script:root "config"
    $script:plan = [pscustomobject]@{
        schemaVersion = "1.0.0"
        planId = $null
        correlationId = $null
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
    $identity = [ordered]@{
        schemaVersion = $script:plan.schemaVersion
        mode = $script:plan.mode
        profile = $script:plan.profile
        rootPath = $script:plan.rootPath
        configPath = $script:plan.configPath
        desiredStateDigest = $script:plan.desiredStateDigest
        operations = $script:plan.operations
    }
    $script:plan.planId = Get-CasSha256 -Value (ConvertTo-CasCanonicalJson -InputObject $identity)
    $script:plan.correlationId = $script:plan.planId
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

    It "rejects a plan changed after integrity identity was assigned" {
        $tampered = $script:plan | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $tampered.operations[0].source = "https://example.invalid/tampered.git"

        { Invoke-CasOperationPlan -Plan $tampered -ConfigPath (Join-Path $script:root tampered) -OperationHandler { param($operation) } } | Should -Throw "*integrity*"
    }

    It "applies a typed client operation and records owned-content evidence" {
        $manifest = Get-CasManifest
        $config = Join-Path $script:root client-apply
        $client = $manifest.clients | Where-Object id -eq codex
        $target = Get-CasClientTarget -Client $client -ConfigPath $config -Manifest $manifest
        $operation = [pscustomobject]@{
            id = "client:codex"; kind = "configuration"; resourceCategory = "client"; adapter = "json-mcp"
            ownershipKey = $client.ownershipKey; target = $target; risk = "medium"; action = "create"
            command = "merge CAS-owned MCP configuration"; source = "manifest:sharedMcpServer"; reason = "missing"
            desiredDigest = Get-CasSha256 -Value (ConvertTo-CasCanonicalJson -InputObject (Get-CasDesiredMcpNode -Manifest $manifest))
        }
        $plan = [pscustomobject]@{
            schemaVersion = "1.0.0"; planId = $null; correlationId = $null; mode = "setup"; profile = "core"
            rootPath = $script:root; configPath = $config; desiredStateDigest = "sha256:$('c' * 64)"; operations = @($operation)
        }
        $identity = [ordered]@{ schemaVersion = $plan.schemaVersion; mode = $plan.mode; profile = $plan.profile; rootPath = $plan.rootPath; configPath = $plan.configPath; desiredStateDigest = $plan.desiredStateDigest; operations = $plan.operations }
        $plan.planId = Get-CasSha256 -Value (ConvertTo-CasCanonicalJson -InputObject $identity)
        $plan.correlationId = $plan.planId

        $journal = Invoke-CasOperationPlan -Plan $plan -ConfigPath $config -Manifest $manifest
        $state = Read-CasManagedState -Path (Get-CasManagedStatePath -ConfigPath $config -Manifest $manifest)

        $journal.status | Should -Be "succeeded"
        $state.resources[0].id | Should -Be "client:codex"
        $state.resources[0].contentDigest | Should -Be $operation.desiredDigest
    }
}
