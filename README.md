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
