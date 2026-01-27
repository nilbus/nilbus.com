# Agent Workflow for Brain Tones

Thanks for helping on this project. Here's how to build, test, and launch the Brain Tones iOS app directly on the owner's device after every substantive change.

## Prerequisites
- Xcode 15 or newer installed.
- Access to the owner's iPhone ("Edward") which is already paired for development.
- The repo cloned locally (`tonesApp` contains the Xcode project).

## Build (Compile & Install on Device)

From the `tonesApp` directory:

```bash
xcodebuild build -scheme BrainTones -project BrainTones.xcodeproj -destination 'id=00008120-000E24910144A01E'
```

This compiles the app and installs it on the paired iPhone. The device must be unlocked.

## Test (Run Unit Tests on Device)

```bash
xcodebuild test -scheme BrainTones -project BrainTones.xcodeproj -destination 'id=00008120-000E24910144A01E'
```

Runs the full test suite on the physical device. Keep the phone unlocked so the test runner completes. Always ensure tests pass after modifications before handing off.

## Launch (Start the App on Device)

After building, launch the app using `devicectl`:

```bash
xcrun devicectl device process launch --device 00008120-000E24910144A01E com.nilbus.BrainTones
```

Alternatively, launch via Xcode:

1. Open `tonesApp/BrainTones.xcodeproj` in Xcode.
2. Select the **BrainTones** scheme and target device **Edward**.
3. Press **⌘R** to build and run (launches the app on the device).

## Combined Build + Test

To build and test in one go:

```bash
xcodebuild build -scheme BrainTones -project BrainTones.xcodeproj -destination 'id=00008120-000E24910144A01E' && \
xcodebuild test  -scheme BrainTones -project BrainTones.xcodeproj -destination 'id=00008120-000E24910144A01E'
```

## Notes
- The iOS bundle identifier (`com.nilbus.BrainTones`) is already signed with the owner's Apple ID. Do not change signing settings.
- The app ships with native S3 playlists; verify tone + music playback on the physical device.
- If `xcodebuild` warns that the device is locked or busy, unlock it and rerun the commands.
- Expect build + test to take ~60 seconds total on a typical machine.

Please document any deviations or known issues in your PR/commit notes to keep the workflow smooth for the next agent.
