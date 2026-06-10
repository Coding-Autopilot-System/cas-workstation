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

## What It Manages

- Core developer tooling: Git, GitHub CLI, Node.js, Python, uv, .NET, Docker,
  Azure CLI, WSL
- AI coder CLIs: Codex, Claude Code, Gemini CLI
- Coding-Autopilot-System component repos
- Shared runtime paths under `C:\Users\KimHarjamaki\.cas\`
- Generated MCP client configuration fragments

## Files

- `stack.manifest.json` - versioned workstation contract
- `schemas/doctor.schema.json` - machine-readable readiness report schema
- `scripts/Cas.Workstation.psm1` - shared implementation module
- `docs/support-matrix.md` - supported platform and component matrix

## Typical Flow

```powershell
.\setup.ps1 -NonInteractive
.\doctor.ps1
.\start.ps1
```
