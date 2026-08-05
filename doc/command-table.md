# zephyr-dev-workflow 命令表

本文列举 `zephyr-dev-workflow` 提供的编译、烧录、OTA 相关命令和参数。新人日常只需要在业务项目根目录执行 `.\dev.ps1 <command>`，不要直接进入 `tool/zephyr-dev-workflow/script` 调内部脚本。

## 基本约定

| 项目 | 说明 |
| --- | --- |
| 项目入口 | `.\dev.ps1` |
| 共享工具目录 | `tool/zephyr-dev-workflow` |
| 项目配置文件 | `project_config.json` |
| 当前工具版本 | `3.6.0` |
| 默认板卡 | 来自 `project_config.json` 的 `Base.Board` |
| 默认构建目录 | 来自 `project_config.json` 的 `Build.BuildDir` |
| 默认 OTA 地址 | 来自 `project_config.json` 的 `Ota.Address` 和 `Ota.Port` |

根目录 `dev.ps1` 会自动把本项目的 `project_config.json` 传给共享工具，所以常规使用不需要手写 `-Config`。

## 总命令表

| 命令 | 用途 | 常用场景 |
| --- | --- | --- |
| `.\dev.ps1 --help` | 显示工具帮助 | 查看支持哪些子命令 |
| `.\dev.ps1 -Version` | 显示 dispatcher 版本 | 确认共享工具版本 |
| `.\dev.ps1 build` | 编译 Zephyr sysbuild 工程 | 日常增量编译 |
| `.\dev.ps1 build -Pristine` | 清理 CMake 配置后重新编译 | DTS、Kconfig、板卡配置变化后 |
| `.\dev.ps1 flash` | 使用 west runner 烧录 | 日常烧录应用或 west 默认镜像 |
| `.\dev.ps1 flash -Target Bootloader` | 只烧录 MCUboot | 首次烧录或 bootloader 更新 |
| `.\dev.ps1 flash -Target App` | 只烧录已确认应用镜像 | 已有 bootloader，仅更新 slot0 |
| `.\dev.ps1 flash -Target All` | 先烧录 MCUboot，再烧录应用 | 整机重新初始化 |
| `.\dev.ps1 ota` | 上传 OTA 镜像，标记为 test，并复位 | 网络 OTA 升级 |
| `.\dev.ps1 ota -SkipReset` | 上传并标记 OTA，但不复位 | 需要人工控制重启时 |
| `.\dev.ps1 image-list` | 查询 MCUboot 镜像列表 | 查看 slot0、slot1 状态 |
| `.\dev.ps1 image-confirm` | 确认当前运行镜像有效 | OTA 新固件启动验证通过后 |

## 全局参数

这些参数由 `dev.ps1` dispatcher 处理，或会转发给具体子命令。

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `-Config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。通常不需要手写，根目录 `dev.ps1` 会自动注入。 |
| `-Version` | 开关 | 关闭 | 显示 dispatcher 或子命令版本，不执行实际编译、烧录或 OTA。 |
| `--help` / `-help` / `-h` / `-?` | 开关 | 关闭 | 显示 dispatcher 帮助信息。 |

示例：

```powershell
.\dev.ps1 --help
.\dev.ps1 -Version
.\dev.ps1 build -Version
```

## build

编译 Zephyr sysbuild 工程。内部执行 `python -m west build --sysbuild`，并自动设置 `ZEPHYR_BASE`、`ZEPHYR_TOOLCHAIN_VARIANT`、`ZEPHYR_SDK_INSTALL_DIR`。

### 命令

```powershell
.\dev.ps1 build [-Board <board>] [-ExtraConf <path>] [-Pristine] [-Config <path>] [-Version]
```

### 参数

| 参数 | 类型 | 默认值来源 | 说明 |
| --- | --- | --- | --- |
| `-Board <board>` | 字符串 | `Base.Board` | Zephyr 板卡名。例如 `craner_cv3d_stm32h753iitx`。 |
| `-ExtraConf <path>` | 字符串 | 空 | 额外 Kconfig 配置文件。相对路径按项目根目录解析，最终传给 CMake 的 `EXTRA_CONF_FILE`。 |
| `-Pristine` | 开关 | 关闭 | 使用 `west build -p always` 重新生成构建系统。修改 DTS、Kconfig、board 文件后建议使用。 |
| `-Config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。 |
| `-Version` | 开关 | 关闭 | 仅显示 `build.ps1` 版本。 |

### 使用示例

```powershell
.\dev.ps1 build
.\dev.ps1 build -Pristine
.\dev.ps1 build -Board craner_cv3d_stm32h753iitx
.\dev.ps1 build -ExtraConf conf\debug.conf
.\dev.ps1 build -Version
```

### 相关配置项

| 配置项 | 说明 |
| --- | --- |
| `Base.Board` | 默认板卡名。 |
| `Base.ZephyrBase` | Zephyr 源码路径。 |
| `Base.ZephyrSdkInstallDir` | Zephyr SDK 安装路径。 |
| `Build.BuildDir` | 构建输出目录，支持 `{Board}` 占位符。 |

## flash

烧录固件。默认 `-Target West`，使用 `west flash` 和配置里的 runner。也支持使用 STM32CubeProgrammer 分别烧录 MCUboot 和应用镜像。

### 命令

```powershell
.\dev.ps1 flash [-Board <board>] [-Runner <runner>] [-Target West|Bootloader|App|All] [-Connection <connection>] [-Programmer <programmer>] [-IncludeBootloader] [-DryRun] [-Config <path>] [-Version]
```

### 参数

| 参数 | 类型 | 默认值来源 | 说明 |
| --- | --- | --- | --- |
| `-Board <board>` | 字符串 | `Base.Board` | 板卡名。主要用于错误提示和路径展开。 |
| `-Runner <runner>` | 字符串 | `Flash.FlashRunner` | west 烧录 runner。例如 `stm32cubeprogrammer`。仅 `-Target West` 使用。 |
| `-Target <target>` | 枚举 | `West` | 烧录目标。可选 `West`、`Bootloader`、`App`、`All`。 |
| `-Connection <connection>` | 字符串 | `Flash.FlashConnection` | STM32CubeProgrammer 连接参数。例如 `port=SWD`。 |
| `-Programmer <programmer>` | 字符串 | `Flash.FlashProgrammer` | STM32CubeProgrammer 命令名或路径。例如 `STM32_Programmer_CLI`。 |
| `-IncludeBootloader` | 开关 | 关闭 | 在非 `West` 流程中先烧录 bootloader。当前 `Bootloader` 和 `All` 已隐式烧录 bootloader。 |
| `-DryRun` | 开关 | 关闭 | 只打印将要执行的命令，不实际烧录。 |
| `-Config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。 |
| `-Version` | 开关 | 关闭 | 仅显示 `flash.ps1` 版本。 |

### Target 说明

| Target | 实际行为 | 适用场景 |
| --- | --- | --- |
| `West` | 执行 `python -m west flash -d <BuildDir> --runner <Runner>` | 日常使用 west runner 烧录。 |
| `Bootloader` | 使用 STM32CubeProgrammer 烧录 `BootloaderHexPath` | 首次烧录 MCUboot 或 bootloader 更新。 |
| `App` | 使用 STM32CubeProgrammer 烧录 `AppConfirmedHexPath` | bootloader 已存在，只更新 slot0 应用。 |
| `All` | 依次烧录 `BootloaderHexPath` 和 `AppConfirmedHexPath` | 空片或整体重刷。 |

### 使用示例

```powershell
.\dev.ps1 flash
.\dev.ps1 flash -DryRun
.\dev.ps1 flash -Target Bootloader
.\dev.ps1 flash -Target App
.\dev.ps1 flash -Target All
.\dev.ps1 flash -Target All -Connection port=SWD
.\dev.ps1 flash -Target App -Programmer C:\ST\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe
```

### 相关配置项

| 配置项 | 说明 |
| --- | --- |
| `Build.BuildDir` | west 构建目录。 |
| `Flash.FlashRunner` | west runner。 |
| `Flash.FlashConnection` | STM32CubeProgrammer 连接参数。 |
| `Flash.FlashProgrammer` | STM32CubeProgrammer 可执行程序。 |
| `Flash.BootloaderHexPath` | MCUboot hex 路径。 |
| `Flash.AppConfirmedHexPath` | 已确认应用 hex 路径。 |

## ota

通过 `mcumgr` 上传 MCUboot OTA 镜像到 slot1，读取镜像列表，标记 slot1 镜像为 test，然后默认复位设备。

### 命令

```powershell
.\dev.ps1 ota [-Board <board>] [-Address <ip-or-host>] [-Port <port>] [-ConnType <type>] [-McuMgr <path>] [-ImagePath <path>] [-SkipUpload] [-SkipReset] [-DryRun] [-RawUploadOutput] [-Config <path>] [-Version]
```

### 参数

| 参数 | 类型 | 默认值来源 | 说明 |
| --- | --- | --- | --- |
| `-Board <board>` | 字符串 | `Base.Board` | 板卡名。主要用于错误提示和路径展开。 |
| `-Address <ip-or-host>` | 字符串 | `Ota.Address` | 设备地址。例如 `192.168.101.36` 或主机名。 |
| `-Port <port>` | 整数 | `Ota.Port` | mcumgr UDP 端口，常用 `1337`。 |
| `-ConnType <type>` | 字符串 | `Ota.ConnType` | mcumgr 连接类型，例如 `udp`。 |
| `-McuMgr <path>` | 字符串 | `Ota.McuMgr` | mcumgr 命令名或完整路径。 |
| `-ImagePath <path>` | 字符串 | `Ota.ImagePath`，为空时自动使用构建产物 | 指定要上传的 signed bin。相对路径按项目根目录解析。 |
| `-SkipUpload` | 开关 | 关闭 | 不上传镜像，只读取当前 slot1 并标记为 test。 |
| `-SkipReset` | 开关 | 关闭 | 标记 test 后不执行 reset。 |
| `-DryRun` | 开关 | 关闭 | 打印 mcumgr 命令，不实际上传、test 或 reset。 |
| `-RawUploadOutput` | 开关 | 关闭 | 上传时直接输出 mcumgr 原始进度，适合排查上传卡住或输出格式问题。 |
| `-Config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。 |
| `-Version` | 开关 | 关闭 | 仅显示 `ota.ps1` 版本。 |

### 自动镜像准备逻辑

如果没有传 `-ImagePath`，脚本会：

| 步骤 | 行为 |
| --- | --- |
| 1 | 检查 `Ota.AppSignedBinPath` 是否存在。 |
| 2 | 创建 `Ota.OtaOutputDir`。 |
| 3 | 复制 signed bin 到 `Ota.OtaUpdateBinPath`。 |
| 4 | 如果 signed hex 存在，复制到 `Ota.OtaUpdateHexPath`。 |
| 5 | 使用复制后的 `Ota.OtaUpdateBinPath` 作为 OTA 上传文件。 |

### 使用示例

```powershell
.\dev.ps1 ota
.\dev.ps1 ota -DryRun
.\dev.ps1 ota -SkipReset
.\dev.ps1 ota -Address 192.168.101.36 -Port 1337
.\dev.ps1 ota -ImagePath build\craner_cv3d_stm32h753iitx\craner_cv3d_gimbal\zephyr\zephyr.signed.bin
.\dev.ps1 ota -SkipUpload -SkipReset
.\dev.ps1 ota -RawUploadOutput
```

### 相关配置项

| 配置项 | 说明 |
| --- | --- |
| `Ota.Address` | 默认 OTA 目标地址。 |
| `Ota.Port` | 默认 OTA 目标端口。 |
| `Ota.ConnType` | mcumgr 连接类型。 |
| `Ota.McuMgr` | mcumgr 命令。 |
| `Ota.ImagePath` | 默认上传镜像；为空时使用自动镜像准备逻辑。 |
| `Ota.AppSignedBinPath` | sysbuild 生成的 signed bin。 |
| `Ota.AppSignedHexPath` | sysbuild 生成的 signed hex。 |
| `Ota.OtaOutputDir` | OTA 镜像整理输出目录。 |
| `Ota.OtaUpdateBinPath` | 最终用于上传的 bin 路径。 |
| `Ota.OtaUpdateHexPath` | 同步保存的 hex 路径。 |

## image-list

通过 `mcumgr image list` 查询设备上的 MCUboot 镜像状态。

### 命令

```powershell
.\dev.ps1 image-list [-Address <ip-or-host>] [-Port <port>] [-ConnType <type>] [-McuMgr <path>] [-Config <path>] [-Version]
```

### 参数

| 参数 | 类型 | 默认值来源 | 说明 |
| --- | --- | --- | --- |
| `-Address <ip-or-host>` | 字符串 | `Ota.Address` | 设备地址。 |
| `-Port <port>` | 整数 | `Ota.Port` | mcumgr UDP 端口。 |
| `-ConnType <type>` | 字符串 | `Ota.ConnType` | mcumgr 连接类型。 |
| `-McuMgr <path>` | 字符串 | `Ota.McuMgr` | mcumgr 命令名或完整路径。 |
| `-Config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。 |
| `-Version` | 开关 | 关闭 | 仅显示 `image_list.ps1` 版本。 |

### 使用示例

```powershell
.\dev.ps1 image-list
.\dev.ps1 image-list -Address 192.168.101.36
.\dev.ps1 image-list -Address 192.168.101.36 -Port 1337
```

## image-confirm

读取 MCUboot 镜像列表，找到当前 active 镜像 hash，然后执行 `mcumgr image confirm <hash>`。OTA 新固件启动并确认功能正常后，应执行该命令，否则 MCUboot 可能在后续重启时回滚。

### 命令

```powershell
.\dev.ps1 image-confirm [-Address <ip-or-host>] [-Port <port>] [-ConnType <type>] [-McuMgr <path>] [-DryRun] [-Config <path>] [-Version]
```

### 参数

| 参数 | 类型 | 默认值来源 | 说明 |
| --- | --- | --- | --- |
| `-Address <ip-or-host>` | 字符串 | `Ota.Address` | 设备地址。 |
| `-Port <port>` | 整数 | `Ota.Port` | mcumgr UDP 端口。 |
| `-ConnType <type>` | 字符串 | `Ota.ConnType` | mcumgr 连接类型。 |
| `-McuMgr <path>` | 字符串 | `Ota.McuMgr` | mcumgr 命令名或完整路径。 |
| `-DryRun` | 开关 | 关闭 | 只打印 `image list` 命令，不解析 hash、不执行 confirm。 |
| `-Config <path>` | 字符串 | 项目根目录 `project_config.json` | 指定项目配置文件。 |
| `-Version` | 开关 | 关闭 | 仅显示 `image_comfirm.ps1` 版本。 |

### 使用示例

```powershell
.\dev.ps1 image-confirm
.\dev.ps1 image-confirm -DryRun
.\dev.ps1 image-confirm -Address 192.168.101.36 -Port 1337
```

## 推荐工作流

### 首次烧录

```powershell
.\dev.ps1 build -Pristine
.\dev.ps1 flash -Target All
```

### 日常本地编译和烧录

```powershell
.\dev.ps1 build
.\dev.ps1 flash
```

### OTA 升级

```powershell
.\dev.ps1 build
.\dev.ps1 ota
```

新固件启动并验证通过后：

```powershell
.\dev.ps1 image-confirm
```

### 排查烧录或 OTA 命令

```powershell
.\dev.ps1 flash -DryRun
.\dev.ps1 ota -DryRun
.\dev.ps1 image-list
```

## project_config.json 配置索引

| 分组 | 配置项 | 被哪些命令使用 | 说明 |
| --- | --- | --- | --- |
| `Base` | `Board` | `build`、`flash`、`ota` | 默认板卡名。 |
| `Base` | `AppName` | 当前脚本未直接使用 | 项目显示名，供项目扩展使用。 |
| `Base` | `AppBuildName` | `flash`、`ota` | sysbuild 应用输出目录名。 |
| `Base` | `ZephyrBase` | `build`、`flash` | Zephyr 源码路径。 |
| `Base` | `ZephyrSdkInstallDir` | `build`、`flash` | Zephyr SDK 路径。 |
| `Build` | `BuildDir` | `build`、`flash`、`ota` | 构建目录。 |
| `Flash` | `FlashRunner` | `flash -Target West` | west runner。 |
| `Flash` | `FlashConnection` | `flash -Target Bootloader/App/All` | STM32CubeProgrammer 连接参数。 |
| `Flash` | `FlashProgrammer` | `flash -Target Bootloader/App/All` | STM32CubeProgrammer 命令。 |
| `Flash` | `BootloaderHexPath` | `flash -Target Bootloader/All` | MCUboot hex。 |
| `Flash` | `AppConfirmedHexPath` | `flash -Target App/All` | confirmed 应用 hex。 |
| `Ota` | `Address` | `ota`、`image-list`、`image-confirm` | OTA 目标地址。 |
| `Ota` | `Port` | `ota`、`image-list`、`image-confirm` | OTA 目标端口。 |
| `Ota` | `ConnType` | `ota`、`image-list`、`image-confirm` | mcumgr 连接类型。 |
| `Ota` | `McuMgr` | `ota`、`image-list`、`image-confirm` | mcumgr 命令。 |
| `Ota` | `ImagePath` | `ota` | 指定默认 OTA 上传镜像。 |
| `Ota` | `AppSignedBinPath` | `ota` | sysbuild signed bin。 |
| `Ota` | `AppSignedHexPath` | `ota` | sysbuild signed hex。 |
| `Ota` | `OtaOutputDir` | `ota` | OTA 镜像整理目录。 |
| `Ota` | `OtaUpdateBinPath` | `ota` | 整理后的 OTA bin。 |
| `Ota` | `OtaUpdateHexPath` | `ota` | 整理后的 OTA hex。 |

## 注意事项

| 症状 | 检查点 |
| --- | --- |
| `Shared Zephyr workflow tool not found` | 是否执行过 `git submodule update --init --recursive`。 |
| 找不到 `ZephyrBase` 或 `BuildDir` | 检查 `project_config.json` 是否存在，路径是否被 `-Config` 覆盖。 |
| `flash` 找不到镜像 | 先执行 `.\dev.ps1 build`，如果修改过 DTS/Kconfig，执行 `.\dev.ps1 build -Pristine`。 |
| `ota` 找不到 signed bin | 确认 sysbuild/MCUboot 已启用，并且构建产物路径和 `Ota.AppSignedBinPath` 一致。 |
| `mcumgr` 连接失败 | 检查 MCU IP、端口、防火墙、网络连通性，以及固件是否启用 mcumgr UDP 服务。 |
| OTA 后重启回滚 | 新固件启动验证通过后需要执行 `.\dev.ps1 image-confirm`。 |
