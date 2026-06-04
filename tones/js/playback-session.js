(function (window, document) {
	"use strict";

	var BrainTones = window.BrainTones || (window.BrainTones = {});
	var storage = BrainTones.storage;
	var toneEngine = BrainTones.toneEngine;
	var youtube = BrainTones.youtube;

	var state = {
		isPaused: true,
		currentPresetIndex: null,
		currentOutputType: null
	};
	var wakeLock = null;
	var mediaOwnershipRefreshScheduled = false;
	var mediaOwnershipRefreshCompleted = false;

	function getPresetName(presetIndex) {
		var preset = window.PRESET_TONES && window.PRESET_TONES[presetIndex];
		return preset ? preset.name : null;
	}

	function getState() {
		var activePlaylist = storage.getCurrentPlaylist();
		return {
			isPaused: state.isPaused,
			currentPresetIndex: state.currentPresetIndex,
			currentOutputType: state.currentOutputType,
			currentPresetName: getPresetName(state.currentPresetIndex),
			activePlaylistId: activePlaylist ? activePlaylist.id : null,
			activePlaylistUrl: activePlaylist ? activePlaylist.url : null
		};
	}

	function normalizeToneSelection(options) {
		var defaultTone = options.defaultTone || { presetIndex: 0, outputType: "speakers" };
		var explicitPreset = Number(options.presetIndex);
		var explicitOutput = options.outputType;
		var selectedTone = null;

		if (isFinite(explicitPreset) && window.PRESET_TONES && window.PRESET_TONES[explicitPreset] && (explicitOutput === "speakers" || explicitOutput === "headphones")) {
			selectedTone = {
				presetIndex: explicitPreset,
				outputType: explicitOutput
			};
		}

		if (!selectedTone && options.usePersistedTone !== false) {
			var persistedTone = storage.getSelectedTone();
			if (persistedTone && window.PRESET_TONES && window.PRESET_TONES[persistedTone.presetIndex]) {
				selectedTone = persistedTone;
			}
		}

		if (!selectedTone && state.currentPresetIndex !== null && state.currentOutputType && window.PRESET_TONES && window.PRESET_TONES[state.currentPresetIndex]) {
			selectedTone = {
				presetIndex: state.currentPresetIndex,
				outputType: state.currentOutputType
			};
		}

		if (!selectedTone) {
			selectedTone = {
				presetIndex: defaultTone.presetIndex,
				outputType: defaultTone.outputType
			};
		}

		return selectedTone;
	}

	function normalizePlaylist(playlist) {
		if (playlist && playlist.id) {
			return {
				id: playlist.id,
				title: playlist.title || playlist.id,
				url: playlist.url || "https://www.youtube.com/playlist?list=" + encodeURIComponent(playlist.id)
			};
		}

		return storage.ensureDefaultPlaylist();
	}

	function showWakeLockStatus() {
		var statusElement = document.getElementById("wake-lock-status");
		if (statusElement) {
			statusElement.style.display = "flex";
		}
	}

	function hideWakeLockStatus() {
		var statusElement = document.getElementById("wake-lock-status");
		if (statusElement) {
			statusElement.style.display = "none";
		}
	}

	async function requestWakeLock() {
		if (!("wakeLock" in window.navigator) || !window.navigator.wakeLock) {
			return;
		}

		try {
			wakeLock = await window.navigator.wakeLock.request("screen");
			showWakeLockStatus();
			wakeLock.addEventListener("release", function () {
				wakeLock = null;
				hideWakeLockStatus();
			});
		} catch (error) {
			console.error("Screen Wake Lock failed:", error);
			hideWakeLockStatus();
		}
	}

	function releaseWakeLock() {
		if (!wakeLock) {
			hideWakeLockStatus();
			return;
		}

		var lock = wakeLock;
		wakeLock = null;
		try {
			lock.release();
		} catch (error) {}
		hideWakeLockStatus();
	}

	function updateVisualAndMediaState() {
		if (BrainTones.ui) {
			BrainTones.ui.setPlaybackVisualState({
				isPaused: state.isPaused,
				presetIndex: state.currentPresetIndex,
				outputType: state.currentOutputType
			});
		}
		if (BrainTones.mediaSession) {
			BrainTones.mediaSession.setMetadata({ presetName: getPresetName(state.currentPresetIndex) });
			BrainTones.mediaSession.setPlaybackState(state.isPaused ? "paused" : "playing");
		}
	}

	async function startPlayback(options) {
		options = options || {};
		var wasPaused = state.isPaused;
		var selectedTone = normalizeToneSelection(options);
		var playlist = normalizePlaylist(options.playlist);
		var currentPlaylist = storage.getCurrentPlaylist();
		var playlistChanged = Boolean(playlist && (!currentPlaylist || currentPlaylist.id !== playlist.id));
		var youtubeSnapshot = youtube.getSnapshot();
		var shouldLoadPlaylist = Boolean(
			playlistChanged ||
			options.forcePlaylistLoad ||
			(
				wasPaused &&
				playlist.id !== BrainTones.config.DEFAULT_PLAYLIST_ID &&
				youtubeSnapshot.states &&
				(
					youtubeSnapshot.state === youtubeSnapshot.states.UNSTARTED ||
					youtubeSnapshot.state === youtubeSnapshot.states.CUED
				)
			)
		);

		toneEngine.initialize();
		toneEngine.applyPreset({
			presetIndex: selectedTone.presetIndex,
			outputType: selectedTone.outputType
		});
		storage.setSelectedTone(selectedTone);

		state.isPaused = false;
		state.currentPresetIndex = selectedTone.presetIndex;
		state.currentOutputType = selectedTone.outputType;
		updateVisualAndMediaState();
		if (BrainTones.ui) {
			BrainTones.ui.setBalance(storage.getBalance());
		}

		if (shouldLoadPlaylist) {
			youtube.loadPlaylist({
				id: playlist.id,
				url: playlist.url,
				autoplay: true
			});
			if (BrainTones.ui) {
				BrainTones.ui.setPlaylistInputValue(playlist.url);
			}
		} else {
			storage.setCurrentPlaylist(playlist);
			youtube.play();
		}

		await toneEngine.play();
		youtube.play();
		youtube.startAutoSave();
		await requestWakeLock();
		if (BrainTones.mediaSession) {
			BrainTones.mediaSession.reassertAppOwnership();
		}
		if (BrainTones.session && typeof BrainTones.session.scheduleMediaOwnershipPlaybackRefresh === "function") {
			BrainTones.session.scheduleMediaOwnershipPlaybackRefresh(0);
		} else {
			scheduleMediaOwnershipPlaybackRefresh(0);
		}
	}

	async function pausePlayback() {
		if (state.isPaused) {
			updateVisualAndMediaState();
			return;
		}

		state.isPaused = true;
		youtube.pause();
		youtube.saveCurrentPosition();
		youtube.stopAutoSave();
		await toneEngine.pause();
		releaseWakeLock();
		updateVisualAndMediaState();
		if (BrainTones.mediaSession) {
			BrainTones.mediaSession.reassertAppOwnership();
		}
	}

	function togglePlayback() {
		if (state.isPaused) {
			return startPlayback({});
		}

		return pausePlayback();
	}

	async function refreshMediaOwnershipPlayback() {
		var presetIndex = state.currentPresetIndex;
		var outputType = state.currentOutputType;

		if (mediaOwnershipRefreshCompleted || state.isPaused || presetIndex === null || !outputType) {
			return false;
		}

		mediaOwnershipRefreshCompleted = true;
		await toneEngine.pause();
		await new Promise(function (resolve) {
			window.setTimeout(resolve, 100);
		});
		if (state.isPaused || state.currentPresetIndex !== presetIndex || state.currentOutputType !== outputType) {
			return false;
		}

		toneEngine.initialize();
		toneEngine.applyPreset({
			presetIndex: presetIndex,
			outputType: outputType
		});
		await toneEngine.play();
		updateVisualAndMediaState();
		if (BrainTones.mediaSession) {
			BrainTones.mediaSession.reassertAppOwnership();
		}
		return true;
	}

	function scheduleMediaOwnershipPlaybackRefresh(delayMs) {
		if (mediaOwnershipRefreshScheduled || mediaOwnershipRefreshCompleted || state.isPaused || state.currentPresetIndex === null || !state.currentOutputType) {
			return false;
		}

		mediaOwnershipRefreshScheduled = true;
		window.setTimeout(function () {
			refreshMediaOwnershipPlayback();
		}, Number(delayMs) || 0);
		return true;
	}

	function selectPreset(options) {
		if (!options) {
			return;
		}

		var presetIndex = Number(options.presetIndex);
		var outputType = options.outputType;
		var sameActiveTone = (
			!state.isPaused &&
			state.currentPresetIndex === presetIndex &&
			state.currentOutputType === outputType
		);

		if (sameActiveTone) {
			return pausePlayback();
		}

		return startPlayback({
			presetIndex: presetIndex,
			outputType: outputType,
			playlist: storage.ensureDefaultPlaylist(),
			usePersistedTone: false
		});
	}

	function selectPlaylist(playlist) {
		var selectedPlaylist = normalizePlaylist(playlist);
		if (!state.isPaused && state.currentPresetIndex !== null && state.currentOutputType) {
			return startPlayback({
				presetIndex: state.currentPresetIndex,
				outputType: state.currentOutputType,
				playlist: selectedPlaylist,
				usePersistedTone: false
			});
		}

		return startPlayback({
			playlist: selectedPlaylist,
			usePersistedTone: true,
			defaultTone: { presetIndex: 0, outputType: "speakers" },
			forcePlaylistLoad: selectedPlaylist.id !== BrainTones.config.DEFAULT_PLAYLIST_ID
		});
	}

	document.addEventListener("visibilitychange", function () {
		if (!state.isPaused && document.visibilityState === "visible") {
			requestWakeLock();
		}
	});

	BrainTones.session = {
		getState: getState,
		startPlayback: startPlayback,
		pausePlayback: pausePlayback,
		togglePlayback: togglePlayback,
		scheduleMediaOwnershipPlaybackRefresh: scheduleMediaOwnershipPlaybackRefresh,
		selectPreset: selectPreset,
		selectPlaylist: selectPlaylist
	};
})(window, document);
