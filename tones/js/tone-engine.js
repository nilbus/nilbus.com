(function (window, document) {
	"use strict";

	var BrainTones = window.BrainTones || (window.BrainTones = {});
	var config = BrainTones.config;
	var layerCount = config.MAX_TONE_LAYERS;
	var FCARMIN = 27.5;
	var OCTCAR = 9;

	var context = null;
	var initialized = false;
	var outputNode = null;
	var mediaOutputDestination = null;
	var mediaOutputElement = null;

	var mod = [1, 0.5, 1.95, 3, 0.2];
	var carrier = [220, 30, 150, 432, 9000];
	var noise = [0, 0, 0, 0, 0];
	var isochronic = [50, 100, 0, 0, 100];
	var binaural = [100, 100, 100, 0, 100];
	var bilateral = [0, 0, 0, 100, 100];
	var fm = [0, 100, 0, 0, 100];
	var level = [0, 0, 0, 0, 0];

	var oscL = [];
	var oscR = [];
	var noiseL = [];
	var noiseR = [];
	var lfo = [];
	var lfoHalf = [];
	var gainL = [];
	var gainR = [];
	var merger = [];
	var gainI = [];
	var bilatGain = [];
	var noiseGainL = [];
	var noiseGainR = [];
	var noiseGainRL = [];
	var noiseGainRR = [];
	var filterL = [];
	var filterR = [];
	var oscGainL = [];
	var oscGainR = [];
	var bilatInvertedGain = [];
	var lfoGain = [];
	var fmGain = [];
	var filterGain = [];
	var gainGlobal = [];

	function createAudioContext() {
		var AudioContextCtor = window.AudioContext || window.webkitAudioContext;
		if (!AudioContextCtor) {
			throw new Error("Web Audio API is not supported.");
		}
		return new AudioContextCtor();
	}

	function setParamValue(param, value) {
		if (!param) {
			return;
		}

		if (typeof param.setTargetAtTime === "function" && context) {
			param.setTargetAtTime(value, context.currentTime, 0.001);
		} else {
			param.value = value;
		}
	}

	function ensureMediaOutput() {
		if (!context) {
			return;
		}

		outputNode = context.destination;
		if (typeof context.createMediaStreamDestination !== "function") {
			return;
		}

		if (!mediaOutputDestination) {
			mediaOutputDestination = context.createMediaStreamDestination();
		}

		if (!mediaOutputElement) {
			mediaOutputElement = new window.Audio();
			mediaOutputElement.id = "tones-media-output";
			mediaOutputElement.autoplay = false;
			mediaOutputElement.preload = "auto";
			mediaOutputElement.muted = false;
			mediaOutputElement.volume = 1;
			mediaOutputElement.playsInline = true;
			mediaOutputElement.setAttribute("aria-hidden", "true");
			mediaOutputElement.style.display = "none";

			if (document.body) {
				document.body.appendChild(mediaOutputElement);
			}
		}

		try {
			if (mediaOutputElement.srcObject !== mediaOutputDestination.stream) {
				mediaOutputElement.srcObject = mediaOutputDestination.stream;
			}
		} catch (error) {
			console.error("Unable to attach tone stream to media element:", error);
		}

		outputNode = mediaOutputDestination;
	}

	function createNoiseBuffer() {
		var bufferSize = 6 * context.sampleRate;
		var noiseBuffer = context.createBuffer(1, bufferSize, context.sampleRate);
		var output = noiseBuffer.getChannelData(0);

		for (var i = 0; i < bufferSize; i += 1) {
			output[i] = 3 * (Math.random() * 2 - 1);
		}

		return noiseBuffer;
	}

	function setFrequencies(index) {
		var binauralOffset = mod[index] / 2 * binaural[index] / 100;

		if (oscL[index]) {
			oscL[index].frequency.value = carrier[index] + binauralOffset;
		}
		if (oscR[index]) {
			oscR[index].frequency.value = carrier[index] - binauralOffset;
		}
		if (filterL[index]) {
			filterL[index].frequency.value = carrier[index];
		}
		if (filterR[index]) {
			filterR[index].frequency.value = carrier[index];
		}
		if (lfo[index]) {
			setParamValue(lfo[index].frequency, mod[index]);
		}
		if (lfoHalf[index]) {
			setParamValue(lfoHalf[index].frequency, mod[index] / 2);
		}
	}

	function updateLayer(index) {
		if (!initialized) {
			return;
		}

		setFrequencies(index);

		if (noiseGainL[index]) {
			noiseGainL[index].gain.value = noise[index] / 100;
		}
		if (noiseGainR[index]) {
			noiseGainR[index].gain.value = noise[index] / 100;
		}
		if (oscGainL[index]) {
			oscGainL[index].gain.value = 1 - noise[index] / 100;
		}
		if (oscGainR[index]) {
			oscGainR[index].gain.value = 1 - noise[index] / 100;
		}
		if (noiseGainRR[index]) {
			noiseGainRR[index].gain.value = binaural[index] / 100;
		}
		if (noiseGainRL[index]) {
			noiseGainRL[index].gain.value = 1 - binaural[index] / 100;
		}
		if (bilatGain[index]) {
			bilatGain[index].gain.value = bilateral[index] / 100 * 0.25;
		}
		if (fmGain[index]) {
			fmGain[index].gain.value = fm[index] / 100 * carrier[index];
		}
		if (filterGain[index]) {
			filterGain[index].gain.value = fm[index] / 150 * carrier[index];
		}
		if (gainI[index]) {
			var fmax = Math.pow(2, OCTCAR) * FCARMIN;
			gainI[index].gain.value = 0.5 * (1 - 0.5 * carrier[index] / fmax) * (1 - 0.6 * carrier[index] / fmax);
		}
		if (lfoGain[index] && gainI[index]) {
			lfoGain[index].gain.value = isochronic[index] / 100 * gainI[index].gain.value;
		}
		if (gainGlobal[index]) {
			gainGlobal[index].gain.value = level[index] * level[index] / 10000;
		}
	}

	function createLayer(index) {
		var noiseBuffer = createNoiseBuffer();

		oscL[index] = context.createOscillator();
		oscL[index].type = "sine";
		oscR[index] = context.createOscillator();
		oscR[index].type = "sine";
		lfo[index] = context.createOscillator();
		lfo[index].type = "sine";
		lfoHalf[index] = context.createOscillator();
		lfoHalf[index].type = "sine";

		noiseL[index] = context.createBufferSource();
		noiseL[index].buffer = noiseBuffer;
		noiseL[index].loop = true;
		noiseR[index] = context.createBufferSource();
		noiseR[index].buffer = noiseBuffer;
		noiseR[index].loop = true;

		filterR[index] = context.createBiquadFilter();
		filterL[index] = context.createBiquadFilter();
		filterR[index].type = "bandpass";
		filterR[index].Q.value = 2;
		filterL[index].type = "bandpass";
		filterL[index].Q.value = 2;

		noiseGainL[index] = context.createGain();
		noiseGainR[index] = context.createGain();
		noiseGainRL[index] = context.createGain();
		noiseGainRR[index] = context.createGain();
		oscGainL[index] = context.createGain();
		oscGainR[index] = context.createGain();
		bilatGain[index] = context.createGain();
		bilatInvertedGain[index] = context.createGain();
		lfoGain[index] = context.createGain();
		fmGain[index] = context.createGain();
		filterGain[index] = context.createGain();
		gainL[index] = context.createGain();
		gainR[index] = context.createGain();
		gainI[index] = context.createGain();
		gainGlobal[index] = context.createGain();
		merger[index] = context.createChannelMerger(2);

		noiseGainL[index].gain.value = 0;
		noiseGainR[index].gain.value = 0;
		oscGainL[index].gain.value = 1;
		oscGainR[index].gain.value = 1;
		noiseGainRL[index].gain.value = 0;
		noiseGainRR[index].gain.value = 1;
		bilatInvertedGain[index].gain.value = -1;
		gainL[index].gain.value = 0.25;
		gainR[index].gain.value = 0.25;
		gainI[index].gain.value = 0.5;
		gainGlobal[index].gain.value = 0;

		noiseL[index].connect(noiseGainL[index]);
		noiseL[index].connect(noiseGainRL[index]);
		noiseR[index].connect(noiseGainRR[index]);
		noiseGainRR[index].connect(noiseGainR[index]);
		noiseGainRL[index].connect(noiseGainR[index]);
		noiseGainL[index].connect(filterL[index]);
		noiseGainR[index].connect(filterR[index]);
		oscL[index].connect(oscGainL[index]);
		oscR[index].connect(oscGainR[index]);

		bilatGain[index].connect(bilatInvertedGain[index]);
		lfoHalf[index].connect(bilatGain[index]);
		lfo[index].connect(lfoGain[index]);
		lfo[index].connect(fmGain[index]);
		lfo[index].connect(filterGain[index]);
		fmGain[index].connect(oscL[index].frequency);
		fmGain[index].connect(oscR[index].frequency);
		filterGain[index].connect(filterL[index].frequency);
		filterGain[index].connect(filterR[index].frequency);

		bilatInvertedGain[index].connect(gainL[index].gain);
		bilatGain[index].connect(gainR[index].gain);
		lfoGain[index].connect(gainI[index].gain);

		oscGainL[index].connect(gainL[index]);
		oscGainR[index].connect(gainR[index]);
		filterL[index].connect(gainL[index]);
		filterR[index].connect(gainR[index]);

		merger[index].connect(gainI[index]);
		gainL[index].connect(merger[index], 0, 0);
		gainR[index].connect(merger[index], 0, 1);
		gainI[index].connect(gainGlobal[index]);
		gainGlobal[index].connect(outputNode || context.destination);

		updateLayer(index);

		lfo[index].start();
		lfoHalf[index].start();
		oscL[index].start();
		oscR[index].start();
		noiseR[index].start(0, 3);
		noiseL[index].start();
	}

	function initialize() {
		if (initialized) {
			return;
		}

		context = createAudioContext();
		ensureMediaOutput();

		for (var index = 0; index < layerCount; index += 1) {
			createLayer(index);
		}

		initialized = true;
	}

	async function play() {
		if (!initialized) {
			initialize();
		}

		if (context && context.state === "suspended" && typeof context.resume === "function") {
			await context.resume();
		}

		if (mediaOutputElement) {
			try {
				await mediaOutputElement.play();
			} catch (error) {
				console.log("Tone media element play was blocked:", error);
			}
		}
	}

	async function pause() {
		if (mediaOutputElement) {
			mediaOutputElement.pause();
		}

		if (context && context.state !== "suspended" && typeof context.suspend === "function") {
			await context.suspend();
		}
	}

	function setLayerValues(index, values) {
		mod[index] = Number(values.mod) || 0;
		carrier[index] = Number(values.carrier) || 220;
		noise[index] = Number(values.noise) || 0;
		isochronic[index] = Number(values.isochronic) || 0;
		binaural[index] = Number(values.binaural) || 0;
		bilateral[index] = Number(values.bilateral) || 0;
		fm[index] = Number(values.fm) || 0;
		level[index] = Number(values.level) || 0;
		updateLayer(index);
	}

	function applyPreset(options) {
		if (!options || !window.PRESET_TONES || !window.generatePresetParams) {
			return;
		}

		var presetIndex = Number(options.presetIndex);
		var outputType = options.outputType;
		var preset = window.PRESET_TONES[presetIndex];
		if (!preset) {
			return;
		}

		for (var index = 0; index < layerCount; index += 1) {
			setLayerValues(index, {
				mod: 0,
				carrier: 220,
				noise: 0,
				isochronic: 0,
				binaural: 0,
				bilateral: 0,
				fm: 0,
				level: 0
			});
		}

		var params = window.generatePresetParams(preset, outputType);
		for (var layerIndex = 0; layerIndex < layerCount; layerIndex += 1) {
			setLayerValues(layerIndex, {
				mod: params["mod" + layerIndex] || 0,
				carrier: params["car" + layerIndex] || 220,
				noise: params["noi" + layerIndex] || 0,
				isochronic: params["iso" + layerIndex] || 0,
				binaural: params["bin" + layerIndex] || 0,
				bilateral: params["bil" + layerIndex] || 0,
				fm: params["fm" + layerIndex] || 0,
				level: params["lvl" + layerIndex] || 0
			});
		}
	}

	function getCurrentParams() {
		var params = {};
		for (var index = 0; index < layerCount; index += 1) {
			params["mod" + index] = mod[index];
			params["car" + index] = carrier[index];
			params["noi" + index] = noise[index];
			params["iso" + index] = isochronic[index];
			params["bin" + index] = binaural[index];
			params["bil" + index] = bilateral[index];
			params["fm" + index] = fm[index];
			params["lvl" + index] = level[index];
		}
		return params;
	}

	function getLayerArrays() {
		return {
			mod: mod.slice(),
			carrier: carrier.slice(),
			noise: noise.slice(),
			isochronic: isochronic.slice(),
			binaural: binaural.slice(),
			bilateral: bilateral.slice(),
			fm: fm.slice(),
			level: level.slice()
		};
	}

	function setOutputVolume(value) {
		if (mediaOutputElement) {
			mediaOutputElement.volume = Math.max(0, Math.min(1, Number(value)));
		}
	}

	BrainTones.toneEngine = {
		initialize: initialize,
		isInitialized: function () { return initialized; },
		isRunning: function () { return Boolean(context && context.state === "running"); },
		play: play,
		pause: pause,
		applyPreset: applyPreset,
		getCurrentParams: getCurrentParams,
		getLayerArrays: getLayerArrays,
		getContext: function () { return context; },
		getMediaOutputDestination: function () { return mediaOutputDestination; },
		getMediaOutputElement: function () { return mediaOutputElement; },
		setOutputVolume: setOutputVolume
	};
})(window, document);
