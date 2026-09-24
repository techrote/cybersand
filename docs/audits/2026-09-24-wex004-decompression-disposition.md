---
title: WEX-004 bounded decompression impulse-event disposition
status: Current
document-kind: evidence
scope: Final evidence and disposition for issue #94 WEX-004; bounded non-production decompression-event proof only
canonical-for: [wex-004-disposition]
last-reviewed: 2026-09-24
related-documents: [../research/bounded-decompression-impulse-events.md, ../research/lumped-gas-region-pressure-bookkeeping.md, ../operations/water-hybrid-pressure-extension-programme.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/validation-evidence.md]
---

# WEX-004 bounded decompression impulse-event disposition

## Disposition

**NARROW-USE.**

The WEX-004 proof demonstrates that a resolved pressure-difference snapshot can
drive a deterministic, finite, local decompression effect on loose cellular debris
and generic Rapier bodies without a cellular gas-velocity field, whole-room
pathfinding, duplicated source budget or through-wall attraction.

It does **not** establish a general decompression/atmosphere solver. The executed
model is intentionally a straight-line local breach abstraction. It suppresses
rather than routes flow around obstacles and conservatively cancels on any
unrecognized external diagnostic-world revision. Those limitations match the
preregistered `narrow-use` criterion exactly.

The useful retained interpretation is therefore:

- viable as a bounded local effect for simple/open, explicitly resolved breaches;
- useful research evidence for #95 and for a possible future authored/portal-local
  decompression feature;
- not authority for production atmosphere integration;
- not evidence that routed/corner flow, long corridors, room-scale gas motion or
  general vacuum scenes can be represented without a broader field/topology owner.

No production follow-up issue is created by this disposition.

## Authority and source identity

WEX-003 / #93 explicitly admitted WEX-004 only as a bounded non-production proof.

Recovered WEX source:

`66a2935e1001737e63ecb03fd21050f7d433bda7`

Post-publication PR head before this disposition record:

`0f17cd36a6e1fa65176a11d1fe2f695dca06ba12`

REC-006 reconstructed PR #105 from recovered main, removed stale
CircleCI/Avrea/Sengi/workflow overlap, and retained only the WEX proof plus the
minimal diagnostic relocation adapter/regression and source-matched runtimes.

No WEX/native/test source changed after `66a2935...`; later commits published
source-matched retained runtimes/provenance and this disposition material.

## Executed evidence

### Source validation

Exact reconstructed source `66a2935...` passed:

- Native C++ run **35744170902** — success;
- GDExtension/Godot run **35744170918** — success;
- Linux runtime build — success;
- Windows x86_64 cross-build — success;
- Linux regression shards 0/1/2/3 — success;
- aggregate Linux gate — success.

The Native run includes the payload-preserving relocation regression, ordinary
native coverage, sanitizers, TSan, shared-library build and benchmark.

### WEX-004 executable run

The WEX fixture executed in Linux regression shard 1, job
**106804170960**, on GitHub-hosted **Ubuntu 24.04**, Godot
**4.7.stable.official.5b4e0cb0f**, one cellular worker.

Retained emitted report:

```text
WEX004_DECOMPRESSION {
  "blocked_occlusions": 1,
  "cell_applied": 0.04,
  "cost": {
    "count": 64,
    "p50_usec": 302,
    "p95_usec": 325,
    "p99_usec": 333,
    "max_usec": 333
  },
  "decay_final_pressure_pa": 189140.0,
  "decay_work_trace": [
    0.75, 0.75, 0.75, 0.75, 0.75,
    0.729166666666667, 0.625, 0.520833333333333,
    0.416666666666667, 0.3125, 0.208333333333333,
    0.104166666666667, 0.0
  ],
  "ok": true,
  "platform": "Linux",
  "rapier_work": 0.75,
  "shared_applied": 0.08,
  "shared_initial_budget": 12.0,
  "vacuum_budget": 12.0,
  "workers": 1
}
```

The timing population measures 64 source-identical first event steps with setup
outside the timed interval. It is CI-environment evidence, not representative
target-hardware performance acceptance.

### Source-matched runtime publication

Publication run **35746514892**:

- verified the frozen source/tree;
- restored the exact Linux runtime artifact used by the successful Godot suite;
- rebuilt Windows with pinned LLVM-MinGW/godot-cpp/SCons;
- regenerated runtime provenance from actual bytes and source inputs;
- passed `check_repository.py --require-materialized`;
- passed `git lfs fsck`;
- pushed verified LFS objects.

Retained Linux runtime:

- SHA-256
  `58eca0792f067a2706c5a9d1a01f52226cd7e7e0b4118fc0229ebcddc1d4064e`;
- 1,612,912 bytes;
- actual Linux runtime execution evidence exists.

Retained Windows runtime:

- SHA-256
  `cccc4a5dea7bc7d5dbf2e61f44cbbbaf79d9f02fa8605171cd3efdf2b11eef5f`;
- 2,091,008 bytes;
- **cross-build only**; no Windows execution is claimed.

## D0-D8 review

| Scenario | Evidence | Disposition |
|---|---|---|
| D0 simple breach | Sand relocates exactly one cell along the opening normal; repeated, shifted and mirrored cases retain the same outcome. The 12-step lifetime trace is non-increasing, exhibits decay and is exactly zero on the post-lifetime step. | Pass |
| D1 obstacle | A hard Wall on the direct target-to-opening line prevents the cell move and increments occlusion rejection. Shifted repetition preserves the result. | Pass |
| D2 offset opening | Offset Dust moves along the opening normal, not diagonally toward the breach point; mirrored repetition preserves direction. | Pass |
| D3 Rapier body | A real generic `RigidBody2D` receives positive outward impulse through `CyberRapierPhysicsBridge`, the result is applied on the existing main-thread bridge, and the body moves outward without unintended vertical motion. | Pass |
| D4 cellular debris | The diagnostic adapter delegates to existing `World::relocate_stored_cell()`. Native regression proves material, `state_a`, `state_b` and optional temperature preservation and occupied-destination refusal without mutation. | Pass |
| D5 multiple openings | Openings are canonically ordered; event initial budgets sum to one source budget; source budget is capped at 12; one-step global work remains capped; shifted case preserves budget/work. | Pass |
| D6 stale topology | External world revision change cancels before work; opening-generation mismatch also cancels before work. The target remains unmoved. | Pass |
| D7 low differential | 125 Pa differential is below the frozen 250 Pa floor; initial budget is zero and no movement/work occurs. | Pass |
| D8 vacuum stress | Destination pressure is 0 Pa absolute; source budget remains capped at 12, pressure remains finite/non-negative, per-event work remains <=1.25 and cellular move count remains <=32. | Pass |

## Boundedness and accounting review

The proof has fixed ceilings rather than world-size-dependent work:

- maximum **4** opening events per source registration;
- **12** event-step lifetime;
- **10-cell** local horizon;
- each event scans at most the fixed local 21x21 bounding square before
  eligibility filtering;
- line-of-sight traversal is bounded by the local horizon;
- global applied-work cap **2.5** per diagnostic step;
- per-event applied-work cap **1.25**;
- maximum **32** successful cell relocations per step;
- per-body per-event impulse cap **0.75**;
- source work budget capped at **12** and partitioned once across openings.

The source budget is decremented only by applied work. Current source pressure is
derived from remaining amount at fixed volume. Adding openings changes partition
weights but does not multiply the source budget.

The model adds no persistent per-cell gas pressure, gas velocity or decompression
velocity field.

## Falsification review

### Through-wall attraction

**Not observed.** D1 blocks the direct path and suppresses the effect. The model
does not route around the wall.

### Whole-room/world cost

**Not present in this proof.** Each event scans a fixed local horizon and bounded
line traversals. This does not prove a future gas-region/topology implementation is
cheap; WEX-003 explicitly left that separate.

### Duplicated source energy/work

**Not observed.** D5 partitions one finite source budget across openings and the
ledger closes against applied work.

### Stale openings applying force

**Not observed.** Generation and authority-revision mismatch cancel before work.

### Cellular/Rapier disagreement

**No catastrophic disagreement in the registered envelope.** Both target classes
receive motion along the same frozen opening normal and through legal ownership
paths. This is a small one-body/local-debris proof, not broad equivalence.

### Ownership/conservation

**Pass within the registered scope.** Cellular relocation reuses the serialized
native move owner and preserves compact payload plus optional temperature. Rapier
remains on the existing main-thread bridge.

### Full gas CFD required

**Not required for the demonstrated simple/open breach cases.** It may become
necessary, or another bounded routed-flow abstraction may be required, for corner
flow, branching corridors or room-scale transport. WEX-004 does not answer those
cases.

## Why the result is narrow-use rather than promising

The preregistration says to use `narrow-use` when the straight-line abstraction
is useful only for simple/open breaches, requires conservative cancellation, or
cannot plausibly represent routed/corner flow without a broader field.

All three qualifiers apply:

1. obstacle handling is line-of-sight rejection, not routed flow;
2. the Arm-B authority revision conservatively invalidates the event on any
   unrecognized external cell mutation;
3. no evidence exists for flow around corners, through branching openings, down
   long corridors or across room-scale topology.

Calling this generally `promising` would erase the most important experimental
boundary. Calling it `no-go` would also be inaccurate: the registered simple
breach controls passed without unsafe ownership, global traversal, duplicated
budget or CFD.

## Recommendation to #90 / #95

WEX-005 should consume WEX-004 as:

**a successful narrow-use local decompression proof, not a production atmosphere
candidate.**

Consequences for synthesis:

- retain the result as evidence that WEX-003-style resolved pressure snapshots can
  drive a cheap bounded local effect without cellular gas CFD;
- do not use WEX-004 as evidence that #45 saturated-Water-head work is solved or
  unnecessary; decompression is a separate boundary/event question;
- do not create a production decompression issue unless a concrete gameplay/engine
  use case justifies one and a production gas-region/portal owner exists;
- if such a use appears later, start with explicitly authored/resolved openings and
  simple direct-flow events; require a new registered proof for routed/corner flow;
- keep #93's gas-region architecture research-only unless #95 or a later explicit
  authority separately admits production work.

For WEX programme completion, #94 can be considered satisfied after this
disposition and its exact-head/merged-main validation. #95 still requires #92 or
an explicit current blocked/no-go disposition for #92.

## Final-validation trigger note

The first `ready_for_review` event correctly classified this PR as requiring
expensive validation, but the downstream jobs were skipped by event-state
orchestration. Those skipped jobs are **not** acceptance evidence.

A subsequent ready-PR `synchronize` run proved the source builds were healthy,
but exposed a second orchestration defect: Linux and Windows GDExtension builds
passed while all Linux regression shards inherited a skipped `ready_scope`
ancestor and were skipped; aggregate run **36017635355** therefore failed
correctly rather than manufacturing green.

That repository-level validation-premise bug was fixed separately in PR #126,
merged as `207bd4202c1a98b6a782333595f733d10c90a609`. The fix adds explicit
`always()` evaluation plus a successful-`linux-build` premise to downstream
GDExtension regression/serial jobs; it changes no WEX source, test, runner or
provider.

This documentation synchronization triggers final #94 validation against the
corrected current main. The WEX force law/native/test source remains unchanged.
Exact final run identities are recorded in the PR/issue completion record after
they finish. The earlier skipped/aggregate-failed orchestration runs remain
non-evidence.

## Remaining evidence limits

- Linux Godot runtime execution only; Windows is cross-build evidence.
- One cellular worker in the retained WEX executable run; no worker-parity claim is
  made for the GDScript event model.
- Timing is GitHub CI first-step timing, not target-hardware or sustained-load
  performance.
- Rapier coverage is one small generic rectangular body.
- Cellular target set is Sand, Dust, Salt and Gunpowder only.
- No routed/corner flow, long-corridor flow, multiple-room topology or atmosphere
  persistence.
- No production save/replay schema or gas-region implementation.
- Work/impulse quantities are declared proxies, not calibrated joules/momentum.
- No owner visual/gameplay acceptance is required or claimed for this research
  disposition.
