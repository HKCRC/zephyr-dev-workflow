# Version: 4.0.0
param(
    [string]$config = "",
    [string]$board = "",
    [string]$runner = "",
    [ValidateSet("no_bootloader", "app", "all", "bootloader", "west")]
    [string]$target = "app",
    [string]$connection = "",
    [string]$programmer = "",
    [switch]$include_bootloader,
    [switch]$skip_option_bytes,
    [switch]$dry_run,
    [switch]$version
)

$ScriptVersion = "4.0.0"
if ($version) {
    Write-Host "flash.ps1 version $ScriptVersion"
    exit 0
}

. "$PSScriptRoot\project_common.ps1"

$projectConfig = Get-ProjectConfig $config
$board = Use-ConfigValue $board $projectConfig.BoardName
$runner = Use-ConfigValue $runner $projectConfig.FlashRunner
$connection = Use-ConfigValue $connection $projectConfig.FlashConnection
$programmer = Use-ConfigValue $programmer $projectConfig.FlashProgrammer

$board = Require-ConfigValue "BoardName" $board
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

function Reset-Stm32Target {
    $resetArgs = @("-c", $connection, "-rst")

    Write-Host "Resetting target after flash..."
    if ($dry_run) {
        Write-Host "$programmer $($resetArgs -join ' ')"
        return
    }

    & $programmer @resetArgs
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Get-OptionByteAssignments {
    $assignments = @()

    if ($null -eq $projectConfig.OptionBytes) {
        return $assignments
    }

    foreach ($property in $projectConfig.OptionBytes.PSObject.Properties) {
        if ($property.Name -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {
            Write-Error "Invalid Option Byte name: $($property.Name)"
            exit 1
        }

        $value = [string]$property.Value
        if ($value -notmatch '^0[xX][0-9A-Fa-f]+$') {
            Write-Error "Invalid value for Option Byte $($property.Name): $value"
            exit 1
        }

        $assignments += "$($property.Name)=$value"
    }

    return $assignments
}

function ConvertFrom-OptionByteHex {
    param([string]$Value)

    return [Convert]::ToUInt32(($Value -replace '^0[xX]', ''), 16)
}

function Get-OptionByteValues {
    param([string[]]$Output)

    $values = @{}
    foreach ($line in $Output) {
        foreach ($assignment in $optionByteAssignments) {
            $name = $assignment.Split('=', 2)[0]
            $match = [regex]::Match(
                $line,
                "^\s*$([regex]::Escape($name))\s*:\s*(0x[0-9A-Fa-f]+)")
            if ($match.Success) {
                $values[$name] = ConvertFrom-OptionByteHex $match.Groups[1].Value
            }
        }
    }

    foreach ($assignment in $optionByteAssignments) {
        $name = $assignment.Split('=', 2)[0]
        if (-not $values.ContainsKey($name)) {
            return $null
        }
    }

    return $values
}

function Test-OptionBytesMatch {
    param([hashtable]$CurrentValues)

    if ($null -eq $CurrentValues) {
        return $false
    }

    foreach ($assignment in $optionByteAssignments) {
        $parts = $assignment.Split('=', 2)
        $expected = ConvertFrom-OptionByteHex $parts[1]
        if ($CurrentValues[$parts[0]] -ne $expected) {
            return $false
        }
    }

    return $true
}

function Get-CurrentOptionBytes {
    $result = & $programmer @("-c", $connection, "-ob", "displ") 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to read Option Bytes from target."
        exit $LASTEXITCODE
    }

    return @($result | ForEach-Object { [string]$_ })
}

function Configure-OptionBytes {
    $script:optionByteAssignments = @(Get-OptionByteAssignments)
    if ($skip_option_bytes -or $optionByteAssignments.Count -eq 0) {
        return
    }

    $programArgs = @("-c", $connection, "-ob") + $optionByteAssignments
    $displayArgs = @("-c", $connection, "-ob", "displ")

    if ($dry_run) {
        Write-Host "Checking and configuring Option Bytes..."
        Write-Host "$programmer $($displayArgs -join ' ')"
        Write-Host "$programmer $($programArgs -join ' ')"
        Write-Host "$programmer $($displayArgs -join ' ')"
        return
    }

    Write-Host "Checking Option Bytes..."
    $currentValues = Get-OptionByteValues (Get-CurrentOptionBytes)
    if (Test-OptionBytesMatch $currentValues) {
        Write-Host "Option Bytes already match the project configuration."
        return
    }

    Invoke-Stm32Programmer `
        -Description "Configuring project Option Bytes..." `
        -Arguments $programArgs

    Write-Host "Verifying Option Bytes..."
    $verifiedValues = Get-OptionByteValues (Get-CurrentOptionBytes)
    if (-not (Test-OptionBytesMatch $verifiedValues)) {
        Write-Error "Option Byte verification failed. Expected: $($optionByteAssignments -join ', ')"
        exit 1
    }

    Write-Host "Option Bytes verified."
}

function Flash-NoBootloaderApp {
    $appHex = Join-Path $buildDir "zephyr\zephyr.hex"
    Require-File $appHex

    Invoke-Stm32Programmer `
        -Description "Flashing application image without bootloader..." `
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
    "no_bootloader" { Flash-NoBootloaderApp; break }
    "bootloader" { break }
    "app" { Flash-App; break }
    "all" { Flash-App; break }
}

if ($target -ne "west") {
    Configure-OptionBytes
    Reset-Stm32Target
}

exit 0
