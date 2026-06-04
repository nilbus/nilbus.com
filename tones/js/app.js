(function (window, document) {
	"use strict";

	var BrainTones = window.BrainTones || (window.BrainTones = {});

	function supportsWebAudio() {
		return Boolean(window.AudioContext || window.webkitAudioContext);
	}

	function bindKeyboard() {
		function toggle(event) {
			if (event && typeof event.preventDefault === "function") {
				event.preventDefault();
			}
			BrainTones.session.togglePlayback();
		}

		if (window.Mousetrap) {
			window.Mousetrap.bind("m", toggle);
			window.Mousetrap.bind("space", toggle);
			return;
		}

		document.addEventListener("keydown", function (event) {
			var tagName = event.target && event.target.tagName;
			var isEditable = event.target && event.target.isContentEditable;
			if (tagName === "INPUT" || tagName === "SELECT" || tagName === "TEXTAREA" || isEditable) {
				return;
			}

			if (event.code === "Space" || event.key === "m" || event.key === "M") {
				toggle(event);
			}
		});
	}

	function bindScrollDimming() {
		window.addEventListener("scroll", function () {
			var background = document.querySelector(".background");
			if (!background) {
				return;
			}

			if (window.pageYOffset || document.documentElement.scrollTop) {
				background.classList.add("dimmed");
			} else {
				background.classList.remove("dimmed");
			}
		});
	}

	function initialize() {
		if (!supportsWebAudio()) {
			window.alert("Web Audio API is missing. To enjoy BrainTones, please use a recent version of Chrome, Edge, Safari or Firefox.");
		}

		var playlist = BrainTones.storage.ensureDefaultPlaylist();
		BrainTones.ui.renderPresetButtons();
		BrainTones.ui.renderRecentPlaylists();
		BrainTones.ui.setPlaylistInputValue(playlist.url);
		BrainTones.ui.setPlaybackVisualState({ isPaused: true });
		BrainTones.ui.setBalance(BrainTones.storage.getBalance());
		BrainTones.ui.bindEvents({ session: BrainTones.session });
		BrainTones.mediaSession.setup({
			session: BrainTones.session,
			youtube: BrainTones.youtube,
			toneEngine: BrainTones.toneEngine
		});

		BrainTones.youtube.onReady(function () {
			BrainTones.ui.renderRecentPlaylists();
			BrainTones.ui.setBalance(BrainTones.storage.getBalance());
		});
		BrainTones.youtube.initializePlayer();

		bindKeyboard();
		bindScrollDimming();

		window.addEventListener("beforeunload", function () {
			BrainTones.youtube.stopAutoSave();
			BrainTones.youtube.saveCurrentPosition();
		});
	}

	BrainTones.app = {
		initialize: initialize
	};

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", initialize, { once: true });
	} else {
		initialize();
	}
})(window, document);
