# Pitfalls Research

## Critical Risks

### Unsafe Recursive Removal

Accepting arbitrary roots and calling recursive removal can destroy unrelated data. Mitigate with canonical path policy, forbidden roots, ownership ledger validation, explicit preview, and tests covering junctions, symlinks, traversal, casing, and alternate separators.

### Configuration Clobbering

Serializing a new object over a user-owned client config loses unrelated settings and formatting. Use client adapters, CAS-owned sections/fragments, backup, preview, atomic write, and round-trip tests.

### False Idempotency

Skipping when a command exists does not prove correct version, source, architecture, health, or configuration. Inventory must compare desired and actual state and explain every decision.

### Partial Failure Without Recovery

Package installation and repository mutation can fail halfway through. Journal each operation before and after apply, preserve resumable state, and distinguish reversible from non-reversible actions.

### Supply-Chain Blindness

Executing mutable package identifiers, npm packages, Git branches, and downloads without provenance creates avoidable risk. Require allowlists, pinned identities where practical, observable process execution, checksums/signatures for direct downloads, and release provenance.

### Secret Leakage

Logs and support bundles can capture environment variables, paths, tokens, Git remotes, or client configs. Use explicit redaction rules, denylist sensitive artifacts, tests with seeded secrets, and user preview.

### CI That Never Proves Installation

Unit tests alone cannot establish workstation correctness. Add disposable Windows clean-machine journeys and validate repeat setup, upgrade, recovery, and uninstall preservation.

## Current Seed Gaps

- No Pester suite or CI.
- No manifest/state/plan/support-bundle schemas.
- Installer execution lacks a preflight plan and durable journal.
- Repository sync mutates working trees without dirty-state policy.
- Client config output is fragment-only and lacks merge adapters.
- Uninstall does not validate ownership or safe boundaries.
- Tool version parsing treats malformed/unknown versions as acceptable.
- No structured logs, support bundle, release evidence, or threat model.
