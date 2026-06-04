(function (window) {
	"use strict";

	var BrainTones = window.BrainTones || (window.BrainTones = {});
	var config = BrainTones.config;
	var keys = config.storageKeys;

	function getItem(key) {
		try {
			return window.localStorage.getItem(key);
		} catch (error) {
			console.error("Unable to read localStorage key:", key, error);
			return null;
		}
	}

	function setItem(key, value) {
		try {
			window.localStorage.setItem(key, value);
		} catch (error) {
			console.error("Unable to write localStorage key:", key, error);
		}
	}

	function parseJson(key, fallback) {
		var raw = getItem(key);
		if (!raw) {
			return fallback;
		}

		try {
			return JSON.parse(raw);
		} catch (error) {
			console.error("Unable to parse localStorage key:", key, error);
			return fallback;
		}
	}

	function writeJson(key, value) {
		setItem(key, JSON.stringify(value));
	}

	function normalizePlaylist(playlist) {
		if (!playlist || !playlist.id) {
			return null;
		}

		return {
			id: String(playlist.id),
			title: playlist.title ? String(playlist.title) : String(playlist.id),
			url: playlist.url ? String(playlist.url) : "https://www.youtube.com/playlist?list=" + encodeURIComponent(String(playlist.id))
		};
	}

	function getRecentPlaylists() {
		var playlists = parseJson(keys.recentPlaylists, []);
		return Array.isArray(playlists) ? playlists.filter(function (playlist) {
			return playlist && playlist.id && playlist.url;
		}) : [];
	}

	function saveRecentPlaylists(playlists) {
		writeJson(keys.recentPlaylists, playlists);
	}

	function getCurrentPlaylist() {
		var id = getItem(keys.playlistId);
		var url = getItem(keys.playlistUrl);
		if (id) {
			return {
				id: id,
				url: url || "https://www.youtube.com/playlist?list=" + encodeURIComponent(id)
			};
		}

		var recent = getRecentPlaylists();
		if (recent.length > 0) {
			return normalizePlaylist(recent[0]);
		}

		return null;
	}

	function setCurrentPlaylist(playlist) {
		var normalized = normalizePlaylist(playlist);
		if (!normalized) {
			return null;
		}

		setItem(keys.playlistId, normalized.id);
		setItem(keys.playlistUrl, normalized.url);
		return normalized;
	}

	function ensureDefaultPlaylist() {
		var current = getCurrentPlaylist();
		if (current) {
			if (!getItem(keys.playlistId)) {
				setCurrentPlaylist(current);
			}
			return current;
		}

		var defaultPlaylist = {
			id: config.DEFAULT_PLAYLIST_ID,
			title: config.DEFAULT_PLAYLIST_TITLE,
			url: config.DEFAULT_PLAYLIST_URL
		};

		setCurrentPlaylist(defaultPlaylist);
		addRecentPlaylist(defaultPlaylist);
		return defaultPlaylist;
	}

	function addRecentPlaylist(playlist) {
		var normalized = normalizePlaylist(playlist);
		if (!normalized) {
			return [];
		}

		var playlists = getRecentPlaylists().filter(function (recentPlaylist) {
			return recentPlaylist.id !== normalized.id;
		});

		playlists.unshift({
			id: normalized.id,
			title: normalized.title,
			url: normalized.url,
			addedAt: Date.now()
		});

		saveRecentPlaylists(playlists);
		return playlists;
	}

	function deleteRecentPlaylist(id) {
		var playlists = getRecentPlaylists().filter(function (playlist) {
			return playlist.id !== id;
		});

		saveRecentPlaylists(playlists);
		return playlists;
	}

	function getPlaylistStates() {
		var states = parseJson(keys.playlistStates, {});
		return states && typeof states === "object" && !Array.isArray(states) ? states : {};
	}

	function getPlaylistState(playlistId) {
		if (!playlistId) {
			return null;
		}

		var state = getPlaylistStates()[playlistId];
		if (!state) {
			return null;
		}

		var videoIndex = Number(state.videoIndex);
		var playbackTime = Number(state.playbackTime);
		if (!isFinite(videoIndex) || !isFinite(playbackTime) || videoIndex < 0 || playbackTime < 0) {
			return null;
		}

		return {
			playlistId: playlistId,
			videoIndex: videoIndex,
			playbackTime: playbackTime
		};
	}

	function setPlaylistState(playlistId, state) {
		if (!playlistId || !state) {
			return;
		}

		var videoIndex = Number(state.videoIndex);
		var playbackTime = Number(state.playbackTime);
		if (!isFinite(videoIndex) || !isFinite(playbackTime) || videoIndex < 0 || playbackTime < 0) {
			return;
		}

		var states = getPlaylistStates();
		states[playlistId] = {
			videoIndex: videoIndex,
			playbackTime: playbackTime,
			lastUsed: Date.now()
		};
		writeJson(keys.playlistStates, states);
	}

	function clearPlaylistState(playlistId) {
		if (!playlistId) {
			return;
		}

		var states = getPlaylistStates();
		delete states[playlistId];
		writeJson(keys.playlistStates, states);
	}

	function getSelectedTone() {
		var rawPresetIndex = getItem(keys.selectedPresetIndex);
		var outputType = getItem(keys.selectedOutputType);
		var presetIndex = Number(rawPresetIndex);

		if (!isFinite(presetIndex) || presetIndex < 0 || Math.floor(presetIndex) !== presetIndex) {
			return null;
		}

		if (outputType !== "headphones" && outputType !== "speakers") {
			return null;
		}

		return {
			presetIndex: presetIndex,
			outputType: outputType
		};
	}

	function setSelectedTone(tone) {
		if (!tone) {
			return;
		}

		var presetIndex = Number(tone.presetIndex);
		var outputType = tone.outputType;
		if (!isFinite(presetIndex) || presetIndex < 0 || Math.floor(presetIndex) !== presetIndex) {
			return;
		}

		if (outputType !== "headphones" && outputType !== "speakers") {
			return;
		}

		setItem(keys.selectedPresetIndex, String(presetIndex));
		setItem(keys.selectedOutputType, outputType);
	}

	function getBalance() {
		var raw = getItem(keys.balance);
		var value = Number(raw);
		if (!isFinite(value) || value < 0 || value > 100) {
			return 50;
		}
		return Math.round(value);
	}

	function setBalance(value) {
		var normalized = Math.max(0, Math.min(100, Math.round(Number(value))));
		if (!isFinite(normalized)) {
			normalized = 50;
		}
		setItem(keys.balance, String(normalized));
		return normalized;
	}

	BrainTones.storage = {
		getCurrentPlaylist: getCurrentPlaylist,
		setCurrentPlaylist: setCurrentPlaylist,
		ensureDefaultPlaylist: ensureDefaultPlaylist,
		getRecentPlaylists: getRecentPlaylists,
		addRecentPlaylist: addRecentPlaylist,
		deleteRecentPlaylist: deleteRecentPlaylist,
		getPlaylistState: getPlaylistState,
		setPlaylistState: setPlaylistState,
		clearPlaylistState: clearPlaylistState,
		getSelectedTone: getSelectedTone,
		setSelectedTone: setSelectedTone,
		getBalance: getBalance,
		setBalance: setBalance
	};
})(window);
