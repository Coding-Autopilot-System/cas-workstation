---
phase: 4
slug: client-skills-and-workspace-profiles
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-13
---

# Phase 4 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pester 5.7.1, PSScriptAnalyzer, JSON Schema Draft 2020-12 |
| **Config file** | `PSScriptAnalyzerSettings.psd1` |
| **Quick run command** | `Invoke-Pester -Path tests/ClientConfig.Tests.ps1,tests/ManagedTrees.Tests.ps1,tests/Plan.Tests.ps1,tests/Uninstall.Tests.ps1` |
| **Full suite command** | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-Quality.ps1` |
| **Estimated runtime** | ~20 seconds |

## Sampling Rate

- **After every task commit:** Run the focused Pester files changed by the task.
- **After every plan wave:** Run `Invoke-Quality.ps1`.
- **Before verification:** Full suite must be green.
- **Max feedback latency:** 30 seconds.

## Per-Task Verification Map

| Capability | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|------------|-------------|------------|-----------------|-----------|-------------------|--------|
| Manifest adapter/source/target policy | CFG-03, CFG-04 | T-04-01 | Reject unallowlisted sources, targets, transports, and secret-bearing fields | schema + unit | `Invoke-Pester -Path tests/ContractSchemas.Tests.ps1,tests/Manifest.Tests.ps1` | pending |
| Surgical client merge and removal | CFG-01, CFG-02, CFG-05 | T-04-02 | Preserve unrelated settings and remove only CAS-owned subtree | unit + integration | `Invoke-Pester -Path tests/ClientConfig.Tests.ps1,tests/Uninstall.Tests.ps1` | pending |
| Managed skill/workspace trees | CFG-03, CFG-05 | T-04-03 | Reject reparse points, escapes, and unowned conflicts | unit + integration | `Invoke-Pester -Path tests/ManagedTrees.Tests.ps1,tests/Safety.Tests.ps1` | pending |
| Typed planning, apply, and repair | CFG-01 through CFG-05 | T-04-04 | No mutation outside validated journaled operations | integration | `Invoke-Pester -Path tests/Plan.Tests.ps1,tests/Apply.Tests.ps1,tests/OperationWorkflow.Tests.ps1` | pending |
| Full governance and regression gate | CFG-01 through CFG-05 | T-04-01 through T-04-04 | Contracts, static analysis, docs, and all behavior remain green | full gate | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-Quality.ps1` | pending |

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. New focused test files
must be added with their corresponding implementation tasks.

## Manual-Only Verifications

All phase behaviors must have automated verification. Real client CLIs may be
used as additional release evidence later, but Phase 4 tests must not require
authenticated external services or mutate real user profiles.

## Validation Sign-Off

- [x] All capabilities have automated verification.
- [x] Sampling continuity prevents three consecutive tasks without automated verification.
- [x] Existing infrastructure covers Wave 0.
- [x] No watch-mode flags.
- [x] Feedback latency target is below 30 seconds.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-06-13
