# Agent Workflow for Brain Tones

Thanks for helping on this project. Here’s how to build and run the Brain Tones iOS app directly on the owner’s device after every substantive change.

## Prerequisites
- Xcode 15 or newer installed.
- Access to the owner’s iPhone (“Edward”) which is already paired for development.
- The repo cloned locally (`tonesApp` contains the Xcode project).

## Build & Run on Device
1. From the repo root:
   ```bash
   cd tonesApp
   xcodebuild build -scheme BrainTones -project BrainTones.xcodeproj -destination 'id=00008120-000E24910144A01E'
   xcodebuild test  -scheme BrainTones -project BrainTones.xcodeproj -destination 'id=00008120-000E24910144A01E'
   ```
   The first command installs the updated app onto the iPhone. The second runs the full test suite on that device; keep it unlocked so the run completes.

2. If you prefer Xcode’s UI, open `tonesApp/BrainTones.xcodeproj`, select the **BrainTones** scheme, choose the device named **Edward**, and press **⌘R** (build/run) followed by **⌘U** (tests).

3. Always ensure the tests complete successfully after modifications before handing off.

## Notes
- The iOS bundle identifier (`com.nilbus.BrainTones`) is already signed with the owner’s Apple ID. Do not change signing settings.
- The app now ships with native S3 playlists; verify tone + music playback on the physical device.
- If `xcodebuild` warns that the device is locked or busy, unlock it and rerun the commands.

Please document any deviations or known issues in your PR/commit notes to keep the workflow smooth for the next agent.
