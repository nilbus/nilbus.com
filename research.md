# Audio Session & YouTube Mixing Notes

## AVAudioSession behaviour
- Apple’s archived *Audio Session Programming Guide* explains that `AVAudioSessionCategoryPlayback` normally interrupts other audio sources, but setting the option `AVAudioSessionCategoryOptionMixWithOthers` overrides this so multiple sources may play simultaneously.
- Keeping the session active and consistent matters; Apple recommends configuring the session once, then only changing category/options deliberately. Every subsystem that might reconfigure the session (e.g. embedded YouTube) must funnel changes through one controller so the OS sees a single, stable “audio intention”.
- When the system interrupts or silences secondary audio (notifications `AVAudioSessionInterruptionNotification`, `AVAudioSessionSilenceSecondaryAudioHintNotification`), apps are expected to restart audio if they still intend to play. QA1749 reiterates the need to rebuild/restart audio graphs after resets.

## Coordinated façade idea
- The web app’s `mediaSessionAnchor` pattern is a good reference: one coordinator owns play/pause, playlist state, and Media Session metadata, while delegating to Web Audio + YouTube beneath it. iOS can mirror this by creating a Swift coordinator that:
  1. Manages a shared `AVAudioSession` (`.playback` + `.mixWithOthers`).
  2. Drives both `ToneEngine` and `YTPlayerView` through a single play/pause/seek API.
  3. Updates `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter` so the OS perceives one logical player, simplifying remote control and background behaviour.

## Remaining considerations
- Embedded `YTPlayerView` still hosts an iframe in `WKWebView`; Apple documentation doesn’t expose hooks to stop it from touching the session. Practical approach is to reassert our desired configuration (option + active state) after every state change and on interruptions.
- If mixing success continues to vary, the fallback (per Apple defaults) is to treat tones + YouTube as mutually exclusive. The unified façade makes this simpler: pausing both from one place is trivial if we need to revert.
