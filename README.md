# craner-zephyr-tools

Shared PowerShell tools for Craner Zephyr firmware projects.

## Scripts

- `scripts/build.ps1`: build a Zephyr sysbuild project.
- `scripts/flash.ps1`: flash by west runner or STM32CubeProgrammer.
- `scripts/ota.ps1`: upload an MCUboot/mcumgr OTA image.
- `scripts/image_list.ps1`: list MCUboot images by mcumgr.
- `scripts/image_comfirm.ps1`: confirm the active MCUboot image.

Project-specific values stay in each firmware repository's
`project_config.json`. The scripts resolve relative paths from that config
file's directory, so this repository can be used as a Git submodule.
