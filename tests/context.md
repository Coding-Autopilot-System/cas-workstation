# Testing Context

## Technology Stack
- **Test framework**: Pester 5 with isolated filesystem/process seams. Standard PowerShell behavior, failure-path, and contract testing.
- **Static quality**: PSScriptAnalyzer plus strict mode. Catches common correctness and maintainability defects.
- **E2E**: Disposable Windows VM runner/sandbox image for proving clean-machine installation.

## Verification
Run the strongest available checks before committing:
```powershell
Invoke-Pester
.\doctor.ps1 -JsonPath .artifacts\doctor.json
```
