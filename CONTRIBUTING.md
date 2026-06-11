# Contributing to CAS Workstation

## Quality Gate

Install the prerequisites documented in `README.md`, then run:

```powershell
.\Invoke-Quality.ps1
```

The command is the authoritative local and CI gate. It must pass before a pull request is ready for review.

## Change Standard

- Keep PowerShell 5.1 compatibility unless an accepted ADR changes the support boundary.
- Add Pester coverage for behavior and failure paths.
- Update schemas and positive/negative fixtures when contracts change.
- Update `docs/traceability.json` when requirement evidence changes.
- Create or supersede an ADR when a change alters security, compatibility, contracts, or operational boundaries.
- Do not embed credentials, tokens, or machine-specific profile paths.

Pull requests should explain the requirement IDs addressed, risk boundaries, verification commands, and deferred work.

