# CAS Workstation Agent Instructions

## Product Standard

CAS Workstation is a public, Windows-first enterprise bootstrap product for
AI-native developers. Changes must be safe, idempotent, testable, and suitable
for execution on a developer's primary workstation.

## Engineering Rules

- Never embed credentials, access tokens, or machine-specific secrets.
- Default destructive operations to dry-run or explicit confirmation.
- Keep installation state and generated configuration under the configured CAS
  root and profile paths.
- Prefer declarative manifest data over hard-coded tool or repository lists.
- Validate manifest and doctor output against their JSON schemas.
- Add Pester tests for PowerShell behavior and failure paths.
- Preserve support for non-interactive CI validation.

## Verification

Run the strongest available checks before committing:

```powershell
Invoke-Pester
.\doctor.ps1 -JsonPath .artifacts\doctor.json
```

