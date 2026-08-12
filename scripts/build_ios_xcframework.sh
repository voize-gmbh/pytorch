#!/usr/bin/env bash
# Assembles an XCFramework from per-slice LibTorch-Lite builds.
#
# The pod produced by build_ios_cocoapod.sh vendors plain `.a` files, which can
# only ever carry one slice per architecture -- device arm64 and simulator arm64
# are both "arm64" and cannot be lipo'd into one archive. An XCFramework is the
# only packaging that lets a consumer link the right slice for device and
# simulator alike, which is what an app that runs its test suite on the
# simulator needs.
#
# Inputs (optional):
#   WORKSPACE   - repo root; defaults to the parent folder of this script
#   SLICES_DIR  - directory holding per-slice inputs (default: $WORKSPACE/out/ios/slices)
#   OUT_DIR     - output directory (default: $WORKSPACE/out/ios)
#
# Expected layout under SLICES_DIR, as produced by build_ios_slice.sh:
#   ios-arm64/libtorch_lite.a                 (device)
#   ios-arm64-simulator/libtorch_lite.a       (simulator, Apple silicon)
#   ios-x86_64-simulator/libtorch_lite.a      (simulator, Intel)   [optional]
#   include/                                  (headers, any one slice will do)

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKSPACE="${WORKSPACE:-"$( cd "$SCRIPT_DIR/.." && pwd )"}"
SLICES_DIR="${SLICES_DIR:-"$WORKSPACE/out/ios/slices"}"
OUT_DIR="${OUT_DIR:-"$WORKSPACE/out/ios"}"

if [[ -n "${PYTORCH_VERSION:-}" ]]; then
  VERSION="$PYTORCH_VERSION"
elif [[ -f "$WORKSPACE/version.txt" ]]; then
  VERSION="$(tr -d '[:space:]' < "$WORKSPACE/version.txt")"
else
  echo "Error: PYTORCH_VERSION not set and $WORKSPACE/version.txt not found." >&2
  exit 1
fi

DEVICE_LIB="$SLICES_DIR/ios-arm64/libtorch_lite.a"
SIM_ARM64_LIB="$SLICES_DIR/ios-arm64-simulator/libtorch_lite.a"
SIM_X86_LIB="$SLICES_DIR/ios-x86_64-simulator/libtorch_lite.a"
HEADERS_DIR="$SLICES_DIR/include"

for required in "$DEVICE_LIB" "$SIM_ARM64_LIB"; do
  if [[ ! -f "$required" ]]; then
    echo "Error: missing required slice: $required" >&2
    exit 1
  fi
done
if [[ ! -d "$HEADERS_DIR" ]]; then
  echo "Error: missing headers directory: $HEADERS_DIR" >&2
  exit 1
fi

WORK="$OUT_DIR/xcframework-staging"
rm -rf "$WORK" "$OUT_DIR/LibTorchLite.xcframework"
mkdir -p "$WORK/simulator"

# Fold the Intel simulator slice in when it was built, so the framework works on
# Intel Macs too; skip it rather than fail when only Apple silicon was built.
if [[ -f "$SIM_X86_LIB" ]]; then
  echo "Merging simulator slices (arm64 + x86_64)"
  lipo -create "$SIM_ARM64_LIB" "$SIM_X86_LIB" -o "$WORK/simulator/libtorch_lite.a"
else
  echo "Note: no x86_64 simulator slice found; simulator support will be arm64 only" >&2
  cp "$SIM_ARM64_LIB" "$WORK/simulator/libtorch_lite.a"
fi

echo "Creating XCFramework"
xcodebuild -create-xcframework \
  -library "$DEVICE_LIB" -headers "$HEADERS_DIR" \
  -library "$WORK/simulator/libtorch_lite.a" -headers "$HEADERS_DIR" \
  -output "$OUT_DIR/LibTorchLite.xcframework"

echo "Slices in the resulting XCFramework:"
ls -1 "$OUT_DIR/LibTorchLite.xcframework"

pushd "$OUT_DIR" >/dev/null
ZIP_NAME="libtorch_lite_ios_xc_${VERSION}.zip"
rm -f "$ZIP_NAME"
zip -qr "$ZIP_NAME" LibTorchLite.xcframework
popd >/dev/null

rm -rf "$WORK"

echo "Done."
echo "XCFramework: $OUT_DIR/LibTorchLite.xcframework"
echo "Zip:         $OUT_DIR/$ZIP_NAME"
