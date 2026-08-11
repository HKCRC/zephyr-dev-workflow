# zephyr-dev-workflow 命令表

本文列举 `zephyr-dev-workflow` 的编译、烧录、OTA 和 MCUboot 镜像管理命令。对外命令和参数统一使用小写加下划线。

## 基本入口

```powershell
.\dev.ps1 <command> [options]
```

| 命令 | 说明 |
| --- | --- |
| `.\dev.ps1 --help` | 查看帮助。 |
| `.\dev.ps1 -version` | 查看 dispatcher 版本。 |
| `.\dev.ps1 build` | 编译 MCUboot app 子工程。 |
| `.\dev.ps1 build -target no_bootloader` | 无 bootloader 普通 Zephyr app 编译。 |
| `.\dev.ps1 build -target all` | 编译 bootloader + app 的完整 sysbuild 工程。 |
| `.\dev.ps1 flash` | 烧录 MCUboot app 应用区镜像。 |
| `.\dev.ps1 flash -target no_bootloader` | 无 bootloader 普通 Zephyr app 烧录。 |
| `.\dev.ps1 flash -target all` | 先烧录 bootloader，再烧录 app。 |
| `.\dev.ps1 ota` | 执行 MCUboot/mcumgr OTA。 |
| `.\dev.ps1 reset` | 通过 mcumgr 重启设备。 |
| `.\dev.ps1 image_list` | 查询 MCUboot 镜像列表。 |
| `.\dev.ps1 image_confirm` | 确认当前运行镜像有效。 |

## build

```powershell
.\dev.ps1 build [-target no_bootloader|app|all] [-board <board>] [-extra_conf <path>] [-pristine] [-config <path>] [-version]
```

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-target <target>` | `app` | `no_bootloader`：普通 Zephyr app，无 bootloader；`app`：只编译已配置的 MCUboot app 子工程；`all`：sysbuild 编译 bootloader + app。 |
| `-board <board>` | `Base.BoardName` | Zephyr board 名。 |
| `-extra_conf <path>` | 空 | 额外 Kconfig 配置文件。 |
| `-pristine` | 关闭 | `no_bootloader` 和 `all` 目标可用，用于重新配置；`app` 子工程构建不支持。 |
| `-config <path>` | `project_config.json` | 指定项目配置文件。 |
| `-version` | 关闭 | 显示 build 脚本版本。 |

常用示例：

```powershell
.\dev.ps1 build
.\dev.ps1 build -target no_bootloader -pristine
.\dev.ps1 build -target all -pristine
```

## flash

```powershell
.\dev.ps1 flash [-target no_bootloader|app|all|bootloader|west] [-board <board>] [-runner <runner>] [-connection <connection>] [-programmer <programmer>] [-include_bootloader] [-dry_run] [-config <path>] [-version]
```

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-target <target>` | `app` | `no_bootloader`：烧普通 app `zephyr.hex`；`app`：烧 MCUboot app；`all`：烧 bootloader + app；`bootloader`：只烧 bootloader；`west`：直接走 west runner。 |
| `-runner <runner>` | `Flash.FlashRunner` | west flash runner。 |
| `-connection <connection>` | `Flash.FlashConnection` | STM32CubeProgrammer 连接参数，例如 `port=SWD`。 |
| `-programmer <programmer>` | `Flash.FlashProgrammer` | STM32CubeProgrammer 命令或完整路径。 |
| `-dry_run` | 关闭 | 只打印命令，不实际烧录。 |
| `-config <path>` | `project_config.json` | 指定项目配置文件。 |
| `-version` | 关闭 | 显示 flash 脚本版本。 |

常用示例：

```powershell
.\dev.ps1 flash
.\dev.ps1 flash -target no_bootloader
.\dev.ps1 flash -target no_bootloader -dry_run
.\dev.ps1 flash -target all
.\dev.ps1 flash -target west
```

## 无 bootloader 流程

无 bootloader 项目使用普通 Zephyr 构建，不启用 sysbuild，不生成 MCUboot signed 镜像：

```powershell
.\dev.ps1 build -target no_bootloader -pristine
.\dev.ps1 flash -target no_bootloader
```

烧录文件为：

```text
<BuildDir>\zephyr\zephyr.hex
```

## MCUboot 流程

首次完整构建和烧录：

```powershell
.\dev.ps1 build -target all -pristine
.\dev.ps1 flash -target all
```

日常 MCUboot app 子工程编译和应用区烧录：

```powershell
.\dev.ps1 build
.\dev.ps1 flash
```

## OTA

```powershell
.\dev.ps1 ota
.\dev.ps1 image_list
.\dev.ps1 image_confirm
.\dev.ps1 reset
```

OTA 仅适用于启用 MCUboot + mcumgr 的项目。无 bootloader 项目不使用 OTA 命令。
