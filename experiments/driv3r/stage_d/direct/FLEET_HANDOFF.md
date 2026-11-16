# D-1A four-stream matched controls — source-bound handoff v2

**Status:** Draft/HOLD · offline DEVELOPMENT only · **no model or native dispatch**.
Owner-accepted immutable M1: `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`;
schema SHA-256 `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d`.
See [issue #570](https://github.com/techrote/cybersand/issues/570),
[owner roadmap](https://github.com/techrote/cybersand/issues/570#issuecomment-6877408001),
[D-1A Draft PR #595](https://github.com/techrote/cybersand/pull/595).

The purpose of the **strong A*/contour oracle** is a conventional reference, **not**
to turn the owner's slightly deranged drawing worm into a shortest-path solver.
Report intentional oddness, changes of direction, revisits, unusual line shapes,
STOP and recovery separately from arrival/offset adherence; do not call
shorter paths better art.

## Four distinct synthetic control streams

| Wrangler slot (NOT an active worker lease) | Requested future model family (NOT loaded) | Frozen DEVELOPMENT fixture | Seed |
| --- | --- | --- | ---: |
| `d1a-wrangler-01` | d1-2B-Q4 | `wall_step_v1` | 103 |
| `d1a-wrangler-02` | LFM2.5-350M | `route_gate_v1` | 211 |
| `d1a-wrangler-03` | Sprocket-500M | `wall_recess_v1` | 307 |
| `d1a-wrangler-04` | SmolLM2-135M | `route_hook_v1` | 401 |

Every slot has a deterministic **synthetic run identifier** calculated from
`(version, slot_index, wrangler_id, fixture_id, exact fixture SHA-256, seed)`.
All *real* inference identifiers—checkpoint SHA, GitHub run/job, PID, native
World SHA and native receipt artifact—remain **null**. These four entries do
not constitute four resident models or four native episodes.

The v2 handoff additionally records source-hashed **descriptive line character**
for each controller: turns, reversals, closed-loop contacts, reused edges,
heading entropy and longest straight segment, plus a full fingerprint digest.
These are measurements of **synthetic brush-up cursor paths**, not evidence
of material ink, artistic quality, model intent or native execution. Missing
policy arms after oracle resource exhaustion have **no** invented fingerprints.

Each slot replays three **matched initial-state, matched legal-menu** offline
controllers at the same seed and 1/2/4/8-cell macro menu:
`astar_or_contour`, the original uniform `random_legal` (STOP permitted),
and the separately versioned movement-complete
`random_legal_persistent_v1`. None are a substitute for a future genuine
neural controller. After different selections, subsequent host menus belong to
different simulated states and are never silently treated as matched.

## Matched episode identity and four-cohort comparability

The planned-slot `synthetic_run_id` remains the stable four-wrangler **recipe
identity**, not evidence that a particular episode ran. New
`episode_run_id` binds each actually computed synthetic report to that recipe,
**decision horizon (36 vs 128), predecessor-probe cap, and SHA-256 of the
executed fleet, oracle, offline geometry and line-character Python modules**.
A 36-decision outcome, a separate 128-decision outcome and a changed resource
cap cannot silently reuse the same episode ID; resource-exhausted reports
also preserve their own episode/source identities without inventing oracle
costs or policy trajectories.

The compact Commander/Ethologist comparison now refuses a four-slot cohort
with mixed horizons or oracle-probe limits; reports remain four distinct
synthetic run records and retain every negative result. The original fixture
hashes, STOP-inclusive random control, baseline trajectories, 64 native
logical-move ceiling and M1 schema are unchanged. This is source-level
preparation, **not proof that the 128 mode finished on a hosted CPU**.

## Exact negative-case oracle accounting

The v3 four-stream control report now records **attempted predecessor probes
even when the oracle exhausts its CPU cap**. A failure at cap N occurs on
counted probe N+1; the report preserves attempted cost, cap, oracle version
and source, explicit resource-failure type, and null (UNKNOWN) reachability
and optimal cost. The Commander/Ethologist handoff retains these fields
for all four negative cases; source replay rejects a falsified count.
These are synthetic CPU-work units, not wall-clock duration, native session
cost or model-inference bills. No controller trajectories are fabricated.

## Separate 36- and 128-decision research boundaries

The original 36-decision fixtures, structural split, SHA-256s, failed/early
STOP traces and all prior baseline outcomes remain unchanged. The **128-turn
mode is an explicitly synthetic overlay** which preserves those source
fixtures while extending only the in-memory control loop, **after**
`budget_oracle.bounded_optimal_route` completes against the exact selected
geometry within a default **3,000,000-predecessor-probe** CPU cap. The actual
probe count, cap, exact oracle objective/cost and source module SHA-256s are
recorded. Resource exhaustion is an explicit negative
`ORACLE_RESOURCE_EXHAUSTED` **without any policy rollouts**; it is not called
unreachable. Runtime resource use is bounded by 128 decisions, the 8-cell
macro maximum, hard swept-cell legality and the oracle probe ceiling.
The CLI's output is a replay-verified summary, not a native campaign receipt.

**Crucial distinction:** the actual M3 host retains **64 logical moves** and
the separately documented #611 native drawing worm retains its own
36-decision/ink/recovery limits. This module does not lift either limit, change
paint semantics, establish longer native sessions or grant any model access.
The D-1A cursor-only/brush-up path is not equivalent to M3 material-58
brush-down painting. Commander/Body Lab must qualify a **separate exact native
host/PAINT adaptation** before considering a real 128-turn fleet.

## Run and qualify

From a **clean exact-head repository checkout** (immutable M1 ancestor),
all-stdlib offline only:

```bash
python3 -m experiments.driv3r.stage_d.direct.qualification
python3 -m experiments.driv3r.stage_d.direct.fleet_controls --horizon 36 --output /tmp/d1a-four-stream-36.json
python3 -m experiments.driv3r.stage_d.direct.fleet_controls --horizon 128 --oracle-probe-cap 3000000 --output /tmp/d1a-four-stream-128.json
```

The CLI invokes `qualification.source_fence` and fails on dirty or
out-of-lane source. A **128 resource-cap failure exits nonzero**, preserving
negative cases in the written JSON rather than declaring success. Existing
`qualification` still must execute **all 193 authored source tests/18 modules** on the
committed checkout; Stage A/doc/source-scope green is not that evidence.
Do not report these runs as completed until exact source, stdout/stderr,
first-pass failures, Git commit and test footer have been collected.

## Commander and Ethologist consumption contract

Each handoff has four ordered wrangler slots, four actual *synthetic* cohort
records (or explicit negative resource records), a distinct SHA-derived
synthetic run ID, source-pinned fixture/seed, 36/128 horizon, exact
oracle probe count and cost **only when computed**, metrics for every arm
including false STOP, retracing and missed arrival, full candidate/sweep
identity and provenance flags `native_qualified=false`,
`sequential_native_receipts=0`, `model_outcome=null`. Archive the
**unabridged three-arm records** if executed; the compact summary is only a
handoff, not a substitute for per-step evidence.

Commander must supply *real* unique model checkpoint, native-vs-synthetic,
lease, GitHub run/job, loaded PID, World/material and receipt identities to
qualify any later live streams. Ethologist should evaluate line character
without conflating synthetic controls, held-out cases and actual native
material-generated images. **No held-out behavioral outcomes are opened**
here; only four existing DEVELOPMENT families are replayable.

This research handoff deliberately avoids a new GitHub Action or changes
outside `experiments/driv3r/stage_d/direct/**`. No inference, training,
paid/GPU work, formal A/B dispatch, Ready promotion or merge is requested.
