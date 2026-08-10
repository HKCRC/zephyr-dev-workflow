# zephyr-dev-workflow 迁移与使用说明

本文说明如何把一个 Zephyr 项目接入 `zephyr-dev-workflow`，以及接入后新人如何执行编译、烧录和 OTA。

`zephyr-dev-workflow` 是一个可复用的 Git submodule。业务项目根目录只保留一个薄入口 `dev.ps1` 和自己的 `project_config.json`；真正的通用命令调度器在 submodule 内，文件名为 `script/workflow.ps1`。

## 目标结构

```text
your-zephyr-project/
  dev.ps1
  project_config.json
  tool/
    zephyr-dev-workflow/
      script/
        workflow.ps1
        build.ps1
        flash.ps1
        ota.ps1
        reset.ps1
        image_list.ps1
        image_comfirm.ps1
```

| 路径 | 职责 |
| --- | --- |
| `dev.ps1` | 业务项目根目录入口，只负责注入本项目配置并转发命令。 |
| `project_config.json` | 业务项目差异配置，例如板卡、构建目录、烧录器、OTA 地址。 |
| `tool/zephyr-dev-workflow` | 共享工具 submodule，由 `HKCRC/zephyr-dev-workflow` 维护。 |
| `tool/zephyr-dev-workflow/script/workflow.ps1` | 共享命令调度器，负责分发 `build`、`flash`、`ota` 等命令。 |
| `tool/zephyr-dev-workflow/script/*.ps1` | 编译、烧录、OTA、reset、image 管理等具体实现。 |

对外使用时，新人只需要记住项目根目录命令：

```powershell
.\dev.ps1 <command> [options]
```

不要直接调用 `tool/zephyr-dev-workflow/script/workflow.ps1`，除非是在维护工具仓库本身。

## 添加 Submodule

在业务项目根目录执行：

```powershell
git submodule add https://github.com/HKCRC/zephyr-dev-workflow.git tool/zephyr-dev-workflow
git submodule update --init --recursive
```

提交时需要包含 `.gitmodules` 和 submodule 指针：

```powershell
git add .gitmodules tool/zephyr-dev-workflow
git commit -m "Add zephyr dev workflow submodule"
```

## 新增根目录入口

业务项目根目录新增 `dev.ps1`：

```powershell
# Version: 1.0.0
$toolScript = Join-Path $PSScriptRoot "tool\zephyr-dev-workflow\script\workflow.ps1"
$projectConfig = Join-Path $PSScriptRoot "project_config.json"

if (-not (Test-Path $toolScript)) {
    Write-Error "Workflow entry not found: $toolScript. Run git submodule update --init --recursive first."
    exit 1
}

$forwardArgs = @($args)
$hasConfig = $false
foreach ($arg in $forwardArgs) {
    if ($arg -eq "-config" -or $arg -like "-config:*") {
        $hasConfig = $true
        break
    }
}

if (-not $hasConfig -and $forwardArgs.Count -gt 0 -and -not ([string]$forwardArgs[0]).StartsWith("-")) {
    if ($forwardArgs.Count -gt 1) {
        $forwardArgs = @($forwardArgs[0], "-config", $projectConfig) + @($forwardArgs[1..($forwardArgs.Count - 1)])
    } else {
        $forwardArgs = @($forwardArgs[0], "-config", $projectConfig)
    }
}

& $toolScript @forwardArgs
exit $LASTEXITCODE
```

这个入口脚本只做三件事：

| 行为 | 说明 |
| --- | --- |
| 定位共享工具 | 找到 `tool/zephyr-dev-workflow/script/workflow.ps1`。 |
| 注入项目配置 | 默认把根目录 `project_config.json` 传给共享工具。 |
| 转发命令 | 把 `build`、`flash`、`ota` 等命令转发给共享调度器。 |

## 新增项目配置

业务项目根目录新增 `project_config.json`。示例：

```json
{
  "version": "3.10.0",
  "base": {
    "board": "your_board_name",
    "app_name": "your-app-name",
    "app_build_name": "your_app_build_name",
    "zephyr_base": "../zephyrproject/zephyr",
    "zephyr_sdk_install_dir": "../zephyr-sdk-1.0.1/zephyr-sdk-1.0.1"
  },
  "build": {
    "build_dir": "build/{board}"
  },
  "flash": {
    "flash_runner": "stm32cubeprogrammer",
    "flash_connection": "port=SWD",
    "bootloader_hex_path": "{build_dir}/mcuboot/zephyr/zephyr.hex",
    "app_confirmed_hex_path": "{build_dir}/{app_build_name}/zephyr/zephyr.signed.confirmed.hex"
  },
  "ota": {
    "address": "192.168.101.36",
    "port": 1337,
    "conn_type": "udp",
    "mcu_mgr": "mcumgr",
    "app_signed_bin_path": "{build_dir}/{app_build_name}/zephyr/zephyr.signed.bin"
  }
}
```

## 常用命令

| 命令 | 说明 |
| --- | --- |
| `.\dev.ps1 --help` | 查看帮助。 |
| `.\dev.ps1 -version` | 查看共享调度器版本。 |
| `.\dev.ps1 build` | 默认编译 MCUboot app 子工程。 |
| `.\dev.ps1 build -target none` | 无 bootloader 普通 Zephyr app 编译。 |
| `.\dev.ps1 build -target none -pristine` | 无 bootloader 干净重编。 |
| `.\dev.ps1 build -target all -pristine` | 编译 bootloader + app 的完整 sysbuild 工程。 |
| `.\dev.ps1 flash` | 默认烧录 MCUboot app 应用区镜像。 |
| `.\dev.ps1 flash -target none` | 无 bootloader 烧录普通 Zephyr app 到芯片起始地址。 |
| `.\dev.ps1 flash -target all` | 烧录 bootloader + app。 |
| `.\dev.ps1 ota` | 上传 OTA 镜像、标记 test，并按配置 reset。 |
| `.\dev.ps1 reset` | 通过 mcumgr 重启设备。 |
| `.\dev.ps1 image_list` | 查询 MCUboot 镜像列表。 |
| `.\dev.ps1 image_confirm` | 确认当前运行镜像有效。 |

## 验证接入

```powershell
Test-Path .\tool\zephyr-dev-workflow\script\workflow.ps1
.\dev.ps1 --help
.\dev.ps1 build -version
.\dev.ps1 flash -target none -dry_run
```

如果以上命令正常，说明根目录薄入口、项目配置注入、submodule 调度链路都已经接通。

## 更新 Submodule

拉取共享工具更新：

```powershell
git submodule update --remote tool/zephyr-dev-workflow
git add tool/zephyr-dev-workflow
git commit -m "Update zephyr dev workflow"
```

刚 clone 下来的项目需要初始化 submodule：

```powershell
git submodule update --init --recursive
```

查看当前项目使用的工具版本：

```powershell
git submodule status tool/zephyr-dev-workflow
.\dev.ps1 -version
```

## 排查

| 现象 | 处理 |
| --- | --- |
| `Workflow entry not found` | 执行 `git submodule update --init --recursive`。 |
| `build` 提示缺少 `board` 或 `build_dir` | 检查 `project_config.json` 是否存在，或者是否传错了 `-config`。 |
| 修改 DTS/Kconfig 后构建没变化 | 执行 `.\dev.ps1 build -target none -pristine` 或 `.\dev.ps1 build -target all -pristine`。 |
| `flash` 找不到 hex | 先执行对应 target 的 `build`，再检查 `project_config.json` 里的镜像路径。 |
| OTA 后回滚 | 新固件验证通过后执行 `.\dev.ps1 image_confirm`。 |
