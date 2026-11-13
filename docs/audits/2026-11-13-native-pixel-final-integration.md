---
title: Final native-pixel camera integration, performance and Windows evaluation
status: Current
document-kind: evidence
scope: Accepted #565 reconciliation, controlled application performance, resulting-source platform qualification and Windows delivery for Draft #566
canonical-for: []
last-reviewed: 2026-11-13
related-documents: [2026-11-13-native-pixel-scrolling.md, 2026-11-12-mat-auth-workbench-integration.md, ../operations/native-pixel-scrolling.md, ../systems/material-appearance-and-rendering.md]
---

# Final native-pixel camera integration

**Draft / HOLD; no merge, Ready promotion or auto-merge is authorized.** The
owner requests final integration with accepted #565, preservation of the
qualified camera, controlled performance investigation and a fully tested
Windows evaluation. The [PR #566 delivery ledger](https://github.com/techrote/cybersand/pull/566)
holds the final source-bound workflow links, downloadable package and separate
technical/owner disposition. This record preserves the integration and measured
engineering evidence; pending execution is not a pass.

## Source and preserved ancestry

| Identity | Exact source |
| --- | --- |
| Accepted main / #565 merge | `ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742` |
| Qualified camera parent | `b52dd6c9fac5739bde9829b72b55f09ef89455d6` |
| Normal integration, ordered parents camera then main | `b1e2e9b1ce0a93d9eda54cbc35d04257eba9dfa7` |
| Integrated, unoptimised source tree | `5ef0f8a14c29481519e7455d646f3011a30d6b1b` |
| Preserved camera shader transition | `1755b2195e4d38c6030ae287ac2eb8e070da62ef` |
| Preserved native capability transition | `b432d52d0d9acaa22f93eeb8d1fad48c64b4c087` |

The source merge has five documentation conflicts: the documentation index,
handover, retrieval corpus, retrieval question index and roadmap. Both sides'
new sections/routes are retained, with the newest review date. Product code
merges without a conflict. No competing design or default is selected.

Independent byte comparison confirms that every path changed by only one
parent retains that parent's exact bytes. `main.gd`, `gameplay_recorder.gd`,
`pixel_camera_transform.gd` and `material_palette.gdshader` exactly match the
qualified camera parent. The shader's LF SHA-256 remains
`b8e5542dae2c36fd6fbef0170a7b537bce5c853fc10920174cefe13dbec78d4f`.
The Materials Lab native-window functions match accepted main; the combined
Workbench retains the camera callbacks plus the accepted Lab toolbar entry.
The compatibility registry retains all 30 accepted-main transitions and the
camera transition, without refreshing the frozen material authority lock.

All files under `native/`, `godot/native_extension/` and `third_party/` match
accepted main. No physics, material-law, native owner, worker architecture,
publication cadence or save-format change is part of the reconciliation.
Original component branches, training #567/#568 and unrelated work remain
outside this task.

## Runtime custody and local preflight

Both retained native manifests are byte-identical to main, and all 89 native
`source_inputs` match. `check_repository.py::verify_runtime` validates those
inputs and the binary/pointer SHA and size. Historical `build_inputs` retain
their original qualification scope and do not establish acceptance of changed
scripts. The canonical build guide permits matching-native retained reuse for
script changes. Fresh Linux/Windows source builds and execution are nevertheless
required for this final campaign.

| Accepted retained binary | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows x86_64 | 5,121,536 | `83b656c2638fe31c9a8ab3700c4f8c353db56e996d37a276ddfa205e81c87c54` |
| Linux x86_64 | 4,576,208 | `44c906356a98c84b09c01f6e83bcae2391a4c0e39c5c632431a4a3f4cc1578e9` |

Local preflight uses the authenticated Godot archive (75,664,355 bytes,
SHA-256 `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`),
runtime `4.7.stable.official.5b4e0cb0f`, and the accepted native/Rapier bytes.
Godot import passes. Current documentation and retained-runtime identity checks
pass after restoring their five exact companion inputs from pinned
`6a58311982941b75f46e22109a0829e5acb83c7e`. The initial missing-companion
diagnostic is an environment prerequisite, not a relaxed source check.

The existing recorder's separate CLI mode passes eight assertions for explicit
ROI precedence, extent clipping and cadence/queue clamps:

```text
Godot_v4.7-stable_linux.x86_64 --headless --path godot --script res://tests/test_gameplay_recorder.gd -- --recording-roi-override-test --record-roi=1000,700,100,120 --record-hz=120 --record-queue=0
```

The camera fixture gains two narrow cases absent from its original scope:
fractional Line/right-button erase with exact surrounding 9×9 native readback,
and twelve distinct real Rapier steps under ordinary Workbench Play/Pause.
A late observer verifies the actual parent/child callback outputs rather than
manually supplying an actor pose. Local execution passes 1,457 assertions in
6.542 seconds with zero failures; the real actor moves from y260.5 to
y262.350677. Each sampled terrain uniform and all three overlays share the
presented origin. The executed fixture SHA-256 is
`f6361d773785b4dd9cc8ac9bec1b73a5446427f214b7352234ee06b094b4b41d`.
This evidence is the integration plus the explicitly identified local test
delta; it is not hosted Windows or graphical qualification.

## Controlled performance questions

Subject A is accepted main `ac0d9fb9`; subject B is the unoptimised integration
`b1e2e9b1`. Compare each exact source with its own native build, identical
Godot/Rapier/settings/seed, an identical externally staged harness and fresh
userdata. Use paired ABBA order, warmups, raw frame samples and per-arm source
identities. Keep Windows and Linux/software results separate.

The historical installed llvmpipe result was 31 legacy and 30 native frames:
median 98.406/101.716 ms and p95 104.210/113.171 ms (+8.60%). Its fixture used
a frozen 512×256 material texture, a 128×96-cell view at 1280×960 output,
twelve warmup frames and at most sixty frames/three seconds per arm, always
legacy first. It isolates the coordinate shader block, not accepted-main
application throughput. A longer interleaved shader comparison must remain
separate from the exact-source application comparison.

Representative application cases cover 512²/1024²/2048², paused and active
Sand/Water, sparse/dense/mixed occupancy, stationary/pan/zoom/follow cameras,
integer/fractional zoom, two viewport sizes, effects on/off, manual/native
authoring and one/four native workers. Existing Main/worker counters identify
CPU submission, snapshot publication, dirty bytes, full-image uploads and
actual worker participation. Process memory and action latency retain their
own units; no software-renderer timing is labelled physical GPU utilization.

Only a measured, low-risk improvement can be admitted. Up to three are allowed;
zero is a valid outcome. The camera architecture and physical sample order are
preserved. Raw samples, per-repeat medians/tails, source identities and measured
comparisons are retained in each platform's `native-pixel-performance` artifact.
The PR delivery ledger records their final interpretation and a ranked
opportunity register without changing the already executed source identity.

## Windows distribution compatibility

The original #565 archive was independently downloaded and matched its recorded
SHA-256 `29e444ac801c884b066bae8866cf4dff02b5bc4ccafea2aec97bf2ceef10dd0c`.
It has 22,476 entries (21,422 files), conventional Deflate compression, no
Zip64 requirement and no invalid Windows names/case collisions. Some member
paths are 263 characters long before an extraction root is added, chiefly
qualification shader caches. This is a concrete Windows path-length risk;
it does not establish the cause of the owner's Explorer opening failure.

The new package preserves the complete Lab/Workbench authoring prerequisites
and source custody. Qualification evidence is kept under a short archive path,
with original bytes/hashes retained. Built-in .NET extraction and actual
Shell.Application ZIP-handler access are separate required checks; neither is
claimed until executed. The delivered application must be tested from its
actual extracted package. Physical owner DPI, graphics hardware and perceived
frame pacing remain owner acceptance, even after hosted qualification passes.
