(function (window, document) {
	"use strict";

	var BrainTones = window.BrainTones || (window.BrainTones = {});
	var storage = BrainTones.storage;
	var config = BrainTones.config;

	var player = null;
	var isReady = false;
	var readyCallbacks = [];
	var autoSaveInterval = null;
	var requestedInitialization = false;
	var loadedPlaylistId = null;

	var previousTrackIndex = null;
	var previousTrackPosition = 0;
	var forwardDestinationIndex = null;
	var forwardDestinationPosition = 0;

	function extractPlaylistId(url) {
		var match = String(url || "").match(/[?&]list=([^&]+)/);
		return match ? decodeURIComponent(match[1]) : null;
	}

	function getPlayerStateValue(name) {
		return window.YT && window.YT.PlayerState ? window.YT.PlayerState[name] : null;
	}

	function resetNavigationHistory() {
		previousTrackIndex = null;
		previousTrackPosition = 0;
		forwardDestinationIndex = null;
		forwardDestinationPosition = 0;
	}

	function retryAutoplayPlaylist(id) {
		window.setTimeout(function () {
			if (!player || !isReady) {
				return;
			}

			var currentPlaylist = storage.getCurrentPlaylist();
			if (!currentPlaylist || currentPlaylist.id !== id) {
				return;
			}

			var playing = getPlayerStateValue("PLAYING");
			var state = typeof player.getPlayerState === "function" ? player.getPlayerState() : null;
			if (state === playing) {
				return;
			}

			var playlistConfig = getPlaylistConfig(id);
			if (typeof player.loadPlaylist === "function") {
				player.loadPlaylist(playlistConfig);
				loadedPlaylistId = id;
			} else if (typeof player.cuePlaylist === "function") {
				player.cuePlaylist(playlistConfig);
				loadedPlaylistId = id;
			}
			play();
		}, 500);
	}

	function getPlaylistConfig(playlistId) {
		var playlistState = storage.getPlaylistState(playlistId);
		var playlistConfig = {
			listType: "playlist",
			list: playlistId
		};

		if (playlistState) {
			playlistConfig.index = playlistState.videoIndex;
			playlistConfig.startSeconds = playlistState.playbackTime;
		}

		return playlistConfig;
	}

	function cueCurrentPlaylist() {
		if (!player || !isReady || typeof player.cuePlaylist !== "function") {
			return;
		}

		var playlist = storage.ensureDefaultPlaylist();
		if (!playlist || !playlist.id) {
			return;
		}
		if (playlist.id !== config.DEFAULT_PLAYLIST_ID) {
			return;
		}

		player.cuePlaylist(getPlaylistConfig(playlist.id));
		loadedPlaylistId = playlist.id;
	}

	function notifyReady() {
		readyCallbacks.slice().forEach(function (callback) {
			callback(player);
		});
	}

	function onReady() {
		isReady = true;
		cueCurrentPlaylist();
		notifyReady();
		applyStoredBalance();
	}

	function onStateChange(event) {
		var ended = getPlayerStateValue("ENDED");
		if (!event || event.data !== ended || !player || !isReady) {
			return;
		}

		stopAutoSave();

		try {
			var currentIndex = player.getPlaylistIndex();
			var playlistItems = typeof player.getPlaylist === "function" ? player.getPlaylist() : [];
			var isLastVideo = Array.isArray(playlistItems) && currentIndex === playlistItems.length - 1;
			var currentPlaylist = storage.getCurrentPlaylist();

			if (isLastVideo && currentPlaylist && currentPlaylist.id) {
				storage.clearPlaylistState(currentPlaylist.id);
				player.loadPlaylist({
					listType: "playlist",
					list: currentPlaylist.id,
					index: 0
				});
				loadedPlaylistId = currentPlaylist.id;
			}
		} catch (error) {
			console.error("Unable to handle YouTube state change:", error);
		}
	}

	function initializePlayer() {
		if (player || !window.YT || typeof window.YT.Player !== "function") {
			return;
		}

		var targetElement = document.getElementById("youtube-player");
		if (!targetElement) {
			if (!requestedInitialization) {
				requestedInitialization = true;
				if (document.readyState === "loading") {
					document.addEventListener("DOMContentLoaded", function () {
						requestedInitialization = false;
						initializePlayer();
					}, { once: true });
				} else {
					window.setTimeout(function () {
						requestedInitialization = false;
						initializePlayer();
					}, 100);
				}
			}
			return;
		}

		storage.ensureDefaultPlaylist();
		player = new window.YT.Player("youtube-player", {
			height: "315",
			width: "560",
			playerVars: {
				listType: "playlist",
				list: config.DEFAULT_PLAYLIST_ID,
				rel: 0,
				showinfo: 0,
				controls: 1,
				disablekb: 0,
				enablejsapi: 1,
				autoplay: 0,
				origin: window.location.origin
			},
			events: {
				onReady: onReady,
				onStateChange: onStateChange
			}
		});
	}

	function onReadyCallback(callback) {
		if (typeof callback !== "function") {
			return;
		}

		readyCallbacks.push(callback);
		if (isReady) {
			callback(player);
		}
	}

	function loadPlaylist(options) {
		var id = options && options.id;
		var url = options && options.url;
		var autoplay = Boolean(options && options.autoplay);

		if (!id) {
			id = extractPlaylistId(url);
		}
		if (!id) {
			return false;
		}
		if (!url) {
			url = "https://www.youtube.com/playlist?list=" + encodeURIComponent(id);
		}

		saveCurrentPosition();
		resetNavigationHistory();
		storage.setCurrentPlaylist({ id: id, url: url });

		if (!player || !isReady) {
			return true;
		}

		try {
			stopAutoSave();
			var playlistConfig = getPlaylistConfig(id);
			if (autoplay && typeof player.loadPlaylist === "function") {
				player.loadPlaylist(playlistConfig);
				loadedPlaylistId = id;
				play();
				retryAutoplayPlaylist(id);
			} else if (autoplay && typeof player.cuePlaylist === "function") {
				player.cuePlaylist(playlistConfig);
				loadedPlaylistId = id;
				play();
				retryAutoplayPlaylist(id);
			} else if (typeof player.cuePlaylist === "function") {
				player.cuePlaylist(playlistConfig);
				loadedPlaylistId = id;
			}

			if (autoplay) {
				window.setTimeout(play, 100);
			}
			return true;
		} catch (error) {
			console.error("Unable to load YouTube playlist:", error);
			return false;
		}
	}

	function play() {
		if (player && isReady && typeof player.playVideo === "function") {
			player.playVideo();
		}
	}

	function pause() {
		if (player && isReady && typeof player.pauseVideo === "function") {
			player.pauseVideo();
		}
	}

	function setVolume(percent) {
		if (player && isReady && typeof player.setVolume === "function") {
			player.setVolume(Math.max(0, Math.min(100, Math.round(Number(percent)))));
		}
	}

	function applyStoredBalance() {
		var value = storage.getBalance();
		var musicVolume = value <= 50 ? value * 2 : 100;
		setVolume(musicVolume);
	}

	function saveCurrentPosition() {
		if (!player || !isReady) {
			return;
		}

		try {
			var currentPlaylist = storage.getCurrentPlaylist();
			if (!currentPlaylist || !currentPlaylist.id) {
				return;
			}

			var videoIndex = typeof player.getPlaylistIndex === "function" ? player.getPlaylistIndex() : 0;
			var playbackTime = typeof player.getCurrentTime === "function" ? player.getCurrentTime() : 0;
			if (videoIndex !== undefined && videoIndex >= 0 && playbackTime !== undefined && playbackTime >= 0) {
				storage.setPlaylistState(currentPlaylist.id, {
					videoIndex: videoIndex,
					playbackTime: playbackTime
				});
			}
		} catch (error) {
			console.error("Unable to save YouTube position:", error);
		}
	}

	function startAutoSave() {
		stopAutoSave();
		autoSaveInterval = window.setInterval(saveCurrentPosition, 29000);
	}

	function stopAutoSave() {
		if (autoSaveInterval) {
			window.clearInterval(autoSaveInterval);
			autoSaveInterval = null;
		}
	}

	function previousTrack() {
		if (!player || !isReady) {
			return;
		}

		try {
			var currentTime = typeof player.getCurrentTime === "function" ? player.getCurrentTime() : 0;
			var currentIndex = typeof player.getPlaylistIndex === "function" ? player.getPlaylistIndex() : 0;

			if (currentTime > 5 && typeof player.seekTo === "function") {
				player.seekTo(0, true);
				saveCurrentPosition();
				return;
			}

			forwardDestinationIndex = currentIndex;
			forwardDestinationPosition = currentTime;

			if (typeof player.previousVideo === "function") {
				player.previousVideo();
			}

			window.setTimeout(function () {
				if (!player || !isReady || typeof player.getPlaylistIndex !== "function") {
					return;
				}

				var newIndex = player.getPlaylistIndex();
				if (previousTrackIndex !== null && newIndex === previousTrackIndex && typeof player.seekTo === "function") {
					player.seekTo(previousTrackPosition, true);
					previousTrackIndex = null;
					previousTrackPosition = 0;
				}
			}, 500);

			saveCurrentPosition();
		} catch (error) {
			console.error("Unable to go to previous YouTube track:", error);
		}
	}

	function nextTrack() {
		if (!player || !isReady) {
			return;
		}

		try {
			var currentIndex = typeof player.getPlaylistIndex === "function" ? player.getPlaylistIndex() : 0;
			var currentTime = typeof player.getCurrentTime === "function" ? player.getCurrentTime() : 0;
			previousTrackIndex = currentIndex;
			previousTrackPosition = currentTime;

			var nextIndex = currentIndex + 1;
			var savedDestinationPosition = forwardDestinationIndex === nextIndex ? forwardDestinationPosition : 0;

			if (typeof player.nextVideo === "function") {
				player.nextVideo();
			}

			window.setTimeout(function () {
				if (!player || !isReady || typeof player.getPlaylistIndex !== "function") {
					return;
				}

				var newIndex = player.getPlaylistIndex();
				if (forwardDestinationIndex !== null && newIndex === forwardDestinationIndex && savedDestinationPosition > 0 && typeof player.seekTo === "function") {
					player.seekTo(savedDestinationPosition, true);
					forwardDestinationIndex = null;
					forwardDestinationPosition = 0;
				} else {
					forwardDestinationIndex = newIndex;
					forwardDestinationPosition = typeof player.getCurrentTime === "function" ? player.getCurrentTime() : 0;
				}
			}, 500);

			saveCurrentPosition();
		} catch (error) {
			console.error("Unable to go to next YouTube track:", error);
		}
	}

	function getSnapshot() {
		var states = window.YT && window.YT.PlayerState ? {
			UNSTARTED: window.YT.PlayerState.UNSTARTED,
			ENDED: window.YT.PlayerState.ENDED,
			PLAYING: window.YT.PlayerState.PLAYING,
			PAUSED: window.YT.PlayerState.PAUSED,
			BUFFERING: window.YT.PlayerState.BUFFERING,
			CUED: window.YT.PlayerState.CUED
		} : {};

		var currentPlaylist = storage.getCurrentPlaylist();
		var snapshot = {
			ready: isReady,
			hasPlayer: Boolean(player),
			state: null,
			currentTime: null,
			playlistIndex: null,
			playlistLength: null,
			volume: null,
			loadedPlaylistId: loadedPlaylistId,
			localPlaylistId: currentPlaylist ? currentPlaylist.id : null,
			states: states,
			navigationHistory: {
				previousTrackIndex: previousTrackIndex,
				previousTrackPosition: previousTrackPosition,
				forwardDestinationIndex: forwardDestinationIndex,
				forwardDestinationPosition: forwardDestinationPosition
			},
			autoSaveActive: Boolean(autoSaveInterval),
			error: null
		};

		if (!player) {
			return snapshot;
		}

		try {
			if (typeof player.getPlayerState === "function") {
				snapshot.state = player.getPlayerState();
			}
			if (typeof player.getCurrentTime === "function") {
				snapshot.currentTime = player.getCurrentTime();
			}
			if (typeof player.getPlaylistIndex === "function") {
				snapshot.playlistIndex = player.getPlaylistIndex();
			}
			if (typeof player.getPlaylist === "function") {
				var playlist = player.getPlaylist();
				snapshot.playlistLength = Array.isArray(playlist) ? playlist.length : null;
			}
			if (typeof player.getVolume === "function") {
				snapshot.volume = player.getVolume();
			}
		} catch (error) {
			snapshot.error = String(error && error.message ? error.message : error);
		}

		return snapshot;
	}

	window.onYouTubeIframeAPIReady = function () {
		initializePlayer();
	};

	if (window.YT && typeof window.YT.Player === "function") {
		initializePlayer();
	}

	BrainTones.youtube = {
		initializePlayer: initializePlayer,
		onReady: onReadyCallback,
		isReady: function () { return isReady; },
		getPlayer: function () { return player; },
		cueCurrentPlaylist: cueCurrentPlaylist,
		loadPlaylist: loadPlaylist,
		play: play,
		pause: pause,
		setVolume: setVolume,
		saveCurrentPosition: saveCurrentPosition,
		startAutoSave: startAutoSave,
		stopAutoSave: stopAutoSave,
		previousTrack: previousTrack,
		nextTrack: nextTrack,
		getSnapshot: getSnapshot,
		extractPlaylistId: extractPlaylistId,
		resetNavigationHistory: resetNavigationHistory
	};
})(window, document);
