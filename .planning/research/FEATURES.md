# Feature Research

## Table Stakes

### Safe Bootstrap

- One setup command with interactive and non-interactive modes.
- Preflight validation before mutation.
- Plan/preview output that shows tools, repositories, files, services, and commands.
- Idempotent apply that skips satisfied desired state.
- Durable journal and resume guidance after partial failure.

### Declarative Composition

- Versioned schemas for manifest, profiles, managed state, operation plan, doctor report, and support bundle.
- Explicit allowlists for installers, repositories, commands, clients, services, skills, and workspaces.
- Profile inheritance or composition without duplicated lists.
- Clear support policy for optional versus required components.

### Safe Configuration

- Per-client adapters that preserve unrelated user settings.
- Owned fragments with deterministic merge and rollback.
- Validation before write, backup before replacement, and atomic commit.
- Drift detection between desired, managed, and actual state.

### Operability

- Doctor with human and machine-readable reports.
- Structured event logs with operation and correlation IDs.
- Recovery and repair commands.
- Redacted support bundles.
- Upgrade planning and compatibility checks.

### Enterprise Delivery

- Pester tests, schema tests, static analysis, documentation checks, and clean-machine E2E.
- Signed releases, checksums, SBOM, provenance, changelog, and rollback instructions.
- Architecture, ADRs, threat model, contribution guide, and release/support policies.

## Differentiators

- AI-native profiles that install tools, repos, MCP connections, portable skills, workspace conventions, and verified runtime prerequisites together.
- Evidence-driven readiness report explaining not only what is missing, but the exact safe remediation.
- Portfolio-quality traceability from product requirements to tests, release evidence, and support boundaries.
- Strict ownership ledger allowing uninstall and repair to affect only CAS-managed resources.

## Deferred Features

- GUI installation wizard.
- Remote fleet orchestration.
- Automatic authentication and secret brokering.
- macOS and Linux host parity.
- Hosted remote MCP control plane.
