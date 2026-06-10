# Architecture Research

## Recommended Architecture

Use a layered PowerShell architecture with pure decision logic separated from side-effect adapters.

1. **Contracts**: schemas and typed validation for manifest, profiles, state, plans, reports, and events.
2. **Domain**: desired-state resolution, dependency graph, decisions, ownership rules, path policy, and drift comparison.
3. **Planning**: convert desired and actual state into an ordered, reviewable operation plan.
4. **Execution**: apply operations through adapters with correlation IDs, journal checkpoints, retries, and fail-closed behavior.
5. **Adapters**: WinGet, Scoop, npm, Git, filesystem, services, WSL, AI clients, and process execution.
6. **Presentation**: setup, upgrade, doctor, repair, start, uninstall, support bundle, and JSON output.

## Core Data Flow

`manifest + selected profile -> validated desired state -> inventory actual state -> operation plan -> approved apply -> managed-state journal -> doctor evidence`

## Managed State

The state ledger should record:

- Bundle, schema, and product version.
- Selected profile and resolved desired-state digest.
- Every CAS-created path, file fragment, repository, and configuration mutation.
- Package observations, without claiming ownership of pre-existing tools.
- Operation history, correlation IDs, status, and recovery checkpoints.
- Backups and rollback metadata for user-owned files touched through adapters.

## Safety Boundaries

- Canonicalize paths before comparison or mutation.
- Reject roots that equal drive roots, profile roots, system directories, or escape configured CAS boundaries.
- Separate discovery, planning, approval, and apply.
- Never construct shell command strings from untrusted manifest values.
- Validate allowlisted installer/repository identity before process execution.
- Require explicit force/confirmation only after ownership and boundary checks pass.

## Client Configuration

Each AI client needs a dedicated adapter that:

- Reads and validates the native format.
- Maintains a named CAS-owned section or fragment.
- Preserves unrelated settings byte-semantically where feasible.
- Produces a preview and backup.
- Writes atomically and verifies the result.
- Can remove only the CAS-owned portion.

## Release Architecture

- Source tag triggers repeatable packaging.
- CI emits module/scripts, schemas, documentation, checksums, SBOM, provenance, and test evidence.
- A clean Windows environment verifies install, repeat install, upgrade, doctor, support bundle, preview uninstall, uninstall, and post-uninstall preservation.
