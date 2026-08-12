# Version: 4.0.0
param(
    [string]$config = "",
    [string]$board = "",
    [string]$extra_conf = "",
    [ValidateSet("no_bootloader", "app", "all")]
    [string]$target = "app",
    [switch]$pristine,
    [switch]$version
)

$ScriptVersion = "4.0.0"
if ($version) {
    Write-Host "build.ps1 version $ScriptVersion"
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
$appBuildDir = Join-Path $buildDir $projectName
$extraConfExplicit = $PSBoundParameters.ContainsKey("extra_conf")
$extra_conf = Use-ConfigValue $extra_conf $projectConfig.ExtraConf
$extra_conf = Expand-ProjectConfigValue $extra_conf $projectConfig

if ($target -eq "no_bootloader") {
    $westArgs = @(
        "build",
        "-b", $board,
        $projectRoot,
        "-d", $buildDir,
        "--",
        "-DBOARD_ROOT=$projectRoot"
    )

    if ($pristine) {
        $westArgs = @("build", "-p", "always") + $westArgs[1..($westArgs.Count - 1)]
    }

    if (-not [string]::IsNullOrWhiteSpace($extra_conf)) {
        $extraConfPath = if ([System.IO.Path]::IsPathRooted($extra_conf)) {
            $extra_conf
        } else {
            Join-Path $projectRoot $extra_conf
        }

        if (-not (Test-Path $extraConfPath)) {
            Write-Error "Extra config file not found: $extraConfPath"
            exit 1
        }

        $westArgs += "-DEXTRA_CONF_FILE=$extraConfPath"
    }

    & python -m west @westArgs
    exit $LASTEXITCODE
}

if ($target -eq "app") {
    if ($pristine) {
        Write-Error "App-only pristine build is not supported. Use .\dev.ps1 build -target all -pristine to reconfigure sysbuild."
        exit 1
    }

    if ($extraConfExplicit) {
        Write-Error "App-only build cannot apply -extra_conf after CMake configuration. Use .\dev.ps1 build -target all -extra_conf <path>."
        exit 1
    }

    if (-not (Test-Path $appBuildDir)) {
        Write-Error "App build directory not found: $appBuildDir. Run .\dev.ps1 build -target all -pristine first."
        exit 1
    }

    & cmake --build $appBuildDir
    exit $LASTEXITCODE
}

$westArgs = @(
    "build", "--sysbuild",
    "-b", $board,
    $projectRoot,
    "-d", $buildDir,
    "--",
    "-DBOARD_ROOT=$projectRoot"
)

if ($pristine) {
    $westArgs = @("build", "--sysbuild", "-p", "always") + $westArgs[2..($westArgs.Count - 1)]
}

if (-not [string]::IsNullOrWhiteSpace($extra_conf)) {
    $extraConfPath = if ([System.IO.Path]::IsPathRooted($extra_conf)) {
        $extra_conf
    } else {
        Join-Path $projectRoot $extra_conf
    }

    if (-not (Test-Path $extraConfPath)) {
        Write-Error "Extra config file not found: $extraConfPath"
        exit 1
    }

    $westArgs += "-DEXTRA_CONF_FILE=$extraConfPath"
}

& python -m west @westArgs
exit $LASTEXITCODE
