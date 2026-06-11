# Phase 2: Manifest, Inventory, and Safety Boundaries - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 establishes the fail-closed contracts and reusable domain functions that resolve declarative desired state, inventory compatibility, validate filesystem boundaries, record ownership, and restrict uninstall to ledger-owned resources. Transactional setup, upgrade, repair, and broad client configuration mutation remain later-phase work.

</domain>

<decisions>
## Implementation Decisions

### Manifest Resolution and Allowlists
- **D-01:** Manifest JSON parsing and semantic validation must finish before any operational external process can run; malformed, unknown, duplicate, or unresolved identifiers fail with actionable errors.
- **D-02:** Profiles explicitly separate required and optional tools, repositories, services, clients, skills, and workspaces; resolution emits a normalized deterministic desired-state object.
- **D-03:** Installer kinds, package identities, repository URLs, command names, and configuration targets use deny-by-default allowlists encoded in the manifest contract and semantic validator.
- **D-04:** Desired-state digest is SHA-256 over canonical UTF-8 JSON with stable property and item ordering.

### Inventory and Compatibility
- **D-05:** Compatibility checks return structured findings for host OS, PowerShell version, architecture, dependencies, and tool versions; unsupported or unknown required compatibility fails closed.
- **D-06:** Existing resources are inventoried as observed and never automatically claimed as CAS-owned.

### Filesystem and Ownership Safety
- **D-07:** Every filesystem mutation target must be canonical, inside an explicitly approved CAS boundary, outside forbidden system/profile/drive roots, and free of existing reparse-point ancestors.
- **D-08:** Managed state is a versioned ownership ledger written atomically under the configured CAS state path; it distinguishes created, modified, and observed resources.
- **D-09:** User-owned files may be modified only after a recoverable backup is recorded and the replacement payload validates before atomic replacement.

### Uninstall
- **D-10:** Uninstall defaults to preview, requires explicit apply intent, and may remove or restore only resources proven by the ledger and revalidated against current path policy.
- **D-11:** Missing, malformed, ambiguous, or unsafe ownership evidence blocks uninstall rather than widening removal scope.

### the agent's Discretion
- Exact internal PowerShell function decomposition and user-facing wording, provided behavior remains PowerShell 5.1-compatible, testable, deterministic, and fail closed.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product and Requirements
- `.planning/ROADMAP.md` - Phase 2 goal and success criteria.
- `.planning/REQUIREMENTS.md` - MAN-01 through MAN-05 and SAFE-01 through SAFE-05.
- `.planning/PROJECT.md` - Product safety, configuration, and state constraints.
- `AGENTS.md` - Repository engineering and verification rules.

### Existing Contracts and Implementation
- `stack.manifest.json` - Current declarative seed manifest.
- `schemas/manifest.schema.json` - Existing manifest contract to strengthen.
- `schemas/managed-state.schema.json` - Existing ownership contract to strengthen.
- `scripts/Cas.Workstation.psm1` - Existing manifest, inventory, and mutation functions.
- `uninstall.ps1` - Existing unsafe recursive-removal entry point to replace.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Get-CasManifest`, `Get-CasProfile`, and profile lookup helpers provide the integration surface for validated resolution.
- `Get-CasToolStatus` and `Get-CasRepoStatus` provide seed inventory behavior to wrap in compatibility findings.
- Phase 1 schema fixtures, Pester suite, and `Invoke-Quality.ps1` provide executable contract and verification infrastructure.

### Established Patterns
- Public behavior lives in `scripts/Cas.Workstation.psm1` and is exposed through thin root scripts.
- JSON contracts use Draft 2020-12 schemas and positive/negative fixtures.
- Full quality validation is repository-local and non-interactive.

### Integration Points
- `setup.ps1`, `upgrade.ps1`, `doctor.ps1`, and `uninstall.ps1` import the shared module.
- Managed state belongs below the manifest-configured state directory.
- Phase 3 will consume resolved desired state, inventory, and safety policies when it builds plans and applies mutations.

</code_context>

<specifics>
## Specific Ideas

- Preserve unrelated user state even when the ledger or target paths are damaged.
- Favor structured result objects that later plan/apply and doctor workflows can consume.

</specifics>

<deferred>
## Deferred Ideas

- Transactional operation planning, apply, resume, retry, and rollback belong to Phase 3.
- Client-native merge adapters and skill/workspace installation belong to Phase 4.

</deferred>

---

*Phase: 02-manifest-inventory-and-safety-boundaries*
*Context gathered: 2026-06-11*
