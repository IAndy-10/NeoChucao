# NeoChucao

**One instrument, two navigators, same latent space.** A real-time SuperCollider instrument built on the 16-dimensional latent space of a pre-trained [RAVE](https://github.com/acids-ircam/RAVE) model (`birds.ts`, z0–z15). It can be played in two ways:

- **MIDI keyboard**: precise and performer-controlled. Notes, velocity and mod wheel set coordinates, and an XY pad sends each note along a looping trajectory through the remaining dimensions.
- **AI agent via [ClaudeCollider](https://github.com/jeremyruppel/claude-collider) (MCP)**: driven by language and exploratory. You describe a direction, Claude writes the patterns, and you hear where in the space it lands.

## Demo

**MIDI performance**

[![NeoChucao demo](https://img.youtube.com/vi/At6OtB0Dt7w/maxresdefault.jpg)](https://www.youtube.com/watch?v=At6OtB0Dt7w)

**Agent session**

> TODO: agent demo video coming soon. Meanwhile, listen to [`agent/example.wav`](agent/example.wav).

## MIDI vs Agent

| | MIDI keyboard ([`midi/`](midi)) | AI agent ([`agent/`](agent)) |
|---|---|---|
| **Control source** | Keys, velocity, mod wheel, GUI XY pad | Natural-language prompts → Claude → `Pbind` patterns |
| **Precision** | Direct: every gesture maps to a latent coordinate | Indirect: you describe intent, the agent picks parameters |
| **Latency** | Real time, playable | Seconds per change (prompt → code → sound) |
| **Good for** | Performing; fine control once you know where the expressive regions are | Finding starting points: surveying a space where some regions are expressive and some are dead |
| **Performer controls** | Everything, moment to moment | Direction and taste: steers, accepts or rejects, stops |
| **Status** | Main instrument | Experimental |

Both drive the same decoder (`NN(\birds, \decode)`) with the same core mapping: pitch → `z0`, energy → `z1`, timbre → `z2`, and motion through `z3–z15`.

## Repo layout

```
midi/       MIDI keyboard instrument (rave_midi_filter.scd) + mapping docs
agent/      ClaudeCollider boot file, agent rules (CLAUDE.md), MCP config example, recorded session
examples/   Standalone patches: D Dorian generative bed, RAVE timbre transfer (1 model, 2 models, mic input)
models/     Where birds.ts goes (not tracked)
```

## Quick start

1. Install [SuperCollider](https://supercollider.github.io) and [nn.ar](https://github.com/elgiano/nn.ar) (arm64 release into your SC Extensions folder).
2. Download the model: see [`models/`](models/README.md).
3. Pick a navigator:
   - **MIDI**: open `midi/rave_midi_filter.scd`, run blocks 1 → 2 → 3. See [`midi/README.md`](midi/README.md).
   - **Agent**: set up ClaudeCollider, connect Claude, then run `agent/boot.scd`. See [`agent/README.md`](agent/README.md).
4. Optional: run [`examples/d_dorian_dark.scd`](examples/d_dorian_dark.scd) as a dark rhythmic bed under the instrument.

## Iterations

**Max/MSP.** The first attempt drove RAVE directly in Max with the `nn~` object. Max version and license issues stopped it.

**Python + Supriya.** `mido` for MIDI, a custom latent mapper, and `supriya` controlling a SuperCollider server that hosted the decoder. It worked, but development time went into infrastructure (OSC routing, async scheduling, process management) rather than the instrument. Archived on the [`python+supriya_architecture`](https://github.com/IAndy-10/NeoChucao/tree/python%2Bsupriya_architecture) branch.

**Native SuperCollider.** Everything moved into a single `.scd`: MIDI, latent mapping, SynthDef, GUI. Without the Python layer, iteration happened at the musical level. A PCA showed the first three latent dimensions to be the most significant, so they got direct controls (note → `z0`, velocity → `z1`, mod wheel → `z2`). A compressor and chorus smooth the decoder's warm-up swells and timbral wobble.

**Latent trajectory / XY pad.** The remaining 13 dimensions first got static or jittered random values per note. They now follow a smooth closed loop: 8 waypoints per note, ordered by a nearest-neighbour TSP pass and interpolated with a Catmull-Rom spline. A GUI XY pad sets the loop's radius and speed, so a held note evolves instead of sitting still.

**Agent via ClaudeCollider.** A second way into the same space: a SynthDef on scsynth exposes pitch/energy/timbre/radius/speed as pattern parameters, and Claude plays it through ClaudeCollider's MCP server. It is useful for exploring quickly and finding regions worth taking back to the keyboard.

## LLM use

Built with Claude Code (Claude Sonnet 4.6 and Claude Opus 4.6, as noted in each file header). Claude generated the initial SynthDef structure, MIDI routing boilerplate, latent mapping and trajectory helpers, the compressor/chorus chain and the GUI scaffolding, and helped debug the decoder warm-up latency. The workflow was iterative: prompt → generated code → test in SuperCollider → targeted fix. Generated code always needed checking in the actual runtime, since several idioms were plausible but subtly wrong. The musical decisions were made by hand: which dimensions to expose, playable ranges, and how much motion keeps it interesting without becoming uncontrollable. In `agent/`, an LLM is also part of the instrument itself. See [`agent/README.md`](agent/README.md).

## Credits

- **RAVE**: Antoine Caillon & Philippe Esling, [IRCAM / ACIDS](https://github.com/acids-ircam/RAVE)
- **nn.ar / nn_tilde**: [nn.ar](https://github.com/elgiano/nn.ar) (Gianluca Elia), based on [nn_tilde](https://github.com/acids-ircam/nn_tilde) (Antoine Caillon)
- **birds model**: [Intelligent Instruments Lab](https://huggingface.co/Intelligent-Instruments-Lab/rave-models)
- **SuperCollider**: James McCartney and contributors
- **ClaudeCollider**: [Jeremy Ruppel](https://github.com/jeremyruppel/claude-collider)

## License

[MIT](LICENSE) © 2026 Italo Rojas
