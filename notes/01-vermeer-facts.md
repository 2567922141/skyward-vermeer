# vermeer（Redmi K70）适配取证记录

日期：2026-11-13。目标：为 `kirklin/skyward` 增加 `devices/vermeer.toml`，不改动手机。

## 已确认事实

| 项目 | 值 | 来源 |
| --- | --- | --- |
| 代号 / 型号 | vermeer / 23113RKC6C（CN）、23113RKC6G（全球） | `getprop`、LOS `lineage_vermeer.mk` |
| 平台 | SM8550（Snapdragon 8 Gen 2） | LOS BoardConfigCommon `TARGET_BOARD_PLATFORM` |
| 屏幕 | 1440×3200（`persist.sys.miui_resolution`），LOS `TARGET_SCREEN_DENSITY := 530` | `vermeer/properties/odm.prop`、`vermeer/BoardConfig.mk` |
| 触控 IC 驱动 | `goodix_core`（Goodix Berlin，`CONFIG_TOUCHSCREEN_GOODIX_BRL=m`，模块由 `obj-$(CONFIG_TOUCHSCREEN_GOODIX_BRL) += goodix_core.o` 定义） | `arch/arm64/configs/vendor/vermeer_GKI.config`、`drivers/input/touchscreen/goodix_berlin_driver/Makefile` |
| 触控特性层 | `xiaomi_touch`（`CONFIG_TOUCHSCREEN_XIAOMI_TOUCHFEATURE=m`） | 同上 |
| 触控服务 | **无** `/odm/bin/touch_report`、`touchsensor`（与 fuxi 不同） | TheMuppets `proprietary_vendor_xiaomi_vermeer` 文件清单 |
| 触控节点 | `/dev/xiaomi-touch`、`/sys/class/touch/touch_dev/{fod_longpress_gesture_enabled,gesture_single_tap_enabled,gesture_double_tap_enabled,gesture_double_tap_state}`、`/sys/devices/virtual/touch/touch_dev/bump_sample_rate` | `sm8550-common/init/init.sm8550.rc` |
| WLAN | `qca_cld3_kiwi_v2`，上层 `/vendor/etc/wifi/kiwi_v2/WCNSS_qcom_cfg.ini`、`/persist/kiwi_v2/wlan_mac.bin`，`/sys/kernel/cnss/fs_ready` | `modules.load.vendor_dlkm`、`proprietary-files.txt`、`init.target.rc` |
| 马达 | `qcom-hv-haptics`（`CONFIG_INPUT_QCOM_HV_HAPTICS=m`） | `kalama_GKI.config`、`modules.load.recovery` |
| 指纹 | Goodix FOD（`goodix_fod.ko`、`goodix_core.ko`） | `vermeer/BoardConfig.mk` |
| A/B | 是（`ab = true`，LOS 构建含 boot/init_boot/vendor_boot） | LOS `BoardConfigCommon.mk` |

## 待真机核实（设备目前 adb offline，未执行）

1. **触摸驱动实际加载情况**：`lsmod | grep -E 'goodix|xiaomi_touch'`；`/dev/input` 事件是否随触摸产生。
   若 `goodix_core` 实为内置（`=y`），`modules.load` 需去掉它；若模块名不同（如 `goodix_ts`），要相应改。
2. **密度**：`wm density` / `getprop ro.sf.lcd_density`。LOS 树给 530，zorn 同分辨率用 560，二者取一。
3. **屏幕圆角**：`corner_radius` 字段未填，可从 `dumpsys window` 或面板参数取。
4. **[stock]**：需要 `OS3.0.307.0.WNKCNXM` 全量包 URL 与 `recovery` 分区 SHA-256；或等设备上线后 `dd if=/dev/block/by-name/recovery of=/sdcard/recovery.img` 导出，直接喂 `skyward-pack recovery --stock recovery.img`（`stock` 子命令才需要 [stock] 段）。
5. `soc` 文案：`第二代骁龙®8移动平台` 是否与 Xiaomi 官方写法一致。

## 已知风险

- Skyward 以 stock recovery 为底重新打包，**只写 recovery 分区**；失败可用官方 `recovery.img` 回刷，不涉及 boot/vbmeta，理论上不砖。
- 若触摸驱动未在 recovery 内加载，recovery 会无触摸输入（可用 adb/按键兜底）。
- `[stock]` 缺失只影响 `skyward-pack stock` 查询，不影响 `recovery` 构建。

## 下一步（按顺序）

1. 设备上线后只读采集：`lsmod`、`/dev/input`、`wm density`、`/proc/cmdline`、`/vendor/lib/modules` 列表。
2. 修正 TOML 的 `modules.load` 与 `display.density`。
3. 安装 Rust 工具链 + Android NDK，编译 `skyward-pack` 与 recovery 二进制。
4. 用 `dd` 导出的 stock recovery 构建镜像，`fastboot flash recovery` 后实机验证触摸/显示/解密。

## 真机只读核实（2026-11-13 21:49，设备 <serial>）

- `lsmod`：`goodix_core 368640 0`、`xiaomi_touch 110592 5 goodix_core`、`goodix_fod 32768 3` → `modules.load = ["goodix_core","xiaomi_touch"]` 正确。
- `/vendor/lib/modules` 确有 `goodix_core.ko`、`goodix_fod.ko`、`xiaomi_touch.ko`。
- 输入设备：`goodix_ts` → `/dev/input/event7`（另有 uinput-goodix → event1），触摸由 goodix 驱动直接出输入事件。
- `/sys/class/touch/touch_dev/` 实际节点：`enable_touch_raw`(system system 0660)、`touch_finger_status`(0660)、`resolution_factor`(root root 0660) 等；**没有** 13 系列的 `fod_longpress_gesture_enabled` / `gesture_*` / `bump_sample_rate` → TOML owners 已按实际节点改。
- 屏幕密度：`wm density` = 560、`persist.sys.miui_resolution=1440,3200,560` → TOML density 由 530 改为 **560**。
- 分区：`recovery_a -> /dev/block/sde27`（100 MiB），`recovery_b -> sde56`；当前槽 `_a`；另有 boot_a/b、init_boot_a/b、vendor_boot_a/b。
- 固件：`ro.mi.os.version.incremental = OS3.0.307.0.WNKCNXM`；`/mnt/vendor/persist/kiwi_v2/wlan_mac.bin` 存在（18 B）。
- 已用 `adb exec-out dd if=/dev/block/by-name/recovery_a` 导出 stock recovery 到 `out/stock-recovery-OS3.0.307.0.WNKCNXM.img`（104,857,600 B，SHA-256 `58e508fe836d9f469e76440329d180a6556ed13ee42eb975a19124e7cc90c987`）。头部为 `ANDROID!`、header_version=4、kernel_size=0、ramdisk_size=27,717,214 → 纯 ramdisk 的 v4 镜像，`skyward-bootimg` 支持 v3/v4（v0 才会拒绝）。
