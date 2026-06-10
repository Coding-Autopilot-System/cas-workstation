[CmdletBinding()]
param(
    [string]$SchemaPath,
    [string]$InstancePath,
    [switch]$ExpectInvalid,
    [switch]$AllFixtures
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $PSScriptRoot "validate_json_schema.py"
$python = Get-Command python -ErrorAction SilentlyContinue

if (-not $python) {
    throw "Python is required for JSON Schema validation."
}
if (-not (Test-Path -LiteralPath $validator)) {
    throw "JSON Schema validator is missing: $validator"
}

function Invoke-CasSchemaValidation {
    param(
        [Parameter(Mandatory = $true)][string]$Schema,
        [Parameter(Mandatory = $true)][string]$Instance,
        [switch]$Invalid
    )

    $arguments = @($validator, "--schema", $Schema, "--instance", $Instance)
    if ($Invalid) {
        $arguments += "--expect-invalid"
    }

    & $python.Source @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "JSON Schema validation failed for '$Instance' against '$Schema'."
    }
}

if ($AllFixtures) {
    $fixtureRoot = Join-Path $repoRoot "tests\fixtures\contracts"
    $schemaRoot = Join-Path $repoRoot "schemas"
    $contracts = @("manifest", "managed-state", "operation-plan", "doctor", "event", "support-bundle")
    foreach ($contract in $contracts) {
        Invoke-CasSchemaValidation `
            -Schema (Join-Path $schemaRoot "$contract.schema.json") `
            -Instance (Join-Path $fixtureRoot "$contract.valid.json")
        Invoke-CasSchemaValidation `
            -Schema (Join-Path $schemaRoot "$contract.schema.json") `
            -Instance (Join-Path $fixtureRoot "$contract.invalid.json") `
            -Invalid
    }
    return
}

if (-not $SchemaPath -or -not $InstancePath) {
    throw "Provide -SchemaPath and -InstancePath, or use -AllFixtures."
}

Invoke-CasSchemaValidation -Schema $SchemaPath -Instance $InstancePath -Invalid:$ExpectInvalid

