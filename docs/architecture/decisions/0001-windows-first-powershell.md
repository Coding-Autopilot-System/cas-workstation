# ADR 0001: Windows-First PowerShell Control Plane

- Status: Accepted
- Date: 2026-06-11
- Requirements: GOV-02, GOV-03, REL-02

## Context

CAS Workstation must safely bootstrap a developer's primary Windows workstation and provide identical interactive and non-interactive behavior.

## Decision

Use PowerShell 5.1-compatible scripts as the v1 workstation control plane. PowerShell 7 is the preferred development shell, but compatibility checks and Windows CI must prevent accidental loss of Windows PowerShell support.

macOS and Linux are not first-class v1 hosts. WSL may be installed and managed as a dependency but is not the primary control plane.

## Consequences

- Public entry points and quality checks remain scriptable in PowerShell.
- Platform-specific behavior requires isolated adapters and tests.
- Clean Windows proof is the release gate.

## Verification

- `.\Invoke-Quality.ps1`
- `.github/workflows/quality.yml`
- `docs/support-matrix.md`

