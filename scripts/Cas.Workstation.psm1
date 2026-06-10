Set-StrictMode -Version Latest

function Get-CasFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "CAS managed paths cannot be empty." }
    [System.IO.Path]::GetFullPath($Path)
}

function Assert-CasSafeManagedPath {
    param([Parameter(Mandatory = $true)][string]$Path, [string]$ParentPath)
    $fullPath = Get-CasFullPath -Path $Path
    $root = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.TrimEnd('\', '/') -eq $root.TrimEnd('\', '/')) { throw "Refusing to use filesystem root '$fullPath' as a CAS managed path." }
    if ($ParentPath) {
        $fullParent = (Get-CasFullPath -Path $ParentPath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        if (-not $fullPath.StartsWith($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Path '$fullPath' escapes the CAS managed parent '$fullParent'." }
    }
    $fullPath
}

function Test-CasRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $false }
    -not (($Path -split '[\\/]') -contains '..')
}

function Test-CasManifest {
    param([Parameter(Mandatory = $true)][pscustomobject]$Manifest)
    foreach ($property in @("manifestVersion", "bundleId", "defaults", "profiles", "paths", "tools", "repos", "clients", "sharedMcpServer")) {
        if (-not $Manifest.PSObject.Properties[$property]) { throw "Manifest is missing required property '$property'." }
    }
    [void](Assert-CasSafeManagedPath -Path $Manifest.defaults.rootPath)
    [void](Assert-CasSafeManagedPath -Path $Manifest.defaults.configPath)
    foreach ($property in @("reposRoot", "logs", "state", "memory", "mcp", "config")) {
        $value = $Manifest.paths.$property
        if (-not $value -or -not (Test-CasRelativePath -Path $value)) { throw "Manifest path '$property' must be a safe relative path." }
    }
    foreach ($collectionName in @("tools", "repos", "clients")) {
        $ids = @($Manifest.$collectionName | ForEach-Object { $_.id })
        if ($ids.Count -ne @($ids | Select-Object -Unique).Count -or $ids -contains $null -or $ids -contains "") { throw "Manifest collection '$collectionName' must contain unique, non-empty ids." }
    }
    $toolIds = @($Manifest.tools.id)
    $repoIds = @($Manifest.repos.id)
    foreach ($profileProperty in $Manifest.profiles.PSObject.Properties) {
        foreach ($toolId in @($profileProperty.Value.tools)) { if ($toolIds -notcontains $toolId) { throw "Profile '$($profileProperty.Name)' references unknown tool '$toolId'." } }
        foreach ($repoId in @($profileProperty.Value.repos)) { if ($repoIds -notcontains $repoId) { throw "Profile '$($profileProperty.Name)' references unknown repo '$repoId'." } }
    }
    $true
}

function Write-CasJsonAtomic {
    param([Parameter(Mandatory = $true)][object]$InputObject, [Parameter(Mandatory = $true)][string]$Path)
    $fullPath = Get-CasFullPath -Path $Path
    $directory = Split-Path -Parent $fullPath
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $temporaryPath = Join-Path $directory (".{0}.{1}.tmp" -f ([System.IO.Path]::GetFileName($fullPath)), [guid]::NewGuid().ToString("N"))
    try {
        $InputObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
        Move-Item -LiteralPath $temporaryPath -Destination $fullPath -Force
    }
    finally { if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force } }
}

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

    $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    [void](Test-CasManifest -Manifest $manifest)
    $manifest
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
    param([string]$RootPath, [string]$ConfigPath, [pscustomobject]$Manifest = (Get-CasManifest))

    $safeRootPath = Assert-CasSafeManagedPath -Path $RootPath
    $safeConfigPath = Assert-CasSafeManagedPath -Path $ConfigPath
    if ($safeRootPath -eq $safeConfigPath) { throw "RootPath and ConfigPath must be different CAS managed directories." }
    $paths = @(
        $safeRootPath,
        (Assert-CasSafeManagedPath -Path (Join-Path $safeRootPath $Manifest.paths.reposRoot) -ParentPath $safeRootPath),
        $safeConfigPath,
        (Assert-CasSafeManagedPath -Path (Join-Path $safeConfigPath $Manifest.paths.logs) -ParentPath $safeConfigPath),
        (Assert-CasSafeManagedPath -Path (Join-Path $safeConfigPath $Manifest.paths.state) -ParentPath $safeConfigPath),
        (Assert-CasSafeManagedPath -Path (Join-Path $safeConfigPath $Manifest.paths.memory) -ParentPath $safeConfigPath),
        (Assert-CasSafeManagedPath -Path (Join-Path $safeConfigPath $Manifest.paths.mcp) -ParentPath $safeConfigPath),
        (Assert-CasSafeManagedPath -Path (Join-Path $safeConfigPath $Manifest.paths.config) -ParentPath $safeConfigPath),
        (Assert-CasSafeManagedPath -Path (Join-Path (Join-Path $safeConfigPath $Manifest.paths.mcp) "clients") -ParentPath $safeConfigPath)
    )
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    }
    foreach ($managedPath in @($safeRootPath, $safeConfigPath)) {
        $markerPath = Join-Path $managedPath ".cas-managed.json"
        if (-not (Test-Path -LiteralPath $markerPath)) {
            Write-CasJsonAtomic -Path $markerPath -InputObject ([ordered]@{ bundleId = $Manifest.bundleId; managedPath = $managedPath; createdAtUtc = [DateTime]::UtcNow.ToString("o") })
        }
    }
}

function Get-CasProfileToolDefinitions {
    param(
        [string]$Profile = "full",
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $toolIds = @((Get-CasProfile -Name $Profile -Manifest $Manifest).tools)
    foreach ($toolId in $toolIds) {
        $Manifest.tools | Where-Object { $_.id -eq $toolId }
    }
}

function Get-CasProfileRepos {
    param(
        [string]$Profile = "full",
        [pscustomobject]$Manifest = (Get-CasManifest)
    )

    $repoIds = @((Get-CasProfile -Name $Profile -Manifest $Manifest).repos)
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
    $profileServices = @((Get-CasProfile -Name $Profile).services)
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

function Test-CasDoctorReport {
    param([Parameter(Mandatory = $true)][pscustomobject]$Report)
    foreach ($property in @("bundleId", "generatedAtUtc", "profile", "rootPath", "configPath", "overallStatus", "tools", "services", "repos", "recommendations")) {
        if (-not $Report.PSObject.Properties[$property]) { throw "Doctor report is missing required property '$property'." }
    }
    if (@("ready", "degraded", "not-ready") -notcontains $Report.overallStatus) { throw "Doctor report has invalid overallStatus '$($Report.overallStatus)'." }
    $generatedAt = [DateTime]::MinValue
    if (-not [DateTime]::TryParse($Report.generatedAtUtc, [ref]$generatedAt)) { throw "Doctor report generatedAtUtc is not a valid date-time." }
    foreach ($tool in @($Report.tools)) { if (@("installed", "missing", "out-of-date") -notcontains $tool.status) { throw "Doctor report has invalid tool status '$($tool.status)'." } }
    foreach ($service in @($Report.services)) { if (@("ready", "missing", "degraded") -notcontains $service.status) { throw "Doctor report has invalid service status '$($service.status)'." } }
    foreach ($repo in @($Report.repos)) { if (@("present", "missing") -notcontains $repo.status) { throw "Doctor report has invalid repo status '$($repo.status)'." } }
    $true
}

function Write-CasDoctorReport {
    param([pscustomobject]$Report, [string]$JsonPath)
    [void](Test-CasDoctorReport -Report $Report)
    if ($JsonPath) { Write-CasJsonAtomic -InputObject $Report -Path $JsonPath }
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
    param([pscustomobject]$Repo, [string]$RootPath, [pscustomobject]$Manifest = (Get-CasManifest))

    if (-not (Test-CasRelativePath -Path $Repo.id)) { throw "Repo id '$($Repo.id)' is not a safe relative path." }
    $git = Get-Command git -ErrorAction Stop
    $safeRootPath = Assert-CasSafeManagedPath -Path $RootPath
    $reposRoot = Assert-CasSafeManagedPath -Path (Join-Path $safeRootPath $Manifest.paths.reposRoot) -ParentPath $safeRootPath
    $repoPath = Assert-CasSafeManagedPath -Path (Join-Path $reposRoot $Repo.id) -ParentPath $reposRoot

    if (-not (Test-Path -LiteralPath $repoPath)) {
        Write-Host "[clone] $($Repo.id)"
        & $git.Source clone $Repo.url $repoPath
        if ($LASTEXITCODE -ne 0) { throw "Clone failed for '$($Repo.id)'." }
        return
    }
    if (-not (Test-Path -LiteralPath (Join-Path $repoPath ".git"))) { throw "Refusing to update '$repoPath' because it is not a Git repository." }
    $originUrl = (& $git.Source -C $repoPath remote get-url origin 2>$null)
    if ($LASTEXITCODE -ne 0 -or $originUrl.TrimEnd("/") -ne $Repo.url.TrimEnd("/")) { throw "Refusing to update '$repoPath' because its origin does not match '$($Repo.url)'." }
    $dirty = (& $git.Source -C $repoPath status --porcelain)
    if ($dirty) { throw "Refusing to update '$repoPath' because it has uncommitted changes." }

    Write-Host "[update] $($Repo.id)"
    & $git.Source -C $repoPath fetch origin
    if ($LASTEXITCODE -ne 0) { throw "Fetch failed for '$($Repo.id)'." }
    & $git.Source -C $repoPath checkout $Repo.defaultBranch
    if ($LASTEXITCODE -ne 0) { throw "Checkout failed for '$($Repo.id)'." }
    & $git.Source -C $repoPath pull --ff-only origin $Repo.defaultBranch
    if ($LASTEXITCODE -ne 0) { throw "Fast-forward update failed for '$($Repo.id)'." }
}

function New-CasClientConfigs {
    param([string]$ConfigPath, [string]$RootPath = (Get-CasDefaultRootPath), [pscustomobject]$Manifest = (Get-CasManifest))
    $safeConfigPath = Assert-CasSafeManagedPath -Path $ConfigPath
    $safeRootPath = Assert-CasSafeManagedPath -Path $RootPath
    $clientRoot = Assert-CasSafeManagedPath -Path (Join-Path (Join-Path $safeConfigPath $Manifest.paths.mcp) "clients") -ParentPath $safeConfigPath
    if (-not (Test-Path -LiteralPath $clientRoot)) { New-Item -ItemType Directory -Path $clientRoot -Force | Out-Null }
    $promptImproverEntry = Assert-CasSafeManagedPath -Path (Join-Path (Join-Path (Join-Path $safeRootPath $Manifest.paths.reposRoot) "Promptimprover") "dist\index.js") -ParentPath $safeRootPath
    $serverDefinition = [pscustomobject]@{ command = $Manifest.sharedMcpServer.command; args = @($promptImproverEntry); transport = $Manifest.sharedMcpServer.transport }
    foreach ($client in @($Manifest.clients)) {
        if (-not (Test-CasRelativePath -Path $client.fileName)) { throw "Client file name '$($client.fileName)' is not a safe relative path." }
        $target = Assert-CasSafeManagedPath -Path (Join-Path $clientRoot $client.fileName) -ParentPath $clientRoot
        $config = if (Test-Path -LiteralPath $target) {
            try { Get-Content -LiteralPath $target -Raw | ConvertFrom-Json } catch { throw "Refusing to overwrite invalid existing client configuration '$target'." }
        } else { [pscustomobject]@{} }
        if (-not $config.PSObject.Properties["mcpServers"]) { $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([pscustomobject]@{}) }
        if ($null -eq $config.mcpServers.PSObject) { throw "Existing mcpServers value in '$target' is not an object." }
        $config.mcpServers | Add-Member -NotePropertyName $Manifest.sharedMcpServer.name -NotePropertyValue $serverDefinition -Force
        Write-CasJsonAtomic -InputObject $config -Path $target
    }
    $runtimeConfig = [ordered]@{ bundleId = $Manifest.bundleId; generatedAtUtc = [DateTime]::UtcNow.ToString("o"); mcpServer = $Manifest.sharedMcpServer }
    $runtimeTarget = Assert-CasSafeManagedPath -Path (Join-Path (Join-Path $safeConfigPath $Manifest.paths.config) "stack.runtime.json") -ParentPath $safeConfigPath
    Write-CasJsonAtomic -InputObject $runtimeConfig -Path $runtimeTarget
}

function Test-CasManagedDirectory {
    param([Parameter(Mandatory = $true)][string]$Path, [pscustomobject]$Manifest = (Get-CasManifest))
    $safePath = Assert-CasSafeManagedPath -Path $Path
    $markerPath = Join-Path $safePath ".cas-managed.json"
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { return $false }
    try { $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json } catch { return $false }
    $marker.bundleId -eq $Manifest.bundleId -and (Get-CasFullPath -Path $marker.managedPath) -eq $safePath
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
