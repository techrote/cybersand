# D-COMMON-001 — DRIV3R research interface v1

**Status: FROZEN CANDIDATE / OWNER REVIEW — not approved for cross-branch integration.** This is an immutable *versioned proposal*, not an assertion that the five records are already wired into the running Workbench. Owner approval, exact schema SHA-256 and a conformance result are required to mark the milestone **ACCEPTED**.

**Canonical schema:** [interface.schema.json](interface.schema.json)
**Related research:** [CyberSand #570](https://github.com/techrote/cybersand/issues/570), [D roadmap](https://github.com/techrote/cybersand/issues/570#issuecomment-6877408001), [active Stage A–C PR #580](https://github.com/techrote/cybersand/pull/580). This branch was forked from PR #580 head `6067ea31adb8f3dfc76867676fc504078f5e9526` without modifying the qualified source or the #568 painter lanes.

## Scope and authority

The five discriminated JSON records all carry `protocol="cybersand.driv3r.d-common/1"`, `type`, unique `record_id`, `episode_id` and monotonic `sequence`. Each emitted record is immutable. Changes require a new record with a new ID; breaking changes require a new contract major version and explicit coordination.

The contract is **not** the preexisting internal `experiments.driv3r.contracts.PROTOCOL`. It is a proposed **D-stage interchange/evidence layer** between independent components, with a future adapter to the already-qualified strict Stage A–C controller. Keep existing receipt hashes and original frozen reports unchanged. No production/default provider change is allowed from contract agreement alone.

### 1. Observation — `type="observation"`

A host-originated bounded read, explicitly tied to `world.id/generation/revision/tick`, material and full-World hashes. Includes original objective and active subgoal, cursor/target, authoritative material crop descriptor, optional guidance record ID, local host-computed geometry metrics, path-history hash, decision/time/material budgets, previous action and native receipt references, and separately typed image witnesses.

**Host invariants:** material crop bytes must agree with the native recorded state at the declared world fence; bytes/hash/coordinate frame must match; model text and image analysis never override focus, permissions or native writes. If the World changes between decision and execution, the host must re-observe and reject or replan. Geometry metrics must define their units in the experiment manifest, and computed geometry is not a substitute for the raw native receipt. Every native action requires a fresh post-action observation.

### 2. Guidance — `type="guidance"`

User-authored or procedurally generated **soft positive preference**, *not* a collision mask and never native mutation authority. Raster origin/frame uses world-aligned integer XY (origin top-left, +X right, +Y down). The canonical numeric field is fixed-point **unsigned little-endian 16-bit**, one value per grid cell in row-major order, 0 = neutral, 65535 = maximally preferred. Blob byte count **MUST equal 2 × width × height**; the field SHA-256 is the authority. PNG/speckles are merely an optional visualization and cannot replace numeric values in numeric-guidance arms.

Seeded gradient-airbrush rendering records radius, centre density, hardness, falloff/gradient length and deterministic seed. Imported PNG conversions must be documented and source-pinned before creating the scalar field. Same scalar values can be rendered multiple ways without changing the guidance objective. There are two versioned thresholds: `exit_below` and `reenter_at_or_above`; **exit must be strictly lower than reentry** to create hysteresis. Crossing a preference threshold triggers a recovery *proposal*, not an automatic material write. The model can prefer to leave the field if all legal candidates are otherwise worse; hard exclusion stays the native host's job.

### 3. Action — `type="action"`

A **host-generated candidate/selected/committed** transition with observation ID, exact precondition World fence, candidate-set SHA-256, candidate ID, actor/policy, bounded path, brush state, predicted effects and optional native operation hash/receipt. A decision model may only choose an offered candidate ID; it never emits unrestricted coordinates, material IDs or permission changes. Predicted effects are non-authoritative. A path with multiple cells must be checked along its **entire swept footprint**; no endpoint-only permission checks.

`brush_state="up"` means logical travel without material mutation. `add` and `erase` mean host-authorised operations, confirmed only by actual native receipt/readback. A `stop` or `no_paint_plan` action must carry no mutation. Keep proposal and result as different immutable event records; do not change a candidate in place once the model has been queried. `native_receipt_ref=null` is not proof of execution.

### 4. Reversal — `type="reversal"`

Exactly three behaviours:
- `BACKTRACK_CURSOR`: traverse a verified prior cursor path with brush lifted, **preserving all previously applied material edits**.
- `RELOCATE_TO_BRANCH`: logical return to an existing saved branch anchor with brush lifted, **preserving material edits**. This is not falsely recorded as a continuous physically travelled/painted line.
- `UNDO_MATERIAL_EDIT`: request a **real, bounded, owner-authorised native Undo**, and independently verify the actual result.

For successfully applied cursor-only reversals, **before and after native material hashes must be identical**, no native material changes may be recorded, `brush_lifted=true`, `preserve_material_edits=true`, and `native_undo_receipt_ref=null`. For applied native Undo, `brush_lifted=true`, `preserve_material_edits=false`, and an actual native history/undo receipt reference plus readback are mandatory. A cancelled/refused reversal changes neither native materials nor logical cursor. A navigation correction without Undo is not labelled `UNDO_MATERIAL_EDIT`. Existing Workbench history capacity and Stop/revision fences remain authoritative.

### 5. Provenance — `type="provenance"`

Links the experiment ID/arm/split and original scenario hash to exact source commit/tree/base, schema SHA-256, actual algorithm name/version/seed/recipe, optional model revision/weights/backend, native runtime identity, guidance reference, **original ordered event IDs**, final native World fence, outcome, metrics, replay result and immutable artifact descriptors.

Artifact `path` is evidence-relative, never absolute or parent-traversing; content must match recorded size/SHA-256. Model results, native results, subjective visual evaluation, material PNGs and true framebuffer captures must remain distinguishable. Evaluation outcomes and all failures are retained, including refusals, partial material prefixes and timeouts. `replay="pass"` must mean independently executed native replay, never regenerated JSON alone. A synthetic fixture uses clearly fake SHA placeholders and **must never count as empirical acceptance**.

## Cross-record rules (mandatory beyond JSON Schema)

1. A referenced ID must exist in the episode journal and resolve to the expected type. Unique IDs are never reused with different content.
2. Source and candidate-set hashes must match exact bytes; any action selected on a stale World fence is refused. `sequence` is strictly increasing for events of the same episode.
3. The native World has exclusive authority over materials, protections, focus, revision, Stop and actual changed cells. Soft guidance never grants permission.
4. **No brush-down cursor teleport:** physically meaningful line continuity requires an explicit legal traversal; `RELOCATE_TO_BRANCH` may change logical cursor only with brush up.
5. A `candidate` or `selected` action cannot claim a native receipt; a `committed` material action must link an actual validated receipt. Every action's post-native World fence and material hashes are captured in its corresponding later observation/receipt.
6. For action `path`, consecutively painted points are cardinal-adjacent unless the host explicitly uses a no-paint jump; no illegal swept cells or self-intersections where the experiment forbids retracing.
7. The current Stage A/B strict observation contract caps step and history at 64/65, so D's 36-step main study fits. **72/144-step stress studies require a reviewed D-specific adapter**, not silent widening of historical checks.
8. Positive guidance is distinct from a forbidden-material mask. An untouched scalar zero is *neutral*, not a prohibition. If negative/repulsive fields are later useful, add a declared extension/version rather than silently reversing polarity.
9. Model-image conditions require genuine image-capable inference; the current DRIV3R Q8 Stage A backend uses `--no-mmproj`. Material-generated PNGs must not be labelled graphical framebuffer images.
10. Deterministic policies, random controls and neural policies must receive matched eligible observations and candidate sets, with explicit information ablations separately labelled. Freeze held-out cases **before** model outcome inspection.
11. `interface.schema.json` checks shape only. Cross-record identities, provenance custody, native readback, rollback semantics, value counts and hysteresis inequalities **require semantic validation** before recording milestone acceptance.

## Independent streams — disjoint source ownership

| Stream | Owns | Does not own |
| --- | --- | --- |
| **D-1A Controller** | `experiments/driv3r/stage_d/direct/**` — 36-decision wall offset and material-Z A→B, geometric/A* and random controls, sequential episodes | Guidance authoring, procedural generator roster, contract schema, shared native/bridge implementation |
| **D-1B Guidance** | `experiments/driv3r/stage_d/guidance/**` — soft u16 field tools, seeded stippling, before/after critic shadow tests, undo proposal validation | Direct cohort, procedural generators, host permission edits, guaranteed visual-backend support |
| **D-2 Procedural** | `experiments/driv3r/stage_d/procedural/**` — Weathering Worm, Branching Growth, Guided Coverage, cursor backtrack/branch relocation, serialized recipes and example corpus | Shared native authority, global model adapter, contract schema, other lanes |
| **Integration/Shepherd (single owner)** | `experiments/driv3r/d_common/**`, shared adapters/native, exact-source qualification, experimental matrix aggregation and formal held-out tests | Model/geometry outcomes cannot be invented, no broad refactors without a demonstrated need |

All three research streams may investigate **independently in parallel** once their candidate contract is available. **Do not integrate or declare conformance until the Owner explicitly approves the v1 freeze.** The central owner handles schema revisions and version bumps after reviewing a bundled change proposal. Nobody silently edits another worker's branch or the #568 painter workers' files.

## Milestone acceptance and rollout

- **M0 — Review candidate (this PR):** five machine-readable schemas, concise semantics, synthetic shape examples, static checks and a source-pinned initial baseline. Status `FROZEN CANDIDATE`, not authoritative across workers.
- **M1 — Owner approves freeze:** review or refine field meanings, brush/cursor reversal semantics, cross-record custody and workload boundaries; record **exact commit SHA + SHA-256 of `interface.schema.json`** in #570, and mark `ACCEPTED/FROZEN v1`. No unreviewed mutation of the accepted bytes.
- **M2 — Independent implementation:** three disjoint Draft worktrees/branches consume the accepted exact SHA and can run CPU/native exploratory work concurrently. A worker can start self-contained tests/preparation before M1, but its shared adapter/interface must be reviewed before integration.
- **M3 — Integration gate:** one integration owner rebases, validates journal compatibility and repeats native Stop/protection/replay/undo tests. Run only *explicit* opt-in model/native experiments with bounded Jobs/VMs, never hourly unbounded training.
- **M4 — Formal comparisons:** preregister paired scenarios and prompts, retain DEVELOPMENT exploration versus sealed structurally distinct held-out tests, execute matched independent Worlds, publish consolidated evidence. Parallelize independent run *execution* but serialize freeze, interpretation and acceptance.

**Deferred:** production/default editor integration, automatic merge/Ready, full node editor, fine-tuning, OpenAI Decisions API expenditure, large GPU models, new inference defaults and unsanctioned scheduling. All require their own Owner approval.

**Proposed owner decision:** approve/refine the exact five-record v1 wire contract, then allow source-pinned D-1A/D-1B/D-2 integration and independent qualified execution under their existing separate owner gates.
