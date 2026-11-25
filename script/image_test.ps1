# Version: 5.0.0
param(
    [string]$config = "",
    [string]$address = "",
    [Nullable[int]]$port = $null,
    [string]$conn_type = "",
    [string]$mcu_mgr = "",
    [string]$hash = "",
    [switch]$dry_run,
    [switch]$version
)

$ScriptVersion = "5.0.0"
if ($version) {
    Write-Host "image_test.ps1 version $ScriptVersion"
    exit 0
}

. "$PSScriptRoot\project_common.ps1"

$projectConfig = Get-ProjectConfig $config
$address = Expand-ProjectConfigValue (Use-ConfigValue $address $projectConfig.OtaTarget) $projectConfig
$port = Use-ConfigValue $port $projectConfig.Port
$conn_type = Use-ConfigValue $conn_type $projectConfig.ConnType
$mcu_mgr = Use-ConfigValue $mcu_mgr $projectConfig.McuMgr

$address = Require-ConfigValue "OtaTarget" $address
$port = Require-ConfigValue "Port" $port
$conn_type = Require-ConfigValue "ConnType" $conn_type
$mcu_mgr = Require-ConfigValue "McuMgr" $mcu_mgr
$hash = Require-ConfigValue "hash" $hash

if ($hash -notmatch "^[0-9a-fA-F]+$") {
    Write-Error "Invalid image hash: $hash"
    exit 1
}

$testArgs = @("--conntype", $conn_type, "--connstring", "$address`:$port", "image", "test", $hash)
Write-Host "Marking image as test upgrade: $hash"
if ($dry_run) {
    Write-Host "$mcu_mgr $($testArgs -join ' ')"
    exit 0
}

& $mcu_mgr @testArgs
exit $LASTEXITCODE
