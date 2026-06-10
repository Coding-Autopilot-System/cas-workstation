$modulePath = Join-Path $PSScriptRoot "..\scripts\Cas.Workstation.psm1"
Import-Module $modulePath -Force

Describe "CAS Workstation safety contracts" {
    It "validates the repository manifest" {
        Test-CasManifest -Manifest (Get-CasManifest) | Should -Be $true
    }

    It "rejects filesystem roots and traversal paths" {
        { Assert-CasSafeManagedPath -Path "C:\" } | Should -Throw
        Test-CasRelativePath -Path "..\escape" | Should -Be $false
    }

    It "creates an idempotent owned directory layout" {
        $root = Join-Path $TestDrive "root"
        $config = Join-Path $TestDrive "config"
        New-CasDirectoryLayout -RootPath $root -ConfigPath $config
        $firstMarker = Get-Content -Raw (Join-Path $root ".cas-managed.json")
        New-CasDirectoryLayout -RootPath $root -ConfigPath $config
        Get-Content -Raw (Join-Path $root ".cas-managed.json") | Should -Be $firstMarker
        Test-CasManagedDirectory -Path $root | Should -Be $true
    }

    It "preserves unrelated client configuration" {
        $root = Join-Path $TestDrive "merge-root"
        $config = Join-Path $TestDrive "merge-config"
        New-CasDirectoryLayout -RootPath $root -ConfigPath $config
        $target = Join-Path $config "mcp\clients\codex.mcp.json"
        Set-Content -LiteralPath $target -Value '{"custom":{"keep":true},"mcpServers":{"other":{"command":"x"}}}' -Encoding UTF8
        New-CasClientConfigs -ConfigPath $config -RootPath $root
        $result = Get-Content -Raw $target | ConvertFrom-Json
        $result.custom.keep | Should -Be $true
        $result.mcpServers.other.command | Should -Be "x"
        $result.mcpServers.'prompt-refiner'.command | Should -Be "node"
    }

    It "refuses to overwrite invalid client JSON" {
        $root = Join-Path $TestDrive "invalid-root"
        $config = Join-Path $TestDrive "invalid-config"
        New-CasDirectoryLayout -RootPath $root -ConfigPath $config
        Set-Content -LiteralPath (Join-Path $config "mcp\clients\codex.mcp.json") -Value '{bad' -Encoding UTF8
        { New-CasClientConfigs -ConfigPath $config -RootPath $root } | Should -Throw
    }

    It "validates doctor reports before writing" {
        $report = [pscustomobject]@{ bundleId="x"; generatedAtUtc=[DateTime]::UtcNow.ToString("o"); profile="x"; rootPath="C:\x"; configPath="C:\y"; overallStatus="ready"; tools=@(); services=@(); repos=@(); recommendations=@() }
        Test-CasDoctorReport -Report $report | Should -Be $true
        $report.overallStatus = "invalid"
        { Test-CasDoctorReport -Report $report } | Should -Throw
    }

    It "previews uninstall without deleting owned directories" {
        $root = Join-Path $TestDrive "uninstall-root"
        $config = Join-Path $TestDrive "uninstall-config"
        New-CasDirectoryLayout -RootPath $root -ConfigPath $config
        & (Join-Path $PSScriptRoot "..\uninstall.ps1") -RootPath $root -ConfigPath $config
        Test-Path -LiteralPath $root | Should -Be $true
        Test-Path -LiteralPath $config | Should -Be $true
    }

    It "removes only owned directories after explicit execution" {
        $root = Join-Path $TestDrive "execute-root"
        $config = Join-Path $TestDrive "execute-config"
        New-CasDirectoryLayout -RootPath $root -ConfigPath $config
        & (Join-Path $PSScriptRoot "..\uninstall.ps1") -RootPath $root -ConfigPath $config -Execute -Confirm:$false
        Test-Path -LiteralPath $root | Should -Be $false
        Test-Path -LiteralPath $config | Should -Be $false
    }

    It "refuses uninstall of unowned directories" {
        $root = Join-Path $TestDrive "unowned-root"
        $config = Join-Path $TestDrive "unowned-config"
        New-Item -ItemType Directory -Path $root,$config -Force | Out-Null
        { & (Join-Path $PSScriptRoot "..\uninstall.ps1") -RootPath $root -ConfigPath $config -Execute -Confirm:$false } | Should -Throw
    }
}