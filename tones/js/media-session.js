(function (window) {
	"use strict";

	var BrainTones = window.BrainTones || (window.BrainTones = {});
	var session = null;
	var youtube = null;
	var toneEngine = null;

	function supportsMediaSession() {
		return Boolean("mediaSession" in window.navigator && window.navigator.mediaSession);
	}

	function setPlaybackState(state) {
		if (!supportsMediaSession()) {
			return;
		}

		window.navigator.mediaSession.playbackState = state;
	}

	function setMetadata(options) {
		if (!supportsMediaSession()) {
			return;
		}

		var presetName = options && options.presetName ? options.presetName : "Ultimate Brainwaves";
		if (typeof window.MediaMetadata === "function") {
			window.navigator.mediaSession.metadata = new window.MediaMetadata({
				title: presetName,
				artist: "nilbus.com",
				album: "BrainTones",
				artwork: [
					{ src: "ba_logo.png", sizes: "192x192", type: "image/png" },
					{ src: "ba_logo.png", sizes: "512x512", type: "image/png" }
				]
			});
		} else {
			window.navigator.mediaSession.metadata = {
				title: presetName,
				artist: "nilbus.com",
				album: "BrainTones"
			};
		}
	}

	function reassertAppOwnership() {
		if (!supportsMediaSession()) {
			return;
		}

		var state = session ? session.getState() : null;
		setPlaybackState(state && !state.isPaused ? "playing" : "paused");
		setMetadata({ presetName: state && state.currentPresetName });

		var mediaElement = toneEngine && toneEngine.getMediaOutputElement ? toneEngine.getMediaOutputElement() : null;
		if (!mediaElement || !state || state.isPaused) {
			return;
		}

		try {
			var playPromise = mediaElement.play();
			if (playPromise && typeof playPromise.catch === "function") {
				playPromise.catch(function () {});
			}
		} catch (error) {}

		window.setTimeout(function () {
			if (!session || session.getState().isPaused || !mediaElement.paused) {
				return;
			}

			try {
				var retryPromise = mediaElement.play();
				if (retryPromise && typeof retryPromise.catch === "function") {
					retryPromise.catch(function () {});
				}
			} catch (error) {}
		}, 150);
	}

	function registerHandler(action, handler) {
		try {
			window.navigator.mediaSession.setActionHandler(action, handler);
		} catch (error) {
			console.error("Unable to register Media Session handler:", action, error);
		}
	}

	function setup(dependencies) {
		session = dependencies && dependencies.session;
		youtube = dependencies && dependencies.youtube;
		toneEngine = dependencies && dependencies.toneEngine;

		if (!supportsMediaSession() || !session || !youtube) {
			return;
		}

		setMetadata({});
		setPlaybackState("paused");

		registerHandler("play", function () {
			return session.startPlayback({});
		});
		registerHandler("pause", function () {
			return session.pausePlayback();
		});
		registerHandler("stop", function () {
			return session.pausePlayback();
		});
		registerHandler("previoustrack", function () {
			youtube.previousTrack();
			reassertAppOwnership();
		});
		registerHandler("nexttrack", function () {
			youtube.nextTrack();
			reassertAppOwnership();
		});

		try {
			if (window.navigator.mediaSession.setPositionState) {
				window.navigator.mediaSession.setPositionState({
					duration: Infinity,
					playbackRate: 1,
					position: 0
				});
			}
		} catch (error) {}
	}

	BrainTones.mediaSession = {
		setup: setup,
		setPlaybackState: setPlaybackState,
		setMetadata: setMetadata,
		reassertAppOwnership: reassertAppOwnership
	};
})(window);
