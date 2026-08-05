# zephyr-dev-workflow

Shared PowerShell scripts for Zephyr firmware development workflows.

## Scripts

- `script/build.ps1`: build a Zephyr sysbuild project.
- `script/flash.ps1`: flash by west runner or STM32CubeProgrammer.
- `script/ota.ps1`: upload an MCUboot/mcumgr OTA image.
- `script/image_list.ps1`: list MCUboot images by mcumgr.
- `script/image_comfirm.ps1`: confirm the active MCUboot image.

Project-specific values stay in each firmware repository's
`project_config.json`. The script resolves relative paths from that config
file's directory, so this repository can be used as a Git submodule.
