# Phase 4: Client, Skills, and Workspace Profiles - Context

**Gathered:** 2026-06-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 makes declaratively selected AI client configuration, portable skills,
and workspace conventions first-class resources in the existing preview-first,
journaled plan/apply engine. It must detect and repair drift while preserving
unrelated user state. Broader diagnostics, release automation, and fleet
management remain later-phase work.

</domain>

<decisions>
## Implementation Decisions

### Golden-Path Profile
- **D-01:** Preserve `full` as the declarative golden-path profile; do not add a
  duplicate `golden-path` profile name. It must continue to select
  `cas-platform`, `cas-contracts`, `cas-evals`, and `cas-reference-product`.
- **D-02:** Client, skill, and workspace operations are derived only from the
  selected profile and manifest catalogs. No adapter may hard-code profile
  membership.

### Client Configuration Ownership
- **D-03:** Each supported client uses an explicit adapter that previews,
  validates, backs up, atomically applies, verifies, and surgically removes
  only CAS-owned configuration.
- **D-04:** CAS-owned client configuration is namespaced and carries stable
  ownership and content-digest evidence. Unrelated keys and user changes are
  preserved during apply, repair, and removal.
- **D-05:** Existing user-owned targets require a recoverable backup before
  first modification. Backups are recovery evidence, not permission to replace
  later unrelated user changes during uninstall.

### Skills and Workspaces
- **D-06:** Skills and workspace conventions are installed only from
  allowlisted manifest sources into approved CAS-managed boundaries.
- **D-07:** Skill and workspace resources receive the same deterministic plan,
  ownership-ledger, drift-digest, safe-path, and uninstall-only-owned behavior
  as other managed resources.
- **D-08:** Existing unowned skill or workspace targets fail closed on conflict;
  CAS does not silently adopt or overwrite them.

### MCP Security Boundary
- **D-09:** MCP configuration explicitly labels local workstation transports
  (`stdio`) separately from production remote transports (`http` or `sse`).
- **D-10:** Generated configuration may contain non-secret authentication
  references or instructions, but never credentials, access tokens, API keys,
  or embedded secrets.

### Planning, Drift, and Recovery
- **D-11:** Clients, skills, and workspaces become typed operations in
  `New-CasOperationPlan` and execute through `Invoke-CasOperationPlan`; direct
  mutation helpers must not bypass preview, journal, or correlation evidence.
- **D-12:** Inventory compares canonical managed content digests and reports
  satisfied, missing, drifted, conflicting, or unsupported state. Repair
  reconciles only CAS-owned drift.

### the agent's Discretion
- Exact adapter function decomposition, namespaced JSON shape, and manifest
  property names, provided they remain PowerShell 5.1-compatible,
  deterministic, schema-validated, and fail closed.
- Whether the first implementation plan separates client adapters from
  skill/workspace adapters, provided all CFG-01 through CFG-05 requirements are
  covered by the completed phase.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product and Requirements
- `.planning/ROADMAP.md` - Phase 4 goal and success criteria.
- `.planning/REQUIREMENTS.md` - CFG-01 through CFG-05.
- `.planning/PROJECT.md` - Configuration, safety, state, and authentication constraints.
- `AGENTS.md` - Repository engineering rules and mandatory GSD workflow.

### Prior Decisions and Current Contracts
- `.planning/phases/02-manifest-inventory-and-safety-boundaries/02-CONTEXT.md` - Fail-closed manifest, ownership, path, backup, and uninstall decisions.
- `.planning/phases/03-transactional-plan-and-apply-engine/03-CONTEXT.md` - Deterministic plan/apply, journal, resume, and repair decisions.
- `stack.manifest.json` - Current profiles, client, skill, workspace, and MCP declarations.
- `schemas/manifest.schema.json` - Manifest contract to extend safely.
- `schemas/managed-state.schema.json` - Ownership and digest evidence contract.
- `schemas/operation-plan.schema.json` - Typed operation-plan contract.

### Existing Implementation and Verification
- `scripts/Cas.Workstation.psm1` - Desired-state resolution, safety, atomic writes, ownership, planner, apply engine, and legacy client-fragment generator.
- `tests/Manifest.Tests.ps1` - Declarative resolution and allowlist tests.
- `tests/Plan.Tests.ps1` - Deterministic planning and idempotency tests.
- `tests/Apply.Tests.ps1` - Journaled apply and failure behavior tests.
- `tests/Safety.Tests.ps1` - Atomic backup and ownership-ledger tests.
- `tests/Uninstall.Tests.ps1` - Ledger-only removal and restoration tests.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Resolve-CasDesiredState` already resolves clients, skills, and workspaces
  deterministically from profile declarations.
- `Write-CasAtomicJson`, `Add-CasManagedResource`, and
  `Write-CasManagedState` provide backup, ownership, and atomic-write
  foundations.
- `New-CasOperationPlan` and `Invoke-CasOperationPlan` provide deterministic
  preview and journaled execution extension points.
- `New-CasClientConfigs` provides legacy isolated fragment behavior that can be
  replaced or wrapped by typed client adapters.

### Established Patterns
- Schema plus semantic validation occurs before external execution.
- All mutation targets are revalidated against approved boundaries.
- Satisfied resources produce deterministic `skip` operations.
- Uninstall acts only on current ownership-ledger evidence.

### Integration Points
- Extend manifest client, skill, workspace, and MCP definitions without
  hard-coding selected resources.
- Extend inventory and planner switches for client, skill, and workspace
  operation kinds.
- Register ownership and content digests after successful adapter execution.
- Keep `setup.ps1`, `upgrade.ps1`, and `repair.ps1` as thin entry points over
  the shared operation engine.

</code_context>

<specifics>
## Specific Ideas

- The public portfolio golden path remains the existing `full` profile and the
  four already-declared CAS repositories.
- Local `stdio` MCP is valid for workstation integration but must not be
  presented as the production remote architecture.

</specifics>

<deferred>
## Deferred Ideas

- Rich doctor findings and support bundles belong to Phase 5.
- Clean-machine end-to-end proof and trusted release artifacts belong to Phase 6.
- Central profile distribution and fleet management remain v2 (`PLAT-03`).

</deferred>

---

*Phase: 04-client-skills-and-workspace-profiles*
*Context gathered: 2026-06-13*
