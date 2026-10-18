---
title: ACT-002 actor rig validation
status: Current
document-kind: evidence
scope: Dated Linux headless evidence for issue 168; target gameplay, learned policies and final CI remain separate gates
canonical-for: [act-002-actor-rig-evidence]
last-reviewed: 2026-10-18
related-documents: [../systems/actor-rigs.md, ../systems/actor-control-prototypes.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/validation-evidence.md, ../operations/local-build-and-validation.md]
---

# ACT-002 actor rigs — 2026-10-18

## Scope and recoverable source

[Issue #168](https://github.com/techrote/cybersand/issues/168) retains Runner,
Skimmer and Crawler as SetA and adds 26 rigs across SetB, SetF, SetY, SetU and
SetV. The [canonical rig contract](../systems/actor-rigs.md) owns the catalog,
per-rig controls, bounded motor/effect rules and shared human/policy interface.
SetV labels are fictional interface personas. No model service, learned policy,
native bridge change or native pressure solver is included.

The recoverable implementation is commit
`0049400345f4ed1e6f07f28eb27fa2909df65ae0`, Git tree
`c709b8c55097551c61f7c6c7c3466295e57f9819`, published in
[PR #170](https://github.com/techrote/cybersand/pull/170). The executions below captured baseline
`a532daa70140aac163e5501051fe5afa1bcf377f` plus working changes and per-file hashes.
Each run has its own isolated copy; an earlier run does not certify later file
changes. The corrected motor/session copy and final bootstrap copy share the
tested motor, effects, catalog, session and core/session test hashes. The latter
adds the production pointer projection seam and its passing integration fixture.
All **138 tracked Godot scripts, scenes and portable bootstrap files** in the
published implementation were compared with the final copy and match exactly.
This audit is a documentation successor to the executable checkpoint.

The 08:54 UTC concurrency refresh still found main at that baseline. Separate
work on [PR #167](https://github.com/techrote/cybersand/pull/167)
(`1ab7c9fc6bd35c832fdc70a4fcdfceae3e71d0f3`) and
[PR #169](https://github.com/techrote/cybersand/pull/169)
(`b3da04aa777ed0e6975663b101d9cd2bf11542ce`) was observed, not adopted. Their
district/material/parallax changes are outside this actor-rig checkpoint.

## Runtime identity

Execution used a fresh Linux x86_64 headless project, Godot
`4.7.stable.official.5b4e0cb0f` and Rapier2D `0.35.2`. The retained native
extension was used without rebuilding; all recorded native provenance source
inputs matched (`native_source_input_errors: []`). Native build/compiler
identity remains in the [Linux manifest](../../godot/addons/cybersand_native/runtime-provenance.linux.json).

| Artifact | SHA-256 |
|---|---|
| Godot archive | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c` |
| Godot executable | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Retained CyberSand Linux extension | `43e747137249041d56a522dbe0ec35219082ea555e1ec1cbdd40971c6a58db9c` |
| Rapier Linux extension | `147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831` |

The following paths are relative to `godot/`. They identify the tested motor/
session bytes and the final `actor-rigs-final-bootstrap` desktop integration.

| Source/test | SHA-256 |
|---|---|
| `scripts/actor_rig_catalog.gd` | `5808438bd056686c7f96d4ee81908588a2004b49d4b7c048124a86042ade2944` |
| `scripts/actor_rig_motor.gd` | `d1bbf55f839f2c29db7cb5cf2d7dc6bbfabddd780be07a5ab9510b2b2b886b60` |
| `scripts/actor_rig_effects.gd` | `bec291dccfc633cc601742381bf029f3fbcf5118cdc14f84a1a8f29ad35a6486` |
| `scripts/actor_prototype.gd` (unchanged SetA motor) | `ccb25275e52150f1e4bfdd228854da3bcaa6e1d2026b52775c3150e6f451bb92` |
| `scripts/actor_prototype_session.gd` | `99d6a77bdf8a45801da00a584428489ff56b4d65577e16153f7f258b2f331f0e` |
| `scripts/actor_prototype_panel.gd` | `7dbc412311647c81b94631c244143f5fe8c37fa21acbe19b6df213fc44041d1d` |
| `scripts/actor_prototype_overlay.gd` | `e87dcbf76ba33e3eceef42654e3be6e35b79a3d85cf73ee079406d11d3fe7735` |
| `scripts/main.gd` | `574027d56d5d09597ee7786a25e67c0115b0846698366cd002f7a5ee349afba7` |
| `scripts/simulation_worker.gd` | `39fc7bf5c79c288263ea1b752869b08c9875b1a3aa8f1801827f5625e5a8cf5f` |
| `scripts/simulation_snapshot.gd` (unchanged) | `a6c711859ee1713bab1f4ee76772f47b8c64bfd9150caa58793223f8e9c5981d` |
| `scripts/gameplay_recorder.gd` | `65c19c1c5a6ef34334bbaa49221f91259fd76007bb40797e6d834a18d19d77d8` |
| `tests/test_actor_rigs.gd` | `76699df7ba54cfc7e1f6025f21cdfd2ed396f2f1f32c1efa2a12a3925e396851` |
| `tests/test_actor_rig_session.gd` | `14cfc4ad084dbde13f75f94f351be72e9efe253fc3d9a6a2db9fafb9981a6f66` |
| `tests/test_actor_rig_integration.gd` | `ff9c63ac89e20a06cbb7f69ebac5c6de0afd12e79c47ad1dd0f14565d2fbeb80` |
| `.godot/global_script_class_cache.cfg` | `c12c6c09d5676170e9e236cd294e295b340c78f8076c0052c369e7e2b676b39a` |

## Commands and executed scope

Raw evidence lives under `/tmp/cybersand-actor-validation/`, outside source
history. `run_focused.py` checked the runtime bytes and native source inputs,
copied the current project, isolated XDG state and ran these command forms.
`ACT_PROJECT` selects the dated directory in the result table; `ACT_TEST` is a
test basename without `.gd`.

```sh
ACT_GODOT=/tmp/cybersand-actor-validation/runtime/godot
ACT_PROJECT=/tmp/cybersand-actor-validation/actor-rigs-verified-core/godot
"$ACT_GODOT" --headless --path "$ACT_PROJECT" --editor --import
"$ACT_GODOT" --headless --path "$ACT_PROJECT" --script "res://tests/$ACT_TEST.gd"
"$ACT_GODOT" --headless --path /tmp/cybersand-actor-validation/actor-rigs-final-bootstrap/godot --quit-after 60
```

Python subprocess limits were **240 s per import** and **180 s per test/scene**.
A pass requires exit 0, no timeout and no `ERROR:` or `SCRIPT ERROR:` in the log.
The runner stops after a failed command. A printed zero-assertion-failure count
or process exit 0 alone is insufficient, as the preserved fixture failures show.

| Isolated run / command | Outcome | Seconds |
|---|---|---:|
| `actor-rigs-verified-core` / import | Pass | 3.8238 |
| Same / `test_actor_rigs` | Pass, 61,932 assertions, 0 failures | 0.9164 |
| Same / `test_actor_rig_session` | Pass, 8,425 assertions, 0 failures | 0.8161 |
| `actor-rigs-final-bootstrap` / `test_actor_rig_integration` | Pass, 683 assertions, 0 failures; no editor import | 3.3225 |
| Same / unchanged `test_actor_prototypes` | Pass, 12,293 assertions, 0 failures | 0.4652 |
| Same / unchanged `test_actor_prototype_session` | Pass, 626 assertions, 0 failures | 0.5660 |
| Same / 60-frame scene | Pass using only the three tracked bootstrap files | 1.1176 |
| `act002-root-legacy` / import | Earlier checkpoint pass | 4.7262 |
| Same / `test_actor_prototype_integration` | Earlier checkpoint pass, 157 assertions | 2.8743 |
| Same / `test_gameplay_recorder` | Earlier checkpoint pass | 0.3653 |
| Same / 60-frame scene | Earlier checkpoint pass after editor import | 1.1227 |

The three new suites passed **71,040 assertions** (61,932 + 8,425 + 683) across
the verified motor/session and final bootstrap copies described above. The old
three SetA test files remain byte-identical to the recorded main baseline.

The new motor fixture exercises all 26 new rigs, finite/adversarial input,
rotation and clear-volume resizing, contact/adhesion, jump/flight/charge,
obstructed ropes, bounded excavation/blast and effect-origin occlusion. Its
native smoke uses `diagnostic_reset({"workers": 1})`, a one-cell wall and floor,
48 updates per new rig and independent material hash/count checks. Ordinary
motion leaves native material and World tick unchanged; a separate point-write
fixture checks editable material, Fire center and protected-wall occlusion.

The session fixture covers all 29 catalog entries, eight-slot capacity,
independent unchanged-SetA oracles through both action APIs, producer/epoch/
sequence/observation-age admission, consumed action/edge identity, auxiliary and
charge cancellation, and copied v1/v2 publications. It uses one scripted owner
and mock occupancy; it is not concurrent policy inference.

The integration fixture exercises actual worker receipts and
effects, extended human controls/rearm/pointer projection, every selector set,
rotated hull/anchor geometry, separate recorder actor/material clocks and
Tower/Water/MicroScenario exclusion. Its direct startup result exercises the
tracked portable script cache without an editor import; it is not GPU or OS
pointer acceptance.

## Preserved failures and corrections

| Retained execution or review | Finding and disposition |
|---|---|
| `actor-rigs-first`: 23,065 assertions, 9 reported failures; exit 1; 0.8170 s | One very large finite effect coordinate narrowed into an unintended integer location before admission. Eight later reports reused its contaminated counter. The production fix validates bounds before integer conversion; the fixture now isolates refusal counters. |
| Source review, dedicated final regressions | A muzzle/tool offset could skip an intervening thin wall. The motor now casts from actor center to the proposed effect origin, clamps to the first blocker and refuses if the shared ray budget is exhausted. No separately executed pre-fix negative control is claimed. |
| Source review, dedicated final regressions | A successful tuck retained contact sampled for the previous hull and could preserve unsupported ceiling adhesion. It now resamples actual resized-hull contacts before adhesion. No separately executed pre-fix negative control is claimed. |
| `actor-rigs-reviewed-core`: 61,932 assertions, exactly 1 failure; exit 1; 0.9166 s | Supported Ripper torque could not tip on a clear floor: accumulated Float32 subtraction put the bottom at 200.0000152588. The motor anchors support height once, applies 0.001-cell upward clearance, checks the interval maximum hull and charges the full pivot path against the movement quota. The unchanged core fixture passes in `actor-rigs-verified-core`. |
| `actor-rigs-integration-first`: 681 assertions, 0 assertion failures; process exit 0; runner failed; 3.3737 s | A test-owned minimal KeyboardHarness omitted `Layout/World` and `Layout/Status`, producing engine errors and a null material access. The corrected final fixture passed; this run remains failed. |
| `actor-rigs-integration-second` and `actor-rigs-integration-verified`: each 684 assertions, 2 failures; exit 1; 3.2219 / 3.4237 s | Both synthetic OS-coordinate fixtures failed to place the pointer in the intended local viewport coordinates under headless root-window stretch. A separate probe distinguished root-window distortion from working SubViewport input. The production adapter now delegates through `actor_pointer_aim_at(local_coordinate)`; the final fixture verifies that real projection math directly and retains the keyboard adapter checks. Neither failed directory is a pass despite the latter's name. |
| `actor-rigs-core-freeze` / import: process exit 0; runner failed; 4.8283 s | The default sandbox could not create the editor's TCP listener. This environment failure is retained separately; fresh permitted imports above passed. No source parser failure or gameplay pass is inferred from that failed import. |

The failing Ripper motor hash was
`bcfae82ec62e7fa4b040ebc730d80dbd7cfaa8bdc15c8dd6fb4a5cba042407f9`;
its core test hash is identical to the passing fixture table above. The initial
finite-coordinate effect hash was
`378ae7eb958de160bb1559ea971b267f62ecd1ebc59a64b5ae00eeff09756702`.
The motor bounds and their failing regression assertions were retained. The
pointer fixture's input-source correction does not establish OS-level pointer or
interactive visual acceptance. Historical audit files were not rewritten.

## Informational timing and limits

In `actor-rigs-verified-core`, 600 mock-World updates per new motor measured local
means of **17.610–46.050 µs**. Fixture peaks were **19/96 occupancy queries**,
**57/64 ray reads**, **49/64 effect reads** and **29/64 cell writes** per actor
update. These are observed fixture peaks against distinct explicit caps, not a
proof that ordinary frame time includes all native material reactions.

Eight mixed scripted actors, owner `step()` and copied v1/v2/action publication
averaged **390.143 µs** over 600 mock steps, with peak **70 aggregate occupancy
queries** and **47 aggregate material reads**. This one-process Linux headless
measurement includes no native world-tick throughput, GPU work, external
inference, target-PC guarantee, production crowd acceptance or allocation audit.

## Evidence files

| File relative to the raw evidence root | SHA-256 |
|---|---|
| `actor-rigs-verified-core/identity.json` | `b383e38752a8752bf51ea039a44ada9540d89db89cfd960ff17aa7414f92f572` |
| `actor-rigs-verified-core/results.json` | `8b6a8803c57ed97a75dccba92f2a024fdbd7fed1edb04e7cad86ec7aa7a13862` |
| `act002-source-comparison.json` | `f372bde39f020977c24ea764eccdf8ad2f02d5c4af01ff2ef4426408f5e2eedc` |
| `actor-rigs-final-bootstrap/identity.json` | `8a250928be37095c1450eeee29f2e9201d15917e36261eab643912698ced7e42` |
| `actor-rigs-final-bootstrap/results.json` | `f716c282db2730800f016b998fe685a1f617568cb62e82b14ebbbc2f0061f7c9` |
| `actor-rigs-reviewed-core/identity.json` | `1f2e0599d4d350c614f698442b5f6927703549d81a35ef0017c73049a951cc00` |
| `actor-rigs-reviewed-core/results.json` | `2f81835de2c7c9c907265a9dcf15da9325eae64687589add720596cde5c835ad` |
| `actor-rigs-first/identity.json` | `20c4d202d7a24eb2597fdca38146199b400ade4b294802f4132ae40d720e6914` |
| `actor-rigs-first/results.json` | `c85afb81318356bd0528411dea4510b2dc6fc73db943747b84dd77e7a80e9361` |
| `act002-root-legacy/identity.json` | `bc1d071a20d14c751c4ed0c9e3a8151247eead23ce8fd2fe1ae9e3b80bd9993c` |
| `act002-root-legacy/results.json` | `2f33cd5a06fb23737b2d1f3d1ba30e7bb19ce239eeadc43a3f8c4ba5851b11b7` |
| `actor-rigs-integration-first/results.json` | `ed448ff1d1dae6cf4577b0ffb7dfa21597154503bf15f9cadf958ec0038be06d` |
| `actor-rigs-integration-second/results.json` | `5868d8a2adbff24ae2ec335ef60f21aae1d85828629627bdac2cbdbaf3416589` |
| `actor-rigs-integration-verified/identity.json` | `3cdab5f1685078a787c1da4e64c94597bc4ed4e06217e7ce90784debf809f4a7` |
| `actor-rigs-integration-verified/results.json` | `f0e2000bac63787f25f05939d341f204953c4ae4dfd1c68a004b1ef9e81e782c` |
| `actor-rigs-core-freeze/results.json` | `1426b78cf627af82e5ab0edfdfac6a0107969edeb259afcc0171ae7f1bfd4e72` |

## Documentation and compatibility

| Concern | Current route and preserved boundary |
|---|---|
| Full catalog/control meanings | [Actor rigs](../systems/actor-rigs.md); SetV personas explicitly fictional |
| SetA/action-v1 compatibility | [Original actor contract](../systems/actor-control-prototypes.md); original motor and ACT-001 dated record preserved |
| Owner and snapshot contracts | [Ownership](../architecture/data-ownership-and-lifetimes.md) and [interfaces](../reference/interfaces-and-message-contracts.md); owner-only World/effects, immutable value publications |
| Budgets and fixtures | [Configuration](../reference/configuration-reference.md#actor-rig-values) and [build/test route](../operations/local-build-and-validation.md#actor-rig-checks); scientific scenarios keep their existing apparatus |
| Current navigation/status | README, docs index, handover, product-intent and roadmap route the new canonical page |
| Evidence/retrieval | Validation ledger links this dated record; corpus excludes it from default current answers; frozen 32-question set and historical audits retained |

After adding this audit and its routes, `python3 tools/ci/check_docs.py` passed
80 documents, 138 canonical claims, 1,358 links and 81 anchors with zero errors/
warnings. `python3 tools/ci/check_repository.py --require-materialized` passed
all 18 runtime payloads/source hashes. `python3 tools/ci/check_m11_consistency.py`
passed 18 historical records/28 hashes at its recorded `05ea45f` source.
`git diff --check` passed. Native/bridge source, the original SetA motor and its
three tests, the ACT-001 audit and the frozen question set have no implementation
diff from the main baseline.

The 80-document/804-chunk local retrieval result found targets in the top five
for **32/32 frozen questions** (22 top-one; MRR 0.8281) and **45/45 supplemental
questions** (33 top-one; MRR 0.8507); ACT-01–09 ranked first. Manual review found
ACT-05's complete desktop bindings and ACT-09's exact v2 field layout require
following the canonical controls/observation sections. Rank alone does not prove
complete single-chunk answers. These are local documentation/retrieval checks.
The final result files are `/tmp/act002-retrieval-audit-final.json` and
`/tmp/act002-challenges-audit-final.json`, produced by `tools/docs/retrieval_eval.py`
with the default query set and `--queries docs/reference/retrieval-challenges.json`.

## Publication and remaining gates

Full hosted CI remained pending at this local evidence checkpoint's initial
publication. [PR #170](https://github.com/techrote/cybersand/pull/170) owns the final
Documentation/provenance, Native and GDExtension/Godot outcomes and merge
disposition; this local record does not claim those gates passed.
Initial draft [Documentation 39113810258](https://github.com/techrote/cybersand/actions/runs/39113810258)
passed on the implementation checkpoint; expensive runs
[39113810286](https://github.com/techrote/cybersand/actions/runs/39113810286) and
[39113810298](https://github.com/techrote/cybersand/actions/runs/39113810298) were
skipped by draft gating. Those skipped runs are not full gate passes.
Water apparatus path scope is not triggered by this GDScript/docs diff.
Windows hands-on play, Web/browser integration, GPU visual review, owner control
feel, trained-policy evaluation and target hardware scaling remain unclaimed.
