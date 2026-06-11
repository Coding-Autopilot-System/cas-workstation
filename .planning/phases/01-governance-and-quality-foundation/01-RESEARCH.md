# Phase 1: Governance and Quality Foundation - Research

## Planning Question

What must be established now so every later CAS Workstation phase is constrained by executable contracts, repeatable quality checks, and traceable evidence?

## Recommended Approach

Build the foundation in three layers:

1. Versioned JSON Schema contracts and positive/negative fixtures for every planned product artifact.
2. Repository governance conventions for ADRs and requirement-to-evidence traceability, enforced by deterministic checks.
3. One PowerShell quality entry point used identically by contributors and Windows CI.

The quality surface must remain PowerShell 5.1-compatible, work without mutating workstation state, and fail closed when required tooling, schemas, fixtures, or traceability evidence are missing.

## Contract Scope

Phase 1 should establish schemas for:

- workstation manifest
- managed state and ownership ledger
- operation plan
- doctor report
- structured event log entry
- support-bundle metadata

Schemas should use JSON Schema Draft 2020-12, include stable `$id` values, reject unknown properties where practical, and carry an explicit schema version. Positive and negative fixtures are required so later phases can evolve implementations without silently weakening contracts.

## Quality Architecture

Use a single `Invoke-Quality.ps1` entry point that:

- runs Pester tests
- runs PSScriptAnalyzer
- validates JSON schemas and fixtures
- validates Markdown links and required documentation conventions
- emits a machine-readable evidence summary under `.artifacts/`
- returns a non-zero exit code on any failed or unavailable required check

The script should expose focused switches for local iteration while the default runs the complete gate. Tests must isolate temporary files and avoid package installation or network access.

## CI Architecture

Windows CI should call the same quality command used locally. It must use:

- least-privilege `contents: read`
- immutable action SHA references
- explicit timeouts
- PowerShell 5.1 and PowerShell 7 validation where practical
- uploaded quality evidence even on failure

Workflow publication may be blocked by the current GitHub token lacking `workflow` scope. Keep workflow work in a separable commit so non-workflow foundation changes can still be pushed safely.

## Governance and Traceability

Add lightweight ADR and traceability conventions rather than a large governance framework. A machine-readable traceability map should connect each v1 requirement to its roadmap phase, tests, ADRs where applicable, and evidence commands/artifacts. Validation must reject unknown requirement IDs, duplicate IDs, missing phase assignments, and missing referenced files.

## Validation Architecture

- Pester tests exercise public PowerShell behavior and failure paths.
- Schema fixture validation proves every contract accepts a canonical example and rejects a broken one.
- Traceability tests compare the map against `.planning/REQUIREMENTS.md`.
- Documentation checks verify required governance files and local quality instructions.
- CI invokes the same local quality command and retains `.artifacts/quality/`.

## Threat Model

| Threat | Severity | Mitigation |
|---|---|---|
| Quality command reports success when a required tool is absent | High | Fail closed and test unavailable-tool behavior |
| Schema validation silently accepts malformed or unknown content | High | Strict schemas plus negative fixtures |
| CI gains unnecessary repository mutation authority | High | `contents: read`, no write permissions, immutable action SHAs |
| Traceability claims evidence that does not exist | Medium | Validate referenced files and requirement IDs |
| Validation command mutates workstation state | High | Restrict Phase 1 checks to repository-local reads and `.artifacts/` writes |

## Planning Implications

- Contract and governance work can proceed independently in Wave 1.
- The integrated quality command and CI depend on both Wave 1 outputs.
- CI workflow changes must be isolated because the current token lacks `workflow` scope.
- Later safety and execution-engine behavior remains out of scope.

