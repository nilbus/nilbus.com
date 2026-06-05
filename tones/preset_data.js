/*
**Goal** Generate scientifically-informed, purpose-driven binaural and isochronic tone sets that
address specific cognitive, emotional, or physiological states through precise frequency
entrainment protocols.

**Return format** Output must be a valid JavaScript object matching this structure exactly:
```json { name: "Descriptive State Name", layers: [ { freq: [number], carrier: [number or
"num1/num2"], type: "binaural" or "isochronic", vol: "[num]" or "[num1/num2]", purpose: "Brief
physiological/cognitive effect" }, … ] } ```

**Warnings** - Binaural layers require split volume notation (e.g., "80/65") where the higher
value is for binaural delivery and lower value maintains equivalent pulsing power when converted
to isochronic-only playback - Isochronic-only layers use single volume values unless designed for
dual-carrier speaker optimization - Erotic or intimacy-focused tone sets must use dual-carrier
isochronic format with split volumes (format: "carrier1/carrier2" and "vol1/vol2") to accommodate
both quality speaker systems (lower frequencies, lower volumes) and shower/mobile phone speakers
(higher frequencies, higher volumes that cut through ambient noise) - Layer volumes create
emphasis hierarchy - adjust relative volumes to weight the dominant intended effect - Frequency
ranges must align with established brainwave entrainment research: Delta (0.5-4 Hz), Theta (4-8
Hz), Alpha (8-14 Hz), Beta (14-30 Hz), Gamma (30-100 Hz) - Carrier frequencies should be audible
(typically 150-400 Hz range) and harmonically compatible within each set - Default to 1 binaural
layer per set unless using all isochronic layers would demonstrably enhance the specific
entrainment goal - Avoid frequency conflicts that could create dissonant beating patterns or
cancel intended entrainment effects - Avoid multiple simultaneous binaural layers; use at most one
binaural layer per preset; make additional entrainment layers isochronic to prevent perceptual
interference and degraded entrainment - Purpose descriptions must be concise, physiologically
accurate, and specific to the layer's contribution to the overall state

**Context** The assistant is an expert in psychoacoustics, brainwave entrainment, neuroscience,
and frequency-based consciousness modulation. Tone sets leverage binaural beats (frequency
difference between ears) and isochronic tones (evenly-spaced pulses) to guide brainwave states
toward desired cognitive, emotional, or somatic outcomes.

Binaural beats require headphones and create the entrainment frequency through interhemispheric
processing of the carrier frequency difference. Isochronic tones work through any speaker by
directly pulsing at the target frequency. The split-volume system for binaural layers accounts
for the perceptual intensity difference between delivery methods while maintaining consistent
entrainment power and layer balance when users switch between headphone and speaker playback.

For tone sets addressing intimacy, arousal, or erotic states, every tone should be isochronic and
have different carriers (e.g. "417/210.42"), the former for use in the shower with tones that
shine through the background noise better on a mobile phone speaker, and the latter for nice
speakers with lower-frequency tones and lower volumes compared to the former.

The assistant should draw upon knowledge of: brainwave frequency correlates to mental states,
autonomic nervous system regulation through entrainment, the role of specific frequency bands in
cognitive performance, the interaction between multiple simultaneous entrainment frequencies,
solfeggio frequencies and their purported effects, Schumann resonance (7.83 Hz), and the
physiological mechanisms of arousal, relaxation, focus, and altered states.

When crafting new tone sets, consider the synergistic interaction between layers, the progression
of entrainment effects, and any contraindications for specific frequency combinations. Optimize
for the specific use case while maintaining the technical constraints of the playback system
architecture.

Science-supported is preferred, but where scientific support is weak, anecdotal support is
acceptable, including for purpose-driven carrier tones that reportedly are good for specific
purposes (e.g. love tones). Use harmonics in carrier tones. const PRESET_TONES = [
*/

const PRESET_TONES = [
  {
    name: "Focused & Sustainable Thinking",
    layers: [
      { freq: 42, carrier: 240, type: "isochronic", vol: "70/75", purpose: "Cognitive sharpness" },
      { freq: 22, carrier: 220, type: "binaural", vol: "80/70", purpose: "Mental energy" },
      { freq: 10, carrier: 180, type: "isochronic", vol: "50/55", purpose: "Mental relaxation" }
    ]
  },
  {
    name: "Relaxed, Productive Creativity",
    layers: [
      { freq: 14, carrier: 250, type: "isochronic", vol: "70/75", purpose: "Steady analytical focus" },
      { freq: 10, carrier: 230, type: "binaural", vol: "75/60", purpose: "Relaxed clarity and mental ease" },
      { freq: 7.5, carrier: 200, type: "isochronic", vol: "55", purpose: "Creative flow and pattern recognition" }
    ]
  },
  {
    name: "Procrastination Crusher",
    layers: [
      { freq: 38, carrier: 260, type: "isochronic", vol: "65/70", purpose: "Urgency and motivation" },
      { freq: 18, carrier: 280, type: "binaural", vol: "75/65", purpose: "Task initiation" },
      { freq: 10, carrier: 240, type: "isochronic", vol: "45", purpose: "Calm focus" }
    ]
  },
  {
    name: "Jumpstart or Post-Meal Focus Boost",
    layers: [
      { freq: 40, carrier: 290, type: "isochronic", vol: "65/70", purpose: "Peak alertness and problem-solving speed" },
      { freq: 18, carrier: 260, type: "binaural", vol: "70/60", purpose: "Maintain focused energy and task engagement" },
      { freq: 10, carrier: 220, type: "isochronic", vol: "50", purpose: "Keep calm flow without mental rigidity" }
    ]
  },
  {
    name: "Deadline Drive",
    layers: [
      { freq: 40, carrier: 270, type: "isochronic", vol: "65/70", purpose: "Executive drive & mental precision" },
      { freq: 18, carrier: 250, type: "binaural", vol: "75/65", purpose: "Goal-oriented task engagement" },
      { freq: 9.5, carrier: 210, type: "isochronic", vol: "45", purpose: "Calm vigilance under pressure" }
    ]
  },
  {
    name: "Pair Flow",
    layers: [
      { freq: 16, carrier: 260, type: "isochronic", vol: "65/70", purpose: "Active verbal collaboration" },
      { freq: 12, carrier: 240, type: "binaural", vol: "65/55", purpose: "Calm focus with social awareness" },
      { freq: 8, carrier: 220, type: "isochronic", vol: "65/70", purpose: "Cooperative ease and flow" }
    ]
  },
  {
    name: "Second Wind",
    layers: [
      { freq: 36, carrier: 290, type: "isochronic", vol: "70", purpose: "Override fatigue with drive" },
      { freq: 20, carrier: 270, type: "binaural", vol: "65/50", purpose: "Sustained problem-solving energy" },
      { freq: 9, carrier: 230, type: "isochronic", vol: "50", purpose: "Prevent mental tension buildup" }
    ]
  },
  {
    name: "Power Nap Reset",
    layers: [
      { freq: 6, carrier: 210, type: "isochronic", vol: "80", purpose: "Transition into restful nap state" },
      { freq: 3, carrier: 190, type: "isochronic", vol: "75", purpose: "Deep, short rejuvenating sleep" }
    ]
  },
  {
    name: "Edge: Initiation & Buildup",
    layers: [
      { freq: 10, carrier: "285/174", type: "isochronic", vol: "60/80", purpose: "(5–10 min) Calm arousal, emotional safety, sympathetic braking" },
      { freq: 7.83, carrier: "210.42/187.87", type: "isochronic", vol: "50/65", purpose: "Cortical-limbic / emotional coherence, relaxed sensual presence" },
      { freq: 5.5, carrier: "417/210.42", type: "isochronic", vol: "60/80", purpose: "Early pelvic interoception without emission loading" }
    ]
  },
  {
    name: "Edge: Contractile Conditioning",
    layers: [
      { freq: 5.5, carrier: "417/210.42", type: "isochronic", vol: "65/90", purpose: "Pelvic sensory amplification, pleasure wave mapping" },
      { freq: 7.83, carrier: "210.42/187.87", type: "isochronic", vol: "40/55", purpose: "Arousal coherence, emotional containment" },
      { freq: 2.8, carrier: "157.43/140.28", type: "isochronic", vol: "40/55", purpose: "Parasympathetic biasing without loss of control" }
    ]
  },
  {
    name: "Edge: Stability for Dry Contractions",
    layers: [
      { freq: 5.5, carrier: "417/210.42", type: "isochronic", vol: "65/90", purpose: "Primary euphoric contraction support without expulsion" },
      { freq: 2.5, carrier: "157.43/140.28", type: "isochronic", vol: "50/70", purpose: "Parasympathetic dominance" },
      { freq: 9.5, carrier: "285/174", type: "isochronic", vol: "20/30", purpose: "Cortical presence, prevention of autonomic drop-through" }
    ]
  },
  {
    name: "Spot: Internal Focus",
    layers: [
      { freq: 9.5, carrier: "285/174", type: "isochronic", vol: "60/80", purpose: "Calm presence without goals or expectations" },
      { freq: 7.83, carrier: "210.42/187.87", type: "isochronic", vol: "55/80", purpose: "Emotional coherence & safety" },
      { freq: 5.5, carrier: "417/210.42", type: "isochronic", vol: "55/65", purpose: "Early pelvic interoceptive mapping" }
    ]
  },
  {
    name: "Spot: Wave Expansion",
    layers: [
      { freq: 5.5, carrier: "417/210.42", type: "isochronic", vol: "65/85", purpose: "After attention effortlessly internal" },
      { freq: 4.5, carrier: "174/157.43", type: "isochronic", vol: "50/75", purpose: "breath effortlessly slow" },
      { freq: 2.8, carrier: "157.43/140.28", type: "isochronic", vol: "40/60", purpose: "pelvic tone neutral/available, sensation can expand without goal or urgency" }
    ]
  },
  {
    name: "Spot: Surrender",
    layers: [
      { freq: 5.5, carrier: "417/210.42", type: "isochronic", vol: "60/75", purpose: "After circulating without buildup" },
      { freq: 2.5, carrier: "157.43/140.28", type: "isochronic", vol: "60/75", purpose: "pelvic floor & breath spontaneous" },
      { freq: 0.75, carrier: "396/175.35", type: "isochronic", vol: "45/75", purpose: "Orgasmic surrender, deep parasympathetic release" }
    ]
  },
  {
    name: "HFDO Surrender",
    layers: [
      { freq: 5.5, carrier: "417/210.42", type: "isochronic", vol: "60/80", purpose: "Pelvic sensory mapping, interoception" },
      { freq: 7.83, carrier: "210.42/187.87", type: "isochronic", vol: "35/50", purpose: "Awareness anchor, cortical-limbic bridge" },
      { freq: 2.5, carrier: "157.43/140.28", type: "isochronic", vol: "65/90", purpose: "Parasympathetic surrender, body melting" },
      { freq: 0.5, carrier: "396/175.35", type: "isochronic", vol: "45/60", purpose: "Primal embodiment, energetic wave support" }
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
    params[`noi${i}`] = 0;
    params[`bil${i}`] = 0;
    params[`fm${i}`] = 0;

    // Carrier frequency handling
    const carrierStr = String(layer.carrier);
    if (carrierStr.includes('/')) {
      // Split carrier frequency for headphones/speakers
      const [carH, carS] = carrierStr.split('/').map(Number);
      params[`car${i}`] = outputType === 'headphones' ? carH : carS;
    } else {
      // Single carrier frequency value
      params[`car${i}`] = Number(layer.carrier);
    }

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

window.PRESET_TONES = PRESET_TONES;
window.generatePresetParams = generatePresetParams;
