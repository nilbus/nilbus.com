const PRESET_TONES = [
  {
    name: "Focused, Sustainable Thinking",
    layers: [
      { freq: 42, carrier: 240, type: "isochronic", vol: "70", purpose: "Cognitive sharpness" },
      { freq: 22, carrier: 220, type: "binaural", vol: "80/65", purpose: "Mental energy" },
      { freq: 10, carrier: 180, type: "isochronic", vol: "50", purpose: "Mental relaxation" }
    ]
  },
  {
    name: "Procrastination Crusher",
    layers: [
      { freq: 38, carrier: 260, type: "isochronic", vol: "75", purpose: "Urgency and motivation" },
      { freq: 18, carrier: 280, type: "binaural", vol: "85/70", purpose: "Task initiation" },
      { freq: 10, carrier: 240, type: "isochronic", vol: "50", purpose: "Calm focus" }
    ]
  },
  {
    name: "Jumpstart or Post-Meal Focus Boost",
    layers: [
      { freq: 40, carrier: 290, type: "isochronic", vol: "75", purpose: "Peak alertness and problem-solving speed" },
      { freq: 18, carrier: 260, type: "binaural", vol: "80/65", purpose: "Maintain focused energy and task engagement" },
      { freq: 10, carrier: 220, type: "isochronic", vol: "55", purpose: "Keep calm flow without mental rigidity" }
    ]
  },
  {
    name: "Deadline Drive",
    layers: [
      { freq: 40, carrier: 270, type: "isochronic", vol: "75", purpose: "Executive drive & mental precision" },
      { freq: 18, carrier: 250, type: "binaural", vol: "85/70", purpose: "Goal-oriented task engagement" },
      { freq: 9.5, carrier: 210, type: "isochronic", vol: "50", purpose: "Calm vigilance under pressure" }
    ]
  },
  {
    name: "Zen Debug Mode",
    layers: [
      { freq: 14, carrier: 250, type: "isochronic", vol: "60", purpose: "Steady analytical focus" },
      { freq: 10, carrier: 230, type: "binaural", vol: "65/50", purpose: "Relaxed clarity and mental ease" },
      { freq: 6.5, carrier: 200, type: "isochronic", vol: "50", purpose: "Creative flow and pattern recognition" }
    ]
  },
  {
    name: "Pair Flow",
    layers: [
      { freq: 16, carrier: 260, type: "isochronic", vol: "50", purpose: "Active verbal collaboration" },
      { freq: 12, carrier: 240, type: "binaural", vol: "50/40", purpose: "Calm focus with social awareness" },
      { freq: 8, carrier: 220, type: "isochronic", vol: "50", purpose: "Cooperative ease and flow" }
    ]
  },
  {
    name: "Second Wind",
    layers: [
      { freq: 36, carrier: 290, type: "isochronic", vol: "75", purpose: "Override fatigue with drive" },
      { freq: 20, carrier: 270, type: "binaural", vol: "70/55", purpose: "Sustained problem-solving energy" },
      { freq: 9, carrier: 230, type: "isochronic", vol: "55", purpose: "Prevent mental tension buildup" }
    ]
  },
  {
    name: "Power Nap Reset",
    layers: [
      { freq: 6, carrier: 210, type: "isochronic", vol: "70", purpose: "Transition into restful nap state" },
      { freq: 3, carrier: 190, type: "isochronic", vol: "65", purpose: "Deep, short rejuvenating sleep" }
    ]
  },
  {
    name: "Primal Drop",
    layers: [
      { freq: 6.3, carrier: 210.42, type: "isochronic", vol: "75", purpose: "Trance focus" },
      { freq: 2.5, carrier: 157.43, type: "isochronic", vol: "70", purpose: "Surrender and body sensitivity" },
      { freq: 0.2, carrier: 396, type: "isochronic", vol: "60", purpose: "Deep primal embodiment" }
    ]
  },
  {
    name: "HFDO Surrender",
    layers: [
      { freq: 5.5, carrier: 150, type: "isochronic", vol: "80", purpose: "Pelvic sensory mapping, interoception" },
      { freq: 7.83, carrier: 210, type: "isochronic", vol: "35", purpose: "Awareness anchor, cortical-limbic bridge" },
      { freq: 2.5, carrier: 100, type: "isochronic", vol: "100", purpose: "Parasympathetic surrender, body melting" },
      { freq: 0.5, carrier: 80, type: "isochronic", vol: "95", purpose: "Primal embodiment, energetic wave support" }
    ]
  }
];

// Function to generate parameters for headphones vs speakers
function generatePresetParams(preset, outputType) {
  const params = {};

  preset.layers.forEach((layer, i) => {
    if (layer.vol === "0") return; // Skip layers with zero volume

    // Common parameters for all layers
    params[`mod${i}`] = layer.freq;
    params[`car${i}`] = layer.carrier;
    params[`noi${i}`] = 0;
    params[`bil${i}`] = 0;
    params[`fm${i}`] = 0;

    // Volume handling
    if (layer.vol.includes('/')) {
      // Binaural layer with different volumes for headphones/speakers
      const [volH, volS] = layer.vol.split('/').map(Number);
      params[`lvl${i}`] = outputType === 'headphones' ? volH : volS;
    } else {
      // Single volume value
      params[`lvl${i}`] = Number(layer.vol);
    }

    // Headphones vs Speakers parameter differences
    if (outputType === 'headphones') {
      if (layer.type === 'isochronic') {
        params[`iso${i}`] = 100;
        params[`bin${i}`] = 0;
      } else if (layer.type === 'binaural') {
        params[`iso${i}`] = 0;
        params[`bin${i}`] = 100;
      }
    } else {
      // Speakers - all layers must be isochronic
      params[`iso${i}`] = 100;
      params[`bin${i}`] = 0;
    }
  });

  return params;
}
