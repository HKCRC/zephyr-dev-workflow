# Version: 3.7.0
param(
    [string]$config = "",
    [string]$board = "",
    [string]$address = "",
    [Nullable[int]]$port = $null,
    [string]$conn_type = "",
    [string]$mcu_mgr = "",
    [string]$image_path = "",
    [switch]$skip_upload,
    [switch]$skip_reset,
    [switch]$dry_run,
    [switch]$raw_upload_output,
    [switch]$version
)

$ScriptVersion = "3.7.0"
if ($version) {
    Write-Host "ota.ps1 version $ScriptVersion"
    exit 0
}

. "$PSScriptRoot\project_common.ps1"

$projectConfig = Get-ProjectConfig $config
$projectRoot = Get-ProjectRoot
$board = Use-ConfigValue $board $projectConfig.Board
$address = Use-ConfigValue $address $projectConfig.Address
$port = Use-ConfigValue $port $projectConfig.Port
$conn_type = Use-ConfigValue $conn_type $projectConfig.ConnType
$mcu_mgr = Use-ConfigValue $mcu_mgr $projectConfig.McuMgr
$image_path = Use-ConfigValue $image_path $projectConfig.ImagePath

$board = Require-ConfigValue "Board" $board
$address = Require-ConfigValue "Address" $address
$port = Require-ConfigValue "Port" $port
$conn_type = Require-ConfigValue "ConnType" $conn_type
$mcu_mgr = Require-ConfigValue "McuMgr" $mcu_mgr

$buildDir = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "BuildDir" $projectConfig.BuildDir) $projectConfig)
$otaDir = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "OtaOutputDir" $projectConfig.OtaOutputDir) $projectConfig)
$defaultSignedBin = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "AppSignedBinPath" $projectConfig.AppSignedBinPath) $projectConfig)
$defaultSignedHex = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "AppSignedHexPath" $projectConfig.AppSignedHexPath) $projectConfig)
$updateBin = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "OtaUpdateBinPath" $projectConfig.OtaUpdateBinPath) $projectConfig)
$updateHex = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "OtaUpdateHexPath" $projectConfig.OtaUpdateHexPath) $projectConfig)
$connString = "$address`:$port"

function Require-File {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Error "Required file not found: $Path. Run .\dev.ps1 build -board $board first."
        exit 1
    }
}

function Invoke-McuMgr {
    param([string[]]$Arguments)

    if ($dry_run) {
        Write-Host "$mcu_mgr $($Arguments -join ' ')"
        return @()
    }

    $output = & $mcu_mgr @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) {
        exit $exitCode
    }

    return $output
}

function Invoke-McuMgrUpload {
    param([string[]]$Arguments)

    if ($dry_run) {
        Write-Host "$mcu_mgr $($Arguments -join ' ')"
        return
    }

    if ($raw_upload_output) {
        & $mcu_mgr @Arguments
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        return
    }

    $output = & $mcu_mgr @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $output | ForEach-Object { Write-Host $_ }
        exit $exitCode
    }

    Write-Host "Upload complete."
}

function Get-Slot1Hash {
    param([string[]]$ImageListOutput)

    $inSlot1 = $false
    foreach ($line in $ImageListOutput) {
        if ($line -match "slot=1") {
            $inSlot1 = $true
            if ($line -match "hash[:=]\s*([0-9a-fA-F]+)") {
                return $Matches[1]
            }
            continue
        }

        if ($line -match "slot=0") {
            $inSlot1 = $false
        }

        if ($inSlot1 -and $line -match "hash[:=]\s*([0-9a-fA-F]+)") {
            return $Matches[1]
        }
    }

    return $null
}

if ([string]::IsNullOrWhiteSpace($image_path)) {
    Require-File $defaultSignedBin
    New-Item -ItemType Directory -Force -Path $otaDir | Out-Null
    Write-Host "Using sysbuild-generated signed image:"
    Write-Host "  $defaultSignedBin"
    Copy-Item $defaultSignedBin $updateBin -Force

    if (Test-Path $defaultSignedHex) {
        Copy-Item $defaultSignedHex $updateHex -Force
    }

    $image_path = $updateBin
    Write-Host "Prepared signed OTA image:"
    Write-Host "  $image_path"
} else {
    if (-not [System.IO.Path]::IsPathRooted($image_path)) {
        $image_path = Join-Path $projectRoot $image_path
    }
    Require-File $image_path
}

if (-not $skip_upload) {
    Write-Host "Uploading signed image to slot1..."
    Invoke-McuMgrUpload @("--conntype", $conn_type, "--connstring", $connString, "image", "upload", $image_path)
}

Write-Host "Reading image list..."
$imageList = Invoke-McuMgr @("--conntype", $conn_type, "--connstring", $connString, "image", "list")
if ($dry_run) {
    Write-Host "Dry run stops before parsing slot1 image hash."
    exit 0
}

$slot1Hash = Get-Slot1Hash $imageList
if ([string]::IsNullOrWhiteSpace($slot1Hash)) {
    Write-Error "Could not find slot1 image hash from mcumgr image list output."
    exit 1
}

if ($skip_upload) {
    Write-Host "Current slot1 firmware hash: $slot1Hash"
} else {
    Write-Host "OTA update firmware hash: $slot1Hash"
}

Write-Host "Marking slot1 image as test upgrade: $slot1Hash"
Invoke-McuMgr @("--conntype", $conn_type, "--connstring", $connString, "image", "test", $slot1Hash) | Out-Null

if ($skip_reset) {
    Write-Host "OTA image marked as test upgrade. Reset skipped."
    exit 0
}

Write-Host "Resetting device to switch to the new firmware..."
Invoke-McuMgr @("--conntype", $conn_type, "--connstring", $connString, "reset") | Out-Null

Write-Host "OTA requested. After the new firmware boots and passes validation, run:"
Write-Host "  .\dev.ps1 image_confirm -address $address -port $port"
exit 0
