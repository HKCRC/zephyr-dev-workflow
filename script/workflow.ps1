# Version: 5.0.0
$ScriptVersion = "5.0.0"

function Show-Help {
    Write-Host "zephyr-dev-workflow $ScriptVersion"
    Write-Host ""
    Write-Host "Project root usage:"
    Write-Host "  .\dev.ps1 <command> [options]"
    Write-Host ""
    Write-Host "Shared workflow dispatcher usage:"
    Write-Host "  .\workflow.ps1 <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  build          Build MCUboot app by default; use -target no_bootloader for direct app without bootloader."
    Write-Host "  menuconfig     Open Zephyr menuconfig for the configured build directory."
    Write-Host "  flash          Flash MCUboot app by default; use -target no_bootloader for direct app without bootloader."
    Write-Host "  ota            Upload and test an MCUboot OTA image without resetting."
    Write-Host "  image upload   Upload an MCUboot image."
    Write-Host "  image test     Mark an image hash for test boot."
    Write-Host "  image reset    Reset the device by mcumgr."
    Write-Host "  image list     List MCUboot images by mcumgr."
    Write-Host "  image confirm  Confirm the active MCUboot image."
    Write-Host ""
    Write-Host "Common options:"
    Write-Host "  -config <path> Use a project_config.json file."
    Write-Host "  -version       Show the selected command version."
}

function Invoke-WorkflowCommand {
    param(
        [string]$ScriptName,
        [string[]]$Arguments,
        [string[]]$OptionNames = @(),
        [string[]]$SwitchNames = @()
    )

    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path $scriptPath)) {
        Write-Error "Workflow script not found: $scriptPath"
        exit 1
    }

    $splat = Convert-ArgumentsToSplat -Arguments $Arguments -OptionNames $OptionNames -SwitchNames $SwitchNames
    & $scriptPath @splat
    exit $LASTEXITCODE
}

function Convert-ArgumentsToSplat {
    param(
        [string[]]$Arguments,
        [string[]]$OptionNames = @(),
        [string[]]$SwitchNames = @()
    )

    $splat = @{}
    $optionSet = @{}
    $switchSet = @{}
    foreach ($name in $OptionNames) {
        $optionSet[$name] = $true
    }

    foreach ($name in $SwitchNames) {
        $switchSet[$name] = $true
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

        if ($switchSet.ContainsKey($name)) {
            $splat[$name] = $true
            continue
        }

        if (-not $optionSet.ContainsKey($name)) {
            Write-Error "Unknown workflow option: -$name. Use lower_snake_case options from .\workflow.ps1 --help."
            exit 1
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

function Invoke-ImageCommand {
    param([string[]]$Arguments)

    $prefixArgs = @()
    if ($Arguments.Count -ge 2 -and $Arguments[0] -eq "-config") {
        $prefixArgs = @($Arguments[0], $Arguments[1])
        if ($Arguments.Count -gt 2) {
            $Arguments = @($Arguments[2..($Arguments.Count - 1)])
        } else {
            $Arguments = @()
        }
    }

    if ($Arguments.Count -eq 0) {
        Write-Error "Missing image command. Use: image upload|test|reset|list|confirm"
        exit 1
    }

    $imageCommand = [string]$Arguments[0]
    $imageArgs = @($prefixArgs)
    if ($Arguments.Count -gt 1) {
        $imageArgs += @($Arguments[1..($Arguments.Count - 1)])
    }

    switch -CaseSensitive ($imageCommand) {
        "upload" {
            Invoke-WorkflowCommand -ScriptName "image_upload.ps1" -Arguments $imageArgs -OptionNames @("config", "board", "address", "port", "conn_type", "mcu_mgr", "image_path") -SwitchNames @("dry_run", "version")
        }
        "test" {
            if ($imageArgs.Count -gt $prefixArgs.Count -and -not ([string]$imageArgs[$prefixArgs.Count]).StartsWith("-")) {
                $hash = [string]$imageArgs[$prefixArgs.Count]
                $beforeHash = @()
                if ($prefixArgs.Count -gt 0) {
                    $beforeHash = @($imageArgs[0..($prefixArgs.Count - 1)])
                }
                $afterHash = @()
                if ($imageArgs.Count -gt ($prefixArgs.Count + 1)) {
                    $afterHash = @($imageArgs[($prefixArgs.Count + 1)..($imageArgs.Count - 1)])
                }
                $imageArgs = @($beforeHash) + @("-hash", $hash) + @($afterHash)
            }
            Invoke-WorkflowCommand -ScriptName "image_test.ps1" -Arguments $imageArgs -OptionNames @("config", "address", "port", "conn_type", "mcu_mgr", "hash") -SwitchNames @("dry_run", "version")
        }
        "reset" {
            Invoke-WorkflowCommand -ScriptName "reset.ps1" -Arguments $imageArgs -OptionNames @("config", "address", "port", "conn_type", "mcu_mgr") -SwitchNames @("dry_run", "version")
        }
        "list" {
            Invoke-WorkflowCommand -ScriptName "image_list.ps1" -Arguments $imageArgs -OptionNames @("config", "address", "port", "conn_type", "mcu_mgr") -SwitchNames @("dry_run", "version")
        }
        "confirm" {
            Invoke-WorkflowCommand -ScriptName "image_confirm.ps1" -Arguments $imageArgs -OptionNames @("config", "address", "port", "conn_type", "mcu_mgr") -SwitchNames @("dry_run", "version")
        }
        default {
            Write-Error "Unknown image command: $imageCommand. Use: image upload|test|reset|list|confirm"
            exit 1
        }
    }
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

if ($command -in @("--help", "-help", "-h", "-?")) {
    Show-Help
    exit 0
}

if ($command -eq "-version") {
    Write-Host "workflow.ps1 version $ScriptVersion"
    exit 0
}

switch -CaseSensitive ($command) {
    "build" {
        Invoke-WorkflowCommand -ScriptName "build.ps1" -Arguments $remainingArgs -OptionNames @("config", "board", "extra_conf", "target") -SwitchNames @("pristine", "version")
    }
    "menuconfig" {
        Invoke-WorkflowCommand -ScriptName "menuconfig.ps1" -Arguments $remainingArgs -OptionNames @("config", "board", "target") -SwitchNames @("dry_run", "version")
    }
    "flash" {
        Invoke-WorkflowCommand -ScriptName "flash.ps1" -Arguments $remainingArgs -OptionNames @("config", "board", "runner", "target", "connection", "programmer") -SwitchNames @("include_bootloader", "dry_run", "version")
    }
    "ota" {
        Invoke-WorkflowCommand -ScriptName "ota.ps1" -Arguments $remainingArgs -OptionNames @("config", "board", "address", "port", "conn_type", "mcu_mgr", "image_path") -SwitchNames @("dry_run", "version")
    }
    "image" {
        Invoke-ImageCommand -Arguments $remainingArgs
    }
    default {
        Write-Error "Unknown workflow command: $command"
        Show-Help
        exit 1
    }
}
