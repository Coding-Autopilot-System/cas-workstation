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
    }

    if ($allowedCommands -notcontains $Manifest.sharedMcpServer.command) {
        throw "Shared MCP server uses unallowlisted command '$($Manifest.sharedMcpServer.command)'."
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
        $state = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        throw "Managed state '$Path' is not valid JSON: $($_.Exception.Message)"
    }
    Assert-CasManagedState -State $state
    $state
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

    Write-Host "[update] $($Repo.id)"
    & $git.Source -C $repoPath fetch origin
    & $git.Source -C $repoPath checkout $Repo.defaultBranch
    & $git.Source -C $repoPath pull --ff-only origin $Repo.defaultBranch
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


