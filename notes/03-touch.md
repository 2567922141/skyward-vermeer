# 触控问题记录（2026-11-13）

## 已确认事实
- 面板设备：`/dev/input/event7`，`name="goodix_ts"`，`INPUT_PROP_DIRECT`，MT 轴 `ABS_MT_POSITION_X 0..143999`、`Y 0..319999`、`ABS_MT_SLOT 0..9`、`ABS_MT_TRACKING_ID 0..65535`，另有 `KEY` 6 个。
- `lsmod`：`goodix_core`、`xiaomi_touch` 已加载；goodix 中断计数约 45656 且在涨。
- Skyward 已打开面板：`/proc/<pid>/fd/8 -> /dev/input/event7`，共 8 个 input fd。
- Skyward 源码无 `EVIOCGRAB`（多读者可同时收事件）。
- 早期两次抓包有数据：`/sdcard/ev7_capture.bin` 71,160 B（raw=1）、`/sdcard/ev7b.bin` 83,040 B（raw=0）。
- 后期两次抓包（点按时）均为 0 B：`/tmp/ev7.raw`、`/tmp/ev7b.raw`。
- 调试版（`skyward-vermeer-v3-debug.img`，input.rs 在 Down/Up 处写 kmsg）点按后 `dmesg | grep "skyward: touch"` 仍为 0 条。
- `settings.json` 里 `brightness: 0.02` → 背光实际 41/4095（≈1%），手动 `echo 2048 > brightness` 后屏幕正常亮起；点按仍无事件。
- vendor 存在 Xiaomi 触摸用户态服务：`/odm/bin/hw/vendor.xiaomi.hw.touchfeature@1.0-service`（Skyward 的 TOML 未启动它）。

## 结论
不是纯“驱动不上报”，也不是面板没被 Skyward 打开；而是触摸数据在 THP/raw 模式下走的是 `/dev/xiaomi-touch` + touchfeature 用户态服务，input 层只在特定条件下（raw=1/0 切换、刚开机）短暂有事件。

## 下一步（按优先级）
1. 在 `vermeer.toml` 增加 `[[service]]` 启动 `/odm/bin/hw/vendor.xiaomi.hw.touchfeature@1.0-service`（用户 system，组 system input uhid），并给 `/dev/xiaomi-touch` 配 owners（已有）。
2. 参考 ishtar 的 `touch_report`/`touchsensor` 模式：抓 `/dev/xiaomi-touch` 原始帧（TOUCH_FEATURE ioctl）转事件。
3. 或在 Skyward `input.rs` 增加 BTN_TOUCH 兜底与协议 A 解析（当前只认 `ABS_MT_TRACKING_ID` + `SYN_REPORT`）。
4. 每次测试前先把 `brightness` 设为 1.0，避免 1% 背光造成误判。

## 已修好的部分
- 解密：`vermeer.toml` 已加 `qseecomd`、`keymint-service-qti`、`hwservicemanager`、`gatekeeper@1.0-service-qti`、`boot@1.2-service`，日志确认全部在跑，`android.hardware.security.keymint.IKeyMintDevice/default` 已注册。

## v10：THP 守护内置（2026-11-13 23:0x）
- `skyward-pack` 增加 `--extra <dir>`（递归加入 ramdisk；`.so/.txt/.ini` 0644，其余 0755）。
- `out/extra/system/bin/thpstart` 打进 ramdisk，`vermeer.toml` 增加 `[[service]] path="/system/bin/thpstart"`（libraries /odm/lib64、/system/lib64；root；groups root/system/input/uhid）与 `/dev/uinput` owner。
- 镜像：`out/skyward-vermeer-v10-thp.img`（104,857,600 B，sha256 `982b79d5fc156dc73451acc1af68cc731eccc81cace820c8a9459c14b784fcad`）。
- 刷入并重启后：`ps` 里 thpstart(pid 760) 自动运行，dmesg 有 `skyward: touch down 896 2338`、`touch down 1124 1813`；qseecomd/keymint/gatekeeper/boot 均起来。重启不再需要手动拉起守护。

## 安装链路验证（4.1/4.5）
- 自建 `out/skyward-test.zip`（仅 update-binary + updater-script，715 B）：关闭签名校验后安装成功；脚本以 `api=3 zip=/sideload/package.zip` 运行，写入 `/data/skyward-test.txt`（66 B），`/skyward/run/install-script.log` 记录 4 行并以 `[ended: exit status: 0]` 结束。
- 安装界面不显示 echo 行：脚本的 stdout 进 `install-script.log`，界面只显示 updater-script 的 ui_print 进度解析结果（本次未显示，属显示层差异，不影响安装）。
