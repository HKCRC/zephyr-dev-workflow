# Version: 4.1.0
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

$ScriptVersion = "4.1.0"
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

function Get-UnderResetConnection {
    param([string]$Value)

    if ($Value -notmatch '(^|\s)mode=') {
        return "$Value mode=UR"
    }

    return $Value
}

$connection = Get-UnderResetConnection $connection

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

function Get-HexPath {
    param([string]$PropertyName)

    $path = Resolve-ProjectPath (
        Expand-ProjectConfigValue `
            (Require-ConfigValue $PropertyName $projectConfig.$PropertyName) `
            $projectConfig)
    Require-File $path
    return $path
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

function Invoke-CombinedFlash {
    param(
        [string[]]$Images,
        [bool]$ProgramOptionBytes
    )

    $arguments = @("-c", $connection, "-halt")
    foreach ($image in $Images) {
        $arguments += @("-w", $image, "-v", "fast")
    }
    if ($ProgramOptionBytes) {
        $arguments += @("-ob") + $optionByteAssignments +
            @("-noreconnect", "-ob", "displ")
    }
    $arguments += @("-rst")

    $description = "Flashing $($Images.Count) image(s)"
    if ($ProgramOptionBytes) {
        $description += " and programming Option Bytes"
    }
    $description += " in one CubeProgrammer session..."
    Write-Host $description
    if ($dry_run) {
        Write-Host "$programmer $($arguments -join ' ')"
        return
    }

    $result = & $programmer @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $result | ForEach-Object { Write-Host ([string]$_) }
    if ($exitCode -ne 0) {
        exit $exitCode
    }

    if ($ProgramOptionBytes) {
        $verifiedValues = Get-OptionByteValues (
            @($result | ForEach-Object { [string]$_ }))
        if (-not (Test-OptionBytesMatch $verifiedValues)) {
            Write-Error "Option Byte verification failed in the flash session. Expected: $($optionByteAssignments -join ', ')"
            exit 1
        }
        Write-Host "Option Bytes verified in the flash session."
    }
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

$images = @()
$flashBootloader = (
    $include_bootloader -or
    $target -eq "bootloader" -or
    $target -eq "all"
)
$flashApplication = (
    $target -eq "app" -or
    $target -eq "all" -or
    $target -eq "no_bootloader"
)

if ($flashBootloader) {
    $images += Get-HexPath "BootloaderHexPath"
}
if ($flashApplication) {
    if ($target -eq "no_bootloader") {
        $appHex = Join-Path $buildDir "zephyr\zephyr.hex"
        Require-File $appHex
        $images += $appHex
    } else {
        $images += Get-HexPath "AppConfirmedHexPath"
    }
}

if ($images.Count -eq 0) {
    Write-Error "No firmware image selected for target '$target'."
    exit 1
}

$script:optionByteAssignments = @(Get-OptionByteAssignments)
$programOptionBytes = (
    -not $skip_option_bytes -and
    $optionByteAssignments.Count -gt 0
)
Invoke-CombinedFlash -Images $images -ProgramOptionBytes $programOptionBytes

exit 0
