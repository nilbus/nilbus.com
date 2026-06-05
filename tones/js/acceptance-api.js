(function (window) {
	"use strict";

	var BrainTones = window.BrainTones || (window.BrainTones = {});

	function getState() {
		var sessionState = BrainTones.session ? BrainTones.session.getState() : {};
		var context = BrainTones.toneEngine ? BrainTones.toneEngine.getContext() : null;
		var destination = BrainTones.toneEngine ? BrainTones.toneEngine.getMediaOutputDestination() : null;

		return {
			isPaused: sessionState.isPaused !== false,
			isAudioInitialized: Boolean(BrainTones.toneEngine && BrainTones.toneEngine.isInitialized()),
			contextState: context ? context.state : null,
			currentPresetName: sessionState.currentPresetName || null,
			currentPresetIndex: sessionState.currentPresetIndex,
			currentOutputType: sessionState.currentOutputType,
			isYouTubeReady: Boolean(BrainTones.youtube && BrainTones.youtube.isReady()),
			youtubeDisplayMode: BrainTones.ui && typeof BrainTones.ui.getYouTubeDisplayMode === "function" ? BrainTones.ui.getYouTubeDisplayMode() : null,
			activePlaylistId: sessionState.activePlaylistId || null,
			hasToneStream: Boolean(destination && destination.stream)
		};
	}

	function getToneParams() {
		return BrainTones.toneEngine ? BrainTones.toneEngine.getLayerArrays() : {
			mod: [],
			carrier: [],
			noise: [],
			isochronic: [],
			binaural: [],
			bilateral: [],
			fm: [],
			level: []
		};
	}

	BrainTones.acceptance = {
		getState: getState,
		getToneParams: getToneParams,
		getYouTubePlayer: function () {
			return BrainTones.youtube ? BrainTones.youtube.getPlayer() : null;
		},
		getAudioContext: function () {
			return BrainTones.toneEngine ? BrainTones.toneEngine.getContext() : null;
		},
		getToneMediaOutputDestination: function () {
			return BrainTones.toneEngine ? BrainTones.toneEngine.getMediaOutputDestination() : null;
		},
		getToneMediaOutputElement: function () {
			return BrainTones.toneEngine ? BrainTones.toneEngine.getMediaOutputElement() : null;
		},
		getYouTubeSnapshot: function () {
			return BrainTones.youtube ? BrainTones.youtube.getSnapshot() : {};
		},
		getBalance: function () {
			return BrainTones.storage ? BrainTones.storage.getBalance() : null;
		}
	};
})(window);
