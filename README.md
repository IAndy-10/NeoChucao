# NeoChucao

**One instrument, two navigators, same latent space.** A real-time SuperCollider instrument built on the 16-dimensional latent space of a pre-trained [RAVE](https://github.com/acids-ircam/RAVE) model (`birds.ts`, z0–z15). It can be played in two ways, as two separate modes. You pick one per session:

- **MIDI keyboard**: precise and performer-controlled. Notes, velocity and mod wheel set coordinates, and an XY pad sends each note along a looping trajectory through the remaining dimensions.
- **AI agent via [ClaudeCollider](https://github.com/jeremyruppel/claude-collider) (MCP)**: driven by language and exploratory. You describe a direction, Claude writes the patterns, and you hear where in the space it lands.

## Demo

**MIDI performance**

[![NeoChucao demo](https://img.youtube.com/vi/At6OtB0Dt7w/maxresdefault.jpg)](https://www.youtube.com/watch?v=At6OtB0Dt7w)

**Agent session**

[![NeoChucao agent demo](https://img.youtube.com/vi/QfZsKgdYTX4/maxresdefault.jpg)](https://www.youtube.com/watch?v=QfZsKgdYTX4)

You can also listen to a recorded session: [`agent/example.wav`](agent/example.wav).

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
agent/      ClaudeCollider boot file, agent rules (CLAUDE.md), MCP config, recorded session
  claude-collider/   ClaudeCollider MCP server (git submodule, pinned)
examples/   Standalone patches: D Dorian generative bed, RAVE timbre transfer (1 model, 2 models, mic input)
models/     Where birds.ts goes (not tracked)
```

## Quick start

NeoChucao has **two independent modes**, and you choose which one to run. Both play the same RAVE model, but each is a separate setup with its own entry point. They do not run together.

| | MIDI mode | Agent mode |
|---|---|---|
| You play it with | A MIDI keyboard + GUI XY pad | Natural-language prompts to Claude |
| Entry point | [`midi/rave_midi_filter.scd`](midi/rave_midi_filter.scd) | [`agent/boot.scd`](agent/boot.scd) + Claude Code |
| Needs | SuperCollider, nn.ar, `birds.ts` | The same, plus Node.js 18+, ClaudeCollider and Claude Code |
| Setup | `./setup.sh --midi` | `./setup.sh` |

### 1. Install

```bash
git clone --recurse-submodules https://github.com/IAndy-10/NeoChucao.git
cd NeoChucao
./setup.sh          # both modes (needs Node.js 18+)
./setup.sh --midi   # MIDI mode only: skips ClaudeCollider and Node.js
```

Those commands are all you need. If you cloned without `--recurse-submodules`, `./setup.sh` fetches the submodule for you. Use `git clone`, not GitHub's "Download ZIP": the ZIP does not include the `agent/claude-collider` submodule, so agent mode will not work from it.

`setup.sh` installs [nn.ar](https://github.com/elgiano/nn.ar) if it is missing and downloads the RAVE `birds` model (138 MB) into `models/`. Without `--midi`, it also builds [ClaudeCollider](https://github.com/jeremyruppel/claude-collider) (a git submodule at `agent/claude-collider`) and links its classes into your SuperCollider Extensions folder. It is safe to re-run, and you can run plain `./setup.sh` later to add agent mode. Restart SuperCollider afterwards.

### 2. Choose a mode

- **MIDI mode**: open `midi/rave_midi_filter.scd` in the SuperCollider IDE and run blocks 1 → 2 → 3. See [`midi/README.md`](midi/README.md).
- **Agent mode**: `cd agent && claude`, then run `agent/boot.scd` when Claude asks. See [`agent/README.md`](agent/README.md).

### 3. Switching modes

Run one mode at a time. Both use the same SuperCollider audio server.

- **MIDI → agent:** run **Block 4** to free the MIDI handlers, then follow the agent session order. `agent/boot.scd` kills the running server itself.
- **Agent → MIDI:** ask Claude to stop everything, quit Claude, then restart SuperCollider (or run `Server.killAll;`) before Block 1. Otherwise MIDI mode starts on ClaudeCollider's server.

Optional: in MIDI mode, run [`examples/d_dorian_dark.scd`](examples/d_dorian_dark.scd) as a dark rhythmic bed under the instrument. Do not use it in agent mode. There, only Claude should create sounds on the server.

## Iterations

**Max/MSP.** The first attempt drove RAVE directly in Max with the `nn~` object. Max version and license issues stopped it.

**Python + Supriya.** `mido` for MIDI, a custom latent mapper, and `supriya` controlling a SuperCollider server that hosted the decoder. It worked, but development time went into infrastructure (OSC routing, async scheduling, process management) rather than the instrument. Archived on the [`python+supriya_architecture`](https://github.com/IAndy-10/NeoChucao/tree/python%2Bsupriya_architecture) branch.

**Native SuperCollider.** Everything moved into a single `.scd`: MIDI, latent mapping, SynthDef, GUI. Without the Python layer, iteration happened at the musical level. A PCA showed the first three latent dimensions to be the most significant, so they got direct controls (note → `z0`, velocity → `z1`, mod wheel → `z2`). A compressor and chorus smooth the decoder's warm-up swells and timbral wobble.

**Latent trajectory / XY pad.** The remaining 13 dimensions first got static or jittered random values per note. They now follow a smooth closed loop: 8 waypoints per note, ordered by a nearest-neighbour TSP pass and interpolated with a Catmull-Rom spline. A GUI XY pad sets the loop's radius and speed, so a held note evolves instead of sitting still.

**Agent via ClaudeCollider.** A second way into the same space: a SynthDef on scsynth exposes pitch/energy/timbre/radius/speed as pattern parameters, and Claude plays it through ClaudeCollider's MCP server. It is useful for exploring quickly and finding regions worth taking back to the keyboard.

## LLM use

Built with Claude Code (Claude Sonnet 4.6 and Claude Opus 4.6, as noted in the `.scd` file headers). The repo restructure, `setup.sh`, the ClaudeCollider submodule integration and the docs were done with Claude Code (Claude Opus 5.5) and tested in SuperCollider. Claude generated the initial SynthDef structure, MIDI routing boilerplate, latent mapping and trajectory helpers, the compressor/chorus chain and the GUI scaffolding, and helped debug the decoder warm-up latency. The workflow was iterative: prompt → generated code → test in SuperCollider → targeted fix. Generated code always needed checking in the actual runtime, since several idioms were plausible but subtly wrong. The musical decisions were made by hand: which dimensions to expose, playable ranges, and how much motion keeps it interesting without becoming uncontrollable. In `agent/`, an LLM is also part of the instrument itself. See [`agent/README.md`](agent/README.md).

## Credits

- **RAVE**: Antoine Caillon & Philippe Esling, [IRCAM / ACIDS](https://github.com/acids-ircam/RAVE)
- **nn.ar / nn_tilde**: [nn.ar](https://github.com/elgiano/nn.ar) (Gianluca Elia), based on [nn_tilde](https://github.com/acids-ircam/nn_tilde) (Antoine Caillon)
- **birds model**: [Intelligent Instruments Lab](https://huggingface.co/Intelligent-Instruments-Lab/rave-models)
- **SuperCollider**: James McCartney and contributors
- **ClaudeCollider**: [Jeremy Ruppel](https://github.com/jeremyruppel/claude-collider)

## License

[MIT](LICENSE) © 2026 Italo Rojas
