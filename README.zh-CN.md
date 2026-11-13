# skyward-vermeer（中文说明）

Skyward 恢复系统（recovery）在 **Redmi K70（vermeer，23113RKC6C）** 上的移植：设备配置、
Windows 宿主编译补丁，以及让触控可用的 THP 守护 shim。

本仓库**只存放源码**，不包含任何恢复镜像或发行产物。

[English](README.md) · 简体中文

## 当前状态

已在真机（OS3.0.307.0.WNKCNXM）验证：

- 可作为 recovery 启动；ADB 免授权 root、MTP、亮度调节、硬件按键均正常
- **重启后触控仍然可用**：`thpstart` 已内置进 ramdisk，并注册为服务随启动运行
- **/data 解密正常**：依赖原厂 keymint 服务链（qseecomd、keymint、gatekeeper、boot 等）
- 可安装 zip（脚本包；签名校验可关闭）、备份/恢复、回滚原厂 recovery 后再刷回

尚未完成：WLAN、MTP 开关、系统 OTA 自愈、第二系统（Skyward 支持该功能，但 vermeer
目前没有对应的系统包）。

## 目录结构

| 路径 | 说明 |
|---|---|
| `devices/vermeer.toml` | 设备配置：显示、触控节点、服务、WLAN、owners |
| `patches/0001-windows-host-build.patch` | Windows 宿主编译补丁：ramdisk 代码的 `cfg(unix)`、POSIX 绝对路径判定、`skyward-pack --extra` |
| `src/thpstart.c` | shim：`dlopen("/odm/lib64/libtouchreport.so")` 并调用 `thp_daemon_main` |
| `scripts/build.sh` | 编译 skyward + system-init，并打包 recovery 镜像 |
| `scripts/make-extra.sh` | 用 NDK 编译 `thpstart` 到 `--extra` 覆盖层 |
| `notes/` | 真机取证、构建记录、触控问题调查 |

## 构建

依赖：Rust（stable）、`rustup target add aarch64-linux-android`、`cargo-ndk`、
Android NDK r29、`lz4`（用于检查镜像）。

```bash
git clone https://github.com/kirklin/skyward.git repos/skyward
cd repos/skyward && git apply ../../patches/0001-windows-host-build.patch && cd ../..

# 需要一份同版本的原厂 recovery 分区镜像作为底板：
#   adb exec-out dd if=/dev/block/by-name/recovery_a of=out/stock-recovery.img
export STOCK=./out/stock-recovery.img

./scripts/make-extra.sh
./scripts/build.sh
```

`skyward-pack recovery` 会生成一个 100 MiB 的 boot 镜像：原厂 recovery 的 ramdisk，
加上 `skyward/`、`system/bin/recovery` 以及 `--extra` 覆盖层。

## 刷入与回滚

```bash
adb reboot bootloader
fastboot flash recovery_ab out/skyward-vermeer.img
fastboot reboot recovery

# 回滚原厂
fastboot flash recovery_ab out/stock-recovery.img
fastboot reboot
```

`recovery_ab` 会同时写入两个槽位；除 recovery 分区外不改动任何分区。

## 注意事项

- vermeer 的 goodix 驱动工作在 **THP（Touch Hardware Path）模式**：触摸报文先进入
  `/dev/xiaomi-touch`，由 `touchfeature` HAL 里的 `touch-report` 线程回注 input；recovery
  没有 framework 客户端，因此不跑守护时触控完全无事件，只有硬件按键可用。
  `thpstart` 在本进程内调用 `thp_daemon_main`，随后驱动恢复在 `/dev/input/event7` 上报触控。
- vermeer 上没有 `/odm/bin/touch_report`、`/odm/bin/touchsensor`，配置里不要添加这两个服务，
  否则服务链中断会导致 keymint 等后续服务全部起不来（表现为解密失败）。
- `/odm/firmware/{glove,film,water}_model.tflite` 缺失，THP 的手套/贴膜/防水识别会报错，
  不影响触控。
- `/metadata` 默认只读，修改 `settings.json` 里的亮度需要先
  `mount -o rw,remount /metadata`。
- 备份的「boot」组包含 7 个分区：boot、init_boot、vendor_boot、dtbo、vbmeta、
  vbmeta_system、recovery；恢复 boot 组会连同 recovery 一起还原（备份时刷的是哪个版本，
  恢复后就是哪个版本）。

## 许可

Skyward 上游为 GPL-3.0-or-later，本移植沿用同一许可，见 `LICENSE`。
