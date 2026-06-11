BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:repoRoot "scripts\Cas.Workstation.psm1") -Force
}

Describe "CAS filesystem boundary policy" {
    It "accepts a canonical child below an approved boundary" {
        $root = Join-Path $TestDrive "cas"
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $target = Join-Path $root "state\managed-state.json"

        Assert-CasSafePath -Path $target -ApprovedRoots $root | Should -Be ([IO.Path]::GetFullPath($target))
    }

    It "rejects targets outside approved boundaries" {
        $root = Join-Path $TestDrive "cas"
        $outside = Join-Path $TestDrive "unrelated\file.json"
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        { Assert-CasSafePath -Path $outside -ApprovedRoots $root } | Should -Throw "*outside approved CAS boundaries*"
    }

    It "rejects an approved boundary itself unless explicitly allowed" {
        $root = Join-Path $TestDrive "cas"
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        { Assert-CasSafePath -Path $root -ApprovedRoots $root } | Should -Throw
        Assert-CasSafePath -Path $root -ApprovedRoots $root -AllowBoundary | Should -Be ([IO.Path]::GetFullPath($root))
    }

    It "rejects a reparse-point target or ancestor" {
        InModuleScope Cas.Workstation -Parameters @{ TestRoot = (Join-Path $TestDrive "cas") } {
            param($TestRoot)
            New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
            Mock Test-CasPathHasReparsePoint { $true }

            { Assert-CasSafePath -Path (Join-Path $TestRoot "unsafe") -ApprovedRoots $TestRoot } | Should -Throw "*reparse point*"
        }
    }
}

Describe "CAS ownership ledger and atomic writes" {
    It "never claims a pre-existing resource as created" {
        $state = New-CasManagedState -BundleId cas-workstation -Profile core -DesiredStateDigest "sha256:$('a' * 64)"

        { Add-CasManagedResource -State $state -Id existing -Kind file -Ownership created -Target (Join-Path $TestDrive "existing") -WasPresentBefore $true } | Should -Throw "*existed before*"
    }

    It "requires backup evidence for modified resources" {
        $state = New-CasManagedState -BundleId cas-workstation -Profile core -DesiredStateDigest "sha256:$('a' * 64)"

        { Add-CasManagedResource -State $state -Id modified -Kind configuration -Ownership modified -Target (Join-Path $TestDrive "config.json") -WasPresentBefore $true } | Should -Throw "*backup target*"
    }

    It "writes and validates managed state atomically" {
        $root = Join-Path $TestDrive "cas"
        $stateRoot = Join-Path $root "state"
        New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
        $path = Join-Path $stateRoot "managed-state.json"
        $state = New-CasManagedState -BundleId cas-workstation -Profile core -DesiredStateDigest "sha256:$('a' * 64)"
        $null = Add-CasManagedResource -State $state -Id created -Kind directory -Ownership created -Target (Join-Path $root "repos") -WasPresentBefore $false

        Write-CasManagedState -State $state -Path $path -ApprovedRoots $root
        $loaded = Read-CasManagedState -Path $path

        $loaded.resources[0].ownership | Should -Be "created"
        Get-ChildItem $stateRoot -Filter "*.tmp" | Should -BeNullOrEmpty
    }

    It "backs up an existing valid target before atomic replacement" {
        $root = Join-Path $TestDrive "cas"
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $path = Join-Path $root "state.json"
        '{"old":true}' | Set-Content -LiteralPath $path

        $backup = Write-CasAtomicJson -InputObject ([pscustomobject]@{ new = $true }) -Path $path -ApprovedRoots $root

        Test-Path -LiteralPath $backup | Should -BeTrue
        (Get-Content $backup -Raw | ConvertFrom-Json).old | Should -BeTrue
        (Get-Content $path -Raw | ConvertFrom-Json).new | Should -BeTrue
    }
}
