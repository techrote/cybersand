---
title: Physical detachment deterministic replay and bounded rearrangement investigation
status: Current
document-kind: audit
scope: Fresh-main rectangle ejection investigation with separate replay, topology and copied-state push-chain checkpoints; no production displacement admission
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../reference/invariants.md, ../reference/status-and-roadmap.md, ../operations/local-build-and-validation.md, ../operations/current-and-historical-validation.md]
---

# Physical detachment investigation — 2026-10-31

## Frozen source and investigation boundary

The experimental baseline is freshly fetched `main`
`adaaa37ae35ffcdaa961b80353be3a23b805c0cc`, Git tree
`ad800ebd5c876f6d1ecd080a6dc3f02918b21870`. The new branch is
`codex/physical-detachment-abc-20261031`, isolated at
`C:/Users/_/.codex/worktrees/physical-detachment-abc/khybersand`.
This run must retain that baseline: no rebase, merge from main, or consumption
of commits from the concurrent investigation. Cross-branch reconciliation is
a subsequent integration task. No merge is authorized by this experiment.

The original source checkout `C:/khybersand` was on
`mat/material-fidelity-pass-2`, HEAD
`620826f59fbe248f93a45c45e786a7297f2e5288`, with unrelated modified native
World/material/test files and a Windows runtime, plus untracked UID/handoff
files. Those files were preserved; this branch was created in a separate
worktree directly from the frozen main commit. The source remote remains
`https://github.com/techrote/cybersand.git`.

This is one dependent investigation: Stage A establishes immutable contact
capsules and deterministic production-decision replay; Stage B reads that
frozen corpus for topology and normal diagnosis; Stage C evaluates bounded
conservative push chains on copied state. Each stage requires its own committed
checkpoint. The oracle cannot be promoted into the runtime in this run.

## Initial open-PR reconciliation

Read-only GitHub metadata and changed-file inventory were captured on
2026-10-31 with `gh pr list --repo techrote/cybersand --state open --limit 100
--json number,title,headRefName,headRefOid,isDraft,url,files`. These are collision
and evidence boundaries; their commits are not experimental inputs.

| Open PR | Captured head | State and relevant surface |
|---|---|---|
| [#283](https://github.com/techrote/cybersand/pull/283) | `254235ec4c3d58782bba44b478caca86bf57c856` | Draft, frozen tree/compound/ejection archive only |
| [#23](https://github.com/techrote/cybersand/pull/23) | `0b96ce2a2fd5f68560575d4c4db8b0ea2f3b3758` | Draft, historical soliding/coupling implementation |
| [#282](https://github.com/techrote/cybersand/pull/282) | `c087ca8569f1df394d67cdc4dbe1c6b46c2bcfb2` | Draft, structural-detachment programme documentation |
| [#333](https://github.com/techrote/cybersand/pull/333) | `21d44e43e071d2d5777c2ed46a92f59675639599` | Draft, render work sharing native World/test files |
| [#290](https://github.com/techrote/cybersand/pull/290) | `ddf812f34c533f654f1488b9115eb0256305a288` | Draft, render-copy work sharing native World/test files |
| [#162](https://github.com/techrote/cybersand/pull/162) | `19f7ff43ecc494185226d1fff07dc21ef4a220fb` | Ready, Water quantity/phase work sharing World authority |
| [#258](https://github.com/techrote/cybersand/pull/258) | `fec2c73a33e146c63398849a1d128cf45c0ba59b` | Ready, native extension observer interfaces |
| [#262](https://github.com/techrote/cybersand/pull/262) | `70ec119381a2cb9abab5d40ed3314fb07c9b1736` | Ready, Rapier bridge and player playground |
| [#272](https://github.com/techrote/cybersand/pull/272) | `00c76b338f65f15d01d7b8c2cba8ebc1a5b23753` | Draft, async architecture and physics tests |
| [#330](https://github.com/techrote/cybersand/pull/330) | `a2543abdcf611d232f538462358bd12bfb0d152f` | Ready, watchdog changes including body/physics tests |
| [#260](https://github.com/techrote/cybersand/pull/260) | `86f95617d2966f9071e9fe8bdd334ea3888fa5cd` | Draft, liquid trial-body fixture |
| [#326](https://github.com/techrote/cybersand/pull/326) | `1afe20c0b2abbffaf3e41ac1e1588b862274c52c` | Draft, palette/cadence test surface |

The inventory distinguishes direct coupling changes from shared-file or test
collisions. It does not establish that every open branch remains applicable to
current main, or authorize integrating any of them.

## Current baseline semantics from source

**Current at the frozen baseline:** native rectangle ejection belongs to
`CyberNativeCellWorld::find_ejection_target` and
`ejection_path_reachable` in
[`cyber_native_cell_world.cpp`](../../godot/native_extension/cyber_native_cell_world.cpp).
The search starts at `max(1, ceil(penetration))`, visits nine inclusive distances
through `first_distance + 8`, and tries tangent offsets
`0, +1, -1, +2, -2, +3, -3, +4, -4` in that order: at most 81 candidates.
Candidate construction uses the cell centre, outward normal and tangent, then
floors each coordinate. Bounds, any endpoint body occupancy and non-empty stored
material reject an endpoint. The intermediate sampled segment rejects hard
surfaces and foreign body IDs, while allowing the source body's mask and
intervening soft material. A passing segment therefore does not prove a strict
empty route. This investigation does not widen those production bounds.

For contacts inside the current rectangle, `overlap_normal` selects the nearest
local rectangle face. Equal x/y penetration selects the y face; zero local
coordinate selects its positive sign. The chosen axis is rotated into world
coordinates and penetration is clamped to at least 0.5. Swept-only contacts use
normalized translation when nonzero, with overlap-face fallback otherwise.
Linear/angular state can explain how a contact arose without being an input to
the subsequent endpoint search. The capsule must preserve both provenance and
the exact decision inputs rather than infer one from the other.

Native cellular storage remains authoritative under the transient mask.
`World::relocate_stored_cell` is the move authority; a visible `material_at()`
query beneath a body is insufficient to capture the stored source tuple.
The GDScript fallback in [`cell_world.gd`](../../godot/scripts/cell_world.gd)
retains the corresponding bounded endpoint/path policy. Controlled parity must
be measured for the captured corpus. The archived #283 12-float cause protocol
is not assumed to be the current-main body-result ABI.

The existing `test_rem002_body_granular.gd` is a narrow source fixture route:
an 8×14 rectangle and 16×16 granular support bed, with native/fallback bearing,
excavation, Water and hard controls. Frozen #283's compound tree, render timing,
lifecycle and A/B policy apparatus are unnecessary prerequisites for replay.

## Frozen #283 evidence and limits

The archive head is exactly
`254235ec4c3d58782bba44b478caca86bf57c856`. It was inspected using `git show`;
no checkout, rebase, wholesale merge or commit to that branch was performed.
Its receipts qualify their recorded sources, not the frozen current-main source
above.

| Archived result | Executed source and tree | Retained finding |
|---|---|---|
| [Cause receipt](https://github.com/techrote/cybersand/blob/254235ec4c3d58782bba44b478caca86bf57c856/docs/audits/sol281-2026-10-28/unresolved-cause-receipt.json) | `756ae4882d346a1439244189c76eda8496070229`; `cf50b83207d28d63fef7b4a6562c87af99b6bb41` | Linux 1,557/1,557 and Windows 1,501/1,501 unresolved were no-target; other cause bins zero; unresolved attempts 97.8015% / 97.4043% |
| [A/B negative receipt](https://github.com/techrote/cybersand/blob/254235ec4c3d58782bba44b478caca86bf57c856/docs/audits/sol281-2026-10-28/ejection-search-ab-receipt.json) | `2d623e1034075f26b5443997781a267f16eeee85`; `cfbbc0cfe385a5905886dfc44b94ada463565ac3` | B=289 improves no-target rate only 0.4302 pp Linux / 0.6119 pp Windows, below registered 20 pp; **NO-GO** |
| [Corrected strict-route receipt](https://github.com/techrote/cybersand/blob/254235ec4c3d58782bba44b478caca86bf57c856/docs/audits/sol281-2026-10-28/strict-empty-route-receipt.json) | `ecacca3e701489d58a13793c038968d36f16bb03`; `94842a127df278655eb049383c52b7e61036a5b1` | 8,084 no-target attempts; 7,892 strict-empty-route absent; 7,891 permissive-direct with strict-empty-route absent |

The strict-route sums independently reconcile as
`2247 + 773 + 3486 + 1578 = 8084`,
`2247 + 772 + 3296 + 1577 = 7892`, and
`2247 + 772 + 3295 + 1577 = 7891`. They describe four different asynchronous
histories; they are neither unique-cell counts nor matched causal efficacy
measurements. The archive's initial failed strict-route run at `b68074d7`
remains negative evidence: its test confused visible masked material with
stored Sand and admitted unintended lateral escape from a rear fixture.
Later fixture corrections do not erase that failure.

These findings motivate testing small conservative rearrangement. They do not
establish its physical validity or justify a normal correction, broader search,
new material law, or production push chain.

## Stage A — replay checkpoint

**Passed on Windows x86_64, 2026-10-31:** the reduced REM-002 body/granular
fixture (32×48 Sand bed, real 8×14 Rapier rectangle, four-height drop, initial
rotation 0.08 radians and angular velocity 1 radian/second, 600 synchronous
coupling/native steps, one native worker) reproduced unresolved ejection.
Production material laws, geometry/search and gains remain unchanged.

The [frozen corpus](physical-detachment-2026-10-31/stage-a-corpus.json) and
[source/runtime receipt](physical-detachment-2026-10-31/stage-a-receipt.json)
retain exact raw counts, bounded-capacity outcomes, commands and SHA-256 inputs.
The corpus contains **64 unique no-target contacts and 16 successful controls**.
The live run recorded1,301 attempts:1,231 no-target,70 targets found and zero
authoritative relocation refusals;173 repeats matched retained states and1,048
were capacity drops. All 80 round-tripped full-precision JSON capsules reproduce the exact native
target, candidate order and rejection reason; actual fallback targets and its
ordered reason census agree for all 80. There are zero mutation failures and
15 malformed-input refusal controls. Existing REM-002 and physics observer/worker/
duplicate/hard-foreign-barrier/stored-Water-mass Godot regressions pass against
the rebuilt DLL. A literal pre-extraction native oracle
passes 4,096 seeded differential cases plus barrier controls. Returned-array
isolation, reset clearing and historical offline replay are also checked.

The initial axis-aligned fixture produced 669 unresolved and 78 successful
attempts but only 10 unique failures, so it failed the requested corpus quota.
The small-tilt and small-angular-impulse variants also failed quota (12 and22
unique failures). Their summaries are preserved in the receipt. The first two
reports used -1 as a generic failure sentinel in the mutation field; they did
not report an observed mutation. The final harness counts mutation separately.
The primary hash was tightened before qualification: it hashes tagged discrete
consulted reads/candidate records, excluding raw normal bits that would inflate
uniqueness without changing discrete search. Raw normals remain in capsules.

Counts of duplicates concern repeats of retained representatives; repeats of a
state first dropped after capacity saturation cannot be counted completely.
Unconsulted topology/tuple differences may share a search-equivalence hash.
Subsequent topology/oracle distributions describe these first representatives,
not all encountered physical neighbourhoods or asynchronous efficacy.

Only source coordinates, source-body relation, discretized candidates and
consulted Empty/hard/mask classifications determine search. Raw normal and
penetration generate those candidates. Body dynamics/geometry and owner IDs
are audit/fencing state, not additional replay dependencies once the decision
inputs are fixed. Quantity, carrier/spare/epoch bits and temperature are kept
for conservative copied-state movement, although they do not select the target.

Frozen #283's bounded 81-probe semantics agree with current main. Its strict
empty-route census cannot establish the need for rearrangement: production
already traverses movable material. The local fixture independently establishes
current no-target behavior; it does not qualify tree detachment or the archive's
asynchronous proportions. Stage A is committed before Stage B implementation.

### File-only replay correction

Stage-A checkpoint `838b2a9df6bde37a902b588f0984161b2a78a22f`, tree
`d229acb59ec1fd5ac1f81a790c57ecaf8c2ff036`, retained the corpus. Its separate
file-only replay exposed strict Godot Array equality comparing parsed floating
coordinates against native integer coordinates. Native validation/hash checks
passed, while the harness comparisons failed. The correction compares exact
finite integral values and reasons without numeric tolerance, and increments
matches only after all comparisons pass. Corrected file-only replay passes
80/80 with zero mutations. The corpus/native source/DLL are unchanged. This
failure is a harness serialization-comparison defect, not discarded physical
evidence; both outcomes remain in the Stage-A receipt.

## Toolchain inspection and initial repository gates

Read-only inspection found Godot
`C:/Godot47/Godot_v4.7-stable_win64_console.exe`, the pinned godot-cpp source
under `C:/Users/_/lcb-local-toolchain/env/`, and LLVM-MinGW 20260826 under the
same toolchain root. Compiler readback reports Clang 23.1.0; its isolated Python
environment reports SCons 4.10.1. `python tools/verify_pinned_source_tree.py verify
<godot-cpp-root>` passed. The revision, archive marker and source ledger match
the repository's pins. The available Windows godot-cpp static library has
SHA-256 `2629ba35adc7b1263deeb1155d674252e1e4188c2c89d1d7158e816d18f957df`.
It is a local build, not the historical M11 byte-identical archive. These are
dependency/source checks, not qualification of a rebuilt investigation runtime.
The repository's `tools/build_native_extension_windows.sh` can target an
isolated output using `CYBERSAND_NATIVE_OUTPUT`; shared prior build outputs
must not become this investigation's source identity.

Initial checks at the frozen baseline retained an existing documentation and
repository failure: six missing companion-workspace references in this isolated
source layout. Historical `python tools/ci/check_m11_consistency.py` passed;
historical hashes remain unchanged. The frozen retrieval evaluation reported
19/32 hit@1, 32/32 hit@5 and MRR 0.7536. These initial outcomes are baseline
evidence, not final-head results; final checkpoint commands and exact outcomes
must be recorded separately. Companion workspace recovery and unrelated link
repairs are outside this bounded physical investigation.

## Documentation obligation map

| Canonical destination | Checkpoint obligation or unchanged boundary |
|---|---|
| [Coupling contract](../architecture/rigid-body-and-cellular-coupling.md) | Add the diagnostic replay route and its source-qualified scope; keep 81-candidate runtime semantics and unresolved material retention explicit |
| [Ownership/lifetimes](../architecture/data-ownership-and-lifetimes.md) | Capsules own immutable copied local state; native World and main-thread Rapier ownership remain unchanged |
| [Interfaces](../reference/interfaces-and-message-contracts.md) | Document the opt-in diagnostic capsule/fencing surface and explicit bounds; preserve ordinary body packet/result semantics |
| [Invariants](../reference/invariants.md) | Retain hard/foreign-body barriers, authoritative tuple and quantity conservation; oracle assertions concern copied state only |
| [Configuration](../reference/configuration-reference.md) | Record capture capacity and replay footprint if exposed; no production search-radius change |
| [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md) | Runtime coupling design unchanged; diagnostics and test oracles do not select a successor production primitive |
| [Roadmap](../reference/status-and-roadmap.md) | Link the dated A/B/C evidence with pending/completed claims separated; broad granular acceptance remains separate |
| [Build/tests](../operations/local-build-and-validation.md) | Add focused replay, topology and oracle commands with source/runtime identities and execution limits |
| [Index](../README.md), [retrieval routes](../reference/retrieval-index.md) and manifest/questions | Register this evidence and affected question routes without creating duplicate canonical ownership |
| User controls and rendering | No ordinary controls, render publication, solver laws or pacing behavior changed |

## Stage B — frozen topology and normal diagnosis

Stage B consumes the immutable Stage-A corpus from `838b2a9d`; file-only replay
was corrected and qualified at `5683acf8`. The graph interior is the AABB of the
source and all81 production endpoint cells, excluding the one-cell captured
outer ring. This deliberately declared geometric overapproximation includes
cells the directional enumeration cannot inspect. Every void records whether
it is actually enumerated, its vector/distances/dot/angle and reachability.
Four-connected costs exclude the source and charge one per intervening movable
cell. Own-body occupancy is traversable only in the permissive diagnostic graph;
this cannot establish an admissible matter move. Strict routes require empty,
unmasked cells after the source. Hard, foreign and immovable cells are barriers.

| Minimum intermediate movable cells | Unresolved contacts |
|---|---:|
| 0 | 2 |
| 1 | 1 |
| 2 | 0 |
| 3 | 6 |
| 4+ | 8 |
| Unreachable | 47 |

All64 failures lack a strict route. Seventeen have a permissive route to an
interior void:15 lowest-cost voids are lateral (45–135 degrees), two are rear;
none are forward (at most45 degrees). Only1/64 has a forward/lateral route of
cost1 or2; that case also has nonnegative dot. Zero failures have an unmasked
empty endpoint in the actual81-probe enumeration. All47 unreachable cases lack
any interior void; none is a case of an existing interior void separated by
hard/foreign/immovable material. Of those47,22 have a void in the diagnostic
ring,21 can reach a ring void permissively, and25 lack even a ring void. These
bounds diagnose local saturation/edge truncation, not global jamming or a
justification to widen the runtime search.

All64 failures use overlap-face normals (31 positive-x,33 positive-y).
Independent reduction finds positive agreement with translation (cosine
0.629–0.779, median0.765) and radial direction (0.0649–0.99998, median0.931).
The selected interior voids are lateral or rear, but there is no general reversed
normal defect. A normal correction could redirect enumeration only for a subset;
it cannot manufacture missing local void volume. Exact per-capsule graph, void
and normal results are in the
[Stage-B machine report](physical-detachment-2026-10-31/stage-b-topology.json).
Two separately written reductions agree on every failed capsule's minimum cost,
selected sector and interior void count. The analyzer also differentially
reproduces all80 production traces with explicit Godot float32 operations.

The dominant bounded missing resource in this fixture is **local free volume**;
there is a small lateral rearrangement subset. Broad compaction or global jamming
is not established by this finite envelope. Stage C must test legal copied-state
chains separately, particularly own-body masks and displacement direction.

Stage-B qualification: ten focused graph/geometry/barrier/nonmutation tests pass
on Windows Python3.13 and Linux/WSL Python3; discrete costs, routes, coordinates, sectors and aggregate distributions agree.
The full reports differ in61 angle values by at most2.842170943040401e-14
degrees across host math libraries; the receipt correctly records full-report
inequality. A first synthetic45-degree sector boundary failed because
acos rounded to45.00000000000001 degrees; a1e-10-degree diagnostic sector
tolerance corrects that classification without altering search or graph costs.
The [Stage-B receipt](physical-detachment-2026-10-31/stage-b-receipt.json) retains
commands, hashes and this failure. Stage B was committed as `f18e1378897ee42b8ad519debb3a18c25160d5bf` before Stage C began.

## Stage C — bounded conservative push-chain oracle

The [pure oracle](../../tools/experiments/ejection_push_chain.py) works only on
copied local state. It enumerates simple four-connected chains within the same
Stage-B interior AABB, with moved-cell caps1,2,3,4 **including the source**.
Every destination must be unmasked, including by the source body; every moved
parcel is nonempty, movable and non-hard. The terminal is unmasked Empty.
Tail-first application preserves each moved nonempty parcel's complete raw
carrier bits (including spare/epoch), state, quantity and persistent temperature.
Body masks remain positional. The vacated source becomes Empty at ambient
temperature, matching the semantic vacancy rule; terminal Empty temperature is
not asserted conserved. Production relocation itself resets scheduling epochs.

The policies use exact per-hop projection: forward requires `dot > 0`;
forward plus lateral requires `dot >= 0`. No rearward hop or epsilon is admitted.
These literal hemispheres differ only at the lateral boundary. All80 retained
normals have both components nonzero, so a four-connected grid has no exactly
lateral axis hop and the policies coincide here. An axis-aligned synthetic
lateral fixture distinguishes them. This zero marginal does not establish that
all geometrically lateral motion is useless under a different declared policy.

| Cumulative accepted contact states | Forward | Forward plus lateral |
|---|---:|---:|
| Production direct | 16/80 | 16/80 |
| Direct or chain at most1 | 16/80 | 16/80 |
| Direct or chain at most2 | 16/80 | 16/80 |
| Direct or chain at most3 | 16/80 | 16/80 |
| Direct or chain at most4 | 16/80 | 16/80 |

**Zero of64 unresolved contacts is recovered at every cap under both policies.**
At cap4,47 lack any local terminal void and17 have voids but no legal chain
under these directional/mask/cap constraints. Graph-cost0 is not a physical
chain proof: the permissive graph can traverse masked Empty space. Five of the
16 production-positive controls admit legal chains by cap4; their chain-only
cumulative counts are0,1,2,5. They are positive validation, not new recovery.
The [per-capsule oracle report](physical-detachment-2026-10-31/stage-c-oracle.json)
records paths, minimum lengths, terminal geometry, moved material sequences,
multiple-path counts and exact refusal/frontier reasons for every cap/policy.

Fifteen adversarial/conservation Python tests pass. Sand, Water with custom
quantity/state/temperature/spare bits, mixed materials, hard/foreign/own masks,
masked Empty terminals, ring terminals, missing voids, cap overflow, rear-only
escape, exact lateral policy, overlapping candidate paths and frozen-input CLI
alias protection are covered. There are zero conservation failures, hard/foreign
violations or newly created overlaps. The selected real copied applications
number16 across policy/cap combinations; a separately written read-only
enumerator checks all20 real legal paths with zero postcondition failures.
All live capsules are Sand. Water/mixed evidence is conservation/control
qualification, not measured live liquid recoverability.

A fresh native copied-World validator independently imports semantic tuples and
temperature, installs positional masks, applies the selected chain tail first,
and verifies material/state/temperature multisets, exact Water quantity,
source vacancy and one fewer material/body overlap. It checks50 exported cases
(16 real positive applications and34 synthetic applications) plus21 native
controls. Its public setters cannot import arbitrary captured epoch/spare bits;
that raw-bit qualification remains in the pure copied-state tests. It never
accesses the real captured simulation World. The first21st-control attempt
failed before application because a test-fixture cell copy changed its coordinate
key; the corrected control preserves that negative result and is requalified.

## Interpretation and next engineering checkpoint

This retained current-main cohort gives **NO-GO for promoting a tiny push chain**.
It recovers0/64 failures. Production already crosses movable material to an
empty endpoint, and all16 successful controls also lack a strict empty route.
Neither the historical strict-route census nor this bounded graph licenses a
wider search, normal correction or production rearrangement by itself.

The strongest supported hypothesis is insufficient admissible local free volume
combined with the body/contact response, with a smaller lateral topology subset.
The normals are not generally reversed;47/64 failures have no void in the local
envelope and25 lack even a diagnostic-ring void. This does not prove global
jamming or select a broad compaction algorithm.

The next production-facing experiment should target generic granular contact/
bearing response under local saturation: test whether a body can stop or deflect
before accumulating deep unresolved material overlap, using the existing plunge/
excavation controls and explicit free-volume variants. Establish trajectory and
conservation evidence before selecting a runtime primitive. Expand fixture
coverage separately to swept-only contacts, other body shapes and materials;
this Sand rectangle cohort cannot qualify frozen tree detachment or all liquids.

Do not pursue B=289 as a primary approach, treat strict-empty-route absence as
causal proof, promote this four-cell chain, or label bounded saturation global
jamming. Source semantics/render publication/material laws remain unchanged;
the investigation branch stays draft and unmerged. Cross-branch reconciliation
is deferred to a later integration pass from the frozen-main boundary.

The [Stage-C source/command receipt](physical-detachment-2026-10-31/stage-c-receipt.json)
records corrected Windows and Linux21+50 copied-World passes and the preserved
failed fixture attempt. Production native inputs and DLL remain identical to
the qualified Stage-A build; later changes add offline tools/tests/documentation.
