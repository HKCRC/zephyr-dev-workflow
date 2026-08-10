# Version: 3.7.0
param(
    [string]$config = "",
    [string]$board = "",
    [string]$runner = "",
    [ValidateSet("west", "bootloader", "app", "all")]
    [string]$target = "west",
    [string]$connection = "",
    [string]$programmer = "",
    [switch]$include_bootloader,
    [switch]$dry_run,
    [switch]$version
)

$ScriptVersion = "3.7.0"
if ($version) {
    Write-Host "flash.ps1 version $ScriptVersion"
    exit 0
}

. "$PSScriptRoot\project_common.ps1"

$projectConfig = Get-ProjectConfig $config
$board = Use-ConfigValue $board $projectConfig.Board
$runner = Use-ConfigValue $runner $projectConfig.FlashRunner
$connection = Use-ConfigValue $connection $projectConfig.FlashConnection
$programmer = Use-ConfigValue $programmer $projectConfig.FlashProgrammer

$board = Require-ConfigValue "Board" $board
$runner = Require-ConfigValue "FlashRunner" $runner
$connection = Require-ConfigValue "FlashConnection" $connection
$programmer = Require-ConfigValue "FlashProgrammer" $programmer

$env:ZEPHYR_BASE = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "ZephyrBase" $projectConfig.ZephyrBase) $projectConfig)
$env:ZEPHYR_TOOLCHAIN_VARIANT = "zephyr"
$env:ZEPHYR_SDK_INSTALL_DIR = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "ZephyrSdkInstallDir" $projectConfig.ZephyrSdkInstallDir) $projectConfig)

$buildDir = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "BuildDir" $projectConfig.BuildDir) $projectConfig)

if (-not (Test-Path $buildDir)) {
    Write-Error "Build directory not found: $buildDir. Run .\dev.ps1 build -board $board first."
    exit 1
}

function Require-File {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Error "Required image not found: $Path. Run .\dev.ps1 build -board $board first."
        exit 1
    }
}

function Invoke-Stm32Programmer {
    param(
        [string[]]$Arguments,
        [string]$Description
    )

    Write-Host $Description
    if ($dry_run) {
        Write-Host "$programmer $($Arguments -join ' ')"
        return
    }

    & $programmer @Arguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Flash-Bootloader {
    $bootloaderHex = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "BootloaderHexPath" $projectConfig.BootloaderHexPath) $projectConfig)
    Require-File $bootloaderHex

    Invoke-Stm32Programmer `
        -Description "Flashing MCUboot bootloader to boot_partition..." `
        -Arguments @("-c", $connection, "-w", $bootloaderHex, "-v")
}

function Flash-App {
    $appHex = Resolve-ProjectPath (Expand-ProjectConfigValue (Require-ConfigValue "AppConfirmedHexPath" $projectConfig.AppConfirmedHexPath) $projectConfig)
    Require-File $appHex

    Invoke-Stm32Programmer `
        -Description "Flashing confirmed application image to slot0_partition..." `
        -Arguments @("-c", $connection, "-w", $appHex, "-v")
}

if ($target -eq "west") {
    $westArgs = @("flash", "-d", $buildDir, "--runner", $runner)

    if ($dry_run) {
        Write-Host "python -m west $($westArgs -join ' ')"
        exit 0
    }

    & python -m west @westArgs
    exit $LASTEXITCODE
}

if ($include_bootloader -or $target -eq "bootloader" -or $target -eq "all") {
    Flash-Bootloader
}

switch ($target) {
    "bootloader" { break }
    "app" { Flash-App; break }
    "all" { Flash-App; break }
}

exit 0
