BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:repoRoot "scripts\Cas.Workstation.psm1") -Force
    $script:root = Join-Path $TestDrive "cas"
    $script:config = Join-Path $TestDrive "config"
}

Describe "CAS deterministic operation planning" {
    It "produces canonical equivalent plans for equivalent invocation modes" {
        $inventory = [pscustomobject]@{ resources = @() }
        $first = New-CasOperationPlan -Mode setup -Profile core -RootPath $script:root -ConfigPath $script:config -Inventory $inventory
        $second = New-CasOperationPlan -Mode setup -Profile core -RootPath $script:root -ConfigPath $script:config -Inventory $inventory

        (ConvertTo-CasCanonicalJson $first) | Should -BeExactly (ConvertTo-CasCanonicalJson $second)
        $first.planId | Should -Match "^sha256:[a-f0-9]{64}$"
        $kinds = @($first.operations.kind)
        $kinds.IndexOf("repository") | Should -BeGreaterThan $kinds.IndexOf("tool")
        $kinds.IndexOf("directory") | Should -BeGreaterThan $kinds.IndexOf("repository")
        $kinds.IndexOf("configuration") | Should -BeGreaterThan $kinds.IndexOf("directory")
    }

    It "shows commands sources risks and changes before apply" {
        $plan = New-CasOperationPlan -Mode upgrade -Profile core -RootPath $script:root -ConfigPath $script:config -Inventory ([pscustomobject]@{ resources = @() })

        @($plan.operations).Count | Should -BeGreaterThan 0
        @($plan.operations | Where-Object { -not $_.command -or -not $_.source -or -not $_.reason }).Count | Should -Be 0
        @($plan.operations | Where-Object action -ne "skip").Count | Should -BeGreaterThan 0
        { Assert-CasOperationPlan $plan } | Should -Not -Throw
    }

    It "turns satisfied desired state into idempotent skips" {
        $initial = New-CasOperationPlan -Mode repair -Profile core -RootPath $script:root -ConfigPath $script:config -Inventory ([pscustomobject]@{ resources = @() })
        $resources = @($initial.operations | ForEach-Object {
            [pscustomobject]@{ id = $_.id; status = if ($_.kind -eq "tool") { "installed" } else { "synchronized" }; detail = $null }
        })
        $repeat = New-CasOperationPlan -Mode repair -Profile core -RootPath $script:root -ConfigPath $script:config -Inventory ([pscustomobject]@{ resources = $resources })

        @($repeat.operations | Where-Object action -ne "skip").Count | Should -Be 0
    }

    It "plans a fast-forward update for a clean behind repository" {
        $inventory = [pscustomobject]@{ resources = @([pscustomobject]@{ id = "repo:autogen"; status = "behind"; detail = $null }) }
        $plan = New-CasOperationPlan -Mode upgrade -Profile core -RootPath $script:root -ConfigPath $script:config -Inventory $inventory

        ($plan.operations | Where-Object id -eq "repo:autogen").action | Should -Be "update"
    }

    It "plans selected clients skills and workspaces as typed operations" {
        $plan = New-CasOperationPlan -Mode setup -Profile full -RootPath $script:root -ConfigPath $script:config -Inventory ([pscustomobject]@{ resources = @() })

        ($plan.operations | Where-Object id -eq "client:codex").kind | Should -Be "configuration"
        ($plan.operations | Where-Object id -eq "skill:prompt-refiner").adapter | Should -Be "tree-copy"
        ($plan.operations | Where-Object id -eq "workspace:cas-default").resourceCategory | Should -Be "workspace"
    }
}
