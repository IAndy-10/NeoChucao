# MIDI navigator

Play the RAVE `birds` latent space from a MIDI keyboard. Polyphonic, real time, every gesture under the performer's hands.

## Prerequisites

- [SuperCollider](https://supercollider.github.io)
- [nn.ar](https://github.com/elgiano/nn.ar): install the arm64 release into your SC Extensions folder
- `birds.ts` in [`../models/`](../models/README.md)
- Any class-compliant MIDI keyboard (mod wheel optional)

## Run

Open `rave_midi_filter.scd` in the SuperCollider IDE and run each block in order (place the cursor inside the block → `Cmd+Enter`):

| Block | What it does |
|---|---|
| **1** | Boots the server, loads `../models/birds.ts`, defines the `\rave_midi` SynthDef and the trajectory helpers. Wait for `Ready.` |
| **2** | Connects all MIDI inputs and starts the voice manager (note on/off, CC). |
| **3** | Opens the GUI: XY pad for the trajectory plus sliders. Optional, and can be reopened at any time. |
| **4** | Stops all trajectories, releases all voices, frees MIDI handlers. |

### Audio device

The device lines in Block 1 are commented out, so SuperCollider uses the system default. To use a specific interface, uncomment and set your own names:

```supercollider
s.options.inDevice_("Your Input Device");
s.options.outDevice_("Your Output Device");
```

`ServerOptions.devices.postln;` lists the available names.

## Mapping

| Input | Latent target | Range / behaviour |
|---|---|---|
| Note number | `z0` | Notes 36–96 → `[-latentRange, +latentRange]` (default ±2), linear |
| Velocity | `z1` | 0–127 → `[-latentRange, +latentRange]`; also scales voice amplitude (`vel/127 × 0.8`) |
| Mod wheel (CC 1) | `z2` | 0–127 → `[-latentRange, +latentRange]`, pushed to all active voices. Defaults to centre (64) |
| XY pad, X | trajectory **radius** in `z3–z15` | 0 – 3.0. At 0 the trajectory is off and `z3–z15` stay at 0 |
| XY pad, Y | trajectory **speed** | 0 – 2.0 Hz (loops per second) |

### Latent trajectory (z3–z15)

Every held note follows its own closed loop through the remaining 13 dimensions:

1. At boot, each of the 128 MIDI notes gets 8 random Gaussian waypoints in 13-D (fixed for the session, so a key keeps its character until you re-run Block 1).
2. The waypoints are ordered into a short closed loop with a nearest-neighbour TSP pass.
3. A Catmull-Rom spline is evaluated through them at 30 Hz, scaled by the radius, and sent to the voice.

The XY pad sets how far from the origin the loop reaches (radius) and how fast it is traversed (speed). Both changes apply to all held notes immediately.

### GUI sliders (Block 3)

| Slider | Effect |
|---|---|
| Mod wheel (z2) | Same as CC 1, for keyboards without a mod wheel |
| Latent range | Scale of the note/velocity/CC → latent mapping (0.5 – 3.0). Applies to new notes |
| Comp threshold | Compander threshold on active voices |
| Chorus mix | Dry/wet of the 3-voice chorus |
| Reverb mix | FreeVerb2 mix |

## Signal chain

```
latent[16] (Lag 10 ms)
   → NN(\birds, \decode).ar(latent, 2048)
   → ADSR envelope × amp          (atk 0.02 s, rel 1.5 s)
   → Compander                    (thresh 0.4, slopeAbove 0.3, 10 / 100 ms)
   → 3-voice chorus               (DelayL 15 ms ± 3 ms, LFOs 0.15–0.22 Hz, 120° apart)
   → FreeVerb2                    (mix 0.3, room 0.7, damp 0.5)
   → Out (stereo)
```

The compressor smooths onset swells from the decoder warming up. The chorus hides leftover timbral wobble.
