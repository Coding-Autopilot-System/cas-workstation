# CAS Workstation

![Visual Diagram](docs/assets/concept.png)


[![CI](https://github.com/Coding-Autopilot-System/cas-workstation/actions/workflows/ci.yml/badge.svg)](https://github.com/Coding-Autopilot-System/cas-workstation/actions/workflows/ci.yml) [![CodeQL](https://github.com/Coding-Autopilot-System/cas-workstation/actions/workflows/codeql.yml/badge.svg)](https://github.com/Coding-Autopilot-System/cas-workstation/actions/workflows/codeql.yml)


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

## Plan, Apply, And Recover

Setup, upgrade, and repair are preview-first entry points over the same
deterministic operation engine. Preview shows stable operation IDs, changes,
skips, commands, sources, and risks without mutating the workstation:

```powershell
.\setup.ps1 -Profile full
.\upgrade.ps1 -Profile full
.\repair.ps1 -Profile full
```

Mutation requires explicit intent. Every apply receives a correlation ID and
writes an atomic operation journal under `.cas\state` plus JSONL events under
`.cas\logs`:

```powershell
.\setup.ps1 -Profile full -Apply
.\repair.ps1 -Profile full -Apply -Resume
```

Retries are bounded. A failed operation stops later work and records actionable
resume guidance. External operations are not automatically rolled back.
Repository updates fail closed when the checkout is dirty, detached, on an
unexpected branch, has local commits, uses an unexpected origin, or cannot
prove a fast-forward relationship.

The `full` profile is the declarative golden path and includes `cas-platform`,
`cas-contracts`, `cas-evals`, and `cas-reference-product`.

## Client, Skill, And Workspace Profiles

The selected profile also resolves clients, portable skills, and workspace
conventions into typed preview-first operations. Client adapters manage only
the namespaced `cas-workstation.prompt-refiner` MCP entry, preserve unrelated
settings, atomically back up modified files, and record an owned-content digest
for drift repair.

Skills and workspaces are copied only from manifest-allowlisted repositories
into approved CAS-managed boundaries. Existing unowned targets, unsafe relative
paths, reparse points, malformed client files, and conflicting owned namespaces
fail closed.

The manifest distinguishes local workstation MCP (`stdio`) from production
remote transports and permits only non-secret authentication references.
Credentials, tokens, and API keys are never generated or embedded. Uninstall
removes the CAS-owned MCP namespace surgically instead of restoring a stale
whole-file backup over later user changes.
