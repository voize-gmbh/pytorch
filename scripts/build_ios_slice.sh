#!/usr/bin/env bash
# Builds one iOS slice of LibTorch-Lite and merges its static libraries into a
# single libtorch_lite.a, ready to be fed to build_ios_xcframework.sh.
#
# Split out from the packaging step so CI can build the slices in parallel --
# each one is a full libtorch build, so doing three sequentially in one job is
# slow enough to risk the runner time limit.
#
# Usage: build_ios_slice.sh <ios-arm64|ios-arm64-simulator|ios-x86_64-simulator>
#
# Inputs (optional):
#   WORKSPACE   - repo root; defaults to the parent folder of this script
#   SLICES_DIR  - where to place the output (default: $WORKSPACE/out/ios/slices)

set -euo pipefail

SLICE="${1:-}"
if [[ -z "$SLICE" ]]; then
  echo "usage: $0 <ios-arm64|ios-arm64-simulator|ios-x86_64-simulator>" >&2
  exit 2
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKSPACE="${WORKSPACE:-"$( cd "$SCRIPT_DIR/.." && pwd )"}"
SLICES_DIR="${SLICES_DIR:-"$WORKSPACE/out/ios/slices"}"

case "$SLICE" in
  ios-arm64)              PLATFORM=OS;        ARCH=arm64 ;;
  ios-arm64-simulator)    PLATFORM=SIMULATOR; ARCH=arm64 ;;
  ios-x86_64-simulator)   PLATFORM=SIMULATOR; ARCH=x86_64 ;;
  *) echo "Error: unknown slice '$SLICE'" >&2; exit 2 ;;
esac

echo "Building slice $SLICE (IOS_PLATFORM=$PLATFORM IOS_ARCH=$ARCH)"

cd "$WORKSPACE"
rm -rf build_ios
IOS_PLATFORM="$PLATFORM" IOS_ARCH="$ARCH" ./scripts/build_ios.sh

INSTALL_DIR="$WORKSPACE/build_ios/install"
if [[ ! -d "$INSTALL_DIR/lib" ]]; then
  echo "Error: expected install dir not found: $INSTALL_DIR/lib" >&2
  exit 1
fi

OUT="$SLICES_DIR/$SLICE"
mkdir -p "$OUT"

# One archive per slice keeps the artifact small enough to hand between CI jobs;
# the individual .a files add up to considerably more.
libtool -static -o "$OUT/libtorch_lite.a" $(find "$INSTALL_DIR/lib" -name '*.a')

echo "Built $OUT/libtorch_lite.a"
lipo -info "$OUT/libtorch_lite.a"

# The headers are identical across slices, so publish them once from the device
# build and let the other slices skip it.
if [[ "$SLICE" == "ios-arm64" ]]; then
  rm -rf "$SLICES_DIR/include"
  mkdir -p "$SLICES_DIR"
  cp -R "$INSTALL_DIR/include" "$SLICES_DIR/include"
  echo "Published headers to $SLICES_DIR/include"
fi
