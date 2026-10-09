# OTA standard flow

Version 5.0.0 separates MCUboot image operations so uploading, test marking,
and resetting can be controlled independently.

## One-command upload and test

```powershell
.\dev.ps1 ota
```

This command prepares the configured signed image, uploads it to slot 1, reads
the slot 1 hash, and marks that hash for test boot. It does not reset the
device. Reset explicitly when the device is ready:

```powershell
.\dev.ps1 image reset
```

After the new firmware boots and passes validation, confirm it:

```powershell
.\dev.ps1 image confirm
```

## Step-by-step flow

```powershell
.\dev.ps1 image upload
.\dev.ps1 image list
.\dev.ps1 image test <hash>
.\dev.ps1 image reset
.\dev.ps1 image confirm
```

## Overrides and dry runs

All image commands use `OtaTarget`, `Port`, `ConnType`, and `McuMgr` from
`project_config.json`. Connection values can be overridden explicitly:

```powershell
.\dev.ps1 image list -address 192.168.101.36 -port 1337
```

Use `-dry_run` to print an operation without contacting the device:

```powershell
.\dev.ps1 ota -dry_run
.\dev.ps1 image upload -dry_run
.\dev.ps1 image test 0123abcd -dry_run
.\dev.ps1 image reset -dry_run
.\dev.ps1 image list -dry_run
.\dev.ps1 image confirm -dry_run
```

An explicit image path can be supplied for upload or OTA:

```powershell
.\dev.ps1 image upload -image_path path\to\signed.bin
.\dev.ps1 ota -image_path path\to\signed.bin
```
