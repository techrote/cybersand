# Local pattern-controller → Workbench Art bridge (opt-in)

**Status:** Implemented and protocol-tested on 13 November 2026; **not** native- or Windows-qualified on current source. This is an additive, loopback-only route, not a new production provider. It makes the real trained LFM2.5-350M adapter available through the existing **LM Studio / Chat Completions** Art seam, without importing older native runtime source or changing the Workbench's protections, Stop, native acknowledgements, shared history or persistence.

`local_art_bridge.py` receives a **single text-only, one-turn** local Art request. It captures the focus width/height, selected material, allowed materials and enabled tool types from the current Workbench host instructions; the host seed and preflight budgets come from the bridge's command line. It delegates model generation and strict completion/EOS/adapter/compiler validation to the existing `training/infer.py`. Only if the compiler produces an accepted full batch with matching hashes, dimensions, material and tool permissions does the bridge return a Chat Completions **content JSON array**. A refusal, malformed response, output mismatch, timeout or unauthorized tool returns an HTTP error with **no Art operation payload**.

The existing Workbench revalidates returned geometry, translates local coordinates into its captured focus rectangle and retains native source/protected-region/body permissions, revision and Stop fencing, shared Undo/Redo and save/reopen. This HTTP bridge never writes a World, claims a native receipt, auto-repairs the model's output, retries a timed-out draw, or credits deterministic keyword fallback as model accuracy.

## Set up with the independently verified adapter

Use a fresh clone containing the integrated Art Workbench source (#564/#565 successor). **Accepted main at `63f8b1ba` does not by itself supply this live Art UI**. Do not replace accepted main's #563 capability consumer with the historical Linux pilot.

Recover the **exact** `wb_art_slm_001_lfm350_adapter_step400.zip` from the owner's files, verify its size **23,413,182 bytes** and SHA-256 `9b53d642ec48c0f7b65835f267a5b38d9183641b12476befc563e216fa3c11a6`, then extract its `adapter/` folder to a **private directory outside Git**. Its `adapter_model.safetensors` SHA-256 is `02b9263e543eb464e6b58f1f74960c98d5aec4ec117baddfcf22b4d5dd4c84b2`. Other model weights, checkpoints and raw evidence stay outside the repository.

Install the pinned packages as detailed in [Training](../training/README.md) and download the pinned local base with:

```powershell
python experiments/wb-art-slm-001/training/download_model.py --profile lfm2_5_350m --output "C:\wb-art-slm-private\models\lfm350"
```

From the CyberSand Git root, with **the pinned `training/requirements.lock` environment activated**, run the loopback service (PowerShell):

```powershell
python experiments/wb-art-slm-001/integration/local_art_bridge.py `
  --model-dir "C:\wb-art-slm-private\models\lfm350" `
  --adapter-dir "C:\wb-art-slm-private\adapter" `
  --evidence-dir "C:\wb-art-slm-private\requests" `
  --seed 73 --threads 3 --device cpu --deadline-seconds 150
```

The adapter and compiler hashes are checked **before the HTTP service starts**; inference additionally verifies pinned model-file hashes and the official tokenizer/chat template. The default service listens only on `127.0.0.1:8127`. Inspect `http://127.0.0.1:8127/v1/models` or `/healthz`. No paid endpoint or external model API is involved.

## Workbench settings

Launch an integrated Workbench build against its own compatible source-built runtime. For source testing on the owner's Windows PC, the Godot executable is **`C:\Godot_v4.7-stable_win64_console.exe`**; do not infer a runtime from the old Linux pilot. Example from the repository root, once an appropriate native extension exists:

```powershell
& "C:\Godot_v4.7-stable_win64_console.exe" --path ".\godot" -- --workbench
```

In **Art** set:

| Setting | Required initial value |
| --- | --- |
| Mode | Model prompt (not Scanline) |
| Source | LM Studio (the existing local-mode provider) |
| Endpoint | `http://127.0.0.1:8127/v1` |
| Model | `wb-art-slm-001-lfm350-step400` |
| Prompt | `roots` (then try another theme or simple modifier) |
| Focus | A supported 16–512-cell-wide and 16–512-cell-high rectangle; begin at 96×96 |
| Material | Hard Wall (58); the pilot also verifies Empty (0), but the Art panel must authorize erase |
| Image | Off |
| Conversation context | None |
| Turns | **1** (not unlimited); no auto-continuation |
| Tools | All five compiled types: rectangle, line, polyline, polygon and disc |
| Toks / Seconds | Toks at least 256 (8192 is fine); Seconds at least 165 (180 recommended) |

The model never receives the seed, world origin, materials or cost budget as editable schema fields. The bridge uses one model load per request; performance has not been characterized on Windows. Run one inference at a time, use the Workbench Stop button to cancel its HTTP request, and inspect traffic/native receipts to distinguish a **completed model inference** from a **confirmed canvas edit**. Stop does not promise that a local CPU inference already executing in the subprocess has terminated immediately; it prevents a stale response from being painted by the current Workbench epoch/request fence.

## Regressions and acceptance boundary

Without downloading a model:

```sh
python -m unittest discover -s experiments/wb-art-slm-001/integration -p 'test_*.py' -v
```

The 13 November local test run passed **4 test methods** covering capture, malformed/unsafe/unsupported refusals, receipt/hash/EOS/tool gates, an actual loopback Chat Completions HTTP response and failure without mutation. The HTTP response used a **fake fixed runner**; it was **not** a new trained-model evaluation, native replay, Windows acceptance or visual result. Existing 400-step model/native evidence remains pinned separately in [Bootstrap report](../BOOTSTRAP_REPORT.md).

Before qualifying this route for user-facing launch: integrate over a source-compatible #564/#565 successor preserving accepted #563; replay raw step-400 predictions, compare operation hashes and native receipts at two seeds, exercise Stop/stale epoch/focus, shared Undo/Redo and save/reopen on current Windows and Linux; obtain independent code/contract review; package an opt-in launcher/preset and inspect real Workbench images. Any compiler/schema change invalidates the adapter's exact hash contract until explicitly requalified.

**Draft / HOLD.** No provider default, source-owner branch, production model alias, physics or material law was changed.
