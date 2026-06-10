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

<!-- GSD:project-start source:PROJECT.md -->
## Project

**CAS Workstation**

CAS Workstation is a public, Windows-first enterprise bootstrap product that turns a clean developer workstation into a complete, validated AI-native development environment for the Coding-Autopilot-System ecosystem. It provides a single trustworthy surface to install, operate, diagnose, upgrade, recover, and safely remove declaratively selected tools, repositories, services, skills, and AI client configuration.

**Core Value:** An AI developer can run one safe, repeatable workflow and receive a complete, working workstation without manually discovering or reconciling prerequisites.

### Constraints

- **Platform**: Windows 11 and PowerShell 5.1+ are the supported v1 host contract — compatibility must be verified in CI and on clean machines.
- **Safety**: Destructive actions require explicit intent, CAS ownership evidence, and canonical path-boundary validation — primary workstations cannot tolerate unsafe cleanup.
- **Security**: No embedded credentials or tokens; downloads and package execution must be allowlisted, observable, and auditable — supply-chain trust is mandatory.
- **Configuration**: Declarative profile and manifest data is authoritative — tool, repository, service, client, workspace, and skill lists must not be hard-coded.
- **State**: CAS-managed state and generated configuration remain under configured CAS root/profile paths — unrelated user state must remain untouched.
- **Automation**: Interactive and non-interactive flows must expose equivalent behavior and machine-readable outcomes — CI and repeatable operations depend on it.
- **Quality**: Schemas, Pester tests, static analysis, and clean-machine journeys are release gates — documentation-only confidence is insufficient.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
