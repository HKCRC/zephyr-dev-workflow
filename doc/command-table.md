# zephyr-dev-workflow 命令表

本文列举 `zephyr-dev-workflow` 提供的编译、烧录和 OTA 命令。对外命令和参数统一使用小写加下划线，例如 `-dry_run`、`-extra_conf`、`image_confirm`。

旧写法不再作为接口支持，例如 `-DryRun`、`-Version`、`image-list`、`image-confirm`。PowerShell 参数绑定本身大小写不敏感，这一点不额外处理；文档和脚本接口只按小写加下划线维护。

## 基本入口

在业务项目根目录执行：

```powershell
.\dev.ps1 <command> [options]
```

| 命令 | 说明 |
| --- | --- |
| `.\dev.ps1 --help` | 查看帮助。 |
| `.\dev.ps1 -version` | 查看 dispatcher 版本。 |
| `.\dev.ps1 build` | 编译 Zephyr sysbuild 工程。 |
| `.\dev.ps1 flash` | 烧录固件。 |
| `.\dev.ps1 ota` | 执行 MCUboot/mcumgr OTA。 |
| `.\dev.ps1 image_list` | 查询 MCUboot 镜像列表。 |
| `.\dev.ps1 image_confirm` | 确认当前运行镜像有效。 |

## 全局参数

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `-config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。业务项目根目录的 `dev.ps1` 会自动注入，日常通常不用手写。 |
| `-version` | 开关 | 关闭 | 显示对应命令版本，不执行实际动作。 |

## build

```powershell
.\dev.ps1 build [-board <board>] [-extra_conf <path>] [-pristine] [-config <path>] [-version]
```

| 参数 | 类型 | 默认值来源 | 说明 |
| --- | --- | --- | --- |
| `-board <board>` | 字符串 | `Base.Board` | Zephyr board 名。 |
| `-extra_conf <path>` | 字符串 | 空 | 额外 Kconfig 配置文件。相对路径按项目根目录解析。 |
| `-pristine` | 开关 | 关闭 | 使用 `west build -p always` 重新配置并编译。 |
| `-config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。 |
| `-version` | 开关 | 关闭 | 显示 build 脚本版本。 |

常用示例：

```powershell
.\dev.ps1 build
.\dev.ps1 build -pristine
.\dev.ps1 build -board craner_cv3d_stm32h753iitx
.\dev.ps1 build -extra_conf conf\debug.conf
.\dev.ps1 build -version
```

| 行为 | 说明 |
| --- | --- |
| 默认构建 | 增量构建，不主动加 `-p always`。 |
| `-pristine` | 修改 DTS、Kconfig、board、sysbuild 配置后建议使用。 |
| 环境变量 | 脚本会根据 `project_config.json` 设置 `ZEPHYR_BASE`、`ZEPHYR_TOOLCHAIN_VARIANT`、`ZEPHYR_SDK_INSTALL_DIR`。 |

## flash

```powershell
.\dev.ps1 flash [-board <board>] [-runner <runner>] [-target west|bootloader|app|all] [-connection <connection>] [-programmer <programmer>] [-include_bootloader] [-dry_run] [-config <path>] [-version]
```

| 参数 | 类型 | 默认值来源 | 说明 |
| --- | --- | --- | --- |
| `-board <board>` | 字符串 | `Base.Board` | 板卡名，用于路径展开和错误提示。 |
| `-runner <runner>` | 字符串 | `Flash.FlashRunner` | `west flash` runner，例如 `stm32cubeprogrammer`。 |
| `-target <target>` | 枚举 | `west` | 烧录目标：`west`、`bootloader`、`app`、`all`。 |
| `-connection <connection>` | 字符串 | `Flash.FlashConnection` | STM32CubeProgrammer 连接参数，例如 `port=SWD`。 |
| `-programmer <programmer>` | 字符串 | `Flash.FlashProgrammer` | STM32CubeProgrammer 命令或完整路径。 |
| `-include_bootloader` | 开关 | 关闭 | 非 `west` 流程中先烧录 bootloader。 |
| `-dry_run` | 开关 | 关闭 | 只打印命令，不实际烧录。 |
| `-config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。 |
| `-version` | 开关 | 关闭 | 显示 flash 脚本版本。 |

`-target` 行为：

| target | 行为 | 适用场景 |
| --- | --- | --- |
| `west` | 执行 `python -m west flash -d <BuildDir> --runner <runner>` | 日常 west runner 烧录。 |
| `bootloader` | 烧录 `Flash.BootloaderHexPath` | 首次烧录或 bootloader 更新。 |
| `app` | 烧录 `Flash.AppConfirmedHexPath` | bootloader 已存在，只更新应用。 |
| `all` | 先烧录 bootloader，再烧录 app | 空片或完整重刷。 |

常用示例：

```powershell
.\dev.ps1 flash
.\dev.ps1 flash -dry_run
.\dev.ps1 flash -target bootloader
.\dev.ps1 flash -target app
.\dev.ps1 flash -target all
.\dev.ps1 flash -target all -connection port=SWD
```

## ota

```powershell
.\dev.ps1 ota [-board <board>] [-address <ip-or-host>] [-port <port>] [-conn_type <type>] [-mcu_mgr <path>] [-image_path <path>] [-skip_upload] [-skip_reset] [-dry_run] [-raw_upload_output] [-config <path>] [-version]
```

| 参数 | 类型 | 默认值来源 | 说明 |
| --- | --- | --- | --- |
| `-board <board>` | 字符串 | `Base.Board` | 板卡名，用于路径展开和错误提示。 |
| `-address <ip-or-host>` | 字符串 | `Ota.Address` | OTA 目标地址。 |
| `-port <port>` | 整数 | `Ota.Port` | mcumgr 端口，UDP 常用 `1337`。 |
| `-conn_type <type>` | 字符串 | `Ota.ConnType` | mcumgr 连接类型，例如 `udp`。 |
| `-mcu_mgr <path>` | 字符串 | `Ota.McuMgr` | mcumgr 命令或完整路径。 |
| `-image_path <path>` | 字符串 | `Ota.ImagePath` | 指定 signed bin。为空时使用构建产物。 |
| `-skip_upload` | 开关 | 关闭 | 不上传镜像，只处理当前 slot 状态。 |
| `-skip_reset` | 开关 | 关闭 | 标记 test 后不复位。 |
| `-dry_run` | 开关 | 关闭 | 只打印 mcumgr 命令，不实际执行。 |
| `-raw_upload_output` | 开关 | 关闭 | 直接显示 mcumgr 上传原始输出。 |
| `-config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。 |
| `-version` | 开关 | 关闭 | 显示 ota 脚本版本。 |

常用示例：

```powershell
.\dev.ps1 ota
.\dev.ps1 ota -dry_run
.\dev.ps1 ota -skip_reset
.\dev.ps1 ota -address 192.168.101.36 -port 1337
.\dev.ps1 ota -image_path build\craner_cv3d_stm32h753iitx\craner_cv3d_gimbal\zephyr\zephyr.signed.bin
.\dev.ps1 ota -skip_upload -skip_reset
.\dev.ps1 ota -raw_upload_output
```

默认镜像准备逻辑：

| 步骤 | 行为 |
| --- | --- |
| 1 | 检查 `Ota.AppSignedBinPath` 是否存在。 |
| 2 | 创建 `Ota.OtaOutputDir`。 |
| 3 | 复制 signed bin 到 `Ota.OtaUpdateBinPath`。 |
| 4 | 如果 signed hex 存在，复制到 `Ota.OtaUpdateHexPath`。 |
| 5 | 使用 `Ota.OtaUpdateBinPath` 作为上传镜像。 |

## image_list

```powershell
.\dev.ps1 image_list [-address <ip-or-host>] [-port <port>] [-conn_type <type>] [-mcu_mgr <path>] [-config <path>] [-version]
```

| 参数 | 类型 | 默认值来源 | 说明 |
| --- | --- | --- | --- |
| `-address <ip-or-host>` | 字符串 | `Ota.Address` | 设备地址。 |
| `-port <port>` | 整数 | `Ota.Port` | mcumgr 端口。 |
| `-conn_type <type>` | 字符串 | `Ota.ConnType` | mcumgr 连接类型。 |
| `-mcu_mgr <path>` | 字符串 | `Ota.McuMgr` | mcumgr 命令或完整路径。 |
| `-config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。 |
| `-version` | 开关 | 关闭 | 显示 image_list 脚本版本。 |

示例：

```powershell
.\dev.ps1 image_list
.\dev.ps1 image_list -address 192.168.101.36
.\dev.ps1 image_list -address 192.168.101.36 -port 1337
```

## image_confirm

```powershell
.\dev.ps1 image_confirm [-address <ip-or-host>] [-port <port>] [-conn_type <type>] [-mcu_mgr <path>] [-dry_run] [-config <path>] [-version]
```

| 参数 | 类型 | 默认值来源 | 说明 |
| --- | --- | --- | --- |
| `-address <ip-or-host>` | 字符串 | `Ota.Address` | 设备地址。 |
| `-port <port>` | 整数 | `Ota.Port` | mcumgr 端口。 |
| `-conn_type <type>` | 字符串 | `Ota.ConnType` | mcumgr 连接类型。 |
| `-mcu_mgr <path>` | 字符串 | `Ota.McuMgr` | mcumgr 命令或完整路径。 |
| `-dry_run` | 开关 | 关闭 | 只打印查询命令，不执行 confirm。 |
| `-config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。 |
| `-version` | 开关 | 关闭 | 显示 image_confirm 脚本版本。 |

示例：

```powershell
.\dev.ps1 image_confirm
.\dev.ps1 image_confirm -dry_run
.\dev.ps1 image_confirm -address 192.168.101.36 -port 1337
```

## 推荐流程

首次烧录：

```powershell
.\dev.ps1 build -pristine
.\dev.ps1 flash -target all
```

日常编译烧录：

```powershell
.\dev.ps1 build
.\dev.ps1 flash
```

OTA：

```powershell
.\dev.ps1 build
.\dev.ps1 ota
.\dev.ps1 image_confirm
```

排查：

```powershell
.\dev.ps1 flash -dry_run
.\dev.ps1 ota -dry_run
.\dev.ps1 image_list
```

## project_config.json 索引

| 分组 | 配置项 | 使用命令 | 说明 |
| --- | --- | --- | --- |
| `Base` | `Board` | `build`、`flash`、`ota` | 默认板卡名。 |
| `Base` | `AppName` | 扩展使用 | 项目显示名。 |
| `Base` | `AppBuildName` | `flash`、`ota` | sysbuild 应用输出目录名。 |
| `Base` | `ZephyrBase` | `build`、`flash` | Zephyr 源码路径。 |
| `Base` | `ZephyrSdkInstallDir` | `build`、`flash` | Zephyr SDK 路径。 |
| `Build` | `BuildDir` | `build`、`flash`、`ota` | 构建目录。 |
| `Flash` | `FlashRunner` | `flash -target west` | west runner。 |
| `Flash` | `FlashConnection` | `flash -target bootloader/app/all` | STM32CubeProgrammer 连接参数。 |
| `Flash` | `FlashProgrammer` | `flash -target bootloader/app/all` | STM32CubeProgrammer 命令。 |
| `Flash` | `BootloaderHexPath` | `flash -target bootloader/all` | MCUboot hex。 |
| `Flash` | `AppConfirmedHexPath` | `flash -target app/all` | confirmed 应用 hex。 |
| `Ota` | `Address` | `ota`、`image_list`、`image_confirm` | OTA 目标地址。 |
| `Ota` | `Port` | `ota`、`image_list`、`image_confirm` | OTA 目标端口。 |
| `Ota` | `ConnType` | `ota`、`image_list`、`image_confirm` | mcumgr 连接类型。 |
| `Ota` | `McuMgr` | `ota`、`image_list`、`image_confirm` | mcumgr 命令。 |
| `Ota` | `ImagePath` | `ota` | 默认 OTA 镜像路径。 |
| `Ota` | `AppSignedBinPath` | `ota` | sysbuild signed bin。 |
| `Ota` | `AppSignedHexPath` | `ota` | sysbuild signed hex。 |
| `Ota` | `OtaOutputDir` | `ota` | OTA 镜像整理目录。 |
| `Ota` | `OtaUpdateBinPath` | `ota` | 整理后的 OTA bin。 |
| `Ota` | `OtaUpdateHexPath` | `ota` | 整理后的 OTA hex。 |

## 常见问题

| 问题 | 检查点 |
| --- | --- |
| 找不到共享工具 | 执行 `git submodule update --init --recursive`。 |
| 提示缺少 `Board` 或 `BuildDir` | 检查 `project_config.json` 和 `-config` 路径。 |
| 修改 DTS 后构建未变化 | 使用 `.\dev.ps1 build -pristine`。 |
| `flash` 找不到 hex | 先执行 `.\dev.ps1 build`，检查 `Flash.*Path`。 |
| `ota` 找不到 signed bin | 确认 MCUboot/sysbuild 已启用，检查 `Ota.AppSignedBinPath`。 |
| OTA 后回滚 | 新固件验证通过后执行 `.\dev.ps1 image_confirm`。 |
