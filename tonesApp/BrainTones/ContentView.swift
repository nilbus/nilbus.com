import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BrainTonesViewModel()
    @StateObject private var youtubeViewModel = YouTubeViewModel()
    @Environment(\.openURL) private var openURL
    @State private var customPlaylistName: String = ""

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = geometry.size.width < 520 ? 16 : 32

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    headerSection
                    presetsSection
                    youtubeSection
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(backgroundGradient)
        }
        .background(Color.black)
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
                        imageName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill",
                        tint: viewModel.isPlaying ? Color.accentPrimary : Color.white.opacity(0.85),
                        background: viewModel.isPlaying ? Color.white.opacity(0.15) : Color.white.opacity(0.08)
                    ) {
                        viewModel.togglePlayPause()
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

            Text("Tap a preset below and choose headphones or speakers. The tones play immediately and pair with your favorite YouTube playlists.")
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
                ForEach(viewModel.presets) { preset in
                    PresetRow(
                        preset: preset,
                        isHeadphonesActive: isActive(preset: preset, mode: .headphones),
                        isSpeakersActive: isActive(preset: preset, mode: .speakers),
                        activate: { mode in
                            viewModel.activatePreset(preset, mode: mode)
                        }
                    )
                }
            }
        }
    }

    private var youtubeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YouTube Playlists")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            VStack(alignment: .leading, spacing: 12) {
                TextField("Enter YouTube playlist URL", text: $youtubeViewModel.playlistURL)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundColor(.white)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.done)
                    .onSubmit {
                        Task { await handlePlaylistLoadAndSave() }
                    }

                TextField("Custom name (optional)", text: $customPlaylistName)
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundColor(.white.opacity(0.9))
                    .disableAutocorrection(true)

                HStack {
                    Button {
                        Task { await handlePlaylistLoadAndSave() }
                    } label: {
                        HStack {
                            if youtubeViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.75)
                            }
                            Text("Add Playlist")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentPrimary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        youtubeViewModel.playlistURL = ""
                        customPlaylistName = ""
                    } label: {
                        Text("Clear")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }

            if let error = youtubeViewModel.errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
            }

            if let playlist = youtubeViewModel.currentPlaylist {
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\\(playlist.videos.count) videos • tap below to manage playback")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                Text("Paste any YouTube or YouTube Music playlist URL to combine with Brain Tones.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            YouTubePlayerView(
                playlistId: Binding(
                    get: { youtubeViewModel.activePlaylistId },
                    set: { _ in }
                ),
                isPlaying: Binding(
                    get: { youtubeViewModel.isPlayerPlaying },
                    set: { youtubeViewModel.isPlayerPlaying = $0 }
                ),
                startIndex: youtubeViewModel.startIndex,
                startTime: youtubeViewModel.startTime,
                onReady: {
                    youtubeViewModel.playerReady()
                },
                onStateChange: { state, index, time in
                    youtubeViewModel.playerStateChanged(state, index: index, time: time)
                },
                onProgress: { index, time, duration in
                    youtubeViewModel.playerProgress(index: index, time: time, duration: duration)
                },
                onError: { message in
                    youtubeViewModel.errorMessage = message
                }
            )
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )

            if !youtubeViewModel.recentPlaylists.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Playlists")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))

                    ForEach(youtubeViewModel.recentPlaylists) { playlist in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(playlist.url.absoluteString)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                Task { await youtubeViewModel.loadRecentPlaylist(playlist) }
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
                                youtubeViewModel.deleteRecentPlaylist(playlist)
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
        }
        .animation(.easeInOut, value: youtubeViewModel.currentPlaylist?.id)
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
        guard let selected = viewModel.selectedPreset else { return false }
        return selected.name == preset.name && viewModel.outputMode == mode && viewModel.isPlaying
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
                speakersButton
                headphonesButton
            }
        }
    }

    private var speakersButton: some View {
        PresetModeButton(
            iconName: "speaker1",
            title: preset.name,
            modeLabel: "Speakers",
            isActive: isSpeakersActive,
            action: { activate(.speakers) }
        )
    }

    private var headphonesButton: some View {
        PresetModeButton(
            iconName: "headphones",
            title: preset.name,
            modeLabel: "Headphones",
            isActive: isHeadphonesActive,
            action: { activate(.headphones) }
        )
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
                    .stroke(isActive ? Color.white.opacity(0.7) : Color.white.opacity(0.2), lineWidth: isActive ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: isActive ? 10 : 5, x: 0, y: 6)
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
        .buttonStyle(.plain)
        .padding(12)
        .background(background)
        .clipShape(Circle())
        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

private extension Color {
    static let accentPrimary = Color(red: 0.82, green: 0.24, blue: 0.38)
    static let accentSecondary = Color(red: 0.54, green: 0.2, blue: 0.56)
}

private extension ContentView {
    func handlePlaylistLoadAndSave() async {
        await youtubeViewModel.loadPlaylistFromCurrentURL()
        if let playlist = youtubeViewModel.currentPlaylist {
            let title = customPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = title.isEmpty ? playlist.title : title
            youtubeViewModel.addCurrentPlaylistToRecents(named: finalTitle)
            customPlaylistName = ""
        }
    }
}

#Preview {
    ContentView()
}
