# Models

RAVE models (`.ts`, TorchScript) go in this folder. They are not tracked in git.

## Required: `birds.ts`

Both navigators (`midi/` and `agent/`) use the birds model from the Intelligent Instruments Lab:

1. Download **[birds_motherbird_b2048_r48000_z16.ts](https://huggingface.co/Intelligent-Instruments-Lab/rave-models/blob/main/birds_motherbird_b2048_r48000_z16.ts)**
2. Rename it to `birds.ts` and place it here:

```
models/
└── birds.ts
```

## Optional: example models

Some scripts in [`examples/`](../examples) also load `marinemammals.ts` and `wheel.ts`. Get them from the same collection, [Intelligent-Instruments-Lab/rave-models](https://huggingface.co/Intelligent-Instruments-Lab/rave-models/tree/main), and rename them to match. If a model file is missing, that script fails to load it.
