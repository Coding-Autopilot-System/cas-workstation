# Requirements: CAS Workstation

**Defined:** 2026-06-11  
**Core Value:** An AI developer can run one safe, repeatable workflow and receive a complete, working workstation without manually discovering or reconciling prerequisites.

## v1 Requirements

### Governance and Contracts

- [x] **GOV-01**: Maintainer can validate manifest, managed state, operation plan, doctor report, event log, and support-bundle metadata against versioned JSON schemas.
- [x] **GOV-02**: Contributor can run Pester, PSScriptAnalyzer, schema validation, and documentation checks locally through one documented command.
- [x] **GOV-03**: Pull requests run required Windows CI checks with least-privilege permissions, pinned actions, timeouts, and retained evidence.
- [x] **GOV-04**: Maintainer can trace requirements to phases, tests, architecture decisions, and release evidence.

### Manifest and Profiles

- [x] **MAN-01**: User receives actionable errors when a manifest or selected profile is invalid.
- [x] **MAN-02**: Profile resolves explicit required and optional tools, repositories, services, clients, skills, and workspaces from declarative data.
- [x] **MAN-03**: Only allowlisted installer kinds, package identities, repositories, commands, and configuration targets can enter an execution plan.
- [x] **MAN-04**: User can inspect the fully resolved desired state and its deterministic digest before mutation.
- [x] **MAN-05**: Compatibility checks identify unsupported host, PowerShell, architecture, dependency, and version combinations before apply.

### Safety and State

- [x] **SAFE-01**: Every filesystem mutation validates canonical path boundaries and rejects forbidden or escaping targets.
- [x] **SAFE-02**: CAS records a versioned ownership ledger for every resource it creates or modifies.
- [x] **SAFE-03**: Uninstall preview lists intended removals and uninstall removes only ownership-ledger resources after explicit intent.
- [x] **SAFE-04**: CAS never claims ownership of tools, repositories, files, or configuration that existed before CAS management.
- [x] **SAFE-05**: User-owned files touched by CAS are backed up and replaced atomically only after validation.

### Setup, Upgrade, and Recovery

- [ ] **OPS-01**: User can run one documented interactive or non-interactive setup command with equivalent outcomes.
- [ ] **OPS-02**: Setup and upgrade first produce a deterministic operation plan showing changes, skips, commands, sources, and risks.
- [ ] **OPS-03**: Re-running setup or upgrade on satisfied desired state performs no unintended mutations.
- [ ] **OPS-04**: Every external process and network-affecting operation emits observable, correlated, auditable events.
- [ ] **OPS-05**: Partial failure leaves a durable journal and actionable resume, retry, or rollback guidance.
- [ ] **OPS-06**: Repository synchronization detects dirty/diverged state and refuses destructive reconciliation by default.
- [ ] **OPS-07**: User can run a repair command that safely reconciles detected drift through the same plan/apply engine.

### Client and Workspace Integration

- [ ] **CFG-01**: CAS generates profile-specific configuration for supported AI clients without overwriting unrelated user configuration.
- [ ] **CFG-02**: User can preview, validate, apply, and remove only CAS-owned client configuration.
- [ ] **CFG-03**: Profiles install and validate portable agent skills and workspace conventions from allowlisted sources.
- [ ] **CFG-04**: MCP configuration clearly distinguishes local workstation transports from production remote transports and never embeds secrets.
- [ ] **CFG-05**: Configuration adapters detect drift and preserve recoverable backups.

### Diagnostics and Support

- [ ] **DIAG-01**: Doctor emits concise human-readable output and schema-valid JSON with stable status and exit-code semantics.
- [ ] **DIAG-02**: Doctor verifies tools, versions, repositories, services, managed state, configuration, skills, workspaces, and relevant runtime health.
- [ ] **DIAG-03**: Diagnostic findings include safe, actionable remediation linked to the operation planner.
- [ ] **DIAG-04**: Operations write structured logs with correlation IDs, timing, outcome, and redacted command/source metadata.
- [ ] **DIAG-05**: User can generate and preview a redacted, schema-valid support bundle that excludes secrets and unrelated user data.

### Release and Verification

- [ ] **REL-01**: Maintainer can create a reproducible versioned release with changelog, checksums, SBOM, provenance, and signed artifacts.
- [ ] **REL-02**: Release CI proves clean-machine setup, repeat setup, upgrade, doctor, repair/recovery, preview uninstall, uninstall, and preservation of unrelated data.
- [ ] **REL-03**: Published documentation defines architecture, threat model, support matrix, contribution workflow, release process, recovery, and rollback.
- [ ] **REL-04**: User can verify release integrity and understand support and security-reporting channels before installation.

## v2 Requirements

### Platform Expansion

- **PLAT-01**: User can bootstrap a supported macOS host.
- **PLAT-02**: User can bootstrap a supported Linux host.
- **PLAT-03**: Administrator can manage a workstation fleet through centrally governed profiles.

### Experience

- **EXP-01**: User can operate CAS Workstation through a graphical installer.
- **EXP-02**: User can consume hosted remote MCP services with enterprise OAuth or managed identity.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Automatic credential provisioning | Authentication must remain user-controlled or use managed identity |
| Silent mutation or removal | Conflicts with safety, auditability, and primary-workstation trust |
| First-class macOS/Linux v1 hosts | Windows reliability is the product boundary for v1 |
| Fleet management | Individual developer workstation is the initial target |
| GUI installer | Scriptable, testable PowerShell workflows have higher v1 value |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GOV-01 | Phase 1 | Complete |
| GOV-02 | Phase 1 | Complete |
| GOV-03 | Phase 1 | Complete |
| GOV-04 | Phase 1 | Complete |
| MAN-01 | Phase 2 | Complete |
| MAN-02 | Phase 2 | Complete |
| MAN-03 | Phase 2 | Complete |
| MAN-04 | Phase 2 | Complete |
| MAN-05 | Phase 2 | Complete |
| SAFE-01 | Phase 2 | Complete |
| SAFE-02 | Phase 2 | Complete |
| SAFE-03 | Phase 2 | Complete |
| SAFE-04 | Phase 2 | Complete |
| SAFE-05 | Phase 2 | Complete |
| OPS-01 | Phase 3 | Pending |
| OPS-02 | Phase 3 | Pending |
| OPS-03 | Phase 3 | Pending |
| OPS-04 | Phase 3 | Pending |
| OPS-05 | Phase 3 | Pending |
| OPS-06 | Phase 3 | Pending |
| OPS-07 | Phase 3 | Pending |
| CFG-01 | Phase 4 | Pending |
| CFG-02 | Phase 4 | Pending |
| CFG-03 | Phase 4 | Pending |
| CFG-04 | Phase 4 | Pending |
| CFG-05 | Phase 4 | Pending |
| DIAG-01 | Phase 5 | Pending |
| DIAG-02 | Phase 5 | Pending |
| DIAG-03 | Phase 5 | Pending |
| DIAG-04 | Phase 5 | Pending |
| DIAG-05 | Phase 5 | Pending |
| REL-01 | Phase 6 | Pending |
| REL-02 | Phase 6 | Pending |
| REL-03 | Phase 7 | Pending |
| REL-04 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35
- Unmapped: 0

---
*Requirements defined: 2026-06-11*  
*Last updated: 2026-06-11 after roadmap creation*
