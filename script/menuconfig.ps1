# Version: 4.0.0
param(
    [string]$config = "",
    [string]$board = "",
    [ValidateSet("no_bootloader", "all")]
    [string]$target = "no_bootloader",
    [switch]$dry_run,
    [switch]$version
)

$ScriptVersion = "4.0.0"
if ($version) {
    Write-Host "menuconfig.ps1 version $ScriptVersion"
    exit 0
}

. "$PSScriptRoot\project_common.ps1"

$projectConfig = Get-ProjectConfig $config
$projectRoot = Get-ProjectRoot
$board = Use-ConfigValue $board $projectConfig.BoardName
$board = Require-ConfigValue "BoardName" $board

$env:ZEPHYR_BASE = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "ZephyrBase" $projectConfig.ZephyrBase) $projectConfig)
$env:ZEPHYR_TOOLCHAIN_VARIANT = "zephyr"
$env:ZEPHYR_SDK_INSTALL_DIR = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "ZephyrSdkInstallDir" $projectConfig.ZephyrSdkInstallDir) $projectConfig)

$buildDir = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "BuildDir" $projectConfig.BuildDir) $projectConfig)
$projectName = Require-ConfigValue "ProjectName" $projectConfig.ProjectName
$menuconfigBuildDir = $buildDir

if ($target -eq "all") {
    $menuconfigBuildDir = Join-Path $buildDir $projectName
}

if (-not (Test-Path $menuconfigBuildDir)) {
    Write-Error "Build directory not found: $menuconfigBuildDir. Run .\dev.ps1 build -target $target -pristine first."
    exit 1
}

$westArgs = @("build", "-d", $menuconfigBuildDir, "-t", "menuconfig")

if ($dry_run) {
    Write-Host ("python -m west " + ($westArgs -join " "))
    exit 0
}

& python -m west @westArgs
exit $LASTEXITCODE
