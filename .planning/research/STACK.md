# Stack Research

## Recommended Baseline

| Area | Choice | Rationale |
|------|--------|-----------|
| Host automation | PowerShell 5.1-compatible modules and advanced scripts | Native Windows reach, supports interactive and unattended execution |
| Package sources | WinGet and Scoop adapters behind a common interface | Existing ecosystem fit while keeping source policy declarative |
| Test framework | Pester 5 with isolated filesystem/process seams | Standard PowerShell behavior, failure-path, and contract testing |
| Static quality | PSScriptAnalyzer plus strict mode | Catches common correctness and maintainability defects |
| Contracts | JSON Schema Draft 2020-12 | Existing doctor schema uses this version; extend to manifest, state, plan, and support bundle |
| State | Versioned JSON operation journal with atomic replacement | Transparent, portable, inspectable, and recoverable without a database |
| Logging | Structured JSON Lines plus concise console rendering | Human operations and machine diagnostics from the same events |
| CI | GitHub Actions on Windows and Ubuntu for schema/docs portability | Primary behavior on Windows; cross-platform contract checks where useful |
| Release | GitHub Releases, signed checksums, SBOM, SLSA provenance | Public verifiability and supply-chain evidence |
| E2E | Disposable Windows VM runner/sandbox image | Proves clean-machine installation and uninstall behavior |

## Compatibility Policy

- Keep Windows PowerShell 5.1 compatibility until the support matrix explicitly changes.
- Test PowerShell 7 as the preferred development shell.
- Pin minimum supported tool versions in the manifest, but resolve installers through allowlisted adapters.
- Keep WSL as an optional managed dependency, never the primary control plane.

## Avoid

- Embedding package-manager commands throughout orchestration logic.
- Treating command presence as proof that an installation is healthy.
- Writing directly to mutable JSON state without atomic replace and backup.
- Using local `stdio` MCP as the implied production architecture; document it as workstation-local only.

## Primary References

- Microsoft WinGet configuration: https://learn.microsoft.com/windows/package-manager/configuration/
- PowerShell `SupportsShouldProcess`: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute
- Pester documentation: https://pester.dev/docs/introduction
- JSON Schema 2020-12: https://json-schema.org/draft/2020-12
- SLSA provenance: https://slsa.dev/spec/
