# CAS Workstation

CAS Workstation is the opinionated Windows-first bootstrap bundle for the
Coding-Autopilot-System ecosystem. It provides one install surface for a fully
configured AI-native coding workstation.

## Commands

```powershell
.\setup.ps1
.\doctor.ps1
.\start.ps1
.\upgrade.ps1
.\uninstall.ps1
```

## Contributor Quality Gate

The repository requires Pester 5.7+, PSScriptAnalyzer 1.24+, Python 3.12+, and
the Python `jsonschema` package. Run the same gate used by CI:

```powershell
.\Invoke-Quality.ps1
```

The command runs tests, static analysis, contract fixtures, and governance
validation. Machine-readable evidence is written under `.artifacts/quality/`.
It fails closed when a required validator or check is unavailable.

## What It Manages

- Core developer tooling: Git, GitHub CLI, Node.js, Python, uv, .NET, Docker,
  Azure CLI, WSL
- AI coder CLIs: Codex, Claude Code, Gemini CLI
- Coding-Autopilot-System component repos
- Shared runtime paths under the configured user profile
- Generated MCP client configuration fragments

## Files

- `stack.manifest.json` - versioned workstation contract
- `schemas/doctor.schema.json` - machine-readable readiness report schema
- `scripts/Cas.Workstation.psm1` - shared implementation module
- `docs/support-matrix.md` - supported platform and component matrix
- `docs/traceability.json` - requirement-to-phase and evidence map
- `Invoke-Quality.ps1` - authoritative local and CI quality gate

## Typical Flow

```powershell
.\setup.ps1 -NonInteractive
.\doctor.ps1
.\start.ps1
```

## Inspect Desired State

Manifest content is validated before operational use. Profiles resolve into a
normalized desired state with a deterministic SHA-256 digest and structured
compatibility findings:

```powershell
Import-Module .\scripts\Cas.Workstation.psm1 -Force
$manifest = Get-CasManifest
Resolve-CasDesiredState -Profile core -Manifest $manifest
```

Unallowlisted operational identities, ambiguous references, and unsupported
required components fail closed before external process execution.

## Safety And Managed State

CAS records explicit ownership under the configured state directory in
`managed-state.json`. Resources are classified as `created`, `modified`, or
`observed`; pre-existing resources cannot be claimed as CAS-created.

Mutation and removal targets must remain within approved CAS roots. Drive,
profile, system, escaping, and reparse-point paths are rejected. Writes use
validated sibling temporary files and backup evidence.

## Safe Uninstall

Uninstall is preview-only by default and acts only on resources proven by the
managed-state ledger:

```powershell
.\uninstall.ps1
.\uninstall.ps1 -Apply
```

Observed resources are preserved. Modified resources require a recorded backup.
Created directories are removed only when empty; unexpected contents block
removal instead of triggering recursive deletion.
