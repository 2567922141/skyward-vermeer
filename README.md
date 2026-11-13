# skyward-vermeer

Skyward recovery for the Redmi K70 (`vermeer`, 23113RKC6C): device configuration, Windows-host
build patches, and the touch daemon shim required because this phone's goodix driver runs in
THP mode.

Source only — no recovery images, no release artifacts.

Based on [kirklin/skyward](https://github.com/kirklin/skyward) (GPL-3.0-or-later):
this repository only contains the `vermeer` port.

![AI assisted](https://img.shields.io/badge/development-AI--assisted-orange)
![Tested on device](https://img.shields.io/badge/tested-human%20on%20real%20device-brightgreen)
![Device](https://img.shields.io/badge/device-Redmi%20K70%20%28vermeer%29-blue)

[English](README.md) · [简体中文](README.zh-CN.md)

> [!WARNING]
> ### ⚠️ Declaration · 声明
>
> **This project is developed with AI assistance, and every functional claim in it was
> verified by a human on a real device.**
> **本项目由 AI 辅助开发，所有功能结论均经人工真机测试。**
>
> AI output may still contain mistakes, and flashing carries risk — read and verify before use.
> 完整说明见 / Full text: **[DISCLAIMER.md](DISCLAIMER.md)**

## Status

Working on a real device (OS3.0.307.0.WNKCNXM):

- boots as recovery; ADB root, MTP, brightness, hardware keys
- **touch works after reboot**: `thpstart` is built into the ramdisk and started as a service
- **/data decryption works** with the stock keymint services
- installs zips (script zips; signature check can be turned off), backup/restore, rollback to
  stock recovery and back

Not done: WLAN, MTP toggling, OTA self-heal, second-system packages (Skyward supports them, but
no package exists for vermeer).

## Before you flash

- Only the recovery partitions are touched; boot, vbmeta and userdata are left alone. Rollback is
  one `fastboot flash recovery_ab` away — but keep a stock image of **your** build.
- Backups made by Skyward's "boot" group contain 7 partitions (boot, init_boot, vendor_boot,
  dtbo, vbmeta, vbmeta_system, **recovery**); restoring that group also restores recovery.
- vermeer's goodix driver delivers touches over THP, not evdev. Without `thpstart` running the
  screen only answers to hardware keys.
- `/odm/firmware/{glove,film,water}_model.tflite` are absent, so those THP features log errors;
  touch still works.
- `/metadata` is read-only; changing brightness in `settings.json` needs
  `mount -o rw,remount /metadata`.

## Flash and rollback

```bash
adb reboot bootloader
fastboot flash recovery_ab out/skyward-vermeer.img
fastboot reboot recovery

# rollback
fastboot flash recovery_ab out/stock-recovery.img
fastboot reboot
```

`recovery_ab` writes both slots.

## Build

Prerequisites: Rust (stable), `rustup target add aarch64-linux-android`, `cargo-ndk`, Android
NDK r29, `lz4`.

```bash
git clone https://github.com/kirklin/skyward.git repos/skyward
cd repos/skyward && git apply ../../patches/0001-windows-host-build.patch && cd ../..

# a stock recovery image of the same build is the base:
#   adb exec-out dd if=/dev/block/by-name/recovery_a of=out/stock-recovery.img
export STOCK=./out/stock-recovery.img

./scripts/make-extra.sh
./scripts/build.sh
```

`skyward-pack recovery` writes a 100 MiB boot image: the stock recovery ramdisk plus `skyward/`,
`system/bin/recovery` and the `--extra` overlay.

## Layout

| Path | What |
|---|---|
| `devices/vermeer.toml` | device config (display, touch nodes, services, WLAN, owners) |
| `patches/0001-windows-host-build.patch` | `cfg(unix)` for the ramdisk code, POSIX-absolute path checks, `skyward-pack --extra` |
| `src/thpstart.c` | shim that dlopens `/odm/lib64/libtouchreport.so` and runs `thp_daemon_main` |
| `scripts/build.sh` | build skyward + system-init and pack a recovery image |
| `scripts/make-extra.sh` | compile `thpstart` into the `--extra` overlay |
| `notes/` | device facts, build record, touch investigation |
| `DISCLAIMER.md` | AI-assistance and real-device-testing declaration (bilingual) |

## Upstream

This repository is a **device port**, not a fork: the project itself lives at
[kirklin/skyward](https://github.com/kirklin/skyward) (GPL-3.0-or-later).

Skyward is a recovery written from scratch in Rust that rebuilds on top of the phone's **stock
recovery image**: it keeps the vendor kernel and partition layout, drives the stock services over
binder (keymint, gatekeeper, wpa_supplicant, boot control, ...), and describes each device in a
`devices/<codename>.toml`. It can pull the recovery partition from an official OTA package and
verify its SHA-256. Features include data decryption, installing A/B full OTAs / zips / partition
images, downloading official OTAs, writing itself back after an update, backup and restore, a
file manager, terminal, WLAN, MTP, adb, fastbootd and a second system beside the installed one.

Upstream supports `nezha` (Xiaomi 17 Ultra) and `ishtar` (Xiaomi 13 Ultra), with 19 more devices
in progress. This repository contributes the `vermeer` (Redmi K70) configuration, the Windows
host-build patches and the THP touch shim.

Upstream repository: **https://github.com/kirklin/skyward**

## License

Skyward is GPL-3.0-or-later; this port is distributed under the same terms. See `LICENSE`.
