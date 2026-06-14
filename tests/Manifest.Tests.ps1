BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:repoRoot "scripts\Cas.Workstation.psm1") -Force
    $script:manifestPath = Join-Path $script:repoRoot "stack.manifest.json"
}

Describe "CAS manifest validation and resolution" {
    It "loads the repository manifest only after semantic validation" {
        $manifest = Get-CasManifest -Path $script:manifestPath
        $manifest.bundleId | Should -Be "cas-workstation"
    }

    It "rejects an unallowlisted command before invoking it" {
        $manifest = Get-Content $script:manifestPath -Raw | ConvertFrom-Json
        $manifest.tools[0].command = "malicious.exe"

        { Assert-CasManifest -Manifest $manifest } | Should -Throw "*unallowlisted command*"
    }

    It "rejects unknown profile references" {
        $manifest = Get-Content $script:manifestPath -Raw | ConvertFrom-Json
        $manifest.profiles.core.tools.required += "unknown-tool"

        { Assert-CasManifest -Manifest $manifest } | Should -Throw "*unknown tools id*"
    }

    It "rejects untrusted repository origins" {
        $manifest = Get-Content $script:manifestPath -Raw | ConvertFrom-Json
        $manifest.repos[0].url = "https://example.invalid/repository.git"

        { Assert-CasManifest -Manifest $manifest } | Should -Throw "*unallowlisted URL*"
    }

    It "rejects unsafe managed-tree sources and secret-like MCP auth values" {
        $manifest = Get-Content $script:manifestPath -Raw | ConvertFrom-Json
        $manifest.skills[0].sourceRelativePath = "..\escape"
        { Assert-CasManifest -Manifest $manifest } | Should -Throw "*unsafe relative path*"

        $manifest = Get-Content $script:manifestPath -Raw | ConvertFrom-Json
        $manifest.sharedMcpServer.authReference = "Bearer real-token"
        { Assert-CasManifest -Manifest $manifest } | Should -Throw "*environment reference*"
    }

    It "keeps local and production MCP transport boundaries explicit" {
        $manifest = Get-Content $script:manifestPath -Raw | ConvertFrom-Json
        $manifest.sharedMcpServer.transport = "http"
        { Assert-CasManifest -Manifest $manifest } | Should -Throw "*Local workstation MCP servers must use stdio*"
    }

    It "resolves every declarative category with explicit requirement level" {
        $resolved = Resolve-CasDesiredState -Profile core
        @($resolved.desiredState.resources.category | Sort-Object -Unique) | Should -Be @("clients", "repos", "services", "skills", "tools", "workspaces")
        @($resolved.desiredState.resources | Where-Object required).Count | Should -BeGreaterThan 0
        @($resolved.desiredState.resources | Where-Object { -not $_.required }).Count | Should -BeGreaterThan 0
    }

    It "produces a deterministic canonical desired-state digest" {
        $first = Resolve-CasDesiredState -Profile full
        $second = Resolve-CasDesiredState -Profile full

        $first.canonicalJson | Should -BeExactly $second.canonicalJson
        $first.digest | Should -BeExactly $second.digest
        $first.digest | Should -Match "^sha256:[a-f0-9]{64}$"
    }

    It "returns structured fail-closed compatibility evidence" {
        $report = Get-CasCompatibilityReport -Profile core

        $report.checks.id | Should -Contain "host-os"
        $report.checks.id | Should -Contain "powershell"
        $report.checks.id | Should -Contain "architecture"
        ($report.compatible -eq (@($report.checks | Where-Object { $_.required -and $_.status -ne "supported" }).Count -eq 0)) | Should -BeTrue
    }
}
