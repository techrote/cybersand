---
title: Art Workbench final evaluation
status: Current
document-kind: guide
scope: Draft/HOLD Art integration, Windows evaluator, no-server responsiveness checks and evidence boundaries
canonical-for: [art-workbench-final-evaluation]
last-reviewed: 2026-11-24
related-documents: [../systems/workbench-art-providers.md, ../systems/workbench-direct-art-batches.md, ../audits/2026-11-24-art-workbench-final/README.md]
---

# Art Workbench final evaluation

The ART-WORKBENCH-FINAL-001 candidate combines the conversation dialog repair,
exact provider presets, close timing probe and failed-HTTP/hidden-UI changes on
accepted main `00cdb02f`. It remains **Draft/HOLD**. Donor branches are preserved;
no Batch Lab, PUBPRES, ObjectShard or new actor work is imported. Existing
accepted Workbench features remain available.

## Open the Windows evaluator

Extract the entire evaluator ZIP to a writable folder and double-click
**Open Workbench.cmd**. The package contains exact Godot 4.7, the unchanged
source-qualified Windows native/Rapier libraries, their dependencies and notices,
the committed application, generator profiles and this guide. No Git, Python,
compiler or model server is needed for ordinary Art evaluation.

The first launch imports the project. It then opens the normal interactive
Workbench and Art window, with Image off for the primary text-only reproduction.
Let the initial import and World setup finish before checking Send/X. The hosted
Windows software-rendering run took about 52 seconds to create the Workbench after
import; that cold-start cost is recorded separately from interaction timings.
Its profile is stored in this package's `profile` folder; existing installations
and historical user data are not read or changed. No request is sent automatically.
Model identifiers and endpoints remain editable. A preset says nothing about
API access, image support or whether a local model is loaded.

The evaluator keeps bounded timing samples in memory. **Ctrl+F12** writes a
checkpoint, and an orderly application exit writes the final report. **Open
diagnostics.cmd** opens the output folder. `art-responsiveness.json` contains
frame-gap histograms and transport, callback, audit and native-edit timing;
it contains no prompts, response bodies, endpoints, model identifiers or keys.
Large-response preparation and its main-thread publication are separate timing
stages. UI projection/list-slice counters are also recorded; deferred engine
layout and rendering remain included in the adjacent-frame gaps.
`workbench.log` records engine output. The ordinary full redacted Art audit
remains in the isolated profile and is separate from the timing report.

The source commit, source tree and hashes of every immutable delivered file are
in `candidate-manifest.json`. Native runtime source identity is recorded
separately; this is a script/UI change and does not rebuild the engine.

`APPLICATION-QUALIFICATION.json` records the source comparison and application
evidence basis. Packaging-only follow-ups may reuse a fixed completed application
run only after the full change allowlist, protected source trees, prior job steps,
artifact digests and all matrix receipts verify. The packaging commit/tree is
recorded separately from that application-tested source. Each evaluator still
requires a fresh committed packaging checkout, the actual extracted command
launcher, immutable-file verification and complementary loaded-module checks.
The source comparison alone does not establish package acceptance.

## Short owner checklist

1. Completely stop LM Studio. Confirm there is no listener on the configured
   local API endpoint, normally `127.0.0.1:1234`. Select **LM Studio → Model prompt**
   and leave **Image** off. Press **Send**, then immediately click Art's ordinary
   **X**. Repeat three
   times, reopening through **Art batches** between attempts. Check mouse, camera and painting
   responsiveness; record any pause and whether it begins on Send, X or recovery.
   Repeat separately with the Image setting used during the original freeze.
2. Compare the same absent-server request with Art left visible, and with
   **Stop** followed by X. Try reopening while a request is pending. X hides Art;
   Stop explicitly cancels activity. A failed connection leaves Send usable.
3. Open **Conversation… → + Note**. Use long text at a 1280×720 and 1920×1080 window,
   and at your normal Windows display scale. Scroll the contents, click Apply,
   reopen and verify the edit. Cancel a second edit and verify that it was not
   applied. Apply/Cancel should remain reachable at a small Art window size; a
   short Note should gain editing height when the Conversation window is taller.
   Messages over 4,096 characters use **Previous/Next** parts; Apply retains the
   complete message, including edits made in other parts. Use the part-number
   field and Enter to jump directly without applying. Moving between parts or pasting across parts resets
   local text Undo; Cancel still discards the whole draft. Ordinary small-note
   Undo remains available.
4. Inspect both provider preset lists, enter a custom model and endpoint, switch
   provider and return. Check that saved custom choices remain. **Key… / Key ✓**
   belongs to the provider named when its dialog opened and is held only in
   process memory. A dummy key suffices to check the dialog without inference.
5. Draw manually and with **Direct JSON → Draw**; Stop a large batch after a visible
   prefix. Wait for its confirmed result, pause through **Play / Pause [P]**, then
   Undo/Redo. **Save start [Ctrl+S] / Load start** should retain the authored start
   so painting can continue. A new Workbench game session starts
   with an empty conversation and a new audit; hiding Art within one game session
   preserves that session's conversation.

Save a Ctrl+F12 checkpoint after a freeze, then exit normally. Report the source
commit, Windows display scale, endpoint category (default numeric loopback,
localhost or a custom local address), listener absence and which comparison
reproduced the delay. Timing evidence does not require sharing a private profile.

## Reproducible engineering matrix

`tools/ci/run_art_workbench_final.py` drives the actual native Shared Workbench,
real loopback sockets and Godot input hit testing. It separates absent listeners
from running mock HTTP servers. Use an isolated output directory on each run:

```text
python tools/ci/run_art_workbench_final.py --godot PATH --project godot --output OUTPUT
```

Use the runner's graphical option for a display-backed run. The focused
`art-session-logging.yml` workflow executes the integrated source on Linux and
Windows Godot 4.7 without a new native compilation. Hosted qualification runs
`network`, `preparation`, `request-preparation`, `lifecycle` and
`conversation-apply` in fresh processes, plus `preparation-exit` and
`request-preparation-exit` for actual process exit. Use `--group NAME` to replay
one group. `network` includes all no-server arms;
the split retains the complete matrix and unchanged two-second frame gate.
The runner records its exact arguments and source/runtime hashes.
A watchdog failure is retained as a failure,
not converted to a pass because the operating system eventually killed Godot.

Large synthetic response fixtures allow 10 seconds for about 1 MiB and 90 seconds
for near-cap bodies, with matching finite CPU-entry and authoring-run budgets.
Intentional timeout fixtures retain their one-second deadline; the two-second
adjacent-frame and cancellation gates are independent of transfer duration.
For graphical replay, the process watchdog defaults to 600 seconds for `network`,
900 for `preparation`, and 2,400 for the combined `all` group. Other groups and
headless runs retain 300 seconds. `--timeout SECONDS` explicitly changes only the
outer process watchdog; every case still has its own finite lifecycle bounds.
Fresh groups are preferred when reproducing a specific condition.

| Failure or lifecycle condition | What the evidence must distinguish |
| --- | --- |
| No server on default numeric loopback | Send/X, visible, Stop/X and reopen; no HTTP status exists |
| Closed spare port, localhost, IPv6 | Immediate refusal and hostname/address-family behavior |
| Saturated loopback connection backlog | A delayed TCP connection, separately identified from refusal |
| Server accepts but sends no headers/body | Stop, request timeout and teardown remain responsive |
| Delayed or invalid-model HTTP reply | X continues the request; a real HTTP error is not an assistant turn |
| Malformed or oversized response | Explicit failure, no accidental drawing, truthful audit/capacity outcome |
| Large response CPU preparation | Hide/reopen continues; Stop and World replacement invalidate publication; owner teardown does not join the job |
| Large Full-context request preparation | Send returns promptly; Stop/World replacement can prevent HTTP admission; captured prompt and image reference remain coherent |
| World replacement or shutdown | Old requests cannot write to the new World or hang its owner |
| Native ticking and manual painting | Actual material readback, not render FPS or synthetic counters alone |
| Long conversations and small windows | Apply/Cancel geometry, asynchronous list loading and stale-edit guard |

## Qualification boundaries

A successful mock 404 is never evidence for the original absent-LM-Studio freeze.
The reproduced stalled-response cancellation defect is also a separate condition.
The [dated integration evidence](../audits/2026-11-24-art-workbench-final/README.md)
records controlled failures, repaired-source results, exact CI/package identities,
independent review and remaining owner checks.

Headless native tests, rendered synthetic-input tests, Linux desktop clicks,
hosted Windows rendering and the owner's physical Windows 11/NVIDIA observation
are separate qualification tiers. No paid inference, remote provider capability
verification or physical NVIDIA acceptance is implied by passing loopback tests.

The nonblocking 64 KiB HTTP read path advances with the application frame loop.
Slow rendering therefore reduces download throughput under the configured
transport timeout. An uncompressed 16 MiB response needs at least 256 body-read
frames; partial reads can take more. This tradeoff is separate from callback, JSON, audit and native-edit
latency; the evaluator records those stages and adjacent-frame gaps separately.
A genuine timeout remains an explicit transport failure and cannot qualify a
complete-response or CPU-preparation success check.
