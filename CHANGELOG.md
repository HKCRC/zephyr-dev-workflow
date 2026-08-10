# Changelog

## 3.8.0

- Add `reset` workflow command for `mcumgr reset`.
- Support `reset -dry_run`, `reset -address`, `reset -port`, `reset -conn_type`, and `reset -mcu_mgr`.

## 3.7.0

- Standardize public command options to lower_snake_case, for example `-dry_run`, `-extra_conf`, and `-image_path`.
- Replace hyphenated image commands with `image_list` and `image_confirm`.
- Remove intentional compatibility aliases for old command and option spellings.
- Add newcomer-facing migration and command reference documentation.

## 3.6.0

- Add `script/dev.ps1` as the shared workflow dispatcher.
- Standardize project usage around a single root `dev.ps1` entry point.

## 3.5.0

- Rename repository to `zephyr-dev-workflow`.
- Publish as `HKCRC/zephyr-dev-workflow`.

## 3.4.0

- Rename repository to `zephyr-build-flash-ota`.
- Remove project/company naming from the shared tool.

## 3.3.0

- Rename repository to an intermediate project-tool name.
- Rename `scripts` directory to `script`.

## 3.2.0

- Extract script for shared submodule use.
- Resolve project-relative paths from `project_config.json`.
- Keep `build.ps1` incremental by default and support `-pristine`.
