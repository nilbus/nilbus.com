# Product Requirements Document: Brain Tones iOS App

## 1. Executive Summary

**Product Name:** Brain Tones
**Platform:** iOS (Native Swift/SwiftUI)
**Version:** 1.2
**Date:** 2026-01-25

Brain Tones is an iOS application that generates binaural and isochronic audio tones designed to enhance cognitive states (focus, relaxation, creativity, etc.). The app combines tone presets with curated audio playlists streamed from S3 storage, allowing users to layer brainwave entrainment audio over music or ambient sounds through a unified native audio pipeline.

## 2. Product Overview

### 2.1 Purpose
Brain Tones enables users to:
- Play scientifically-designed audio tones for cognitive enhancement
- Combine tones with curated audio playlists for personalized audio experiences
- Switch between headphones and speaker output modes with optimized parameters
- Maintain playback state across app sessions
- Play the tracks offline becuase they are cached

### 2.2 Target Users
- Individuals seeking enhanced focus, relaxation, or productivity
- Users who want to combine brainwave entrainment with music
- People who prefer iOS-native experiences over web-based solutions

## 3. Core Features

### 3.1 Tone Preset System

#### 3.1.1 Preset Library
- **Requirement:** The app must load and display a library of tone presets from bundled JSON (`presets.json`)
- **Preset Structure:** Each preset contains:
  - Name (e.g., "Focused & Sustainable Work", "Procrastination Crusher")
  - Multiple tone layers (typically 2-4 layers per preset)
  - Each layer includes:
    - Modulation frequency (`freq`)
    - Carrier frequency settings (separate for headphones/speakers)
    - Tone type: `binaural` or `isochronic`
    - Volume settings (separate for headphones/speakers)
    - Purpose description (e.g., "Cognitive sharpness", "Mental energy")

#### 3.1.2 Preset Selection & Activation
- **Requirement:** Users can select and activate presets via UI
- **Behavior:**
  - Tapping a non-active preset activates it immediately
  - Tapping an active preset acts just as pressing pause
  - Preset selection persists across app launches
  - Last selected preset is restored on app restart
  - Each preset's headphones and speakers modes act as distinct presets
- **Initial Use Default:** On first app launch (no saved preset), the default "last played" preset is the first preset in speakers mode

#### 3.1.3 Preset Display
- **Requirement:** Presets must display:
  - Preset name
  - Combined purposes from all layers (comma-separated)
  - Visual indicators for active state
  - Separate activation buttons for headphones and speakers modes

### 3.2 Output Mode System

#### 3.2.1 Output Modes
- **Requirement:** Support two output modes:
  - **Headphones Mode:** Optimized for stereo binaural beats
  - **Speakers Mode:** Optimized for mono-compatible isochronic tones

#### 3.2.2 Mode-Specific Parameters
- **Requirement:** Each preset layer must provide different parameters based on output mode:
  - **Binaural layers:**
    - Headphones: Full binaural effect (100% binaural level, 0% isochronic)
    - Speakers: Disabled binaural effect (0% binaural level, 100% isochronic)
  - **Carrier frequencies:** Can differ between modes (e.g., "240/220" format = headphones/speakers)
  - **Volume levels:** Can differ between modes (e.g., "80/65" format = headphones/speakers)

#### 3.2.3 Mode Persistence
- **Requirement:** Selected output mode must persist in UserDefaults
- **Default:** Headphones mode
- **Behavior:** Mode selection persists across app sessions

### 3.3 Tone Engine

#### 3.3.1 Engine Configuration
- **Requirement:** Tone engine must configure based on:
  - Selected preset
  - Output mode (headphones/speakers)
  - Layer parameters (frequency, carrier, volume, binaural/isochronic levels)

#### 3.3.2 Playback Control
- **Requirement:** Engine must support:
  - Start playback
  - Pause playback
  - Stop playback
  - Query running state (`isRunning`)

#### 3.3.3 Engine Lifecycle
- **Requirement:**
  - Engine is shared singleton instance
  - Playback does not start automatically on app launch
  - Playback must be explicitly started by the user
  - Engine state persists during app lifecycle

### 3.4 Audio Playlist Integration

#### 3.4.1 Playlist Catalog
- **Requirement:** App loads playlists from bundled JSON manifest:
  - Playlists are hard-coded in project JSON file (no user-added playlists)
  - Each playlist contains metadata: id, title, defaultStartIndex, track list
  - Tracks include id, title, optional duration, and remoteURL (hosted on Amazon S3)
  - Initial playlist: "AllieSpaces" with 11 tracks (only one playlist for now, but designed for multiple)

#### 3.4.2 Playlist Loading & Display
- **Requirement:** Loaded playlist must display:
  - Playlist title
  - Track count
  - List of tracks with titles (inferred from filename if not specified in metadata)
  - Current track indicator
  - Error messages for network failures
  - Track duration shown only when available; otherwise omitted

#### 3.4.3 Track Download & Caching
- **Requirement:** Download management system:
  - **Storage Location:** Files stored in `Library/Caches/BrainTonesMusicDownloads/` (not backed up, may be purged by system, not backed up to iCloud)
  - **Naming Scheme:** Sanitized track ID (with `/` replaced by `-`) + `.mp3` extension
  - **Fallback:** If local file missing, stream from remote URL
  - **Playback Priority:** Play from local cache when available; only stream when track is not downloaded. After a playing track's download completes, automatically switch from playing the stream to playing the downloaded file at the same playback location.
  - **Download Strategy:**
    - Current playing track downloads immediately if not cached
    - The next track in the queue downloads (if not already downloaded) after the current track completes its download
    - Download of the next track continues sequentially as tracks advance
  - **Cache Mapping:** Track ID to cached file name mapping persisted in UserDefaults
  - **Download Status:** Track download state (not downloaded, downloading, downloaded) exposed for UI display
  - **Display:** Download state for each track is shown right-aligned on each track in the list. While downloading, a ring progress indicator shows the progress for that track. The download progress ring is NOT also shown next to where the currently playing track name is displayed. Other non-ring icons symbolize "not downloaded" and "downloaded".

#### 3.4.4 Playlist State Management
- **Requirement:** Each playlist maintains playback state:
  - Current track index (0-based)
  - Playback time within current track (seconds, double precision)
  - State persists per playlist ID
  - Per-track playback positions persist per track ID (used when selecting a track)
  - Cache state (which tracks are downloaded) persists per track

#### 3.4.5 Playback State Persistence
- **Requirement:** Playback state must be saved:
  - **On pause:** Immediately save current track index and playback time
  - **During playback:** Auto-save every 29 seconds via timer
  - **On playlist switch:** Save outgoing playlist state before loading new one
  - **On track end:** Advance to next track, save new state
  - **On track selection:** Save outgoing track state before switching
  - **On app restart:** Restore last active playlist and its saved state

#### 3.4.6 Playlist Restoration
- **Requirement:** On app launch:
  - Restore last active playlist ID from settings
  - Load playlist metadata from bundled catalog
  - Restore saved playback state (track index and playback time)
  - Check cache status for tracks
  - If no saved state exists, start from beginning (index 0, time 0)
  - Do not auto-play on restoration (user must explicitly start)

### 3.5 Media Playback Coordination

#### 3.5.1 Dual Playback System
- **Requirement:** App must coordinate two independent audio sources:
  - **Tones:** Generated audio tones from ToneEngine
  - **Music:** Audio playlist playback
  - Both sources run through unified AVAudioSession for seamless mixing
- **Auto-Start Tones:** When music playback is started, the last played tone preset automatically starts playing as well (tones and music play together by default)
- **Auto-Start Music:** When tones are is started, the last played playlist automatically starts playing as well (tones and music play together by default)
- **Allow pausing Music without Tones:** The track play/pause button can pause music without pausing tones. (Tones, however, are always present if anything is playing.)

#### 3.5.2 Playback Intent Management
- **Requirement:** System must track desired playback state:
  - `desiredTonesPlaying`: Whether tones should be playing
  - `desiredMusicPlaying`: Whether music playlist should be playing
  - Intent persists when playback is paused via external controls

#### 3.5.3 Global Playback Controls
- **Requirement:** Support unified playback control:
  - **Play:** Resume the last played tone preset and last played track (at its saved playback position). Both tones and music start together.
  - **Pause All:** Pause both sources while remembering intent—this is triggered by tapping an active tone preset, the global play/pause button, or through external iOS controls
  - **Pause Music:** Pause the music source; update intent—this is triggered by the in-app visual pause button between the Skip Forward/Back buttons
  - **Skip Forward:** Advance to next track in playlist
  - **Skip Backward:** Return to previous track in playlist
  - **Seek:** Scrub to specific time position in current track
  - **Toggle:** The Play and Pause Pause Music buttons replace each other, switching based on playback state

#### 3.5.4 External Control Integration
- **Requirement:** Integrate with iOS media controls:
  - Lock screen controls (play/pause, skip forward/backward, seek)
  - Control Center controls
  - Now Playing metadata display

#### 3.5.5 Now Playing Metadata
- **Requirement:** Display metadata in Now Playing:
  - **Title:** Uses track title when available; otherwise falls back "Brain Tones"
  - **Artist:** Preset name
  - **Album:** Playlist title

### 3.6 Settings Persistence

#### 3.6.1 UserDefaults Storage
- **Requirement:** All settings must persist in UserDefaults, e.g.:
  - `outputMode`: Current output mode (headphones/speakers)
  - `lastPresetName`: Name of last selected preset
  - `currentPlaylistId`: Currently active audio playlist ID
  - `playlistStates`: Dictionary mapping playlist IDs to playback states (track index, playback time)
  - `recentPlaylists`: Array of recent playlist entries (max 20)
  - `cachedTrackFileNames`: Dictionary mapping track IDs to cached file names
  - `trackPlaybackPositions`: Dictionary mapping track IDs to last playback positions

#### 3.6.2 Settings Store
- **Requirement:** Centralized settings management:
  - Observable object for SwiftUI binding
  - Automatic persistence on value changes
  - Codable support for complex types

## 4. User Interface Requirements

### 4.1 Main Screen Layout
- **Header Section:**
  - App logo and branding ("BrainTones")
  - Global play/pause button

- **Tone Presets Section:**
  - Section title: "Tone Presets"
  - List of available presets
  - Each preset shows:
    - Name and purposes
    - Headphones activation button
    - Speakers activation button
    - Visual active state indicator

- **Music Playlists Section:**
  - Section title: "Music Playlists"
  - Playlist selection menu (from bundled catalog)
  - Current playlist info (if loaded):
    - Playlist title
    - Track count
  - Native player UI:
    - Track title
    - Track number
    - Transport controls: play/pause, skip forward, skip backward
    - Scrubber bar for seeking within track
    - Track list with current track indicator
  - Recent playlists list
  - Error message display for catalog load failures
  - Empty-state message if no playlists are available

### 4.2 Visual Design
- **Color Scheme:**
  - Deep black gradient background with subtle dark red undertones
  - Accent colors: Primary (#E53935, vibrant red), Secondary (#FF8C00, amber/orange glow)
  - White text with opacity variations
  - Glowing ember effects for interactive elements (subtle red/orange particle aesthetic)

- **Typography:**
  - System fonts with weight variations
  - Brand wordmark: 28pt bold, tagline: 18pt medium
  - Section titles: 22pt semibold
  - Preset names: 18pt semibold
  - Body text: 14-15pt regular

- **Layout:**
  - Responsive padding (16px on small screens, 32px on larger)
  - Rounded corners (14-18px radius)
  - Card-based preset display
  - Grid layout for mode buttons

### 4.3 Interaction Patterns
- **Preset Activation:** Tap headphones/speakers button to activate preset or deactivate the active one
- **Playback Control:** Tap global play/pause button
- **Track Playback Control:** Tap playlist play/pause button
- **Playlist Selection:** Select playlist from catalog
- **Track Selection:** Tap track in list to jump to that track
- **Transport Controls:** Use native player controls (play/pause, skip, seek)
- **Recent Playlist:** Tap "Load" button on recent entry

## 5. Technical Requirements

### 5.1 Architecture
- **Framework:** SwiftUI with MVVM pattern
- **Language:** Swift 5.9+
- **iOS Target:** iOS 17.0+
- **Dependencies:**
  - AVFoundation for audio generation and playback
  - Amazon S3 for audio file hosting
  - URLSession for network requests and file downloads

### 5.2 Audio Engine
- **Tone Generation:** AVAudioEngine with custom tone generation
  - Real-time audio synthesis
  - Multiple concurrent tone layers per preset
  - Stereo for headphones, mono-compatible for speakers
- **Music Playback:** AVPlayer
  - Sequential track playback with automatic advancement
  - Support for local cached files and remote streaming
  - Unified AVAudioSession configuration for mixing tones and music

### 5.3 Data Models
- **Preset:** Codable struct with layers array
- **ToneLayer:** Contains frequency, carrier, type, volume, purpose
- **OutputMode:** Enum (headphones, speakers)
- **AudioTrack:** Codable struct (id, title, duration?, remoteURL, localURL?)
- **AudioPlaylist:** Codable struct (id, title, defaultStartIndex, tracks: [AudioTrack])
- **MusicPlaybackState:** Codable struct (playlistId, trackIndex, playbackTime)
- **MusicRecentPlaylist:** Codable struct (playlistId, customName?, lastPlayedAt)
- **Cached Track Map:** Dictionary (trackId -> cached file name)
- **Track Playback Positions:** Dictionary (trackId -> playbackTime)

### 5.4 State Management
- **ViewModels:** ObservableObject classes
  - `BrainTonesViewModel`: Manages preset selection and tone playback
  - `MusicPlayerViewModel`: Manages playlist selection and track display
- **Services:** Singleton classes
  - `MusicCatalogService`: Loads playlist manifests and metadata
  - `TrackDownloadManager`: Actor handling track downloads, caching, and progress tracking
- **Controllers:** Classes
  - `MusicPlaybackController`: Manages AVPlayer playback, track navigation, seeking
- **Stores:** ObservableObject classes
  - `PresetStore`: Loads and provides presets
  - `SettingsStore`: Manages persistent settings
- **Coordinators:** Singleton classes
  - `MediaPlaybackCoordinator`: Coordinates dual playback system (tones + music)

### 5.5 Testing Requirements
- **Unit Tests:** All ViewModels, Services, Controllers, and Stores must have test coverage
- **Integration Tests:** Tone engine configuration, music playback, and coordinated playback
- **Test Coverage Areas:**
  - Preset decoding and parameter generation
  - Settings persistence
  - Playlist catalog loading
  - Track download and caching
  - Playlist state management
  - Playback coordination (tones + music simultaneously)
  - Playlist restoration
  - Cache management and cleanup

## 6. Performance Requirements

### 6.1 Audio Performance
- **Latency:** No explicit instrumentation; target is quick start after user action
- **CPU Usage:** No enforced limits in code
- **Battery:** Best-effort, no explicit optimization checks

### 6.2 UI Performance
- **Frame Rate:** No explicit performance instrumentation
- **Load Time:** Best-effort, no measured requirement in code
- **Memory:** No enforced limits in code

## 7. Error Handling

### 7.1 Preset Loading Errors
- **Requirement:** Handle invalid or missing preset JSON gracefully
- **Behavior:** Log error to console and continue with an empty preset list (no user-facing error UI)

### 7.2 Network & Download Errors
- **Requirement:** Handle network failures, download errors, and invalid playlist data
- **Behavior:**
  - Display user-friendly error message in playlist section
  - Retry failed downloads automatically
  - Fall back to remote streaming if cached file unavailable
  - Log download and file system errors to console

### 7.3 Audio Engine Errors
- **Requirement:** Handle audio session configuration failures and playback errors
- **Behavior:**
  - Log error, disable playback, show user notification
  - Handle audio file format errors gracefully
  - Recover from interrupted playback sessions

## 8. Accessibility Requirements

### 8.1 VoiceOver Support
- **Requirement:** Key interactive elements have accessibility labels
- **Labels:** Descriptive labels for preset buttons and download status icons

### 8.2 Dynamic Type
- **Requirement:** No explicit Dynamic Type support beyond standard SwiftUI font usage

## 9. Success Metrics

### 9.1 Functional Metrics
- All test cases pass (100% test suite success rate)
- Zero crashes during normal usage
- Settings persist correctly across app restarts
- Playback state restores accurately for playlists and per-track positions

### 9.2 User Experience Metrics
- Preset activation responds immediately (best-effort)
- Playlist loading completes quickly from bundled catalog
- Track download starts immediately when track selected
- Playback coordination works seamlessly (tones + music simultaneously)
- Now Playing metadata displays correctly
- Download progress indicator updates smoothly

## 10. Future Enhancements (Out of Scope)

- Custom preset creation
- User-added playlists (currently hard-coded catalog only)
- Offline mode indicator
- iPad-optimized layout

## 11. Dependencies

### 11.1 External Services
- **Amazon S3:** Hosts audio files (MP3 format) for playlists
  - Bucket: `nilbus-podcasts.s3.us-east-2.amazonaws.com`
  - Public read access for audio files
  - No authentication required for file downloads

### 11.2 System Frameworks
- AVFoundation (AVAudioEngine, AVQueuePlayer, AVAudioSession)
- SwiftUI
- Combine
- Foundation (URLSession, FileManager)

## 12. Testing Strategy

### 12.1 Test Execution
- Tests run on physical iOS device ("Edward")
- All tests must pass before deployment
- Test suite executed via Xcode or xcodebuild command line

---

**Document Version:** 1.2
**Last Updated:** 2026-01-25
