---
title: ObjectShard 001R playability and stability qualification
status: Historical
document-kind: audit
scope: Exact experimental finisher source, preserved negative controls, platform and delivered-package evidence; no owner physical acceptance or production merge
last-reviewed: 2026-11-22
related-documents: [../research/objectshard-001.md, ../operations/objectshard-lab-playtest.md, 2026-11-22-objectshard-001r-forensics.md, 2026-11-22-objectshard-001r-native-performance.md]
---

# OBJECTSHARD-001R — playability and stability finisher

This record separates material correctness, physical stability, measured cost,
Windows package custody and owner physical acceptance. PR #738 remains Draft/HOLD.
No production defaults, sibling branch, selected Rapier solver or historical
ObjectShard source/evidence has been replaced.

## Source identities

| Role | Identity |
| --- | --- |
| Accepted main and merge base | `662df51cd8409a52332fa7ef15d06d8ab8945aed` |
| Unchanged M2 parent | `dc4282e5f5f9b886315e8450613740d265f5fbc3` |
| Original qualified M2 runtime control | `8f55a4e61b7cbb34a594f5e07e7d81d49aa58945` |
| Qualified native/host code | `514d76fbf4df30eb05353bc14b6a4ec3ea9bf61c`, tree `e2b0753b82650734b5738ff000be62a2c7db2abe` |
| Delivered Windows packaging source | `28be5a4a8a023d466e642afaca767c0224de1ba3`, tree `d734a7acd6429fe1182d856a78f49efd36d99758` |

The packaging descendants change the verifier, ZIP qualifier, negative tests and
the ObjectShard workflow's explicit Windows-only request marker. Commit f480
removes the shipped verifier's dependency on PowerShell module autoload; 28be
makes its console JSON safe under Windows CP1252 after Unicode-path testing.
All 116 native input hashes and 26 Lab input hashes match qualified 514d. Windows
was rebuilt and executed at 28be; Linux/native qualification names 514d. The
skipped Linux job on the packaging-only request is not a pass. The
[platform custody manifest](objectshard-001r-20261122/platform-qualification/custody.json)
binds these inputs, exact ZIP bytes, receipts and all 15 retained PNGs.
Documentation/evidence descendants do not change the executed code.

## Demonstrated defects and repairs

The original admission control chose components `[1,4,9]` while leaving an
eligible 400-cell detached component in World. It revisited 51,200 cells during
128 unchanged full-slot calls, and a 32-work search restarted indefinitely. The
repair performs a bounded, resumable complete census before scarce-slot selection,
chooses large components with bounded age fairness, caches refusal reasons and
reconsiders transient obstructions. The same fixtures admit `[400,9,4]` with zero
repeated full-slot traversal. The actual Lab offcut scene admits its 777-cell main
structure first. The original owner B export lacks the remaining World raster,
so these are demonstrated mechanisms, not an invented exact B replay.

The retained D actions reproduce the original tick-970 protective hold and final
poses. A controlled old-bridge run exhibits a 45.2933-degree excursion after tick
754. Required shape/mass replacement wakes Rapier, but the old adapter overwrote
that wake with its previous sleeping state. Necessary replacement now allows
contact recovery, and identical geometry retains collider handles. Real support
removal and later off-centre impacts still cause motion; bodies are not frozen.

On exact 28be Windows, all 3,599 recorded D frames through tick 3,600 were checked.
Maximum excursions from tick 754 were 0.0003825, 0.0043577 and 0.0009904 degrees;
maximum translation was 0.0016271 cells. All three bodies ended naturally asleep
after subsequent geometry changes. These retained 198 actions are not a complete
reconstruction of the original owner's input session.

Actual bounded Rapier segmentation preserves four-cell translation, 0.20-radian
rotation and swept-corner limits. At most 16 real segments complete one semantic
interval; every segment requires an applied native identity-bound receipt before
another step. Protective refusals retain ownership and remain visible. Source-owned
moving erasure preflights exact replacement geometry before debit. Ordinary World
edits never become a second owner of moving material.

The visible sustained burner authors genuine World Fire. The accepted Wood law
is unchanged. External ignition uses the existing sampled opportunity and a
bounded carrier claim that survives relocation, preventing duplicate ignition
across shards or the subsequent World tick. Intermediate duplicate-Fire and
Sand-fence rollback failures were reproduced, repaired and retained. Sand lodging
remains a bounded pocket; visible bypass is not hidden or relabelled as capture.

## Native and physical evidence

Final native performance matrix: **4,237,399 assertions, zero failures, 74/74
unchanged limits passed**. Focused ASan/UBSan: **34,895 checks, zero failures**.
The independent four-neighbour oracle exercised 40 grids with 6,000 ordinary
mutations each and 1–31-node discovery budgets: **2,237,430 checks, zero failures**,
also repeated under ASan/UBSan. LeakSanitizer was unavailable under the local
ptrace restriction; no leak-check pass is claimed.

The exact 28be Windows Lab executed 19 cases successfully, including original
379-check M2 integration, bridge, contact, bounded motion, owner-aware editing,
capture, retained D and three 3,600-step rest interventions. It retained 15 actual
material/render PNGs. The prospective 262-action, 50-step replay reported zero
operation/refusal/step differences. It does not compare every inventory checkpoint
or promise cross-platform pose bit identity.

The [514d Linux campaign](https://github.com/techrote/cybersand/actions/runs/44985942694)
passed **93,529 ASan/UBSan checks**, all **192 existing World test cases**, the
Linux ABI floor, all **19 actual Godot/Rapier cases**, and both **719-check**
headless/rendered profile runs. No leak-check pass is claimed. Native receipt:
`64e67fc021a202f245fb5bdd49a21eb5394ea557147b68cf21053aa3432040dd` (Linux SO).
The [source-bound native summary](objectshard-001r-20261122/platform-qualification/linux-514d/native/summary.json)
retains individual suite counts, commands, input digest and failure accounting.

The [final Windows campaign](https://github.com/techrote/cybersand/actions/runs/44987818314)
passed all **19 actual Lab cases**, both **719-check** profile runs, and all
**15 applicable integration cases repeated from the delivered ZIP**. Four fresh
ZIP extractions passed both shipped verification and actual GUI boot: spaces,
a folder ending `(1)`, a 124-character nested path and Unicode. This is not a
claim to cover every Windows long-path policy. A shadowed `Get-FileHash` still
passed; changing `READ-ME.md` produced its specific hash refusal, followed by
exact restoration and successful full verification.

Download the [qualified owner package](https://github.com/techrote/cybersand/actions/runs/44987818314/artifacts/14740363854).
The Actions artifact contains `objectshard-windows-evaluator.zip`, **93,056,059 bytes**:

```text
SHA-256 c6a4d79e95295e91228d161591554136dec6d73438f184ab1e48ebfc507e83d4
```

Its native DLL is `bcf74222e97f4714f1c2ce4fbb083f577e5a5e1fac2b80ed662e9ec8a13489a2`.
Root independently checked all **1,073 manifest files directly from the final
ZIP bytes**. The [Windows evidence artifact](https://github.com/techrote/cybersand/actions/runs/44987818314/artifacts/14740069324)
retains raw process logs, source identities, complete profiles, frame traces,
renders, launch receipts and extracted-package replay. Selected small receipts,
all PNGs and the package manifest are also retained in this repository. Four
Windows text receipts have LF Git presentation copies plus lossless raw companions;
the custody manifest distinguishes their original and normalized hashes.

The pinned engine is Godot **4.7.stable.official.5b4e0cb0f**; Windows console SHA
`d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`.
The selected Windows Rapier SHA is
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
No Rapier solver or dependency selection changed.

## Performance and resource interpretation

The original M2 **10/74 timing-limit failures remain historical failures**. A new
same-host control passing does not erase them. The first integrated finisher also
failed **14/74 memory limits**, with 6,670,496 requested C++ bytes. This negative
result is retained. Compacting private ingress fences from 32 to 16 bytes saved
393,216 bytes without reducing either history capacity or public identity checks.
The final peak is 6,277,280 bytes, just 14,176 below the default-canvas 6 MiB limit.
Larger optional canvases have separately reported storage and are not covered by
that default-canvas bound.

Three alternating baseline/candidate pairs show no general frame-rate improvement:
three-reacting p50 increased 3.28%, wake-burst p50 4.43%, and one-body p95 35.24%.
The final standalone native p95 was 368.092 microseconds empty, 554.523 one reacting,
and 929.858 three reacting; the maximum observed frame was 21.145 milliseconds.
All measured steady-state C++ allocation counts were zero. This is not a claim
about Godot, Rapier, GPU or total process allocations.

An independent frozen-binary probe challenged later dormant/wake timing increases.
Both pre-timer and final binaries reproduced the slower 600–660-microsecond range;
no unique causal attribution or final-delta regression was established. Inclusive
stage timers must not be summed as disjoint costs. Synthetic immediate geometry
ACKs do not measure real main-thread installation latency.

On the final 28be hosted Windows runner, rendered three-reacting processing p95
was 11.471 ms and presentation-interval p95 27.786 ms; headless processing p95
was 5.041 ms. All registered hosted headless
and rendered limits passed. These figures do not establish NVIDIA GPU performance,
owner-PC frame rates or physical acceptance. Full per-stage and tail measurements
are retained in the linked source-bound evidence.

## Review and retained negative experiments

Fresh independent source review found and repaired omitted history-only contact
timing, then approved the exact 514d source conditionally on platform/package
qualification. A separate independent performance review recomputed 660 native
and 454 earlier Windows custody/statistical checks with zero discrepancies and
independently passed 36 packaging tests. Both withheld Windows-delivery approval
until the actual corrected ZIP was executed.

Retained negative results include original admission starvation/restarts, original
late Rapier movement, duplicate relocated Fire opportunities, failed Sand-fence
rollback, f11 memory failures, c065 Git text-normalization custody refusal and the
f11/514d Windows PowerShell verifier failure. f480 then passed all four path
cases but failed while printing Unicode success output to a CP1252 console;
that negative run is retained separately from the successful 28be delivery. The shipped verifier now uses strict
streaming .NET SHA-256; its qualifier checks missing-cmdlet independence and a
specific changed-file refusal, restores the extraction exactly and re-verifies.
No manifests or shipped files are patched after qualification to manufacture green.

The fresh [independent source review](objectshard-001r-20261122/independent-source/2026-11-22-independent-source-review.txt)
and separate [performance review](objectshard-001r-20261122/independent-performance/independent-performance-review.txt)
retain their executed-source limits. The final
[platform/package addendum](objectshard-001r-20261122/independent-source/2026-11-22-final-platform-package-review.txt)
independently approves the exact delivered evaluator as **Draft/HOLD**, with no
unresolved Class A/B custody finding. It verifies all 1,073 file hashes, 116
native inputs, 26 Lab and 18 qualification inputs, DLL/source binding, every
hosted case log hash, 19 Windows cases, 15 delivered-package cases and all four
launcher paths. Its machine receipt SHA-256 is
`d9977866912fe216279b1659b5f4eb8e706bb6ffb83ada500eadea1b5e32cad8`.
This is not merge, release, production, NVIDIA or owner-physical approval.

## Owner playtest and integration boundaries

Eleven reference scenes include large-plus-offcuts, awkward branching, diagonal
multi-support cuts, sustained genuine Fire, long resting/erosion and a 320×192
three-structure canvas. The owner can pause, step, reset, make ordinary or moving
cuts, inspect exact inventory, view geometry/COM, identify admission reasons and
export a source-labelled incident JSON plus bounded JSONL trace.

Remaining explicit limits are three active owners, bounded component/bounding-box
and shape capacity, no preemption of existing owners, nonfracturing welded islands,
bounded Sand lodging, selected contact/chemistry only and no durable save/streaming.
Motion beyond the admitted segment envelope can still require explicit reset.
Ordinary production Workbench, Water selection, controls and publication defaults
are unchanged. Physical Windows 11/NVIDIA acceptance remains the owner's decision.

Recommended eventual order is M0 #726 → M1 #728 → M2 #730 → finisher #738 → the
separate M3 preflight. All remain Draft/HOLD. Current main is an ancestor; refresh
it again before an owner-authorized mergedown. Reconcile narrow World hooks and
the native registration/build inputs with accepted PUBPRES/GEN-006 successors,
then perform strict production runtime publication and required gates. The normal
documentation/provenance guard remains red while repository-retained production
binaries do not match these experimental native inputs; it was not weakened.

M3 preflight publishes its own code/review/platform identities in the next stacked PR. Its executable
fallback is a standalone worker/main ownership rehearsal with real World and
Rapier, plus tested Workbench contracts and explicit absent integration seams.
It is not a second material engine, an attached Workbench World or a completed
production integration.

## Evidence map and visual review

- [Forensic ledger](2026-11-22-objectshard-001r-forensics.md): observed owner exports,
  demonstrated mechanisms, missing evidence and controlled experiments.
- [Implementation record](2026-11-22-objectshard-001r-repairs.md) and
  [native admission](2026-11-22-objectshard-001r-native-admission.md): bounded
  eligibility, admission, exact ownership and adversarial repairs.
- [Full native performance record](2026-11-22-objectshard-001r-native-performance.md):
  every unchanged limit, complete matched cohorts and preserved failures.
- [Final platform custody](objectshard-001r-20261122/platform-qualification/custody.json),
  [Windows Lab](objectshard-001r-20261122/platform-qualification/windows-28be/windows-lab/qualification.json),
  [delivered replay](objectshard-001r-20261122/platform-qualification/windows-28be/package-replay/qualification.json),
  [launcher matrix](objectshard-001r-20261122/platform-qualification/windows-28be/launcher-matrix/result.json),
  [D trajectory analysis](objectshard-001r-20261122/platform-qualification/windows-28be/retained-d-analysis.json),
  [complete per-stage profile summaries](objectshard-001r-20261122/platform-qualification/windows-28be/profiles-summary.json).

Visual inspection confirmed readable ownership/capacity labels, an admitted main
structure with explicitly deferred offcuts, exact occupied shapes and COM, visible
carried Sand, and genuine Fire/Smoke around the sustained fixture. The screenshots
are actual material output, not physical acceptance evidence by themselves. The
resting-body claim comes from full pose traces and interventions. All 15 final
Windows PNGs match the separately retained 514d renders byte for byte. A compact
source-labelled gallery is posted directly in the [PR conversation](https://github.com/techrote/cybersand/pull/738#issuecomment-7074186648).

Documentation validation passed with 147 canonical documents, 4,163 local links
and no warnings; historical M11 retained 18 records and 28 source hashes.
[ObjectShard retrieval](objectshard-001r-20261122/platform-qualification/documentation-retrieval.json)
found all six canonical routes within top-k (four at rank one). The
[unpublished production guard](objectshard-001r-20261122/platform-qualification/production-repository-guard-unpublished.json)
truthfully reports six source/binary mismatches across the old production Linux
and Windows manifests. It is a remaining mergedown/publication requirement, not
a failed candidate ZIP identity and not permission to bypass a gate.
