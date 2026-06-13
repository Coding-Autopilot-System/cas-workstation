# Phase 4: Client, Skills, and Workspace Profiles - Research

**Researched:** 2026-06-13  
**Domain:** Safe PowerShell 5.1 configuration adapters and managed developer-context resources  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Golden-Path Profile
- **D-01:** Preserve `full` as the declarative golden-path profile; do not add a
  duplicate `golden-path` profile name. It must continue to select
  `cas-platform`, `cas-contracts`, `cas-evals`, and `cas-reference-product`.
- **D-02:** Client, skill, and workspace operations are derived only from the
  selected profile and manifest catalogs. No adapter may hard-code profile
  membership.

### Client Configuration Ownership
- **D-03:** Each supported client uses an explicit adapter that previews,
  validates, backs up, atomically applies, verifies, and surgically removes
  only CAS-owned configuration.
- **D-04:** CAS-owned client configuration is namespaced and carries stable
  ownership and content-digest evidence. Unrelated keys and user changes are
  preserved during apply, repair, and removal.
- **D-05:** Existing user-owned targets require a recoverable backup before
  first modification. Backups are recovery evidence, not permission to replace
  later unrelated user changes during uninstall.

### Skills and Workspaces
- **D-06:** Skills and workspace conventions are installed only from
  allowlisted manifest sources into approved CAS-managed boundaries.
- **D-07:** Skill and workspace resources receive the same deterministic plan,
  ownership-ledger, drift-digest, safe-path, and uninstall-only-owned behavior
  as other managed resources.
- **D-08:** Existing unowned skill or workspace targets fail closed on conflict;
  CAS does not silently adopt or overwrite them.

### MCP Security Boundary
- **D-09:** MCP configuration explicitly labels local workstation transports
  (`stdio`) separately from production remote transports (`http` or `sse`).
- **D-10:** Generated configuration may contain non-secret authentication
  references or instructions, but never credentials, access tokens, API keys,
  or embedded secrets.

### Planning, Drift, and Recovery
- **D-11:** Clients, skills, and workspaces become typed operations in
  `New-CasOperationPlan` and execute through `Invoke-CasOperationPlan`; direct
  mutation helpers must not bypass preview, journal, or correlation evidence.
- **D-12:** Inventory compares canonical managed content digests and reports
  satisfied, missing, drifted, conflicting, or unsupported state. Repair
  reconciles only CAS-owned drift.

### the agent's Discretion
- Exact adapter function decomposition, namespaced JSON shape, and manifest
  property names, provided they remain PowerShell 5.1-compatible,
  deterministic, schema-validated, and fail closed.
- Whether the first implementation plan separates client adapters from
  skill/workspace adapters, provided all CFG-01 through CFG-05 requirements are
  covered by the completed phase.

### Deferred Ideas (OUT OF SCOPE)
- Rich doctor findings and support bundles belong to Phase 5.
- Clean-machine end-to-end proof and trusted release artifacts belong to Phase 6.
- Central profile distribution and fleet management remain v2 (`PLAT-03`).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CFG-01 | CAS generates profile-specific configuration for supported AI clients without overwriting unrelated user configuration. | Use per-client adapters that own one namespaced MCP entry and perform read-modify-validate-stage-atomic-replace. |
| CFG-02 | User can preview, validate, apply, and remove only CAS-owned client configuration. | Add typed client operations, owned-node ledger evidence, staged verification, and surgical removal. |
| CFG-03 | Profiles install and validate portable agent skills and workspace conventions from allowlisted sources. | Add exact manifest source/target declarations and deterministic tree manifests with conflict detection. |
| CFG-04 | MCP configuration clearly distinguishes local workstation transports from production remote transports and never embeds secrets. | Normalize transport intent, render client-native shapes, and permit only environment-variable/auth references. |
| CFG-05 | Configuration adapters detect drift and preserve recoverable backups. | Digest only CAS-owned nodes/trees, classify inventory state, and retain first-modification recovery backups without whole-file uninstall restore. |
</phase_requirements>

## Summary

Phase 4 should extend the existing desired-state, inventory, planner, apply, and
ledger pipeline rather than expand `New-CasClientConfigs`. Today that helper
writes isolated fragments directly with `Set-Content`; the operation inventory,
planner, and executor currently handle only tools and repositories. The schemas
already permit generic `configuration`, `file`, and `directory` kinds, but the
planner and executor need explicit client, skill, and workspace adapter routing.
[VERIFIED: scripts/Cas.Workstation.psm1, schemas/operation-plan.schema.json]

The safe ownership unit for a client file is one stable namespaced MCP server
entry, not the entire user file. Use `cas-workstation.prompt-refiner` as the
stable logical owner key, rendered into each client's native syntax. Inventory
and ledger evidence must digest that owned node only. Apply may atomically
replace the full physical file after a surgical semantic merge; uninstall must
remove only the owned node and must never restore the original whole-file
backup over later user changes. [VERIFIED: 04-CONTEXT.md D-03 through D-05]

Skills and workspaces should use deterministic tree manifests: sorted normalized
relative paths plus per-file SHA-256 digests, with reparse points rejected.
Existing unowned targets are conflicts. Updates and removals act only on
ledger-owned entries, while unexpected files block destructive cleanup.
[VERIFIED: 04-CONTEXT.md D-06 through D-08; scripts/Cas.Workstation.psm1]

**Primary recommendation:** Implement one shared owned-resource adapter contract,
three client-native adapters, and one tree-resource adapter, all invoked only as
typed operations through the current plan/apply/journal engine. [VERIFIED:
04-CONTEXT.md D-11 through D-12]

## Project Constraints (from AGENTS.md)

- Keep Windows 11 and Windows PowerShell 5.1 compatibility; PowerShell 7 is a
  development shell, not the v1 host contract. [VERIFIED: AGENTS.md]
- Never embed credentials, access tokens, or machine-specific secrets.
  [VERIFIED: AGENTS.md]
- Default destructive behavior to preview or explicit confirmation and preserve
  unrelated user state. [VERIFIED: AGENTS.md]
- Keep generated state under configured CAS root/profile paths and derive
  resources from declarative manifest data. [VERIFIED: AGENTS.md]
- Validate manifest and managed-state changes against JSON schemas, add Pester
  tests for behavior and failure paths, and preserve non-interactive CI.
  [VERIFIED: AGENTS.md]
- Use composition, guard clauses, testable core logic, and boundary-contained
  side effects. Reproduce failure cases before fixes and validate with direct
  tests/logs/runtime behavior. [VERIFIED: user-provided C:\PersonalRepo
  AGENTS.md instructions]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Resolve selected clients, skills, and workspaces | PowerShell domain/core | Manifest/schema | Resolution already derives all six categories from selected profiles. [VERIFIED: `Resolve-CasDesiredState`] |
| Inspect client-owned configuration | PowerShell adapter | Client-native config file | Adapter knows the native target and owned namespace; core consumes normalized status. [CITED: OpenAI/Anthropic/Gemini client docs] |
| Merge/remove client configuration | PowerShell adapter boundary | Atomic filesystem writer | Merge semantics are client-specific; replacement and backup remain shared safety primitives. [VERIFIED: 04-CONTEXT.md D-03] |
| Skill/workspace source validation and drift | PowerShell tree adapter | Managed repository/filesystem | Sources come from allowlisted repos; deterministic tree evidence drives status. [VERIFIED: stack.manifest.json, 04-CONTEXT.md D-06 through D-08] |
| Plan ordering and execution | Shared operation engine | Adapters | The planner owns deterministic sequencing; adapters execute one typed operation. [VERIFIED: `New-CasOperationPlan`, `Invoke-CasOperationPlan`] |
| Ownership, backup, and uninstall evidence | Managed-state ledger | Adapters | Ledger is the authority for owned node/path and digest evidence. [VERIFIED: schemas/managed-state.schema.json, 04-CONTEXT.md D-04 through D-05] |
| MCP transport/auth policy | Manifest semantic validator | Client renderers | Policy is client-independent; renderers translate approved intent to native syntax. [CITED: MCP transport and authorization specifications] |

## Standard Stack

### Core

| Library/Capability | Version | Purpose | Why Standard |
|--------------------|---------|---------|--------------|
| Windows PowerShell | 5.1+ | Host automation and adapter orchestration | Locked v1 compatibility contract and currently available as 5.1.26100.8655. [VERIFIED: AGENTS.md; environment probe] |
| Pester | 5.7.1 | Unit, integration, and failure-path tests | Existing test framework; 46 current tests pass. [VERIFIED: module probe; `Invoke-Pester -Path tests`] |
| Newtonsoft.Json | 13.0.4, published 2025-09-16 | Fail-closed JSON token parsing and owned-node merge for Claude/Gemini | Windows PowerShell 5.1 `ConvertFrom-Json` keeps only the last duplicate key; Json.NET exposes duplicate-property handling and supports .NET Framework. Pin and vendor the approved DLL with checksum/provenance. [CITED: Microsoft ConvertFrom-Json docs; NuGet registry; Json.NET docs] |
| Existing CAS canonical JSON + SHA-256 helpers | repository-local | Stable desired/managed content digests | Existing tested implementation sorts object properties before compressed UTF-8 SHA-256 hashing. [VERIFIED: `ConvertTo-CasCanonicalJson`, `Get-CasSha256`, Manifest.Tests.ps1] |
| Existing `Write-CasAtomicJson` / `System.IO.File.Replace` pattern | repository-local / .NET Framework | Validate, stage, backup, and atomically replace JSON targets | Existing code and .NET API already create replacement backups. [VERIFIED: scripts/Cas.Workstation.psm1; CITED: Microsoft File.Replace docs] |
| Client-native Codex CLI staging | selected manifest tool | Safely modify TOML without hand-rolling TOML parsing | Codex officially supports managing MCP with `codex mcp` and stores configuration in `config.toml`. Run it against a staged `CODEX_HOME`, verify, then atomically replace the real target. [CITED: OpenAI Codex MCP docs] |

### Supporting

| Capability | Purpose | When to Use |
|------------|---------|-------------|
| JSON Schema Draft 2020-12 contracts | Extend manifest, managed-state, and operation-plan evidence | Every new property and typed operation must update positive/negative fixtures. [VERIFIED: repository schemas/tests] |
| `Get-FileHash -Algorithm SHA256` or equivalent stream hashing | Digest skill/workspace file bytes | Use for every tree-manifest file; do not hash timestamps or absolute source paths. [VERIFIED: Windows PowerShell 5.1 availability probe] |
| Client CLIs (`codex`, `claude`, `gemini`) | Post-stage/native validation where deterministic and non-secret | Apply verification only; planning must not run external processes. [VERIFIED: Phase 3 context; environment probe] |

**Installation:** No runtime package-manager install should occur during Phase 4
planning or apply. Vendor and pin the Json.NET DLL as a repository dependency so
safe JSON inspection is available before tool installation and without network
access. [VERIFIED: Phase 3 no-external-process planning decision; CITED: NuGet
Newtonsoft.Json 13.0.4]

## Architecture Patterns

### System Architecture Diagram

```text
Selected profile + validated manifest
              |
              v
 Resolve-CasDesiredState
              |
              v
 Adapter registry resolves client / skill / workspace definition
              |
              v
 Inventory: desired owned digest vs observed owned digest + ledger evidence
              |
              +--> satisfied ------> deterministic skip
              +--> missing --------> create
              +--> drifted --------> update only when CAS-owned
              +--> conflicting ----> fail closed
              +--> unsupported ----> fail closed for required resource
                                      |
                                      v
 New-CasOperationPlan (dependency-aware deterministic typed operations)
                                      |
                          preview ----+---- explicit apply
                                                 |
                                                 v
                         Invoke-CasOperationPlan + journal/events
                                                 |
                                                 v
                 stage -> validate -> backup -> atomic apply -> verify
                                                 |
                                                 v
                          update managed-state ownership/digest evidence
```

### Recommended Project Structure

Keep the public module as the current integration surface, but decompose
functions by responsibility inside it unless the implementation plan explicitly
introduces dot-sourced private modules. [VERIFIED: repository convention]

```text
scripts/Cas.Workstation.psm1
  manifest + semantic validation
  adapter registry and normalized adapter results
  client JSON adapter
  Codex TOML-through-staged-CLI adapter
  skill/workspace tree adapter
  inventory / planner / executor integration
  managed-state and uninstall integration

tests/
  ClientConfig.Tests.ps1
  ManagedTrees.Tests.ps1
  Plan.Tests.ps1
  Apply.Tests.ps1
  Safety.Tests.ps1
  Uninstall.Tests.ps1
  Manifest.Tests.ps1
```

### Pattern 1: Shared Owned-Resource Adapter Contract

Use a normalized adapter result so core planning never knows client-native
syntax. [VERIFIED: 04-CONTEXT.md D-03, D-11]

```powershell
# Recommended normalized result shape.
[pscustomobject]@{
    id             = "client:codex"
    kind           = "configuration"
    adapter        = "codex-mcp"
    target         = $canonicalTarget
    ownershipKey   = "cas-workstation.prompt-refiner"
    desiredDigest  = $desiredOwnedNodeDigest
    observedDigest = $observedOwnedNodeDigest
    status         = "satisfied" # missing|drifted|conflicting|unsupported
    detail         = $null
}
```

Required adapter operations: resolve exact target, render desired owned content,
inspect, stage apply, validate staged result, atomically commit, verify, and
surgically remove. [VERIFIED: 04-CONTEXT.md D-03 through D-05]

### Pattern 2: Owned-Node JSON Merge

For Claude and Gemini, parse the full target with duplicate-property rejection,
clone it, replace only `mcpServers["cas-workstation.prompt-refiner"]`, validate
the staged full document, then atomically replace the target. Preserve every
other semantic property. [CITED: Claude and Gemini MCP configuration docs;
Microsoft ConvertFrom-Json duplicate-key behavior; Json.NET duplicate-property
handling]

The digest is over the canonical desired owned node, not over the full user
file. This makes unrelated user changes invisible to CAS drift while changes
inside the CAS namespace become drift. [VERIFIED: 04-CONTEXT.md D-04, D-12]

### Pattern 3: Codex Native TOML Staging

Codex stores MCP configuration in `~/.codex/config.toml`, with each server under
`[mcp_servers.<server-name>]`. Do not implement a partial TOML parser. Copy the
user target to a CAS-controlled staging `CODEX_HOME`, invoke the allowlisted
`codex mcp` command against staging, validate the staged result, then atomically
replace the real file. [CITED: OpenAI Codex MCP docs]

Planning uses manifest and file/ledger evidence only; the external Codex CLI may
run only inside the journaled apply adapter. [VERIFIED: Phase 3 context]

### Pattern 4: Deterministic Tree Manifest for Skills and Workspaces

Represent a desired tree as canonical records sorted by normalized relative
path:

```powershell
[ordered]@{
    schemaVersion = "1.0.0"
    resourceId = "skill:prompt-refiner"
    entries = @(
        [ordered]@{ path = "SKILL.md"; type = "file"; digest = "sha256:..." }
    )
}
```

Reject absolute paths, `..` escapes, reparse points, and any source outside the
manifest-declared managed repository. Digest the canonical record set. Install
files through staged copies and record owned files/directories so uninstall can
remove files first and only empty directories afterward. [VERIFIED:
`Assert-CasSafePath`, current uninstall behavior, 04-CONTEXT.md D-06 through
D-08]

### Pattern 5: Dependency-Aware Deterministic Planning

Typed resources require execution ordering: tools before client-native CLI
operations; repositories before repo-sourced skills/workspaces; skills and
workspaces before client configuration that references them. Current plans sort
only by operation ID, which can place client operations before repositories.
Add deterministic dependency evidence or a stable kind-priority/topological
sort and include that ordering in plan identity. [VERIFIED:
`New-CasOperationPlan`; stack.manifest.json]

Recommended order: `tool -> repository -> skill/workspace -> client
configuration`. Cycles or missing dependencies fail before apply. [VERIFIED:
manifest relationships and locked fail-closed behavior]

### Pattern 6: Backup Is Recovery Evidence, Not Uninstall State

On first modification of a user-owned client file, retain a recoverable full
backup in a CAS-controlled backup directory and record it in the ledger. On
later updates, retain new operation backups as recovery evidence. Uninstall
parses the current file and removes only the CAS-owned node; it does not restore
the first backup. [VERIFIED: 04-CONTEXT.md D-05]

### Anti-Patterns to Avoid

- **Expanding `New-CasClientConfigs` direct writes:** it bypasses inventory,
  preview, plan integrity, journal, ledger, and safe-path enforcement.
  [VERIFIED: scripts/Cas.Workstation.psm1]
- **Digesting the entire client file:** unrelated user edits would be reported
  as CAS drift. [VERIFIED: 04-CONTEXT.md D-04, D-12]
- **Restoring a whole client backup during uninstall:** this overwrites user
  changes made after CAS first modified the file. [VERIFIED: 04-CONTEXT.md D-05]
- **Using Windows PowerShell `ConvertFrom-Json` alone for untrusted user
  configuration:** duplicate keys are silently collapsed to the last key.
  [CITED: Microsoft ConvertFrom-Json docs]
- **Treating all MCP transports as one shape:** client-native keys differ, and
  Streamable HTTP replaced the old HTTP+SSE transport in the MCP specification.
  [CITED: OpenAI/Claude/Gemini docs; MCP transport specification]
- **Recursive copy/remove of skill or workspace roots:** it can follow or erase
  unexpected state and cannot prove per-entry ownership. [VERIFIED:
  `Assert-CasSafePath`, `Invoke-CasUninstall`, 04-CONTEXT.md D-08]

## Manifest and Contract Changes

### Manifest

Extend each client with an adapter ID, scope, exact target template, ownership
key, and supported transport mapping. Extend skills/workspaces with exact source
repository, source-relative path, target template, and adapter ID. Extend policy
with allowlisted adapter IDs, approved target templates/parents, and permitted
non-secret auth-reference field names. [VERIFIED: current manifest lacks these
properties; 04-CONTEXT.md D-02, D-06, D-09, D-10]

The current `skills` entry identifies only `repo`, and the current `workspaces`
entry identifies only `relativePath`; neither identifies an installable source
tree. The current repository also contains no `cas-default` workspace source.
[VERIFIED: stack.manifest.json; repository grep]

### Managed State

Extend resource evidence to identify the adapter and owned unit, for example:
`adapter`, `ownershipKey` or `ownedPath`, `contentDigest`, and optional
`backupTarget`. Tree resources also need owned entry evidence or individual
file/directory ledger entries. [VERIFIED: current managed-state schema records
only whole target, ownership, backup, and digest]

The current uninstall implementation restores the entire backup for every
modified resource; configuration adapters need a distinct surgical-remove path
so D-05 is not violated. [VERIFIED: `Get-CasUninstallPreview`,
`Invoke-CasUninstall`, 04-CONTEXT.md D-05]

### Operation Plan

Keep existing schema kinds (`configuration`, `file`, `directory`) and add
adapter/dependency metadata needed to execute typed Phase 4 operations without
embedding secret payloads in plans or logs. The operation source should identify
the manifest resource/source reference, not contain configuration content or
credentials. [VERIFIED: schemas/operation-plan.schema.json; 04-CONTEXT.md D-10,
D-11]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| General TOML parsing/serialization | Regex or line-based TOML merger | Staged `codex mcp` native CLI adapter | Codex owns its TOML grammar and CLI management surface. [CITED: OpenAI Codex MCP docs] |
| JSON tokenization | Regex JSON merge or bare `ConvertFrom-Json` | Pinned Json.NET token model with duplicate-property errors | Duplicate keys and nested object semantics must fail closed. [CITED: Microsoft and Json.NET docs] |
| Whole-file JSON patch semantics | Generic RFC 7396 patch over user files | Exact owned-node replace/remove | Generic merge patch does not express CAS ownership or protect adjacent user state. [CITED: RFC 7396; VERIFIED: 04-CONTEXT.md D-04] |
| Tree identity | Timestamps, directory size, or unordered enumeration | Sorted relative-path + file-digest tree manifest | Stable content identity must be independent of machine and enumeration order. [VERIFIED: existing canonical digest pattern] |
| Recursive deletion | `Remove-Item -Recurse` on managed roots | Ledger-owned file removal then empty-directory removal | Unexpected user content must block deletion. [VERIFIED: Uninstall.Tests.ps1] |
| MCP authentication | Embedded tokens, API keys, or static bearer values | Environment-variable/auth references and client-native OAuth flow | MCP HTTP authorization is transport-level; stdio retrieves credentials from environment. [CITED: MCP authorization specification; 04-CONTEXT.md D-10] |

## Common Pitfalls

### Pitfall 1: Whole-File Ownership by Accident
**What goes wrong:** CAS reports drift for unrelated edits or overwrites user
settings during repair/uninstall. [VERIFIED: 04-CONTEXT.md D-04 through D-05]  
**How to avoid:** Persist and compare the owned-node digest; merge/remove only
that node.  
**Warning signs:** Ledger has only a target file path and whole-file digest.

### Pitfall 2: Backup Restoration Violates Surgical Uninstall
**What goes wrong:** Restoring the first backup discards all later user edits.
[VERIFIED: current uninstall implementation versus 04-CONTEXT.md D-05]  
**How to avoid:** Route configuration uninstall to the adapter's remove-owned
operation; retain backups only for explicit recovery.

### Pitfall 3: Duplicate JSON Keys Are Silently Lost
**What goes wrong:** Windows PowerShell 5.1 keeps only the last duplicate key,
so a read-modify-write can destroy ambiguous user data. [CITED: Microsoft
ConvertFrom-Json docs]  
**How to avoid:** Parse with duplicate-property handling set to error before
planning a merge or removal.

### Pitfall 4: Planning Executes Client CLIs
**What goes wrong:** Preview mutates state, prompts, reads credentials, or
depends on tool availability. [VERIFIED: Phase 3 context]  
**How to avoid:** Planning uses manifest, filesystem, and ledger evidence only;
native CLI execution is apply-time and journaled.

### Pitfall 5: Resource Dependencies Are Hidden by ID Sorting
**What goes wrong:** A client operation runs before the repository or skill it
references exists. [VERIFIED: current operation ID sorting and manifest MCP
command path]  
**How to avoid:** Add explicit deterministic dependencies or stable topological
ordering and test it.

### Pitfall 6: Workspace/Skill Source Is Ambiguous
**What goes wrong:** Adapter hard-codes source locations or copies the wrong
variant. [VERIFIED: current manifest identifies no exact source paths; two
`prompt-refiner` skill variants exist in the sibling Promptimprover checkout]  
**How to avoid:** Require exact source repo and relative source path in the
manifest; missing/ambiguous source fails semantic validation.

### Pitfall 7: MCP Transport Labels Do Not Match Native Client Shape
**What goes wrong:** A generic `transport` property is written where the client
expects `command`, `url`, `httpUrl`, or `type`. [VERIFIED:
`New-CasClientConfigs`; CITED: client docs]  
**How to avoid:** Store normalized intent in the manifest and render per-client:
Codex uses `command` or `url`; Claude uses command entries or HTTP type/url;
Gemini uses `command`, `url` for SSE, or `httpUrl` for Streamable HTTP.

### Pitfall 8: Legacy SSE Is Presented as the Production Default
**What goes wrong:** New remote configurations are built around the transport
replaced by Streamable HTTP. [CITED: MCP transport specification]  
**How to avoid:** Label `stdio` as workstation-local, use `http`/Streamable HTTP
as the production remote default, and retain `sse` only as an explicitly
legacy-compatible option.

## Code Examples

### Owned-Node Digest and Status

```powershell
# Uses existing CAS canonicalization and SHA-256 helpers.
$desiredDigest = Get-CasSha256 -Value (
    ConvertTo-CasCanonicalJson -InputObject $desiredOwnedNode
)

$status = if (-not $targetExists) {
    "missing"
}
elseif (-not $ownedNodeExists -and $ledgerOwnsNode) {
    "missing"
}
elseif (-not $ownedNodeExists) {
    "missing"
}
elseif (-not $ledgerOwnsNode) {
    "conflicting"
}
elseif ($observedOwnedDigest -ne $desiredDigest) {
    "drifted"
}
else {
    "satisfied"
}
```

Source: existing canonical digest helpers plus D-12 status contract.
[VERIFIED: scripts/Cas.Workstation.psm1; 04-CONTEXT.md]

### Surgical JSON Apply

```powershell
# Pseudocode: Json.NET load settings must reject duplicate property names.
$document = Read-CasJsonDocumentFailClosed -Path $target
$document.mcpServers[$ownershipKey] = $desiredOwnedNode

$staged = Write-CasStagedJson -Document $document -Target $target
Assert-CasClientConfig -Adapter $adapter -Path $staged
$backup = Commit-CasAtomicFile -StagedPath $staged -TargetPath $target
Assert-CasOwnedNodeDigest -Path $target -ExpectedDigest $desiredDigest
```

Source: Json.NET duplicate-property handling, existing atomic replacement
pattern, and locked adapter behavior. [CITED: Json.NET docs; VERIFIED:
scripts/Cas.Workstation.psm1, 04-CONTEXT.md]

### Secret-Free MCP Rendering

```powershell
# Allowed: reference a variable name. Never resolve or persist its value.
[ordered]@{
    url = "https://example.internal/mcp"
    bearer_token_env_var = "CAS_MCP_ACCESS_TOKEN"
}
```

Codex documents `bearer_token_env_var`; Gemini documents environment-variable
expansion; MCP authorization says stdio implementations retrieve credentials
from the environment. [CITED: OpenAI Codex MCP docs; Gemini MCP docs; MCP
authorization specification]

## State of the Art

| Old/Current Seed Approach | Required Phase 4 Approach | Impact |
|---------------------------|---------------------------|--------|
| Generic JSON fragment with `transport` property for every client | Client-native rendering and adapter validation | Current fragment shape is not a valid universal client contract. [VERIFIED: seed code; CITED: client docs] |
| Direct `Set-Content` from `New-CasClientConfigs` | Typed journaled adapter operation with staging, backup, atomic commit, and verification | Brings client mutation under Phase 3 guarantees. [VERIFIED: seed code; 04-CONTEXT.md D-11] |
| Whole-file backup restore for modified configuration | Surgical owned-node removal; backup retained for recovery only | Preserves later unrelated user changes. [VERIFIED: 04-CONTEXT.md D-05] |
| HTTP+SSE as a standard remote transport | Streamable HTTP as current standard; SSE only for backward compatibility | MCP specification states Streamable HTTP replaced HTTP+SSE. [CITED: MCP transport specification dated 2025-11-25] |
| Skill identified only by repo; workspace only by destination path | Exact allowlisted source tree + approved target + canonical tree digest | Makes install, drift, repair, and uninstall implementable. [VERIFIED: current manifest; 04-CONTEXT.md D-06 through D-08] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The user-level native client targets are the intended Phase 4 integration scope, rather than project-only configuration files. [ASSUMED] | Architecture Patterns | Target templates and backup boundaries would change; adapter semantics remain the same. |
| A2 | `cas-workstation.prompt-refiner` is acceptable as the stable logical ownership key. [ASSUMED] | Summary | A different namespace changes manifests, ledger fixtures, and adapter tests but not architecture. |

## Open Questions

1. **Which exact source tree defines `cas-default` workspace conventions?**
   - What we know: The manifest selects `cas-default`, but no source repo/path
     or matching workspace content exists in this repository. [VERIFIED:
     stack.manifest.json; repository grep]
   - Recommendation: Make creation/selection of a minimal versioned workspace
     source tree a Wave 0 task before CFG-03 implementation.

2. **Which prompt-refiner skill variant is canonical?**
   - What we know: The sibling Promptimprover checkout contains matching
     `universal-refiner\skills\prompt-refiner` and
     `gemini-extension\skills\prompt-refiner` trees; the current manifest names
     only the repository. [VERIFIED: filesystem probe]
   - Recommendation: Declare the exact canonical source-relative path in the
     manifest; do not let the adapter infer it.

3. **Should client integration target user scope or project scope?**
   - What we know: Codex supports user and trusted-project config; Claude has
     local/project/user MCP scopes; Gemini supports user and project settings.
     [CITED: official client docs]
   - Recommendation: Use user scope for the workstation-wide golden path unless
     discuss-phase changes the decision; keep target scope declarative per
     client.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Windows PowerShell | Product host and tests | Yes | 5.1.26100.8655 | None |
| Pester | Validation | Yes | 5.7.1 | None |
| PSScriptAnalyzer | Full quality gate | Yes | 1.24.0 | None |
| Python/jsonschema | Existing schema fixtures | Yes | Python 3.14.2 | None |
| Git | Repo-sourced skills/workspaces | Yes | 2.53.0.windows.1 | None |
| Node.js | Local stdio MCP command | Yes | 24.13.0 | None |
| Codex CLI | Codex native config adapter verification | Yes | 0.138.0 | Required resource; fail unsupported if absent |
| Claude Code | Claude adapter verification | Yes | 2.1.172 | Required resource; fail unsupported if absent |
| Gemini CLI | Gemini adapter verification | Yes | 0.45.1 | Required resource; fail unsupported if absent |
| PowerShell 7 | Optional development shell | No | — | Windows PowerShell 5.1 is the supported host |

All availability and versions were verified locally on 2026-06-13. The full
repository quality gate passed with 46/46 Pester tests, schema fixtures, static
analysis, and governance checks. [VERIFIED: environment probes and
`Invoke-Quality.ps1`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Pester 5.7.1 [VERIFIED: environment probe] |
| Config file | None; tests use direct Pester discovery and `Invoke-Quality.ps1`. [VERIFIED: repository] |
| Quick run command | `Invoke-Pester -Path tests\ClientConfig.Tests.ps1,tests\ManagedTrees.Tests.ps1,tests\Plan.Tests.ps1,tests\Uninstall.Tests.ps1` |
| Full suite command | `.\Invoke-Quality.ps1` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CFG-01 | Profile-selected adapters merge native client configuration while preserving unrelated keys | integration/unit | `Invoke-Pester -Path tests\ClientConfig.Tests.ps1` | No - Wave 0 |
| CFG-02 | Preview/apply/remove operate only on CAS-owned namespace through plan/apply/ledger | integration | `Invoke-Pester -Path tests\ClientConfig.Tests.ps1,tests\Plan.Tests.ps1,tests\Apply.Tests.ps1,tests\Uninstall.Tests.ps1` | Partial - extend existing; add client tests |
| CFG-03 | Exact allowlisted skill/workspace sources install, validate, drift, conflict, and uninstall safely | integration/unit | `Invoke-Pester -Path tests\ManagedTrees.Tests.ps1,tests\Manifest.Tests.ps1,tests\Uninstall.Tests.ps1` | No - Wave 0 |
| CFG-04 | Local/remote transports render distinctly and generated output contains no secret values | unit/security | `Invoke-Pester -Path tests\ClientConfig.Tests.ps1,tests\Manifest.Tests.ps1` | No - Wave 0 |
| CFG-05 | Owned-node/tree drift is detected and first-modification backups remain recoverable without whole-file uninstall restore | integration | `Invoke-Pester -Path tests\ClientConfig.Tests.ps1,tests\ManagedTrees.Tests.ps1,tests\Safety.Tests.ps1,tests\Uninstall.Tests.ps1` | Partial - extend existing; add adapter tests |

### Required Test Cases

- Equivalent profile/inventory inputs produce byte-equivalent canonical plans
  including Phase 4 operations. [VERIFIED: existing Plan.Tests.ps1 pattern]
- Preview performs no filesystem or external-process mutation. [VERIFIED:
  existing OperationWorkflow.Tests.ps1 pattern]
- Unrelated JSON/TOML client settings survive apply, repair, and uninstall.
  [VERIFIED: CFG-01/CFG-02 contract]
- Duplicate JSON properties, malformed config, unsupported adapter/transport,
  and ambiguous ownership fail closed before mutation. [CITED: Microsoft
  ConvertFrom-Json behavior; VERIFIED: phase decisions]
- First modification creates recoverable backup; later uninstall removes only
  the owned node and preserves later unrelated changes. [VERIFIED: D-05]
- Changed owned node is `drifted`; changed unrelated node remains `satisfied`;
  missing ledger with existing namespaced node is `conflicting`. [VERIFIED:
  D-04, D-12]
- Skill/workspace tree digest ignores enumeration order but changes for file
  content/path changes. [VERIFIED: deterministic digest contract]
- Existing unowned target, unexpected file, source escape, destination escape,
  and reparse point all fail closed. [VERIFIED: D-06 through D-08 and current
  safety tests]
- Operation order honors repository/tool dependencies and remains deterministic.
  [VERIFIED: identified current ordering gap]
- Plan, journal, events, and generated config never contain seeded secret
  values. [VERIFIED: D-10]

### Sampling Rate

- **Per task commit:** Run the focused new/extended Pester files for the adapter
  or contract being changed. [VERIFIED: repository test pattern]
- **Per wave merge:** Run `Invoke-Pester -Path tests` plus schema fixture
  validation. [VERIFIED: repository quality architecture]
- **Phase gate:** Run `.\Invoke-Quality.ps1`; full suite must remain green before
  `$gsd-verify-work`. [VERIFIED: AGENTS.md and current passing quality gate]

### Wave 0 Gaps

- [ ] `tests\ClientConfig.Tests.ps1` - owned-node merges, native rendering,
  backup, drift, secret rejection, and surgical removal.
- [ ] `tests\ManagedTrees.Tests.ps1` - source allowlist, canonical tree digest,
  conflict, repair, and uninstall behavior.
- [ ] Extend manifest/managed-state/operation-plan positive and negative
  fixtures before implementing adapters.
- [ ] Add a minimal canonical `cas-default` workspace source tree or fixture.
- [ ] Pin and load Json.NET 13.0.4 with checksum/provenance and a test proving
  duplicate-property rejection under Windows PowerShell 5.1.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | Yes for remote MCP references | Store only environment-variable/auth-flow references; never secret values. [CITED: MCP authorization spec; D-10] |
| V3 Session Management | Limited to remote MCP clients | Do not persist MCP session IDs or tokens in generated config/ledger/logs. [CITED: MCP transport specification] |
| V4 Access Control | Yes | Manifest allowlists, exact adapter/target/source boundaries, namespaced ownership, and client tool allowlists where supported. [VERIFIED: phase decisions; CITED: client docs] |
| V5 Input Validation | Yes | JSON Schema plus semantic validation; duplicate-property rejection; canonical path and reparse-point checks. [VERIFIED: repository patterns; CITED: Microsoft/Json.NET docs] |
| V6 Cryptography | Yes | Use SHA-256 for deterministic evidence; do not implement credentials or cryptography. [VERIFIED: existing helpers; D-10] |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| User-config clobbering | Tampering | Owned-node merge/remove, staged validation, atomic replacement, recovery backup. [VERIFIED: D-03 through D-05] |
| Path escape or reparse-point traversal | Tampering/Elevation | Canonical exact-target/source checks and existing reparse-point rejection before every mutation. [VERIFIED: current safety implementation/tests] |
| Untrusted skill/workspace content replacement | Tampering | Allowlisted repository/path, canonical tree digest, conflict detection, ledger evidence. [VERIFIED: D-06 through D-08] |
| Secret leakage into config/plan/log | Information Disclosure | Permit names/references only; reject secret-like fields/values; test seeded canaries across outputs. [VERIFIED: D-10] |
| Remote MCP exposed without authentication | Spoofing/Information Disclosure | Production remote intent uses Streamable HTTP with proper authentication; local HTTP binds localhost and validates Origin. [CITED: MCP transport specification] |
| Overprivileged MCP tools | Elevation of Privilege | Preserve client approval defaults and use tool allowlists where declared; never set Gemini `trust=true` by default. [CITED: OpenAI and Gemini MCP docs] |
| Ambiguous duplicate JSON keys | Tampering | Reject duplicate properties before semantic merge. [CITED: Microsoft ConvertFrom-Json docs; Json.NET docs] |

## Sources

### Primary (HIGH confidence)

- Repository `AGENTS.md`, `stack.manifest.json`, schemas,
  `scripts/Cas.Workstation.psm1`, and Pester tests - current architecture,
  contracts, gaps, and passing baseline.
- `.planning/phases/04-client-skills-and-workspace-profiles/04-CONTEXT.md` -
  locked Phase 4 decisions.
- https://developers.openai.com/codex/mcp - Codex native MCP config, scopes,
  stdio/HTTP fields, and environment auth references.
- https://code.claude.com/docs/en/mcp - Claude MCP scopes and native JSON shape.
- https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md
  - Gemini native settings, transports, environment references, and trust/tool
  controls.
- https://modelcontextprotocol.io/specification/2025-11-25/basic/transports -
  current standard transports and HTTP security requirements.
- https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization -
  HTTP authorization scope and stdio environment-credential boundary.
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json?view=powershell-5.1
  - PowerShell 5.1 duplicate-key and comment behavior.
- https://learn.microsoft.com/en-us/dotnet/api/system.io.file.replace?view=netframework-4.8.1
  - replacement/backup behavior.
- https://www.nuget.org/packages/Newtonsoft.Json - verified stable version
  13.0.4, publish date, and .NET Framework compatibility.
- https://www.newtonsoft.com/json/help/html/P_Newtonsoft_Json_Linq_JsonLoadSettings_DuplicatePropertyNameHandling.htm
  - duplicate-property handling control.

### Secondary (MEDIUM confidence)

- https://www.rfc-editor.org/rfc/rfc7396 - generic JSON Merge Patch semantics,
  used only to explain why ownership-aware exact-node merge is required.
- https://www.rfc-editor.org/rfc/rfc8785 - canonical JSON reference; CAS should
  continue its existing tested canonical subset unless cross-implementation JCS
  interoperability becomes a requirement.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - verified against local environment, repository
  implementation, Microsoft docs, client docs, and NuGet registry.
- Architecture: HIGH - primarily constrained by locked context and existing
  plan/apply/ledger contracts.
- Pitfalls: HIGH - directly evidenced by current code gaps, PowerShell 5.1
  behavior, and official client/MCP documentation.

**Research date:** 2026-06-13  
**Valid until:** 2026-07-13 for repository architecture; recheck client-native
configuration docs and MCP specification immediately before implementation
because those interfaces are fast-moving.
