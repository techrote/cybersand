# D-1A long-horizon direct-drive research — offline foundation

**Status:** independent **development-only** preparatory fixtures and oracle policies, not native or model qualification. #570; [owner D roadmap](https://github.com/techrote/cybersand/issues/570#issuecomment-6877408001). The five-record [D-COMMON-001 contract](https://github.com/techrote/cybersand/pull/594) received **M1 owner acceptance on 14 Nov 2026** at source commit `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`, schema SHA-256 `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d` ([#570 freeze record](https://github.com/techrote/cybersand/issues/570#issuecomment-6881686675)). **M2 offline integration preparation is permitted; native/model experiments, merges and formal A1/A2/A3 comparisons are not.**

## Exact remaining-decision horizon (M2 offline diagnostic, 15 November 2026)

**New lane-only source:** `horizon.py` and `test_horizon.py`, version
`d1a-offline-decision-horizon/1`. For a frozen DEVELOPMENT trajectory, reverse
breadth-first search computes the *exact minimum remaining cardinal action
decisions* from every reachable cursor to the goal under the same host-like
full-sweep legal macro menu (1 / 2 / 4 / 8). This is stronger than dividing
the A* cell distance by maximum action length: full swept cells may hit
material Z, protected cells, walls or World bounds. Legal straight macros
are reversible in this synthetic grid, so one reverse search yields exact
distance-to-go in *decisions* for every original cursor.

The source-replay-verified analysis records initial budget feasibility,
pre/post-choice slack against the 36-decision cap, the first point at which
even an optimal *future* geometric continuation has insufficient decisions,
and whether an original STOP is terminal and non-resumable. It **does not**
restart the trace, repair a failed first pass, evaluate held-out policy
outcomes, assume that geometric reachability proves good wall-following, or
claim native material edits, native receipts, neural effectiveness or
separate D-1A native campaign authorization.

```sh
python -m unittest experiments.driv3r.stage_d.direct.test_horizon -v
python -m unittest discover -s experiments/driv3r/stage_d/direct -p 'test_*.py' -v
```

**Source-qualified local check:** `horizon.py` Git blob
`d3e4840dcebda17b62bc6bbb84b4f7bd9297d036` and
`test_horizon.py` Git blob
`ac03f6a1c8a7c8927d649b69a8e368fa7f9f79e3` match locally
syntax-compiled/tested bytes. Four pure-helper methods **PASS 4/4**
(unit-vs-macro, obstacle detour, sealed wall, strict candidate admission);
three DEVELOPMENT replay/STOP/held-out methods are authored but **not yet
executed against the complete repository source**. Full lane now has
**87 authored tests**, but an exact-current-HEAD 87-test suite result must
not be claimed; the older 62/62 result is source-stale.

## Target-sweep contact versus terminal arrival (M2 offline diagnostic)

The frozen `d1a-offline/1` score defines **arrival at the end of an admitted action**, not merely touching an endpoint during a 2/4/8-cell macro. A legal random macro can pass through the target and end beyond it. Treating that intermediate swept-cell contact as successful terminal arrival would overstate control quality; ignoring the contact entirely would lose a useful overshoot diagnostic.

The lane-only `target_sweep.py` adds a **supplementary, replay-verified DEVELOPMENT diagnostic** without changing prior fixture source IDs, episode version, action selection or frozen scoring. It reports first target contact (global swept-cell step, decision index, within-macro offset), whether it occurred at the macro endpoint, total target contacts, post-contact movement, and the independently verified terminal-arrival flag. Adverse tests check interior overshoot, true endpoint contact, no contact/STOP, repeated contact, source verification and held-out rejection.

```sh
PYTHONPATH=. python -m unittest experiments.driv3r.stage_d.direct.test_target_sweep -v
PYTHONPATH=. python -m unittest discover -s experiments/driv3r/stage_d/direct -p 'test_*.py' -q
```

**Qualification boundary:** six additional source-tree Python tests are authored, but the exact-head lane suite (now **71 methods**) has **not yet been run**. Four equivalent, manually reconstructed *pure sweep-accounting* smoke cases passed in an isolated Python runtime; this does **not** qualify the committed module or the full suite. No held-out policy results, native receipts, model inference, paid workload, formal A/B or production changes are claimed. Independent M2/M3 review and separate D-1A native campaign authorization remain necessary.


## Verified complete offline lane suite — 14 November 2026

**Source qualification for code head `4c7d0ac5658354eb472f117d6886e15cbbfbec0b`: 62/62 Python unittest methods PASS (1.236 s, Python 3.13.5, isolated local lane-package reconstruction).** All **11 imported Python source files**, including `__init__.py` and five `test_*.py` files, were individually verified against their GitHub **Git blob SHA-1** using `git hash-object` before this final run. The executed suite:

```sh
PYTHONPATH=. python -m unittest discover -s experiments/driv3r/stage_d/direct -p 'test_*.py' -q
# Ran 62 tests in 1.236s — OK
```

The reconstructed workspace contained the GitHub-exact D-1A Python package, **not a full repository clone**; this proves current lane regression behaviour but does not prove GitHub Actions discovery, cross-platform integration, native D-COMMON conformance, material readbacks or 36-decision live execution. Existing earlier statements that a 58-method suite was pending are historical checkpoints, not the current qualification status. No held-out policy outcomes or model predictions were executed.

**Fixed held-out structural custody escape:** the old factories accepted held-out structural families with the caller-supplied `development` label, and `dataclasses.replace(..., split="development")` could bypass the shallow policy-dispatch guard. The factories now refuse family/split mismatches; episode dispatch, independent replay and direct synthetic oracle continuation require a canonical **development fixture ID plus exact source digest**. Four new regression methods reject relabelled or source-mutated fixtures before scoring. Future new geometries require a separately versioned study; all changes remain under `experiments/driv3r/stage_d/direct/**`. This is an offline source-integrity boundary, not a security sandbox for intentionally modified Python source.

**Gates:** owner-accepted M1 source `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6` / schema SHA-256 `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d`; no native D-1A campaign, model API/GPU use, paid inference, formal A1/A2/A3, merge or Ready authorization.

---


## Directional-control integrity (subsequent source change)

The offline M1 preflight adapter **v3** now validates complete declared action semantics: `E/N/S/W` direction and an exact `1/2/4/8` straight swept-cell footprint. Cardinal-adjacent, collision-free geometry alone is insufficient: an `E2` that bends, a `W2` moving east, or an `E1` with two swept cells is rejected. Both synthetic catalog admission and rehashed model-presentation auditing enforce this invariant. Accepted D-COMMON v1 and native action authority remain unchanged.

Two additional adversarial test methods cover admission and post-hash presentation tampering. **The earlier 62/62 full-suite result predates this source revision; current-head execution of the expanded lane suite is still required.** No model/native/held-out campaign was run.

## What is implemented

- Deterministic versioned 36-decision fixtures: 3 distinct irregular selected-wall profiles and 4 material-Z avoidance geometries in **development**, plus 2 different wall profiles and 2 different routing topologies in **heldout**. Split is by hardcoded structural family, *not merely RNG seed*.
- Source hash for every complete fixture, manifest catalog hash, selected-wall identity held separately from distractor walls; all blocked/protected/Z coordinates enforce 4-connected movement.
- Strong conventional controls: selected-wall distance-band-penalised A* contour tracker versus shortest legal A* for A→B routing; seeded random legal policy receiving the same candidate set, including STOP.
- Optional separately labelled cardinal 1/2/4/8-cell action-macro arm. Every traversed cell is checked; an endpoint can never conceal collision.
- Strictly sequential **synthetic** observation → action → new observation loop (36 attempted decisions maximum), with original option-list hashes, immutable fixture hash, ordered events, deterministic path hash, honest STOP and first-pass failures.
- Geometry metrics: exact selected-wall distance, fraction within 6–10-cell band, mean/max deviation, wall-route progress, legal endpoint arrival, route inefficiency versus shortest A*, revisits/retraces, false STOP, collisions and material-Z/protected violations. Native counters are explicitly zero / not performed.
- Narrow staging view `observation_stub`: candidate IDs, geometry, budgets, simulated positions and explicit NULL native fences/receipts. It is deliberately **not** a D-COMMON or native observation.
- **Synthetic evidence integrity:** `paired.verify_episode` regenerates each legal candidate menu and full observation, confirms a sequential policy- and seed-reproducible choice, checks swept cells, STOP and arrival, all intermediate simulated positions and path digests, and independently recomputes every final metric. It explicitly **rejects claimed native receipts**, malformed/altered sequence, unbounded macros, forged choices, edited offered candidates, metric tampering, and held-out behavioral evaluation. JSON/JSONL round trips are supported.
- **Separately audited synthetic effect divergence:** the exact first differing selected ID is not asserted to be a consequential result. Replayed arms now distinguish first differing simulated cursor position, accumulated swept-path digest, episode length and shared cell prefix. Full post-divergence Worlds and native material are **not** compared; those require separately authorized sequential receipts. New `trajectory.py` has 9 source-hash-matched Python tests executed locally (9/9 PASS, including tuple/JSON roundtrip equivalence); the combined legacy lane suite remains pending independent qualification.

- **Matched development-only comparison:** `paired.compare_matched` requires the same fixture hash and identical macro/action menu; checks identical positions and legal candidate-set hashes **only until the first differing chosen action**. It records the first consequential decision-divergence index, avoids false post-divergence parity claims and retains full metric records of both strong geometric and seeded random-legal arms. No representation A1/A2/A3 model experiments are dispatched by this lane; M1 is now accepted, but formal experiment dispatch still needs a separate owner gate.

## Commands

From repository root, with Python 3.11+ and no extra dependencies:

```sh
python -m unittest discover -s experiments/driv3r/stage_d/direct -p 'test_*.py' -v
python -m experiments.driv3r.stage_d.direct.offline --manifest
python -m experiments.driv3r.stage_d.direct.offline --policy astar
python -m experiments.driv3r.stage_d.direct.offline --policy random_legal --seed 17 --output /tmp/d1a-random.jsonl
python -m experiments.driv3r.stage_d.direct.offline --policy contour_astar --macro
```

To audit a source-pinned development pair programmatically:

```python
from experiments.driv3r.stage_d.direct import offline, paired
dev = next(f for f in offline.fixtures() if f.fixture_id == "route_gate_v1")
comparison = paired.run_development_pair(dev, seed=13)
assert comparison["native_qualified"] is False
```

**Qualification history:** [M2 integration PR #600](https://github.com/techrote/cybersand/pull/600) ran the then-current **30/30 D-1A tests** at exact integrated source `9f09a1b11634a03e56b748887d93b7fb8e96601d` ([Actions run 43623698285](https://github.com/techrote/cybersand/actions/runs/43623698285)). The subsequent 10-method M1 preflight module and the new safety/recovery tests were **not** part of that frozen snapshot. Changes made after the M2 snapshot also require a fresh, exact-head full-lane Python run before claiming current-source qualification. Stage A workflow success by itself is not sufficient. The earlier independent JavaScript cross-check of the seven development reference geometries returned wall steps **33/29/35** and A→B shortest paths **35/25/33/31**, without native execution.

Default runner executes **development fixtures only**. Held-out fixtures are manifested for source custody and cheap structural checks; no held-out model outcome is inspected. All JSONL data are offline simulation events and may not be described as native receipts, paintings or visual renderings.


## M1-source-pinned synthetic admission preflight (M2 preparation)

`m1_preflight.py` is a narrow, **offline-only** bridge into the *shape and distinctions* of accepted D-COMMON-001 M1; it neither imports nor edits the frozen contract. The signed source identity and actual schema-byte SHA-256 are pinned, but actual schema-byte verification is performed only when `repo_root` is passed to `preflight_episode`, or `assert_approved_schema(repo_root)` is called explicitly.

- `legal_catalog` reconstructs an ID-sorted synthetic candidate set. It requires exactly one inert STOP, 1–8 fully cardinal and fully legal swept cells for every movement, explicit World dimensions and a caller-owned legality callback. It deliberately emits **`synthetic_legal_catalog_sha256`**, never a forged native `action.legal_candidate_set_sha256`.
- `model_presentation_hash` (offline adapter **v2**) keeps soft annotation and display ordering separate from legal candidate membership, and now additionally binds the **explicit World dimensions, M1 schema hash, adapter version, source kind and candidate membership digest** into the model-facing presentation hash. Two Worlds may have byte-identical local candidate menus, so catalog-only hashing must not stand in for observation-context identity. The synthetic membership digest remains catalog-only and is **not** a native admission hash. This supports future matched A1/A2/A3 attribution without granting model input native authority.
- `preflight_episode` first calls the existing source/seed-bound `paired.verify_episode`, excludes held-out policy outcomes and builds original per-decision synthetic candidate hashes. All native World, observation and receipt fields are **null**; `d_common_record_emitted=false`. Only a future host-owned integration adapter can produce actual conforming D-COMMON native records.

From the repo root run the entire lane-specific Python regression suite:

```sh
python -m unittest discover -s experiments/driv3r/stage_d/direct -p 'test_*.py' -v
```

An optional repo-root schema check can be added programmatically:

```python
from pathlib import Path
from experiments.driv3r.stage_d.direct import m1_preflight
m1_preflight.assert_approved_schema(Path.cwd())
```

**Qualification disclosure:** This checkpoint compiled both added files and executed a standalone pure-Python preflight harness (16 positive/adverse assertions, PASS) against the new adapter logic. The *combined exact-checkout* D-1A suite, including new `test_m1_preflight.py`, remains **pending**; do not label a normal Stage A CI green check as the D-1A test result. Neither the standalone harness nor the new tests have measured native controller effectiveness.

## Synthetic recovery-shepherd opportunity audit (subsequent lane-only development)

`recovery.py` first verifies each original **development-only** trajectory with the unchanged `paired.verify_episode`, then compares the actually selected action to an independently recomputed conventional contour/A* choice at each recorded pre-decision cursor. It records the first **oracle-choice disagreement** as a possible intervention point, not proof of a mistake or neural-model value. At most one purely hypothetical deterministic continuation from that point is explored, **after** preserving the original recorded choice, under the same legal swept-segment rules and exact remaining 36-decision budget. A chosen STOP remains terminal: it cannot be fictitiously resumed or undone.

The module never changes an episode, computes held-out behavioural outcomes, authorises edits, reads model predictions or fabricates native receipts. `test_recovery.py` adds focused oracle identity, deterministic macro, replay-tamper, terminal-STOP, zero-budget and held-out-seal checks. In parallel, `run_episode` now rejects held-out policy dispatch, unsupported/unbounded seeds and irregular action-macro menus **before** emitting an irreplayable source record; `test_offline.py` adds four regression methods for these inputs.

**Current-source qualification remains pending:** the 7 recovery tests, four input/split tests, 10 M1 preflight tests and 3 additional evidence-custody adversarial tests must be executed alongside the original 30 at the newest branch head (nominally **54 methods**, subject to actual discovery). Authored test counts are not execution results. An integration owner can consume this read-only synthetic opportunity report for M3/M4 study design but it is not a native recovery session or a substitute for an owner-authorised campaign.

## World-context identity regression (offline adapter v2)

A same-local-candidates/different-World alias was found in the previously list-only `model_presentation_hash`. The catalog-only hash is intentionally unchanged, but a **separate full presentation identity** must differ when World bounds change. Adapter v2 includes the immutable accepted M1 schema digest and the bounded World dimensions in that hash; `test_m1_preflight.py` adds the direct cross-World regression. This is a synthetic provenance improvement, not proof of native World custody or a new M1 contract revision. **58 Python regression methods are authored at this checkpoint; full exact-head execution is outstanding.** Existing Stage A and documentation checks are not D-1A lane qualification.

## Explicit further gates

1. **M1 accepted; M2 pending:** the approved shared schema/source is pinned. The added synthetic adapter must be independently qualified in the exact-source Python checkout; native conformance and any conversion to real D-COMMON observations/actions remain exclusively under the subsequent integration/native gate.
2. **Separate native execution authority:** integrate only through the centrally owned validated native bridge with fresh actual World fences, Stop, protection, swept-extent checking, material readback, native receipts, replay and cleanup. Never infer native success from these geometry fixtures.
3. **Preregister then dispatch:** matched controller/model Q8/random episodes on exact frozen sources; resident CPU cost/time; first-pass failures and complete sequential trajectories retained; holdout model outcomes kept sealed until the approved evaluation.
4. **36-decision limit:** subsequent 72/144-step stress cases need a reviewed D-specific adapter to avoid silently expanding prior strict Stage A/B caps. Real training, paid API/GPU, defaults and merges require separate authorization.

Do not edit `d_common/**`, other D streams, #568 or historical Stage A/B/C.

## Type-exact source custody (offline verifier hardening)

The source-pinned `paired.verify_episode` now rejects unrecognised top-level and per-decision fields. An otherwise replayable synthetic transcript cannot smuggle a second, unverified `native_*` receipt/readback claim into a record that the verifier approves. Canonical JSON **text** equality retains legitimate tuple/list roundtrips while distinguishing integral coordinates/counters from booleans or equal-valued floats and rejecting nonfinite values. Three additional adversarial `test_paired.py` methods cover forged native fields, numeric-type spoofing and nonfinite observation contamination; these are **authored regressions, not an executed full-source pass**.

No native candidate admission or physical World evidence is generated by these stricter offline checks; owner gate for D-1A native/model dispatch is unchanged.

## Development fixture custody: sealed structural families

The 36-decision **held-out** structural families cannot be relabelled as
`development` through the fixture factories. All episode dispatch and
independent replay require the exact frozen development fixture ID **and**
content digest; a manually constructed or dataclass-replaced fixture with a
plausible split label is rejected before behavioural scoring. The standalone
hypothetical recovery-continuation helper is guarded too. This is an offline
anti-leakage invariant, not a claim that Python code can protect against an
operator intentionally rewriting the research source or running an external
unapproved policy. New development geometries must get separately versioned,
predeclared fixtures rather than silently changing the v1 corpus.

Four additional adversarial regressions cover constructor relabelling,
dataclass-level relabelling/source mutation, replay entry and direct oracle
continuation. They are **authored, not yet exact-source Python-qualified**.
The frozen M1 schema and native authorisation gates are unchanged.

### Replay-bound full-observation presentation digest (synthetic only)

Adapter **v4** preserves the v3 directional/sweep admission invariants.

In addition to the synthetic legal-catalog membership hash, every DEVELOPMENT
preflight now records `synthetic_observation_presentation_sha256`. This binds
the exact independently replay-verified objective/target, selected wall,
visited-path hash, decision budget, raw offered candidate ordering, World size,
frozen M1 schema identity and separately sorted model-menu presentation.
Identical local legal choices alone do **not** imply identical model input.
No real native action, receipt, World revision or permission is conferred.
The M1 source and schema remain frozen; native M2/M3 integration is independent.

## Selected-wall progress: max-Y false-positive control (synthetic)

The frozen v1 `route_progress_fraction` measures the largest row reached,
not whether the cursor **followed the identified selected wall**. A path can
reach the target row far outside the prescribed 6–10-cell band and still
score 1.0 raw vertical progress. Do **not** reinterpret that metric alone as
successful wall tracing.

`wall_progress.py` adds a separately versioned, replay-verified
DEVELOPMENT-only diagnostic (now `d1a-selected-wall-ordered-progress/2`):
ordered in-band profile rows, unique row coverage, off-band excursions and
reentries, and the ungated/ordered progress gap. The v2 report additionally
records the **longest physically continuous, forward-advancing in-band row
run**, its start/end rows and fraction of required vertical traversal.
Repeated lateral cells do not increase this run; reverse steps, band exits
and sparse jumps reset continuity. Distances are measured to the **selected
wall**, not nearby distractors. This is a descriptive longest-run diagnostic,
not an assertion of clean end-to-end traversal or native controller success.

**Deterministic counterexample:** a fully cardinal path visiting every
selected-wall row in order can obtain **100% ordered in-band progress** while
briefly leaving the 6–10-cell band between rows. Its longest uninterrupted
forward in-band trace can cover only **50%** of the required vertical
transitions. The supplementary fields do not change frozen v1 scores,
original trajectories, fixture identities, policy choices or the M1 schema.

Nine adversarial/integration tests are authored in `test_wall_progress.py`,
including four new continuous-trace, detour, reverse-motion, and lateral/sparse
cases. The **exact committed v2 helper blob** was locally syntax-compiled and
passed seven independent pure-helper cases (four new, three original);
source-matched full lane discovery and DEVELOPMENT replay/integration tests
still require qualification. No held-out controller outcomes or real native
receipts were executed.
