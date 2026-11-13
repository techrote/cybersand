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

The model never receives the seed, world origin, materials or cost budget as editable schema fields. The bridge uses one model load per request; performance has not been characterized on Windows. Run one inference at a time, use the Workbench Stop button to cancel its HTTP request, and inspect traffic/native receipts to distinguish a **completed model inference** from a **confirmed canvas edit**. The local bridge now polls the Workbench TCP socket during inference: Stop/disconnect terminates its owned child process (POSIX process group), frees the single-job lock and discards a late response. This is Linux fixture-verified with an actual HTTP connection and fake subprocess, **not** Windows child-tree, loaded-model, Godot or native Stop qualification; the Workbench epoch/request fence remains authoritative.

## Integrated role checkpoints and receipt safety (13 November 2026)

Draft #567 now carries the **four role-owned source checkpoints**, imported by four
separate fast-forward commits without modifying their original branches:
Controls `ed2720e33e3b` (opt-in coral 1.1 and native pairing);
Corpus `791dc710c099` (verified replay-order candidate);
Training `729343a22e30` (optional keyword sampler, no new training);
Evaluation `07f7e191ec4c` (native packet auditor and <=38-character aliases).
These are **additional code and evidence-handling tools**, not measured new model
accuracy and not current-source native acceptance. The v1 compiler and step-400
adapter identities remain frozen; v1.1 must not silently replace them.

The bridge now checks each successful subprocess's inference receipt against
the **exact request prompt, pinned host seed, adapter hash, LFM base model identity
and `native_execution=false`**, in addition to its existing compiler,
focus, material, permitted shapes, EOS and compiled-batch SHA checks. This
rejects a stale or mis-associated inference folder without exposing its
operations to the Art provider. The focused test fixture includes five forged receipt variants. Both
exact-head offline CI runs ([run 43364062901](https://github.com/techrote/cybersand/actions/runs/43364062901),
[run 43364068843](https://github.com/techrote/cybersand/actions/runs/43364068843))
passed on commit `95ed04dcada3beb0b79f9b289c4a630d0b581261`:
**4/4 bridge HTTP/refusal test methods**, **18/18 compiler v1/v1.1 tests**,
**1/1 native alias-pair builder test**, **2/2 synthetic Corpus tests** and
**4/4 applicable Training sampler tests**; Python source compilation passed.
Both private-archive-dependent suites were explicitly **skipped** on hosted
CI because the materialized admitted corpus is not in Git. No model weights,
real native simulation or Windows were involved. Independent code review is
still required.

**Upstream qualification blocker:** #565 Request 4 at source
`d66499ec3409fb657875fca7dbd0f234cf28ca49`
([workflow 43358127824](https://github.com/techrote/cybersand/actions/runs/43358127824))
completed with **Windows failure** on 13 November 2026 at 04:00 UTC:
the original graphical `MATERIAL_LAB_UI` shared Workbench installation case
exceeded its internal deadline at 15 FPS (211 assertions, one failure).
The source-matched Linux job passed. Packaging/publishing was skipped;
there is **no verified compatible Windows runtime** to adopt yet. The
upstream owner must resolve and qualify that gate. This experiment does
not alter #565 or treat its partial success as current-main approval.


## Subsequent integration checkpoint — 13 November 2026

Four further **owner-scope-only** role commits were imported serially with exact source blobs: Controls `a75f90956f18` (7 paths, real archived coral baseline readback audit and explicit paired history mode); Corpus `9f9a462fca15` (4 paths, balanced v2 theme/phrasing exposure alternative); Training `4da123301705` (5 paths, durable lease and strict process-wide checkpoint-aware job guard); Evaluation `8a533c5762e5` (6 paths, a sealed-answer-key 34-card/68-image historical native blind-review fixture). All 22 owned paths are kept separate from this Integration-owned bridge code and from existing native/art source; no model retraining or new native qualification was performed. The original v1 compiler, development/final splits and step-400 adapter remain frozen.

The bridge now checks client TCP disconnect while its local inference child runs, terminates the child on Stop or deadline and never sends a late geometry batch. An ordinary aborted connection no longer raises a response-header write error. Because Workbench appends its captured local-coordinate XYWH/material/tool fields **after** editable Guidance, the bridge uses the last occurrence of each scope field; synthetic spoofed Guidance examples cannot override the actual appended scope. These were tested in the full real loopback HTTP/fake-child handler, not against a loaded LoRA or native world. POSIX group termination was exercised; **Windows process-tree cleanup is unqualified**.

At exact source `0fc6f9cedeb5b147fe86cb61446354f38db16d8a`, the [first hosted workflow](https://github.com/techrote/cybersand/actions/runs/43370584693) and [second hosted workflow](https://github.com/techrote/cybersand/actions/runs/43370593006) both succeeded: 52 exercised model-free unit methods across the five roles, Python compilation PASS, and expected missing-private-archive cases SKIPPED. This is **neither** authentic step-400 model inference **nor** current-source Godot/native Windows/Linux or graphical acceptance. Independent Evaluation review of Integration's Stop/host-scope edits is still pending. The [dependency board](DEPENDENCIES.json) pins exact role commits and next actions; preserve the upstream #565 Windows HOLD.

## Regressions and acceptance boundary

Without downloading a model:

```sh
python -m unittest discover -s experiments/wb-art-slm-001/integration -p 'test_*.py' -v
```

The latest 13 November exact-head hosted run passed **9 Integration methods** covering captured host scope and adversarial Guidance examples, forged receipts, rejected/unsafe/unsupported requests, complete EOS/hash/tool gates, an actual loopback Chat Completions exchange and an actual HTTP disconnect that terminated a fake inference child and released the service lock. The HTTP response used a **fake fixed runner**; it was **not** a new trained-model evaluation, native replay, Windows acceptance or visual result. Existing 400-step model/native evidence remains pinned separately in [Bootstrap report](../BOOTSTRAP_REPORT.md).

Before qualifying this route for user-facing launch: integrate over a source-compatible #564/#565 successor preserving accepted #563; replay raw step-400 predictions, compare operation hashes and native receipts at two seeds, exercise Stop/stale epoch/focus, shared Undo/Redo and save/reopen on current Windows and Linux; obtain independent code/contract review; package an opt-in launcher/preset and inspect real Workbench images. Any compiler/schema change invalidates the adapter's exact hash contract until explicitly requalified.

**Draft / HOLD.** No provider default, source-owner branch, production model alias, physics or material law was changed.
