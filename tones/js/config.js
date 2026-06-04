(function (window) {
	"use strict";

	var BrainTones = window.BrainTones || (window.BrainTones = {});

	BrainTones.config = {
		DEFAULT_PLAYLIST_ID: "PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF",
		DEFAULT_PLAYLIST_URL: "https://www.youtube.com/playlist?list=PLr6Fn9qwKreJh28Ac9DexzsRY_tq6-KHF",
		DEFAULT_PLAYLIST_TITLE: "AllieSpaces",
		MAX_TONE_LAYERS: 5,
		storageKeys: {
			playlistId: "youtube_playlist_id",
			playlistUrl: "youtube_playlist_url",
			playlistStates: "youtube_playlist_states",
			recentPlaylists: "youtube_recent_playlists",
			balance: "tones_music_balance",
			selectedPresetIndex: "selected_preset_index",
			selectedOutputType: "selected_output_type"
		}
	};
})(window);
