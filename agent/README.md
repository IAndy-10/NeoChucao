# Agent navigator (experimental)

Navigate the same RAVE `birds` latent space by talking to Claude. [ClaudeCollider](https://github.com/jeremyruppel/claude-collider) (an MCP server by Jeremy Ruppel) lets Claude write and run SuperCollider code live. `boot.scd` defines a SynthDef that turns pattern parameters into latent coordinates, and Claude writes `Pbind` patterns that play it.

```
You ──→ Claude ──→ ClaudeCollider (MCP) ──→ Pbind(\instrument, \rave_birds) ──→ NN decode ──→ speakers
```

**Authorship:** the agent navigates and proposes, and the performer stays in control. It is a way to explore the latent space by describing a direction in words and hearing where that lands, so you can find regions worth playing. It does not compose a finished piece for you. You steer every step, stop it, and take the results to the MIDI instrument or your own code.

## Setup

From the repo root, run `./setup.sh` once (see the [main README](../README.md#quick-start)). It builds ClaudeCollider from the `claude-collider/` submodule, links its classes into SuperCollider, installs nn.ar and downloads `birds.ts`. You also need [Claude Code](https://claude.com/claude-code) or another MCP client.

Then launch Claude Code from this folder:

```bash
cd agent
claude
```

Everything is already wired up here:
- [`.mcp.json`](.mcp.json) registers ClaudeCollider from the submodule (`claude-collider/dist/index.js`).
- [`.claude/settings.json`](.claude/settings.json) enables that server.
- [`CLAUDE.md`](CLAUDE.md) gives Claude its operating rules.

With another MCP client, point it at `node /absolute/path/to/NeoChucao/agent/claude-collider/dist/index.js`.

The submodule is pinned to a tested ClaudeCollider commit. To try a newer one, run `git -C agent/claude-collider pull origin main` and then `./setup.sh`.

## Session order

> **Agent mode runs on its own.** Do not run it at the same time as [MIDI mode](../midi/README.md). `boot.scd` kills any running SuperCollider server when it starts, so stop MIDI mode (Block 4) first.

The order matters. ClaudeCollider reboots `scsynth` on its first connection, so that reboot has to happen before the model is loaded.

1. **Connect Claude first.** Claude runs a dummy `cc_execute`, which triggers the scsynth reboot on an empty server.
2. **Run `boot.scd`.** Open it in the SuperCollider IDE, select all (`Cmd+A`), run (`Cmd+Enter`). Wait for:
   ```
   ════════════════════════════════════
     NeoChucao agent ready
     Model   : birds
     SynthDef: \rave_birds
     Now talk to Claude.
   ════════════════════════════════════
   ```
3. **Talk.** Claude confirms the boot (it reads a marker file `boot.scd` writes to `/tmp`) and starts playing.

To stop, ask Claude to stop everything, or run `~cc.stop;`. Never use `s.freeAll`, because it permanently kills ClaudeCollider's limiter/output chain.

## What the agent controls

`boot.scd` defines `\rave_birds` on scsynth. SynthDefs live on the server, so ClaudeCollider's separate `sclang` process can use it directly as a `Pbind` instrument with no bus routing.

| Parameter | Default | Latent / effect |
|---|---|---|
| `\freq` | 440 | → `z0` (MIDI 36–96 → −2…+2) |
| `\amp` | 0.5 | → `z1` (0…1 → −2…+2) |
| `\timbre` | 0 | → `z2` directly (−2…+2) |
| `\radius` | 0.5 | Width of the `z3–z15` motion (0 = static) |
| `\speed` | 0.3 | Rate of the `z3–z15` motion |
| `\atk`, `\rel` | 0.01, 0.2 | ASR envelope times (s) |
| `\gain` | 0.8 | Output level |
| `\pan` | 0 | Stereo position |
| `\out` | 0 | Output bus. Keep it at 0: any other bus is silent |

`z3–z15` are driven by 13 `LFDNoise3` generators at slightly different rates, scaled by `speed` and `radius`. That is the agent-side equivalent of the MIDI version's XY-pad trajectory. Claude can also layer ClaudeCollider's built-in drum/bass instruments around it.

**No effects.** ClaudeCollider's effects (`cc_fx` / `~cc.fx`) do not work with this setup: they move the pattern's output to a private bus, and the audio never reaches the speakers. `CLAUDE.md` tells Claude not to use them and to get space from long releases, overlapping layers and stereo panning instead.

## Example prompts

> "Make a slow dark ambient texture using the birds model"

> "Play a Phrygian melody through birds"

> "Make a slow dark ambient texture with the birds model. Notes should be sparse and widely spaced, roughly 7 to 11 beats apart, with a short attack and a quick fade out. Keep the sound noisy and saturated. Add a slow kick, a sparse snare, and a dark bass underneath."

> "Layer two drones a fifth apart, slow attack, wide stereo"

Mid-session:

> "Make it slower and darker"
> "Add a sparse high layer"
> "Stop everything and start something more rhythmic"

## Recorded session

[`example.wav`](example.wav) is a recording of an agent session.

## Troubleshooting

- **Claude says it is playing but you hear nothing:** first check `s.meter;` in the SC IDE. If the output meters are flat, an effect has probably routed the pattern to a private bus. Ask Claude to remove all effects and set `\out, 0` on every pattern.
- **Silence:** this setup runs at 44.1 kHz, and `boot.scd` sets it. (The model was trained at 48 kHz: see the [sample rate warning](../models/README.md).) Check with `s.sampleRate.postln;`, and if it reads 48000, quit SuperCollider, relaunch, and re-run `boot.scd`.
- `cc_status` showing `Server: stopped` is an artifact of the two-sclang setup and can be ignored if audio plays.
- See [`CLAUDE.md`](CLAUDE.md) for the full rules (cc_execute syntax pitfalls, what not to call).
