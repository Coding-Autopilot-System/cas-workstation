---
phase: 01-governance-and-quality-foundation
plan: 03
subsystem: quality
tags: [pester, psscriptanalyzer, github-actions, evidence]
provides:
  - Unified local and CI quality gate
  - Machine-readable quality evidence
  - Least-privilege immutable Windows CI workflow
affects: [all-future-phases, pull-requests, contributor-workflow]
tech-stack:
  added: [PSScriptAnalyzer, GitHub Actions]
  patterns: [shared local-ci command, immutable action pins, retained evidence]
key-files:
  created: [Invoke-Quality.ps1, PSScriptAnalyzerSettings.psd1, .github/workflows/quality.yml]
  modified: [README.md, docs/traceability.json]
key-decisions:
  - "Use the same fail-closed PowerShell quality command locally and in CI."
  - "Keep workflow publication in a separable commit because GitHub requires workflow token scope."
duration: 15min
completed: 2026-06-11
---

# Phase 1 Plan 03: Unified Quality Gate Summary

CAS Workstation now has one fail-closed quality command used locally and by a least-privilege Windows CI workflow.

## Accomplishments

- Added Pester, PSScriptAnalyzer, contract, governance, and documentation checks behind `Invoke-Quality.ps1`.
- Added machine-readable evidence under `.artifacts/quality/`.
- Added immutable action pins, read-only permissions, timeouts, and retained evidence in Windows CI.

## Verification

- `.\Invoke-Quality.ps1`
- `Invoke-Pester tests\Workflow.Tests.ps1`
- Result: 11/11 full-suite tests passed and zero blocking static-analysis findings.

## Deviations

- The CI workflow is isolated in its own commit because publishing it requires GitHub OAuth `workflow` scope.

## Self-Check: PASSED
