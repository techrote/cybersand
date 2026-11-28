# PUBPRES mainline convergence: local spawn investigation

This is dated local engineering evidence for PUBPRES-MAINLINE-CONVERGENCE-001.
It does not establish integrated Windows, graphical, NVIDIA or physical owner
acceptance. The frozen pre-repair and repaired measurements below are retained
without rewriting earlier failed observations.

## Finding and selected repair

The ordinary Place/Reset route retains native cells through the existing
prepared-World transaction and constructs a provisional physical owner. It
repeatedly validates a transport profile on Main and on the exclusive simulation
owner. `CyberTransportProfiles.resolve` previously expanded the same unchanged
81 by 81 pair table on every validation, producing 39,529 integers. Repeated
baseline-profile calls cost 65–67 ms locally; tuned profiles cost 107–115 ms.

The bounded repair in `e8ab8a6000` retains one compiled table for an exact valid
profile. It preserves every existing public schema/range/pair-policy check and
the complete original compiler for changed inputs. It freezes a deep copy of
the retained profile, copies returned packed/profile values, and serializes only
the bounded cache lookup/publication through a mutex. Compilation remains
outside that lock. It retains no native World, body, scene, publication, material
history or input ownership. The existing Native, Rapier and presentation
authorities and admission fences are unchanged.

Direct warmed calls then measured 12–73 µs with the same complete packet hashes.
A cold first compilation still occurs; the optimization does not conceal or
defer it. Main's synchronous retained spawn/reset request fell from 80–87 ms to
5.6–15.9 ms in the matched complete application observations. Total observed
admission fell from 630–678 ms to 211–249 ms. The remaining transaction interval is
real and remains visible.

This supports repeated profile compilation as a material contributor to the
locally reproduced spawn interruption. It does not prove the precise cause of
the owner's earlier TITAN RTX observation. Fire-on and Fire-off cases had
similar request/admission behavior before repair; fresh emitted pixels are not
established as that observation's cause.

## Sources, execution and raw custody

The pre-repair application is #767 source
`957b4696b9f7987df18b4bf437e56ca3f391b956` plus the explicit tracked diagnostic
patch saved by the runner. That instrumentation/witness was subsequently
committed at `cf6ec2e255`. The repaired run uses `1ea8c4d2fa` plus the explicit
transport-only tracked patch later committed at `e8ab8a6000`. Each arm records
its actual Main and observer hashes. The first runner's recording-off arm
closed its writer immediately after Main readiness; the repaired runner's
recording-off arm suppresses writer creation from startup. The comparison's
runtime requests occur after that startup interval. The final qualification
runner independently disables recording from startup on both current and
frozen reference sources.

Both local application arms use these unchanged binaries:

| Component | Identity |
|---|---|
| Engine | Godot 4.7 stable official 5b4e0cb0f, Linux, headless |
| Engine SHA-256 | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Native SHA-256 | `56ecc606e0f8111816ec96e4022789aeb280feef52e73292f5e9d2b9026da6b1` |
| Rapier SHA-256 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Selected architecture | Stock Safe, Full two slots, coherent Water composition, all-worker completion, flight pacing/coupling clock/empty effects enabled |
| Workload | Existing owner Wave512 fixture, unchanged material recipe; six Place/Reset/Restore operations with a real 100 ms W pulse and real Thruster control |

The original raw archive, bound by the [external-artifact custody record](../../tools/pubpres_mainline/local_evidence.json),
contains 49 files and 11,828,570 uncompressed bytes, including complete profile
files, original recorder segments, startup/case receipts, reductions, stdout,
source-delta patches, direct compiler observations and the adverse prototype.
Its compressed size is 1,261,587 bytes and SHA-256 is
`3b98692ecd8e95ea83d6e1df2c2102776a74d0a8adeeccd80f41ae24bcdec951`.
The [raw manifest](2026-11-28-pubpres-mainline/spawn-local/raw-manifest.json)
binds every inner file. The [comparison](2026-11-28-pubpres-mainline/spawn-local/comparison.json)
retains all twelve matched recording-on/off case rows.

## Matched application observations

All six cases passed real request admission, real keyboard acceptance and
application, and actual completed Rapier progression in both recording modes
before and after the repair. Recording-on reported no loss. These are local
headless CPU/application observations; graphical callback fields are absent.

| Recording-on case | Request before/after, ms | Observed admission before/after, ms | First actual physical completion before/after, ms |
|---|---:|---:|---:|
| First additional actor, air, Fire off |84.17 /5.63|662.35 /239.94|666.06 /239.56|
| Warm reset, Fire off |80.46 /6.83|677.67 /222.92|677.30 /222.51|
| Warm reset, Fire on |86.36 /8.82|633.47 /234.54|633.04 /234.14|
| Placement near material, Fire on |81.90 /8.36|673.78 /210.63|678.86 /215.21|
| Restore authored start |101.10 /27.37|686.23 /223.61|694.91 /238.41|
| Placement after restore |83.28 /10.06|648.17 /215.47|647.73 /220.11|

Admission is observed on a process callback; an actual completed-step timestamp
can therefore precede that observed admission by a fraction of a millisecond.
Those clocks are not interchangeable. Native semantic ticks are not counted as
physical steps.

For the five retained Place/Reset cases, median request time was 83.279 ms before
and 8.355 ms after with recording on; median observed admission was 662.351 ms and
222.922 ms. Recording-off medians were 83.178 ms to 9.711 ms for requests and 640.445 ms
to 231.659 ms for admission. The recording-on worst physical completion gap across
these case windows changed from 695.529 ms to 246.949 ms. These small local cohorts
do not establish a universal tail bound or the physical Windows threshold.

Pre-repair phase rows located authored validation/retained sampling around 1–2 ms
and complete physical graph preparation around 5–9 ms. Most synchronous request
time occurred after Workbench request assembly and before provisional physical
preparation. Native/physical staging intervals included repeated profile
compilation on the worker. Nested phase durations overlap and must not be added;
terrain handoff/adoption durations include scheduling and other preparation,
and are not measurements of GPU execution or isolated native CPU time.

## Independent review and regression scope

Root and Specialist B independently reviewed the cache's exact key, mutable
value isolation, one-entry bound and cross-thread publication. Specialist C
reviewed the separate bounded instrumentation and source/runtime admission.

The local new test passed 18 checks covering all three pre-repair golden packet
hashes, caller input/output mutation, changed metadata, schema/range/carrying
refusal and two concurrent compiler callers. The existing native transport test
passed its preset, round-trip, inheritance, pair, limit and invalid-preservation
checks. The existing recorder test passed its actual rotation/loss tests plus
the new phase schema. The final Python reduction tests also reject loss,
missing actual completion, missing draw evidence and an unclosed recorder.

The strict final runner stages committed source, verifies original native and
dependency receipts through the shared mission custody helper, enforces the
committed Rapier pointer and engine pin, and hashes its explicit observers.
Its actual-process CPU/memory sampler and process lifetime gates are retained
from existing qualification infrastructure. The resulting integrated source
still requires hosted graphical and extracted Windows qualification.

## Preserved adverse observations and remaining work

The first prototype held W for three seconds. It drove an actor to the finite
canvas boundary, correctly paused/refused the native owner, and caused two
later retained placements to fail provisional owner validation. That arm remains
failed; it was not reclassified. Its complete script delta was not captured by
that earliest prototype, so it is retained as adverse diagnostic evidence only.
The registered witness uses a 100 ms input pulse followed by neutral braking and
fails any unexpected pause/refusal. The unchanged material fixture and physical
allowances remain explicit.

An earlier process was killed before startup under local memory pressure; its
short original log is also retained. No result is inferred from it.

No texture-upload, shader, driver or physical monitor latency was measured by
these headless observations. Mixed2048, Windows ANGLE and physical owner
comparison remain separate gates. Approximately 0.21–0.25 s of local observed
admission remains after compilation reuse, and no initial cold compile is
removed. The selected native and presentation architecture is unchanged.

## Subsequent source and external raw custody

Generated raw archives are kept in a separately verified GitHub Actions artifact,
not committed into the repository. The source-owned publisher admits the exact
Git blob and SHA-256 above, checks its bounded archive members and uploads the
original bytes. Its final Actions artifact link is recorded in the mission
ledger. No generated archive or evidence-only source commit is an application
qualification claim.

The later Object-key lifetime refinement at integrated source
`7f9bc26c1c5e51de9497868f4604ea07458c870c` preserves the measured scalar-input
path and adds two controls, bringing the final focused test to 20 checks. It
bypasses retention of unusual script-created Object keys while retaining their
original compiler acceptance. The earlier timing and 18-check results above
remain tied to their original source bytes. Final-source hosted Windows,
recording-on/off and extracted evaluator results remain separate.
