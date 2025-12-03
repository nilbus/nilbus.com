import SwiftUI

struct ContentView: View {
    @StateObject private var tonesViewModel = BrainTonesViewModel()
    @StateObject private var musicViewModel = MusicPlayerViewModel()
    @Environment(\.openURL) private var openURL
    @State private var customPlaylistName: String = ""
    @State private var sliderEditing = false
    @State private var pendingSeekTime: TimeInterval = 0

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = geometry.size.width < 520 ? 16 : 32

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    headerSection
                    presetsSection
                    musicSection
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(backgroundGradient)
        }
        .background(Color.black)
        .onChange(of: musicViewModel.selectedPlaylist?.id) { newValue in
            if let id = newValue,
               let recent = musicViewModel.recentPlaylists.first(where: { $0.id == id }) {
                customPlaylistName = recent.customName ?? ""
            } else {
                customPlaylistName = ""
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                Image("ba_logo")
                    .resizable()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("brain")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black.opacity(0.85))
                        Text("aural")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("®")
                            .font(.system(size: 16, weight: .semibold))
                            .baselineOffset(10)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Text("Ultimate Brainwaves")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                HStack(spacing: 16) {
                    ControlButton(
                        imageName: tonesViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill",
                        tint: tonesViewModel.isPlaying ? Color.accentPrimary : Color.white.opacity(0.85),
                        background: tonesViewModel.isPlaying ? Color.white.opacity(0.15) : Color.white.opacity(0.08)
                    ) {
                        tonesViewModel.togglePlayPause()
                    }

                    ControlButton(
                        imageName: "link",
                        tint: Color.white.opacity(0.9),
                        background: Color.white.opacity(0.08)
                    ) {
                        openURL(URL(string: "https://brainaural.com")!)
                    }
                }
            }

            Text("Tap a preset to activate tones, then layer them with our curated playlists for an immersive Brain Tones experience.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.75))
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tone Presets")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(tonesViewModel.presets) { preset in
                    PresetRow(
                        preset: preset,
                        isHeadphonesActive: isActive(preset: preset, mode: .headphones),
                        isSpeakersActive: isActive(preset: preset, mode: .speakers),
                        activate: { mode in
                            tonesViewModel.activatePreset(preset, mode: mode)
                        }
                    )
                }
            }
        }
    }

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Music Playlists")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            if let error = musicViewModel.errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
            }

            if let playlist = musicViewModel.selectedPlaylist {
                playlistHeader(for: playlist)
                playbackDetails
                playbackControls
                trackList(for: playlist)
            } else {
                Text("No playlists available. Check the bundled catalog for music manifests.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            if !musicViewModel.recentPlaylists.isEmpty {
                recentSection
            }
        }
        .animation(.easeInOut, value: musicViewModel.selectedPlaylist?.id)
    }

    private func playlistHeader(for playlist: AudioPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Menu {
                    ForEach(musicViewModel.playlists, id: \.id) { entry in
                        Button(entry.title) {
                            musicViewModel.selectPlaylist(entry, autoplay: false)
                        }
                    }
                } label: {
                    HStack {
                        Text(playlist.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }

                Spacer()

                Button {
                    musicViewModel.addSelectedPlaylistToRecents(customName: customPlaylistName)
                } label: {
                    Text("Save to Recents")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.accentPrimary.opacity(0.25))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }

            TextField("Custom display name (optional)", text: $customPlaylistName)
                .padding()
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private var playbackDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                DownloadProgressRing(
                    progress: musicViewModel.downloadProgress,
                    isBuffering: musicViewModel.isBuffering
                )
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(musicViewModel.currentTrack?.title ?? "Select a track")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Track \(musicViewModel.currentTrackIndex + 1)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }

            if let duration = musicViewModel.playbackDuration {
                playbackSlider(duration: duration)
            } else {
                playbackSlider(duration: max(musicViewModel.playbackPosition + 1, 1))
                    .redacted(reason: .placeholder)
            }
        }
    }

    private func playbackSlider(duration: TimeInterval) -> some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { musicViewModel.playbackPosition },
                    set: { newValue in
                        if sliderEditing {
                            pendingSeekTime = newValue
                        }
                    }
                ),
                in: 0...max(duration, 1),
                onEditingChanged: { editing in
                    sliderEditing = editing
                    if editing {
                        pendingSeekTime = musicViewModel.playbackPosition
                    } else {
                        musicViewModel.seek(to: pendingSeekTime)
                    }
                }
            )
            .accentColor(.accentPrimary)

            HStack {
                Text(formattedTime(musicViewModel.playbackPosition))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                if let total = musicViewModel.playbackDuration {
                    Text(formattedTime(total))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("—")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 24) {
            ControlButton(
                imageName: "backward.fill",
                tint: Color.white.opacity(0.85),
                background: Color.white.opacity(0.08)
            ) {
                musicViewModel.skipBackward()
            }

            ControlButton(
                imageName: musicViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill",
                tint: musicViewModel.isPlaying ? Color.accentPrimary : Color.white.opacity(0.9),
                background: musicViewModel.isPlaying ? Color.white.opacity(0.18) : Color.white.opacity(0.08)
            ) {
                musicViewModel.togglePlayback()
            }
            .frame(width: 68, height: 68)

            ControlButton(
                imageName: "forward.fill",
                tint: Color.white.opacity(0.85),
                background: Color.white.opacity(0.08)
            ) {
                musicViewModel.skipForward()
            }
        }
    }

    private func trackList(for playlist: AudioPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracks")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            ForEach(Array(playlist.tracks.enumerated()), id: \.1.id) { index, track in
                TrackRow(
                    index: index,
                    track: track,
                    isActive: index == musicViewModel.currentTrackIndex,
                    downloadProgress: index == musicViewModel.currentTrackIndex ? musicViewModel.downloadProgress : 0,
                    select: {
                        musicViewModel.selectTrack(at: index, autoplay: true)
                    }
                )
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Playlists")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            ForEach(musicViewModel.recentPlaylists) { entry in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.displayTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        if let custom = entry.customName {
                            Text("Custom name: \(custom)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    Spacer()
                    Button {
                        musicViewModel.loadRecentPlaylist(entry.id)
                    } label: {
                        Text("Load")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentPrimary.opacity(0.3))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }

                    Button {
                        musicViewModel.removeRecentPlaylist(entry.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.01, blue: 0.07),
                Color(red: 0.16, green: 0.04, blue: 0.12),
                Color.accentPrimary.opacity(0.85),
                Color(red: 0.05, green: 0.01, blue: 0.07)
            ],
            startPoint: .top,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func isActive(preset: Preset, mode: OutputMode) -> Bool {
        guard let selected = tonesViewModel.selectedPreset else { return false }
        return selected.name == preset.name && tonesViewModel.outputMode == mode && tonesViewModel.isPlaying
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "--:--" }
        let total = Int(time.rounded(.towardZero))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct TrackRow: View {
    let index: Int
    let track: AudioTrack
    let isActive: Bool
    let downloadProgress: Double
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 30, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    if let duration = track.duration {
                        Text(duration.formattedMinutesSeconds)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                if isActive {
                    DownloadProgressRing(progress: downloadProgress, isBuffering: downloadProgress < 1.0)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .padding()
            .background(isActive ? Color.accentPrimary.opacity(0.25) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct DownloadProgressRing: View {
    let progress: Double
    let isBuffering: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                .stroke(Color.accentPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if isBuffering {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeInOut(duration: 0.3), value: progress)
    }
}

private struct PresetRow: View {
    let preset: Preset
    let isHeadphonesActive: Bool
    let isSpeakersActive: Bool
    let activate: (OutputMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text(preset.combinedPurposes)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .italic()
            }

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 160), spacing: 16, alignment: .top)
                ],
                alignment: .leading,
                spacing: 16
            ) {
                PresetModeButton(
                    iconName: "speaker1",
                    title: preset.name,
                    modeLabel: "Speakers",
                    isActive: isSpeakersActive,
                    action: { activate(.speakers) }
                )

                PresetModeButton(
                    iconName: "headphones",
                    title: preset.name,
                    modeLabel: "Headphones",
                    isActive: isHeadphonesActive,
                    action: { activate(.headphones) }
                )
            }
        }
    }
}

private struct PresetModeButton: View {
    let iconName: String
    let title: String
    let modeLabel: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isActive ? Color.white.opacity(0.7) : Color.white.opacity(0.2),
                        lineWidth: isActive ? 2 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(0.25),
                radius: isActive ? 10 : 5,
                x: 0,
                y: 6
            )
            .accessibilityLabel(Text("\(title) \(modeLabel)"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
    }

    private var background: some View {
        LinearGradient(
            colors: isActive
                ? [Color.accentPrimary.opacity(0.9), Color.accentSecondary.opacity(0.8)]
                : [Color.white.opacity(0.08), Color.white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ControlButton: View {
    let imageName: String
    let tint: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if imageName == "link" {
                Image(imageName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .foregroundColor(tint)
            } else {
                Image(systemName: imageName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(tint)
            }
        }
        .frame(width: 52, height: 52)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 5)
        .buttonStyle(.plain)
    }
}

private extension TimeInterval {
    var formattedMinutesSeconds: String {
        guard isFinite else { return "--:--" }
        let total = Int(rounded(.towardZero))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
