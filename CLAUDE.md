# NeoChucao: Claude Code instructions

A real-time SuperCollider instrument that plays the 16-dim latent space (z0–z15) of the RAVE `birds` model. It has two independent modes that the user chooses between: **MIDI mode** and **agent mode** (Claude via ClaudeCollider MCP).

> **Performance session?** If you were launched from `agent/` to make music, follow [`agent/CLAUDE.md`](agent/CLAUDE.md). It takes precedence there. This file is for developing the repo.

## Layout

```
midi/rave_midi_filter.scd   MIDI mode: 4 blocks (1 boot+SynthDef \rave_midi, 2 MIDI, 3 GUI/XY pad, 4 stop)
agent/boot.scd              Agent mode: CC.boot, NN.load, SynthDef \rave_birds, writes /tmp/rave_synthdef.sc
agent/CLAUDE.md             Rules for Claude during a performance session
agent/.mcp.json             Registers ClaudeCollider from the submodule (relative path, launch from agent/)
agent/.claude/settings.json Enables that MCP server
agent/claude-collider/      ClaudeCollider (third-party, git submodule, pinned)
examples/                   Standalone patches (generative bed, RAVE timbre transfer)
models/                     RAVE .ts models, git-ignored except README.md
setup.sh                    One-step install (--midi, --extras)
```

## Invariants

- **The two modes are independent.** Each runs on its own and the user picks one. Never couple them: no shared engine, and MIDI mode must not depend on ClaudeCollider, Node.js or anything in `agent/`. Both use the same scsynth, so they never run at the same time. Docs must keep saying so.
- **Same latent mapping in both modes:** pitch → z0, energy (velocity / `\amp`) → z1, timbre (mod wheel / `\timbre`) → z2, and a moving trajectory through z3–z15. If you change the mapping in one mode, update the other mode or document the difference, and update the mapping tables in the READMEs.
- **The server runs at 44.1 kHz.** `NN.ar` goes silent at 48 kHz. `agent/boot.scd` sets `sampleRate = 44100`. `midi/rave_midi_filter.scd` does not, and relies on the device default (see Known gaps).
- **In agent mode, only ClaudeCollider creates nodes.** The IDE's sclang must not create synths during a session, to avoid node ID collisions. That rules out `examples/d_dorian_dark.scd` and any other patch that plays sound.
- **Models are never committed.** `birds.ts` is 138 MB, over GitHub's 100 MB limit. `setup.sh` downloads it from Hugging Face (Intelligent-Instruments-Lab/rave-models).
- **Agent mode uses two sclang processes.** The SC IDE's sclang runs `boot.scd`; ClaudeCollider's MCP server runs its own sclang. They share only scsynth, so the SynthDef on the server is the interface between them. Do not add bus/Ndef routing between the processes, and do not call `NN.load` from `cc_execute`.
- **The submodule is read-only.** Never edit files under `agent/claude-collider/`. To update it: `git -C agent/claude-collider pull origin main`, re-run `./setup.sh`, re-verify (see below), then commit the new submodule pointer. If ClaudeCollider renames something (for example `\cc_hat` became `\cc_hihat`), fix `agent/CLAUDE.md`.
- **Do not commit local config:** the root `/.mcp.json` and `.claude/settings.local.json`. `agent/.mcp.json` and `agent/.claude/settings.json` are tracked on purpose.

## Setup

```bash
git submodule update --init --recursive
./setup.sh          # both modes
./setup.sh --midi   # MIDI mode only
```

`setup.sh` symlinks `agent/claude-collider/ClaudeCollider` into the SuperCollider Extensions folder and installs nn.ar there if it is missing. Restart SuperCollider (or `Cmd+Shift+L`) afterwards. Keep `setup.sh` idempotent: every step must be skippable when it is already done.

## Verifying changes

Claude cannot hear audio, so verify headlessly. Use `/Applications/SuperCollider.app/Contents/MacOS/sclang` (it is not on PATH). Put test scripts in a scratch directory, never in the repo. Then tell the user what still needs an audible test (MIDI keyboard, GUI, a live agent session).

- **MCP server:** pipe `initialize` + `tools/list` JSON-RPC into `node agent/claude-collider/dist/index.js` from `agent/`. It should list 9 `cc_*` tools.
- **Agent boot:** `.load` `agent/boot.scd` in a script, wait for `/tmp/rave_synthdef.sc`, then check `NN.models` contains `birds` and `s.sampleRate == 44100`.
- **RAVE output:** play the SynthDef to a private bus (for example `\out, 100`, so nothing reaches the speakers), measure it with `Peak.ar` + `SendReply`, and expect a peak > 0.
- **MIDI Block 1:** wrap the body of Block 1 in a function, set `thisProcess.nowExecutingPath` to `midi/rave_midi_filter.scd` so the relative model path resolves, run it, and expect `Ready.` and `\rave_midi` in `SynthDescLib`.
- Always end test scripts with `Server.killAll; 0.exit`, and kill leftover `scsynth` processes.

## Conventions

- Docs, code comments and commit messages are in **English**.
- Commit messages: imperative present tense ("Add …", "Fix …"), no `feat:` prefixes. End each one with the co-author trailer.
- `.scd` files keep their header comment (file path, what it does, how to run) and, where present, the `LLM used:` line. Update that line when Claude makes substantial changes to a file.
- The root README has a "LLM use" section. Keep it accurate when the workflow changes.
- Audio devices stay commented out in the `.scd` files (system default) so the repo works for anyone who clones it.
- In SuperCollider, never use `s.freeAll` in agent mode, because it kills ClaudeCollider's limiter/output chain. Use `Pdef(\x).stop` or `~cc.stop`.

## Known gaps

- ClaudeCollider's effects (`cc_fx` / `~cc.fx`) do not work in agent mode: they route the pattern to a private bus (seen: bus 8) and the audio never reaches the output. `agent/CLAUDE.md` forbids them. A future fix could add reverb/delay inside `\rave_birds` in `boot.scd`, as SynthDef parameters, so no routing between the sclang processes is needed.
- MIDI mode does not set `s.options.sampleRate = 44100`, so it goes silent on an interface that defaults to 48 kHz.
- **Sample rate mismatch:** `birds.ts` is `birds_motherbird_b2048_r48000_z16.ts`, trained at 48 kHz, but the project runs at 44.1 kHz. The server rate should match the model. This is documented as a warning only. Resolving it (running at 48 kHz and finding out why that was silent) needs code changes and a listening test.
- `wheel.ts`, used by `examples/rave_single_model.scd` and `examples/rave_mic_input.scd`, has no known download source.
