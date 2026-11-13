#!/usr/bin/env bash
# Compile the THP touch daemon shim (src/thpstart.c) into the ramdisk overlay
# that skyward-pack --extra consumes. vermeer's goodix driver runs in THP mode,
# so no touch events reach evdev until thp_daemon_main runs.
set -euo pipefail
NDK=${ANDROID_NDK_HOME:-/c/skyward-tools/ndk-r29}
CLANG="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android30-clang"
mkdir -p out/extra/system/bin
"$CLANG" -O2 -o out/extra/system/bin/thpstart src/thpstart.c -ldl
ls -l out/extra/system/bin/thpstart
