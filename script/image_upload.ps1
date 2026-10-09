# Version: 5.0.0
param(
    [string]$config = "",
    [string]$board = "",
    [string]$address = "",
    [Nullable[int]]$port = $null,
    [string]$conn_type = "",
    [string]$mcu_mgr = "",
    [string]$image_path = "",
    [switch]$dry_run,
    [switch]$version
)

$ScriptVersion = "5.0.0"
if ($version) {
    Write-Host "image_upload.ps1 version $ScriptVersion"
    exit 0
}

. "$PSScriptRoot\project_common.ps1"

$projectConfig = Get-ProjectConfig $config
$projectRoot = Get-ProjectRoot
$board = Use-ConfigValue $board $projectConfig.BoardName
$address = Expand-ProjectConfigValue (Use-ConfigValue $address $projectConfig.OtaTarget) $projectConfig
$port = Use-ConfigValue $port $projectConfig.Port
$conn_type = Use-ConfigValue $conn_type $projectConfig.ConnType
$mcu_mgr = Use-ConfigValue $mcu_mgr $projectConfig.McuMgr
$image_path = Use-ConfigValue $image_path $projectConfig.ImagePath

$board = Require-ConfigValue "BoardName" $board
$address = Require-ConfigValue "OtaTarget" $address
$port = Require-ConfigValue "Port" $port
$conn_type = Require-ConfigValue "ConnType" $conn_type
$mcu_mgr = Require-ConfigValue "McuMgr" $mcu_mgr

$otaDir = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "OtaOutputDir" $projectConfig.OtaOutputDir) $projectConfig)
$defaultSignedBin = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "AppSignedBinPath" $projectConfig.AppSignedBinPath) $projectConfig)
$defaultSignedHex = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "AppSignedHexPath" $projectConfig.AppSignedHexPath) $projectConfig)
$updateBin = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "OtaUpdateBinPath" $projectConfig.OtaUpdateBinPath) $projectConfig)
$updateHex = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "OtaUpdateHexPath" $projectConfig.OtaUpdateHexPath) $projectConfig)

if ([string]::IsNullOrWhiteSpace($image_path)) {
    if (-not (Test-Path $defaultSignedBin)) {
        Write-Error "Required file not found: $defaultSignedBin. Run .\dev.ps1 build -target all first."
        exit 1
    }
    New-Item -ItemType Directory -Force -Path $otaDir | Out-Null
    Copy-Item $defaultSignedBin $updateBin -Force
    if (Test-Path $defaultSignedHex) {
        Copy-Item $defaultSignedHex $updateHex -Force
    }
    $image_path = $updateBin
} elseif (-not [System.IO.Path]::IsPathRooted($image_path)) {
    $image_path = Join-Path $projectRoot $image_path
}

if (-not (Test-Path $image_path)) {
    Write-Error "Required file not found: $image_path"
    exit 1
}

$uploadArgs = @("--conntype", $conn_type, "--connstring", "$address`:$port", "image", "upload", $image_path)
Write-Host "Uploading signed image to slot1: $image_path"
if ($dry_run) {
    Write-Host "$mcu_mgr $($uploadArgs -join ' ')"
    exit 0
}

& $mcu_mgr @uploadArgs
if ($LASTEXITCODE -eq 0) {
    Write-Host "Upload complete."
}
exit $LASTEXITCODE
