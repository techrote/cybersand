# Native pattern qualification

This directory contains the executable native evaluation path for the small-model
pattern experiment. It uses an actual mounted CyberSand Workbench, the existing
Art planner and executor, the shared PAINT history owner, and the compiled
`CyberNativeCellWorld`. It never substitutes a Python rasterizer for native
execution.

## Independent blinded model-image review (development only)

The [custody-checked 34-pair native review](blind_model_review.html) hides expected
themes and prompts, presents both actual host seeds per admitted request, and
exports local responses. The separate [answer key](blind_model_review_answer_key.json)
must not be opened by the reviewer before they freeze their answers. Use
[`blind_native_review.py`](blind_native_review.py) to regenerate and score; run
[`test_blind_native_review.py`](test_blind_native_review.py) to check the
source-bound fixture and scoring adversaries. The
[dated checkpoint](BLIND_REVIEW_CHECKPOINT_2026-11-13.md) retains exact native and
code hashes, rejections and limits. The two malformed coral requests have no
images and remain failures in the **36 original-request** denominator. Correct
symbolic labels and native passes are not equivalent to blind theme recognition.

## Qualification scope

The bootstrap is a **pinned Linux headless native-material pilot**, using:

| Item | Exact identity |
| --- | --- |
| CyberSand source | `90719c72b9fcf90593fb7878354051ad601b47fd` |
| Native binary SHA-256 | `3a8b0b2cd04f09054426842f978e2421aad4016aae03dec91ed527ff50b953cd` |
| Rapier SHA-256 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Official Godot ZIP SHA-256 | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c` |
| Published runtime | GitHub Actions run `43334477644`, Linux artifact `13999396092` |
| Artifact ZIP SHA-256 | `6ca3266605d06e4cb0773eb105ab27442219baf23eec4d9a15468bc0091c398a` |

The source was an earlier combined Materials Lab/Workbench candidate. It predates
the subsequently accepted capability-consumer main. Results here do not qualify
current main, a Windows runtime, graphical framebuffer rendering, physics behavior,
owner visual acceptance, or an unexecuted model. Each packet declares its actual
source, tools, worker capacity, input and output hashes. Pilot pictures are
visualizations of independently captured native stored material IDs, generated
with Godot `Image`; they are not desktop screenshots. Empty is dark and Hard Wall
is ivory. The separate `.materials.png` stores the exact numeric IDs as grayscale.

The original mounted `tests/test_art_batch_native.gd` suite was run first and
passed all 145 checks on these exact runtime bytes. The initial 32-pattern pilot
then passed 1,234 engine assertions, including shared Undo/Redo and authored-start
save/reopen for all 32 cases. Its independent reducer passed 126,383 checks. The
full campaign then executed 864/864 cases across three independent one-worker
packets: 14,288 engine assertions and 4,572,506 independent reducer checks passed.
All three packets passed all 15 global gates, with zero cells changed outside
the requested area and zero unexpected material IDs. They acknowledged 1,518,630
native cell visits and confirmed 1,170,966 changed cells. All 864 final readbacks
were distinct; the 192 gallery cases also had 192 distinct readbacks.

The full campaign exercised exact shared Undo/Redo and authored-start save/reopen
for one representative of each of the 12 themes. The initial pilot exercised
those extra operations on every one of its 32 cases. Repeating the same 32 inputs
in the full campaign produced identical operation digests, raw native material
hashes and PNG bytes for all 32. Packet wall times were 452.057, 453.398 and
450.661 seconds while running in parallel. This is a local timing observation,
not a throughput guarantee.

## Running a packet

Use a private checkout at the exact source above. Materialize the matching
published native library and its `runtime-provenance.linux.json`, plus the pinned
Rapier library. Import the project with the pinned Godot once. Runtime preparation
must not replace production or original-branch files.

```sh
python3 evaluation/run_native_replay.py \
  --runtime /absolute/path/to/private/cybersand \
  --godot /absolute/path/to/Godot_v4.7-stable_linux.x86_64 \
  --cases /absolute/path/to/cases.json \
  --output /absolute/path/to/new-evidence-directory \
  --workers 1 --history per-theme --timeout 2400

python3 evaluation/verify_native_replay.py /absolute/path/to/new-evidence-directory
```

The runner refuses a different source commit, native/Rapier hash, engine version,
or published build-input/source-input hash. It compares them again after the
engine exits. It creates a uniquely named temporary harness in the private
project, uses an isolated Godot profile, and removes that harness on exit. Parallel
packets can share an already imported private project while retaining separate
profiles and evidence directories. An existing output directory is refused so
failed attempts are preserved.

The JSON input is `{"cases":[...]}`. Each case has a unique safe `id`, `theme`,
`width`, `height`, `operations`, and optionally `seed`, `program_sha256` and
`operations_sha256`. The runner computes and verifies the operation digest before
execution. Inputs contain 1–1,024 cases and 1–2,048 operations per case. The pilot
permits only destination IDs 0 and 58. Width and height are 1–512 cells; the
compiler corpus uses 96×96.

## What executes and what is checked

Every case installs a fresh paused 512×512 native World, because the Workbench
setup contract requires a minimum side of 512. The 96×96 compiler canvas is the
requested area at origin. Art submission is only admission; the harness waits
for all authoritative native chunk receipts and shared history finalization.

It then captures the full 512×512 stored material array through the worker's
native capture operation. Full-world hashes and complete-area scans verify that
no stored cells changed outside the requested area and no unexpected material
was written. Cropped binary IDs, exact material-ID PNGs, colored PNGs, receipt
rows, counters and source identities are retained. The independent Python reader
reconstructs cells from the actual native before/after receipt rows. It compares
that reconstruction with the independent full-world capture hash, raw crop,
numeric PNG, display colors, and terminal checked/changed/unchanged counts.

Representative invariant fixtures execute before the corpus:

- A drawing crosses its selected area and protected rectangle while encountering
  a pre-existing Metal cell. An exact whole-world comparison checks all three
  exclusions and closes the native changed-cell count.
- Stop is issued after one native chunk completes but before its receipt is
  consumed. Exact stored-cell capture proves the applied prefix and untouched
  suffix. Additional frames check for delayed writes, then shared Undo/Redo
  reverses and restores only that prefix.
- Undo is refused while an Art batch or an unconsumed native receipt owns the
  edit boundary. Save is refused while Undo/Redo is queued.

With `--history per-theme`, the first case of each theme additionally runs exact
full-world Undo, Redo, save, and reconstruction into a new native World. This is
explicitly recorded per case; other cases do not claim those extra probes.
`--history each` performs them on every case. All cases still receive the full
native execution, independent capture and bounds/material checks.

## Evidence files and admission

`runtime-custody.json` binds source, native/Rapier/Godot, harness and input bytes.
`process-result.json` retains the command, timeout, exit status and post-run
identity comparisons. `engine.log`, `native-receipts.jsonl` and
`native-summary.json` preserve actual execution and assertions. Per-case receipts,
PNGs and raw IDs retain the inspectable outputs. Representative saved starts are
copied as `.setup.json` files.

`admission-receipts.json` is the runner's normalized report. Prefer
`verified-admission-receipts.json`, produced by the independent reducer. Its
`runtime` and `cases` fields match the corpus-admission input contract. Admission
requires `passed`, successful cases, exact operation hashes, positive
acknowledged native cell counts, image/readback hashes, and zero violations.
Semantic visual review remains an additional corpus gate. A native pass means
the operation was correctly executed, not that its theme is aesthetically good.

The input compiler hash can change for validation-only repairs while actual
operation hashes remain identical. Preserve both source records and explicitly
prove trace equality; do not silently rewrite the runtime custody packet.

## Testing the evidence reader

```sh
python3 evaluation/test_native_replay.py \
  --fixture /absolute/path/to/completed-native-packet \
  --output /absolute/path/to/new-adverse-controls.json
```

This accepts the unaltered genuine packet and rejects thirteen deliberate corruptions:
raw material bytes, material PNG, native before-row continuity, out-of-area
count, process failure, missing case, harness identity, native identity, and an
incorrect operation digest, a false engine assertion hidden behind summary pass,
changed input custody, a corrupt protection witness and a corrupt Stop witness.
The reducer also exposes 15 explicit global gates, and positive case status
requires every global gate. A missing case, failed process, source change, failed
Stop/protection probe, or incomplete source packet blocks corpus admission.
Mutated copies are temporary controlled fixtures;
they are never represented as native executions. The full current set passed
14/14 controls on the initial 32-case packet. Separate packet-merge checks
accepted a valid packet and refused duplicate case IDs and a failed global gate
(3/3).

The first strengthened reader attempt compared Godot's different CLI and Engine
API version string formats literally and refused the otherwise passing packet.
That failed reader result is retained. The corrected reader checks the exact
expected strings separately, and its successor passed all 15 global gates and
126,421 independent assertions for the same unchanged 32-case execution packet.


## Audit of repeated blind visual stimuli (development only)

The independent [PNG stimulus auditor](audit_blind_stimulus.py) and its
[six regression tests](test_audit_blind_stimulus.py) parse actual embedded native
PNG bytes from the frozen blind HTML, verify the exact source identity and
two host seeds, and count byte-identical two-image pairs. Use the separate
answer-key mode **only after** a reviewer has frozen their responses.

The [dated checkpoint](STIMULUS_AUDIT_CHECKPOINT_2026-11-13.md) records a real
duplicate: q004 and q007 are two distinct original development requests but
the **same native image pair at both seeds**, from the same structural group.
The 34 displayed request cards therefore contain 33 distinct exact image pairs
and 66 distinct PNG bytes, not 34 independent visual examples. Preserve the
36 original first-pass requests, 34 native-admitted requests and 68/68
native seed-replay outcomes as separate denominators. No visual theme score,
new native execution or new model inference was obtained in this audit.

Offline reproduction with a frozen self-contained HTML file:

    python3 evaluation/audit_blind_stimulus.py \
      --html /private/review/blind_model_review.html \
      --expected-html-sha256 5f554c67c928d6f940126d07c529df89694a42d6cdeb7a65c7b9c4413f354877
    python3 evaluation/test_audit_blind_stimulus.py
