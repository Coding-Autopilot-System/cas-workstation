# Phase 3 Research: Transactional Plan and Apply Engine

## Recommended Design

Use a PowerShell orchestration core with serializable plan, journal, and event
contracts. Keep external execution behind an injected operation handler so
Pester can prove behavior without installing packages or contacting networks.

## Key Risks

- Random identifiers or timestamps in plan identity break deterministic preview.
- Treating command presence as desired-state satisfaction breaks idempotency.
- Git pull against dirty or diverged repositories can destroy user work.
- Writing journal state only after an operation loses recovery evidence.
- Unbounded retry can repeat unsafe external side effects.

## Verification Strategy

- Compare canonical plan JSON from equivalent interactive/non-interactive calls.
- Apply a synthetic plan twice and assert the second plan contains skips only.
- Inject operation failure and prove journal/event correlation and resume scope.
- Exercise dirty, detached, unexpected-branch, and diverged Git status parsing.
