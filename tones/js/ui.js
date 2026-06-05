(function (window, document) {
	"use strict";

	var BrainTones = window.BrainTones || (window.BrainTones = {});
	var storage = BrainTones.storage;
	var youtube = BrainTones.youtube;
	var toneEngine = BrainTones.toneEngine;
	var session = null;
	var YOUTUBE_SIMPLE_MODE_DELAY_MS = 1000;
	var YOUTUBE_NOW_PLAYING_REFRESH_MS = 1000;
	var youtubeDisplayMode = "player";
	var youtubeSimpleModeTimer = null;
	var keepPlayerModeForActivePlayback = false;
	var youtubeNowPlayingRefreshTimer = null;

	function upcaseFirstLetter(value) {
		if (!value) {
			return "";
		}
		return value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
	}

	function renderPresetButtons() {
		var container = document.getElementById("preset-buttons-container");
		if (!container || !window.PRESET_TONES) {
			return;
		}

		container.innerHTML = "";
		window.PRESET_TONES.forEach(function (preset, index) {
			var row = document.createElement("div");
			row.className = "preset-row";

			var speakersButton = document.createElement("button");
			speakersButton.type = "button";
			speakersButton.className = "preset-button";
			speakersButton.id = "preset-" + index + "-speakers";
			speakersButton.dataset.presetIndex = String(index);
			speakersButton.dataset.outputType = "speakers";
			speakersButton.innerHTML = '<img src="speaker1.png" class="preset-icon" alt=""><span class="preset-name"></span>';
			speakersButton.querySelector(".preset-name").textContent = preset.name;

			var headphonesButton = document.createElement("button");
			headphonesButton.type = "button";
			headphonesButton.className = "preset-button";
			headphonesButton.id = "preset-" + index + "-headphones";
			headphonesButton.dataset.presetIndex = String(index);
			headphonesButton.dataset.outputType = "headphones";
			headphonesButton.innerHTML = '<img src="headphones.png" class="preset-icon" alt=""><span class="preset-name"></span>';
			headphonesButton.querySelector(".preset-name").textContent = preset.name;

			var purposesDiv = document.createElement("div");
			purposesDiv.className = "preset-purposes-row";
			var purposesText = preset.layers.map(function (layer) {
				return layer.purpose;
			}).filter(function (purpose) {
				return purpose && purpose.trim();
			}).join(", ");
			purposesDiv.innerHTML = '<span class="preset-purposes"></span>';
			purposesDiv.querySelector(".preset-purposes").textContent = upcaseFirstLetter(purposesText);

			row.appendChild(speakersButton);
			row.appendChild(headphonesButton);
			row.appendChild(purposesDiv);
			container.appendChild(row);
		});
	}

	function renderRecentPlaylists() {
		var container = document.getElementById("recent-playlists");
		if (!container) {
			return;
		}

		var playlists = storage.getRecentPlaylists();
		container.innerHTML = "";

		if (playlists.length === 0) {
			container.style.display = "none";
			return;
		}

		container.style.display = "block";
		playlists.forEach(function (playlist) {
			var item = document.createElement("div");
			item.className = "recent-playlist-item";

			var deleteButton = document.createElement("button");
			deleteButton.type = "button";
			deleteButton.className = "delete-btn";
			deleteButton.textContent = "\u2715";
			deleteButton.setAttribute("aria-label", "Remove " + playlist.title);
			deleteButton.setAttribute("title", "Remove playlist");
			deleteButton.addEventListener("click", function (event) {
				event.preventDefault();
				event.stopPropagation();
				handleDeletePlaylist(playlist);
			});

			var link = document.createElement("a");
			link.href = "#";
			link.className = "playlist-link";
			link.textContent = playlist.title;
			link.addEventListener("click", function (event) {
				event.preventDefault();
				if (session) {
					session.selectPlaylist(playlist);
				}
			});

			item.appendChild(deleteButton);
			item.appendChild(link);
			container.appendChild(item);
		});
	}

	function handleDeletePlaylist(playlist) {
		var isMobile = window.innerWidth <= 768 || /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(window.navigator.userAgent);
		if (!isMobile || window.confirm("Delete " + playlist.title + "?")) {
			storage.deleteRecentPlaylist(playlist.id);
			renderRecentPlaylists();
		}
	}

	function setPlaybackVisualState(options) {
		var isPaused = Boolean(options && options.isPaused);
		var presetIndex = options ? options.presetIndex : null;
		var outputType = options ? options.outputType : null;
		var muteButton = document.getElementById("mute");

		if (muteButton) {
			muteButton.classList.toggle("superactive", isPaused);
		}

		document.querySelectorAll(".preset-button").forEach(function (button) {
			button.classList.remove("active");
		});

		if (!isPaused && presetIndex !== null && outputType) {
			var selectedButton = document.getElementById("preset-" + presetIndex + "-" + outputType);
			if (selectedButton) {
				selectedButton.classList.add("active");
			}
		}

		updateYouTubeTransportVisualState();
	}

	function getBalanceVolumes(value) {
		var p = value / 100;
		if (p <= 0.5) {
			return {
				tonesVolume: 1,
				musicVolume: 2 * p
			};
		}

		return {
			tonesVolume: 2 * (1 - p),
			musicVolume: 1
		};
	}

	function clearYouTubeSimpleModeTimer() {
		if (youtubeSimpleModeTimer) {
			window.clearTimeout(youtubeSimpleModeTimer);
			youtubeSimpleModeTimer = null;
		}
	}

	function setYouTubeDisplayMode(mode, options) {
		var nextMode = mode === "simple" ? "simple" : "player";
		var section = document.querySelector(".youtube-section");
		var toggle = document.getElementById("youtube-display-toggle");

		if (options && options.userInitiated) {
			clearYouTubeSimpleModeTimer();
			if (nextMode === "player" && session && !session.getState().isPaused) {
				keepPlayerModeForActivePlayback = true;
			} else if (nextMode === "simple") {
				keepPlayerModeForActivePlayback = false;
			}
		}

		youtubeDisplayMode = nextMode;

		if (section) {
			section.classList.toggle("youtube-mode-player", nextMode === "player");
			section.classList.toggle("youtube-mode-simple", nextMode === "simple");
		}

		if (toggle) {
			toggle.textContent = nextMode === "simple" ? "Show video" : "Show controls";
			toggle.setAttribute("aria-expanded", nextMode === "player" ? "true" : "false");
		}
	}

	function toggleYouTubeDisplayMode() {
		setYouTubeDisplayMode(youtubeDisplayMode === "simple" ? "player" : "simple", {
			userInitiated: true
		});
	}

	function scheduleSimpleModeAfterPlaybackStart(options) {
		clearYouTubeSimpleModeTimer();

		if (options && options.resetManualPreference) {
			keepPlayerModeForActivePlayback = false;
		}

		if (keepPlayerModeForActivePlayback) {
			return;
		}

		youtubeSimpleModeTimer = window.setTimeout(function () {
			youtubeSimpleModeTimer = null;
			setYouTubeDisplayMode("simple");
		}, YOUTUBE_SIMPLE_MODE_DELAY_MS);
	}

	function cancelScheduledSimpleMode(options) {
		clearYouTubeSimpleModeTimer();

		if (options && options.resetManualPreference) {
			keepPlayerModeForActivePlayback = false;
		}
	}

	function formatTrackTime(seconds) {
		var normalized = Math.max(0, Math.floor(Number(seconds) || 0));
		var hours = Math.floor(normalized / 3600);
		var minutes = Math.floor((normalized % 3600) / 60);
		var remainingSeconds = normalized % 60;
		var paddedSeconds = remainingSeconds < 10 ? "0" + remainingSeconds : String(remainingSeconds);

		if (hours > 0) {
			var paddedMinutes = minutes < 10 ? "0" + minutes : String(minutes);
			return hours + ":" + paddedMinutes + ":" + paddedSeconds;
		}

		return minutes + ":" + paddedSeconds;
	}

	function formatTrackTimeRange(currentTime, duration) {
		var current = formatTrackTime(currentTime);
		var normalizedDuration = Number(duration);
		if (isFinite(normalizedDuration) && normalizedDuration > 0) {
			return current + " / " + formatTrackTime(normalizedDuration);
		}

		return current;
	}

	function updateYouTubeNowPlaying() {
		var titleElement = document.getElementById("youtube-track-title");
		var authorElement = document.getElementById("youtube-track-author");
		var indexElement = document.getElementById("youtube-track-index");
		var timeElement = document.getElementById("youtube-track-time");
		var snapshot = youtube && typeof youtube.getSnapshot === "function" ? youtube.getSnapshot() : {};
		var videoData = snapshot.videoData || {};
		var currentPlaylist = storage.getCurrentPlaylist();
		var title = videoData.title || (currentPlaylist && currentPlaylist.title) || "YouTube playlist";
		var author = videoData.author || "";
		var trackNumber = Number(snapshot.playlistIndex) + 1;
		var playlistLength = Number(snapshot.playlistLength);

		if (titleElement) {
			titleElement.textContent = title;
		}
		if (authorElement) {
			authorElement.textContent = author;
		}
		if (indexElement) {
			indexElement.textContent = isFinite(trackNumber) && trackNumber > 0 && isFinite(playlistLength) && playlistLength > 0
				? "Track " + trackNumber + " of " + playlistLength
				: "";
		}
		if (timeElement) {
			timeElement.textContent = formatTrackTimeRange(snapshot.currentTime, snapshot.duration);
		}
	}

	function startYouTubeNowPlayingRefresh() {
		if (youtubeNowPlayingRefreshTimer) {
			return;
		}

		updateYouTubeNowPlaying();
		youtubeNowPlayingRefreshTimer = window.setInterval(updateYouTubeNowPlaying, YOUTUBE_NOW_PLAYING_REFRESH_MS);
	}

	function updateYouTubeTransportVisualState() {
		var playPauseButton = document.getElementById("youtube-playpause-btn");
		var previousButton = document.getElementById("youtube-previous-btn");
		var nextButton = document.getElementById("youtube-next-btn");
		var snapshot = youtube && typeof youtube.getSnapshot === "function" ? youtube.getSnapshot() : {};
		var states = snapshot.states || {};
		var isReady = Boolean(snapshot.ready);
		var isPlaying = snapshot.state === states.PLAYING || snapshot.state === states.BUFFERING;

		if (playPauseButton) {
			var playPauseLabel = isPlaying ? "Pause YouTube" : "Play YouTube";
			var playPauseTitle = isPlaying ? "Pause YouTube" : "Play YouTube";
			var playPauseIcon = playPauseButton.querySelector("[aria-hidden='true']");
			playPauseButton.disabled = !isReady;
			playPauseButton.setAttribute("aria-label", playPauseLabel);
			playPauseButton.setAttribute("title", playPauseTitle);
			playPauseButton.classList.toggle("is-paused", !isPlaying);
			if (playPauseIcon) {
				playPauseIcon.textContent = isPlaying ? "\u275A\u275A" : "\u25B6";
			}
		}

		if (previousButton) {
			previousButton.disabled = !isReady;
		}

		if (nextButton) {
			nextButton.disabled = !isReady;
		}

		updateYouTubeNowPlaying();
	}

	function toggleYouTubeOnlyPlayback() {
		var snapshot = youtube && typeof youtube.getSnapshot === "function" ? youtube.getSnapshot() : {};
		var states = snapshot.states || {};
		var isPlaying = snapshot.state === states.PLAYING || snapshot.state === states.BUFFERING;

		if (isPlaying) {
			youtube.pause();
		} else {
			youtube.play();
		}

		window.setTimeout(updateYouTubeTransportVisualState, 100);
	}

	function setBalance(value) {
		var normalized = storage.setBalance(value);
		var slider = document.getElementById("tones-music-balance");
		var volumes = getBalanceVolumes(normalized);

		if (slider && slider.value !== String(normalized)) {
			slider.value = String(normalized);
		}

		toneEngine.setOutputVolume(volumes.tonesVolume);
		youtube.setVolume(volumes.musicVolume * 100);
		return normalized;
	}

	function markPlaylistInputValid(isValid) {
		var input = document.getElementById("playlist-url");
		if (input) {
			input.classList.toggle("invalid", !isValid);
		}
	}

	function getInputPlaylist() {
		var input = document.getElementById("playlist-url");
		var url = input ? input.value.trim() : "";
		var id = youtube.extractPlaylistId(url);
		if (!id) {
			return null;
		}

		return {
			id: id,
			url: url,
			title: id
		};
	}

	function savePlaylistFromInput() {
		var playlist = getInputPlaylist();
		if (!playlist) {
			markPlaylistInputValid(false);
			return;
		}

		markPlaylistInputValid(true);
		youtube.saveCurrentPosition();

		var title = window.prompt("Enter a name for this playlist:", playlist.id);
		if (title === null || title.trim() === "") {
			title = playlist.id;
		}
		playlist.title = title;

		storage.addRecentPlaylist(playlist);
		renderRecentPlaylists();

		if (session && !session.getState().isPaused) {
			session.selectPlaylist(playlist);
		} else {
			storage.setCurrentPlaylist(playlist);
		}
	}

	function loadInputPlaylist() {
		var playlist = getInputPlaylist();
		if (!playlist) {
			markPlaylistInputValid(false);
			return;
		}

		markPlaylistInputValid(true);
		if (session && !session.getState().isPaused) {
			session.selectPlaylist(playlist);
		} else {
			youtube.saveCurrentPosition();
			storage.setCurrentPlaylist(playlist);
		}
	}

	async function openBrainauralUrl() {
		if (session && !session.getState().isPaused) {
			await session.pausePlayback();
		}

		var params = toneEngine.getCurrentParams();
		var url = "https://brainaural.com/play.php?";
		var parts = [];
		for (var index = 0; index < BrainTones.config.MAX_TONE_LAYERS; index += 1) {
			parts.push("mod" + index + "=" + encodeURIComponent(params["mod" + index]));
			parts.push("car" + index + "=" + encodeURIComponent(params["car" + index]));
			parts.push("noi" + index + "=" + encodeURIComponent(params["noi" + index]));
			parts.push("iso" + index + "=" + encodeURIComponent(params["iso" + index]));
			parts.push("bin" + index + "=" + encodeURIComponent(params["bin" + index]));
			parts.push("bil" + index + "=" + encodeURIComponent(params["bil" + index]));
			parts.push("fm" + index + "=" + encodeURIComponent(params["fm" + index]));
			parts.push("lvl" + index + "=" + encodeURIComponent(params["lvl" + index]));
		}
		window.open(url + parts.join("&"), "_blank");
	}

	function bindEvents(dependencies) {
		session = dependencies && dependencies.session;
		var muteButton = document.getElementById("mute");
		var brainauralLink = document.getElementById("brainaural-link");
		var presetContainer = document.getElementById("preset-buttons-container");
		var playlistInput = document.getElementById("playlist-url");
		var saveButton = document.getElementById("save-playlist-btn");
		var balance = document.getElementById("tones-music-balance");
		var youtubeDisplayToggle = document.getElementById("youtube-display-toggle");
		var youtubePreviousButton = document.getElementById("youtube-previous-btn");
		var youtubePlayPauseButton = document.getElementById("youtube-playpause-btn");
		var youtubeNextButton = document.getElementById("youtube-next-btn");

		if (muteButton) {
			muteButton.addEventListener("click", function () {
				if (session) {
					session.togglePlayback();
				}
			});
		}

		if (brainauralLink) {
			brainauralLink.addEventListener("click", function () {
				openBrainauralUrl();
			});
		}

		if (presetContainer) {
			presetContainer.addEventListener("click", function (event) {
				var button = event.target.closest(".preset-button");
				if (!button || !presetContainer.contains(button) || !session) {
					return;
				}

				session.selectPreset({
					presetIndex: Number(button.dataset.presetIndex),
					outputType: button.dataset.outputType
				});
			});
		}

		if (playlistInput) {
			playlistInput.addEventListener("keydown", function (event) {
				if (event.key === "Enter") {
					event.preventDefault();
					loadInputPlaylist();
				}
			});
		}

		if (saveButton) {
			saveButton.addEventListener("click", savePlaylistFromInput);
		}

		if (youtubeDisplayToggle) {
			youtubeDisplayToggle.addEventListener("click", toggleYouTubeDisplayMode);
		}

		if (youtubePreviousButton) {
			youtubePreviousButton.addEventListener("click", function () {
				youtube.previousTrack();
				window.setTimeout(updateYouTubeTransportVisualState, 100);
			});
		}

		if (youtubePlayPauseButton) {
			youtubePlayPauseButton.addEventListener("click", function () {
				toggleYouTubeOnlyPlayback();
			});
		}

		if (youtubeNextButton) {
			youtubeNextButton.addEventListener("click", function () {
				youtube.nextTrack();
				window.setTimeout(updateYouTubeTransportVisualState, 100);
			});
		}

		if (balance) {
			balance.addEventListener("input", function () {
				setBalance(balance.value);
			});
			balance.addEventListener("dblclick", function () {
				setBalance(50);
			});
		}

		startYouTubeNowPlayingRefresh();
	}

	function setPlaylistInputValue(url) {
		var input = document.getElementById("playlist-url");
		if (input && url) {
			input.value = url;
		}
	}

	BrainTones.ui = {
		renderPresetButtons: renderPresetButtons,
		renderRecentPlaylists: renderRecentPlaylists,
		bindEvents: bindEvents,
		setPlaybackVisualState: setPlaybackVisualState,
		setYouTubeDisplayMode: setYouTubeDisplayMode,
		getYouTubeDisplayMode: function () { return youtubeDisplayMode; },
		updateYouTubeTransportVisualState: updateYouTubeTransportVisualState,
		updateYouTubeNowPlaying: updateYouTubeNowPlaying,
		scheduleSimpleModeAfterPlaybackStart: scheduleSimpleModeAfterPlaybackStart,
		cancelScheduledSimpleMode: cancelScheduledSimpleMode,
		setBalance: setBalance,
		markPlaylistInputValid: markPlaylistInputValid,
		openBrainauralUrl: openBrainauralUrl,
		setPlaylistInputValue: setPlaylistInputValue,
		getBalanceVolumes: getBalanceVolumes
	};
})(window, document);
