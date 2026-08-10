# zephyr-dev-workflow

Shared PowerShell scripts for Zephyr firmware development workflows.

## Entry Point

Use the dispatcher from a firmware project root:

```powershell
.\dev.ps1 build
.\dev.ps1 build -target none -pristine
.\dev.ps1 build -target all -pristine
.\dev.ps1 flash
.\dev.ps1 flash -target none
.\dev.ps1 flash -target all
.\dev.ps1 ota
.\dev.ps1 reset
.\dev.ps1 image_list
.\dev.ps1 image_confirm
```

## Scripts

- `script/workflow.ps1`: shared dispatcher used by a firmware project's root `dev.ps1` entry.
- `script/build.ps1`: build an MCUboot app by default, build without bootloader with `-target none`, or sysbuild bootloader + app with `-target all`.
- `script/flash.ps1`: flash by west runner or STM32CubeProgrammer.
- `script/ota.ps1`: upload an MCUboot/mcumgr OTA image.
- `script/reset.ps1`: reset a device by mcumgr.
- `script/image_list.ps1`: list MCUboot images by mcumgr.
- `script/image_comfirm.ps1`: confirm the active MCUboot image.

Project-specific values stay in each firmware repository's `project_config.json`.
The script resolves relative paths from that config file's directory, so this
repository can be used as a Git submodule.

## Documents

- `doc/command-table.md`: command and parameter reference for build, flash, OTA,
  and MCUboot image management workflows.
- `doc/migration-and-usage.md`: migration guide for adding this tool to a Zephyr
  project and daily usage guide for new developers.
