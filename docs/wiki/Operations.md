# Operations

## Contributor quality gate

The repository requires Pester 5.7+, PSScriptAnalyzer 1.24+, Python 3.12+, and the Python
`jsonschema` package. Run the same gate used by CI:

```powershell
.\Invoke-Quality.ps1
```

This runs tests, static analysis, contract fixtures, and governance validation. Machine-readable
evidence is written under `.artifacts/quality/`. It fails closed when a required validator or
check is unavailable.

## CI gate (`.github/workflows/quality.yml`)

Runs on `windows-latest`:

```powershell
Install-Module Pester -MinimumVersion 5.7.1 -Scope CurrentUser -Force
Install-Module PSScriptAnalyzer -MinimumVersion 1.24.0 -Scope CurrentUser -Force
python -m pip install --disable-pip-version-check jsonschema==4.26.0
.\Invoke-Quality.ps1
```

Quality evidence is uploaded as a CI artifact (`.artifacts/quality`, `if-no-files-found: error`).
There is no coverage-percentage gate in this repo's CI as of this writing — `Invoke-Quality.ps1`
is a pass/fail composite of tests, static analysis, contract fixtures, and governance checks.

## Other CI workflows

| Workflow | Purpose |
|---|---|
| `codeql.yml` | CodeQL static analysis |
| `pr-lint.yml` | PR metadata/title linting |
| `stale.yml` | Stale issue/PR sweep |
| `pages.yml` | Publishes docs to GitHub Pages |

## Typical flow

```powershell
.\setup.ps1 -NonInteractive
.\doctor.ps1
.\start.ps1
```

## Inspect desired state

```powershell
Import-Module .\scripts\Cas.Workstation.psm1 -Force
$manifest = Get-CasManifest
Resolve-CasDesiredState -Profile core -Manifest $manifest
```

## Plan, apply, and recover

```powershell
.\setup.ps1 -Profile full
.\upgrade.ps1 -Profile full
.\repair.ps1 -Profile full
```

Apply with explicit intent:

```powershell
.\setup.ps1 -Profile full -Apply
.\repair.ps1 -Profile full -Apply -Resume
```

## Safe uninstall

```powershell
.\uninstall.ps1
.\uninstall.ps1 -Apply
```

Preview-only by default; acts only on resources proven by the managed-state ledger. Observed
resources are preserved; modified resources require a recorded backup; created directories are
removed only when empty.

<!-- docs-verified: 4c70f86190c6cd2333fb6357a5928fbb904776ef 2026-07-08 -->
