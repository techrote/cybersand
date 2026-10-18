---
title: ACT-003 Thunderbowl control lab validation
status: Current
document-kind: evidence
scope: Dated Linux headless evidence for issue 172; prototype mechanics and contract acceptance, with separate hosted CI, hardware and learned-policy limits
canonical-for: [act-003-thunderbowl-evidence]
last-reviewed: 2026-10-18
related-documents: [../systems/thunderbowl-control-reference.md, ../systems/actor-rigs.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../reference/validation-evidence.md, ../operations/local-build-and-validation.md]
---

# ACT-003 Thunderbowl control lab — 2026-10-18

## Scope and recoverable source

[Issue #172](https://github.com/techrote/cybersand/issues/172) adds a standalone,
eight-actor native arena, virtual tag combat, three direct actuator profiles and
versioned controller examples. The [canonical reference](../systems/thunderbowl-control-reference.md)
owns the wire/metal distinction, observation privileges, three swarm baselines,
NCA-inspired graph, smart-link protocol and runnable commands. This checkpoint
does not implement native actor damage/contact, trained policies, terrain-lattice
NCA training or a live model/vision service.

The recoverable implementation is commit
`4252040a57a4aec601ddaf286dbd8b0471453089`, Git tree
`5fd242bd86050ac5bb53b8a5ac990cfc0882d204`, parent
`087ca3e972296b189c8b83060463125c06d600e2`, on
`codex/act003-thunderbowl-control-lab` in
[PR #174](https://github.com/techrote/cybersand/pull/174).
The execution identity captured that parent plus working changes and per-file
hashes. A subsequent comparison against the published commit verified all
**194 relevant Godot source/configuration/resource files**, with zero mismatches.
This audit is a documentation successor, not a later executable implementation.

## Runtime and source identity

The isolated Linux x86_64 headless copy used Godot
`4.7.stable.official.5b4e0cb0f`, Rapier2D `0.35.2` and the retained native
extension. No native/bridge source or runtime library was changed or rebuilt.
All native provenance source inputs matched (`native_source_input_errors: []`);
the [Linux provenance manifest](../../godot/addons/cybersand_native/runtime-provenance.linux.json)
owns the retained compiler/build identity. No CPU-model performance claim is made.

| Artifact | SHA-256 |
|---|---|
| Godot archive | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c` |
| Godot executable | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| CyberSand Linux extension | `43e747137249041d56a522dbe0ec35219082ea555e1ec1cbdd40971c6a58db9c` |
| Rapier Linux extension | `147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831` |

Selected final source/test hashes follow; paths are relative to `godot/`.
The complete copied-file manifest is in the hashed execution identity below.

| Source/test | SHA-256 |
|---|---|
| `scripts/thunderbowl_contract.gd` | `1eb1c5cfcd6ec5db398a9677413ec1afefcaf0c2337427d51c6c545a21391218` |
| `scripts/thunderbowl_arena.gd` | `d075422be9275fc3ca2543e977a39d39d2397335f2785d9c475df78c20fd5ab5` |
| `scripts/actor_rig_actuation.gd` | `78ba62edbffcf9af9e0f4f1b35831dd29d5ad67bc60e7b2ecbfd78fee59ae251` |
| `scripts/actor_rig_motor.gd` | `27b0c731c1495f635c4ee772e6bd678b2d72c1bbc3f0240f429c11f208f3d1fb` |
| `scripts/actor_prototype_session.gd` | `c19f965360143484e499227a3aa32b225a235e74b904a0204a69315b4b7d1a45` |
| `scripts/simulation_worker.gd` | `b431ae210ad5665eb54e3ee100e35919f6a690542fb0009b6da6a6c9ca8aeebe` |
| `examples/thunderbowl/thunderbowl_driver.gd` | `18874191f0abecfc6aa1ab5d96afc7f98c5057e62d66285f5f21b06e8bba901b` |
| `examples/thunderbowl/thunderbowl_scene.gd` | `d1ae9f59b7cc3ecf06d4604665ff2794463b1a9193fa47f55e8a524c6a16549c` |
| `examples/thunderbowl/run_thunderbowl.gd` | `320b83df4b5219e10cc1f6ee0cf5bcd1eb638705f4da7960b319d3e1b5f11a82` |
| `examples/thunderbowl/smart_link.gd` | `ab27dc96bf33f3931be9b6945fc611a1d11cd8aff6ea52b06a4ee7c12fdfc43f` |
| `examples/thunderbowl/nca.gd` | `93191e9becb5bc9d2cf31c77db1d3e2d4f4b32a6536748c7c43f811f997eae5b` |
| `examples/thunderbowl/nca_seed_weights.json` | `79d95aafd6e10285630533849448fa50597deec52b281237524f28a1b73e2c21` |
| `tests/test_thunderbowl_arena.gd` | `c1f828c25143b9a8338fb6d6cfa3d957a87bf5c92b35de20f9f21b08f1794df1` |
| `tests/test_thunderbowl_controllers.gd` | `2e61313a44e9f5a83cf9b01a446a0f2be297ff51308ef627e3ebb9617c414879` |
| `tests/test_actor_rig_actuation.gd` | `7c0d694c346273657858347678fef3517c298236217ac1658f93a7d775eb4039` |
| `tests/test_actor_actuator_session.gd` | `cf4d17960dbb848630d6614a1987e4557ba37ac9941c8385c04d8527e61e1c66` |
| `.godot/global_script_class_cache.cfg` | `035aa56658b46fb19e2b745045736480aed72daaeb287cbacad9bc2c649ab82e` |

## Final local execution

Raw evidence is under `/tmp/cybersand-actor-validation/`, outside source history.
`run_focused.py` verified pinned runtimes/native inputs, copied the project and
isolated XDG data/config/cache directories. The `thunderbowl-final-bootstrap`
run used only the three tracked portable bootstrap files: **no editor import**.
Its command forms were:

```sh
ACT003_GODOT=/tmp/cybersand-actor-validation/runtime/godot
ACT003_PROJECT=/tmp/cybersand-actor-validation/thunderbowl-final-bootstrap/godot
"$ACT003_GODOT" --headless --path "$ACT003_PROJECT" --script "res://tests/$ACT003_TEST.gd"
"$ACT003_GODOT" --headless --path "$ACT003_PROJECT" --quit-after 60
```

`ACT003_TEST` selects each basename below. Python subprocess limits were
**180 seconds per test or scene**. A pass requires exit 0, no timeout, and no
`ERROR:` or `SCRIPT ERROR:`. The recorded **14.0453 seconds** is the sum of
case durations, not a whole-task or performance benchmark. All 11 processes
passed, totaling **109,944 assertions and zero failures**.

| Test/scene | Assertions | Seconds |
|---|---:|---:|
| `test_thunderbowl_arena` | 621 | 2.4205 |
| `test_thunderbowl_controllers` | 712 | 0.9166 |
| `test_actor_rig_actuation` | 24,338 | 0.2648 |
| `test_actor_actuator_session` | 157 | 0.4684 |
| `test_actor_rigs` | 61,932 | 0.9163 |
| `test_actor_rig_session` | 8,425 | 0.8159 |
| `test_actor_rig_integration` | 683 | 3.3247 |
| `test_actor_prototypes` | 12,293 | 0.4651 |
| `test_actor_prototype_session` | 626 | 0.5658 |
| `test_actor_prototype_integration` | 157 | 2.7704 |
| Ordinary main scene, 60 frames | Not assertion-counted | 1.1168 |

The four new suites contribute 25,828 assertions. The existing six actor suites
retain their original test bytes. Arena coverage uses actual native worlds with
`workers: 1`: all 29 rigs, issued-observation/epoch/sequence/lease admission,
hidden-state local-view invariance, terrain LOS, simultaneous virtual tags,
message types/expiry, native digging, deterministic paired traces and failed-owner
quarantine. Driver/scene checks cover first-frame wire/raw human input, ordinary
and oracle command-to-slot binding, typed file replies, device disconnect/reconnect,
all-pad release/rearm and actual local-coordinate projection paths.

The actuator fixture independently checks authored force/mass and torque/inertia
laws, rotated axes, Ripper support projection, Gemini arm moments, proportional
energy limits, empty-energy demand, neutral/passive behavior and brake dissipation.
Its counted mock World exercises collision, burial, rotation and timestep/speed
caps; requested/applied/passive wrenches remain distinct from collision-limited
motion. The session test includes a real producer `Thread` gated during candidate
configuration, with a mock-World owner, and an unstarted worker forwarder. These
are not SI/Rapier force measurements or arbitrary-script sandbox tests.

## CLI, mock link and JSON Schema

`thunderbowl-live-link/results.json` retains exact argv/environment/timeouts.
The frozen headless runner used `matches/mixed.json`, `--ticks=360`, `--seed=73`,
`--realtime`, an existing `--smart-dir`, and a JSON output path. Concurrently,
`tools/thunderbowl/mock_smart_link.py` watched actor 7's request/response files
with `--watch --seconds 9`. The CLI passed in 6.4309 s (20 s limit); the mock
passed in 9.1014 s (15 s limit). The 360-tick run ended at `tick_limit`, with
12 mock replies for observed ticks 0–330 at 30-tick intervals: 12 admitted,
zero rejected. Owner totals were 349 admitted commands, zero refusals and zero
driver-origin rejections. Initial/final native state hashes were
`325ee2614ea8f6ac` / `7ae3d5d62ea76d98`.

`tools/thunderbowl/validate_examples.py --capture <recorded-capture> --output <report>`
passed **215 cases across eight schemas**: 197 captured valid/invalid contract
cases plus 18 static fixtures. It used `jsonschema 4.26.0` and
`referencing 0.37.0`, took 0.3107 s, had a 30 s limit and exited 0 with zero
failures. The captured-case SHA-256 is
`74a66c5cab388ca27692bfb377e8d1426e006b3995f3c882107124808ab6671d`.
The mock and validation helper hashes are respectively
`cce70804d193626deb415aea565a57cd179b368496bb26d6f986ee0cdf9ac0b4`
and `9ca2440125a47043ccbd1cfbdcf90bb5ba2818e8a21282e08362c8b0e9d9f69b`.
This is a local offline mock contract exercise, not model/network inference.

## Preserved failures and corrections

| Retained run/review | Finding and disposition |
|---|---|
| `thunderbowl-arena-first`: 469 assertions, 1 failure; exit 1; 1.7690 s; 180 s limit | Arena read `state_hash` from `diagnostic_snapshot`, which publishes `hash`, leaving material identity empty. Both reads were fixed. The unchanged 469-assertion fixture passed in `thunderbowl-arena-second` (1.7693 s). |
| `thunderbowl-arena-second/visible-scene`: exit 0, failed log scan; 1.0170 s; 180 s limit | Unsupported `%g` formatting generated engine errors. Supported floating formatting replaced it. The separate core pass does not turn this scene run into a pass. |
| `thunderbowl-arena-integrated`: 608 assertions, 3 failures; exit 1; 2.0187 s; 180 s limit | Synthetic input did not populate physical-key polling, producing two rearm failures; an absolute tick assertion ignored advancement during awaited frames. Final fixtures use narrow production input/projection seams and compare relative advancement. This is no physical-device acceptance claim. |
| Ad hoc pre-fix probes, final negative regressions | `thunderbowl-review-json-types.gd` and `thunderbowl-review-routing.gd` reproduced invalid scalar comparisons and cross-slot command routing. Strict typed guards now reject malformed values; ordinary/oracle output is bound to its assigned actor. |
| Source/driver review, final regressions | Smart `speed` previously changed effort without scaling movement; zero demand now cancels and positive demand scales both. `decide_input` now binds identity before copying the first human frame. Removal/replacement of the selected gamepad forces release/rearm before another pad can resume input. |

The first failing arena SHA-256 was
`9ba446ac0c47dfab195030c9a788ae2fa489afc698e0d3b79f4018f146f09073`;
its original fixture SHA-256 was
`75495d1a33bdfc5715db11b7a3a08a3a3b38b0d9b80f31e940543682ab71777c`.
The two retained scratch probes reproduced the scalar/routing defects; they are
not a fully source-bound acceptance campaign. The speed/first-frame findings are
source-review findings, without separate executed pre-fix controls claimed here.
Earlier imports used 240 s limits; the final bootstrap gate did not run one.
Historical ACT-001/ACT-002 records and their unchanged regression tests were preserved.

## Bounds, timing and evidence limits

The prototype caps actors/commands at eight, messages at four floats and seven
senders per recipient, history at 128 events, JSON files at 64 KiB, and command
leases at 18 ticks (12 by default). Motor calls retain 96 occupancy queries,
64 ray reads and existing 64-read/64-write effect limits, with dt ≤1/30 s and
speed ≤160 cells/s; SetA retains its earlier limits. Arena sensor/tag budgets
are 8,192/10,752 reads. The [configuration contract](../reference/configuration-reference.md#thunderbowl-values)
owns exact capacity outcomes and the separation from optional presentation work.

The final actuator fixture observed peak **22/96 occupancy queries** and zero
material/ray/effect reads or writes. The native paired-arena fixture ran two
eight-actor, workers=1 worlds for 120 ticks each in **361,654 µs**, including
10 Hz observations/actions, 60 Hz motors/materials, evaluator copies and equality
checks; peak sensor reads were **1,104**, with **61 actual terrain edits**.
This is informational local-host timing. The CLI's **6,000,200 µs** loop included
deliberate wall-clock pacing and optional file I/O; it is not a throughput result.

No GPU/Windows/Web, physical keyboard/gamepad/touch, human control-feel,
hard-real-time, allocation-free or large-population acceptance is claimed.
The visible scene is a full evaluator view, not human/local-bot sensory parity.
Local observations and driver assignment checks are trusted-code contracts,
not an in-process security sandbox. The untrained NCA graph and mock smart link
provide no learned-policy, density-benefit or advanced-model efficacy evidence.

## Evidence files and documentation compatibility

Paths below are relative to `/tmp/cybersand-actor-validation/`; generated logs,
projects and runtime artifacts are not committed.

| Evidence file | SHA-256 |
|---|---|
| `thunderbowl-final-bootstrap/identity.json` | `f52bfd0db92278dd6bafa014e30c2f660f8574d0dbf71bddb2c7174d5b8e55cf` |
| `thunderbowl-final-bootstrap/results.json` | `ee3d24be99c8f1d0946780e8c4b3336fa8662c254505dfce8976537a6cd4893b` |
| `thunderbowl-final-bootstrap/final-source-comparison.json` | `bf1c17970de562b59c64ad5f6a91725de32cf988b63d68f91e56ccc8ff4c5dc4` |
| `thunderbowl-live-link/results.json` | `c408b301e8a5f6370bdf33d39f477733581be4313f29e79666ee0fed57e73e6f` |
| `thunderbowl-live-link/schema-results.json` | `d413026af807110ec6c0b89834ec2719f1421ff8d1054ccb4becd3e288271914` |
| `thunderbowl-live-link/published-source-verification.json` | `6da344185a89baa725f1fbfa7ce00f3bba84d0fc42bf8e1e8dfe72de4ebabc0a` |
| `thunderbowl-arena-first/results.json` | `621abecc1b428c93cb759d4e24c002a4e702790563ca0542920e7cb1a0843a25` |
| `thunderbowl-arena-second/example-results.json` | `1f3213e981ad2e5d3c5be60157c6b4388f15f08243dd13b3d8aca6a065f46ea4` |
| `thunderbowl-arena-integrated/results.json` | `12b23d48ad94ce6aa5e8bfe5841048d2bf2958b89547e05eecd19f0f7188d31a` |

| Concern | Canonical route / preserved boundary |
|---|---|
| Controls, topology, schemas and examples | [Thunderbowl reference](../systems/thunderbowl-control-reference.md); current prototypes and Planned training are distinguished |
| Owner/value lifetime and packet admission | [Ownership](../architecture/data-ownership-and-lifetimes.md), [interfaces](../reference/interfaces-and-message-contracts.md); copied views and fixed lanes |
| Capacity and execution | [Configuration](../reference/configuration-reference.md#thunderbowl-values), [build/tests](../operations/local-build-and-validation.md#thunderbowl-controls-and-native-arena) |
| Existing gameplay and evidence | [Actor rigs](../systems/actor-rigs.md), [SetA](../systems/actor-control-prototypes.md), prior dated audits; ordinary F5/scientific fixtures retain their interfaces |
| Navigation/retrieval/evidence | README, handover, index and roadmap route the canonical page; the validation ledger routes this dated checkpoint; frozen retrieval questions are retained |

Final local documentation gates passed: `python3 tools/ci/check_docs.py` checked
81 documents, 141 canonical claims, 1,392 links and 83 anchors with zero errors
or warnings. `check_repository.py --require-materialized` passed all 18 runtime
payloads; historical `check_m11_consistency.py` passed 18 records/28 hashes.
The lexical retrieval evaluation covered 81 documents/825 chunks: frozen
questions **32/32 top-five** (22 top-one, MRR 0.8281), supplemental questions
**51/51 top-five** (40 top-one, MRR 0.8781), with THB-01–06 all ranked first.
Results are `thunderbowl-final-frozen-retrieval.json` and
`thunderbowl-final-supplemental-retrieval.json` under the raw evidence root.
Retrieval rank does not establish answer sufficiency or runtime correctness.

## Publication and remaining gates

Full hosted implementation CI remained pending at this local checkpoint's initial
publication. [PR #174](https://github.com/techrote/cybersand/pull/174) owns the final
exact-head Documentation/provenance, Native, GDExtension/Godot and merge disposition.
Initial draft [Documentation 39120887269](https://github.com/techrote/cybersand/actions/runs/39120887269)
passed; [Native 39120887184](https://github.com/techrote/cybersand/actions/runs/39120887184)
and [Godot 39120887159](https://github.com/techrote/cybersand/actions/runs/39120887159)
were skipped by draft gating. On the ready transition,
[Documentation 39120962091](https://github.com/techrote/cybersand/actions/runs/39120962091)
passed, while [Native 39120962099](https://github.com/techrote/cybersand/actions/runs/39120962099)
and [Godot 39120962170](https://github.com/techrote/cybersand/actions/runs/39120962170)
reported scope-only success with their actual build/regression jobs skipped.
Neither skipped run is full gate acceptance. The audit/docs synchronization
successor triggers the required implementation jobs without changing CI policy.
Water apparatus path scope is not triggered by this GDScript/example/docs change.
