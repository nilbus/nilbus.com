# Agent Workflow for Brain Tones

Thanks for helping on this project. Here's how to build, test, and launch the Brain Tones iOS app directly on the owner's device after every substantive change.

## Prerequisites
- Xcode 15 or newer installed.
- Access to the owner's iPhone ("Edward") which is already paired for development.
- The repo cloned locally (`tonesApp` contains the Xcode project).

## Targets (Adults vs Kids)

| Target | Scheme | Bundle ID | Logo | Presets |
|--------|--------|-----------|------|---------|
| **Adults** | BrainTones | com.nilbus.BrainTones | ba_logo.png | presets.json |
| **Kids** | BrainTones Kids | com.nilbus.BrainTonesKids | logo_kids.png | presets_kids.json |

**Sticky per device:** The scheme used for each device is stored in `device-scheme-defaults.json`. Once you install the Kids app on a device, that device defaults to the **BrainTones Kids** scheme for future builds. **Adults (BrainTones) is the default only for new devices** that have no stored preference. Use the `scripts/build-for-device.sh` script so the correct scheme is chosen automatically and updated after install.

## Build (Compile & Install on Device)

**Preferred:** Use the build script so the device’s sticky scheme is used and updated:

```bash
cd tonesApp
./scripts/build-for-device.sh <device_id> [scheme] [--launch]
```

- **device_id:** Use the **Identifier** from `xcrun devicectl list devices` (e.g. `21CA8C12-1659-54C9-BA7A-39E37287E044`). The script builds for generic iOS and installs via devicectl, so this id is required for install/launch to succeed.
- **scheme:** Optional. `BrainTones` (adults) or `BrainTones Kids`. If omitted, the script uses the stored scheme for that device, or BrainTones for new devices.
- **--launch:** After a successful build/install, launch the app on the device.

After a successful install, the chosen scheme is written to `device-scheme-defaults.json` for that device so future builds default to it.

**Manual (no sticky):** From the `tonesApp` directory:

```bash
# Adults
xcodebuild build -scheme BrainTones -project BrainTones.xcodeproj -destination 'id=<device_id>'

# Kids
xcodebuild build -scheme "BrainTones Kids" -project BrainTones.xcodeproj -destination 'id=<device_id>'
```

The device must be unlocked.

## Test (Run Unit Tests on Device)

```bash
xcodebuild test -scheme BrainTones -project BrainTones.xcodeproj -destination 'id=00008120-000E24910144A01E'
```

Runs the full test suite on the physical device. Keep the phone unlocked so the test runner completes. Always ensure tests pass after modifications before handing off.

## Launch (Start the App on Device)

After building, launch with `devicectl` using the bundle ID for the scheme you installed:

- **Adults:** `com.nilbus.BrainTones`
- **Kids:** `com.nilbus.BrainTonesKids`

```bash
xcrun devicectl device process launch --device <device_id> <bundle_id>
```

Or use the build script with `--launch` so it launches the app that was just installed.

Alternatively, launch via Xcode:

1. Open `tonesApp/BrainTones.xcodeproj` in Xcode.
2. Select the **BrainTones** scheme (adults) or **BrainTones Kids** scheme, and target device **Edward**.
3. Press **⌘R** to build and run (launches the app on the device).

## Combined Build + Test

To build and test in one go:

```bash
xcodebuild build -scheme BrainTones -project BrainTones.xcodeproj -destination 'id=00008120-000E24910144A01E' && \
xcodebuild test  -scheme BrainTones -project BrainTones.xcodeproj -destination 'id=00008120-000E24910144A01E'
```

## Notes
- The iOS bundle identifiers (`com.nilbus.BrainTones`, `com.nilbus.BrainTonesKids`) are signed with the owner's Apple ID. Do not change signing settings.
- The app ships with native S3 playlists; verify tone + music playback on the physical device.
- If `xcodebuild` warns that the device is locked or busy, unlock it and rerun the commands.
- Expect build + test to take ~60 seconds total on a typical machine.

Please document any deviations or known issues in your PR/commit notes to keep the workflow smooth for the next agent.
