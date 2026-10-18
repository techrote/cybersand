---
title: ACT-001 actor control prototype validation
status: Current
document-kind: evidence
scope: Dated Linux headless implementation evidence for issue 161; target gameplay, learned policies and final CI remain separate gates
canonical-for: [act-001-actor-control-evidence]
last-reviewed: 2026-10-18
related-documents: [../systems/actor-control-prototypes.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/configuration-reference.md, ../reference/validation-evidence.md, ../operations/local-build-and-validation.md]
---

# ACT-001 actor control prototypes — 2026-10-18

## Scope and recoverable source

[Issue #161](https://github.com/techrote/cybersand/issues/161) adds three optional
desktop actor motors: Runner, Skimmer and Crawler. Their shared action and
observation contract supports keyboard, scripted demonstration and external
policy producers. No inference engine, trained network or native simulation
change is included. The [canonical actor contract](../systems/actor-control-prototypes.md)
owns controls, capabilities, ownership, command expiry and experimental limits.

The public implementation checkpoint is
`e6d3b8daad445bb001aa6917b0a9e4da783a1bc6`, Git tree
`8080bd3206914d6efb49ef5997b4149f73b4aeb5`. Local checkpoint
`99dcd70bf93d71fda1b803d25bf99d179c9a5261` has the identical tree.
Runtime capture preceded that commit: its identity records baseline
`ec05d7227885bda59bf72a5889b004296b9a07e5` plus the working changes and per-file
hashes. All eleven changed actor/integration script and test hashes below were
compared with the public checkpoint and match exactly. The final validation
summary reports no script, scene or test changes since its isolated snapshot.
This audit is a documentation successor, not a new executable checkpoint.

## Runtime and content identity

Execution used an isolated Linux x86_64 headless project, Godot
`4.7.stable.official.5b4e0cb0f` and Rapier2D `0.35.2`. The retained native
runtime was used without rebuilding; its provenance source inputs all matched
(`native_source_input_errors: []`). Its earlier build/compiler evidence stays in
the [Linux runtime manifest](../../godot/addons/cybersand_native/runtime-provenance.linux.json).
No Windows or Web execution is inferred from this Linux result.

| Artifact | SHA-256 |
|---|---|
| Godot archive | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c` |
| Godot executable | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Retained CyberSand Linux extension | `43e747137249041d56a522dbe0ec35219082ea555e1ec1cbdd40971c6a58db9c` |
| Rapier Linux extension | `147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831` |

Paths in the following table are relative to `godot/`.

| Source/test | SHA-256 |
|---|---|
| `scripts/actor_prototype.gd` | `ccb25275e52150f1e4bfdd228854da3bcaa6e1d2026b52775c3150e6f451bb92` |
| `scripts/actor_prototype_session.gd` | `98586a84e4fb4c51615c2eebb44fed813477976a67c79fd6fd65a0adccb74771` |
| `scripts/actor_prototype_panel.gd` | `95f84a092adef9987ea1a63887ac92be4e53c8ba1442f6d99e3561773bef35b5` |
| `scripts/actor_prototype_overlay.gd` | `a8d67367629df39d4190175d23025af325c5730744f3a5c9d6aefe43af59a4e8` |
| `scripts/main.gd` | `cdd264df462cb0f05dcc5a01722d9854bc096d5e08cd7811a728bb222eb40de8` |
| `scripts/simulation_worker.gd` | `41c28848f045ba03c5c26fe84b67fc0fecf992b762f0cad28a5eff1a51b28af9` |
| `scripts/simulation_snapshot.gd` | `a6c711859ee1713bab1f4ee76772f47b8c64bfd9150caa58793223f8e9c5981d` |
| `scripts/gameplay_recorder.gd` | `f23a94be81537fccd6076968d51f35f280daf4667b208394517997128de3ca08` |
| `tests/test_actor_prototypes.gd` | `a1af3bedca1f04fe4c515c8d0efedd05dacffd73dc8615893a66b4806a3d6ae5` |
| `tests/test_actor_prototype_session.gd` | `a2e443d1b3ab8c6a2cdd2723693892074ab5aa5f406d060862cc5a584d369c9d` |
| `tests/test_actor_prototype_integration.gd` | `42d560eaae52e77ce80ba5bbda120e4d708b1f9bd7ddd787777f1d9224cf03cc` |

Raw evidence root is `/tmp/cybersand-actor-validation/`; generated files are
excluded from source history. `final-validation-summary.json` binds these records;
this audit preserves their identities/results if temporary files become unavailable.

| Evidence file, relative to that root | SHA-256 |
|---|---|
| `actor-final-focused/identity.json` | `8ba838451f3701541831c8e1db0073f582274d8e66c06d3081474fbeb72d065c` |
| `actor-final-focused/results.json` | `d9ea1e88db9977e1f9170b3bd99124a322578d9e30866cbbd2908d8a6ffb336a` |
| `actor-bootstrap-first/identity.json` | `94a36248f7c6acc4a1807afe44318004b9f0135ea6adaf69a708bff6ad6eaab5` |
| `actor-bootstrap-first/results.json` | `1371dd01f2266c0fe876d78817f8a925edb0b92b74ee250e4a843aca52252886` |

## Executed commands and coverage

`run_focused.py` copied the project into a fresh directory, materialized the
verified runtime bytes and isolated XDG state. It executed the commands below
with Python subprocess limits of **240 seconds for import** and **180 seconds
per test/scene**. Each accepted run exited 0 without `ERROR:` or `SCRIPT ERROR:`.
`ACT_TEST` denotes each test basename in the table, without `.gd`.

```sh
ACT_GODOT=/tmp/cybersand-actor-validation/runtime/godot
ACT_PROJECT=/tmp/cybersand-actor-validation/actor-final-focused/godot
"$ACT_GODOT" --headless --path "$ACT_PROJECT" --editor --import
"$ACT_GODOT" --headless --path "$ACT_PROJECT" --script "res://tests/$ACT_TEST.gd"
"$ACT_GODOT" --headless --path /tmp/cybersand-actor-validation/actor-bootstrap-first/godot --quit-after 180
```

Clean import and all **12 focused regressions passed**, totaling **84.5401 s**
for the 13 commands. The three new actor suites contain **13,076 assertions**
(12,293 + 626 + 157), with zero failures.

| Test basename | Executed scope | Result |
|---|---|---|
| `test_actor_prototypes` | Model response, edges, energy, safe clamber, burial, bounds and native hard-surface conservation | Pass, 12,293 assertions |
| `test_actor_prototype_session` | Capacity, producer/epoch/sequence/lease admission, coalescing, cancellation, independent state and copied publications | Pass, 626 assertions |
| `test_actor_prototype_integration` | Real worker reset/refusal receipts, F5 models/NPCs, focus/rearm, baseline/F6/F7/Tower/Water, overlay geometry and recorder identities | Pass, 157 assertions |
| `test_gameplay_recorder` | Existing recording controls | Pass |
| `test_penv001_player_environment` | Existing PENV contract | Pass |
| `test_pchar001_player_representations` | Existing representation experiment | Pass |
| `test_playval001_selectable_player_fixtures` | Existing selectable player fixtures | Pass |
| `test_rem003_player_granular` | Existing sampled-player granular recurrence | Pass |
| `test_tick_failure_regression` | Existing failed-world quarantine | Pass |
| `test_render_patch_handoff_regression` | Existing immutable render handoff | Pass |
| `test_physics_async` | Existing asynchronous owner integration | Pass |
| `test_presentation_controls` | Existing presentation controls | Pass |

The separate **180-frame bootstrap scene run passed in 1.9718 s**, using only the
three tracked portable Godot bootstrap files and no editor import. This verifies
direct headless startup; it is not GPU rendering or visual acceptance. The new
native motor smoke uses `diagnostic_reset({"workers": 1})`, fixed hard floor/wall
geometry and 120 updates per model; material hash/counts and world tick remain
unchanged. Other regressions retain their source-defined fixtures and worker
settings. No new cross-seed or cross-worker performance campaign was run.

## Preserved negative control and review corrections

The buffered-landing jump/dash regression was run against the preserved motor
before the final post-contact speed clamp: SHA-256
`10962f2ac3691b3d48afccedea02a4c3e5f0319fc903dd2a14108615517a6ecf`.
The same final motor test hash above produced exactly **one failed assertion**,
`actor exceeded common speed bound`, and exit 1 in `buffered-dash-negative/`.
The corrected motor passes that unchanged test. The negative command uses the
same Godot executable and test, with the negative-control project path.
Its one-off timeout was not recorded; no timeout is inferred from the later
focused runner's limits. The observed outcome was the expected assertion failure.

Independent reviews also corrected exhausted Skimmer gravity, actor overlay
alignment with the terrain viewport/camera, owner refusal acknowledgement,
brief-key input/rearm handling and recorder generation tick-zero fallback.
The final suites cover the resulting behavior, including distinct material and
current actor sample identities. These are bounded engineering regressions;
they do not establish subjective control feel or neural policy quality.

## Informational timing and limits

At 6,000 mock-occupancy updates per motor, local means were Runner **7.574 µs**,
Skimmer **6.533 µs** and Crawler **7.781 µs**. Across motor fixtures the observed
peak was **13 occupancy queries**, within the explicit 32-query per-update bound.
The full-capacity eight-actor mixed-demo session, including `step()` and copied
`snapshot()`, averaged **89.503 µs** over 1,200 mock steps with peak **39 aggregate
queries**. These timings were collected in one Linux headless process and are
informational. They include no neural inference, native world-tick throughput,
GPU work, target-PC acceptance or production NPC scaling result. Bounded copied
GDScript containers are not an allocation-free claim.

## Documentation and compatibility map

| Changed concern | Canonical/current route and compatibility decision |
|---|---|
| Actor inputs, capabilities and observations | [Actor control prototypes](../systems/actor-control-prototypes.md); provisional shared interface, no inference implementation |
| Worker ownership and publication | [Ownership](../architecture/data-ownership-and-lifetimes.md) and [interfaces](../reference/interfaces-and-message-contracts.md); no mutable World/actor references leave the owner |
| Motor and session limits | [Configuration](../reference/configuration-reference.md#actor-control-prototype-values); fixed model values, PENV remains a separate experiment |
| Scientific fixture identity | Actor contract and [roadmap](../reference/status-and-roadmap.md); registered Tower/Water/MicroScenario representations retained |
| Controls, tests and status | [Build/validation](../operations/local-build-and-validation.md#actor-control-prototype-checks), repository README and handover updated |
| Retrieval and evidence | [Docs index](../README.md), corpus, retrieval index and ACT-01–03 supplemental challenges route the canonical page; frozen 32-question set retained; this audit excluded from default current answers |

Local `python3 tools/ci/check_docs.py`, `python3 tools/ci/check_repository.py`
and `git diff --check` passed. The separate
`python3 tools/ci/check_m11_consistency.py` passed 18 historical records/28 hashes.
`python3 tools/docs/retrieval_eval.py` found canonical targets in the top five for
32/32 frozen and 39/39 supplemental questions; ACT-01–03 contexts were reviewed.
These checks establish documentation, identity and retrieval scope.

## Publication and remaining gates

Direct Git HTTPS push authentication was unavailable in this workspace. The
existing GitHub connector published the identical implementation tree recorded
above. [PR #165](https://github.com/techrote/cybersand/pull/165) owns the final CI and merge disposition.
Ready-transition runs [GDExtension 39106193039](https://github.com/techrote/cybersand/actions/runs/39106193039)
and [Native 39106193095](https://github.com/techrote/cybersand/actions/runs/39106193095)
classified scope but skipped expensive jobs; they are **not full gate passes**.
Ordinary synchronization must establish final Documentation/provenance, Native
and GDExtension/Godot outcomes; those remain pending at initial publication.
Water apparatus path scope is not triggered/applicable to this GDScript/docs diff.
Windows hands-on play, browser/Web integration, owner control-feel acceptance and
trained-policy evaluation remain unclaimed.
