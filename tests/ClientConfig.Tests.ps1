BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:repoRoot "scripts\Cas.Workstation.psm1") -Force
    $script:manifest = Get-CasManifest
    $script:client = $script:manifest.clients | Where-Object id -eq "codex"
}

Describe "CAS owned client configuration" {
    It "merges only the CAS-owned namespace and preserves unrelated settings" {
        $existing = '{"theme":"dark","mcpServers":{"user.server":{"command":"user"}}}' | ConvertFrom-Json
        $merged = Merge-CasClientConfiguration -ExistingConfiguration $existing -Client $script:client -Manifest $script:manifest

        $merged.theme | Should -Be "dark"
        $merged.mcpServers.'user.server'.command | Should -Be "user"
        $merged.mcpServers.'cas-workstation.prompt-refiner'.scope | Should -Be "local-workstation"
    }

    It "removes only the CAS-owned namespace" {
        $existing = Merge-CasClientConfiguration -ExistingConfiguration ('{"mcpServers":{"user.server":{"command":"user"}}}' | ConvertFrom-Json) -Client $script:client -Manifest $script:manifest
        $updated = Remove-CasClientConfiguration -ExistingConfiguration $existing -OwnershipKey $script:client.ownershipKey

        $updated.mcpServers.'user.server'.command | Should -Be "user"
        $updated.mcpServers.PSObject.Properties[$script:client.ownershipKey] | Should -BeNullOrEmpty
    }

    It "atomically applies and reports owned-content drift without reacting to unrelated changes" {
        $config = Join-Path $TestDrive config
        New-Item -ItemType Directory -Path $config | Out-Null
        $result = Set-CasClientConfiguration -Client $script:client -ConfigPath $config -ApprovedRoots $config -Manifest $script:manifest
        $status = Get-CasClientConfigurationStatus -Client $script:client -ConfigPath $config -Manifest $script:manifest

        $result.contentDigest | Should -Match "^sha256:"
        $status.status | Should -Be "satisfied"

        $target = Get-CasClientTarget -Client $script:client -ConfigPath $config -Manifest $script:manifest
        $document = Get-Content $target -Raw | ConvertFrom-Json
        $document | Add-Member -MemberType NoteProperty -Name theme -Value dark
        $document | ConvertTo-Json -Depth 20 | Set-Content $target
        (Get-CasClientConfigurationStatus -Client $script:client -ConfigPath $config -Manifest $script:manifest).status | Should -Be "satisfied"
    }
}
