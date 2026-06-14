# Phase 4: Client, Skills, and Workspace Profiles - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents. Decisions are captured in CONTEXT.md.

**Date:** 2026-06-13
**Phase:** 04-client-skills-and-workspace-profiles
**Mode:** `$gsd-discuss-phase 4 --auto`
**Areas discussed:** golden-path profile, client ownership, skills and
workspaces, MCP boundaries, drift and recovery

---

## Golden-Path Profile

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve `full` | Keep the existing profile as the single declarative golden path | Yes |
| Add `golden-path` | Add a duplicate profile selecting the same repositories | No |

**Auto-selected choice:** Preserve `full`.
**Notes:** The current manifest and README already establish `full` as the
golden path and include the four cross-repository proof components.

## Client Configuration Ownership

| Option | Description | Selected |
|--------|-------------|----------|
| Namespaced surgical merge | Preserve unrelated settings and remove only CAS-owned entries | Yes |
| Replace complete client files | Treat the whole client file as CAS-owned | No |
| Isolated fragments only | Generate fragments without supported merge/apply behavior | No |

**Auto-selected choice:** Namespaced surgical merge.
**Notes:** Existing user files require backups, atomic writes, and stable
ownership/content-digest evidence.

## Skills and Workspaces

| Option | Description | Selected |
|--------|-------------|----------|
| First-class managed resources | Plan, journal, validate, repair, and uninstall only owned resources | Yes |
| Best-effort copy helpers | Copy selected content outside the plan/apply engine | No |

**Auto-selected choice:** First-class managed resources.
**Notes:** Conflicting unowned targets fail closed.

## MCP Boundaries

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit transport and auth boundary | Label local versus remote transports and prohibit embedded secrets | Yes |
| Uniform opaque server entries | Treat all MCP transports and authentication alike | No |

**Auto-selected choice:** Explicit transport and auth boundary.
**Notes:** Local workstation `stdio` remains valid, while production remote MCP
must use an external secure identity model.

## Drift and Recovery

| Option | Description | Selected |
|--------|-------------|----------|
| Canonical digest plus owned repair | Detect drift and reconcile only CAS-owned content | Yes |
| Overwrite desired files on repair | Replace complete files whenever drift exists | No |

**Auto-selected choice:** Canonical digest plus owned repair.
**Notes:** All operations remain preview-first and journaled.

## the agent's Discretion

- Exact adapter decomposition and manifest property names.
- Plan split, provided all Phase 4 requirements are covered.

## Deferred Ideas

- Phase 5 diagnostics and support bundles.
- Phase 6 clean-machine and trusted-release evidence.
- v2 centrally governed workstation fleets.
