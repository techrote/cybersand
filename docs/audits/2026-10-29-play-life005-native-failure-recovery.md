---
title: PLAY-LIFE-005 actual Main native failure and ordinary recovery
status: Current
document-kind: evidence
scope: Accepted Windows/Linux bounded real native capacity failure, Main/reference-Rapier quarantine and ordinary reset; broader course/native-busy/release qualification remains open
canonical-for: []
last-reviewed: 2026-10-29
related-documents: [../systems/player-control-playground.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/simulation-tick-and-threading.md, ../architecture/liquid-prepared-setup-and-receipts.md, 2026-10-29-play-life004-populated-retirement.md]
---

# PLAY-LIFE-005 actual Main failure and recovery — 2026-10-29

## Accepted source and exact-head hosted qualification

[PR #293](https://github.com/techrote/cybersand/pull/293) accepted source
`385e030776ca15302f4fe5c97908e1c281b010ae` through guarded non-forced merge
`4b6ca055c1f9a46f3dc88fdf7aa2a97252550a48`, parents5374a343+385e0307.
Remote main and accepted tree `81bd8f5e1e083d4211a6aa9fe53d06979b015ccb`
were verified identical to reviewed head385 and actual CI checkout
`fca4eee826b516d30acd30d27ec0c9abfa5601f9`. That checkout retains original
parentsd3ad+385; source-tree-equivalent accepted parent5374 was verified before
the metadata-only main retarget. No source/ancestry premise is relabeled.

All exact-head attempt1
[Docs40803888498](https://github.com/techrote/cybersand/actions/runs/40803888498),
[Native40803888519](https://github.com/techrote/cybersand/actions/runs/40803888519),
[Windows/Linux Godot40803888527](https://github.com/techrote/cybersand/actions/runs/40803888527),
[source/local review](https://github.com/techrote/cybersand/pull/293#pullrequestreview-5691970531)
and [final independent execution review](https://github.com/techrote/cybersand/pull/293#pullrequestreview-5692331108)
passed before merge, with zero unresolved review threads/requested changes.

Windows185 applicable cases plus import/186 log hashes and Linux197 unique
cases plus four imports/201 logs pass, including12 Linux display cases. The12
declared graphical exclusions in Windows are not counted as successful runs.
LIFE005 passes **30 assertions / zero failures per OS**: healthy execution,
actual capacity fault/count1, retained copied data/image, eighteen Main/eight
physics callbacks with Rapier frozen after the observed failure fence, ordinary
reset to a healthy newer World, same three reference nodes/epoch0, joined exit
and complete1,048,576-byte stored image with Sand0. Status serials differ by OS;
the oracle requires monotonic ordering, not fixed absolute clocks.

Inherited LIFE004335/LIFE003150/LIFE002335/LIFE00150 actual lifetimes and1,165
assertions, plus81/15/126/32 controls, also pass. Native164 tests in three
variants/all21 steps/154 CLI invocations/308 stream hashes pass. All eight ZIP
digests and80 native/738 Windows inputs were verified, with original bounds
and no diagnostic error, skip, timeout or retry. ASan leak detection is disabled;
these covered cases do not establish general leak/race freedom or absence of
other Native defects, including separately registered issue292.

Final combined ledger SHA-256
`041530bb0f366ba161d23cd41b8606baf348be1245e0f6204f0b332fdf20ddf6`;
all1,313 CI-readback files are hash-verified in
`C:/Users/_/.codex/artifacts/play-life005-ci-2026-10-29`.
Historical working-overlay/candidate statements below retain their original
source scope. This later documentation-only receipt does not rerun runtime
tests or promote #270. Five-SetP recovery, prepared-liquid recovery, native-busy
shutdown and the other stated release gates remain unqualified.

## Clean committed-source Windows proof

Exact clean source **`79574a243daa45600471c56ecfeb5e58caaca6e3`**, tree
`a2b2a8772be458cc7785eb4399c42ba2b28306be`, passes strict import plus the
actual-host case, **30 assertions / zero failures**. All80 native inputs match
the retained source/payload and all738 scoped tested inputs remain unchanged
after execution. The test's working bytes match its exact Git blob.

```text
python C:/tmp/run_play_life005_exact.py --root C:/Users/_/.codex/worktrees/play-integration-20261028/khybersand --source 79574a243daa45600471c56ecfeb5e58caaca6e3 --output C:/Users/_/.codex/tmp/play-life005-20261029/exact-79574a24
```

The raw result reports healthy completed native tick3, failure attempt4/count1
with the exact capacity reason, unchanged World generation2 and newer status
serial16→17. Eighteen actual Main and eight physics callbacks complete while
Rapier stays at observed step3. Ordinary reset produces generation3, failure
count0, native tick3 and Rapier step7; the same reference nodes/epoch0 remain.
Final Main exit joins the owner and retires all three bodies. Only afterward,
the complete1,048,576-byte stored-material image contains **zero Sand cells**.
No inference depends on material queries masked by the live body graph or on
Sand remaining inside the64x64 interest region.

This clean cohort is separate from the27/29-assertion working-overlay probes
below. No diagnostic error, skip, timeout or retry occurred. The external
collector records its own hash, pinned runtime identities, all source inputs,
raw logs, exact bounds and result checks. Later documentation-only appends do
not change the executed test; final hosted Windows/Linux/Native/Docs and
distinct review remain their own gates.

Import takes4.388s under240s; the case2.598s under180s; predicate bounds stay
15,000ms. These are process durations, not frame-rate or gameplay latency
measurements. Test source SHA-256
`4b606239d28478082e43939023316ba5ab264728b36362cb6c5588d0ea9cfe4d`.

| Clean-source evidence | SHA-256 |
|---|---|
| `identity.json` | `010799b66fdc14b6af7a7f1e16fb5d3e5e64eaa35a6a0715e6cbc858f877bc57` |
| `timings.json` | `8f6fa849242227d6b1d7a77e6b2219c01ec0fb75ff1e69790698809e72e9e083` |
| `results.json` | `06efffffe95ea3f6c9cb6a0d910246b377ffc0d0e0c0f9df3b5bbea044f9c454` |

## Source and dependency boundary

The isolated branch `codex/play-life005-failure-recovery`, source root
`C:/Users/_/.codex/worktrees/play-integration-20261028/khybersand`, starts at
`d3ad406dea57b51ad3d05b7487fdfd5dec65bde9`, the unchanged candidate head of
[PR #291](https://github.com/techrote/cybersand/pull/291). Runtime production
source is accepted main91778603; #291 adds tests/documentation only. This child
must not merge ahead of the parent's final exact-head CI, distinct review and
accepted-tree gate. Parent Windows/Linux Godot40797616577 pass independently;
Native40797616487 and final acceptance remain tracked on that PR. No result is
transferred from that parent to the new child.

Only a new automatically discovered test and focused documentation are added.
No production/native/solver/default/runtime/dependency/CI change is selected.
The current test is
`godot/tests/test_play_life005_failure_recovery.gd`. It extends the accepted
actual Main apparatus, preserving main-thread Rapier and exclusive asynchronous
native ownership. It uses the real three-reference-body route, not SetP course
actors, a fake native return or a second scheduler.

## Actual fault, publication and recovery oracles

The existing test setting `cybersand/native_active_core_capacity=1` is supplied
only while Main and its harness construct; the original setting is restored
before entering the tree. Main starts paused. Public ordinary MicroScenario
admission builds an Empty-on-Empty no-op rectangle with fixed64x64 interest,
disabled sampled player and three actual reference bodies outside that region.
Healthy native and completed Rapier steps must occur before any fault injection.

The public owner queue admits two Sand points at(20,20)/(48,20) while paused.
The owner applies them; Main's actual material image must display both. After
acknowledged render transport settles, the test retains the valid copied packet
and image, then unpauses. The next native attempt must report the real
`active scheduling-core capacity exhausted` exception, attempted tick one above
the completed tick and failure count1. These points touch two activity blocks;
capacity is checked before deduplication, so this is not proof of two distinct
scheduling cores.

The failed wrapper must retain valid cellular/render/terrain/context data and
the prior immutable lease, leave the presented image unchanged, publish a newer
paused failure status and clear partial body feedback. At least eight actual
Main and eight physics callbacks must progress while no further Rapier step or
pose change occurs **after the observed failure fence**. Independent native and
Rapier pacing can admit a physical step before Main sees the failure; the test
does not impose instantaneous cross-owner clock equivalence. Emission refusal,
a latched single failure and an available owner thread survive resume/view
requests.

Ordinary public R/reset rebuilds the same recipe, advances native generation,
clears failure at paused tick0 and permits healthy native/Rapier progress again.
The same three reference nodes/epoch0 are reset and retained; no new SetP actor
incarnation is claimed. The default liquid policy envelope remains unchanged.
Prepared liquid construction still requires a healthy World; this does not
authorize prepared same-policy recovery or live solver replacement.

After Main exit and confirmed owner join, exclusive access transfers to the
test for a full1024x1024 stored-material image. Its Sand count must be zero,
including outside interest and beneath body masks. Live worker World inspection
never occurs on main. This checks the known admitted/refused fixture emissions,
not every possible concurrent enqueue or effect-cancellation race.

## Retained working-overlay probes and review corrections

Both initial cohorts use the unchanged pinned Windows native DLL
`e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb`,
Rapier `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`
and Godot `4.7.stable.official.5b4e0cb0f`. Native build/source remainsd7e35aa3;
no fresh build is asserted. Evidence root:
`C:/Users/_/.codex/tmp/play-life005-20261029`.

- `initial-capacity-one`: original source SHA-256
  `4ac91025b74f3982bb695733144af7dc3a1fda6d5777da5e7f1bb89c2d8152b7`
  passes27/0. Original source bytes were recovered by reversing the narrow later
  patch and matched against the original pre-run identity; this is not a claimed
  pre-run source-file copy. Raw process/log identities remain untouched.
- `render-ack-capacity-one`: source SHA-256
  `84b148dcd57318d8a7b903bfc2d81b9508cb40503446c7f596c90d37ed5367b4`
  passes29/0, strict import3.457s and case2.595s, all exit0/no error, skip, timeout
  or retry. It requires both visible Sand points and acknowledged empty pending
  patch transport before retaining the failure comparison, then checks the image.

The second cohort records healthy native tick3/Rapier step4, failed attempt4
after completed tick3, continued callbacks with Rapier frozen after its observed
fence, ordinary recovery to native generation3 and resumed native/Rapier work.
Its selected-region Sand0 check is historical, not the new whole-image oracle.
Handoff JSON SHA-256
`42fd4ae0fa6e18b64a56c97a09789388127f2bc3d9ed6b2cd785c29847faf5fd`
contains both source/process/log identities.

Independent source review confirmed that transport acknowledgements legitimately
clear patch arrays while paused; they are not semantic World mutation. The
latest source binds acknowledgement to the same emitted World/revision/render
identity and completed tick, retaining the complete payload comparison. Review
also replaces selected-region masked queries after join with the whole stored
material image, avoiding gravity/interest/body-mask blind spots. This corrected
source receives the fresh clean committed-source execution above; the prior27/29
cohorts are not relabeled as that proof.

## Documentation map and remaining gates

The player contract owns the bounded actual-host failure regression; navigation,
roadmap and an additive PLAY retrieval question route to it. Existing failure/
ownership/interface/capacity/ADR contracts remain unchanged. The source uses
automatic strict test discovery, existing public owner queues and ordinary
reset, with180s process/240s import/15,000ms predicate bounds and no retry/skip
masking. Frozen32 retrieval and historical evidence remain unchanged.

Clean final-source local execution, exact-head hosted Windows/Linux, applicable
Native/Docs and distinct source/execution review remain required. This does not
qualify the five SetP course rigs, slow native execution, outstanding phase-job
shutdown, native thread joins, broad race/leak freedom, frame/snapshot performance,
physical devices or human feel. #266/#268/#269/#270 remain open; #265 stays closed
and #271 deferred. No unsupported solver/default route is admitted.
