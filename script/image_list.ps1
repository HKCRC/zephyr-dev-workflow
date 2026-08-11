# Version: 4.0.0
param(
    [string]$config = "",
    [string]$address = "",
    [Nullable[int]]$port = $null,
    [string]$conn_type = "",
    [string]$mcu_mgr = "",
    [switch]$version
)

$ScriptVersion = "4.0.0"
if ($version) {
    Write-Host "image_list.ps1 version $ScriptVersion"
    exit 0
}

. "$PSScriptRoot\project_common.ps1"

$projectConfig = Get-ProjectConfig $config
$address = Use-ConfigValue $address $projectConfig.OtaTarget
$address = Expand-ProjectConfigValue $address $projectConfig
$port = Use-ConfigValue $port $projectConfig.Port
$conn_type = Use-ConfigValue $conn_type $projectConfig.ConnType
$mcu_mgr = Use-ConfigValue $mcu_mgr $projectConfig.McuMgr
$connString = "$address`:$port"

Write-Host "Querying MCUboot image list from $connString..."
& $mcu_mgr --conntype $conn_type --connstring $connString image list
exit $LASTEXITCODE
