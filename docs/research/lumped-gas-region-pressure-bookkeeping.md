---
title: Lumped gas-region pressure bookkeeping feasibility
document-kind: reference
canonical-for: [lumped-gas-region-pressure-bookkeeping-research]
status: Planned
scope: WEX-003 research result for optional connected-gas-region pressure bookkeeping; no production atmosphere solver, Water head solver or runtime adoption
last-reviewed: 2026-09-20
related-documents: [../operations/water-hybrid-pressure-extension-programme.md, ../systems/smoke-heat-pressure-roadmap.md, ../systems/water-design.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/simulation-tick-and-threading.md, ../decisions/ADR-008-bounded-approximate-fidelity.md]
---

# Lumped gas-region pressure bookkeeping feasibility

## Disposition

**WEX-003 result: technically promising for a bounded optional/research feature,
but not adopted as production architecture.** CyberSand can plausibly represent
sealed-compartment pressure without a per-cell gas pressure/velocity field by
combining local exact gas-space topology summaries with a sparse region/portal
graph and an authoritative region amount/volume ledger.

The preferred research direction is:

1. recompute exact gas connectivity only inside geometry-dirty local macrocells;
2. connect those local components through a sparse graph and explicit narrow
   opening/portal records;
3. treat openings/additions as cheap graph additions/region merges;
4. treat closures/deletions as potentially expensive splits, reconstructed lazily
   and only for the affected component;
5. keep gas amount and free volume authoritative enough that pressure is derived,
   not stored as a lone byte;
6. invalidate unresolved topology rather than returning stale pressure.

This result **admits #94 only as a bounded non-production decompression-event
proof**. It does not admit a production atmosphere system, general gas CFD,
Water-head transmission, Smoke replacement, save-schema migration or new
authoritative runtime field.

No executable proof is added by #93. A standalone toy would only re-demonstrate
the ideal-gas ratio and graph flood/union mechanics while failing to answer the
material question: the cost of maintaining topology under CyberSand's actual
geometry churn. Touching World/Stage-3B source merely to obtain that toy evidence
would create unnecessary ownership overlap. The architecture and worst-case
bounds below are sufficient to decide whether the separately scoped #94 proof is
worth running.

## Source and ownership reconciliation

Research was reconciled against authoritative `main`
`3fa6728d6a6fbadbe19111102bf292648782b04c`, which includes WEX-001 through
PR #102. WEX-001 retained both useful generic body-to-Water displacement and the
hard-floor Water-ejection defect without changing coupling semantics.

At the #93 branch point:

- #101 / Stage 3B remained active on sparse coverage witnesses;
- no active branch or PR owned an atmosphere, room-pressure or equivalent
  gas-region implementation;
- #49 retained sole ownership of successor Water apparatus;
- #45 retained the saturated-Water-head architecture question and remained
  implementation-gated;
- #12/Stage 3B retained production dynamic-connectivity/discovery ownership.

Accordingly #93 stays in research/RAG surfaces. The topology design may later reuse
generic #12 graph/index lessons only after an explicit production owner decides
that reuse; this document does not take over those structures.

## External modeling principles used

External systems are used only for modeling ideas, not as evidence that a CyberSand
implementation will be cheap.

- NIST's CFAST technical reference describes compartment/zone control volumes with
  state represented through quantities including mass, volume/density, temperature
  and pressure related by an ideal-gas equation. Borrowed principle: a game-engine
  compartment can derive pressure from an authoritative amount and free volume
  instead of carrying a per-cell pressure field. Accessed 2026-09-20:
  [NIST CFAST technical reference](https://www.nist.gov/publications/cfast-consolidated-model-fire-growth-and-smoke-transport-version-6-technical-reference).
  CyberSand does **not** adopt CFAST's fire, plume, layer or thermal models.
- Tarjan's disjoint-set treatment supplies the standard algorithmic asymmetry for
  incremental connectivity: set creation/find/union handles additions cheaply,
  while deletion/split is not the same operation and needs separate reconstruction.
  Borrowed principle: optimize openings/merges independently from closures/splits.
  Accessed 2026-09-20:
  [Data Structures and Network Algorithms, Chapter 2](https://doi.org/10.1137/1.9781611970265.ch2).

The isothermal relation below is therefore a deliberately small feasibility model,
not a thermodynamics claim.

## Required authoritative state

A resolved finite gas region needs enough state to survive compression, merge,
split and identity reuse:

| State | Purpose |
|---|---|
| stable region slot plus generation | Reject stale users after slot reuse |
| topology revision | Reject stale portals/events/queries after geometry edits |
| free gas volume `V` | Denominator for pressure and split accounting |
| gas amount `A` | Conserved finite-region quantity; fixed-point integer is preferred |
| boundary mode/reference | Sealed, atmosphere-coupled, vacuum-coupled, or another finite region |
| bounded portal adjacency | Openings, vents and narrow connections without whole-room scans |
| resolution state | Resolved, split-dirty/rebuilding, refused/unavailable |
| optional derived pressure cache | Presentation/query acceleration only; never sole authority |

For a minimal fixed-temperature model:

```text
P_abs = K * A / V
```

where `A` is an engine-defined fixed-point gas amount, `V > 0` is exact free
volume in declared cell/subcell units, and `K` absorbs the selected reference
temperature/unit scale. Initialization against a reference pressure can set
`A = P_ref * V / K`. Absolute pressure is clamped/represented at or above zero;
negative gauge values may be derived relative to a reference but are not
authoritative absolute pressure.

A one-byte pressure cache is acceptable only after the amount/volume calculation.
It cannot preserve information through arbitrary merge/split/compression by itself.

## Maintaining free volume without room scans

The proposed hierarchy uses small **local topology macrocells**, not a single
coarse occupied/free bit.

On a geometry-dirty macrocell, perform an exact bounded flood over that macrocell's
gas cells and emit:

- exact free-cell/free-volume count;
- one or more local gas components;
- boundary contact spans/ports for each component;
- explicit semantic openings such as authored vents/doors when needed.

Neighbouring local components are connected by matching boundary contacts or
explicit portal metadata. A narrow one-cell opening therefore survives even when
the surrounding macrocell is mostly solid. Destructive breaches can be derived
from the same exact dirty-local scan; they do not require every narrow opening to
have been authored in advance.

For a resolved region, ordinary occupancy changes update free volume by local
delta. A room-wide count is unnecessary. The edit is classified separately as
volume-only or topology-affecting.

### Edit classification

| World change | Required bookkeeping |
|---|---|
| Cell becomes occupied/free but local gas connectivity is unchanged | Apply `delta V`; pressure derives from new volume |
| New connection appears | Add graph edge/portal; merge connected finite regions or attach boundary |
| Existing connection closes | Mark affected region split-dirty; rebuild only that component |
| Atmosphere/vacuum vent opens/closes | Change boundary edge and topology revision |
| Water/free surface moves without opening/closing a passage | Volume/accounting delta only |
| Water/solid movement blocks or opens a passage | Topology edit plus volume delta |
| Authored room/portal metadata changes | Invalidate affected seed/portal and rebuild from live geometry |

This classification is important: changing pressure through compression must not
force a connectivity rebuild, and a topology edit must not be hidden as a mere
volume delta.

## Merge, split and exact amount accounting

### Opening / finite-region merge

For two sealed finite regions that are intentionally approximated as immediately
mixed after an opening:

```text
A_new = A_1 + A_2
V_new = V_1 + V_2
P_new = K * A_new / V_new
```

The merge is cheap once the connecting edge is known. The surviving identity is a
policy choice; stale callers are protected by generation/topology revision.

If a later decompression proof needs a finite transient pressure difference,
#94 should snapshot the **resolved pre-open** source/destination region tokens,
pressures and finite budget at the opening transition before #93-style immediate
mixing/relaxation destroys that differential. #93 does not implement that event.

### Closure / split

A closure first invalidates the old region as authoritative. Reconstruct connected
children over the affected region graph only. A split is not complete when new IDs
exist; gas amount must also be divided.

For an isothermal well-mixed parent immediately before closure, a conservative
approximation is to preserve its density/pressure in each child:

```text
A_i = A_parent * V_i / sum(V_children)
```

Use fixed-point/integer division plus deterministic remainder assignment in stable
child order so that:

```text
sum(A_i) = A_parent
```

If insertion of the closing geometry itself consumes free volume, apply that
declared compression/volume delta while the pre-split region is still connected,
then partition the remaining amount across the reconstructed child volumes. This
avoids silently deleting the gas formerly occupying the new solid.

A model with materially different pre-closure composition/temperature would need
more state and is outside WEX-003.

## Atmosphere, vents and vacuum

Atmosphere and vacuum should be **boundary reservoirs**, not ordinary finite region
records pretending to contain a huge amount.

- atmosphere: configured positive absolute reference pressure;
- vacuum/exterior: approximately zero absolute pressure;
- finite sealed region: amount is conserved except for explicit boundary exchange;
- vented region: pressure may be pinned to, or boundedly relaxed toward, the
  selected reservoir according to a later admitted runtime policy.

Any relaxation changes finite-region amount and therefore requires an explicit
source/sink ledger. Merely relabeling a sealed region as atmospheric without
accounting would destroy the meaning of `A`.

#94 may use the pre-relaxation pressure differential as an event input. Negative
absolute pressure is never required.

## Authored rooms and narrow openings

Level-authored room IDs can accelerate startup by supplying seeds or expected
static partitions. They are **hints, never stale truth**. A geometry edit touching
their covered topology invalidates the corresponding revision and causes local
reconstruction before a pressure query can become authoritative again.

Narrow doors, vents and breaches are protected in two ways:

1. exact local macrocell connectivity emits boundary contacts from current cells;
2. explicit portal metadata represents semantic openings whose effective area or
   gameplay meaning cannot be recovered reliably from a coarse summary alone.

A portal record must carry its own identity/generation and endpoint revisions.
Closing or destroying either endpoint invalidates it.

## Candidate topology alternatives

| Alternative | Strength | Failure/cost mode | WEX-003 disposition |
|---|---|---|---|
| Exact whole gas-space component reconstruction on demand | Simple and exact at cell resolution | Split can scan a very large room in cells; poor churn bound | Reference/fallback only |
| One coarse occupancy node per macrocell | Very small graph/memory | Erases narrow gaps and can invent connectivity | Reject alone |
| Exact local macrocell components + lazy global graph | Local edits are bounded; global work scales with affected topology | Pathological local component/edge counts still need caps | Preferred backbone |
| Explicit portal/opening metadata | Preserves doors/vents/breaches and effective area | Metadata/invalidation complexity; not sufficient for arbitrary destruction alone | Preferred complement |
| Pre-authored room seeds | Cheap static startup | Becomes wrong after edits if treated as authority | Hint only, with mandatory invalidation |
| Fully dynamic general graph algorithm | Strong asymptotic deletion guarantees are possible in theory | Complexity and implementation risk are disproportionate to current evidence | Defer unless measured churn requires it |

The preferred candidate is therefore **exact dirty-local topology + sparse
macro-component graph + explicit semantic portals + optional authored seeds**,
with affected-component reconstruction on deletion.

## Complexity and illustrative memory budget

These are design estimates, not measured CyberSand runtime results.

Let:

- `N` = world cells covered by the optional gas system;
- `s` = macrocell side length;
- `M ~= N / s^2` = macrocell count;
- `R` = live finite gas regions;
- `P` = live portal/opening records;
- `m_r, e_r` = local-component nodes/edges in an affected region.

Expected operations:

| Operation | Work |
|---|---|
| pressure query on resolved token | O(1) |
| volume-only edit | O(1) after local classification |
| dirty macrocell local rebuild | O(s^2) |
| opening/edge insertion | near-constant plus union/adjacency work |
| finite-region amount/volume merge | O(1) plus bounded adjacency bookkeeping |
| possible split | O(m_r + e_r) affected graph reconstruction |
| exact-cell fallback split | O(c_r) cells in affected component |

A single world-spanning room remains the adversarial case: its closure can make
`m_r + e_r` approach the covered world graph. Laziness changes when that cost is
paid; it does **not** remove the worst case. A production design therefore needs a
per-tick reconstruction budget and an explicit unresolved result.

Illustrative packing only:

- 8x8 macrocells: about 15,625 macrocells per million covered cells;
- 16 bytes of fixed summary per macrocell would be about 244 KiB per million cells,
  before variable local-component/contact storage;
- 64 bytes per region gives about 64 KiB for 1,024 regions;
- 32 bytes per portal gives about 128 KiB for 4,096 portals.

Those byte sizes are budgeting examples, not selected layouts. Checkerboard-like
geometry can create many local components/contacts; variable storage therefore
needs explicit per-macrocell/global caps and high-water counters.

Because no #93 executable harness is justified, p50/p95/p99 timing, observed
capacity high-water and real churn distributions are **not measured here**.
They are mandatory before production adoption.

## Lazy/off-camera semantics

Off-camera or low-interest topology may remain split-dirty without consuming
immediate reconstruction work, but only under a strict truth rule:

- stale assignments are not pressure authority;
- a query may perform bounded catch-up if budget permits;
- otherwise the query returns `unavailable/unresolved`;
- optional callers may explicitly fall back to their pre-feature boundary
  condition, normally configured atmosphere;
- pressure-driven effects and #94 events must not launch from unresolved tokens.

This makes latency visible instead of converting deferred work into silently wrong
pressure.

## Capacity, refusal and failure

A future implementation must bound at least:

- region slots;
- portal records;
- local component/contact records;
- dirty-split queue;
- reconstruction scratch;
- reconstruction work per tick.

On exhaustion or budget overrun, mark the affected topology unresolved and retain
the underlying world state. Do not drop gas amount, fabricate a merge, reuse a
stale pressure, or run an unbounded emergency world scan.

Generation/revision mismatch is a normal stale-reference failure, not permission to
look up the new occupant of a reused slot.

## Water query boundary

Water needs only a read-only boundary-condition query, conceptually:

```text
surface_pressure(region_token) -> resolved absolute pressure | unavailable
```

The query must not expose mutable gas-region storage. Water continues to own all
Water mass, movement and any future saturated-head mechanism. A gas region never
pushes Water cells merely because it has pressure state.

Thus:

- both reservoirs vented to the same atmosphere -> same surface boundary pressure;
- separately sealed headspaces -> potentially different surface pressures;
- neither case tells Water how to transmit hydraulic head through saturated cells.

#45 remains the owner of that separate architecture question.

## Explicit answers to the WEX-003 questions

1. **State required:** stable identity/generation, topology revision, free volume,
   conserved/owned gas amount, boundary relation, bounded adjacency, resolution
   state; pressure can be derived/cached.
2. **Free volume without room scans:** exact local free-volume summaries plus
   mutation deltas; rebuild only dirty macrocells.
3. **Topology versus accounting dirtiness:** connectivity-changing openings,
   closures and boundary changes dirty topology; compression/occupancy changes that
   preserve connectivity change volume only.
4. **Cheap openings / lazy closures:** yes. Insert/union is cheap; deletion marks
   the affected component unresolved until bounded split reconstruction completes.
5. **Atmosphere/vents/vacuum:** immutable boundary reservoirs with explicit exchange
   semantics; vacuum approaches zero absolute pressure.
6. **Authored room IDs:** useful as seeds only; live geometry revision invalidates
   them before authoritative use.
7. **Narrow openings:** exact local component/contact extraction plus explicit
   semantic portal metadata where needed.
8. **Worst-case split:** linear in the affected region graph, or affected cells for
   exact fallback; one giant room can still approach whole-covered-world work.
9. **Capacity/refusal:** fixed capacities/work budgets; unresolved/unavailable on
   exhaustion, with no stale pressure or silent amount loss.
10. **Water interface:** read-only resolved surface pressure only; gas does not own
    Water transport/head simulation.

## What a later production proof must measure

Before any production admission, measure on actual CyberSand geometry mutation:

- macrocells/local components/regions/portals and bytes by category;
- local dirty area per tick;
- merge counts/cost;
- split reconstruction node/edge/cell visits;
- p50/p95/p99/max split and topology maintenance cost when sample counts support it;
- unresolved latency under off-camera/budgeted work;
- avoided full-world work;
- capacity high-water/refusal;
- generation/revision churn;
- the one-large-room adversarial case;
- deterministic repeat and relevant worker parity.

A docs-only #93 result makes no claim that those measurements already pass.

## WEX-004 disposition

**ADMIT #94 as a bounded research proof.**

Admission conditions:

- consume only resolved #93-style region/boundary data;
- snapshot source/destination pressure, opening generation and a finite shared
  source budget before any immediate region merge/relaxation;
- cancel on stale topology/generation;
- keep event work local, capacity-bounded and explicitly accounted;
- do not interpret the admission as production atmosphere adoption;
- retain a no-go result if credible obstacle-aware behavior requires general gas CFD.

The admission is justified because #93 identifies a coherent low-state pressure
source and explicit stale/failure semantics that #94 can consume without requiring
per-cell gas pressure. #94 remains responsible for proving whether the resulting
impulse approximation is physically/gameplay-useful enough to retain.

## Limitations and unresolved questions

- No executable topology maintenance or timing evidence was produced.
- Macrocell size, storage layout, portal capacity, reconstruction budget and update
  cadence are intentionally unselected.
- Gas composition, temperature, combustion, humidity and stratification are absent.
- Instant finite-region mixing is an approximation; #94 must not pretend it
  reproduces transient gas flow.
- Fast moving geometry may keep topology unresolved frequently enough to make the
  feature unattractive; only an integrated measured proof can answer that.
- Persistence/replay schema is deliberately not designed here.
- Reuse of Stage-3B graph/index machinery is a future ownership decision, not an
  implication of similar terminology.

These gaps prevent production adoption, but they do not block the narrower #94
research question.
