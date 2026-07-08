# cas-workstation Wiki

`cas-workstation` is the opinionated Windows-first bootstrap bundle for the
Coding-Autopilot-System ecosystem — one install surface for a fully configured AI-native coding
workstation: developer tooling, AI coder CLIs, the CAS component repos, and MCP client
configuration.

## The workstation contract

The workstation's desired state is declared once in [`stack.manifest.json`](../../stack.manifest.json)
(the versioned workstation contract) and validated against
[`schemas/doctor.schema.json`](../../schemas/doctor.schema.json) (the machine-readable readiness
report schema). Every mutating command — `setup.ps1`, `upgrade.ps1`, `repair.ps1` — is
preview-first over the same deterministic operation engine; nothing mutates the machine without
an explicit `-Apply`.

## Quickstart

```powershell
.\setup.ps1
.\doctor.ps1
.\start.ps1
.\upgrade.ps1
.\uninstall.ps1
```

## Where to go next

- [Architecture](Architecture.md) — the manifest-to-desired-state resolution and safety model
- [Operations](Operations.md) — verified quality-gate, setup, and readiness commands
- [Decisions](Decisions.md) — index of recorded architectural decisions

<!-- docs-verified: 4c70f86190c6cd2333fb6357a5928fbb904776ef 2026-07-08 -->
