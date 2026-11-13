#!/usr/bin/env bash
# Build Skyward (aarch64) + system-init, then pack a recovery image for vermeer.
# Prerequisites: rustup target aarch64-linux-android, cargo-ndk, Android NDK r29,
# a stock recovery image (see README), and the skyward source checkout.
set -euo pipefail
SKYWARD=${SKYWARD:-./repos/skyward}
TARGET_DIR=${CARGO_TARGET_DIR:-/c/skyward-tools/target}
NDK=${ANDROID_NDK_HOME:-/c/skyward-tools/ndk-r29}
STOCK=${STOCK:-./out/stock-recovery-OS3.0.307.0.WNKCNXM.img}
OUT=${OUT:-./out/skyward-vermeer.img}

export PATH="$HOME/.cargo/bin:$PATH"
export CARGO_TARGET_DIR="$TARGET_DIR"
export ANDROID_NDK_HOME="$NDK"

pushd "$SKYWARD"
cargo ndk -t arm64-v8a --platform 30 build --release -p skyward
RUSTFLAGS="-C target-feature=+crt-static" \
  CARGO_TARGET_DIR="${TARGET_DIR}-si" \
  cargo ndk -t arm64-v8a --platform 30 build --release -p skyward-system-init
# Host build of skyward-pack: needs patches/0001 applied.
cargo build --release -p skyward-pack
popd

"$SKYWARD/target/release/skyward-pack" recovery \
  --stock "$STOCK" \
  --binary "$TARGET_DIR/aarch64-linux-android/release/skyward" \
  --system-init "${TARGET_DIR}-si/aarch64-linux-android/release/system-init" \
  --config "$SKYWARD/devices/vermeer.toml" \
  --font "$SKYWARD/resources/fonts/MiSansVF.ttf" \
  --mono "$SKYWARD/resources/fonts/KirkMono-Regular.ttf" \
  --mono-license "$SKYWARD/resources/fonts/KirkMono-OFL.txt" \
  --extra ./out/extra \
  --out "$OUT"
