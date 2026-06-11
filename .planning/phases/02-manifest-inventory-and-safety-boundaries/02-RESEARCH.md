# Phase 2: Manifest, Inventory, and Safety Boundaries - Research

## Planning Question

How can CAS establish desired-state and ownership evidence that remains deterministic, inspectable, and safe enough to constrain every later workstation mutation?

## Recommended Approach

Build Phase 2 as three dependency-ordered layers:

1. Strengthen the manifest contract and implement semantic validation, normalized profile resolution, deterministic digesting, and structured compatibility inventory.
2. Implement canonical path policy, a versioned ownership ledger, and validated atomic writes with backups.
3. replace arbitrary recursive uninstall with ledger-only preview and explicit apply.

Keep these functions side-effect-light and independently testable. Phase 2 should not build the broader transactional operation engine; it should provide the safety and evidence primitives that engine must use.

## Manifest and Resolution

JSON Schema should reject unknown structural content, while PowerShell semantic validation should enforce relationships that schema cannot express cleanly: unique IDs, valid profile references, trusted repository origins, command identity, installer/package allowlists, and safe relative configuration targets.

Resolution should normalize all profile categories into required/optional entries, sort deterministically, and emit only explicit declarative data. Digest canonical UTF-8 JSON rather than raw source JSON so whitespace and property-order differences do not change desired identity.

## Compatibility and Inventory

Compatibility is evidence, not mutation. Return structured checks with `supported`, `unsupported`, or `unknown` status and actionable messages. Required unknowns fail closed. Existing tools, repositories, and files remain `observed`; CAS ownership begins only when a later CAS operation creates or explicitly modifies a resource and records evidence.

## Path Safety

Use `System.IO.Path.GetFullPath()` for lexical canonicalization, compare paths case-insensitively on Windows, and require a target to be strictly below an approved boundary. Reject drive roots, the user profile root, Windows and Program Files roots, traversal, and any existing target or ancestor carrying the `ReparsePoint` attribute. Revalidate immediately before mutation because paths can change after preview.

## Ownership and Atomic Writes

The ledger is authoritative for removal scope but is not sufficient alone: every target must also pass path policy at apply time. State writes use a sibling temporary file, validate the serialized content, then atomically replace or move it. Existing user-owned files require a backup record before replacement. Never mark a pre-existing resource as `created`.

## Uninstall

Preview is the default and must work without mutation. Apply requires an explicit switch and ShouldProcess confirmation. The uninstall operation loads and validates managed state, filters to actionable ownership classes, validates every path, and blocks the entire apply if any resource is ambiguous or unsafe. Modified user-owned files restore a recorded backup; observed resources are never removed.

## Threat Model

| Threat | Severity | Mitigation |
|---|---|---|
| Malicious manifest injects a command, package, repository, or path | Critical | Strict schema plus deny-by-default semantic allowlists before operational processes |
| Path traversal or junction redirects deletion outside CAS roots | Critical | Canonical boundary validation and reparse-point ancestor rejection at preview and apply |
| Corrupt ledger widens uninstall scope | Critical | Strict ledger validation and all-or-nothing fail-closed preview/apply |
| CAS claims pre-existing resources and later removes them | Critical | Inventory records `observed`; ownership claims require explicit creation/modification evidence |
| Interrupted state/config write corrupts user or CAS state | High | Validated sibling temp file, backup, atomic replacement, and cleanup |

## Verification Strategy

- Add focused Pester tests for valid and invalid manifest semantics, deterministic resolution/digest, compatibility outcomes, canonical paths, forbidden roots, traversal, reparse points, ownership rules, atomic write failure, uninstall preview, and explicit apply.
- Strengthen schema fixtures for the new manifest and ledger shape.
- Run the full `Invoke-Quality.ps1` gate and `git diff --check`.
- Keep tests isolated under Pester `TestDrive`; never mutate real user or system paths.

## Planning Implications

- Plan 02-01 establishes contract and desired-state primitives.
- Plan 02-02 depends on those contracts and establishes mutation safety primitives.
- Plan 02-03 depends on both and integrates ledger-only uninstall plus traceability.

