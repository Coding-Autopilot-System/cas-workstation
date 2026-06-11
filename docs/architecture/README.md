# Architecture Decision Records

CAS Workstation uses lightweight Architecture Decision Records (ADRs) for decisions that constrain security, compatibility, contracts, or operations.

## Lifecycle

1. Copy `decisions/0000-template.md` to the next numbered file.
2. Describe the context, decision, consequences, and verification evidence.
3. Open a pull request and link affected requirement IDs.
4. Use one status: `Proposed`, `Accepted`, `Superseded`, or `Rejected`.
5. Supersede accepted decisions with a new ADR instead of rewriting history.

Accepted ADRs must name executable evidence when the decision can be tested. Requirement evidence is tracked in `docs/traceability.json` and validated by `scripts/Test-CasGovernance.ps1`.

