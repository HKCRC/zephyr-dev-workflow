# OTA 标准流程

本文描述 `craner-cv3d-gimbal` 项目的标准 OTA 操作流程。当前项目使用 Zephyr + MCUboot + mcumgr，所有日常命令通过项目根目录的 `dev.ps1` 执行。

## 前提条件

| 项目 | 要求 |
| --- | --- |
| 固件 | 已启用 MCUboot 和 mcumgr。 |
| 网络 | PC 可以访问 MCU 的 IP。当前默认 OTA 地址来自 `project_config.json` 的 `Ota.Address`。 |
| 工具 | PC 已安装 `mcumgr`，并且命令可执行。 |
| 构建 | 已通过 `.\dev.ps1 build` 生成 signed OTA 镜像。 |

查看当前 OTA 目标配置：

```powershell
Get-Content .\project_config.json
```

常用默认连接参数：

```text
address: 192.168.101.36
port: 1337
conn_type: udp
```

## 标准升级流程

推荐流程：

```powershell
.\dev.ps1 build
.\dev.ps1 ota
```

`.\dev.ps1 ota` 会完成下面几个动作：

| 步骤 | 动作 | 说明 |
| --- | --- | --- |
| 1 | 准备 signed 镜像 | 默认使用 sysbuild 生成的 `zephyr.signed.bin`。 |
| 2 | 上传镜像 | 通过 `mcumgr image upload` 上传到 MCUboot secondary slot。 |
| 3 | 查询镜像 | 通过 `mcumgr image list` 找到新镜像 hash。 |
| 4 | 标记 test | 通过 `mcumgr image test <hash>` 标记新镜像为 test。 |
| 5 | 重启设备 | 通过 `mcumgr reset` 让设备启动新固件。 |

新固件启动后，先观察日志、通信、业务功能是否正常。确认新固件可以长期运行后，再执行：

```powershell
.\dev.ps1 image_confirm
```

`image_confirm` 会确认当前运行镜像有效。确认后，后续重启不会回滚到旧固件。

## 试运行但不确认

如果只是想试运行新固件，不想确认该固件，流程如下：

```powershell
.\dev.ps1 build
.\dev.ps1 ota
```

设备会启动到新固件。此时不要执行：

```powershell
.\dev.ps1 image_confirm
```

如果判断新固件不需要保留，直接再次重启设备：

```powershell
.\dev.ps1 reset
```

MCUboot 会发现当前 test 镜像没有被确认，通常会回滚到旧固件。回滚到旧固件后，可以继续 OTA 另一版新固件：

```powershell
.\dev.ps1 build
.\dev.ps1 ota
```

注意：前提是应用固件没有在启动后自动确认镜像。如果应用代码里主动调用了 Zephyr/MCUboot 的镜像确认接口，那么再次重启不会回滚。

## 只上传和标记，不立即重启

如果希望 OTA 后由人工控制重启：

```powershell
.\dev.ps1 ota -skip_reset
```

此命令会上传镜像并标记 test，但不会重启设备。需要切换到新固件时再执行：

```powershell
.\dev.ps1 reset
```

## 查询镜像状态

查看 MCUboot 镜像状态：

```powershell
.\dev.ps1 image_list
```

常见状态含义：

| 状态 | 含义 |
| --- | --- |
| `active` | 当前正在运行的镜像。 |
| `confirmed` | 已确认有效，后续重启不会回滚。 |
| `pending` / `test` | 已标记为下次试运行。 |
| `permanent` | 标记为永久启动。当前标准流程不使用此模式。 |

实际字段以 `mcumgr image list` 输出为准。

## 常用命令表

| 目的 | 命令 |
| --- | --- |
| 编译固件 | `.\dev.ps1 build` |
| 干净重新编译 | `.\dev.ps1 build -pristine` |
| OTA 并自动重启 | `.\dev.ps1 ota` |
| OTA 但不重启 | `.\dev.ps1 ota -skip_reset` |
| 重启设备 | `.\dev.ps1 reset` |
| 查询镜像列表 | `.\dev.ps1 image_list` |
| 确认当前镜像 | `.\dev.ps1 image_confirm` |
| 查看 OTA 命令但不执行 | `.\dev.ps1 ota -dry_run` |
| 查看 reset 命令但不执行 | `.\dev.ps1 reset -dry_run` |

临时指定设备地址：

```powershell
.\dev.ps1 ota -address 192.168.101.36 -port 1337
.\dev.ps1 reset -address 192.168.101.36 -port 1337
.\dev.ps1 image_list -address 192.168.101.36 -port 1337
.\dev.ps1 image_confirm -address 192.168.101.36 -port 1337
```

## 推荐现场流程

### 正常升级并保留新固件

```powershell
.\dev.ps1 build
.\dev.ps1 ota
# 等待设备启动，观察日志和业务功能
.\dev.ps1 image_confirm
.\dev.ps1 reset
.\dev.ps1 image_list
```

确认点：

| 检查项 | 预期 |
| --- | --- |
| 设备可启动 | 串口日志正常输出。 |
| 网络可达 | PC 可以 ping 通设备 IP。 |
| 业务正常 | 心跳、Modbus、核心业务功能正常。 |
| 镜像已确认 | `image_list` 中当前镜像为 confirmed。 |

### 试运行新固件，失败后回滚

```powershell
.\dev.ps1 build
.\dev.ps1 ota
# 等待设备启动，观察日志和业务功能
# 不执行 image_confirm
.\dev.ps1 reset
.\dev.ps1 image_list
```

回滚到旧固件后，再修复代码并重新 OTA：

```powershell
.\dev.ps1 build
.\dev.ps1 ota
```

## 故障排查

| 问题 | 检查点 |
| --- | --- |
| `mcumgr` 找不到 | 确认 `mcumgr` 已安装，并且在 PATH 中。 |
| OTA 连接失败 | 检查 IP、端口、防火墙、网线、交换机和 MCU 网络状态。 |
| 上传后没有启动新固件 | 检查是否执行到 `image test` 和 `reset`，可用 `.\dev.ps1 image_list` 查看状态。 |
| 新固件重启后回滚 | 说明 test 镜像没有被确认。验证通过后执行 `.\dev.ps1 image_confirm`。 |
| 不希望 OTA 后立即重启 | 使用 `.\dev.ps1 ota -skip_reset`。 |
| 想确认命令内容 | 使用 `-dry_run` 查看实际 mcumgr 命令。 |
