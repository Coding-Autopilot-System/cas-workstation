BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:repoRoot "scripts\Cas.Workstation.psm1") -Force
}

Describe "CAS deterministic managed trees" {
    It "produces stable digests independent of file creation order" {
        $one = Join-Path $TestDrive one
        $two = Join-Path $TestDrive two
        New-Item -ItemType Directory -Path $one,$two | Out-Null
        "a" | Set-Content (Join-Path $one a.txt)
        "b" | Set-Content (Join-Path $one b.txt)
        "b" | Set-Content (Join-Path $two b.txt)
        "a" | Set-Content (Join-Path $two a.txt)

        (Get-CasTreeDigest -Path $one -ApprovedRoots $TestDrive) | Should -BeExactly (Get-CasTreeDigest -Path $two -ApprovedRoots $TestDrive)
    }

    It "copies an absent managed tree and rejects adoption of an existing target" {
        $source = Join-Path $TestDrive source
        $target = Join-Path $TestDrive target
        New-Item -ItemType Directory -Path $source | Out-Null
        "content" | Set-Content (Join-Path $source file.txt)

        $result = Copy-CasManagedTree -Source $source -Target $target -ApprovedRoots $TestDrive
        $result.contentDigest | Should -Be (Get-CasTreeDigest -Path $source -ApprovedRoots $TestDrive)
        { Copy-CasManagedTree -Source $source -Target $target -ApprovedRoots $TestDrive } | Should -Throw "*cannot be adopted*"
    }

    It "removes obsolete owned files during a digest-proven update" {
        $source = Join-Path $TestDrive update-source
        $target = Join-Path $TestDrive update-target
        New-Item -ItemType Directory -Path $source | Out-Null
        "keep" | Set-Content (Join-Path $source keep.txt)
        "obsolete" | Set-Content (Join-Path $source obsolete.txt)
        $null = Copy-CasManagedTree -Source $source -Target $target -ApprovedRoots $TestDrive
        $priorDigest = Get-CasTreeDigest -Path $target -ApprovedRoots $TestDrive
        Remove-Item (Join-Path $source obsolete.txt)

        $null = Copy-CasManagedTree -Source $source -Target $target -ApprovedRoots $TestDrive -ReplaceOwned -ExpectedOwnedDigest $priorDigest
        Test-Path (Join-Path $target obsolete.txt) | Should -BeFalse
        (Get-CasTreeDigest -Path $target -ApprovedRoots $TestDrive) | Should -Be (Get-CasTreeDigest -Path $source -ApprovedRoots $TestDrive)
    }
}
