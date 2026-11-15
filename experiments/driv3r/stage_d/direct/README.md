# D-1A long-horizon direct-drive research — offline foundation

**Status:** independent **development-only** preparatory fixtures and oracle policies, not native or model qualification. #570; [owner D roadmap](https://github.com/techrote/cybersand/issues/570#issuecomment-6877408001). The five-record [D-COMMON-001 contract](https://github.com/techrote/cybersand/pull/594) received **M1 owner acceptance on 14 Nov 2026** at source commit `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`, schema SHA-256 `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d` ([#570 freeze record](https://github.com/techrote/cybersand/issues/570#issuecomment-6881686675)). **M2 offline integration preparation is permitted; native/model experiments, merges and formal A1/A2/A3 comparisons are not.**

## Deterministic CPU-work cap for bounded geometry oracle (15 November 2026)

The DEVELOPMENT-only `budget_oracle.py` now has an explicit, configurable
search-work cap (`max_predecessor_probes`, 3,000,000 by default). The counter
includes blocked/cached predecessor probes so a large open grid or 72/144-step
horizon cannot silently consume unbounded CPU. Exhaustion raises the distinct
`PlanningBudgetExceeded` error; it is **not** an unreachable-world result and
must not enter arrival statistics as a completed planner outcome. Successful
reports expose consumed probes and cap for reproducible economics. The cap is
independent of native or learned-model execution; the owner-gated 36-decision
native campaign remains on HOLD.

Three new regression methods cover explicit cap exhaustion, a sufficient-cap
plan preserving geometry and cost, and type/range rejection. **Authored test
inventory: 159 methods / 15 modules.** Full clean exact-checkout execution and
first-pass failure capture remain outstanding. Existing frozen DEVELOPMENT
baseline outcomes, held-out fixtures and shared M1 records are unchanged.

## Committed M1 rename must not masquerade as a direct-lane-only change (15 November 2026)

The original `qualification.source_fence` used `git diff --name-only
<accepted-M1> HEAD`. On Git installations with rename detection enabled, a
100%-identical file moved **from frozen `d_common/**` into
`stage_d/direct/**` appears *only at its destination*, even though the
accepted M1 source file was deleted. The previous exclusive-write check could
therefore erroneously admit a committed shared-source deletion.

The revised `d1a-exact-head-offline-qualification/2` gate uses
`git diff --no-renames --name-only` against the same accepted immutable M1.
Both the forbidden old-path deletion and lane addition are now visible.
New `test_qualification.py` regressions create real temporary Git histories:
(1) an unchanged shared-file rename must be rejected; (2) a legitimate
direct-only committed addition must be admitted. They never touch actual M1
files, external branches, held-out outcomes or native Worlds.

**Verification limits:** an independently executed local Git fixture reproduced
the false acceptance premise and exercised the repaired command: 2/2 scenario
checks PASS. These scenarios are **not** claimed as executions of the two
newly committed unittest methods. Source inspection at the new branch revision
counts **154 authored test methods across 15 modules**. The complete
source-matched 154-method Python suite is still unexecuted here; its actual
first-pass log must be preserved. This is source-fence hardening, not a
geometric-controller performance result or a native GO.

## Complete offline-source census and immutable-stack fence (15 November 2026)

The launcher now refuses **partial discovery**, not merely a low aggregate
unittest count. `inventory.py` anchors all 15 expected test modules and their
source-method floors; 154 named unittest methods are now authored (the original
130 plus subsequent census, routing-oracle and source-fence regressions).
It statically parses the exact source files and requires the executed unittest
count to equal the current parsed count. Missing/renamed modules, removed
methods, symlinked source, parse failures, skipped tests and mismatched
discovery are fail-closed.

The source fence additionally rejects *any* dirty or untracked repository path
and compares frozen accepted M1 source against HEAD, refusing every committed
change outside `experiments/driv3r/stage_d/direct/**`. This prevents source
attestation with modified shared imports, native code or frozen evidence.
Frozen schema bytes and exact M1 ancestry remain independently verified.

**Actual bounded qualification:** 17/17 scoped Python tests PASS on four
Git-blob-identical committed Python files, with the M1 dependency stubbed.
This is explicitly **not** a completed 139-method exact-checkout suite:
the full source tree could not be executed in this tool environment. The
existing Stage A/M2 runs do not qualify the present D-1A HEAD. Execute the
normal `qualification` command on a clean exact checkout and retain its
original stdout JSON and stderr unittest log. No D-1A native/model campaign
has been authorised or run.

## Exact-checkout offline qualification launcher (15 November 2026)

The D-1A lane now contains a fail-closed CPU-only qualification launcher: `qualification.py` and eight direct regression methods. It checks (1) the accepted M1 source is an ancestor of HEAD, (2) the actual M1 schema bytes match the owner-approved SHA-256, and (3) the entire D-1A lane is clean before and after invoking normal unittest discovery. It refuses missing/ambiguous output, fewer than the 122 pre-harness methods, any skipped/failing test, timeout, and source changes during testing. The full original failure log is printed to stderr and its SHA-256 recorded in a JSON summary on stdout.

```sh
python3 -m experiments.driv3r.stage_d.direct.qualification > /tmp/d1a-qualification.json 2> /tmp/d1a-unittest.log
```

The JSON includes the exact tested commit, schema pin, total tests, exit/skip/timeout status, log digest, and explicit zero-native-receipt / no-held-out-outcome flags. No workflow, paid model, GPU, native World, or formal campaign is launched. **The new harness has not been run against the full committed D-1A dependency tree**; eight isolated harness tests passed using a stubbed M1 import, not source-matched complete-suite qualification. Do not count existing Stage A/docs checks as D-1A's own full-suite result. Preserve and report any genuine first-pass failures rather than silently editing or rerunning them away.

## Replay-gated synthetic cursor gallery (15 November 2026)

`visualize.py` adds an **offline, DEVELOPMENT-only** raster comparison of the same strong contour/A* and seeded random-legal policies on identical original grids and 36-decision budgets. Seven frozen DEVELOPMENT topologies × two controls give **14 PNGs per seed/macro configuration**; the four sealed held-out families are **never dispatched** to controller evaluation. The output depicts **synthetic brush-up cursor movement only**, NOT Workbench PAINT, native material, a true framebuffer, resident d1 outputs, or aesthetically accepted artwork.

Every trajectory is independently replay-verified through `paired.verify_episode` **before rasterization**, and paired controls are checked against matching original legal menus until first action divergence. Deterministic stdlib RGB PNG encoding shows selected-wall 6–10-cell offset region, selected-wall identity vs decoys, material-Z/protected blockers, original cursor traces, retraces, start/target and route outcomes. The JSON manifest binds original fixture SHA, event and path records, policy, full metrics, PNG SHA-256, reproducible index, selected commit and explicit no-native/no-model qualifiers. Source-fencing refuses a mismatched HEAD or a dirty D-1A worktree; an existing output directory cannot be silently overwritten.

From a clean checkout at the exact commit under review:

```sh
sha="$(git rev-parse HEAD)"
python3 -m unittest experiments.driv3r.stage_d.direct.test_visualize -v
python3 -m experiments.driv3r.stage_d.direct.visualize \
  --source-sha "$sha" --seed 13 --output "build/d1a-cursor-$sha"
# Independently labelled optional macro arm (1/2/4/8 cells):
python3 -m experiments.driv3r.stage_d.direct.visualize \
  --source-sha "$sha" --seed 13 --macro --output "build/d1a-cursor-macro-$sha"
python3 -m unittest discover -s experiments/driv3r/stage_d/direct -p 'test_*.py' -v
```

**Qualification boundary:** Ten new Python regression methods authored (**122 D-1A tests total**), covering source replay, exact raster decoding/CRC, selected-wall vs decoy, held-out refusal, native-counterfeit rejection, source fencing, hash provenance, deterministic gallery equality and refusal to overwrite. The two new **committed** source blobs match locally syntax-compiled Python files (renderer `c49310549bb82120844a5d0623f92e634360c29b`, tests `079a074b165f136da28c73f17bdced4c2f0fb46d`). A small isolated scratch-injected render/manifest smoke passed, **not** the source-matched full test suite. Execution of all 122 tests against current-head real `offline.py` and `paired.py` remains open, as does M2/M3 native-adapter review. No native/model/gated campaigns authorized for D-1A.

## Cursor-line character for the owner's drawing-worm hypothesis (15 Nov 2026)

Issue [#570 owner correction](https://github.com/techrote/cybersand/issues/570#issuecomment-6889195672) prioritises an eccentric but bounded **line-steering worm brain**, not A* superiority. The lane-only `line_character.py` adds a **descriptive** geometry fingerprint for original DEVELOPMENT paths: cardinal heading distribution and entropy, clockwise/counterclockwise turns, reversals, straight runs, repeated cursor cells, retraced undirected edges, closed loops and footprint bounds. None is treated as an art-quality score or success/failure by itself. A loop or detour may be desirable worm behaviour. Pen-state/material and steerability cannot be inferred from cursor geometry alone.

`audit_development_line_character` invokes the existing `paired.verify_episode` before examining any original offline episode, rejecting held-out behaviour, forged receipts, source-identity/choice tampering or silent trajectory repair. Outputs explicitly identify **synthetic cursor geometry**, not actual native material strokes or learned-model decisions. The separately owner-authorised [real wormbrain PR #611](https://github.com/techrote/cybersand/pull/611) remains independent; its native receipts are not imported or claimed here.

```sh
python -m unittest experiments.driv3r.stage_d.direct.test_line_character -v
python -m unittest discover -s experiments/driv3r/stage_d/direct -p 'test_*.py' -v
```

**New file qualification:** 8/8 pure descriptor methods executed locally on Git-blob-identical Python source/tests (blobs `01e19b975213aed10652565cc346d485d823c4de` and `d9e80d48cb943458bd1ec2f0b369ca1cb27d42ed`). The existing 101-method suite plus these eight = **109 authored tests**, but the full exact-head suite **has not been executed**. Full DEVELOPMENT replay integration and M2/M3 native adapter review remain open; D-1A native campaign authorization remains separate.

## Supplementary forward-Y selected-wall feasibility (15 November 2026)

The v2 strict selected-wall horizon verifies 6–10-cell clearance across entire
movement macros but allows backward-Y detours. Its reachability result cannot
be read as evidence of a *forward* uninterrupted trace. The new **separate**
`d1a-selected-wall-monotone-band-horizon/1` ablation in `band_horizon.py`
calculates the exact minimum legal macro decisions needed to reach the target
while each swept cursor cell remains within the selected wall's band **and
forward Y never decreases**. A source-replay-verified DEVELOPMENT audit records
per-choice remaining decision slack, the first original backwards-Y step,
sticky original-prefix compliance and whether a hypothetical 36-decision
continuation could still satisfy that stronger condition.

A backwards-Y recovery maneuver may be artistically valid and necessary.
The monotone result is therefore an intentionally stricter **diagnostic
counterfactual**, not a redefinition of acceptance or a requirement for
controller success. Frozen original episodes, score fields, held-out fixture
identities and accepted M1 records remain unchanged.

**Source qualification boundary:** Five extra unittest methods authored;
**101 total** D-1A tests pending current-head execution. Independent local
forward-BFS cross-check of the algorithm on **75 seeded synthetic grids and
3,600 possible starts yielded 0 discrepancies**, plus three representative
assertions passed. That comparison used a scratch reproduction, **not**
the committed Python module or its two new DEVELOPMENT replay tests.
The full current-head suite and independent M2/M3 native adapter review remain
open. No model/native/held-out campaigns or receipts occurred.

```sh
python -m unittest experiments.driv3r.stage_d.direct.test_band_horizon -v
python -m unittest discover -s experiments/driv3r/stage_d/direct -p 'test_*.py' -v
```

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

## Deterministic lexicographic macro oracle (development-only)

`macro_oracle.py` adds a stronger *planning* comparator for the separately
labelled 1/2/4/8-cell macro arm. The earlier A* baseline minimizes cardinal
distance and compresses a selected path into macros; it need not minimize the
number of macro decisions. The new reverse-Dijkstra reference minimizes
(decisions, swept-cell distance) for material-Z A→B routing. For selected-wall
contours, it lexicographically minimizes (6–10-cell band departures,
backwards-Y steps, decisions, swept-cell distance). Every intermediate
swept cell requires an explicit host-like boolean legality response; no
distractor wall is substituted for the selected wall. The wrapper
`audit_development_macro_plan` rejects non-pinned or held-out fixtures
*before* geometry calculation. A 36-decision budget is enforced.

The first local focused test execution failed 1/6 due to an incorrect *test
expectation*: distance 14 with macro lengths 1/2/4/8 needs 3 decisions
(8+4+2), not 2. The expectation was repaired without altering the algorithm.
Final isolated exact-module Python tests: **7/7 PASS**, with independent
forward-Dijkstra agreement on **3,012 random routing starting states** and
**3,809 random selected-wall starting states**, zero observed mismatches.
This is **offline-only** and does not claim that the complete repository suite
or native Workbench control passed. The complete authored D-1A inventory is
now **146** tests across 14 modules, still requiring exact-branch checkout
qualification. The existing v1 episode policies and first-pass trajectories
are unchanged; held-out outcomes remain sealed.


## Budget-constrained wall fidelity (additional synthetic oracle)

The previous unbounded reverse-Dijkstra `macro_oracle.py` chooses the
lexicographically best eventual route and then truncates at 36 actions. For
selected-wall tracing, an uninterrupted 6–10-cell offset path can require
more decisions than allowed, while a slightly less faithful route could
**arrive** within the decision budget. Do not rank an unreachable-on-budget
ideal route as a successful 36-decision baseline.

The separate `budget_oracle.py` solves the exact *bounded arrival* problem
with an exact-k reverse dynamic program, retaining the number of decisions as
a state dimension rather than collapsing long and short paths. Each swept
cell must pass immutable hard legality. Among routes arriving within the
budget, the objective minimizes (out-of-selected-band cells, backwards-Y
cells, decisions, swept distance); A→B instead minimizes decisions/distance.
An impossible-to-complete episode is explicitly returned as **infeasible**;
the solver never fabricates progress, repairs recorded trajectories or
inspects held-out policy outcomes. The original A*/contour/random baselines,
unbounded oracle, v1 scores and M1 schema are unchanged.

**First-pass test history:** an initial isolated six-test run could not
import the absent real `offline` module; a minimal isolated dependency was
then supplied. This exposed a real parenthesization bug in the new wrapper:
the conditional was inside a lambda and returned `None` for routing cases.
After fixing the conditional to select either a lambda or `None`, all
**6/6 newly authored tests passed** in the isolated Python runtime with
stubbed existing dependencies. A separate **120/120 small-grid brute-force**
comparison agreed with the newly authored exact-source algorithm. Both new
Python files match their committed Git blob bytes. These are **focused local
checks, not execution of the full committed source/dependency tree**.
The lane now inventories **152 authored tests across 15 modules**, whose
complete exact-branch execution remains outstanding. No native receipts,
actual material, resident inference, paid workload or artist assessment.

## Budget-constrained oracle: safe lexicographic cutoffs (15 November 2026)

`budget_oracle.py` v2 eliminates unnecessary exact-k expansion for an
already-reached target; for routing after the first feasible k; and for
selected-wall tracing after reaching the **absolute zero band-departure and
zero backward-step** lower bound. A later path must use more decisions and
cannot beat those objectives. If early arrival crosses the selected-wall
6–10-cell band or backtracks, the search continues: a later path may be
better despite requiring more actions. Hard swept-cell checks and the
existing geometric objectives are unchanged.

Two new regression methods check zero-action and one-action optima with
bounded geometry-callback counts; the original longer-in-band alternative
test guards against premature cutoff. A separate **independent** Python
unshortened-DP comparison matched optimum cost/decision count in **600/600**
seeded small-grid routing and wall cases with blocked cells. In a 20×20
12-layer scratch reconstruction, a single-cell route used 9 candidate
expansions instead of 41,281 and an already-arrived start used 0 instead of
40,512. These are **scratch comparator counts**, not measured committed-code
runtime. The full source-matched D-1A suite, now **156 authored methods across
15 test modules**, still requires clean-checkout execution. No inference,
native painting, held-out behavioural evaluation or new owner authorization.
