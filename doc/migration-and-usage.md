# zephyr-dev-workflow 迁移与使用指南

本文说明如何把一个已有 Zephyr 项目迁移到 `zephyr-dev-workflow`，以及迁移后新人如何编译、烧录和 OTA。

`zephyr-dev-workflow` 是一个可复用 Git submodule，负责提供统一的 PowerShell 开发入口。业务项目只保留自己的配置和一个很薄的入口脚本，不再在每个项目里维护重复的 `build.ps1`、`flash.ps1`、`ota.ps1` 逻辑。

## 目标结构

迁移完成后，业务项目推荐保持下面的结构：

```text
your-zephyr-project/
  dev.ps1
  project_config.json
  tool/
    zephyr-dev-workflow/
      script/
        dev.ps1
        build.ps1
        flash.ps1
        ota.ps1
        image_list.ps1
        image_comfirm.ps1
      doc/
        command-table.md
        migration-and-usage.md
```

| 文件或目录 | 职责 |
| --- | --- |
| `dev.ps1` | 业务项目唯一 PowerShell 入口，自动转发到 submodule。 |
| `project_config.json` | 业务项目差异配置，例如板卡、构建目录、烧录器、OTA 地址。 |
| `tool/zephyr-dev-workflow` | 共享工具 submodule，由 `HKCRC/zephyr-dev-workflow` 维护。 |
| `tool/zephyr-dev-workflow/script` | 共享脚本实现，不建议业务项目直接修改。 |
| `tool/zephyr-dev-workflow/doc` | 共享工具文档。 |

对外命令和参数统一使用小写加下划线，例如 `image_confirm`、`-dry_run`、`-extra_conf`。旧的根目录脚本和旧参数写法不再维护。

## 迁移前准备

| 项目 | 要求 |
| --- | --- |
| 操作系统 | Windows + PowerShell。 |
| Zephyr 构建 | 已经可以用 `west build` 构建。 |
| Python/west | `python -m west` 可用。 |
| Zephyr SDK | 已安装，并能通过项目配置路径找到。 |
| Git | 支持 submodule。 |
| 烧录工具 | 如果使用 STM32，建议安装 STM32CubeProgrammer，并确保 `STM32_Programmer_CLI` 可执行。 |
| OTA 工具 | 如果使用 OTA，需要安装 `mcumgr` 并确保命令可执行。 |

建议先确认旧项目当前构建命令能跑通，再开始迁移。这样如果迁移后失败，可以清楚地区分是工具迁移问题还是项目原有配置问题。

## 第一步：添加 submodule

在业务项目根目录执行：

```powershell
git submodule add https://github.com/HKCRC/zephyr-dev-workflow.git tool/zephyr-dev-workflow
git submodule update --init --recursive
```

提交时需要把 `.gitmodules` 和 submodule 指针一起提交：

```powershell
git add .gitmodules tool/zephyr-dev-workflow
```

`.gitmodules` 应该类似：

```ini
[submodule "tool/zephyr-dev-workflow"]
	path = tool/zephyr-dev-workflow
	url = https://github.com/HKCRC/zephyr-dev-workflow.git
```

## 第二步：新增项目入口 dev.ps1

在业务项目根目录新增 `dev.ps1`：

```powershell
# Version: 1.0.0
$toolScript = Join-Path $PSScriptRoot "tool\zephyr-dev-workflow\script\dev.ps1"
$projectConfig = Join-Path $PSScriptRoot "project_config.json"

if (-not (Test-Path $toolScript)) {
    Write-Error "Shared Zephyr workflow tool not found: $toolScript. Run git submodule update --init --recursive."
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

这个脚本只做三件事：

| 行为 | 说明 |
| --- | --- |
| 定位共享工具 | 找到 `tool/zephyr-dev-workflow/script/dev.ps1`。 |
| 自动注入配置 | 默认把项目根目录的 `project_config.json` 传给共享工具。 |
| 转发命令 | 把 `build`、`flash`、`ota` 等命令转发给共享工具。 |

## 第三步：新增 project_config.json

在业务项目根目录新增 `project_config.json`。下面是一个 STM32 + MCUboot + mcumgr OTA 项目的示例：

```json
{
  "Version": "3.0.0",
  "Base": {
    "Board": "your_board_name",
    "AppName": "your-app-name",
    "AppBuildName": "your_app_build_name",
    "ZephyrBase": "../zephyrproject/zephyr",
    "ZephyrSdkInstallDir": "../zephyr-sdk-1.0.1/zephyr-sdk-1.0.1"
  },
  "Build": {
    "BuildDir": "build/{Board}"
  },
  "Flash": {
    "FlashRunner": "stm32cubeprogrammer",
    "FlashConnection": "port=SWD",
    "FlashProgrammer": "STM32_Programmer_CLI",
    "BootloaderHexPath": "{BuildDir}/mcuboot/zephyr/zephyr.hex",
    "AppConfirmedHexPath": "{BuildDir}/{AppBuildName}/zephyr/zephyr.signed.confirmed.hex"
  },
  "Ota": {
    "Address": "192.168.101.36",
    "Port": 1337,
    "ConnType": "udp",
    "McuMgr": "mcumgr",
    "ImagePath": "",
    "AppSignedBinPath": "{BuildDir}/{AppBuildName}/zephyr/zephyr.signed.bin",
    "AppSignedHexPath": "{BuildDir}/{AppBuildName}/zephyr/zephyr.signed.hex",
    "OtaOutputDir": "{BuildDir}/ota_images",
    "OtaUpdateBinPath": "{OtaOutputDir}/app_update_signed.bin",
    "OtaUpdateHexPath": "{OtaOutputDir}/app_update_signed.hex"
  }
}
```

| 配置项 | 说明 |
| --- | --- |
| `Base.Board` | Zephyr 板卡名，对应 `west build -b <board>`。 |
| `Base.AppName` | 项目显示名，给文档或扩展脚本使用。 |
| `Base.AppBuildName` | sysbuild 下应用镜像目录名，通常等于 CMake `project()` 名的下划线形式。 |
| `Base.ZephyrBase` | Zephyr 源码路径。相对路径按 `project_config.json` 所在目录解析。 |
| `Base.ZephyrSdkInstallDir` | Zephyr SDK 安装路径。 |
| `Build.BuildDir` | 构建目录，支持 `{Board}` 占位符。 |
| `Flash.FlashRunner` | `west flash` 使用的 runner。 |
| `Flash.FlashConnection` | STM32CubeProgrammer 连接参数。 |
| `Flash.BootloaderHexPath` | MCUboot hex 路径。 |
| `Flash.AppConfirmedHexPath` | confirmed 应用 hex 路径。 |
| `Ota.Address` | OTA 目标 IP 或主机名。 |
| `Ota.Port` | mcumgr UDP 端口。 |
| `Ota.McuMgr` | mcumgr 命令名或完整路径。 |

完整命令和参数说明见：

```text
tool/zephyr-dev-workflow/doc/command-table.md
```

## 第四步：删除旧脚本

迁移到单入口后，删除业务项目根目录中重复维护的旧脚本：

```text
build.ps1
flash.ps1
ota.ps1
image_list.ps1
image_comfirm.ps1
project_common.ps1
```

删除后，新人只需要记住一个入口：

```powershell
.\dev.ps1 <command>
```

本工具不再保留旧根目录脚本的兼容入口。外部 CI 或生产脚本如果还在调用旧入口，应同步迁移到 `dev.ps1`。

## 第五步：验证迁移

确认 submodule 存在：

```powershell
Test-Path .\tool\zephyr-dev-workflow\script\dev.ps1
```

查看帮助和版本：

```powershell
.\dev.ps1 --help
.\dev.ps1 -version
.\dev.ps1 build -version
```

验证编译：

```powershell
.\dev.ps1 build
```

如果改过 DTS、Kconfig、board、sysbuild 配置，建议执行：

```powershell
.\dev.ps1 build -pristine
```

验证烧录命令但不实际烧录：

```powershell
.\dev.ps1 flash -dry_run
```

验证 OTA 命令但不实际上传：

```powershell
.\dev.ps1 ota -dry_run
```

## 常用命令

### 编译

```powershell
.\dev.ps1 build
```

默认是增量编译。脚本不会主动加 `-p always`。

### 干净重新配置并编译

```powershell
.\dev.ps1 build -pristine
```

适用场景：

| 场景 | 原因 |
| --- | --- |
| 修改 DTS | 需要重新生成 devicetree。 |
| 修改 Kconfig/prj.conf | 需要重新计算配置。 |
| 修改 board 文件 | CMake/Zephyr 缓存可能仍指向旧配置。 |
| sysbuild/MCUboot 配置变化 | 多镜像构建需要重新配置。 |

### 使用 west runner 烧录

```powershell
.\dev.ps1 flash
```

默认执行：

```text
python -m west flash -d <BuildDir> --runner <FlashRunner>
```

### 首次烧录 bootloader 和应用

```powershell
.\dev.ps1 build -pristine
.\dev.ps1 flash -target all
```

`-target all` 会通过 STM32CubeProgrammer 先烧录 MCUboot，再烧录 confirmed 应用镜像。

### 只烧录 MCUboot

```powershell
.\dev.ps1 flash -target bootloader
```

### 只烧录应用

```powershell
.\dev.ps1 flash -target app
```

### OTA 升级

```powershell
.\dev.ps1 build
.\dev.ps1 ota
```

OTA 成功启动并验证功能正常后，确认当前镜像：

```powershell
.\dev.ps1 image_confirm
```

如果不确认，MCUboot 可能在后续重启时回滚。

### 查询镜像状态

```powershell
.\dev.ps1 image_list
```

### 排查命令

```powershell
.\dev.ps1 flash -dry_run
.\dev.ps1 ota -dry_run
.\dev.ps1 image_confirm -dry_run
```

`-dry_run` 会打印实际命令或流程，不执行烧录、上传、复位等动作。

## 多项目更新共享工具

每个业务项目都通过 submodule 固定到一个明确提交。更新共享工具时，在业务项目根目录执行：

```powershell
git submodule update --remote tool/zephyr-dev-workflow
git add tool/zephyr-dev-workflow
git commit -m "Update zephyr-dev-workflow"
```

如果只是初始化一个刚 clone 的项目：

```powershell
git submodule update --init --recursive
```

如果需要查看当前项目使用的工具版本：

```powershell
git submodule status tool/zephyr-dev-workflow
.\dev.ps1 -version
```

## 新项目接入检查表

| 检查项 | 通过标准 |
| --- | --- |
| submodule 已添加 | `.gitmodules` 中有 `tool/zephyr-dev-workflow`。 |
| 根目录有 `dev.ps1` | 执行 `.\dev.ps1 --help` 可以显示帮助。 |
| 根目录有 `project_config.json` | 执行 `.\dev.ps1 build -version` 可以显示版本。 |
| `Base.Board` 正确 | `.\dev.ps1 build` 使用正确板卡。 |
| `Build.BuildDir` 正确 | 构建输出进入预期目录。 |
| `Flash.*` 正确 | `.\dev.ps1 flash -dry_run` 输出预期烧录命令。 |
| `Ota.*` 正确 | `.\dev.ps1 ota -dry_run` 输出预期 mcumgr 命令。 |
| 旧脚本已清理 | 新人只需要使用 `.\dev.ps1 <command>`。 |

## 常见问题

| 问题 | 处理方式 |
| --- | --- |
| `Shared Zephyr workflow tool not found` | 执行 `git submodule update --init --recursive`。 |
| 提示缺少 `Board`、`ZephyrBase`、`BuildDir` | 检查 `project_config.json` 是否存在，或者命令是否传错 `-config`。 |
| 修改 DTS 后构建没有变化 | 执行 `.\dev.ps1 build -pristine`。 |
| `flash` 找不到 hex | 先执行 `.\dev.ps1 build`，确认 `Flash.BootloaderHexPath` 和 `Flash.AppConfirmedHexPath` 正确。 |
| `ota` 找不到 signed bin | 确认 sysbuild/MCUboot 已启用，且 `Ota.AppSignedBinPath` 与实际构建产物一致。 |
| `mcumgr` 无法连接 | 检查设备 IP、端口、防火墙、网络连通性和固件 mcumgr 服务。 |
| OTA 后回滚 | 新固件验证通过后执行 `.\dev.ps1 image_confirm`。 |

## 推荐给新人看的顺序

1. 先读本文，理解项目如何接入 `zephyr-dev-workflow`。
2. 再读 `doc/command-table.md`，查询每个命令和参数。
3. 最后看业务项目自己的 README，确认板卡、串口、网络、烧录器等项目特定信息。
