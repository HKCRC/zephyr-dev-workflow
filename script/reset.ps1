# Version: 3.8.0
param(
    [string]$config = "",
    [string]$address = "",
    [Nullable[int]]$port = $null,
    [string]$conn_type = "",
    [string]$mcu_mgr = "",
    [switch]$dry_run,
    [switch]$version
)

$ScriptVersion = "3.8.0"
if ($version) {
    Write-Host "reset.ps1 version $ScriptVersion"
    exit 0
}

. "$PSScriptRoot\project_common.ps1"

$projectConfig = Get-ProjectConfig $config
$address = Use-ConfigValue $address $projectConfig.Address
$port = Use-ConfigValue $port $projectConfig.Port
$conn_type = Use-ConfigValue $conn_type $projectConfig.ConnType
$mcu_mgr = Use-ConfigValue $mcu_mgr $projectConfig.McuMgr

$address = Require-ConfigValue "Address" $address
$port = Require-ConfigValue "Port" $port
$conn_type = Require-ConfigValue "ConnType" $conn_type
$mcu_mgr = Require-ConfigValue "McuMgr" $mcu_mgr

$connString = "$address`:$port"
$resetArgs = @("--conntype", $conn_type, "--connstring", $connString, "reset")

Write-Host "Resetting device by mcumgr: $connString"
if ($dry_run) {
    Write-Host "$mcu_mgr $($resetArgs -join ' ')"
    exit 0
}

& $mcu_mgr @resetArgs
exit $LASTEXITCODE
