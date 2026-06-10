# Roadmap: CAS Workstation

## Overview

CAS Workstation v1 progresses from a functional seed to a trustworthy desired-state workstation product. The sequence establishes enforceable contracts and safety before broadening mutation, then adds recoverable orchestration, integrations, diagnostics, release proof, and public operational documentation.

## Phases

| Phase | Name | Goal | Requirements | Count |
|-------|------|------|--------------|-------|
| 1 | Governance and Quality Foundation | Establish enforceable contracts, test seams, CI, and traceability | GOV-01, GOV-02, GOV-03, GOV-04 | 4 |
| 2 | Manifest, Inventory, and Safety Boundaries | Make desired state, ownership, paths, and destructive operations fail closed | MAN-01..05, SAFE-01..05 | 10 |
| 3 | Transactional Plan and Apply Engine | Deliver idempotent setup, upgrade, repair, and recovery | OPS-01..07 | 7 |
| 4 | Client, Skills, and Workspace Profiles | Safely integrate supported AI clients and portable developer context | CFG-01..05 | 5 |
| 5 | Diagnostics and Supportability | Make readiness, drift, failures, and support evidence actionable | DIAG-01..05 | 5 |
| 6 | Trusted Release and Clean-Machine Proof | Produce verifiable releases and end-to-end operational evidence | REL-01, REL-02 | 2 |
| 7 | Public Architecture and Operations Evidence | Complete the documentation and support surface required for adoption | REL-03, REL-04 | 2 |

## Phase Details

### Phase 1: Governance and Quality Foundation

**Goal:** Every later change is constrained by schemas, tests, static quality, CI, and requirement traceability.

**Requirements:** GOV-01, GOV-02, GOV-03, GOV-04

**Success criteria:**
1. One documented local command runs Pester, PSScriptAnalyzer, schemas, and documentation validation.
2. Windows CI enforces the same checks with pinned actions, least privilege, timeouts, and retained evidence.
3. Versioned schemas exist for all planned product contracts, with positive and negative fixtures.
4. Architecture decision and requirement traceability conventions are documented and tested.

### Phase 2: Manifest, Inventory, and Safety Boundaries

**Goal:** CAS can safely resolve desired state, inventory actual state, and prove ownership and path safety before mutation.

**Requirements:** MAN-01, MAN-02, MAN-03, MAN-04, MAN-05, SAFE-01, SAFE-02, SAFE-03, SAFE-04, SAFE-05

**Success criteria:**
1. Invalid or unallowlisted manifest/profile content fails before external process execution.
2. Resolved desired state and digest are deterministic and inspectable.
3. Canonical path and ownership policies reject forbidden, escaping, junction, and unrelated targets.
4. Uninstall preview and apply can affect only ledger-owned resources, with backup and atomic-write contracts verified.

### Phase 3: Transactional Plan and Apply Engine

**Goal:** Setup, upgrade, and repair use one observable, idempotent, recoverable plan/apply engine.

**Requirements:** OPS-01, OPS-02, OPS-03, OPS-04, OPS-05, OPS-06, OPS-07

**Success criteria:**
1. Interactive and non-interactive setup produce equivalent deterministic plans and outcomes.
2. Reapplying satisfied desired state produces no unintended changes.
3. Every operation is correlated and journaled with safe failure, resume, retry, or rollback guidance.
4. Dirty or diverged repositories and risky external operations fail closed by default.

### Phase 4: Client, Skills, and Workspace Profiles

**Goal:** Profiles safely install and maintain the AI-native context developers need without clobbering user configuration.

**Requirements:** CFG-01, CFG-02, CFG-03, CFG-04, CFG-05

**Success criteria:**
1. Each supported client adapter previews, validates, backs up, atomically merges, verifies, and removes only CAS-owned configuration.
2. Profiles declaratively install and validate allowlisted portable skills and workspace conventions.
3. Drift is detected and repairable without overwriting unrelated settings.
4. MCP configuration documents transport/security boundaries and contains no embedded secrets.

### Phase 5: Diagnostics and Supportability

**Goal:** Users and maintainers can understand readiness, drift, failures, and safe remediation from trustworthy evidence.

**Requirements:** DIAG-01, DIAG-02, DIAG-03, DIAG-04, DIAG-05

**Success criteria:**
1. Doctor covers all managed resource categories and emits stable schema-valid JSON and exit codes.
2. Findings link to safe planner-backed remediation.
3. Structured logs provide correlated outcomes without leaking seeded secrets.
4. A previewable support bundle is schema-valid, redacted, and excludes unrelated user data.

### Phase 6: Trusted Release and Clean-Machine Proof

**Goal:** Every published version is reproducible, verifiable, and proven on a disposable clean Windows environment.

**Requirements:** REL-01, REL-02

**Success criteria:**
1. Release automation emits changelog, checksums, SBOM, provenance, signatures, test evidence, and reproducible artifacts.
2. A clean Windows journey verifies setup, repeat setup, upgrade, doctor, recovery/repair, preview uninstall, uninstall, and unrelated-data preservation.
3. Failed release gates cannot publish artifacts.

### Phase 7: Public Architecture and Operations Evidence

**Goal:** A prospective user, contributor, employer, or security reviewer can understand how CAS works, its boundaries, and how it is operated.

**Requirements:** REL-03, REL-04

**Success criteria:**
1. Published docs cover architecture, ADRs, threat model, support matrix, contribution, release, recovery, rollback, and security reporting.
2. Installation docs explain release integrity verification and authentication boundaries before mutation.
3. Documentation claims are validated against commands, schemas, and release evidence.

## Requirement Coverage

- v1 requirements: 35
- Requirements mapped exactly once: 35
- Unmapped requirements: 0
- Duplicate mappings: 0

---
*Roadmap created: 2026-06-11*
