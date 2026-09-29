/*
  NeoChucao — rave_midi.scd
  ══════════════════════════
  MIDI keyboard → latent space → RAVE birds.ts decoder → audio.

  Runtime controls:
    Mod wheel (CC 1) → z2 (timbre morph), pushed to all active voices
    XY Pad           → trajectory radius (X) and speed (Y) for z3–z15

  Each held note continuously traverses a smooth looping trajectory
  through latent dimensions z3–z15, creating evolving timbre.

  Blocks:
    1   — Boot server, load model, define SynthDef + trajectory helpers
    2   — Connect MIDI keyboard, start playing
    3   — Open GUI controls (with XY pad)
    4   — Stop everything (MIDI + voices)

LLM used: Claude Code - Claude Opus 4.6
*/
s.boot

// ════════════════════════════════════════════════════════
// BLOCK 1 — Boot, load model, define SynthDef
// Run once per session. Wait for "Ready." before Block 2.
// ════════════════════════════════════════════════════════
(
s.options.memSize = 65536;
//s.options.numInputBusChannels  = 1;
s.options.numOutputBusChannels = 2;
s.options.inDevice_("MacBook Air Microphone");
//s.options.outDevice_("MacBook Air Speakers");
s.options.outDevice_("External Headphones");
s.latency = 0.05;
s.waitForBoot {

    // ── Load RAVE model ───────────────────────────────────
    NN.load(\birds, PathName(thisProcess.nowExecutingPath).pathOnly +/+ "/models/birds.ts");
    s.sync;
    NN(\birds).describe;

    // ── SynthDef ──────────────────────────────────────────
    SynthDef(\rave_midi, { |
        gate = 1, amp = 0.5,
        atk  = 0.02, dec = 0.1, sus = 0.9, rel = 1.5,
        z0  = 0, z1  = 0, z2  = 0, z3  = 0,
        z4  = 0, z5  = 0, z6  = 0, z7  = 0,
        z8  = 0, z9  = 0, z10 = 0, z11 = 0,
        z12 = 0, z13 = 0, z14 = 0, z15 = 0,
        compThresh = 0.4, compRatio = 0.3,
        chMix = 0.4,
        rvMix = 0.3, rvRoom = 0.7, rvDamp = 0.5 |

        var latent = [z0, z1, z2, z3, z4, z5, z6, z7,
                      z8, z9, z10, z11, z12, z13, z14, z15]
                        .collect({ |z| Lag.kr(z, 0.01) });
        var sig = NN(\birds, \decode).ar(latent, 2048);
        var env = EnvGen.kr(
            Env.adsr(atk, dec, sus, rel),
            gate:       gate,
            doneAction: 2
        );
        var dry  = sig * env * amp;

        // Compressor
        var comp = Compander.ar(dry, dry,
            thresh:     compThresh,
            slopeBelow: 1.0,
            slopeAbove: compRatio,
            clampTime:  0.01,
            relaxTime:  0.1
        );

        // Chorus
        var chorus = Mix.fill(3, { |i|
            var rate = [0.18, 0.22, 0.15][i];
            var phase = [0, 2.09, 4.19][i];
            var mod  = SinOsc.kr(rate, phase) * 0.003;
            DelayL.ar(comp, 0.05, 0.015 + mod)
        }) / 3;
        var chorused = (comp * (1 - chMix)) + (chorus * chMix);

        // Reverb
        var wet = FreeVerb2.ar(chorused, chorused, mix: rvMix, room: rvRoom, damp: rvDamp);
        Out.ar(0, wet);
    }).add;
    s.sync;

    // ── Latent mapping ──────────────────────────────────
    ~noteMin     = 36;
    ~noteMax     = 96;
    ~latentRange = 2.0;
    ~trajRadius  = 0.0;   // XY pad X — how wide the trajectory orbit is
    ~trajSpeed   = 0.5;   // XY pad Y — how fast the trajectory is traversed (Hz)
    ~ccState     = Dictionary.new;
    ~voices      = Dictionary.new;  // MIDI note → Synth
    ~routines    = Dictionary.new;  // MIDI note → Routine

    // ── Waypoints per note ──────────────────────────────
    // 8 random waypoints in 13D (z3–z15), unit-normalized.
    // Actual amplitude is scaled by ~trajRadius at runtime.
    ~numWaypoints = 8;
    ~noteWaypoints = Array.fill(128, {
        var pts = Array.fill(~numWaypoints, { Array.fill(13, { gauss(0, 1) }) });
        pts
    });

    // ── Nearest-neighbor TSP sort ───────────────────────
    // Orders waypoints into a short closed loop.
    ~tspSort = { |points|
        var n = points.size;
        var visited = Array.fill(n, { false });
        var order = Array.newClear(n);
        var current = 0;
        visited[current] = true;
        order[0] = current;
        (n - 1).do { |step|
            var bestDist = inf;
            var bestIdx  = 0;
            n.do { |j|
                var dist = 0;
                if (visited[j].not) {
                    points[current].size.do { |d|
                        dist = dist + ((points[current][d] - points[j][d]).squared);
                    };
                    if (dist < bestDist) {
                        bestDist = dist;
                        bestIdx  = j;
                    };
                };
            };
            current = bestIdx;
            visited[current] = true;
            order[step + 1] = current;
        };
        order.collect { |i| points[i] };
    };

    // Sort all note waypoints via TSP
    128.do { |note|
        ~noteWaypoints[note] = ~tspSort.(~noteWaypoints[note]);
    };

    // ── Catmull-Rom spline interpolation ────────────────
    // Returns a 13D point on the closed spline at parameter t (0–1).
    ~catmullRom = { |points, t|
        var n = points.size;
        var scaled = t * n;
        var i = scaled.floor.asInteger % n;
        var frac = scaled - scaled.floor;
        // 4 control points wrapping around
        var p0 = points[(i - 1) % n];
        var p1 = points[i % n];
        var p2 = points[(i + 1) % n];
        var p3 = points[(i + 2) % n];
        var t2 = frac * frac;
        var t3 = t2 * frac;
        // Catmull-Rom matrix multiply per dimension
        points[0].size.collect { |d|
            var a0 = p0[d], a1 = p1[d], a2 = p2[d], a3 = p3[d];
            0.5 * (
                (2 * a1) +
                (a2 - a0) * frac +
                (2*a0 - 5*a1 + 4*a2 - a3) * t2 +
                (a0.neg + 3*a1 - 3*a2 + a3) * t3
            );
        };
    };

    // Map MIDI value [lo, hi] → [-latentRange, +latentRange]
    ~midiToZ = { |value, lo = 0, hi = 127|
        var t = ((value - lo) / (hi - lo)).clip(0, 1);
        ~latentRange.neg + (t * ~latentRange * 2);
    };

    // Build the initial 16-element latent array (z3–z15 start at spline t=0)
    ~buildLatent = { |note, vel|
        var z = Array.newClear(16);
        var pt = ~catmullRom.(~noteWaypoints[note], 0);
        z[0]  = ~midiToZ.(note, ~noteMin, ~noteMax);
        z[1]  = ~midiToZ.(vel);
        z[2]  = ~midiToZ.(~ccState.at(1) ?? { 64 });
        13.do { |i| z[i + 3] = pt[i] * ~trajRadius };
        z
    };

    // Spawn a trajectory routine for a voice
    ~spawnTrajectory = { |note, synth|
        var phase = 0.0;
        var dt = 1 / 30; // 30 Hz update rate
        var routine = Routine({
            var radius, speed, pt;
            loop {
                radius = ~trajRadius;
                if (radius > 0) {
                    speed = ~trajSpeed.max(0.01);
                    pt = ~catmullRom.(~noteWaypoints[note], phase);
                    synth.set(
                        \z3,  pt[0]  * radius, \z4,  pt[1]  * radius,
                        \z5,  pt[2]  * radius, \z6,  pt[3]  * radius,
                        \z7,  pt[4]  * radius, \z8,  pt[5]  * radius,
                        \z9,  pt[6]  * radius, \z10, pt[7]  * radius,
                        \z11, pt[8]  * radius, \z12, pt[9]  * radius,
                        \z13, pt[10] * radius, \z14, pt[11] * radius,
                        \z15, pt[12] * radius
                    );
                    phase = (phase + (speed * dt)) % 1.0;
                };
                dt.wait;
            };
        }).play(AppClock);
        routine
    };

    "Ready. Run Block 2 to connect MIDI.".postln;
};
)


// ════════════════════════════════════════════════════════
// BLOCK 2 — Connect MIDI, start playing
// ════════════════════════════════════════════════════════
(
MIDIClient.init;
MIDIIn.connectAll;

// ── Note on ───────────────────────────────────────────────
MIDIdef.noteOn(\noteOn, { |vel, note|
    var z, synth;

    // note_on with vel=0 is a note_off on some keyboards
    if (vel == 0) {
        ~routines[note] !? { |r| r.stop; ~routines.removeAt(note) };
        ~voices[note] !? { |v| v.set(\gate, 0); ~voices.removeAt(note) };
    } {
        z = ~buildLatent.(note, vel);
        // Release any existing voice on this pitch first
        ~routines[note] !? { |r| r.stop; ~routines.removeAt(note) };
        ~voices[note] !? { |v| v.set(\gate, 0) };
        synth = Synth(\rave_midi, [
            \amp, (vel / 127) * 0.8,
            \z0,  z[0],  \z1,  z[1],  \z2,  z[2],  \z3,  z[3],
            \z4,  z[4],  \z5,  z[5],  \z6,  z[6],  \z7,  z[7],
            \z8,  z[8],  \z9,  z[9],  \z10, z[10], \z11, z[11],
            \z12, z[12], \z13, z[13], \z14, z[14], \z15, z[15],
        ]);
        ~voices[note] = synth;
        ~routines[note] = ~spawnTrajectory.(note, synth);
        ("note_on  note=" ++ note ++ " vel=" ++ vel
            ++ "  z0=" ++ z[0].round(0.01)
            ++ " z1=" ++ z[1].round(0.01)).postln;
    };
});

// ── Note off ──────────────────────────────────────────────
MIDIdef.noteOff(\noteOff, { |vel, note|
    ~routines[note] !? { |r| r.stop; ~routines.removeAt(note) };
    ~voices[note] !? { |v|
        v.set(\gate, 0);
        ~voices.removeAt(note);
    };
    ("note_off note=" ++ note).postln;
});

// ── CC ────────────────────────────────────────────────────
MIDIdef.cc(\cc, { |val, num|
    var z2;
    ~ccState[num] = val;

    // CC 1 — mod wheel → z2, pushed to all active voices
    if (num == 1) {
        z2 = ~midiToZ.(val);
        ~voices.do { |v| v.set(\z2, z2) };
        ("mod wheel  z2=" ++ z2.round(0.01)).postln;
    };
});

"MIDI connected — play your keyboard.".postln;
"  Mod wheel (CC 1) → z2 timbre".postln;
"  Run Block 3 for GUI with XY pad.".postln;
)


// ════════════════════════════════════════════════════════
// BLOCK 3 — GUI Controls (with XY Pad)
// Run after Block 2. Can be reopened at any time.
// ════════════════════════════════════════════════════════
(
var bgColor  = Color(0.05, 0.05, 0.08);
var lblColor = Color(0.65, 0.65, 0.85);
var valColor = Color(0.85, 0.85, 1.0);
var padColor = Color(0.08, 0.08, 0.15);
var dotColor = Color(0.6, 0.75, 1.0);
var fnt      = Font("Monaco", 11);
var win, makeRow;
var padSize = 180, padX = 110, padY = 20;
var xyView, xLabel, yLabel, xyAction;
var sliderTop;

win = Window("NeoChucao Controls", Rect(100, 100, 400, 500))
    .background_(bgColor)
    .front;

// Helper — one labelled slider row.
makeRow = { |label, y, initVal, lo, hi, action|
    var valLabel, sl;

    StaticText(win, Rect(10, y, 140, 24))
        .string_(label)
        .stringColor_(lblColor)
        .font_(fnt);

    valLabel = StaticText(win, Rect(340, y, 50, 24))
        .string_(initVal.round(0.01).asString)
        .stringColor_(valColor)
        .font_(fnt)
        .align_(\right);

    sl = Slider(win, Rect(155, y + 2, 178, 20))
        .value_((initVal - lo) / (hi - lo))
        .background_(Color(0.12, 0.12, 0.2));

    sl.action_({
        var mapped = lo + (sl.value * (hi - lo));
        valLabel.string_(mapped.round(0.01).asString);
        action.(mapped);
    });

    sl
};

// ── XY Pad for trajectory (radius x speed) ─────────────
StaticText(win, Rect(10, padY, 95, 24))
    .string_("Trajectory")
    .stringColor_(lblColor)
    .font_(fnt);

StaticText(win, Rect(padX, padY + padSize + 4, padSize, 16))
    .string_("< radius >")
    .stringColor_(lblColor.alpha_(0.5))
    .font_(Font("Monaco", 9))
    .align_(\center);

StaticText(win, Rect(padX + padSize + 6, padY, 60, padSize))
    .string_("speed\n  ^\n  |\n  v")
    .stringColor_(lblColor.alpha_(0.5))
    .font_(Font("Monaco", 9));

xyView = UserView(win, Rect(padX, padY, padSize, padSize))
    .background_(padColor)
    .drawFunc_({ |view|
        var x = ~trajRadius / 3.0 * (padSize - 10) + 5;
        var y = (1 - (~trajSpeed / 2.0)) * (padSize - 10) + 5;
        Pen.fillColor = dotColor;
        Pen.addArc(x @ y, 5, 0, 2pi);
        Pen.fill;
        // Crosshairs
        Pen.strokeColor = dotColor.alpha_(0.15);
        Pen.line(x @ 0, x @ padSize);
        Pen.line(0 @ y, padSize @ y);
        Pen.stroke;
    });

xLabel = StaticText(win, Rect(padX, padY - 16, 90, 16))
    .string_("R: 0.00")
    .stringColor_(valColor)
    .font_(Font("Monaco", 9));

yLabel = StaticText(win, Rect(padX + 95, padY - 16, 90, 16))
    .string_("S: 0.50")
    .stringColor_(valColor)
    .font_(Font("Monaco", 9));

xyAction = { |view, mouseX, mouseY|
    var normX = (mouseX / padSize).clip(0, 1);
    var normY = (mouseY / padSize).clip(0, 1);
    ~trajRadius = normX * 3.0;         // 0 to 3.0
    ~trajSpeed  = (1 - normY) * 2.0;   // 0 to 2.0 Hz
    xLabel.string_("R: " ++ ~trajRadius.round(0.01));
    yLabel.string_("S: " ++ ~trajSpeed.round(0.01));
    view.refresh;
};

xyView.mouseDownAction_({ |view, x, y| xyAction.(view, x, y) });
xyView.mouseMoveAction_({ |view, x, y| xyAction.(view, x, y) });

// ── Sliders below the XY pad ───────────────────────────
sliderTop = padY + padSize + 30;

// ── Mod wheel → z2 ─────────────────────────────────────
makeRow.("Mod wheel  (z2)", sliderTop, 0.0, -2.0, 2.0, { |val|
    ~ccState[1] = ((val + 2.0) / 4.0 * 127).round.asInteger;
    ~voices.do { |v| v.set(\z2, val) };
});

// ── Latent range ────────────────────────────────────────
makeRow.("Latent range", sliderTop + 55, 2.0, 0.5, 3.0, { |val|
    ~latentRange = val;
});

// ── Comp threshold ──────────────────────────────────────
makeRow.("Comp threshold", sliderTop + 110, 0.4, 0.1, 1.0, { |val|
    ~voices.do { |v| v.set(\compThresh, val) };
});

// ── Chorus mix ──────────────────────────────────────────
makeRow.("Chorus mix", sliderTop + 165, 0.4, 0.0, 1.0, { |val|
    ~voices.do { |v| v.set(\chMix, val) };
});

// ── Reverb mix ──────────────────────────────────────────
makeRow.("Reverb mix", sliderTop + 220, 0.3, 0.0, 1.0, { |val|
    ~voices.do { |v| v.set(\rvMix, val) };
});
)


// ════════════════════════════════════════════════════════
// BLOCK 4 — Stop
// ════════════════════════════════════════════════════════
(
~routines.do { |r| r.stop };
~routines.clear;
~voices.do { |v| v.set(\gate, 0) };
~voices.clear;
MIDIdef.freeAll;
"Stopped. All voices released, MIDI disconnected.".postln;
)

s.quit;
