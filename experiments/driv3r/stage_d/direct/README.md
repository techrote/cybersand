# D-1A long-horizon direct-drive research — offline foundation

**Status:** independent **development-only** preparatory fixtures and oracle policies, not native or model qualification. #570; [owner D roadmap](https://github.com/techrote/cybersand/issues/570#issuecomment-6877408001). The five-record [D-COMMON-001 contract](https://github.com/techrote/cybersand/pull/594) received **M1 owner acceptance on 14 Nov 2026** at source commit `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`, schema SHA-256 `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d` ([#570 freeze record](https://github.com/techrote/cybersand/issues/570#issuecomment-6881686675)). **M2 offline integration preparation is permitted; native/model experiments, merges and formal A1/A2/A3 comparisons are not.**

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
