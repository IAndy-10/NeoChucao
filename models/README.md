# Models

RAVE models (`.ts`, TorchScript) go in this folder. They are not tracked in git.

## Required: `birds.ts`

Both navigators (`midi/` and `agent/`) use the birds model from the Intelligent Instruments Lab. `../setup.sh` downloads it for you (138 MB, too large for git). To do it by hand:

1. Download **[birds_motherbird_b2048_r48000_z16.ts](https://huggingface.co/Intelligent-Instruments-Lab/rave-models/blob/main/birds_motherbird_b2048_r48000_z16.ts)**
2. Rename it to `birds.ts` and place it here:

```
models/
└── birds.ts
```

> **Warning: sample rate mismatch.** The `r48000` in the file name means the model was trained at **48 kHz**, but both modes currently run the server at **44.1 kHz**. It plays at 44.1 kHz, but pitch and timbre may be slightly off from what the model learned. The server's sample rate should match the model's. This has not been fixed or re-tested yet.

## Optional: example models

Some scripts in [`examples/`](../examples) also load `marinemammals.ts` and `wheel.ts`. `../setup.sh --extras` downloads `marinemammals.ts` (`marinemammals_pondbrain_b2048_r48000_z20.ts` from [Intelligent-Instruments-Lab/rave-models](https://huggingface.co/Intelligent-Instruments-Lab/rave-models/tree/main)). `wheel.ts` is not in that collection, and no download source is documented yet. If a model file is missing, that script fails to load it.
