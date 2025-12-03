# Strategy: Replace YouTube Embedding with First-Party Audio Streaming

## Goal
Deliver a combined Brain Tones + music experience without relying on the embedded YouTube player, so that both audio sources can run simultaneously and reliably under our own `AVAudioSession` control. We will stream curated playlists from our own storage (e.g., Amazon S3) and play them alongside the tone engine using native Apple APIs.

## Why this change
- YouTube’s iframe player (via `YTPlayerView`) repeatedly reconfigures `AVAudioSession` to an exclusive category, muting the tone engine. Even with a coordinator façade, playback toggles between the two sources.
- Ownership of the audio pipeline solves mixing, background audio, and remote-control interoperability, and opens the door to offline caching and more predictable UX.

## Target architecture
1. **Media catalog & metadata**
   - Playlist audio files (mp3) are hosted in an S3 bucket.
   - Hard-code the list of playlists in a project JSON file, with each playlist containing tracks and titles. The user is no longer able to add their own playlists.

2. **App data model**
   - Define `AudioTrack` (id, title, duration, remoteURL, localURL?).
   - Define `AudioPlaylist` (id, title, [AudioTrack], defaultStartIndex).
   - Update persistence (`SettingsStore`) to keep: current playlist id, active track index, local cache state, last playback position, recents.

3. **Networking & caching layer**
   - Create `MusicCatalogService` responsible for manifest downloads and refreshing metadata.
   - Add `TrackDownloadManager` to download audio files, manage progress, and store them in `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)` using a predictable naming scheme (trackID + hash).
   - Maintain a mapping from track ids to local file URLs in persistence so playback can fall back to remote streaming if local file missing.
   - The app downloads audio files to and plays from Library/Caches/ so that they are not persisted to backups.
   - Any track requested should be downloaded, plus, after the playing track is downloaded, one subsequent track, so that advancing tracks will not block on download. The next subsequent will download after advancing tracks. After initial install when the cache is empty, the first track should start downloading immediately, because it is assumed to be the next track to play.

4. **Playback engine**
   - Use `AVQueuePlayer` (or `AVAudioPlayerNode` in our existing `AVAudioEngine`) for playlist playback.
   - Each track node will be created from local file if available; otherwise stream from remote URL (with `AVURLAsset` + `AVPlayerItem`).
   - Implement gapless or crossfade later if desired; start with sequential playback.
   - Handle interruptions and `AVAudioSession` setup via our existing `AudioSessionManager.configureForPlayback()`.

5. **Playback coordinator updates**
   - Extend `MediaPlaybackCoordinator` to work with the new `MusicPlaybackController` (instead of YouTube).
   - Methods needed: `play()`, `pause()`, `seek(to:)`, `skipForward()`, `skipBackward()`, plus metadata reporting to `NowPlayingManager`.
   - Ensure coordinator updates `NowPlayingManager` with playlist & track details (title) along with tone preset info.

6. **UI adjustments**
   - Replace the WebView player UI with a native SwiftUI component:
     - On initial play of a track, show a status indicator (a filling ring, like the Podcasts app) to show download progress.
     - Show current track title.
     - Provide transport controls (play/pause, next, previous, scrubber) bound to the new playback controller.
     - Provide playlist list + ability to select track.
   - Update playlist management UI to use S3 manifests (URL entry may now accept direct JSON playlist URLs or choose predefined catalog).

7. **Persistence & auto-save**
   - Migrate existing playlist state persistence to new track-based structure.
   - Auto-save current track index and playback time at an interval (same 29sec timer) or on app backgrounding.
   - Maintain recents and custom naming similar to current YouTube implementation.

8. **Testing strategy**
   - Unit tests for `MusicCatalogService`, download manager, playback controller (simulate track list, ensure state changes, persistence updates).
   - Integration test exercising coordinator to ensure tones + music play concurrently without toggling.
   - UI tests (optional) verifying native controls respond as expected.

9. **Migration steps**
   1. Introduce new data models and services alongside existing YouTube code.
   2. Build native playback controller and integrate with `MediaPlaybackCoordinator` (keep YouTube active until new flow works).
   3. Replace YouTube view in SwiftUI with the new native player UI.
   4. Remove YouTube-specific code and tests once parity achieved.
   5. Update documentation, QA on device (Edward), confirm remote controls & background audio behave correctly.

10. **Considerations**
    - When a playlist is deleted, purge any of its cached downloads.

11. **Initial Playlist**
   - Initially, the app will ship with only one playlist, "AllieSpaces", with these tracks (track name inferred from filename without extension):
      1. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/1+Chillout+Ambient.mp3
      2. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/2+Allie's+Dream.mp3
      3. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/3+The+dream+of+an+AI+Mind.mp3
      4. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/4+Relaxing+Yoga.mp3
      5. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/5+Waves.mp3
      6. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/6+Astronaut.mp3
      7. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/7+Rain.mp3
      8. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/8+ADHD.mp3
      9. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/9+Quiet+Depths.mp3
      10. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/10+Focus+Rain.mp3
      11. https://nilbus-podcasts.s3.us-east-2.amazonaws.com/AllieSpaces/11+Distant+Planet.mp3

This strategy gives a clean, fully controllable audio pipeline, allowing Brain Tones and music to run through one AVAudioSession without interference from a third-party web player.
