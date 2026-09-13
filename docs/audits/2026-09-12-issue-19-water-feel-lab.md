---
title: Issue 19 Water Feel Lab completion
status: Current
document-kind: evidence
scope: V1 fractional presentation and V2 deterministic Water Feel Lab implementation, validation, review and H-readiness boundary
canonical-for: [issue-19-water-feel-lab-evidence]
last-reviewed: 2026-09-12
related-documents: [../operations/water-feel-lab-experiment.md, ../operations/experiment-tower.md, ../operations/architecture-programme-water-feel-addendum.md, ../operations/architecture-programme-prompts/fractional-presentation.md, ../systems/water-design.md, ../systems/material-appearance-and-rendering.md]
---

# Issue 19 Water Feel Lab completion

## Outcome and legitimate boundary

**Current, 2026-09-12:** both registered #19 stages are implemented and pass the
available native, desktop, rendered-pixel and real-browser acceptance gates. V1
provides a selectable four-level partial-fill experiment and oriented interface
mode. V2 extends the existing Experiment Tower with 35 deterministic Water
scenarios, one normalized runtime policy, transactional Apply + Reset, deterministic
A/B/blind preparation and reconstructible observation export. The apparatus is
**H-ready**.

This result selects no preferred mass precision, coherence duration, Water state
budget, Cell layout, packing, spare-state allocation, compact history or sparse
ballistics. Production defaults remain mass8/coherence12 and the existing Cell
carrier. No human preference study was performed. #18 remains open and unimplemented
pending an H-derived directional-persistence target or H-backed no-go; #20 remains
downstream; G-final remains open.

## Source and artifact identity

- Git root/worktree: `C:/kybersand/worktrees/issue-19-water-feel-lab` on
  `codex/issue-19-water-feel-lab`.
- Base: `d39e31f03f2e39b0022d507b79fbee5c2439436d`.
- Validated source checkpoint: `3ef4923abb011c5451be0f2ba477d8a3bffb0ee3`.
  The later evidence/provenance commit changes documentation and retained binaries,
  not the validated source inputs.
- Windows GDExtension: SHA-256
  `ce0b252171a7931317068eda62ec1ec773632d760f85f0ebb594af44d197a138`,
  1,825,792 bytes; Godot 4.7, godot-cpp
  `101ae38034304346a46ea9ea84ae156d3e860496`, LLVM-MinGW 20260826 UCRT,
  Clang 23.1.0.
- Web compatibility WASM: SHA-256
  `f74afb0cc6eac076c6879e99992ca4673a4d82983f1486619974ca1bd1b79584`,
  1,946,507 bytes, Emscripten 4.0.20.
- Web threaded WASM: SHA-256
  `0fc1ee6b0d19d38d73a115db1c29eabc83eb1f2bff2c79ef95373a7ffe2660b3`,
  1,949,966 bytes, Emscripten 4.0.20.

Raw local output is retained below
`validation/local/issue-19/`; it is intentionally excluded from source control.
The positive browser JSON and PNG captures are under
`browser-compat-rebuilt/` and `browser-threaded/`. The first compatibility run
is retained under `browser-compat/` as a negative stale-artifact result.
Portable captures are retained as [compatibility pass](issue-19-2026-09-12/web-compat-pass.png),
[threaded pass](issue-19-2026-09-12/web-threaded-pass.png) and
[stale-artifact failure](issue-19-2026-09-12/web-compat-stale-failure.png).

## V1 result: derived four-level presentation

The immutable RG8 Water condition byte remains normalized authoritative mass.
`water_presentation_model.gd` and `material_palette.gdshader` derive four visible
coverage levels and an optional local orientation from it. Synthetic tests cover
top surfaces, undersides, vertical edges, diagonals, concave boundaries, isolated
droplets, weak/ambiguous gradients, adjacent continuity, temporal stability and
2x/4x scales. Ambiguous or unsupported orientations fall back to horizontal fill.

The real OpenGL test on an NVIDIA GeForce GTX 1650 SUPER rendered exactly 2/4
covered pixels at 2x and 8/16 at 4x, and passed the right-edge orientation case.
The focused model has eight passing groups. Presentation mode switching preserved
the authoritative state hash in the native/Godot and both browser probes. No
production presentation mode was selected.

Measured facts are deliberately narrow: coverage, orientation cases, the existing
immutable RG8 handoff and full-texture upload behavior. Snapshot copy/upload byte
semantics remain those of the current renderer. This work did not establish a GPU
timing improvement, reduced upload cost or universal flicker result.

## V2 result: normalized policy and deterministic lab

The version-1 policy has these independent dimensions:

| Dimension | Registered range/current control |
|---|---|
| semantic Water mass | integer bits 3..8; control 8 |
| coherent emission | integer ticks 0..12; named 12, 7, 3, 0; control 12 |
| presentation | legacy, four-level, oriented four-level |
| interface mode | none or local gradient, presentation-only |
| scenario | one of 35 registered recipe IDs |
| identity | seed, recipe version/hash, canonical policy JSON/hash and provenance |

Profile/config, launch arguments and the developer panel feed one resolver. The
precedence is panel > launch > profile > default. Provenance validation requires
the effective source to agree with a strictly ordered layer chain. Invalid input
does not replace the current World and disables unsafe save/reset/blind actions.

Semantic Apply is a fresh-world transaction at the exclusive owner boundary.
Desktop commits policy only after worker acknowledgement; Web applies at its
synchronous main-thread owner. Rejection preserves the previous World and pause
state. Policy is never mutated under an executing worker. Presentation-only controls
may switch without a semantic reset and cannot mutate simulation authority.

Blind mapping uses deterministic seeded shuffling, anonymous labels and a
reconstructible export. Fresh tower clears hidden mapping and restores the
pre-blind base, while an in-run reset retains the label/mapping. A hidden policy
cannot leak into a saved profile. Observation export records policy, provenance,
scenario, seed, recipe/catalogue identity, presentation, bounded actions and
source/artifact/platform/worker identity.

## Scenario and H-ready candidate set

The 35 deterministic recipes cover shallow/deep/connected pools; calm settling;
tiny quantities, drips, trickles and residual pockets; narrow/broad channels,
steps, stairs, U-vessels, constrictions and nozzles; irregular beds; fast dumps,
slow releases, falls, ledge sheets, thin streams and shower/drizzle; vertical,
horizontal and diagonal references; excavation/refill, support removal and cavity
fill/drain; real voids/barriers; preserved Water/Sand and Mercury references;
supported body/player interactions; films; storage/activity/core seams; and
long-tail micro-motion. Non-body scenarios disable collision layers/masks, so a
body cannot accidentally vary those arms.

For later H comparisons, select any technically admitted mass3..8 and coherence
0..12 pair, then hold the scenario, seed, release/action schedule, camera/player
start, worker configuration and four-level presentation fixed. Record anonymous
pre-reveal observations about weight, fluidity, readability, liveliness, settling,
stream/puddle behavior, crawling/stickiness, chunkiness and game fit. The later H
owner—not this issue—classifies preferred/acceptable/unacceptable outcomes.

## #17 and current correspondence

The native suite establishes exact closed integer conservation for every runtime
mass arm, arithmetic and low-quantity boundaries for mass3/5/7, coherence creation/
decrement/movement/merge behavior across 0..12, repeat and one/four-worker parity,
and invalid-policy refusal. Initial physical quantization numerator/error is
reported separately from runtime drift. Initial values that quantize to zero are
skipped; a scheduled zero is an accepted no-op, not a source or sink.

Mass4/6/8 use the same registered quantization and tolerance oracle as #17. The
default mass8/coherence12 policy has exact current state-hash correspondence, and
coherence12 remains unchanged in the wider experimental carrier. This establishes
harness trust without repeating #17's full campaign and does not retract #17's
mass8 numerical-reference conclusion.

## Package DAG and execution

The preregistered DAG is retained in
[the experiment registration](../operations/water-feel-lab-experiment.md#implementation-package-dag).
P0 froze the contract. A (xHigh) owned conservation-sensitive native policy/math;
B (High) owned presentation-only shader/model work. Their RG8 normalized-mass
interface was frozen and their write sets did not overlap, so they were eligible
for one two-writer wave. The master serialized I1 integration. C (High) owned only
scenario registry/recipe tests; D (xHigh) owned only resolver/blind/panel models;
their opaque scenario-ID interface was frozen, so they were eligible for the
second two-writer wave. I2 integration and E evidence/docs were serialized under
the master. At no point were more than two write-capable workers allowed.

Terra xHigh independently reviewed B/C and consequential integration. Terra Max
reviewed A/D, owner-boundary integration and the integrated high-risk paths.
Spark xHigh handled the accepted correctness-sensitive repairs; the master owned
shared interfaces, integration and every disposition.

## Independent review findings and dispositions

Material findings were classified against the frozen contract:

| Finding | Classification | Master disposition and repair |
|---|---|---|
| non-body scenarios left Godot collision layers/masks active | confirmed defect | accepted; disable them for non-body scenarios and restore layer/mask 1 for supported scenarios; regression added |
| rejected asynchronous reset could leave a previously running lab paused | confirmed defect | accepted; restore prior pause state after rejection; regression added |
| blind exit/re-entry could expose/save a hidden candidate | confirmed defect | accepted; Fresh tower restores the pre-blind base and clears mapping; lifecycle/save regressions added |
| provenance accepted inconsistent effective source/layer claims | evidence-backed concern | accepted narrowly; vocabulary, monotonic ordering and final-layer/effective-source agreement are now validated; malformed seams rejected |
| real Web execution was initially absent | evidence gap | closed with rebuilt compatibility/threaded exports executed in Chrome 152 |
| blind lifecycle could leak through demo/profile exit, nested blind or ordinary policy apply | confirmed defect | accepted; transactional exit, nested/apply refusal and desktop/Web lifecycle regressions added |
| unregistered brush/Tower/config/import controls could vary a Water run | confirmed defect | accepted; authority-level desktop/Web guards and UI disabling added while registered actions/pause/step/reset remain available |
| ordinary worlds inherited an experimental Water policy | confirmed defect | accepted; ordinary constructors restore mass8/coherence12 and compare against clean-world hashes |
| incremental RG8 patches normalized Water as mass8 | confirmed defect | accepted; projection now receives the immutable World policy and mass3/4 dirty-patch regression added |
| blind machine export contains the reconstructible mapping | unsupported speculation | rejected: the frozen contract explicitly requires that mapping in machine export while visible status stays anonymous |

Other speculative concerns were checked against source/tests and not accepted
without evidence. Consequential repairs were re-run through focused and integrated
suites. The final stable diff received a final Terra Max read-only review; its
conclusion and any last disposition are recorded in the closing GitHub report.

## Validation matrix

| Surface | Command/evidence | Result |
|---|---|---|
| Native Windows | fresh compile and `build/test_world_issue19_final.exe` | 61/61 passed |
| Godot Windows | import plus every `godot/tests/test_*.gd` runner except the separately rendered GPU runner | 29/29 runners passed |
| Focused policy | `test_water_experiment_profiles.gd` | canonical/surfaces/precedence/provenance/invalid/blind/panel passed; hash `2bfdaa148c4c6e0da9db40361f7e2fd66544e0d3cac68fa466fd7348ed37671a` |
| Focused owner | `test_water_feel_controller.gd` | transactional rejection, collision isolation and blind lifecycle passed |
| Integrated desktop | `test_water_feel_integration.gd` | 24 policy cases, 70 scenario builds/resets, invalid/actions/RG8/authority passed; default hash `7c40afe52c6e0e37` |
| Scenario registry | `test_water_feel_scenarios.gd` | 35 recipes; seed-0 catalogue hash `c0d465a25dfd0bf26301c1f2466b327c8d9af914e6254d9defff07a9bf662014` |
| Actual GPU | non-headless `test_water_presentation_render.gd` | OpenGL/NVIDIA: 2/4 and 8/16 coverage plus oriented right edge passed |
| Real Web compatibility | `node tools/web/run_browser_probe.mjs ...` | Chrome 152, cross-origin isolated; 70 scenario cases, 110 actions, controller Apply+Reset/single-step/blind/ordinary-exit lifecycle, invalid/presentation preservation, zero failures, 1 worker |
| Real Web threaded | same runner against threaded export | Chrome 152, isolated; same catalogue/default hash/lifecycle passes, 6 workers |

Both successful Web profiles report catalogue hash
`c49c729891b2884932f183ef5b253f3b0b385f78664c5d9e76c85dd918538281`
at seed 31 and default hash `2c1ae35dad232984`. Profile equality is exact.
The first compatibility run used a stale WASM
(`9ad8d7a15dea271b369324ce1a54c615e63e4a8627367e0e7152fcc394e53f55`)
and correctly failed `shower-drizzle/fill mass3`; rebuilding from the recorded
source produced the passing artifact above. The failure is preserved, not erased.

## Repository gates

- `python tools/ci/check_m11_consistency.py` passes all 18 immutable records and
  28 historical source hashes.
- `python tools/docs/retrieval_eval.py` routes all 32 frozen questions to a
  canonical result within five: hit@1 22/32 and MRR@5 0.8229. This is lexical
  routing, not answer proof.
- `git diff --check` passes.
- `check_docs.py` and therefore `check_repository.py` retain six pre-existing
  expected-fact path failures: `SOURCE-PROVENANCE.json`, `docs/WEB_THREADING.md`,
  `tools/dev.py`, `docs/LOCAL_DEVELOPMENT.md` and
  `validation/browser-results.json` (some are referenced by multiple questions).
  #19 does not invent those historical files.
- Pull request CI rebuilt the Linux GDExtension from issue source with the pinned
  Ubuntu 24.04/G++ 13/Godot 4.7 toolchain. Run 34726713968 passed the ABI floor
  and all 34 Godot invocations, including the #19 controller, policy, scenario and
  integration suites. The actual-pixel presentation oracle now exits explicitly
  under a headless DisplayServer instead of waiting for a frame that cannot be
  submitted; the retained Windows/NVIDIA GPU run remains the pixel oracle.
- The CI-produced Linux object is materialized at
  godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so
  (SHA-256 f44360702d942386bf515a201cf72018bed1568e14061cf0e586d2e30c351492,
  1,301,488 bytes). Its provenance records workflow run 34726713968, artifact
  10308325733, artifact ZIP SHA-256
  b651e65001bf63c965f7a070492b172300de9ca7dec2a079b40294ed0f637fdb
  and tested merge commit 1bf5a987e0bd48ead2828c5d7b6392d12a32b2ef.

## Limitations and gaps

- The available Windows/NVIDIA GPU and Chrome profiles passed; no macOS, mobile,
  alternate browser engine or representative GPU timing campaign was run.
- UI automation was unavailable because the trusted computer-control process
  exited. Actual Godot rendered pixels, instantiated desktop owner/controller
  paths and real Chrome exports were executed instead; no manual human preference
  or accessibility claim is made.
- Linux validation comes from the pinned Ubuntu CI job rather than the local host;
  this validates build/runtime parity but is not a production migration.
- Observation export is bounded experimental metadata, not a complete replay of
  arbitrary brush/player/OS input.
- Full-texture GPU upload cost is unchanged and no performance saving is inferred.

## Implementation commits

The source series from the preregistration through the validated browser harness is:

`e4f2212`, `86ed176`, `7bd31e4`, `0009288`, `fad813f`, `2080a3a`,
`dfa95b3`, `4150833`, `3d227f7`, `d9792e2`, `369b4a3`, `ef5e56d`,
`d97a8c6`, `d15fc9d`, `5691b16`, `0fc265b`, `17ff83f`,
`d0cb399`, `3ef4923`, `8ba0853`, `b66fce4`.

The pull request and GitHub closing report identify the final CI-derived Linux
runtime/provenance integration commit exactly.
