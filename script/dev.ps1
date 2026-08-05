# Version: 3.6.0
$ScriptVersion = "3.6.0"

function Show-Help {
    Write-Host "zephyr-dev-workflow $ScriptVersion"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\dev.ps1 <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  build          Build the Zephyr sysbuild project."
    Write-Host "  flash          Flash firmware by west runner or STM32CubeProgrammer."
    Write-Host "  ota            Upload and test an MCUboot OTA image."
    Write-Host "  image-list     List MCUboot images by mcumgr."
    Write-Host "  image-confirm  Confirm the active MCUboot image."
    Write-Host ""
    Write-Host "Common options:"
    Write-Host "  -Config <path> Use a project_config.json file."
    Write-Host "  -Version       Show the selected command version."
}

function Invoke-WorkflowCommand {
    param(
        [string]$ScriptName,
        [string[]]$Arguments,
        [string[]]$SwitchNames = @()
    )

    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path $scriptPath)) {
        Write-Error "Workflow script not found: $scriptPath"
        exit 1
    }

    $splat = Convert-ArgumentsToSplat -Arguments $Arguments -SwitchNames $SwitchNames
    & $scriptPath @splat
    exit $LASTEXITCODE
}

function Convert-ArgumentsToSplat {
    param(
        [string[]]$Arguments,
        [string[]]$SwitchNames = @()
    )

    $splat = @{}
    $switchSet = @{}
    foreach ($name in $SwitchNames) {
        $switchSet[$name.ToLowerInvariant()] = $true
    }

    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = [string]$Arguments[$i]
        if (-not $arg.StartsWith("-")) {
            Write-Error "Unexpected positional argument for workflow command: $arg"
            exit 1
        }

        $nameValue = $arg.TrimStart("-")
        $name = $nameValue
        $value = $null

        if ($nameValue.Contains(":")) {
            $split = $nameValue.Split(":", 2)
            $name = $split[0]
            $value = $split[1]
        }

        if ($switchSet.ContainsKey($name.ToLowerInvariant())) {
            $splat[$name] = $true
            continue
        }

        if ($null -eq $value) {
            if ($i + 1 -ge $Arguments.Count) {
                Write-Error "Missing value for workflow option: -$name"
                exit 1
            }

            $i++
            $value = [string]$Arguments[$i]
        }

        $splat[$name] = $value
    }

    return $splat
}

$rawArgs = @($args)

if ($rawArgs.Count -eq 0) {
    Show-Help
    exit 0
}

$command = [string]$rawArgs[0]
$remainingArgs = @()
if ($rawArgs.Count -gt 1) {
    $remainingArgs = @($rawArgs[1..($rawArgs.Count - 1)])
}

switch -Regex ($command) {
    '^-{1,2}(h|help|\?)$' {
        Show-Help
        exit 0
    }
    '^-{1,2}version$' {
        Write-Host "dev.ps1 version $ScriptVersion"
        exit 0
    }
}

switch ($command.ToLowerInvariant()) {
    "build" {
        Invoke-WorkflowCommand -ScriptName "build.ps1" -Arguments $remainingArgs -SwitchNames @("Pristine", "Version")
    }
    "flash" {
        Invoke-WorkflowCommand -ScriptName "flash.ps1" -Arguments $remainingArgs -SwitchNames @("IncludeBootloader", "DryRun", "Version")
    }
    "ota" {
        Invoke-WorkflowCommand -ScriptName "ota.ps1" -Arguments $remainingArgs -SwitchNames @("SkipUpload", "SkipReset", "DryRun", "RawUploadOutput", "Version")
    }
    { $_ -in @("image-list", "image_list", "imagelist", "list-image", "list-images") } {
        Invoke-WorkflowCommand -ScriptName "image_list.ps1" -Arguments $remainingArgs -SwitchNames @("Version")
    }
    { $_ -in @("image-confirm", "image_confirm", "image-comfirm", "image_comfirm", "confirm-image", "confirm") } {
        Invoke-WorkflowCommand -ScriptName "image_comfirm.ps1" -Arguments $remainingArgs -SwitchNames @("DryRun", "Version")
    }
    default {
        Write-Error "Unknown workflow command: $command"
        Show-Help
        exit 1
    }
}
