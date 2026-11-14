# S1-2B-DRIV3R Stage A — engineering report

**Draft/HOLD.** This source checkpoint implements the bounded qualification
campaign. Its final execution disposition is the generated `execution/summary.json`
and the source/run-linked report in the PR and [#570](https://github.com/techrote/cybersand/issues/570).
No gate passes from this document or code presence alone.

## Contents

1. **Foundation and ownership** — exact adopted sources and disjoint responsibilities.
2. **Resident decision backend** — pinned official weights, typed outputs and lifecycle.
3. **Controller and native integration** — host-owned controls through the real Workbench.
4. **Original diagnostic outcomes** — measured preliminary execution and its limits.
5. **Defects and controls** — preserved failures and concrete repairs.
6. **Acceptance evidence** — gates, original artifacts and reproducibility.
7. **Next-stage handoff** — bounded next experiments and ownership recommendations.

## 1. Foundation and ownership

GitHub intake on 14 November 2026 verified accepted main
`ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742` and unmerged foundation #569
`2a565df45efc568eb96a2166e0b77f299e289625`, tree
`30aa0bf1130ada37d5273ceb533f0e0c91caec14`. The new branch is stacked on
`codex/agent-painter-foundation-568`. [SOURCE_BASELINE.json](SOURCE_BASELINE.json)
retains all four independent painter heads and their owned paths. None of those
lanes, their data, training/checkpoint machinery or shared source is changed.

Reused contracts are the unchanged #568 program compiler, native runtime custody,
POSIX process-group cleanup, and existing Workbench Art planner/executor, stored
material captures, native acknowledgements and protection/Stop semantics.
The generic chat proposal bridge is not the d1 transport: d1 uses its actual
typed decision endpoint. No alternate World or production UI is introduced.

## 2. Resident decision backend

Official `LiquidAI/d1-2B-GGUF` revision
`4a181094d1b6addfaa3a0956f78e7ab2aa406a0c`, `d1-2B-Q8_0.gguf`,
1,846,240,576 bytes, SHA-256
`073313d92b53b0ac8193db6e906cb3c78a98183d244b15b7b8f5426115c6738c`.
llama.cpp b11960/v0.8.0 source
`8642541b255bfb5dc39cd351a178be09013a55d6`, official Ubuntu x64 archive
SHA-256 `31cc3a6bc638ac6c48dc4b1b74888f1eaadf3d14227c1e5f67daf9a49541d97a`.
Every bundled executable/library hash is pinned and checked before launch.
Original model LFM Open License v1.0 and runtime MIT license are retained.

The host binds loopback with a private ephemeral credential. Typed named
single-choice outputs include the selected ID, confidence and full probabilities,
with `output_tokens=0`. The adapter rejects multi-select and advanced types;
the pinned upstream silently ignores `multiple`, so native parser behavior alone
cannot establish support. Multiple named questions inspect the same input state.
Timeout/cancellation retires and reaps the instance; late answers cannot reenter
the action loop. Normal multi-action episodes reuse one process.

The reference Transformers `system_one` implementation was inspected at
`LiquidAI/d1-2B@652f920e544ea37f81e4b0ce89b81d4ed0da90b1`. A matched reference
execution and Q4 comparison are explicitly deferred: Q8 works within the CPU
memory budget, and Stage A needs infrastructure feasibility rather than probability
parity. [BACKEND.md](BACKEND.md) retains exact semantics and sources.

## 3. Controller and native integration

`cybersand.driv3r/1` separates bounded observations, legal candidate providers,
typed decisions, native execution and episode ownership. State and ordered
candidate hashes bind every decision. Native generation/revision/tick and complete
material hash are re-read immediately before action admission. Materials, focus,
protection, operation/cell budgets and cancellation remain host-owned.

The direct provider exposes UP/DOWN/LEFT/RIGHT one-cell controls and STOP. It
starts at (12,24), aims for (12,30), and preserves a four-cell offset from the
protected x=8 wall. A second protected obstacle and protected empty region are
present. The model sees a bounded local crop plus exact host geometry metrics.

The three-node fuzzy graph offers existing architecture platform, extension and
support operations with discrete thin/thick and short/long profiles. These are
compiled by the unchanged #568 compiler into existing Art rectangles. SKIP and
STOP are explicit; finishing the graph alone is not semantic success.

One persistent Godot 4.7 session mounts the actual Shared Workbench. Its native
World is 512², with a 96² authorized focus. Native receipts are checked against
full before/after material data, and original material PNGs are decoded and
verified pixel by pixel. A cancelled partial prefix is counted and retained
without advancing a vehicle or claiming full action completion.

## 4. Original diagnostic outcomes

These preliminary executions used a verified **source-compatible retained native
runtime and uncommitted harness**, so they are development diagnostics, not final
source-built admission. The final hosted campaign must report its own exact source,
host measurements and original outcomes, including failures.

| Diagnostic | Original measured result |
| --- | --- |
| Q8 acquisition | 52.897 seconds; exact official weight hash matched |
| Initial resident inference | Four genuine requests plus malformed HTTP400, one PID; three RIGHT choices and one ADD_BRIDGE_SHORT |
| Small-question inference timing | 0.595 s model load; approximately 1.9–2.0 s per decision; peak process HWM 1,900,432 KiB |
| Direct native episode | Six original DOWN choices, six actual changed cells, target reached; 173.513 s end-to-end |
| Fuzzy native episode | ADD_PLATFORM_THIN, EXTEND_SHORT, SUPPORT_THIN; 72 actual changed cells; 90.751 s end-to-end |
| Conventional native baseline | Six DOWN actions, six actual changed cells; 44.144 s end-to-end |
| Native refusal suite | 19 actual native checks passed; protected cells, stale/material/focus/budget/refusal, Stop, late and cancelled operations |

The richer direct/fuzzy observations take materially longer than tiny oracle
questions. The diagnostic baseline also includes full readback, source fingerprints
and original PNG capture at every boundary; it is not a low-overhead game-loop
benchmark. No claim of neural superiority follows from matching this easy task.

## 5. Defects and controls

Original failures were retained and repaired before the final campaign:

- The initial Godot parent watchdog used an API that only recognizes Godot-owned
  child processes on Unix. The harness now uses the actual Linux parent lifetime.
- Independent review found cancellation could arrive during the fresh native
  observation. The executor now rechecks cancellation/deadline after that observation,
  forwards cancellation into native RPC, and fences admission at the native owner.
- Candidate IDs originally validated cardinal distance without binding UP to its
  exact delta. The validator now binds each ID to its corresponding geometry.
- Caller-supplied model identity and unverified bundled runtime libraries could
  weaken provenance. Committed pins now control all weights and bundle bytes.
- A repeated acquisition attempted to rewrite an active runtime bundle and failed
  with `ETXTBSY`. Acquisition now reuses intact bundles without writes, refuses dirty
  existing bundles and only publishes fresh verified extraction atomically.
- Partial native cancellation accounting now retains actual acknowledged prefix
  cells and verifies their authorized material transition separately from completion.
- The pinned runtime returns HTTP500 `server_error` for an oversized decision
  batch. The first probe expected HTTP400 and failed; the source now checks that
  exact capacity refusal and verifies a valid request still works afterward.
- Independent actual-native review of the first published source
  `c5329498937ef97df0f9459a3c754e61dd6bf05d` found that reset dispatch could clear
  cancellation which arrived after request publication. A paused-Godot
  reproduction retained a generation change and loss of a painted marker after
  cancellation; that source cannot pass A7 even if its earlier cohort succeeds.
  The repair clears only the prior episode's fence before reset publication,
  serializes that boundary against out-of-band cancellation, and never deletes
  cancellation in native dispatch. The real regression pauses Godot, publishes
  reset, establishes cancellation, then resumes and requires unchanged native
  generation and materials. An already admitted reset remains truthfully recorded
  if cancellation arrives during installation.

The final campaign runs both candidate orders, keeps wrong or early STOP choices,
tests a real model timeout and cancellation while a request is outstanding, then
checks process cleanup and zero unintended native changes. Synthetic negative
decisions are clearly labelled and cannot satisfy real-inference gates.

## 6. Acceptance evidence

The explicit workflow runs the frozen [qualify.py](qualify.py) cohort. The generated
`summary.json` marks A1–A8 individually PASS/FAIL/PARTIAL/BLOCKED; its exit status
requires all eight to pass. The source, tree, model revision and hashes, runtime
bundle/dependencies, frozen inputs, original requests/responses, native receipts,
full material hashes, PNGs, resource counters and cleanup are retained.

Both direct and fuzzy episodes run in each candidate order; the conventional
baseline uses the same actual native fixture. Each original episode is replayed
through another real native World and compared with its original material bytes.
This is deterministic stored-material action replay, not full simulation replay
or repeated model inference. The gallery embeds exact original PNG bytes and
does not call them framebuffer captures.
Timing-dependent cancelled partial prefixes remain original failure evidence and
are not replayed; Stage A replay refuses them before any native reset.

The immutable research ZIP includes every file hash and is read back after
packaging. A uniquely named GitHub prerelease retains the evidence beyond the
ordinary 90-day workflow artifact. The PR report must cite that exact run/asset;
publishing an artifact does not itself establish a successful gate.

## 7. Next-stage handoff

After Owner review, the highest-value Stage B work is a small frozen held-out
microtask cohort: turns/corners, wall-offset recovery, a blocked next move, early
STOP and a simple endpoint connection. Compare untuned d1, a deterministic controller
and seeded random-legal controls using identical initial Worlds and budgets. Separate
quality, success, refusal and actual end-to-end CPU cost. Avoid increasing scale until
those comparisons establish what the model contributes.

For fuzzy tools, test modest alternatives in operation family and discrete profile,
with objective geometry checks and original native previews. Candidate order,
instruction phrasing and observation size are useful bounded ablations; choose
parameters on DEVELOPMENT before any held-out evaluation. No fine-tuning is needed
to ask whether the untuned controller is useful.

Stage C could expand independently into Pipework, Architecture and Greebles only
after Stage B results justify it. A possible later worker split is direct-drive
microtasks, fuzzy-tool microtasks and an independent evidence reviewer. Keep changes
to protocol, native admission, pins and qualification ownership serialized; independent
workers can add disjoint frozen scenarios and reports. Do not create these schedules
or start those stages from this Stage A checkpoint.
