BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:repoRoot "scripts\Cas.Workstation.psm1") -Force
}

Describe "CAS ledger-only uninstall" {
    BeforeEach {
        $script:root = Join-Path $TestDrive "cas"
        $script:config = Join-Path $TestDrive "config"
        $script:stateRoot = Join-Path $script:config "state"
        New-Item -ItemType Directory -Path $script:root, $script:stateRoot -Force | Out-Null
        $script:statePath = Join-Path $script:stateRoot "managed-state.json"
        $script:state = New-CasManagedState -BundleId cas-workstation -Profile core -DesiredStateDigest "sha256:$('a' * 64)"
    }

    It "previews ledger actions without mutating targets" {
        $target = Join-Path $script:root "created.txt"
        "owned" | Set-Content -LiteralPath $target
        $null = Add-CasManagedResource -State $script:state -Id created -Kind file -Ownership created -Target $target -WasPresentBefore $false
        Write-CasManagedState -State $script:state -Path $script:statePath -ApprovedRoots $script:config

        $preview = Get-CasUninstallPreview -StatePath $script:statePath -ApprovedRoots @($script:root, $script:config)

        $preview.actions[0].action | Should -Be "remove-created"
        Test-Path -LiteralPath $target | Should -BeTrue
    }

    It "preserves observed resources" {
        $target = Join-Path $script:root "existing.txt"
        "user" | Set-Content -LiteralPath $target
        $null = Add-CasManagedResource -State $script:state -Id observed -Kind file -Ownership observed -Target $target -WasPresentBefore $true
        Write-CasManagedState -State $script:state -Path $script:statePath -ApprovedRoots $script:config

        $preview = Get-CasUninstallPreview -StatePath $script:statePath -ApprovedRoots @($script:root, $script:config)
        $result = Invoke-CasUninstall -Preview $preview -ApprovedRoots @($script:root, $script:config) -Confirm:$false

        $result | Should -BeNullOrEmpty
        Get-Content -LiteralPath $target | Should -Be "user"
    }

    It "applies removal only to a ledger-created file" {
        $owned = Join-Path $script:root "created.txt"
        $unrelated = Join-Path $script:root "unrelated.txt"
        "owned" | Set-Content -LiteralPath $owned
        "user" | Set-Content -LiteralPath $unrelated
        $null = Add-CasManagedResource -State $script:state -Id created -Kind file -Ownership created -Target $owned -WasPresentBefore $false
        Write-CasManagedState -State $script:state -Path $script:statePath -ApprovedRoots $script:config

        $preview = Get-CasUninstallPreview -StatePath $script:statePath -ApprovedRoots @($script:root, $script:config)
        $null = Invoke-CasUninstall -Preview $preview -ApprovedRoots @($script:root, $script:config) -Confirm:$false

        Test-Path -LiteralPath $owned | Should -BeFalse
        Test-Path -LiteralPath $unrelated | Should -BeTrue
    }

    It "refuses recursive removal when an owned directory contains unexpected state" {
        $directory = Join-Path $script:root "created-directory"
        New-Item -ItemType Directory -Path $directory | Out-Null
        "user" | Set-Content -LiteralPath (Join-Path $directory "unexpected.txt")
        $null = Add-CasManagedResource -State $script:state -Id directory -Kind directory -Ownership created -Target $directory -WasPresentBefore $false
        Write-CasManagedState -State $script:state -Path $script:statePath -ApprovedRoots $script:config

        $preview = Get-CasUninstallPreview -StatePath $script:statePath -ApprovedRoots @($script:root, $script:config)

        { Invoke-CasUninstall -Preview $preview -ApprovedRoots @($script:root, $script:config) -Confirm:$false } | Should -Throw "*refusing recursive removal*"
        Test-Path -LiteralPath (Join-Path $directory "unexpected.txt") | Should -BeTrue
    }

    It "blocks the preview when ledger evidence escapes approved roots" {
        $outside = Join-Path $TestDrive "outside.txt"
        "user" | Set-Content -LiteralPath $outside
        $null = Add-CasManagedResource -State $script:state -Id unsafe -Kind file -Ownership created -Target $outside -WasPresentBefore $false
        Write-CasManagedState -State $script:state -Path $script:statePath -ApprovedRoots $script:config

        { Get-CasUninstallPreview -StatePath $script:statePath -ApprovedRoots @($script:root, $script:config) } | Should -Throw "*outside approved CAS boundaries*"
        Test-Path -LiteralPath $outside | Should -BeTrue
    }

    It "restores modified files from recorded backup evidence" {
        $target = Join-Path $script:root "config.json"
        $backup = Join-Path $script:config "config.backup.json"
        '{"cas":true}' | Set-Content -LiteralPath $target
        '{"user":true}' | Set-Content -LiteralPath $backup
        $null = Add-CasManagedResource -State $script:state -Id modified -Kind configuration -Ownership modified -Target $target -WasPresentBefore $true -BackupTarget $backup
        Write-CasManagedState -State $script:state -Path $script:statePath -ApprovedRoots $script:config

        $preview = Get-CasUninstallPreview -StatePath $script:statePath -ApprovedRoots @($script:root, $script:config)
        $null = Invoke-CasUninstall -Preview $preview -ApprovedRoots @($script:root, $script:config) -Confirm:$false

        (Get-Content -LiteralPath $target -Raw | ConvertFrom-Json).user | Should -BeTrue
    }

    It "surgically removes client-owned configuration while preserving later user changes" {
        $manifest = Get-CasManifest
        $client = $manifest.clients | Where-Object id -eq codex
        $target = Get-CasClientTarget -Client $client -ConfigPath $script:config -Manifest $manifest
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        $document = Merge-CasClientConfiguration -ExistingConfiguration ('{"theme":"dark","mcpServers":{"user.server":{"command":"user"}}}' | ConvertFrom-Json) -Client $client -Manifest $manifest
        $document | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $target
        $backup = Join-Path $script:config "client.backup.json"
        '{}' | Set-Content -LiteralPath $backup
        $null = Add-CasManagedResource -State $script:state -Id "client:codex" -Kind configuration -Ownership modified -Target $target -WasPresentBefore $true -BackupTarget $backup
        Write-CasManagedState -State $script:state -Path $script:statePath -ApprovedRoots $script:config

        $preview = Get-CasUninstallPreview -StatePath $script:statePath -ApprovedRoots $script:config
        $preview.actions[0].action | Should -Be "remove-owned-configuration"
        $null = Invoke-CasUninstall -Preview $preview -ApprovedRoots $script:config -Confirm:$false
        $updated = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json
        $updated.theme | Should -Be "dark"
        $updated.mcpServers.'user.server'.command | Should -Be "user"
        $updated.mcpServers.PSObject.Properties[$client.ownershipKey] | Should -BeNullOrEmpty
    }
}
