# Technical Summary: Brainaural Brainwave Entrainment Application

## Overview
A web-based brainwave entrainment application that generates and mixes multiple audio layers (binaural beats, isochronic tones, bilateral stimulation) with YouTube playlist integration. The application uses Web Audio API for real-time audio synthesis and processing.

## Core Functionality

### 1. Audio Synthesis Engine
- **5 parallel audio generators** (TABS=5) that can operate independently or in multi-mode
- **Real-time audio generation** using Web Audio API:
  - Sine wave oscillators (left/right channels)
  - Low-frequency oscillators (LFO) for modulation
  - White noise generation with bandpass filtering
  - Frequency modulation (FM synthesis)
  - Gain control nodes for mixing
  - Channel merging for stereo output

### 2. Brainwave Entrainment Techniques
- **Binaural Beats**: Frequency difference between left/right channels (requires headphones)
- **Isochronic Tones**: Amplitude-modulated pulses (works on speakers)
- **Bilateral Stimulation**: Alternating left/right panning
- **Frequency Modulation**: Dynamic carrier frequency modulation
- **Noise Mixing**: Optional filtered white noise

### 3. Preset System
- **10 predefined presets** loaded from `preset_data.js`
- Each preset contains 2-4 layers with:
  - Modulation frequency (Hz) - determines brainwave state (Delta, Theta, Alpha, Beta, Gamma)
  - Carrier frequency (Hz) - base tone frequency
  - Volume levels
  - Output type adaptation (headphones vs speakers)
- **Dynamic parameter generation** based on output device type
- **Preset buttons** with visual feedback (active state)

### 4. YouTube Integration
- **YouTube IFrame API** for playlist playback
- **Playlist management**:
  - Save/load playlists from localStorage
  - Recent playlists list with custom names
  - Playback state persistence (video index + playback time)
  - Auto-save every 29 seconds
  - Restore playback position on app reload
  - Playlist looping (restarts from beginning when last video ends)

### 5. Media Session API
- **System media controls** integration (lock screen, notification controls)
- **Metadata display** (title, artist, album, artwork)
- **Play/pause/stop handlers** for OS-level media controls
- **Silent audio anchor** workaround for browser compatibility

### 6. Screen Wake Lock
- **Prevents screen sleep** during playback
- **Visual indicator** when active
- **Auto-reacquire** on visibility change

## Key Technologies & APIs

### Browser APIs (Critical Dependencies)
1. **Web Audio API** (`AudioContext`, `OscillatorNode`, `GainNode`, `BiquadFilterNode`, `ChannelMergerNode`)
   - Real-time audio synthesis
   - Low-latency audio processing
   - Audio graph routing

2. **Media Session API** (`navigator.mediaSession`)
   - System media controls
   - Lock screen integration

3. **Screen Wake Lock API** (`navigator.wakeLock`)
   - Keep screen awake during playback

4. **localStorage API**
   - Persistent state storage
   - Playlist management
   - Playback position tracking

5. **YouTube IFrame API**
   - External dependency: `https://www.youtube.com/iframe_api`
   - Playlist playback control

### JavaScript Libraries
- **jQuery** (DOM manipulation, event handling)
- **jQuery UI** (slider widgets - though sliders appear unused in current preset-based UI)
- **jQuery UI Touch Punch** (touch support for sliders)
- **Mousetrap** (keyboard shortcuts: 'm' and spacebar for play/pause)

## Audio Processing Architecture

### Audio Graph Structure (per generator)
```
OscillatorL → OscGainL → GainL ┐
                                 ├→ ChannelMerger → GainI → GainGlobal → Destination
OscillatorR → OscGainR → GainR ┘

LFO → LfoGain → GainI (for isochronic modulation)
LFOHalf → BilatGain → BilatInvertedGain → GainL/GainR (for bilateral)

NoiseL → NoiseGainL → FilterL → GainL
NoiseR → NoiseGainR → FilterR → GainR

LFO → FmGain → OscillatorL/R.frequency (FM synthesis)
LFO → FilterGain → FilterL/R.frequency (dynamic filtering)
```

### Real-time Parameter Control
- **Frequency modulation**: Direct oscillator frequency updates
- **Gain control**: Real-time volume adjustments
- **Filter modulation**: Dynamic bandpass filter frequency changes
- **Safari compatibility**: Uses `setTargetAtTime()` instead of direct value assignment

## State Management

### Global State Variables
- Audio context state (suspended/running)
- Current preset and output type
- Playback state (paused/playing)
- YouTube player state
- Wake lock state

### Persistent Storage (localStorage)
- `youtube_playlist_id`: Current playlist ID
- `youtube_playlist_url`: Current playlist URL
- `youtube_playlist_states`: Object mapping playlist IDs to playback states
- `youtube_recent_playlists`: Array of saved playlists with metadata

## UI Components

### Preset Grid
- Dynamic button generation from preset data
- Two buttons per preset (headphones/speakers)
- Purpose text display
- Active state highlighting

### YouTube Controls
- Playlist URL input field
- Save button
- Recent playlists list with delete functionality
- Embedded YouTube player (hidden, audio-only)

### Control Buttons
- Mute/play toggle button
- External link to brainaural.com

## Browser-Specific Considerations

### iOS Autoplay Prevention
- Audio context starts in "suspended" state
- Requires user interaction to resume
- Explicit `context.resume()` calls

### Safari Compatibility
- Uses `webkitAudioContext` fallback
- Frequency changes use `setTargetAtTime()` instead of direct assignment
- Special handling for audio context state

### Audio Context Lifecycle
- Lazy initialization on first user interaction
- Suspension/resumption handling
- State synchronization with UI

## Challenges for Native Mobile Reproduction

### ✅ Feasible Components
1. **Audio Synthesis**: Native audio frameworks available (AVAudioEngine on iOS, AudioTrack/OpenSL ES on Android)
2. **Preset System**: Simple data structure, easily portable
3. **State Management**: Standard patterns, can use any state management solution
4. **UI Components**: Standard mobile UI components available
5. **localStorage equivalent**: Native storage APIs (UserDefaults, SharedPreferences, AsyncStorage)

### ⚠️ Moderate Complexity
1. **YouTube Integration**:
   - Native: YouTube Data API v3 + AVPlayer/MediaPlayer
   - Alternative: YouTube IFrame Player API in WebView (hybrid approach)
   - Challenge: Playlist playback state management

2. **Media Session API**:
   - iOS: MPNowPlayingInfoCenter, MPRemoteCommandCenter
   - Android: MediaSession, MediaMetadata
   - Challenge: Platform-specific implementations

3. **Screen Wake Lock**:
   - iOS: `UIApplication.shared.isIdleTimerDisabled`
   - Android: `WakeLock` API
   - Challenge: Platform-specific APIs

### 🔴 Significant Challenges
1. **Web Audio API → Native Audio**:
   - **iOS**: AVAudioEngine with AVAudioUnitGenerator, AVAudioUnitSourceNode
   - **Android**: AudioTrack, OpenSL ES, or Oboe library
   - **Challenge**: Different API paradigms, requires significant audio graph reimplementation
   - **Complexity**: Real-time parameter modulation, audio routing, low-latency requirements

2. **Real-time Audio Processing**:
   - Native audio frameworks have different threading models
   - Buffer management differs significantly
   - Latency characteristics vary by platform

3. **Cross-platform Audio Consistency**:
   - Ensuring identical audio output across iOS/Android
   - Different sample rates, buffer sizes
   - Platform-specific audio optimizations

## Recommendations for Native Port

### Framework Considerations
- **React Native**:
  - ✅ Good UI framework
  - ⚠️ Audio: Use `react-native-audio` or `react-native-sound` (limited), or native modules
  - ⚠️ YouTube: WebView or native YouTube SDK

- **Flutter**:
  - ✅ Good UI framework
  - ✅ Audio: `just_audio`, `audioplayers`, or `flutter_sound` packages
  - ⚠️ YouTube: WebView or `youtube_player_flutter`

- **NativeScript**:
  - ✅ Direct native API access
  - ✅ Audio: Native AVAudioEngine/AudioTrack access
  - ⚠️ YouTube: Native SDKs or WebView

- **Capacitor/Ionic**:
  - ✅ Can embed web version with minimal changes
  - ✅ Web Audio API works in WebView
  - ⚠️ Performance may be suboptimal

### Critical Implementation Requirements
1. **Low-latency audio engine** with real-time parameter control
2. **Multi-channel audio mixing** (5 parallel generators)
3. **Precise timing** for brainwave entrainment (millisecond accuracy)
4. **Background audio playback** support
5. **System media controls** integration
6. **YouTube playlist playback** with state persistence

## Conclusion

**Reproducibility Assessment**: **FEASIBLE but requires significant audio engine reimplementation**

The application's core audio synthesis logic can be ported to native mobile, but requires:
- Platform-specific audio framework implementation
- Careful attention to audio latency and timing
- Native media session integration
- YouTube integration strategy (native SDK vs WebView)

The preset system, UI, and state management are straightforward to port. The main complexity lies in recreating the Web Audio API audio graph using native audio frameworks while maintaining the same audio characteristics and low-latency performance.
