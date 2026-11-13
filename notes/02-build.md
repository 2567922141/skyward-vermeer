# 构建记录（2026-11-13）

## 工具链

| 组件 | 版本 / 位置 |
| --- | --- |
| rustup / rustc / cargo | 1.100.0（`RUSTUP_HOME` 默认，`tools/rustup-init.exe` 安装） |
| aarch64 target | `aarch64-linux-android` |
| cargo-ndk | 4.1.2 |
| Android NDK | r29，`C:/skyward-tools/ndk-r29`（zip 833,850,862 B，解开约 2.4 GB） |
| lz4 | 1.11.1（scoop 安装，供 `skyward-pack` 压缩 ramdisk 调用） |

## 上游代码补丁（本地为 Windows 构建所加，均不改语义）

1. `crates/skyward-bootimg/src/ramdisk.rs`
   - 给 `std::os::unix` 导入、`Ramdisk::unpack`、`fn c_path`、`fn unpack`、`fn set_time` 加 `#[cfg(unix)]`；
   - 增加 `#[cfg(not(unix))] impl Ramdisk { pub fn unpack(..) -> Result<()> { bail!("unpacking a ramdisk onto the filesystem needs a Unix host") } }`。
   - 原因：host 端（Windows）编译 pack 需要该 crate，但 unix 专属 API 不可用。
2. `crates/skyward-config/src/lib.rs`
   - 新增 `fn rooted(path)`（`is_absolute() || 以 '/' 开头`）与 `fn plain(path)`（无 `.`/`..`/反斜杠）；
   - 替换 `[wipe] logs`、`[haptics] resonance`、`[logd] libraries`、`[[owners]] paths`、`[wlan] firmware`（无 partition 分支）的绝对路径校验。
   - 原因：Windows 上 `Path::is_absolute("/sys/...")` 为 false，而配置里全是 Android 绝对路径。

## 构建命令

```bash
# 1. packer（host，x86_64-pc-windows-msvc）
cd repos/skyward && cargo build --release -p skyward-pack

# 2. Skyward 主程序（aarch64）
export ANDROID_NDK_HOME=C:/skyward-tools/ndk-r29
export CARGO_TARGET_DIR=C:/skyward-tools/target
cargo ndk -t arm64-v8a --platform 30 build --release -p skyward

# 3. system-init（静态链接、供 system 分区旁装系统用）
RUSTFLAGS="-C target-feature=+crt-static" CARGO_TARGET_DIR=C:/skyward-tools/target-si \
  cargo ndk -t arm64-v8a --platform 30 build --release -p skyward-system-init

# 4. 打 recovery 镜像
./target/release/skyward-pack.exe recovery \
  --stock ../../out/stock-recovery-OS3.0.307.0.WNKCNXM.img \
  --binary C:/skyward-tools/target/aarch64-linux-android/release/skyward \
  --system-init C:/skyward-tools/target-si/aarch64-linux-android/release/system-init \
  --config devices/vermeer.toml \
  --font resources/fonts/MiSansVF.ttf \
  --mono resources/fonts/KirkMono-Regular.ttf \
  --mono-license resources/fonts/KirkMono-OFL.txt \
  --out ../../out/skyward-vermeer.img
```

## 产物

| 文件 | 大小 | SHA-256 |
| --- | --- | --- |
| `out/stock-recovery-OS3.0.307.0.WNKCNXM.img` | 104,857,600 | `58e508fe836d9f469e76440329d180a6556ed13ee42eb975a19124e7cc90c987` |
| `out/skyward-vermeer.img` | 104,857,600 | `b2951ea08c294dc05da55e194f5f6d7d845cd994aed704e402ed0c407506e12a` |
| 内嵌 `system/bin/recovery` | 8,593,464 | `1e7003ea6bbf4bd25405446c13b7d42901592ec30ada82bb7a6862b42b3181f6`（= 构建出的 skyward 二进制） |
| `skyward/system-init` | 1,040,152 | 静态链接 |

## 镜像内容核对（`skyward-pack list`）

- 头部：`ANDROID!`，header v4，kernel 0 B，ramdisk 48,371,508 B，整 100 MiB 分区。
- `system/bin/recovery` 已被替换为 Skyward 主程序（sha256 与构建产物一致）。
- 新增 `skyward/`：`system-init`、`device.toml`、`MiSansVF.ttf`、`KirkMono-Regular.ttf`、`KirkMono-OFL.txt`；以及 `system/etc/init/skyward-mtp.rc`。
- 原厂 ramdisk 内容保留（`init`、`init.recovery.*`、`miui.factoryreset.*`、`system/etc/recovery.fstab`、`res/images/*` 等）。

## 尚未做

- 实机启动验证（用户要求先不动手机，未刷入）。
- `[stock]` 段（`version` / `package` / `recovery` sha256）：当前用 `--stock` 本地镜像构建，不需要；补上后可支持 `skyward-pack stock` 自动下载。
- `corner_radius`、`soc` 官方文案等可选字段。

## 11.1 回滚往返实测（2026-11-13）
- 刷回原厂：`fastboot flash recovery_ab out/stock-recovery-OS3.0.307.0.WNKCNXM.img` → 启动进入 Mi Recovery，adb 可见 `getprop ro.build.version.incremental=OS3.0.307.0.WNKCNXM`，无 `skyward/thpstart/qseecomd` 进程，`/system/bin/thpstart` 不存在。
- 再刷 v10：`fastboot flash recovery_ab out/skyward-vermeer-v10-thp.img` → Skyward 正常进入，`thpstart`(849)、`keymint`(830)、`qseecomd`(777) 起来，`dmesg` 已有 20 次 `skyward: touch down`。
