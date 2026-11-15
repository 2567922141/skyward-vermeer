# skyward-vermeer（中文说明）

Skyward 恢复系统（recovery）在 **Redmi K70（vermeer，23113RKC6C）** 上的移植：设备配置、
Windows 宿主编译补丁，以及让触控可用的 THP 守护 shim。

本仓库**只存放源码**，不包含任何恢复镜像或发行产物。

基于 [kirklin/skyward](https://github.com/kirklin/skyward)（GPL-3.0-or-later）的移植：
本仓库只包含 `vermeer` 适配内容。

![AI assisted](https://img.shields.io/badge/development-AI--assisted-orange)
![Tested on device](https://img.shields.io/badge/tested-human%20on%20real%20device-brightgreen)
![Device](https://img.shields.io/badge/device-Redmi%20K70%20%28vermeer%29-blue)

[English](README.md) · 简体中文

> [!WARNING]
> ### ⚠️ 声明 · Declaration
>
> **本项目由 AI 辅助开发，所有功能结论均经人工真机测试。**
> **This project is developed with AI assistance, and every functional claim in it was
> verified by a human on a real device.**
>
> AI 输出仍可能有误，刷机有风险，使用前请自行阅读并复核。
> 完整说明见 / Full text: **[DISCLAIMER.md](DISCLAIMER.md)**

## 当前状态

真机（OS3.0.307.0.WNKCNXM）已测通过：

| 功能 | 结果 |
| --- | --- |
| 启动进入 Skyward | ✅ |
| 触控（内置 `thpstart`，重启后仍可用）、硬件按键、亮度 | ✅ |
| `/data` 解密（FBE） | ✅ |
| ADB 免授权 root；push/pull 后 sha256 一致 | ✅ |
| MTP | ✅ |
| 安装脚本 zip（脚本以 `api=3` 运行，日志 `/skyward/run/install-script.log`，退出码 0） | ✅ |
| 备份（`boot` 组 = boot/init_boot/vendor_boot/dtbo/vbmeta/vbmeta_system/recovery，7 个 lz4 文件，sha256 与 `backup.toml` 全等） | ✅ |
| 恢复（上述 7 个分区原样写回，sha256 全等；`recovery_b` 不动） | ✅ |
| 回滚原厂 recovery 再刷回（数据无损） | ✅ |
| WLAN 连接；0.0.7 起密码写入 `/metadata/skyward/wifi/`，0.0.9 起开机自动连接并获取地址（实测重启后 wlan0 直接拿到 192.168.0.111，无需重输密码） | ✅ |
| 在线更新（检测预发行、镜像下载、写入 recovery 槽位，重启后版本生效） | ✅ |

尚未测试，风险自负：格式化 `/data`、清缓存、`adb sideload`、A/B 槽位切换、双系统
（Skyward 支持，但 vermeer 没有对应系统包）、系统 OTA 在线检测/安装。

## 刷机前必读

- 只写 recovery 分区，boot、vbmeta、userdata 都不动；回滚只需一次
  `fastboot flash recovery_ab`——但要保留**你当前版本**的原厂镜像。
- Skyward 备份的「boot」组包含 7 个分区（boot、init_boot、vendor_boot、dtbo、vbmeta、
  vbmeta_system、**recovery**）；恢复该组会连 recovery 一起还原。
- vermeer 的 goodix 驱动工作在 **THP（Touch Hardware Path）模式**，触摸报文先进入
  `/dev/xiaomi-touch`，由 `touchfeature` HAL 的 `touch-report` 线程回注 input。recovery
  没有 framework 客户端，不跑 `thpstart` 时屏幕只响应硬件按键。
- `/odm/firmware/{glove,film,water}_model.tflite` 缺失，THP 的手套/贴膜/防水识别会报错，
  不影响触控。
- `/metadata` 默认只读，修改 `settings.json` 里的亮度需要先
  `mount -o rw,remount /metadata`。

## 刷入与回滚

```bash
adb reboot bootloader
fastboot flash recovery_ab out/skyward-vermeer.img
fastboot reboot recovery

# 回滚原厂
fastboot flash recovery_ab out/stock-recovery.img
fastboot reboot
```

`recovery_ab` 会同时写入两个槽位。

## 构建

依赖：Rust（stable）、`rustup target add aarch64-linux-android`、`cargo-ndk`、
Android NDK r29、`lz4`。

```bash
git clone https://github.com/kirklin/skyward.git repos/skyward
cd repos/skyward && git apply ../../patches/0001-vermeer-port.patch && cd ../..

# 需要一份同版本的原厂 recovery 分区镜像作为底板：
#   adb exec-out dd if=/dev/block/by-name/recovery_a of=out/stock-recovery.img
export STOCK=./out/stock-recovery.img

./scripts/make-extra.sh
./scripts/build.sh
```

`skyward-pack recovery` 会生成一个 100 MiB 的 boot 镜像：原厂 recovery 的 ramdisk，
加上 `skyward/`、`system/bin/recovery` 以及 `--extra` 覆盖层。

## 目录结构

| 路径 | 说明 |
|---|---|
| `devices/vermeer.toml` | 设备配置：显示、触控节点、服务、WLAN、owners |
| `patches/0001-vermeer-port.patch` | 本移植相对于上游的全部改动：`cfg(unix)` 保护、POSIX 绝对路径判定、`skyward-pack --extra`、发布列表/镜像/`latest.txt` 更新链路，以及本移植的 Wi-Fi 配置保存 |
| `src/thpstart.c` | shim：`dlopen("/odm/lib64/libtouchreport.so")` 并调用 `thp_daemon_main` |
| `scripts/build.sh` | 编译 skyward + system-init，并打包 recovery 镜像 |
| `scripts/make-extra.sh` | 用 NDK 编译 `thpstart` 到 `--extra` 覆盖层 |
| `notes/` | 真机取证、构建记录、触控问题调查 |
| `DISCLAIMER.md` | AI 辅助与人工真机测试声明（中英双语） |

## 上游仓库

本仓库是**设备移植**，不是 Skyward 的分支：Skyward 本体在
[kirklin/skyward](https://github.com/kirklin/skyward)（GPL-3.0-or-later）。

上游简介：Skyward 是一个用 Rust 从零编写的 recovery，做法是**基于手机原厂 recovery 镜像重建**——
保留原厂内核与分区布局，运行时通过 binder 调用原厂服务（keymint、gatekeeper、wpa_supplicant、
boot control 等），每台设备用一份 `devices/<codename>.toml` 描述。它从官方 OTA 包按需取出
recovery 分区并校验 SHA-256，支持解密 data、安装 A/B 全量 OTA/zip/分区镜像、在线下载官方 OTA、
更新后自愈写回 recovery、备份恢复、文件管理、终端、WLAN、MTP、adb、fastbootd、双系统等。

上游目前已适配 `nezha`（小米 17 Ultra）与 `ishtar`（小米 13 Ultra），另有 19 台在建；
本仓库补上 `vermeer`（Redmi K70）的配置、Windows 宿主编译补丁与 THP 触控 shim。

上游仓库地址：**https://github.com/kirklin/skyward**

## 许可

Skyward 上游为 GPL-3.0-or-later，本移植沿用同一许可，见 `LICENSE`。
