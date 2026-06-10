# Research Summary

CAS Workstation should evolve from a useful bootstrap script into a desired-state workstation product. The central architectural decision is a validated, declarative manifest feeding a plan/apply engine with a durable ownership and operation journal. That structure makes installation, upgrades, repair, diagnostics, and uninstall explainable and safe.

The highest-priority work is not adding more tools. It is establishing fail-closed contracts, path and ownership safety, test seams, CI, and an execution plan before allowing broader mutation. Client configuration must use dedicated merge adapters rather than replacement. Release trust requires signed artifacts, SBOM/provenance, and a clean Windows machine journey that proves repeatability and preservation.

## Recommended Sequence

1. Establish governance, contracts, test seams, and CI.
2. Harden manifest resolution, inventory, path policy, and ownership state.
3. Build plan/apply execution with journaling, idempotency, and recovery.
4. Add client, skill, workspace, and service profile adapters.
5. Complete doctor, structured logging, repair, and support bundles.
6. Add signed releases and clean-machine verification.
7. Finish architecture, threat model, operations, support, and contribution evidence.

## Planning Implications

- Safety and contracts are prerequisites for every mutating feature.
- Each phase must ship tests and update schemas/documentation.
- Clean-machine E2E is the final proof, not a substitute for unit and contract tests.
- No phase should broaden supported host platforms before Windows v1 is trustworthy.
