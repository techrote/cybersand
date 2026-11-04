---
title: Scooper carried-material leakage and entry-side repair
status: Current
document-kind: validation
scope: Source-bound translation/ejection diagnosis and bounded authored-only repair; rotation and open-side carrying remain separate
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/gcr-scooper-leak-registration.md, ../architecture/compound-granular-coupling.md, ../systems/granular-review-flight-fleet.md, 2026-11-04-authored-compound-scooper.md]
---

# Scooper carried-material leak — 4 November 2026

## Owner report, source and registration

The owner reports that selective-arrival Scooper feels very good but carried
powder leaks through/out of the hull above very slow movement. This is positive
handling feedback with a concrete carrying defect, not general gameplay
acceptance. The [registration](../operations/gcr-scooper-leak-registration.md)
separates the known presentation-phase overlap from true far-side escape.

The isolated codex/gcr-scooper-leak-investigation-20261104 branch starts at
draft PR385 source `5e79f2be994b652f9aef658e2075650631581427`. Fresh main is
`7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`, tree
`36ce5a01e754a141c321f41cac7f1c6b6059c371`, unchanged. PR347 remains separately
owned at957ce67d, draft and physically NO-GO; its latest branch is not imported.
Both dirty source checkouts/imports and the owner's running build are preserved.

Registration85f28c02 and machine protocol3502293e precede the new captures.
Apparatus source `fa6de57e56cbd953005418c0835a3d1befb56816` supplies the complete
baseline. The entry-side candidate is separately registered at9b26af95 after
baseline acquisition and before implementation. Native repair source is
`3df1279f799230bafdc7a34766eb2995bf4ae69b`; runtime publicatione625c6f2 and
corrected fixture source `68aef83c16857347fe16efaffd9bffdb65d95c11` retain those
same89 native inputs. No historical hash or registered limit is rewritten.

## Reproduced mechanism

Normal synchronous ownership samples the Rapier hull, advances native material
against that mask, applies one response and then advances Rapier. The earlier
tick180 cavity-count dip reflects grains inside the new drawn deck while above
the sampled deck; it clears at the next preparation. That is not sufficient
evidence of persistent leakage.

New capture observes every actual Sand coordinate before/after each ordinary
owner boundary, classified against both hull poses. Exactly16 grains, no source,
unchanged Scooper mass0.18/controls, one worker, dt1/60, budget20 and450 ticks
per case. The [protocol](gcr-carry-2026-11-04/protocol.json) fixes eight selective
motion cases plus LA and event-off full-rise controls, on Windows and Linux.
No cells are attached, erased, restored, assigned an invented identity or given
extra simulation ticks. Bounded128-cell observations fall back to complete
stored-cell censuses when required. Outside-window quantities are never assumed.

Both OS baselines complete all10 cases with true source custody. In full rise,
all16 grains lie in the deck's lower half before181 and below it afterward,
remaining horizontally inside the deck and surviving the next boundary.
Boosted rise reproduces at148. Aggregate displacement is16 at each witness.
Actual vertical speeds there are approximately64.14 and69.08cells/s; these are
fixture observations, not a universal speed threshold. Stationary, slow and
moderate rise have no far-side deck escape. Event-off reproduces full-rise181;
LA does not lift sufficiently in that arm.

The native-only36-case replay isolates the cause without a native tick, live
Rapier body, force result or per-proxy evaluator. A26×2 rectangle moves upward
1.5/2 cells across one previously above-deck grain. Its current nearest face is
now the bottom, so existing ejection moves the grain downward3cells. This
occurs in both independent/authored routes and C/E/S:12/36 cases per OS.
All1046 apparatus checks and exact quantities pass. Offset3 uses the sweep-only
branch and does not show that defect: leakage is not assumed monotonic in step.

The closed-end and diagonal cases have far-side occupancy too, but they lack
the same complete cloud/interior witness. Open-rim/nose escape and rotation
must not be relabelled a proven closed-wall crossing from those counts alone.

## Bounded repair and authority

One private adapter helper preserves a unique entry face for currently
overlapping material in the explicitly authored compound route. It requires
valid previous geometry, consecutive samples in the existing cyclic protocol,
exactly unchanged orientation/size, nonzero translation within the existing
32-cell sweep bound, and the source centre outside the entire previous union.
A two-axis slab interval chooses the entry face. A corner/tangent tie, any other
proxy intersection, missing history, rotation or ambiguous seam retains the
old rule. This follows the current cell centre through hull transforms; it is
not a reconstructed persistent grain trajectory or general continuous collision.

Penetration is measured to that face; existing search distances, probe/radius
limits, empty endpoints, whole-union masks and hard/foreign-mask path rules are
unchanged. No advection, response owner, mass, impulse budget, material law,
friction, motor or sleep change. Independent bodies retain their old ejection
selection, and the conservative structural branch returns before this helper.
At most eight proxy slab tests are added per admitted overlapping source;
solver-node counts alone do not measure this extra preparation work.

Both source-matched SDKs are rebuilt from3df1279f using pinned Godot-cpp101ae380,
LLVM-MinGW23.1 and GCC13.3. [Build records](gcr-carry-2026-11-04/native-builds.json)
retain commands, compiler/dependency inputs, source/artifact hashes and explicit
platform scope. Linux floor remains GLIBC2.34 bundle, extension GLIBC2.32,
GLIBCXX3.4.30 and CXXABI1.3.9. Godot4.7.stable.official.5b4e0cb0f and Rapier
addon0.35.2/core0.35.1 remain pinned. Other platform artifacts remain historical.

## Qualification, failures and limits

Fresh candidate02 at68aef83c completes the unchanged20 live captures with true
source custody. The matched reducer authenticates original raw/log/campaign,
complete copied source/native maps, protocol, runtime bytes and frozen actor
definition, retaining coordinate-set limitations and exact quantities. Compact
summaries/traces and original hashes accompany this record. Large raw remains
local under build/carry-baseline-01 and build/carry-candidate-02.
The [paired summary](gcr-carry-2026-11-04/paired-summary.json),
[baseline](gcr-carry-2026-11-04/baseline-summary.json),
[candidate](gcr-carry-2026-11-04/candidate-summary.json) and
[selected witnesses](gcr-carry-2026-11-04/selected-witnesses.json) keep every case
and the same illustrative failure boundaries in both cohorts. Separate raw
manifests bind the large original files; the
[verification summary](gcr-carry-2026-11-04/verification-summary.json) preserves
original failed controls, builds and instrumentation receipts.

| Level rise, both OSs | Baseline | Candidate |
| --- | --- | --- |
| Selective full | Persistent closed-deck escape starts181 | No below-deck frames |
| Selective boosted | Persistent closed-deck escape starts148 | No below-deck frames |
| Event-off full | Persistent closed-deck escape starts181 | No below-deck frames |
| Stationary/slow/moderate | No far-side deck escape | No far-side deck escape |
| Native authored one-rectangle replay |6/18 wrong-side endpoints |0/18 |
| Native independent replay |6/18 wrong-side endpoints |6/18, retained control |

This is not accomplished by slowing the craft: selective full keeps the same
97.974cells/s peak upward speed and1.63687cell maximum normal COM step; boosted
keeps119.178cells/s and1.99027cells. Quantities and one-owner/budget/energy checks
pass in all40 acquired baseline/candidate cases. The paired source comparison
changes exactly the two native adapter inputs; actor, capture, replay, commands
and configuration are unchanged, with native provenance and the added targeted
test identified separately. No baseline rejection or custody failure is hidden.

Diagonal motion retains a persistent far-side observation at165 without the
all-cloud interior qualifier; the closed-end147 observation also lacks its
height qualifier and is unchanged. These are unresolved or open-edge behaviours,
not evidence of a general corner/rotation fix. Open-nose departure remains an
open-side result. Primary cavity minima of zero also remain: the repair prevents
the demonstrated far-side relocation but does not synchronize native and drawn
poses or promise an uninterrupted current-pose cavity count.

Keeping cargo requires more actual native relocations: in boosted rise the
aggregate displaced sum increases256→2148 per OS. Work is therefore reported,
not described as free. Each case retains whole-owner step p50/p95/p99/max and
native scanned/move/active-block work; timings exclude the diagnostic snapshots
and are not a controlled production performance comparison. Passive body-energy
checks exclude motor, gravity, event/correction and material relocation work;
they do not establish total body/material mechanical-energy conservation.

The new native entry-side test passes400 checks per OS: corrected authored
translation in all C/E/S, retained independent endpoints, fixed rotated
orientations, changed-angle and serial-gap fallback, previous overlap, sweep
bound, shared seams/intervening proxies, hard obstruction, reset/session
watermark and mixed-owner refusal. A foreign independent owner is refused;
the test does not fabricate a foreign mask to claim additional coverage.

Candidate01 failed this new test before physical acquisition on both OSs.
Its previous-overlap fixture attempted to seed beneath a live mask: native cell
authority refused the grain although the diagnostic fill wrapper returned true.
The explicit quantity checks caught zero Sand. The corrected native-only fixture
seeds before masks, admits its old sample with resolve=false, then resolves the
next sample normally. No force efficacy is claimed for that initially unbacked
overlap and no authority check is weakened. Original failures and source are
preserved. An initial reducer command comparison also rejects float32(-0.1)
against unconverted JSON doubles; comparing to the exact float32 carrier fixes
only the observer expectation, not physical commands or tolerances.

Fresh local adapter ASan/UBSan coverage passes import and9397 checks:
entry400, authored API6277, body245, detachment415 and no-catch2060. Its actual
compile sourcee625c6f2 has the same89 inputs as shipping3df; host source68aef83c.
Instrumented module SHA256 is
`9993d33a9941c2d891c66af7429604e2561dbe557e5d867d5fe106dfa14f70eb`.
This retains the explicitly local loader shim removing RTLD_DEEPBIND, with leak
detection enabled and one exact Fontconfig suppression matching three external
import allocations/320bytes. Original unsuppressed stacks are preserved. No
candidate sanitizer diagnostics occur; shipping engine/libraries are untouched
by instrumentation. Core177 Debug and177 ASan/UBSan results remain separate,
reusable only after authenticating all136 unchanged core/test/build inputs.

Final-head full host, docs/provenance, retrieval, source/SDK and hosted statuses
belong to their actual source receipt and the focused draft PR. The three
inherited material-shadow lock mismatches remain a separate blocker; no lock or
checker is refreshed. No broad physical, uninterrupted-carry, rotational CCD,
production/default or owner acceptance follows. Actual delayed/asynchronous
authored motion is not qualified by these synchronous captures; retained async
regressions are a separate compatibility gate. All PRs stay unmerged.

Reproduce with fresh output directories:
`python tools/experiments/run_gcr_carry.py --output build/<new-run> --platform both`
then
`python tools/experiments/analyze_gcr_carry.py --output build/<new-candidate> --baseline build/<baseline> --summary-dir build/<new-summary>`.
The reducer's eight failure controls cover quantity, frame/class identity,
missing/false crossing witnesses, budget and actuation corruption. Final host
gates use run_gcr_authored.py --gates-only; no physical snapshot is advanced to
the final documentation head by renaming its source.

The new worktree's first documentation preflight reports six missing references
to the separate companion workspace. Binding the same five authenticated
companion snapshot files used by PR385 restores those references; both local
documentation and materialized provenance then pass. Binding hashes remain in
build/companion-bindings.json. Source documentation and expected fixtures are
not weakened to hide missing external inputs.
