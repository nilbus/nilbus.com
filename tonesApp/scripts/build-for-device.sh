#!/usr/bin/env bash
# Build and optionally install/launch BrainTones on a device.
# Scheme is "sticky" per device: once you install Kids on a device, that device
# defaults to BrainTones Kids for future builds. Adults is default for new devices.
#
# Usage:
#   ./scripts/build-for-device.sh <device_id> [scheme] [--launch]
#   scheme: "BrainTones" (adults) or "BrainTones Kids"; default = stored for device or adults
#   --launch: after build, launch the app on the device

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TONES_APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAP_FILE="$TONES_APP_DIR/device-scheme-defaults.json"
PROJECT="$TONES_APP_DIR/BrainTones.xcodeproj"

scheme_to_bundle_id() {
  case "$1" in
    "BrainTones") echo "com.nilbus.BrainTones" ;;
    "BrainTones Kids") echo "com.nilbus.BrainTonesKids" ;;
    *) echo "" ;;
  esac
}

# Parse args: device_id [scheme] [--launch]
DEVICE_ID="${1:-}"
SCHEME_OVERRIDE=""
LAUNCH=""
shift 2>/dev/null || true
for arg in "$@"; do
  if [[ "$arg" == "--launch" ]]; then
    LAUNCH=1
  elif [[ -n "$arg" && "$arg" != "--launch" ]]; then
    SCHEME_OVERRIDE="$arg"
  fi
done

if [[ -z "$DEVICE_ID" ]]; then
  echo "Usage: $0 <device_id> [scheme] [--launch]"
  echo "  scheme: BrainTones | 'BrainTones Kids' (default: sticky for device or adults)"
  echo "  --launch: launch app on device after build"
  echo ""
  echo "Available devices (use Identifier):"
  xcrun devicectl list devices 2>/dev/null | head -20
  exit 1
fi

# Resolve scheme: override > sticky for device > default (adults)
if [[ -n "$SCHEME_OVERRIDE" ]]; then
  SCHEME="$SCHEME_OVERRIDE"
else
  DEFAULT_SCHEME="BrainTones"
  if [[ -f "$MAP_FILE" ]]; then
    STORED=$(MAP_FILE="$MAP_FILE" DEVICE_ID="$DEVICE_ID" python3 -c "
import json, os
try:
    with open(os.environ['MAP_FILE']) as f:
        d = json.load(f)
    dev = os.environ.get('DEVICE_ID', '')
    print(d.get('devices', {}).get(dev, d.get('default_scheme', 'BrainTones')))
except Exception:
    print('BrainTones')
" 2>/dev/null || echo "BrainTones")
    SCHEME="${STORED:-BrainTones}"
  else
    SCHEME="$DEFAULT_SCHEME"
  fi
fi

BUNDLE_ID=$(scheme_to_bundle_id "$SCHEME")
if [[ -z "$BUNDLE_ID" ]]; then
  echo "Unknown scheme: $SCHEME (use 'BrainTones' or 'BrainTones Kids')"
  exit 1
fi

# App name on disk: both schemes produce BrainTones.app
APP_NAME="BrainTones.app"

DERIVED="$TONES_APP_DIR/build/Device"
APP_PATH="$DERIVED/Build/Products/Debug-iphoneos/$APP_NAME"

echo "Device: $DEVICE_ID | Scheme: $SCHEME | Bundle: $BUNDLE_ID"

cd "$TONES_APP_DIR"
# Build for generic iOS so we get a predictable .app path; then install via devicectl
# (xcodebuild -destination id=DEVICE can report success without actually installing)
if xcodebuild build -scheme "$SCHEME" -project "$PROJECT" -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" -quiet; then
  if [[ -d "$APP_PATH" ]]; then
    echo "Installing app to device..."
    if xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"; then
      # Make scheme sticky for this device
      MAP_FILE="$MAP_FILE" DEVICE_ID="$DEVICE_ID" SCHEME="$SCHEME" python3 -c "
import json, os
p = os.environ['MAP_FILE']
dev = os.environ['DEVICE_ID']
scheme = os.environ['SCHEME']
try:
    with open(p) as f:
        d = json.load(f)
except Exception:
    d = {}
d.setdefault('_comment', 'Maps device ID to scheme. New devices use default_scheme.')
d.setdefault('default_scheme', 'BrainTones')
d.setdefault('devices', {})
d['devices'][dev] = scheme
with open(p, 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || true
      echo "Installed; scheme for this device is now sticky: $SCHEME"
      if [[ -n "$LAUNCH" ]]; then
        xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
      fi
    else
      echo "Build succeeded but devicectl install failed. Try pairing/trusting the device and enabling Developer Mode."
      exit 1
    fi
  else
    echo "Build succeeded but app not found at $APP_PATH"
    exit 1
  fi
else
  exit 1
fi
