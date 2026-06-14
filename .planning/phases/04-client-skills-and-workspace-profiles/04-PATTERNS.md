# Phase 4: Client, Skills, and Workspace Profiles - Pattern Map

**Mapped:** 2026-06-13
**Files analyzed:** 11 implementation/contract/test files
**Analogs found:** 8 / 8 behavior areas

## Scope Summary

Phase 4 should extend the existing single-module, manifest-driven operation engine.
The closest patterns live in `scripts/Cas.Workstation.psm1`; no separate adapter
directory currently exists. Keep direct mutation behind typed operations and use
the existing safety, ownership, journal, and uninstall functions.

The legacy `New-CasClientConfigs` function is payload-shape evidence only. Its
direct directory creation and `Set-Content` calls bypass safe-path validation,
atomic backup/write, ownership evidence, planning, and journaling, so new client
adapters must not copy its mutation behavior.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/Cas.Workstation.psm1` | service, adapter, utility | transform, file-I/O, request-response | Existing desired-state, safety, planner/apply, and uninstall functions in the same module | exact extension point |
| `stack.manifest.json` | config | declarative transform | Existing `clients`, `skills`, `workspaces`, `sharedMcpServer`, and `full` profile declarations | exact extension point |
| `schemas/manifest.schema.json` | config/contract | validation | Existing `$defs.client`, `$defs.workspace`, profile selections, policy, and MCP contract | exact extension point |
| `schemas/managed-state.schema.json` | model/contract | CRUD, file-I/O | Existing resource ownership and content-digest contract | exact extension point |
| `schemas/operation-plan.schema.json` | model/contract | transform, request-response | Existing typed operation object and enums | exact extension point |
| `tests/Manifest.Tests.ps1` | test | validation, transform | Existing declarative resolution, allowlist, and deterministic digest tests | exact |
| `tests/Plan.Tests.ps1` and `tests/Apply.Tests.ps1` | test | request-response, event-driven | Existing deterministic skip/update plan and journaled apply tests | exact |
| `tests/Safety.Tests.ps1` and `tests/Uninstall.Tests.ps1` | test | file-I/O, CRUD | Existing atomic backup, ownership, safe-path, and ledger-only removal tests | exact |

## Pattern Assignments

### Client Configuration Merge and Drift

**Implementation location:** `scripts/Cas.Workstation.psm1`

**Closest reusable functions:**

- `Resolve-CasDesiredState` (`169-207`) selects clients only from the chosen
  profile and manifest catalog and creates the deterministic desired-state
  digest.
- `ConvertTo-CasCanonicalJson` and `Get-CasSha256` (`150-167`) provide stable
  content-digest evidence for the CAS-owned namespace.
- `Write-CasAtomicJson` (`407-442`) provides validated JSON serialization,
  recoverable first backup, atomic replace/move, and temporary-file cleanup.
- `Add-CasManagedResource` (`354-386`) records ownership, backup target, and
  content digest.
- `Get-CasOperationInventory` (`989-1012`) is the inventory extension point for
  returning `satisfied`, `missing`, `drifted`, `conflicting`, or `unsupported`
  client states.

**Desired-state selection pattern** (`scripts/Cas.Workstation.psm1:185-206`):

```powershell
foreach ($category in @("tools", "repos", "services", "clients", "skills", "workspaces")) {
    $catalog = @($Manifest.$category)
    foreach ($required in @($true, $false)) {
        $level = if ($required) { "required" } else { "optional" }
        foreach ($id in @($profileDefinition.$category.$level | Sort-Object)) {
            $definition = $catalog | Where-Object id -eq $id | Select-Object -First 1
            $resolved.resources += [ordered]@{
                category = $category
                id = $id
                required = $required
                definition = ConvertTo-CasCanonicalValue -Value $definition
            }
        }
    }
}
$canonical = ConvertTo-CasCanonicalJson -InputObject $resolved
```

**Atomic merge-write boundary** (`scripts/Cas.Workstation.psm1:415-441`):

```powershell
$target = Assert-CasSafePath -Path $Path -ApprovedRoots $ApprovedRoots -AllowBoundary:$AllowBoundary
$json = $InputObject | ConvertTo-Json -Depth 30
$null = $json | ConvertFrom-Json
$temp = Join-Path $directory ".$([IO.Path]::GetFileName($target)).$([Guid]::NewGuid().ToString('N')).tmp"
[IO.File]::WriteAllText($temp, $json, (New-Object Text.UTF8Encoding($false)))
$null = Get-Content -LiteralPath $temp -Raw | ConvertFrom-Json
if (Test-Path -LiteralPath $target -PathType Leaf) {
    $backup = "$target.backup.$([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff'))"
    [IO.File]::Replace($temp, $target, $backup)
}
```

**Legacy payload shape, not mutation pattern**
(`scripts/Cas.Workstation.psm1:1533-1546`):

```powershell
$sharedServer = [ordered]@{
    mcpServers = @{
        ($Manifest.sharedMcpServer.name) = @{
            command = $Manifest.sharedMcpServer.command
            args = @($promptImproverEntry)
            transport = $Manifest.sharedMcpServer.transport
        }
    }
}
```

New adapters should read existing client JSON, validate it, surgically replace
only a stable CAS-owned namespace, preserve all unrelated keys, calculate a
canonical digest for the owned fragment, then call `Write-CasAtomicJson`.
Existing unowned conflicting namespaces must fail closed.

**Closest tests:**

- `tests/Safety.Tests.ps1:70-81`: existing valid target is backed up before
  atomic replacement.
- `tests/Manifest.Tests.ps1:34-48`: declarative category resolution and stable
  digest.
- `tests/Plan.Tests.ps1:28-35`: satisfied state becomes `skip`.
- `tests/RepositorySafety.Tests.ps1:13-18`: closest fail-closed drift/conflict
  evidence pattern.
- `tests/Uninstall.Tests.ps1:79-91`: closest modified-configuration restoration
  test, but Phase 4 must add a surgical removal test that preserves user changes
  made after the initial backup.

**No exact analog:** There is no existing surgical JSON merge/removal function.
Do not model uninstall as unconditional full-backup restoration when unrelated
user keys may have changed after CAS apply.

---

### Atomic Backup and Write

**Analog:** `Write-CasAtomicJson`, `Write-CasManagedState`,
`Restore-CasBackupAtomically`

**Write wrapper pattern** (`scripts/Cas.Workstation.psm1:444-453`):

```powershell
Assert-CasManagedState -State $State
Write-CasAtomicJson -InputObject $State -Path $Path -ApprovedRoots $ApprovedRoots
```

**Atomic restoration pattern** (`scripts/Cas.Workstation.psm1:539-558`):

```powershell
Copy-Item -LiteralPath $BackupPath -Destination $temp -Force
if (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
    [IO.File]::Replace($temp, $TargetPath, $replacedBackup)
}
else {
    [IO.File]::Move($temp, $TargetPath)
}
```

Apply this pattern to client JSON and generated CAS-owned files. Validate target
boundaries before every write, validate serialized content before replacement,
and retain backup evidence in managed state.

**Closest tests:**

- `tests/Safety.Tests.ps1:55-68`: managed state validates and leaves no temp.
- `tests/Safety.Tests.ps1:70-81`: backup contains old content and target contains
  new content.
- `tests/Uninstall.Tests.ps1:79-91`: atomic backup restoration.

---

### Ownership Ledger

**Analog:** `New-CasManagedState`, `Add-CasManagedResource`,
`Assert-CasManagedState`, `Write-CasManagedState`

**Ownership registration pattern** (`scripts/Cas.Workstation.psm1:366-384`):

```powershell
if ($Ownership -eq "created" -and $WasPresentBefore) {
    throw "Resource '$Id' cannot be owned as created because it existed before CAS management."
}
if ($Ownership -eq "modified" -and (-not $WasPresentBefore -or -not $BackupTarget)) {
    throw "Modified resource '$Id' requires pre-existing evidence and a backup target."
}
$State.resources += [pscustomobject]@{
    id = $Id
    kind = $Kind
    ownership = $Ownership
    target = Resolve-CasCanonicalPath -Path $Target
    backupTarget = if ($BackupTarget) { Resolve-CasCanonicalPath -Path $BackupTarget } else { $null }
    contentDigest = if ($ContentDigest) { $ContentDigest } else { $null }
}
```

Use stable IDs such as `client:<id>`, `skill:<id>`, and `workspace:<id>`. Record
`created` only for absent targets, `modified` only with backup evidence, and
never adopt pre-existing unowned skill/workspace targets.

**Contract analog** (`schemas/managed-state.schema.json:18-30`):

- Existing kinds include `directory`, `file`, `repository`, `configuration`,
  and `tool`.
- Ownership is `created`, `modified`, or `observed`.
- `contentDigest` already supports canonical drift evidence.
- Modified resources require `backupTarget` and `wasPresentBefore: true`.

**Closest tests:**

- `tests/Safety.Tests.ps1:43-53`: rejects claiming pre-existing resources and
  requires backup evidence.
- `tests/Safety.Tests.ps1:55-68`: persists ledger atomically.

---

### Operation Planning and Apply

**Analog:** `New-CasOperationPlan`, `Assert-CasOperationPlan`,
`Invoke-CasPlannedOperation`, `Invoke-CasOperationPlan`

**Planner switch pattern** (`scripts/Cas.Workstation.psm1:1030-1066`):

```powershell
foreach ($resource in @($resolved.desiredState.resources | Sort-Object category, id)) {
    $inventoryId = "$($resource.category.TrimEnd('s')):$($resource.id)"
    $actual = @($Inventory.resources | Where-Object id -eq $inventoryId | Select-Object -First 1)
    switch ($resource.category) {
        # Add clients, skills, and workspaces beside tools and repos.
    }
}
```

**Deterministic identity pattern** (`scripts/Cas.Workstation.psm1:1069-1089`):

```powershell
$sortedOperations = @($operations.ToArray() | Sort-Object { $_.id })
$identity = [ordered]@{
    schemaVersion = "1.0.0"
    mode = $Mode
    profile = $Profile
    rootPath = Resolve-CasCanonicalPath -Path $RootPath
    configPath = Resolve-CasCanonicalPath -Path $ConfigPath
    desiredStateDigest = $resolved.digest
    operations = $sortedOperations
}
$planId = Get-CasSha256 -Value (ConvertTo-CasCanonicalJson -InputObject $identity)
```

**Executor dispatch pattern** (`scripts/Cas.Workstation.psm1:1218-1247`):

```powershell
if ($Operation.action -eq "skip") {
    return
}
if ($Operation.kind -eq "tool") {
    # adapter execution
    return
}
if ($Operation.kind -eq "repository") {
    # adapter execution
    return
}
throw "No executor is registered for operation kind '$($Operation.kind)'."
```

Add explicit client/configuration, skill, and workspace executors here or
dispatch to focused adapter functions from here. Direct helpers must not mutate
outside this call path.

**Journal/apply pattern** (`scripts/Cas.Workstation.psm1:1289-1328`):

- Skip operations are journaled and emit correlated skipped events.
- Before each attempt, journal status is atomically persisted.
- Adapter exceptions become failed events and actionable resume guidance.
- A failed operation stops later operations.

**Closest tests:**

- `tests/Plan.Tests.ps1:9-17`: deterministic plan ID and operation ordering.
- `tests/Plan.Tests.ps1:19-35`: preview evidence and idempotent skips.
- `tests/Apply.Tests.ps1:34-70`: correlated success/skip, bounded failure,
  resume, and tamper rejection.
- `tests/OperationWorkflow.Tests.ps1:11-22`: shared setup/upgrade/repair planner
  and mutation-free preview.

---

### Skill and Workspace Directories

**Closest analogs:** `Resolve-CasDesiredState`, `Assert-CasSafePath`,
`New-CasDirectoryLayout`, and repository create/update planning

**Directory layout evidence** (`scripts/Cas.Workstation.psm1:635-651`):

```powershell
$paths = @(
    $RootPath,
    (Join-Path $RootPath $Manifest.paths.reposRoot),
    $ConfigPath,
    (Join-Path $ConfigPath $Manifest.paths.state),
    (Join-Path $ConfigPath $Manifest.paths.config)
)
foreach ($path in $paths) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}
```

Use this only as path-composition evidence. Phase 4 skill/workspace creation
must be planned and applied through typed operations, call `Assert-CasSafePath`
before mutation, and fail if an unowned target already exists.

**Safe-path guard pattern** (`scripts/Cas.Workstation.psm1:302-334`):

- Canonicalize target and approved roots.
- Require target inside an approved boundary.
- Reject forbidden roots/system directories.
- Reject existing reparse-point targets or ancestors.

**Closest tests:**

- `tests/Manifest.Tests.ps1:34-39`: skills/workspaces resolve from profile data.
- `tests/Safety.Tests.ps1:7-39`: canonical child acceptance, boundary escape,
  boundary root, and reparse-point rejection.
- `tests/Uninstall.Tests.ps1:56-66`: refuses removal of an owned directory that
  contains unexpected state.

**No exact analog:** There is no current skill/workspace copy or validation
adapter. The planner should require tests for allowlisted source resolution,
created-target ownership, unowned-target conflict, digest drift, idempotent
skip, and non-recursive safe uninstall.

---

### Drift Detection

**Analog:** `Get-CasOperationInventory` plus `New-CasOperationPlan`

**Inventory pattern** (`scripts/Cas.Workstation.psm1:996-1011`):

```powershell
$resources = New-Object System.Collections.Generic.List[object]
# Inspect each selected resource and emit stable id/status/detail evidence.
[pscustomobject]@{ resources = $resources.ToArray() }
```

For clients, skills, and workspaces, compare the canonical digest of current
CAS-owned content against ledger `contentDigest`. Return explicit states:
`satisfied`, `missing`, `drifted`, `conflicting`, or `unsupported`. Planner
logic should map satisfied to `skip`, owned missing/drifted to create/update,
and unowned conflict/unsupported to a fail-closed operation or planning error.

**Closest tests:**

- `tests/Plan.Tests.ps1:28-43`: inventory status drives skip versus update.
- `tests/RepositorySafety.Tests.ps1:8-18`: pure evidence conversion with
  fail-closed conflict branches.
- `tests/Manifest.Tests.ps1:41-48`: canonical digest determinism.

---

### Uninstall

**Analog:** `Get-CasUninstallPreview`, `Invoke-CasUninstall`

**Preview pattern** (`scripts/Cas.Workstation.psm1:486-523`):

```powershell
foreach ($resource in @($state.resources)) {
    if ($resource.ownership -eq "observed") {
        # preserve
        continue
    }
    $target = Assert-CasSafePath -Path $resource.target -ApprovedRoots $ApprovedRoots -AllowBoundary
    # modified -> restore-backup; created -> remove-created
}
```

**Apply pattern** (`scripts/Cas.Workstation.psm1:568-594`):

```powershell
$actions = @($Preview.actions | Where-Object actionable | Sort-Object { $_.target.Length } -Descending)
foreach ($action in $actions) {
    $target = Assert-CasSafePath -Path $action.target -ApprovedRoots $ApprovedRoots -AllowBoundary
    if (-not $PSCmdlet.ShouldProcess($target, $action.action)) {
        continue
    }
    # Apply only previewed ledger-backed action.
}
```

Client configuration needs a specialized uninstall action that removes only the
CAS-owned namespace from the current file. Full backup restoration is correct
only when it cannot erase later unrelated user changes. Skills/workspaces must
remove only ledger-created targets and must refuse recursive removal when
unexpected content exists.

**Closest tests:**

- `tests/Uninstall.Tests.ps1:16-26`: preview does not mutate.
- `tests/Uninstall.Tests.ps1:28-54`: observed/unrelated state is preserved.
- `tests/Uninstall.Tests.ps1:56-77`: unexpected directory content and unsafe
  ledger paths fail closed.
- `tests/Uninstall.Tests.ps1:79-91`: modified file backup restoration baseline.

## Contract Patterns

### Manifest

**Sources:** `stack.manifest.json:10-35,328-361`,
`schemas/manifest.schema.json:7-33`

- Keep `full` as the golden-path profile; its profile membership remains
  declarative.
- Extend catalogs and policy fields rather than hard-coding adapter membership.
- Existing semantic validation in `Assert-CasManifest`
  (`scripts/Cas.Workstation.psm1:46-121`) validates required properties,
  uniqueness, allowlisted commands/repos/config targets, and profile references
  before execution.
- MCP transport enum already distinguishes `stdio`, `http`, and `sse`.
- Add semantic validation that rejects secret-bearing MCP/client fields and
  validates skill/workspace allowlisted sources and approved target metadata.

### Managed State

**Source:** `schemas/managed-state.schema.json:7-34`

Reuse the existing ownership and digest shape. Extend resource kinds only if
typed `skill` and `workspace` kinds add planner/uninstall clarity; otherwise use
`directory`, `file`, and `configuration` consistently with stable IDs.

### Operation Plan

**Source:** `schemas/operation-plan.schema.json:7-17`

Extend the operation `kind` enum and any required adapter metadata in lockstep
with `Assert-CasOperationPlan`, planner output, executor dispatch, and positive/
negative fixtures. Preserve `additionalProperties: false`.

## Shared Patterns

### Fail Closed Before Mutation

**Sources:** `Get-CasManifest` (`scripts/Cas.Workstation.psm1:11-29`),
`Assert-CasManifest` (`46-121`), `Assert-CasSafePath` (`295-335`),
`Assert-CasOperationPlan` (`1093-1124`)

Validate JSON, semantic allowlists, canonical paths, ownership evidence, and
plan integrity before any adapter performs file I/O.

### Canonical Digests

**Source:** `scripts/Cas.Workstation.psm1:123-167`

Use `ConvertTo-CasCanonicalJson` followed by `Get-CasSha256`; do not hash
formatting-dependent raw JSON.

### Preview First and Journaled Apply

**Sources:** `Invoke-CasWorkstationOperation`
(`scripts/Cas.Workstation.psm1:1394-1440`) and `Invoke-CasOperationPlan`
(`1250-1337`)

Preview returns the deterministic plan without mutation. Apply and resume route
through the same engine, with atomic journal updates and correlated events.

### Test Structure

**Sources:** all existing Pester files

- Import the shared module in `BeforeAll`.
- Use `$TestDrive` for isolated filesystem behavior.
- Construct explicit inventory/state objects instead of invoking real external
  tools.
- Test both success and failure paths with `Should -Throw`.
- For contracts, update both positive and negative fixtures; the generic
  coverage test is `tests/ContractSchemas.Tests.ps1:16-22`.

## No Exact Analog Found

| Behavior | Closest Existing Pattern | Planner Guidance |
|---|---|---|
| Surgical merge into a user-owned client JSON file | `Write-CasAtomicJson` plus legacy `New-CasClientConfigs` payload | Add focused adapter/helper and tests preserving unrelated keys |
| Surgical client uninstall after later user edits | `Get-CasUninstallPreview` / `Invoke-CasUninstall` | Remove only current CAS-owned namespace; do not blindly restore whole backup |
| Skill installation/validation adapter | Repository planning plus safe directory ownership | Add allowlisted source/target adapter and conflict tests |
| Workspace convention installation/validation adapter | Directory layout plus safe path and ledger patterns | Add planned file/directory operations and digest validation |
| Client/skill/workspace drift inventory | Repository inventory/status pattern | Add canonical owned-content digest comparison and explicit status mapping |

## Metadata

**Analog search scope:** `scripts/`, `schemas/`, `tests/`, `stack.manifest.json`,
Phase 2/3/4 context, roadmap, requirements, and project constraints

**Primary module scanned:** `scripts/Cas.Workstation.psm1` (1,587 lines)

**Pattern extraction date:** 2026-06-13
