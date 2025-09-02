#!/usr/bin/env bash
# Simple linear script to prepare iOS Cocoapods artifacts for LibTorch Lite (non-nightly)
# Location: scripts/build_ios_cocoapod.sh
#
# Inputs (optional):
#   WORKSPACE         - repo root; defaults to the grandparent folder of this script
#   BUILD_INSTALL_DIR - input install dir (default: $WORKSPACE/build_ios/install)
#   OUT_DIR           - output directory for pod artifacts (default: $WORKSPACE/out/ios)
#   PYTORCH_VERSION   - version string; if unset, will read from $WORKSPACE/version.txt

set -euo pipefail

# Resolve WORKSPACE to the grandparent of this script (i.e., repo root if placed under scripts/)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEFAULT_WORKSPACE="$( cd "$SCRIPT_DIR/.." && pwd )"
WORKSPACE="${WORKSPACE:-"$DEFAULT_WORKSPACE"}"

BUILD_INSTALL_DIR="${BUILD_INSTALL_DIR:-"$WORKSPACE/build_ios/install"}"
OUT_DIR="${OUT_DIR:-"$WORKSPACE/out/ios"}"

# Resolve version
if [[ -n "${PYTORCH_VERSION:-}" ]]; then
  VERSION="$PYTORCH_VERSION"
elif [[ -f "$WORKSPACE/version.txt" ]]; then
  VERSION="$(tr -d '[:space:]' < "$WORKSPACE/version.txt")"
else
  echo "Error: PYTORCH_VERSION not set and $WORKSPACE/version.txt not found." >&2
  exit 1
fi

echo "WORKSPACE=$WORKSPACE"
echo "BUILD_INSTALL_DIR=$BUILD_INSTALL_DIR"
echo "OUT_DIR=$OUT_DIR"
echo "VERSION=$VERSION"

# Validate inputs
if [[ ! -d "$BUILD_INSTALL_DIR" ]]; then
  echo "Error: BUILD_INSTALL_DIR does not exist: $BUILD_INSTALL_DIR" >&2
  exit 1
fi
if [[ ! -f "$WORKSPACE/ios/LibTorch-Lite.h" ]]; then
  echo "Error: Missing header: $WORKSPACE/ios/LibTorch-Lite.h" >&2
  exit 1
fi
if [[ ! -f "$WORKSPACE/ios/LibTorch-Lite.podspec.template" ]]; then
  echo "Error: Missing podspec template: $WORKSPACE/ios/LibTorch-Lite.podspec.template" >&2
  exit 1
fi
if [[ ! -f "$WORKSPACE/LICENSE" ]]; then
  echo "Error: Missing LICENSE at $WORKSPACE/LICENSE" >&2
  exit 1
fi

# Prepare destination
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/install/lib"
mkdir -p "$OUT_DIR/src"

# Copy headers, share, and libs
if [[ -d "$BUILD_INSTALL_DIR/include" ]]; then
  cp -R "$BUILD_INSTALL_DIR/include" "$OUT_DIR/install"
else
  echo "Warning: include/ not found under $BUILD_INSTALL_DIR" >&2
fi

if [[ -d "$BUILD_INSTALL_DIR/share" ]]; then
  cp -R "$BUILD_INSTALL_DIR/share" "$OUT_DIR/install"
else
  echo "Note: share/ not found under $BUILD_INSTALL_DIR (ok)" >&2
fi

# Copy static libraries if present
if compgen -G "$BUILD_INSTALL_DIR/lib/*.a" > /dev/null; then
  cp "$BUILD_INSTALL_DIR"/lib/*.a "$OUT_DIR/install/lib"/
else
  echo "Warning: No static libraries (*.a) found in $BUILD_INSTALL_DIR/lib" >&2
fi

# Copy src header (Lite only)
cp "$WORKSPACE/ios/LibTorch-Lite.h" "$OUT_DIR/src/"

# Copy LICENSE and write version.txt
cp "$WORKSPACE/LICENSE" "$OUT_DIR/"
echo "$VERSION" > "$OUT_DIR/version.txt"

# Generate podspecs (Lite only, non-nightly)
sed -e "s/IOS_BUILD_VERSION/${VERSION}/g" \
  "$WORKSPACE/ios/LibTorch-Lite.podspec.template" > "$OUT_DIR/LibTorch-Lite.podspec"

# Also produce a versioned spec alongside (handy for distribution/archival)
cp "$OUT_DIR/LibTorch-Lite.podspec" "$OUT_DIR/LibTorch-Lite-${VERSION}.podspec"

# Create the artifact zip (no nightly suffixes)
pushd "$OUT_DIR" >/dev/null
ZIP_NAME="libtorch_lite_ios_${VERSION}.zip"
zip -r "$ZIP_NAME" install src version.txt LICENSE >/dev/null
popd >/dev/null

# Verify the podspec locally: unzip the artifact and lint with local path source
TMP_SPEC_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'ltlite')"
cp "$OUT_DIR/LibTorch-Lite.podspec" "$TMP_SPEC_DIR/LibTorch-Lite.podspec"
unzip -q "$OUT_DIR/$ZIP_NAME" -d "$TMP_SPEC_DIR"

# In the temp spec, set s.source to use the local directory
sed -E -i '' "s|^[[:space:]]*s\\.source[[:space:]]*=.*$|    s.source           = { :path => '.' }|g" "$TMP_SPEC_DIR/LibTorch-Lite.podspec"

# Ensure cocoapods is available
if ! command -v pod >/dev/null 2>&1; then
  echo "CocoaPods not found; install by running: gem install cocoapods"
  exit 1
fi

echo "Running: pod lib lint $TMP_SPEC_DIR/LibTorch-Lite.podspec"
pod lib lint "$TMP_SPEC_DIR/LibTorch-Lite.podspec" --allow-warnings --use-libraries --skip-import-validation --verbose

echo "Done."
echo "Output directory: $OUT_DIR"
echo "Zip artifact:     $OUT_DIR/$ZIP_NAME"
echo "Podspecs:"
echo "  - $OUT_DIR/LibTorch-Lite.podspec"
echo "  - $OUT_DIR/LibTorch-Lite-${VERSION}.podspec"
