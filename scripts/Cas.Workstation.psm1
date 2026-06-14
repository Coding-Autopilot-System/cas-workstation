Set-StrictMode -Version Latest

function Get-CasModuleRoot {
    Split-Path -Parent $PSScriptRoot
}

function Get-CasManifestPath {
    Join-Path (Get-CasModuleRoot) "stack.manifest.json"
}

function Get-CasManifest {
    param(
        [string]$Path = (Get-CasManifestPath)
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Manifest was not found: $Path"
    }

    try {
        $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        throw "Manifest '$Path' is not valid JSON: $($_.Exception.Message)"
    }

    Assert-CasManifest -Manifest $manifest
    $manifest
}

function Get-CasPropertyNames {
    param([object]$InputObject)

    @($InputObject.PSObject.Properties | ForEach-Object { $_.Name })
}

function Assert-CasUniqueIds {
    param([string]$Category, [object[]]$Items)

    $duplicates = @($Items | ForEach-Object id | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicates.Count -gt 0) {
        throw "Manifest category '$Category' contains duplicate id(s): $($duplicates -join ', ')."
    }
}

function Assert-CasManifest {
    param([Parameter(Mandatory = $true)][pscustomobject]$Manifest)

    $requiredProperties = @("manifestVersion", "bundleId", "defaults", "policy", "profiles", "paths", "tools", "repos", "services", "clients", "skills", "workspaces", "sharedMcpServer")
    foreach ($property in $requiredProperties) {
        if (-not $Manifest.PSObject.Properties[$property]) {
            throw "Manifest is missing required property '$property'."
        }
    }

    $categories = @("tools", "repos", "services", "clients", "skills", "workspaces")
    foreach ($category in $categories) {
        Assert-CasUniqueIds -Category $category -Items @($Manifest.$category)
    }

    $allowedCommands = @($Manifest.policy.allowedCommands)
    foreach ($tool in @($Manifest.tools)) {
        if ($allowedCommands -notcontains $tool.command) {
            throw "Tool '$($tool.id)' uses unallowlisted command '$($tool.command)'."
        }
        foreach ($installer in @($tool.installers)) {
            if (@($Manifest.policy.allowedInstallerKinds) -notcontains $installer.kind) {
                throw "Tool '$($tool.id)' uses unallowlisted installer kind '$($installer.kind)'."
            }
            if ($installer.kind -ne "manual" -and (-not $installer.id -or $installer.id -notmatch '^[A-Za-z0-9@][A-Za-z0-9@/._-]+$')) {
                throw "Tool '$($tool.id)' has an invalid package identity."
            }
        }
    }

    foreach ($repo in @($Manifest.repos)) {
        $trusted = @($Manifest.policy.allowedRepositoryPrefixes | Where-Object { $repo.url.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) })
        if ($trusted.Count -eq 0) {
            throw "Repository '$($repo.id)' uses unallowlisted URL '$($repo.url)'."
        }
    }

    foreach ($client in @($Manifest.clients)) {
        if (@($Manifest.policy.allowedConfigTargets) -notcontains $client.fileName) {
            throw "Client '$($client.id)' uses unallowlisted configuration target '$($client.fileName)'."
        }
        if (@($Manifest.policy.allowedAdapters) -notcontains $client.adapter) {
            throw "Client '$($client.id)' uses unallowlisted adapter '$($client.adapter)'."
        }
        if ($client.ownershipKey -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]+$') {
            throw "Client '$($client.id)' uses an invalid ownership key."
        }
    }

    $knownRepos = @($Manifest.repos | ForEach-Object id)
    foreach ($category in @("skills", "workspaces")) {
        foreach ($resource in @($Manifest.$category)) {
            if (@($Manifest.policy.allowedAdapters) -notcontains $resource.adapter) {
                throw "$category resource '$($resource.id)' uses unallowlisted adapter '$($resource.adapter)'."
            }
            if ($knownRepos -notcontains $resource.repo) {
                throw "$category resource '$($resource.id)' references unknown repository '$($resource.repo)'."
            }
            foreach ($relativePath in @($resource.sourceRelativePath, $resource.targetRelativePath)) {
                if ([IO.Path]::IsPathRooted($relativePath) -or $relativePath -match '(^|[\\/])\.\.([\\/]|$)') {
                    throw "$category resource '$($resource.id)' uses unsafe relative path '$relativePath'."
                }
            }
        }
    }

    if ($allowedCommands -notcontains $Manifest.sharedMcpServer.command) {
        throw "Shared MCP server uses unallowlisted command '$($Manifest.sharedMcpServer.command)'."
    }
    if ($Manifest.sharedMcpServer.scope -eq "local-workstation" -and $Manifest.sharedMcpServer.transport -ne "stdio") {
        throw "Local workstation MCP servers must use stdio transport."
    }
    if ($Manifest.sharedMcpServer.scope -eq "production-remote" -and $Manifest.sharedMcpServer.transport -eq "stdio") {
        throw "Production remote MCP servers cannot use stdio transport."
    }
    if ($Manifest.sharedMcpServer.authReference -and $Manifest.sharedMcpServer.authReference -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        throw "Shared MCP server authentication must be an environment reference, not a secret value."
    }

    foreach ($profileName in Get-CasPropertyNames -InputObject $Manifest.profiles) {
        $profile = $Manifest.profiles.PSObject.Properties[$profileName].Value
        foreach ($category in $categories) {
            if (-not $profile.PSObject.Properties[$category]) {
                throw "Profile '$profileName' is missing category '$category'."
            }
            $selection = $profile.$category
            foreach ($level in @("required", "optional")) {
                if (-not $selection.PSObject.Properties[$level]) {
                    throw "Profile '$profileName' category '$category' is missing '$level'."
                }
            }
            $overlap = @($selection.required | Where-Object { @($selection.optional) -contains $_ })
            if ($overlap.Count -gt 0) {
                throw "Profile '$profileName' category '$category' repeats id(s) as required and optional: $($overlap -join ', ')."
            }
            $knownIds = @($Manifest.$category | ForEach-Object id)
            foreach ($id in @($selection.required) + @($selection.optional)) {
                if ($knownIds -notcontains $id) {
                    throw "Profile '$profileName' references unknown $category id '$id'."
                }
            }
        }
    }

    if (-not $Manifest.profiles.PSObject.Properties[$Manifest.defaults.profile]) {
        throw "Default profile '$($Manifest.defaults.profile)' does not exist."
    }
}

function ConvertTo-CasCanonicalValue {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [string] -or $Value -is [ValueType]) {
        return $Value
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in @($Value.Keys | Sort-Object)) {
            $ordered[$key] = ConvertTo-CasCanonicalValue -Value $Value[$key]
        }
        return $ordered
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value | ForEach-Object { ConvertTo-CasCanonicalValue -Value $_ })
    }

    $result = [ordered]@{}
    foreach ($property in @($Value.PSObject.Properties | Sort-Object Name)) {
        $result[$property.Name] = ConvertTo-CasCanonicalValue -Value $property.Value
    }
    $result
}

function ConvertTo-CasCanonicalJson {
    param([Parameter(Mandatory = $true)][object]$InputObject)

    ConvertTo-CasCanonicalValue -Value $InputObject | ConvertTo-Json -Depth 30 -Compress
}

function Get-CasSha256 {
    param([Parameter(Mandatory = $true)][string]$Value)

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        "sha256:$([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant())"
    }
    finally {
        $sha.Dispose()
    }
}

function Resolve-CasDesiredState {
    param(
        [string]$Profile = "full",
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    Assert-CasManifest -Manifest $Manifest
    $profileDefinition = Get-CasProfile -Name $Profile -Manifest $Manifest
    $resolved = [ordered]@{
        schemaVersion = "1.0.0"
        bundleId = $Manifest.bundleId
        manifestVersion = $Manifest.manifestVersion
        profile = $Profile
        resources = @()
    }

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
    [pscustomobject]@{
        desiredState = $resolved
        canonicalJson = $canonical
        digest = Get-CasSha256 -Value $canonical
    }
}

function Get-CasCompatibilityReport {
    param(
        [string]$Profile = "full",
        [pscustomobject]$Manifest = (Get-CasManifest),
        [switch]$IncludeToolInventory
    )

    Assert-CasManifest -Manifest $Manifest
    $checks = New-Object System.Collections.Generic.List[object]
    $isWindows = $env:OS -eq "Windows_NT" -or [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    $checks.Add([pscustomobject]@{ id = "host-os"; required = $true; status = if ($isWindows) { "supported" } else { "unsupported" }; actual = [Environment]::OSVersion.Platform.ToString(); message = "Windows 11 is the supported v1 host." })
    $checks.Add([pscustomobject]@{ id = "powershell"; required = $true; status = if ($PSVersionTable.PSVersion -ge [version]"5.1") { "supported" } else { "unsupported" }; actual = $PSVersionTable.PSVersion.ToString(); message = "PowerShell 5.1 or later is required." })
    $architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    $checks.Add([pscustomobject]@{ id = "architecture"; required = $true; status = if ($architecture -in @("X64", "Arm64")) { "supported" } else { "unsupported" }; actual = $architecture; message = "X64 and Arm64 are supported." })

    if ($IncludeToolInventory) {
        foreach ($tool in Get-CasProfileToolDefinitions -Profile $Profile -Manifest $Manifest) {
            $status = Get-CasToolStatus -Tool $tool
            $checks.Add([pscustomobject]@{ id = "tool:$($tool.id)"; required = $true; status = if ($status.status -eq "installed") { "supported" } elseif ($status.status -eq "missing") { "unknown" } else { "unsupported" }; actual = $status.installedVersion; message = $status.message })
        }
    }

    [pscustomobject]@{
        profile = $Profile
        compatible = @($checks | Where-Object { $_.required -and $_.status -ne "supported" }).Count -eq 0
        checks = $checks.ToArray()
    }
}

function Resolve-CasCanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $fullPath = [IO.Path]::GetFullPath($Path)
    }
    catch {
        throw "Path '$Path' cannot be canonicalized: $($_.Exception.Message)"
    }

    $root = [IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.Length -gt $root.Length) {
        $fullPath = $fullPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    }
    $fullPath
}

function Get-CasForbiddenPaths {
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in @($env:USERPROFILE, $env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData)) {
        if ($candidate) {
            $paths.Add((Resolve-CasCanonicalPath -Path $candidate))
        }
    }
    foreach ($drive in [IO.DriveInfo]::GetDrives()) {
        $paths.Add((Resolve-CasCanonicalPath -Path $drive.RootDirectory.FullName))
    }
    $paths.ToArray() | Sort-Object -Unique
}

function Test-CasPathHasReparsePoint {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$StopAt
    )

    $current = Resolve-CasCanonicalPath -Path $Path
    $stop = Resolve-CasCanonicalPath -Path $StopAt
    while ($current.StartsWith($stop, [StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                return $true
            }
        }
        if ($current.Equals($stop, [StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current) {
            break
        }
        $current = $parent
    }
    $false
}

function Assert-CasSafePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$ApprovedRoots,
        [switch]$AllowBoundary
    )

    $canonical = Resolve-CasCanonicalPath -Path $Path
    $approved = $null
    foreach ($rootPath in $ApprovedRoots) {
        $root = Resolve-CasCanonicalPath -Path $rootPath
        $prefix = "$root$([IO.Path]::DirectorySeparatorChar)"
        if ($canonical.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or ($AllowBoundary -and $canonical.Equals($root, [StringComparison]::OrdinalIgnoreCase))) {
            $approved = $root
            break
        }
    }
    if (-not $approved) {
        throw "Path '$canonical' is outside approved CAS boundaries."
    }

    foreach ($forbidden in Get-CasForbiddenPaths) {
        if ($canonical.Equals($forbidden, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Path '$canonical' is a forbidden root."
        }
    }

    foreach ($systemRoot in @($env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData)) {
        if ($systemRoot) {
            $forbidden = Resolve-CasCanonicalPath -Path $systemRoot
            if ($canonical.StartsWith("$forbidden$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::OrdinalIgnoreCase)) {
                throw "Path '$canonical' is inside a forbidden system directory."
            }
        }
    }

    if (Test-CasPathHasReparsePoint -Path $canonical -StopAt $approved) {
        throw "Path '$canonical' or an existing ancestor is a reparse point."
    }
    $canonical
}

function New-CasManagedState {
    param(
        [Parameter(Mandatory = $true)][string]$BundleId,
        [Parameter(Mandatory = $true)][string]$Profile,
        [Parameter(Mandatory = $true)][string]$DesiredStateDigest
    )

    [pscustomobject]@{
        schemaVersion = "1.0.0"
        bundleId = $BundleId
        profile = $Profile
        desiredStateDigest = $DesiredStateDigest
        resources = @()
        operations = @()
    }
}

function Add-CasManagedResource {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$State,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][ValidateSet("directory", "file", "repository", "configuration", "tool")][string]$Kind,
        [Parameter(Mandatory = $true)][ValidateSet("created", "modified", "observed")][string]$Ownership,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][bool]$WasPresentBefore,
        [string]$BackupTarget,
        [string]$ContentDigest
    )

    if ($Ownership -eq "created" -and $WasPresentBefore) {
        throw "Resource '$Id' cannot be owned as created because it existed before CAS management."
    }
    if ($Ownership -eq "modified" -and (-not $WasPresentBefore -or -not $BackupTarget)) {
        throw "Modified resource '$Id' requires pre-existing evidence and a backup target."
    }
    if (@($State.resources | Where-Object id -eq $Id).Count -gt 0) {
        throw "Managed resource id '$Id' already exists."
    }

    $State.resources += [pscustomobject]@{
        id = $Id
        kind = $Kind
        ownership = $Ownership
        target = Resolve-CasCanonicalPath -Path $Target
        wasPresentBefore = $WasPresentBefore
        backupTarget = if ($BackupTarget) { Resolve-CasCanonicalPath -Path $BackupTarget } else { $null }
        contentDigest = if ($ContentDigest) { $ContentDigest } else { $null }
    }
    $State
}

function Assert-CasManagedState {
    param([Parameter(Mandatory = $true)][pscustomobject]$State)

    if ($State.schemaVersion -ne "1.0.0" -or $State.desiredStateDigest -notmatch '^sha256:[a-f0-9]{64}$') {
        throw "Managed state has an invalid schema version or desired-state digest."
    }
    if (@($State.resources | ForEach-Object id | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
        throw "Managed state contains duplicate resource ids."
    }
    foreach ($resource in @($State.resources)) {
        if ($resource.ownership -eq "created" -and $resource.wasPresentBefore) {
            throw "Created resource '$($resource.id)' has conflicting pre-existing evidence."
        }
        if ($resource.ownership -eq "modified" -and (-not $resource.wasPresentBefore -or -not $resource.backupTarget)) {
            throw "Modified resource '$($resource.id)' is missing backup evidence."
        }
    }
}

function Write-CasAtomicJson {
    param(
        [Parameter(Mandatory = $true)][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$ApprovedRoots,
        [switch]$AllowBoundary
    )

    $target = Assert-CasSafePath -Path $Path -ApprovedRoots $ApprovedRoots -AllowBoundary:$AllowBoundary
    $directory = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        throw "Atomic write parent directory does not exist: $directory"
    }

    $json = $InputObject | ConvertTo-Json -Depth 30
    $null = $json | ConvertFrom-Json
    $temp = Join-Path $directory ".$([IO.Path]::GetFileName($target)).$([Guid]::NewGuid().ToString('N')).tmp"
    $backup = $null
    try {
        [IO.File]::WriteAllText($temp, $json, (New-Object Text.UTF8Encoding($false)))
        $null = Get-Content -LiteralPath $temp -Raw | ConvertFrom-Json
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $backup = "$target.backup.$([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff'))"
            [IO.File]::Replace($temp, $target, $backup)
        }
        else {
            [IO.File]::Move($temp, $target)
        }
    }
    finally {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Force
        }
    }
    $backup
}

function Write-CasManagedState {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$State,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$ApprovedRoots
    )

    Assert-CasManagedState -State $State
    Write-CasAtomicJson -InputObject $State -Path $Path -ApprovedRoots $ApprovedRoots
}

function Read-CasManagedState {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Managed state was not found: $Path"
    }
    try {
        $state = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Managed state '$Path' is not valid JSON: $($_.Exception.Message)"
    }
    Assert-CasManagedState -State $state
    $state
}

function Get-CasManagedStatePath {
    param(
        [string]$ConfigPath = (Get-CasDefaultConfigPath),
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    Join-Path (Join-Path $ConfigPath $Manifest.paths.state) "managed-state.json"
}

function Get-CasUninstallPreview {
    param(
        [Parameter(Mandatory = $true)][string]$StatePath,
        [Parameter(Mandatory = $true)][string[]]$ApprovedRoots
    )

    $state = Read-CasManagedState -Path $StatePath
    $actions = New-Object System.Collections.Generic.List[object]
    foreach ($resource in @($state.resources)) {
        if ($resource.ownership -eq "observed") {
            $actions.Add([pscustomobject]@{
                id = $resource.id
                kind = $resource.kind
                ownership = $resource.ownership
                target = $resource.target
                action = "preserve"
                actionable = $false
            })
            continue
        }

        $target = Assert-CasSafePath -Path $resource.target -ApprovedRoots $ApprovedRoots -AllowBoundary
        if ($resource.kind -eq "directory" -and $resource.ownership -eq "created" -and $resource.contentDigest) {
            $backup = $null
            $action = "remove-owned-tree"
        }
        elseif ($resource.kind -eq "configuration" -and $resource.id -like "client:*") {
            $backup = $null
            $action = "remove-owned-configuration"
        }
        elseif ($resource.ownership -eq "modified") {
            $backup = Assert-CasSafePath -Path $resource.backupTarget -ApprovedRoots $ApprovedRoots
            if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) {
                throw "Backup for modified resource '$($resource.id)' was not found: $backup"
            }
            $action = "restore-backup"
        }
        else {
            $backup = $null
            $action = "remove-created"
        }

        $actions.Add([pscustomobject]@{
            id = $resource.id
            kind = $resource.kind
            ownership = $resource.ownership
            target = $target
            backupTarget = $backup
            contentDigest = $resource.contentDigest
            action = $action
            actionable = $true
        })
    }

    [pscustomobject]@{
        schemaVersion = "1.0.0"
        bundleId = $state.bundleId
        statePath = Resolve-CasCanonicalPath -Path $StatePath
        actions = $actions.ToArray()
    }
}

function Restore-CasBackupAtomically {
    param(
        [Parameter(Mandatory = $true)][string]$BackupPath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $directory = Split-Path -Parent $TargetPath
    $temp = Join-Path $directory ".$([IO.Path]::GetFileName($TargetPath)).restore.$([Guid]::NewGuid().ToString('N')).tmp"
    $replacedBackup = Join-Path $directory ".$([IO.Path]::GetFileName($TargetPath)).replaced.$([Guid]::NewGuid().ToString('N')).bak"
    try {
        Copy-Item -LiteralPath $BackupPath -Destination $temp -Force
        if (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
            [IO.File]::Replace($temp, $TargetPath, $replacedBackup)
        }
        else {
            [IO.File]::Move($temp, $TargetPath)
        }
    }
    finally {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Force
        }
        if (Test-Path -LiteralPath $replacedBackup) {
            Remove-Item -LiteralPath $replacedBackup -Force
        }
    }
}

function Invoke-CasUninstall {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Preview,
        [Parameter(Mandatory = $true)][string[]]$ApprovedRoots
    )

    $results = New-Object System.Collections.Generic.List[object]
    $actions = @($Preview.actions | Where-Object actionable | Sort-Object { $_.target.Length } -Descending)
    foreach ($action in $actions) {
        $target = Assert-CasSafePath -Path $action.target -ApprovedRoots $ApprovedRoots -AllowBoundary
        if (-not $PSCmdlet.ShouldProcess($target, $action.action)) {
            continue
        }

        if ($action.action -eq "remove-owned-tree") {
            $actualDigest = Get-CasTreeDigest -Path $target -ApprovedRoots $ApprovedRoots
            if (-not $action.contentDigest -or $actualDigest -ne $action.contentDigest) {
                throw "Managed tree '$($action.id)' does not match ledger ownership evidence."
            }
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        elseif ($action.action -eq "remove-owned-configuration") {
            $clientId = $action.id.Substring("client:".Length)
            $client = (Get-CasManifest).clients | Where-Object id -eq $clientId | Select-Object -First 1
            if (-not $client) { throw "Client adapter '$clientId' was not found for uninstall." }
            if (Test-Path -LiteralPath $target -PathType Leaf) {
                $existing = Get-Content -LiteralPath $target -Raw -Encoding UTF8 | ConvertFrom-Json
                $updated = Remove-CasClientConfiguration -ExistingConfiguration $existing -OwnershipKey $client.ownershipKey
                $null = Write-CasAtomicJson -InputObject $updated -Path $target -ApprovedRoots $ApprovedRoots
            }
        }
        elseif ($action.action -eq "restore-backup") {
            $backup = Assert-CasSafePath -Path $action.backupTarget -ApprovedRoots $ApprovedRoots
            if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) {
                throw "Backup for '$($action.id)' disappeared before apply."
            }
            Restore-CasBackupAtomically -BackupPath $backup -TargetPath $target
        }
        elseif (Test-Path -LiteralPath $target -PathType Leaf) {
            Remove-Item -LiteralPath $target -Force
        }
        elseif (Test-Path -LiteralPath $target -PathType Container) {
            if (@(Get-ChildItem -LiteralPath $target -Force).Count -gt 0) {
                throw "Created directory '$target' is not empty; refusing recursive removal."
            }
            Remove-Item -LiteralPath $target -Force
        }

        $results.Add([pscustomobject]@{ id = $action.id; target = $target; action = $action.action; status = "applied" })
    }
    $results.ToArray()
}

function Get-CasDefaultRootPath {
    param(
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $Manifest.defaults.rootPath
}

function Get-CasDefaultConfigPath {
    param(
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $Manifest.defaults.configPath
}

function Get-CasProfile {
    param(
        [string]$Name = "full",
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $profile = $Manifest.profiles.PSObject.Properties[$Name]
    if (-not $profile) {
        throw "Unknown profile '$Name'."
    }

    $profile.Value
}

function New-CasDirectoryLayout {
    param(
        [string]$RootPath,
        [string]$ConfigPath,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $paths = @(
        $RootPath,
        (Join-Path $RootPath $Manifest.paths.reposRoot),
        $ConfigPath,
        (Join-Path $ConfigPath $Manifest.paths.logs),
        (Join-Path $ConfigPath $Manifest.paths.state),
        (Join-Path $ConfigPath $Manifest.paths.memory),
        (Join-Path $ConfigPath $Manifest.paths.mcp),
        (Join-Path $ConfigPath $Manifest.paths.config),
        (Join-Path (Join-Path $ConfigPath $Manifest.paths.mcp) "clients")
    )

    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

function Get-CasProfileToolDefinitions {
    param(
        [string]$Profile = "full",
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $profileDefinition = Get-CasProfile -Name $Profile -Manifest $Manifest
    $toolIds = @($profileDefinition.tools.required) + @($profileDefinition.tools.optional)
    foreach ($toolId in $toolIds) {
        $Manifest.tools | Where-Object { $_.id -eq $toolId }
    }
}

function Get-CasProfileRepos {
    param(
        [string]$Profile = "full",
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $profileDefinition = Get-CasProfile -Name $Profile -Manifest $Manifest
    $repoIds = @($profileDefinition.repos.required) + @($profileDefinition.repos.optional)
    foreach ($repoId in $repoIds) {
        $Manifest.repos | Where-Object { $_.id -eq $repoId }
    }
}

function Invoke-CasCommandCapture {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList = @()
    )

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & $FilePath @ArgumentList 2>$null
        [string]::Join([Environment]::NewLine, @($output))
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Get-CasVersionFromOutput {
    param(
        [string]$Output,
        [string]$Pattern
    )

    if (-not $Output) {
        return $null
    }

    $match = [regex]::Match($Output, $Pattern)
    if ($match.Success) {
        if ($match.Groups["version"].Success) {
            return $match.Groups["version"].Value.TrimStart("v")
        }
        return $match.Value.TrimStart("v")
    }

    return $null
}

function Compare-CasVersion {
    param(
        [string]$InstalledVersion,
        [string]$MinimumVersion
    )

    if (-not $InstalledVersion -or -not $MinimumVersion) {
        return 0
    }

    try {
        $installed = [version]$InstalledVersion
        $minimum = [version]$MinimumVersion
        return $installed.CompareTo($minimum)
    }
    catch {
        return 0
    }
}

function Get-CasToolStatus {
    param(
        [pscustomobject]$Tool
    )

    $command = Get-Command $Tool.command -ErrorAction SilentlyContinue
    if (-not $command) {
        return [pscustomobject]@{
            id = $Tool.id
            displayName = $Tool.displayName
            required = $true
            status = "missing"
            installedVersion = $null
            minimumVersion = $Tool.minimumVersion
            message = "Command '$($Tool.command)' was not found."
        }
    }

    $output = Invoke-CasCommandCapture -FilePath $command.Source -ArgumentList @($Tool.versionArgs)
    $installedVersion = Get-CasVersionFromOutput -Output $output -Pattern $Tool.versionPattern
    $compare = Compare-CasVersion -InstalledVersion $installedVersion -MinimumVersion $Tool.minimumVersion
    $status = if ($compare -lt 0) { "out-of-date" } else { "installed" }
    $message = if ($status -eq "installed") {
        "$($Tool.displayName) is installed."
    }
    else {
        "$($Tool.displayName) is below the required version $($Tool.minimumVersion)."
    }

    [pscustomobject]@{
        id = $Tool.id
        displayName = $Tool.displayName
        required = $true
        status = $status
        installedVersion = $installedVersion
        minimumVersion = $Tool.minimumVersion
        message = $message
    }
}

function Get-CasRepoStatus {
    param(
        [pscustomobject]$Repo,
        [string]$RootPath,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $path = Join-Path (Join-Path $RootPath $Manifest.paths.reposRoot) $Repo.id
    [pscustomobject]@{
        id = $Repo.id
        status = if (Test-Path -LiteralPath $path) { "present" } else { "missing" }
        path = $path
    }
}

function Test-CasDockerDaemon {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        return [pscustomobject]@{
            id = "docker-daemon"
            status = "missing"
            message = "Docker CLI is not installed."
        }
    }

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & $docker.Source info --format "{{.ServerVersion}}" 2>$null
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($LASTEXITCODE -eq 0) {
        return [pscustomobject]@{
            id = "docker-daemon"
            status = "ready"
            message = "Docker daemon is reachable."
        }
    }

    [pscustomobject]@{
        id = "docker-daemon"
        status = "degraded"
        message = "Docker CLI is installed but the daemon is not reachable."
    }
}

function Test-CasGhAuth {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        return [pscustomobject]@{
            id = "gh-auth"
            status = "missing"
            message = "GitHub CLI is not installed."
        }
    }

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $gh.Source auth status 1>$null 2>$null
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($LASTEXITCODE -eq 0) {
        return [pscustomobject]@{
            id = "gh-auth"
            status = "ready"
            message = "GitHub CLI is authenticated."
        }
    }

    [pscustomobject]@{
        id = "gh-auth"
        status = "degraded"
        message = "GitHub CLI is installed but not authenticated."
    }
}

function Get-CasServiceStatuses {
    param(
        [string]$Profile = "full"
    )

    $statuses = @()
    $profileDefinition = Get-CasProfile -Name $Profile
    $profileServices = @($profileDefinition.services.required) + @($profileDefinition.services.optional)
    foreach ($service in $profileServices) {
        switch ($service) {
            "docker-daemon" { $statuses += Test-CasDockerDaemon }
            "gh-auth" { $statuses += Test-CasGhAuth }
            default {
                $statuses += [pscustomobject]@{
                    id = $service
                    status = "degraded"
                    message = "Unknown service check."
                }
            }
        }
    }

    $statuses
}

function Get-CasOverallStatus {
    param(
        [object[]]$ToolStatuses,
        [object[]]$ServiceStatuses,
        [object[]]$RepoStatuses
    )

    if ($ToolStatuses.status -contains "missing" -or $ToolStatuses.status -contains "out-of-date") {
        return "not-ready"
    }

    if ($ServiceStatuses.status -contains "missing" -or $ServiceStatuses.status -contains "degraded") {
        return "degraded"
    }

    if ($RepoStatuses.status -contains "missing") {
        return "degraded"
    }

    "ready"
}

function Get-CasRecommendations {
    param(
        [object[]]$ToolStatuses,
        [object[]]$ServiceStatuses,
        [object[]]$RepoStatuses
    )

    $messages = New-Object System.Collections.Generic.List[string]

    foreach ($tool in $ToolStatuses | Where-Object { $_.status -eq "missing" }) {
        $messages.Add("Install $($tool.displayName).")
    }

    foreach ($tool in $ToolStatuses | Where-Object { $_.status -eq "out-of-date" }) {
        $messages.Add("Upgrade $($tool.displayName) to at least $($tool.minimumVersion).")
    }

    foreach ($service in $ServiceStatuses | Where-Object { $_.status -ne "ready" }) {
        switch ($service.id) {
            "docker-daemon" { $messages.Add("Start Docker Desktop and confirm the daemon is reachable.") }
            "gh-auth" { $messages.Add("Authenticate GitHub CLI with 'gh auth login'.") }
            default { $messages.Add($service.message) }
        }
    }

    foreach ($repo in $RepoStatuses | Where-Object { $_.status -eq "missing" }) {
        $messages.Add("Clone or install the managed repo '$($repo.id)'.")
    }

    $messages.ToArray()
}

function Get-CasDoctorReport {
    param(
        [string]$Profile = "full",
        [string]$RootPath = (Get-CasDefaultRootPath),
        [string]$ConfigPath = (Get-CasDefaultConfigPath),
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $toolStatuses = @(Get-CasProfileToolDefinitions -Profile $Profile -Manifest $Manifest | ForEach-Object {
        Get-CasToolStatus -Tool $_
    })
    $serviceStatuses = @(Get-CasServiceStatuses -Profile $Profile)
    $repoStatuses = @(Get-CasProfileRepos -Profile $Profile -Manifest $Manifest | ForEach-Object {
        Get-CasRepoStatus -Repo $_ -RootPath $RootPath -Manifest $Manifest
    })
    $overallStatus = Get-CasOverallStatus -ToolStatuses $toolStatuses -ServiceStatuses $serviceStatuses -RepoStatuses $repoStatuses
    $recommendations = @(Get-CasRecommendations -ToolStatuses $toolStatuses -ServiceStatuses $serviceStatuses -RepoStatuses $repoStatuses)

    [pscustomobject]@{
        schemaVersion = "1.0.0"
        bundleId = $Manifest.bundleId
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        profile = $Profile
        rootPath = $RootPath
        configPath = $ConfigPath
        overallStatus = $overallStatus
        tools = $toolStatuses
        services = $serviceStatuses
        repos = $repoStatuses
        recommendations = $recommendations
    }
}

function Write-CasDoctorReport {
    param(
        [pscustomobject]$Report,
        [string]$JsonPath
    )

    if ($JsonPath) {
        $directory = Split-Path -Parent $JsonPath
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        $Report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $JsonPath -Encoding UTF8
    }

    $Report
}

function Get-CasClientTarget {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Client,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    Join-Path (Join-Path (Join-Path $ConfigPath $Manifest.paths.mcp) "clients") $Client.fileName
}

function Get-CasDesiredMcpNode {
    param([pscustomobject]$Manifest = (Get-CasManifest))

    [ordered]@{
        command = $Manifest.sharedMcpServer.command
        args = @($Manifest.sharedMcpServer.args)
        transport = $Manifest.sharedMcpServer.transport
        scope = $Manifest.sharedMcpServer.scope
        authReference = $Manifest.sharedMcpServer.authReference
    }
}

function Get-CasObjectPropertyValue {
    param([object]$InputObject, [string]$Name)

    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) { $property.Value }
}

function Merge-CasClientConfiguration {
    param(
        [object]$ExistingConfiguration,
        [Parameter(Mandatory = $true)][pscustomobject]$Client,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $merged = if ($null -eq $ExistingConfiguration) {
        [pscustomobject]@{}
    }
    else {
        $ExistingConfiguration | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    }
    $servers = Get-CasObjectPropertyValue -InputObject $merged -Name "mcpServers"
    if ($null -eq $servers) {
        $servers = [pscustomobject]@{}
        $merged | Add-Member -MemberType NoteProperty -Name "mcpServers" -Value $servers
    }
    elseif ($servers -isnot [pscustomobject]) {
        throw "Client '$($Client.id)' has an invalid mcpServers object."
    }

    $node = [pscustomobject](Get-CasDesiredMcpNode -Manifest $Manifest)
    $property = $servers.PSObject.Properties[$Client.ownershipKey]
    if ($property) {
        $property.Value = $node
    }
    else {
        $servers | Add-Member -MemberType NoteProperty -Name $Client.ownershipKey -Value $node
    }
    $merged
}

function Remove-CasClientConfiguration {
    param(
        [Parameter(Mandatory = $true)][object]$ExistingConfiguration,
        [Parameter(Mandatory = $true)][string]$OwnershipKey
    )

    $updated = $ExistingConfiguration | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $servers = Get-CasObjectPropertyValue -InputObject $updated -Name "mcpServers"
    if ($servers -and $servers.PSObject.Properties[$OwnershipKey]) {
        $servers.PSObject.Properties.Remove($OwnershipKey)
    }
    $updated
}

function Get-CasClientConfigurationStatus {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Client,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $target = Get-CasClientTarget -Client $Client -ConfigPath $ConfigPath -Manifest $Manifest
    $desiredDigest = Get-CasSha256 -Value (ConvertTo-CasCanonicalJson -InputObject (Get-CasDesiredMcpNode -Manifest $Manifest))
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        return [pscustomobject]@{ status = "missing"; target = $target; desiredDigest = $desiredDigest; observedDigest = $null }
    }
    try {
        $configuration = Get-Content -LiteralPath $target -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{ status = "unsupported"; target = $target; desiredDigest = $desiredDigest; observedDigest = $null }
    }
    $servers = Get-CasObjectPropertyValue -InputObject $configuration -Name "mcpServers"
    $node = Get-CasObjectPropertyValue -InputObject $servers -Name $Client.ownershipKey
    if ($null -eq $node) {
        return [pscustomobject]@{ status = "missing"; target = $target; desiredDigest = $desiredDigest; observedDigest = $null }
    }
    $observedDigest = Get-CasSha256 -Value (ConvertTo-CasCanonicalJson -InputObject $node)
    [pscustomobject]@{
        status = if ($observedDigest -eq $desiredDigest) { "satisfied" } else { "drifted" }
        target = $target
        desiredDigest = $desiredDigest
        observedDigest = $observedDigest
    }
}

function Set-CasClientConfiguration {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Client,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [string[]]$ApprovedRoots = @($ConfigPath),
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $target = Get-CasClientTarget -Client $Client -ConfigPath $ConfigPath -Manifest $Manifest
    $parent = Split-Path -Parent $target
    $null = Assert-CasSafePath -Path $parent -ApprovedRoots $ApprovedRoots -AllowBoundary
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $existing = if (Test-Path -LiteralPath $target -PathType Leaf) {
        Get-Content -LiteralPath $target -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    else { $null }
    $merged = Merge-CasClientConfiguration -ExistingConfiguration $existing -Client $Client -Manifest $Manifest
    $backup = Write-CasAtomicJson -InputObject $merged -Path $target -ApprovedRoots $ApprovedRoots
    $status = Get-CasClientConfigurationStatus -Client $Client -ConfigPath $ConfigPath -Manifest $Manifest
    if ($status.status -ne "satisfied") {
        throw "Client configuration '$($Client.id)' failed post-write verification."
    }
    [pscustomobject]@{ target = $target; backupTarget = $backup; contentDigest = $status.desiredDigest; wasPresentBefore = [bool]$existing }
}

function Get-CasTreeDigest {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$ApprovedRoots
    )

    $root = Assert-CasSafePath -Path $Path -ApprovedRoots $ApprovedRoots
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        return $null
    }
    $entries = @(
        Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName | ForEach-Object {
            $null = Assert-CasSafePath -Path $_.FullName -ApprovedRoots $root
            [ordered]@{
                path = $_.FullName.Substring($root.Length).TrimStart("\", "/").Replace("\", "/")
                digest = "sha256:$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())"
            }
        }
    )
    Get-CasSha256 -Value (ConvertTo-CasCanonicalJson -InputObject $entries)
}

function Copy-CasManagedTree {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string[]]$ApprovedRoots,
        [switch]$ReplaceOwned,
        [string]$ExpectedOwnedDigest
    )

    $sourceRoot = Assert-CasSafePath -Path $Source -ApprovedRoots $ApprovedRoots
    $targetRoot = Assert-CasSafePath -Path $Target -ApprovedRoots $ApprovedRoots
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        throw "Managed tree source was not found: $sourceRoot"
    }
    if ((Test-Path -LiteralPath $targetRoot) -and -not $ReplaceOwned) {
        throw "Managed tree target already exists and cannot be adopted: $targetRoot"
    }
    if (-not (Test-Path -LiteralPath $targetRoot)) {
        New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    }
    if ($ReplaceOwned) {
        $actualDigest = Get-CasTreeDigest -Path $targetRoot -ApprovedRoots $ApprovedRoots
        if (-not $ExpectedOwnedDigest -or $actualDigest -ne $ExpectedOwnedDigest) {
            throw "Managed tree target does not match prior ownership evidence."
        }
        Remove-Item -LiteralPath $targetRoot -Recurse -Force
        New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    }
    foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File) {
        $null = Assert-CasSafePath -Path $file.FullName -ApprovedRoots $sourceRoot
        $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart("\", "/")
        $destination = Join-Path $targetRoot $relative
        $null = Assert-CasSafePath -Path $destination -ApprovedRoots $targetRoot
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    }
    [pscustomobject]@{ target = $targetRoot; contentDigest = Get-CasTreeDigest -Path $targetRoot -ApprovedRoots $ApprovedRoots; wasPresentBefore = $false }
}

function Get-CasOperationInventory {
    param(
        [string]$Profile = "full",
        [string]$RootPath = (Get-CasDefaultRootPath),
        [string]$ConfigPath = (Get-CasDefaultConfigPath),
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $resources = New-Object System.Collections.Generic.List[object]
    $managedStatePath = Get-CasManagedStatePath -ConfigPath $ConfigPath -Manifest $Manifest
    $managedState = if (Test-Path -LiteralPath $managedStatePath -PathType Leaf) { Read-CasManagedState -Path $managedStatePath } else { $null }
    foreach ($tool in Get-CasProfileToolDefinitions -Profile $Profile -Manifest $Manifest) {
        $status = Get-CasToolStatus -Tool $tool
        $null = $resources.Add([pscustomobject]@{ id = "tool:$($tool.id)"; status = $status.status; detail = $status.installedVersion })
    }
    foreach ($repo in Get-CasProfileRepos -Profile $Profile -Manifest $Manifest) {
        $path = Join-Path (Join-Path $RootPath $Manifest.paths.reposRoot) $repo.id
        $status = if (Test-Path -LiteralPath $path -PathType Container) {
            (Get-CasRepositorySafetyStatus -Path $path -ExpectedOrigin $repo.url -ExpectedBranch $repo.defaultBranch).status
        }
        else {
            "missing"
        }
        $null = $resources.Add([pscustomobject]@{ id = "repo:$($repo.id)"; status = $status; detail = $path })
    }
    $profileDefinition = Get-CasProfile -Name $Profile -Manifest $Manifest
    $selectedRepoIds = @($profileDefinition.repos.required) + @($profileDefinition.repos.optional)
    foreach ($clientId in @($profileDefinition.clients.required) + @($profileDefinition.clients.optional)) {
        $client = $Manifest.clients | Where-Object id -eq $clientId | Select-Object -First 1
        $status = Get-CasClientConfigurationStatus -Client $client -ConfigPath $ConfigPath -Manifest $Manifest
        if ($status.status -eq "drifted" -and ($null -eq $managedState -or @($managedState.resources | Where-Object id -eq "client:$clientId").Count -eq 0)) {
            $status.status = "conflicting"
        }
        $null = $resources.Add([pscustomobject]@{ id = "client:$clientId"; status = $status.status; detail = $status.target; desiredDigest = $status.desiredDigest })
    }
    foreach ($category in @("skills", "workspaces")) {
        foreach ($id in @($profileDefinition.$category.required) + @($profileDefinition.$category.optional)) {
            $definition = $Manifest.$category | Where-Object id -eq $id | Select-Object -First 1
            $source = Join-Path (Join-Path (Join-Path $RootPath $Manifest.paths.reposRoot) $definition.repo) $definition.sourceRelativePath
            $target = Join-Path $ConfigPath $definition.targetRelativePath
            $sourceDigest = $null
            $targetDigest = $null
            $status = if (-not (Test-Path -LiteralPath $source -PathType Container)) { if ($selectedRepoIds -contains $definition.repo) { "pending-source" } else { "unsupported" } } elseif (-not (Test-Path -LiteralPath $target -PathType Container)) { "missing" } else {
                $sourceDigest = Get-CasTreeDigest -Path $source -ApprovedRoots $RootPath
                $targetDigest = Get-CasTreeDigest -Path $target -ApprovedRoots $ConfigPath
                if ($sourceDigest -eq $targetDigest) { "satisfied" } elseif ($managedState -and @($managedState.resources | Where-Object id -eq "$($category.TrimEnd('s')):$id").Count -gt 0) { "drifted" } else { "conflicting" }
            }
            $null = $resources.Add([pscustomobject]@{ id = "$($category.TrimEnd('s')):$id"; status = $status; detail = $target; desiredDigest = $sourceDigest; observedDigest = $targetDigest })
        }
    }
    [pscustomobject]@{ resources = $resources.ToArray() }
}

function New-CasOperationPlan {
    param(
        [ValidateSet("setup", "upgrade", "repair")][string]$Mode = "setup",
        [string]$Profile = "full",
        [string]$RootPath = (Get-CasDefaultRootPath),
        [string]$ConfigPath = (Get-CasDefaultConfigPath),
        [pscustomobject]$Manifest = (Get-CasManifest),
        [pscustomobject]$Inventory
    )

    if (-not $Inventory) {
        $Inventory = [pscustomobject]@{ resources = @() }
    }
    $resolved = Resolve-CasDesiredState -Profile $Profile -Manifest $Manifest
    $operations = New-Object System.Collections.Generic.List[object]

    foreach ($resource in @($resolved.desiredState.resources | Sort-Object category, id)) {
        $inventoryId = "$($resource.category.TrimEnd('s')):$($resource.id)"
        $actual = @($Inventory.resources | Where-Object id -eq $inventoryId | Select-Object -First 1)
        switch ($resource.category) {
            "tools" {
                $installer = @($resource.definition.installers | Where-Object kind -ne "manual" | Select-Object -First 1)
                $satisfied = $actual.Count -gt 0 -and $actual[0].status -eq "installed"
                $command = if ($installer.Count -gt 0) { "$($installer[0].kind) install $($installer[0].id)" } else { "manual" }
                $source = if ($installer.Count -gt 0) { "$($installer[0].kind):$($installer[0].id)" } else { "manual" }
                $null = $operations.Add([ordered]@{
                    id = "tool:$($resource.id)"
                    kind = "tool"
                    target = $resource.id
                    risk = if ($satisfied) { "low" } else { "medium" }
                    action = if ($satisfied) { "skip" } else { "update" }
                    command = $command
                    source = $source
                    reason = if ($satisfied) { "Desired tool state is satisfied." } else { "Tool is missing or below policy." }
                })
            }
            "repos" {
                $target = Join-Path (Join-Path $RootPath $Manifest.paths.reposRoot) $resource.id
                $satisfied = $actual.Count -gt 0 -and $actual[0].status -eq "synchronized"
                $present = $actual.Count -gt 0 -and $actual[0].status -in @("present", "behind", "synchronized")
                $null = $operations.Add([ordered]@{
                    id = "repo:$($resource.id)"
                    kind = "repository"
                    target = $target
                    risk = if ($satisfied) { "low" } else { "medium" }
                    action = if ($satisfied) { "skip" } elseif ($present) { "update" } else { "create" }
                    command = if ($present) { "git fetch and fast-forward" } else { "git clone" }
                    source = $resource.definition.url
                    reason = if ($satisfied) { "Repository is synchronized." } elseif ($present) { "Repository requires safe synchronization." } else { "Repository is missing." }
                    defaultBranch = $resource.definition.defaultBranch
                })
            }
            "clients" {
                $status = if ($actual.Count -gt 0 -and $actual[0].status -eq "synchronized") { "satisfied" } elseif ($actual.Count -gt 0) { $actual[0].status } else { "missing" }
                if ($status -in @("unsupported", "conflicting")) { throw "Client '$($resource.id)' has $status configuration state." }
                $target = Get-CasClientTarget -Client $resource.definition -ConfigPath $ConfigPath -Manifest $Manifest
                $null = $operations.Add([ordered]@{
                    id = "client:$($resource.id)"
                    kind = "configuration"
                    resourceCategory = "client"
                    adapter = $resource.definition.adapter
                    ownershipKey = $resource.definition.ownershipKey
                    target = $target
                    risk = if ($status -eq "satisfied") { "low" } else { "medium" }
                    action = if ($status -eq "satisfied") { "skip" } elseif ($status -eq "missing") { "create" } else { "update" }
                    command = "merge CAS-owned MCP configuration"
                    source = "manifest:sharedMcpServer"
                    desiredDigest = if ($actual.Count -gt 0 -and $actual[0].PSObject.Properties["desiredDigest"]) { $actual[0].desiredDigest } else { Get-CasSha256 -Value (ConvertTo-CasCanonicalJson -InputObject (Get-CasDesiredMcpNode -Manifest $Manifest)) }
                    reason = if ($status -eq "satisfied") { "CAS-owned client configuration is satisfied." } else { "CAS-owned client configuration is missing or drifted." }
                })
            }
            { $_ -in @("skills", "workspaces") } {
                $status = if ($actual.Count -gt 0 -and $actual[0].status -eq "synchronized") { "satisfied" } elseif ($actual.Count -gt 0) { $actual[0].status } else { "missing" }
                if ($status -in @("conflicting", "unsupported")) { throw "$($resource.category.TrimEnd('s')) '$($resource.id)' has $status state and cannot be reconciled safely." }
                $source = Join-Path (Join-Path (Join-Path $RootPath $Manifest.paths.reposRoot) $resource.definition.repo) $resource.definition.sourceRelativePath
                $target = Join-Path $ConfigPath $resource.definition.targetRelativePath
                $null = $operations.Add([ordered]@{
                    id = "$($resource.category.TrimEnd('s')):$($resource.id)"
                    kind = "directory"
                    resourceCategory = $resource.category.TrimEnd("s")
                    adapter = $resource.definition.adapter
                    target = $target
                    risk = if ($status -eq "satisfied") { "low" } else { "medium" }
                    action = if ($status -eq "satisfied") { "skip" } elseif ($status -eq "drifted") { "update" } else { "create" }
                    command = "copy allowlisted managed tree"
                    source = $source
                    observedDigest = if ($actual.Count -gt 0 -and $actual[0].PSObject.Properties["observedDigest"]) { $actual[0].observedDigest } else { $null }
                    reason = if ($status -eq "satisfied") { "Managed tree is satisfied." } else { "Managed tree is missing." }
                })
            }
        }
    }

    $kindOrder = @{ tool = 0; repository = 1; directory = 2; configuration = 3 }
    $sortedOperations = @($operations.ToArray() | Sort-Object @{ Expression = { $kindOrder[$_.kind] } }, @{ Expression = { $_.id } })
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
    [pscustomobject]@{
        schemaVersion = "1.0.0"
        planId = $planId
        correlationId = $planId
        mode = $Mode
        profile = $Profile
        rootPath = $identity.rootPath
        configPath = $identity.configPath
        desiredStateDigest = $resolved.digest
        operations = $sortedOperations
    }
}

function Assert-CasOperationPlan {
    param([Parameter(Mandatory = $true)][pscustomobject]$Plan)

    if ($Plan.schemaVersion -ne "1.0.0" -or $Plan.planId -notmatch '^sha256:[a-f0-9]{64}$') {
        throw "Operation plan has an invalid schema version or plan id."
    }
    if ($Plan.desiredStateDigest -notmatch '^sha256:[a-f0-9]{64}$') {
        throw "Operation plan has an invalid desired-state digest."
    }
    $identity = [ordered]@{
        schemaVersion = $Plan.schemaVersion
        mode = $Plan.mode
        profile = $Plan.profile
        rootPath = $Plan.rootPath
        configPath = $Plan.configPath
        desiredStateDigest = $Plan.desiredStateDigest
        operations = @($Plan.operations)
    }
    $expectedPlanId = Get-CasSha256 -Value (ConvertTo-CasCanonicalJson -InputObject $identity)
    if ($Plan.planId -ne $expectedPlanId) {
        throw "Operation plan integrity validation failed."
    }
    if (@($Plan.operations | ForEach-Object id | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
        throw "Operation plan contains duplicate operation ids."
    }
    foreach ($operation in @($Plan.operations)) {
        if ($operation.action -notin @("create", "update", "remove", "skip") -or $operation.risk -notin @("low", "medium", "high")) {
            throw "Operation '$($operation.id)' has an invalid action or risk."
        }
    }
    $Plan
}

function Get-CasOperationFilePaths {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Plan,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $safeId = $Plan.planId -replace '[^A-Za-z0-9._-]', '-'
    [pscustomobject]@{
        journal = Join-Path (Join-Path $ConfigPath $Manifest.paths.state) "operation-$safeId.json"
        events = Join-Path (Join-Path $ConfigPath $Manifest.paths.logs) "operation-$safeId.jsonl"
    }
}

function Write-CasOperationEvent {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$CorrelationId,
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][ValidateSet("started", "succeeded", "failed", "skipped")][string]$Outcome,
        [Parameter(Mandatory = $true)][string]$Message,
        [hashtable]$Metadata = @{}
    )

    $event = [ordered]@{
        schemaVersion = "1.0.0"
        timestampUtc = [DateTime]::UtcNow.ToString("o")
        correlationId = $CorrelationId
        eventType = $EventType
        outcome = $Outcome
        message = $Message
        metadata = $Metadata
    }
    Add-Content -LiteralPath $Path -Value (ConvertTo-CasCanonicalJson -InputObject $event) -Encoding UTF8
    [pscustomobject]$event
}

function New-CasOperationJournal {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Plan,
        [Parameter(Mandatory = $true)][string]$CorrelationId,
        [Parameter(Mandatory = $true)][int]$MaxRetries
    )

    [pscustomobject]@{
        schemaVersion = "1.0.0"
        planId = $Plan.planId
        correlationId = $CorrelationId
        status = "pending"
        maxRetries = $MaxRetries
        startedAtUtc = [DateTime]::UtcNow.ToString("o")
        completedAtUtc = $null
        plan = $Plan
        operations = @($Plan.operations | ForEach-Object {
            [pscustomobject]@{
                id = $_.id
                status = "pending"
                attempts = 0
                lastError = $null
                guidance = "Not started."
            }
        })
    }
}

function Write-CasOperationJournal {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Journal,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$ApprovedRoots
    )

    $null = Write-CasAtomicJson -InputObject $Journal -Path $Path -ApprovedRoots $ApprovedRoots
}

function Read-CasOperationJournal {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Operation journal was not found: $Path"
    }
    try {
        Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Operation journal '$Path' is not valid JSON: $($_.Exception.Message)"
    }
}

function Invoke-CasPlannedOperation {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Operation,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    if ($Operation.action -eq "skip") {
        return
    }
    if ($Operation.kind -eq "tool") {
        $parts = $Operation.source -split ':', 2
        switch ($parts[0]) {
            "winget" { & winget install --exact --id $parts[1] --accept-package-agreements --accept-source-agreements }
            "scoop" { & scoop install $parts[1] }
            "npm" { & npm install -g $parts[1] }
            default { throw "Tool operation '$($Operation.id)' has no executable allowlisted adapter." }
        }
        if ($LASTEXITCODE -ne 0) { throw "Tool operation '$($Operation.id)' failed with exit code $LASTEXITCODE." }
        return
    }
    if ($Operation.kind -eq "repository") {
        if ($Operation.action -eq "create") {
            & git clone $Operation.source $Operation.target
        }
        else {
            $null = Get-CasRepositorySafetyStatus -Path $Operation.target -ExpectedOrigin $Operation.source -ExpectedBranch $Operation.defaultBranch
            & git -C $Operation.target fetch origin
            if ($LASTEXITCODE -eq 0) {
                $null = Get-CasRepositorySafetyStatus -Path $Operation.target -ExpectedOrigin $Operation.source -ExpectedBranch $Operation.defaultBranch
                & git -C $Operation.target merge --ff-only "origin/$($Operation.defaultBranch)"
            }
        }
        if ($LASTEXITCODE -ne 0) { throw "Repository operation '$($Operation.id)' failed with exit code $LASTEXITCODE." }
        return
    }
    if ($Operation.kind -eq "configuration" -and $Operation.adapter -eq "json-mcp") {
        $clientId = $Operation.id.Substring("client:".Length)
        $client = $Manifest.clients | Where-Object id -eq $clientId | Select-Object -First 1
        $configPath = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Operation.target))
        return Set-CasClientConfiguration -Client $client -ConfigPath $configPath -ApprovedRoots $configPath -Manifest $Manifest
    }
    if ($Operation.kind -eq "directory" -and $Operation.adapter -eq "tree-copy") {
        $observedDigest = if ($Operation.PSObject.Properties["observedDigest"]) { $Operation.observedDigest } else { $null }
        return Copy-CasManagedTree -Source $Operation.source -Target $Operation.target -ApprovedRoots @((Split-Path -Parent $Operation.source), (Split-Path -Parent $Operation.target)) -ReplaceOwned:($Operation.action -eq "update") -ExpectedOwnedDigest $observedDigest
    }
    throw "No executor is registered for operation kind '$($Operation.kind)'."
}

function Update-CasManagedStateFromOperation {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Plan,
        [Parameter(Mandatory = $true)][pscustomobject]$Operation,
        [AllowNull()][object]$Result,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string[]]$ApprovedRoots,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    if ($null -eq $Result -or -not $Result.PSObject.Properties["target"]) { return }
    $statePath = Get-CasManagedStatePath -ConfigPath $ConfigPath -Manifest $Manifest
    $state = if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        Read-CasManagedState -Path $statePath
    }
    else {
        New-CasManagedState -BundleId $Manifest.bundleId -Profile $Plan.profile -DesiredStateDigest $Plan.desiredStateDigest
    }
    $state.resources = @($state.resources | Where-Object id -ne $Operation.id)
    $wasPresent = [bool]$Result.wasPresentBefore
    $ownership = if ($wasPresent) { "modified" } else { "created" }
    $kind = if ($Operation.kind -eq "configuration") { "configuration" } else { "directory" }
    $backupTarget = if ($Result.PSObject.Properties["backupTarget"]) { $Result.backupTarget } else { $null }
    $contentDigest = if ($Result.PSObject.Properties["contentDigest"]) { $Result.contentDigest } else { $null }
    $null = Add-CasManagedResource -State $state -Id $Operation.id -Kind $kind -Ownership $ownership -Target $Result.target -WasPresentBefore $wasPresent -BackupTarget $backupTarget -ContentDigest $contentDigest
    $null = Write-CasManagedState -State $state -Path $statePath -ApprovedRoots $ApprovedRoots
}

function Invoke-CasOperationPlan {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Plan,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [string[]]$ApprovedRoots,
        [ValidateRange(0, 3)][int]$MaxRetries = 1,
        [switch]$Resume,
        [scriptblock]$OperationHandler,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $null = Assert-CasOperationPlan -Plan $Plan
    if (-not $OperationHandler) {
        $OperationHandler = { param($operation) Invoke-CasPlannedOperation -Operation $operation -Manifest $Manifest }.GetNewClosure()
    }
    if (-not $ApprovedRoots) {
        $ApprovedRoots = @($Plan.rootPath, $ConfigPath)
    }
    $stateRoot = Join-Path $ConfigPath $Manifest.paths.state
    $logRoot = Join-Path $ConfigPath $Manifest.paths.logs
    foreach ($directory in @($ConfigPath, $stateRoot, $logRoot)) {
        $null = Assert-CasSafePath -Path $directory -ApprovedRoots $ApprovedRoots -AllowBoundary
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
    }

    $paths = Get-CasOperationFilePaths -Plan $Plan -ConfigPath $ConfigPath -Manifest $Manifest
    if ($Resume) {
        $journal = Read-CasOperationJournal -Path $paths.journal
        if ($journal.planId -ne $Plan.planId) {
            throw "Operation journal does not match the requested plan."
        }
    }
    else {
        $journal = New-CasOperationJournal -Plan $Plan -CorrelationId ([Guid]::NewGuid().ToString()) -MaxRetries $MaxRetries
    }

    $journal.status = "running"
    Write-CasOperationJournal -Journal $journal -Path $paths.journal -ApprovedRoots $ApprovedRoots
    $null = Write-CasOperationEvent -Path $paths.events -CorrelationId $journal.correlationId -EventType "plan" -Outcome "started" -Message "Operation plan apply started." -Metadata @{ planId = $Plan.planId }

    foreach ($operation in @($Plan.operations)) {
        $entry = $journal.operations | Where-Object id -eq $operation.id | Select-Object -First 1
        if ($entry.status -in @("succeeded", "skipped")) {
            continue
        }
        if ($operation.action -eq "skip") {
            $entry.status = "skipped"
            $entry.guidance = "No action required."
            Write-CasOperationJournal -Journal $journal -Path $paths.journal -ApprovedRoots $ApprovedRoots
            $null = Write-CasOperationEvent -Path $paths.events -CorrelationId $journal.correlationId -EventType $operation.id -Outcome "skipped" -Message $operation.reason -Metadata @{ command = $operation.command; source = $operation.source }
            continue
        }

        $succeeded = $false
        for ($attempt = 0; $attempt -le $MaxRetries -and -not $succeeded; $attempt++) {
            $entry.attempts++
            $entry.status = "running"
            $entry.guidance = "Operation is running."
            Write-CasOperationJournal -Journal $journal -Path $paths.journal -ApprovedRoots $ApprovedRoots
            $null = Write-CasOperationEvent -Path $paths.events -CorrelationId $journal.correlationId -EventType $operation.id -Outcome "started" -Message "Operation attempt $($entry.attempts) started." -Metadata @{ command = $operation.command; source = $operation.source }
            try {
                $operationResult = & $OperationHandler $operation
                Update-CasManagedStateFromOperation -Plan $Plan -Operation $operation -Result $operationResult -ConfigPath $ConfigPath -ApprovedRoots $ApprovedRoots -Manifest $Manifest
                $entry.status = "succeeded"
                $entry.lastError = $null
                $entry.guidance = "No recovery action required."
                $succeeded = $true
                $null = Write-CasOperationEvent -Path $paths.events -CorrelationId $journal.correlationId -EventType $operation.id -Outcome "succeeded" -Message "Operation succeeded." -Metadata @{ attempts = $entry.attempts }
            }
            catch {
                $entry.status = "failed"
                $entry.lastError = $_.Exception.Message
                $entry.guidance = "Inspect the correlated event log, correct the cause, then resume this plan. External operations are not automatically rolled back."
                $null = Write-CasOperationEvent -Path $paths.events -CorrelationId $journal.correlationId -EventType $operation.id -Outcome "failed" -Message $_.Exception.Message -Metadata @{ attempts = $entry.attempts }
            }
            Write-CasOperationJournal -Journal $journal -Path $paths.journal -ApprovedRoots $ApprovedRoots
        }
        if (-not $succeeded) {
            $journal.status = "failed"
            Write-CasOperationJournal -Journal $journal -Path $paths.journal -ApprovedRoots $ApprovedRoots
            return $journal
        }
    }

    $journal.status = "succeeded"
    $journal.completedAtUtc = [DateTime]::UtcNow.ToString("o")
    Write-CasOperationJournal -Journal $journal -Path $paths.journal -ApprovedRoots $ApprovedRoots
    $null = Write-CasOperationEvent -Path $paths.events -CorrelationId $journal.correlationId -EventType "plan" -Outcome "succeeded" -Message "Operation plan apply completed." -Metadata @{ planId = $Plan.planId }
    $journal
}

function ConvertFrom-CasGitRepositoryEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedOrigin,
        [Parameter(Mandatory = $true)][string]$ExpectedBranch,
        [string]$ActualOrigin,
        [string]$ActualBranch,
        [string]$PorcelainStatus,
        [ValidateRange(0, [int]::MaxValue)][int]$Ahead = 0,
        [ValidateRange(0, [int]::MaxValue)][int]$Behind = 0
    )

    if ($ActualOrigin -ne $ExpectedOrigin) {
        throw "Repository origin '$ActualOrigin' does not match expected origin '$ExpectedOrigin'."
    }
    if (-not $ActualBranch) {
        throw "Repository is in detached HEAD state."
    }
    if ($ActualBranch -ne $ExpectedBranch) {
        throw "Repository branch '$ActualBranch' does not match expected branch '$ExpectedBranch'."
    }
    if ($PorcelainStatus) {
        throw "Repository has uncommitted changes and cannot be synchronized safely."
    }
    if ($Ahead -gt 0) {
        throw "Repository has local commits or diverged history and cannot be reconciled automatically."
    }

    [pscustomobject]@{
        status = if ($Behind -gt 0) { "behind" } else { "synchronized" }
        ahead = $Ahead
        behind = $Behind
        branch = $ActualBranch
        origin = $ActualOrigin
    }
}

function Get-CasRepositorySafetyStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedOrigin,
        [Parameter(Mandatory = $true)][string]$ExpectedBranch
    )

    $git = Get-Command git -ErrorAction Stop
    $actualOrigin = (& $git.Source -C $Path remote get-url origin 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0) { throw "Repository at '$Path' does not have a readable origin." }
    $actualBranch = (& $git.Source -C $Path symbolic-ref --quiet --short HEAD 2>$null | Select-Object -First 1)
    $porcelain = [string]::Join([Environment]::NewLine, @(& $git.Source -C $Path status --porcelain 2>$null))
    $counts = [string]::Join(" ", @(& $git.Source -C $Path rev-list --left-right --count "HEAD...origin/$ExpectedBranch" 2>$null)).Trim() -split '\s+'
    if ($LASTEXITCODE -ne 0 -or $counts.Count -ne 2) {
        throw "Repository at '$Path' cannot prove its relationship to origin/$ExpectedBranch."
    }
    ConvertFrom-CasGitRepositoryEvidence -ExpectedOrigin $ExpectedOrigin -ExpectedBranch $ExpectedBranch -ActualOrigin $actualOrigin -ActualBranch $actualBranch -PorcelainStatus $porcelain -Ahead ([int]$counts[0]) -Behind ([int]$counts[1])
}

function Invoke-CasWorkstationOperation {
    param(
        [ValidateSet("setup", "upgrade", "repair")][string]$Mode,
        [ValidateSet("core", "full")][string]$Profile = "full",
        [string]$RootPath,
        [string]$ConfigPath,
        [switch]$Apply,
        [switch]$Resume,
        [pscustomobject]$Inventory,
        [scriptblock]$OperationHandler,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    if (-not $RootPath) { $RootPath = Get-CasDefaultRootPath -Manifest $Manifest }
    if (-not $ConfigPath) { $ConfigPath = Get-CasDefaultConfigPath -Manifest $Manifest }
    if ($Resume -and -not $Apply) {
        throw "Resume requires explicit apply intent."
    }
    if ($Resume) {
        $stateRoot = Join-Path $ConfigPath $Manifest.paths.state
        $failedJournal = @(Get-ChildItem -LiteralPath $stateRoot -Filter "operation-*.json" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | ForEach-Object {
            $candidate = Read-CasOperationJournal -Path $_.FullName
            if ($candidate.status -eq "failed" -and $candidate.plan.mode -eq $Mode -and $candidate.plan.profile -eq $Profile) {
                $candidate
            }
        } | Select-Object -First 1)
        if ($failedJournal.Count -eq 0) {
            throw "No failed $Mode operation journal was found for profile '$Profile'."
        }
        if ($OperationHandler) {
            return Invoke-CasOperationPlan -Plan $failedJournal[0].plan -ConfigPath $ConfigPath -Resume -Manifest $Manifest -OperationHandler $OperationHandler
        }
        return Invoke-CasOperationPlan -Plan $failedJournal[0].plan -ConfigPath $ConfigPath -Resume -Manifest $Manifest
    }
    if (-not $Inventory) {
        $Inventory = Get-CasOperationInventory -Profile $Profile -RootPath $RootPath -ConfigPath $ConfigPath -Manifest $Manifest
    }
    $plan = New-CasOperationPlan -Mode $Mode -Profile $Profile -RootPath $RootPath -ConfigPath $ConfigPath -Manifest $Manifest -Inventory $Inventory
    if (-not $Apply) {
        return $plan
    }

    if ($OperationHandler) {
        return Invoke-CasOperationPlan -Plan $plan -ConfigPath $ConfigPath -Manifest $Manifest -OperationHandler $OperationHandler
    }
    Invoke-CasOperationPlan -Plan $plan -ConfigPath $ConfigPath -Manifest $Manifest
}

function Install-CasTool {
    param(
        [pscustomobject]$Tool
    )

    $status = Get-CasToolStatus -Tool $Tool
    if ($status.status -eq "installed") {
        Write-Host "[ok] $($Tool.displayName) already installed ($($status.installedVersion))."
        return
    }

    foreach ($installer in @($Tool.installers)) {
        switch ($installer.kind) {
            "scoop" {
                $scoop = Get-Command scoop -ErrorAction SilentlyContinue
                if ($scoop) {
                    Write-Host "[install] scoop install $($installer.id)"
                    & $scoop.Source install $installer.id
                    return
                }
            }
            "winget" {
                $winget = Get-Command winget -ErrorAction SilentlyContinue
                if ($winget) {
                    Write-Host "[install] winget install --exact --id $($installer.id)"
                    & $winget.Source install --exact --id $installer.id --accept-package-agreements --accept-source-agreements
                    return
                }
            }
            "npm" {
                $npm = Get-Command npm -ErrorAction SilentlyContinue
                if ($npm) {
                    Write-Host "[install] npm install -g $($installer.id)"
                    & $npm.Source install -g $installer.id
                    return
                }
            }
            "manual" {
                if ($installer.hint) {
                    Write-Warning $installer.hint
                    return
                }
            }
        }
    }

    throw "No supported installer was available for $($Tool.displayName)."
}

function Sync-CasRepo {
    param(
        [pscustomobject]$Repo,
        [string]$RootPath,
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $git = Get-Command git -ErrorAction Stop
    $reposRoot = Join-Path $RootPath $Manifest.paths.reposRoot
    $repoPath = Join-Path $reposRoot $Repo.id

    if (-not (Test-Path -LiteralPath $repoPath)) {
        Write-Host "[clone] $($Repo.id)"
        & $git.Source clone $Repo.url $repoPath
        return
    }

    $null = Get-CasRepositorySafetyStatus -Path $repoPath -ExpectedOrigin $Repo.url -ExpectedBranch $Repo.defaultBranch
    Write-Host "[update] $($Repo.id)"
    & $git.Source -C $repoPath fetch origin
    if ($LASTEXITCODE -ne 0) {
        throw "Fetch failed for repository '$($Repo.id)'."
    }
    $null = Get-CasRepositorySafetyStatus -Path $repoPath -ExpectedOrigin $Repo.url -ExpectedBranch $Repo.defaultBranch
    & $git.Source -C $repoPath merge --ff-only "origin/$($Repo.defaultBranch)"
    if ($LASTEXITCODE -ne 0) {
        throw "Fast-forward failed for repository '$($Repo.id)'."
    }
}

function New-CasClientConfigs {
    param(
        [string]$ConfigPath,
        [string]$RootPath = (Get-CasDefaultRootPath),
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $clientRoot = Join-Path (Join-Path $ConfigPath $Manifest.paths.mcp) "clients"
    if (-not (Test-Path -LiteralPath $clientRoot)) {
        New-Item -ItemType Directory -Path $clientRoot -Force | Out-Null
    }

    $promptImproverEntry = Join-Path (Join-Path (Join-Path $RootPath $Manifest.paths.reposRoot) "Promptimprover") "dist\index.js"
    $sharedServer = [ordered]@{
        mcpServers = @{
            ($Manifest.sharedMcpServer.name) = @{
                command = $Manifest.sharedMcpServer.command
                args = @($promptImproverEntry)
                transport = $Manifest.sharedMcpServer.transport
            }
        }
    }

    foreach ($client in @($Manifest.clients)) {
        $target = Join-Path $clientRoot $client.fileName
        $sharedServer | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $target -Encoding UTF8
    }

    $runtimeConfig = [ordered]@{
        bundleId = $Manifest.bundleId
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        mcpServer = $Manifest.sharedMcpServer
    }
    $runtimeTarget = Join-Path (Join-Path $ConfigPath $Manifest.paths.config) "stack.runtime.json"
    $runtimeConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $runtimeTarget -Encoding UTF8
}

function Start-CasRuntime {
    param(
        [string]$Profile = "full",
        [string]$RootPath = (Get-CasDefaultRootPath),
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $docker = Test-CasDockerDaemon
    if ($docker.status -ne "ready") {
        $dockerDesktop = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
        if (Test-Path -LiteralPath $dockerDesktop) {
            Write-Host "[start] Docker Desktop"
            Start-Process -FilePath $dockerDesktop -WindowStyle Hidden
        }
        else {
            Write-Warning "Docker Desktop is not installed or its executable was not found."
        }
    }

    foreach ($repo in Get-CasProfileRepos -Profile $Profile -Manifest $Manifest) {
        $repoPath = Join-Path (Join-Path $RootPath $Manifest.paths.reposRoot) $repo.id
        if (-not (Test-Path -LiteralPath $repoPath)) {
            Write-Warning "Repo '$($repo.id)' is missing at $repoPath."
        }
    }
}

Export-ModuleMember -Function *-Cas*


