# Build, install, and launch the iOS app on the connected device

Run this workflow whenever the user invokes `/ios`. Use the project’s sticky device/scheme behavior so the correct app variant (adults or kids) is built for the device.

## Steps

1. **Find the connected device**
   - Run: `xcrun devicectl list devices`
   - Pick the first device whose **State** is `available` or `connected` (not `unavailable`). Prefer an iPhone or iPad over a Watch.
   - Use that row’s **Identifier** (UUID) as `DEVICE_ID`. If there are multiple available devices, prefer the one already in `tonesApp/device-scheme-defaults.json` so the sticky scheme is used; otherwise pick the first available iOS device.

2. **Build, install, and launch**
   - From the repo root, run:
     ```bash
     tonesApp/scripts/build-for-device.sh <DEVICE_ID> --launch
     ```
   - The script builds the app for that device (using the device’s sticky scheme if set, else adults), installs it, and launches it. Ensure the device is unlocked so the app can start.

3. **If something fails**
   - If the device is “unpaired” or “unavailable,” tell the user to pair/unlock it in Xcode (Window → Devices and Simulators) and enable Developer Mode on the device if prompted.
   - If build fails, report the xcodebuild error. Do not change signing settings.

Do not run generic/platform builds for this command; use the actual device ID so the app is installed and launched on the connected device.
