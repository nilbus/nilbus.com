# Agent Notes

## Real User Audio Acceptance Suite

`real-user-audio.acceptance.spec.js` is reserved for critical playback paths: any user-visible flow that starts, stops, changes, or restores actual tones/music playback or persisted playback state.

Keep this suite Chromium-only, serial, and unmocked for WebAudio and the real YouTube iframe. Prove tones by sampling PCM from `tonesMediaOutputDestination.stream`, and prove expected YouTube playback by observing the real iframe API state plus advancing `getCurrentTime()`.

Do not add lower-level or non-playback coverage here. Keep those in the mocked Playwright suite, including the `m` alias, playlist deletion, invalid URL styling, localStorage implementation details, wake lock behavior, Media Session metadata registration, generated URL formatting, and exhaustive parameter math.

Known/current playback bugs should remain as `test.fail` executable specs with an explicit reason until the product fix lands.
