# skyward-vermeer

Skyward recovery for the Redmi K70 (`vermeer`, 23113RKC6C): device configuration,
Windows-host build patches, and the touch daemon shim needed because this phone's
goodix driver runs in THP mode.

This repository holds **source only** — no recovery images, no release artifacts.

## Status

Working on a real device (OS3.0.307.0.WNKCNXM):

- boots as recovery, ADB root, MTP, brightness, keys
- **touch works after reboot**: `thpstart` is built into the ramdisk and started as a service
- **/data decryption works** with the stock keymint services
- installs zips (script zips; signature check can be turned off), backup/restore, rollback to
  stock recovery and back

Not done: WLAN, MTP toggling, OTA self-heal, second-system packages (Skyward supports them,
but no package exists for vermeer).

## Layout

| Path | What |
|---|---|
| `devices/vermeer.toml` | device config (display, touch nodes, services, WLAN, owners) |
| `patches/0001-windows-host-build.patch` | host-build fixes: `cfg(unix)` for the ramdisk code, POSIX-absolute path checks, `skyward-pack --extra` |
| `src/thpstart.c` | shim that dlopens `/odm/lib64/libtouchreport.so` and runs `thp_daemon_main` |
| `scripts/build.sh` | build skyward + system-init + pack a recovery image |
| `scripts/make-extra.sh` | compile `thpstart` into the `--extra` overlay |
| `notes/` | device facts, build record, touch investigation |

## Build

Prerequisites: Rust (stable), `rustup target add aarch64-linux-android`, `cargo-ndk`,
Android NDK r29, `lz4` (for inspecting images).

```bash
git clone https://github.com/kirklin/skyward.git repos/skyward
cd repos/skyward && git apply ../../patches/0001-windows-host-build.patch && cd ../..

# a stock recovery partition image of the same build is required as the base:
#   adb exec-out dd if=/dev/block/by-name/recovery_a of=out/stock-recovery.img
export STOCK=./out/stock-recovery.img

./scripts/make-extra.sh
./scripts/build.sh
```

`skyward-pack recovery` writes a 100 MiB boot image with the stock recovery's ramdisk
plus `skyward/`, `system/bin/recovery` and the `--extra` overlay.

## Flash / rollback

```bash
adb reboot bootloader
fastboot flash recovery_ab out/skyward-vermeer.img
fastboot reboot recovery

# rollback
fastboot flash recovery_ab out/stock-recovery.img
fastboot reboot
```

Flashing `recovery_ab` writes both slots; nothing outside the recovery partitions is touched.

## Notes

- The device's kernel driver reports touches through THP, not evdev; without the daemon the
  screen only reacts to hardware keys. `thpstart` runs `thp_daemon_main` in-process and the
  driver then publishes touch events on `/dev/input/event7`.
- `/odm/firmware/{glove,film,water}_model.tflite` are absent on vermeer, so those THP features
  log errors; touches still work.
- `/metadata` is mounted read-only; brightness in `settings.json` needs
  `mount -o rw,remount /metadata` to change.

## License

Skyward is GPL-3.0-or-later; this port is distributed under the same terms. See `LICENSE`.
