# CAS Workstation

## What This Is

CAS Workstation is a public, Windows-first enterprise bootstrap product that turns a clean developer workstation into a complete, validated AI-native development environment for the Coding-Autopilot-System ecosystem. It provides a single trustworthy surface to install, operate, diagnose, upgrade, recover, and safely remove declaratively selected tools, repositories, services, skills, and AI client configuration.

## Core Value

An AI developer can run one safe, repeatable workflow and receive a complete, working workstation without manually discovering or reconciling prerequisites.

## Requirements

### Validated

- ✓ A versioned manifest can describe core and full workstation profiles — existing seed
- ✓ PowerShell entry points exist for setup, doctor, start, upgrade, and uninstall — existing seed
- ✓ Doctor can emit human-readable and JSON readiness output — existing seed
- ✓ The seed can discover tools, repositories, and basic service health — existing seed
- ✓ Governance, schemas, Pester, static analysis, Windows CI, ADRs, and requirement traceability — validated in Phase 1
- ✓ Manifest, inventory, ownership, path safety, and ledger-only uninstall — validated in Phase 2
- ✓ Deterministic plan/apply, durable recovery, repair, and repository fail-closed behavior — validated in Phase 3

### Active

- [ ] Generate and merge profile-specific AI client, MCP, skill, workspace, and service configuration without overwriting unrelated user state.
- [ ] Provide actionable diagnostics, structured logs, state inventory, recovery, and redacted support bundles.
- [ ] Publish signed, reproducible releases with provenance and clean-machine end-to-end verification.
- [ ] Document architecture, threat model, support boundaries, contribution workflow, and operations.

### Out of Scope

- macOS or Linux as first-class hosts — Windows 11 is the v1 product boundary; WSL is a managed dependency.
- Automatic credential provisioning or secret storage — authentication remains explicitly user-controlled or uses managed identity.
- Silent removal of third-party tools or unrelated user configuration — uninstall removes only CAS-owned resources recorded in managed state.
- A graphical installer — a reliable scriptable PowerShell surface is the v1 priority.
- Enterprise fleet management — v1 targets an individual developer workstation, while preserving automation-friendly interfaces.

## Context

- The repository contains a functional seed: a manifest, support matrix, PowerShell module, command entry points, and doctor JSON schema.
- Current setup executes package managers and Git updates directly without an execution plan, durable operation journal, rollback model, or download verification.
- Current client configuration generation writes isolated fragments, but does not yet merge into client-owned configuration or manage skills and workspaces.
- Current uninstall accepts arbitrary root/config paths and recursively removes them after confirmation, making path-boundary and ownership validation critical.
- No Pester suite, CI workflows, manifest schema, release automation, threat model, or clean-machine verification currently exists.
- The product is also a public portfolio artifact; architecture decisions, evidence, reproducibility, and security posture must be inspectable.

## Constraints

- **Platform**: Windows 11 and PowerShell 5.1+ are the supported v1 host contract — compatibility must be verified in CI and on clean machines.
- **Safety**: Destructive actions require explicit intent, CAS ownership evidence, and canonical path-boundary validation — primary workstations cannot tolerate unsafe cleanup.
- **Security**: No embedded credentials or tokens; downloads and package execution must be allowlisted, observable, and auditable — supply-chain trust is mandatory.
- **Configuration**: Declarative profile and manifest data is authoritative — tool, repository, service, client, workspace, and skill lists must not be hard-coded.
- **State**: CAS-managed state and generated configuration remain under configured CAS root/profile paths — unrelated user state must remain untouched.
- **Automation**: Interactive and non-interactive flows must expose equivalent behavior and machine-readable outcomes — CI and repeatable operations depend on it.
- **Quality**: Schemas, Pester tests, static analysis, and clean-machine journeys are release gates — documentation-only confidence is insufficient.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Windows-first PowerShell product | Matches the target developer environment and existing seed | — Pending |
| Declarative manifest and profiles are the control plane | Enables reviewable, testable, reproducible workstation composition | — Pending |
| Plan/apply execution with durable managed-state journal | Makes partial failure, recovery, upgrades, and uninstall safe | — Pending |
| CAS-owned fragments plus explicit merge adapters | Prevents overwriting unrelated client configuration | — Pending |
| User-controlled authentication and managed identity for Azure | Avoids secret ownership and embedded credentials | — Pending |
| Signed reproducible releases and clean-machine gates | Establishes supply-chain and operational trust | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition**:
1. Move validated requirements to Validated with the phase reference.
2. Move invalidated requirements to Out of Scope with a reason.
3. Add newly discovered requirements and key decisions.
4. Confirm the product description and core value remain accurate.

**After each milestone**:
1. Review all scope and constraints.
2. Revalidate the core value.
3. Audit out-of-scope decisions.
4. Update context with evidence, users, feedback, and operational metrics.

---
*Last updated: 2026-06-12 after Phase 3 completion*
