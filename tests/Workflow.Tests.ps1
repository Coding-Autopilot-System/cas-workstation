BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    $script:workflowPath = Join-Path $script:repoRoot ".github\workflows\quality.yml"
    $script:workflow = Get-Content $script:workflowPath -Raw
}

Describe "CAS quality workflow contract" {
    It "uses least-privilege repository permissions" {
        $script:workflow | Should -Match "permissions:\s*\r?\n\s+contents: read"
        $script:workflow | Should -Not -Match "contents: write|pull-requests: write|actions: write"
    }

    It "pins every action reference to a full commit SHA" {
        $references = [regex]::Matches($script:workflow, "uses:\s+[^@\s]+@([^\s#]+)")
        $references.Count | Should -BeGreaterThan 0
        foreach ($reference in $references) {
            $reference.Groups[1].Value | Should -Match "^[a-f0-9]{40}$"
        }
    }

    It "calls the shared quality command with timeouts and retained evidence" {
        $script:workflow | Should -Match "Invoke-Quality.ps1"
        $script:workflow | Should -Match "timeout-minutes:"
        $script:workflow | Should -Match "if: always\(\)"
        $script:workflow | Should -Match "\.artifacts/quality"
    }
}

