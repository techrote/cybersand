---
title: Compound granular response and native detachment qualification
status: Current
document-kind: audit
scope: Source-qualified experimental single-aggregate integration; mechanical pass, physical production gate not met, owner acceptance pending
canonical-for: [compound-granular-detachment-evidence-20261102]
last-reviewed: 2026-11-02
related-documents: [../operations/gcr-detachment-integration-plan.md, ../architecture/compound-granular-coupling.md]
---

# Compound granular response and native detachment qualification

## Disposition

The one-owner compound integration is mechanically qualified for its narrow
experimental developer route. It is **not production physically qualified**:
one of eight registered COM-entry comparisons fails, all eight comparative
stored-cell overlap gates are unsupported, and hard terrain confounds bearing.
There is no default promotion, new friction/load law, sleep policy, mass
rescaling, ordinary-playground detachment admission or issue#12/#281/#83 closure.
All PRs remain unmerged. **AWAITING OWNER GAMEPLAY ACCEPTANCE.** Gameplay
acceptance alone would not erase a failed or unsupported technical gate.

## Sources and recoverable checkpoints

Fresh main was `a8f08a67fea3c58f6df7473cbae1831334fcc04e`, tree
`4bfc2fbdda3704dfbf386235e54d2fe525ca32bc`; a second fetch on2026-11-02 still
resolved that main. Branch `codex/gcr-detachment-integration-20261101` selectively
reconstructs source/tests from detachment#347 `5af50b3c5a5f11614099a82090ad431646db4cba`
and GCR#348 `be1847464803bab0f74d184d60d77aea5e384228`. No branch was merged,
rebased or wholesale cherry-picked. The separate fleet checkout and unrelated
dirty material checkout remain preserved. The branch is pushed as a recovery
checkpoint; large raw bundles are local, not silently claimed remotely available.

| Lane | Exact executed source | Meaning |
|---|---|---|
| Native build/full suites and original scoped hosts | `5d124667a3058a335680048a7099e2bbabde8de3` | Both exact native libraries and unchanged production physics inputs |
| Corrected acquisition | `86108a148d6edf4d2c956a13f47a22ebe2cd0c7e` | One capture-entrypoint parser/receipt repair;88 native inputs and536 of537 project inputs independently unchanged |
| Playable selector | `9138bdaf2ea295b0e6ff84972dd909fefdf7a2f1` | Lab UI plus zero-release selector test; native/session/worker/bridge physics unchanged |
| Corrected reduction | `ec182afcaf64993ae342a3220e3342b3be925c7d` | Analyzer code; all eight original primary outcomes exactly retained |
| Reducer regressions | `b5c110a8` |13 synthetic regressions, including tiny offered-but-unapplied correction accounting |

The [registration](../operations/gcr-detachment-integration-plan.md) and
[machine protocol](gcr-detachment-2026-11-01/protocol.json) precede all physical
results. Native artifacts are Windows SHA-256
`2922792e238f45be1f4188472071f8d629bcdecb5345f7bd3716ae2a43eb1603`,4,986,880bytes,
and Linux `3b69072af379f8f71dcff19d941c5d4cfa7a13387b70a0eeba3d20f865366dbd`,4,412,328bytes.
Godot is4.7.stable.official.5b4e0cb0f; Rapier2D addon is the pinned0.35.2 with rapier2d core0.35.1 and the
Windows/Linux cooperative-BVH backport. Native build provenance keeps source5d, rather than relabelling it as a
later UI/documentation build. Toolchain hashes were verified after building;
this is not contemporaneous tracing or reproducible-release attestation.

## What changed and what passed?

The seven shared World/adapter/worker/Rapier paths preserve native payload
handoff, collision retirement, rollback, quarantine and asynchronous lease fences.
One complete17-value-per-proxy batch describes one actual COM velocity, mass,
COM and inertia. One version2 physical wrench is solved and applied; independent
version1 and legacy11/9 routes refuse misrouting. Native mask-installation
acknowledgement precedes release. Every actual proxy corner participates in the
age<=1/displacement<=0.5 admission check.

The native aggregate is520 unit-square RedBrick members, six exact rectangles,
mass520, COM(57.33076923076923,37.875), inertia109907693/1560. Actual Rapier
inertia is its permitted host-float representation70453.6484375. The crown pixel
hole and open AABB concavity remain empty geometry; neither is filled by an AABB.
No lightweight flyer convention is applied to terrain. One event/normal budget20,
per-source2, unchanged friction/material response, and one correction cap0.5
serve the whole body. Conservative four-parcel relocation remains a separate
material operation, not evidence of penetration resistance.

| Executed gate | Result |
|---|---|
| Windows LLVM-MinGW Clang23.1 O2, Linux GCC13 O2, Linux GCC13 ASAN+UBSAN O1 | Nine builds+nine executions pass;177 core groups in each profile; no timeout/sanitizer diagnostics |
| Standalone detachment, each profile |10groups /19,355checks, including allocation-forbidden explicit quarantine |
| Standalone conservative displacement, each profile |6groups /281checks |
| Compound mechanics |81 exact old-wrapper comparisons; independent full-node oracle;1024-node/8192-update bounds; unchanged36-case reduction maximum0.0450628 versus0.10 gate |
| Scoped target-OS hosts |46effective cases per OS, including REM-002/003, old GCR/async/gameplay, lifecycle/failure/relocation controls |
| New compound/current acquisition controls |415 native/bridge+63 async/publication assertions per OS; repeated at861 after capture-only repair |
| Current-main render/Water controls |Five cases per OS; RG8 full/delta, immutable handoff, generation and Water/liquid policy preserved |
| Final UI control at9138 |Lab41+bridge415+async63 assertions per OS; anchored selector test performs no body release/trajectory |
| Linux ABI floor |GLIBC2.34 bundle; extension GLIBCXX3.4.30/CXXABI1.3.9 |

Limits remain1024 nodes/8192 scalar updates per native boundary, with fixed
73,728-byte solver scratch plus bounded stack data. Observed GCR maximum was
42nodes/336updates. The API still allocates copied arrays/dictionaries/strings;
full preparation/publication allocation-free operation is not claimed. Explicit
native quarantine is tested; the adapter catch itself was not fault-injected.

## Registered physical population and results

All48 primary and eight R2 worker1 repeats completed: legacy/R2/A1 × four
surroundings × requested workers1/4 × Windows/Linux, with a target horizon of
1200 native ticks and a300-observation tail. Actual cutoff overshoot is0–1tick;
observed row counts are1199–1202 and remain explicitly recorded. All56 captures
have matching post-campaign source/project/runtime identities and no acquisition,
handoff, runtime or timeout failures. Observations include held main frames with
zero actual Rapier dt; derivatives then remain null. Configured workers are not
a claim that every worker participated in every tick. Repeated event counts are
not independent efficacy samples.

| OS / requested workers | Packed COM-entry legacy→R2 | Embedded COM-entry legacy→R2 | Registered entry gates |
|---|---:|---:|---|
| Windows /1 |20.364670→20.364666 |20.364658→20.364670 |pass /pass |
| Windows /4 |20.364666→20.366100 |18.456108→20.364655 |pass /**FAIL** |
| Linux /1 |20.364655→20.364662 |20.364674→19.657776 |pass /pass |
| Linux /4 |20.364662→20.364658 |20.364666→20.364666 |pass /pass |

The Windows4 embedded increase is1.908546cells against allowance1.845611,
exceeding the original gate by0.062936. It is retained without threshold change.
COM downward travel is a fixture-relative proxy, not measured granular
penetration. All eight comparative overlap gates remain null: legacy has no
matching ledger, and the top-level capture observations are unsupported.
Supplemental copied native GCR observations reach470 post-ejection overlapped
movable cell centres; coverage is68.27–99.83% for R2 and67.44–99.75% for A1.
Those are largest observed samples, not complete-window maxima or gate passes.

All56 regional checks in(0,0,160,128) close exactly: Sand count, integer Water mass, unchanged
Wall count, native Brick+520-owned payload balanced against the confirmed8-cell
cut, exact member tuples and sole aggregate520/native-source0 ownership.
Sampled passive energy delta never exceeds0; event, correction/zeroing, gravity
and hard-contact energy remain separate. The normal+event cost maximum is
20.00000000000005 from roundoff within the registered tolerance. Delivery refuses
remain counted, not silently applied or converted into efficacy populations.

The source leaves20 hard Brick stump cells atx[50,54),y[67,72), two cells below
the initial stem; floor beginsy72. COM.x lies outside the upright stem width.
Stump/floor contact and rotation are possible before the floor-plane flag, and
there is no hard-contact wrench ledger isolating them. Late stability therefore
does not establish granular support for mass520. The unusually shallow A1
Linux1 embedded result also contains1089 correction/zeroing events and a last300
span4.8674×2.4766cells with |vy|p95≈3.0214: it is not an accepted rest envelope.
Registered worker1 repeats vary; the largest R2 entry difference is Linux embedded
+0.706875cells. They neither replicate nor dismiss the Windows4 primary failure.

## Performance investigation and unsupported envelope

All eight R2/legacy primary pairs trigger the preregistered main-sync investigation:
p95 increases52–103.9microseconds (ratios1.323–1.684). Three worker, one native-tick
and one Rapier timing comparisons also trigger. Source review identifies bounded
17-field geometry packing,24-corner transport checks, COM-wrench processing and
diagnostic deep copies; native result generation belongs to the worker snapshot
path. These observations do not isolate a causal cost fraction. Trajectories and
concurrent processes differ; no uncontended performance acceptance follows.
Legacy work counters are absent, so work-amplification comparisons remain null.

This route is one homogeneous ambient Wall/RedBrick aggregate. Simultaneous
player/flyer/other independent bodies in the same World are not admitted by the
compound API. Other compound geometries/materials, arbitrary fracture/restoration,
reactive payload, browser/Web, true heavy granular bearing and owner gameplay
acceptance remain unqualified. The generic response still uses the existing
powder/granular policy; these dynamic compound fixtures do not qualify every
powder. The next load-law decision needs separately registered evidence that
isolates hard support while retaining payload-derived mass, rather than silently
lightening buildings or increasing friction to mask the limit.

## Retained failures, reproducibility and owner review

Pre-fix sourcee6485b5 built both modules and passed Windows native gates before
review found angle-overflow, empty-mask-clearing and preparation exception gaps.
Its matrix remains explicitly incomplete. The successor also clears actionable
GCR fields in failed snapshots while preserving prior immutable presentation.
Six host-wrapper failures are retained: four displacement invocations omitted the
optional report-file assertion (291 versus292checks); corrected invocations ran
all17cases with292checks. Two liquid-worker logs passed29assertions but the wrapper
expected a boolean rather than the actual completed dictionary; their original
hashed logs were reparsed, not claimed rerun.

Source5d also produced33 zero-owner argument failures (Windows28/Linux5): JSON
FLOAT worker values failed INT array membership. No World/body/open/ticks ran.
Its unconditional edit metadata was planned intent incorrectly labelled as actual;
it is not evidence of an executed cut. Source861 repairs numeric comparison and
separates planned/confirmed edits. All56 configurations then passed actual-engine
validation-only preflights before physical acquisition. Native88/project537 and
full-native92 inputs were independently compared; only the capture script changed.
The failed/partial analyzer admission defect was corrected after capture; all
current captures succeeded, so all eight original outcomes remain exactly equal.
The first ignored supplementary reducer also overcounted883 tiny offered but
unapplied legacy corrections across12 cases. The corrected analyzer uses actual
application counters; the original supplement remains archived. Corrected totals
are legacy2071/R22673/A12920 actual corrections. The GCR A1 example above uses
its explicit applied flag and is unaffected. Thirteen reducer regressions pass.

Compact [engineering](gcr-detachment-2026-11-01/engineering-summary.json),
[physical](gcr-detachment-2026-11-01/physical-summary.json),
[selected traces](gcr-detachment-2026-11-01/selected-traces.json) and
[evidence manifest](gcr-detachment-2026-11-01/evidence-manifest.json) accompany the
[protocol](gcr-detachment-2026-11-01/protocol.json). The local raw ZIP is139,847,809bytes,
SHA-256 `93dd44203871053397128352e252bdb62bbe184dc8d6ff4c790826ea0b0496d6`,
with531 entries fully decompressed and hashed against its immutable file manifest. Raw logs/binaries/archives stay
local and uncommitted; their availability and hashes are stated explicitly, not
inferred from a hash alone. Exact commands, bounds, tools, input hashes and source
lane distinctions are preserved. Final source-sensitive documentation/provenance
checks belong to the final draft head; the frozen execution records keep their
original source identities.

Use the pinned engine and matching materialized runtimes:

```text
godot --path godot res://solid_detachment_lab.tscn -- --candidate=R2 --surroundings=packed_sand --workers=1
```

Default is legacy. C cycles fresh legacy/R2/A1 sessions; R resets; Space cuts;
P pauses; 1–4 change surroundings; W changes requested workers; X excavates;
I prints copied conservation values. The visible arm is experimental for R2/A1.
`--baseline` refuses an experimental contact arm. No runtime law switches live.
The [owner-review manifest](gcr-detachment-2026-11-01/owner-review.json) records exact source/runtime/engine/backend and
manual commands; preparing or testing it is not owner gameplay acceptance.

Documentation mapping: the compound contract owns this interface/capacity;
soliding lifecycle and data-ownership routes describe lifetime; interfaces,
invariants, configuration and build/test routes link the focused owner; roadmap,
handover, corpus/index and the added GCR-DETACHMENT retrieval challenge agree.
ADR-007 and the material programme retain their existing ownership semantics.
No dependency pin, provider policy, historical M11 evidence or material law changes.
