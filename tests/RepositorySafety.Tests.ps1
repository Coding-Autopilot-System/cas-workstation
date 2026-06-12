BeforeAll {
    $script:repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:repoRoot "scripts\Cas.Workstation.psm1") -Force
    $script:origin = "https://github.com/Coding-Autopilot-System/example.git"
}

Describe "CAS repository synchronization safety" {
    It "allows only clean expected branches without local commits" {
        $status = ConvertFrom-CasGitRepositoryEvidence -ExpectedOrigin $script:origin -ActualOrigin $script:origin -ExpectedBranch main -ActualBranch main -Behind 2
        $status.status | Should -Be "behind"
    }

    It "fails closed for dirty detached unexpected and diverged repositories" {
        { ConvertFrom-CasGitRepositoryEvidence -ExpectedOrigin $script:origin -ActualOrigin $script:origin -ExpectedBranch main -ActualBranch main -PorcelainStatus " M file" } | Should -Throw "*uncommitted*"
        { ConvertFrom-CasGitRepositoryEvidence -ExpectedOrigin $script:origin -ActualOrigin $script:origin -ExpectedBranch main -ActualBranch $null } | Should -Throw "*detached*"
        { ConvertFrom-CasGitRepositoryEvidence -ExpectedOrigin $script:origin -ActualOrigin $script:origin -ExpectedBranch main -ActualBranch feature } | Should -Throw "*expected branch*"
        { ConvertFrom-CasGitRepositoryEvidence -ExpectedOrigin $script:origin -ActualOrigin $script:origin -ExpectedBranch main -ActualBranch main -Ahead 1 -Behind 1 } | Should -Throw "*diverged*"
    }
}
