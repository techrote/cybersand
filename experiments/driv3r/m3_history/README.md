# DRIV3R M3-HISTORY — bounded real PAINT Undo, branch relocation, short native sequence

**Owner-approved next step** in [CyberSand #570](https://github.com/techrote/cybersand/issues/570): qualify real Workbench material Undo and host-owned branch relocation under the already-accepted source-fenced D-COMMON v1 wire contract; after an independently verified PASS, qualify a short multi-decision native episode. **No 36-decision A1/A2/A3 campaigns, model training, multimodal inference, merge, Ready promotion or production default changes.**

## Exact source and authority

- Immutable M1 approved source: `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`
- Immutable M1 `interface.schema.json` SHA-256: `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d`
- Qualified M3 first one-edit/brush-up pilot: `012e77001b30823836360ea09f16a674cdfdca13`, [Actions 43625519948](https://github.com/techrote/cybersand/actions/runs/43625519948)
- This PR is stacked on the first qualified M3 scope and adds **only** a strict optional script selector in `experiments/driv3r/native.py`, a derived GDScript host in `godot/tests/run_driv3r_m3_history.gd`, and isolated `experiments/driv3r/m3_history/**` plus opt-in workflow. The original Stage A script, native C++ backend, M1 schema and D-1A/B/D-2 worker files remain unchanged.
- The existing `NativeSession` default remains exactly `res://tests/run_driv3r_stage_a.gd`. The new script path is allowlisted, bound to the exact source SHA/harness SHA and included in runtime identity checks. Godot-rapier, Godot 4.7, godot-cpp and compiler/build pins are inherited from the qualified first M3 pilot.

## Phase 1: Workbench PAINT history + host-owned branch

**Actual live Godot Workbench** at 512×512 World/96×96 focus, material 58, fixed protected 8×8 region. Explicit native fixture reset, readback, two distinct source-fenced Art submissions:
1. Paint A at (12,25). Read native write receipt, entire original native material and real stored-material PNG; move the host-owned *logical* cursor one adjacent cell with brush lifted.
2. Save named branch anchor at logical (12,25), retain its generation and source.
3. Paint B at (13,25). Verify A and B genuinely exist; move logical cursor to (13,25).
4. `RELOCATE_TO_BRANCH` from (13,25) back to saved (12,25). This must be acknowledged by the **running Godot host** with fresh original native material readbacks *before and after relocation*, and unchanged full World/crop material hashes. It is **not native pointer teleportation**, a physical traversal, or native Undo.
5. Deliberately submit a **stale source-fence** PAINT Undo; require explicit refusal and zero material changes.
6. Submit `UNDO_MATERIAL_EDIT` **through `editor.undo()`**, the real shared Workbench PAINT history owner. Require emitted `history_action_finished` with action=undo, status=completed, changed=1, recorded=true; independently compare all 512² native materials to show B has returned to Empty (0) while A remains material 58, reproducing the exact pre-B World SHA. Stop and reap process.
7. Independently rebuild that original sequence in a **second** source-matched Godot native session (paint A+B and true PAINT Undo); require identical final full-World material SHA and original one-cell Undo delta. Never label a generated JSON or synthetic raster as native proof.

D-COMMON v1 event journal must include original `guidance` (positive u16le core), exact readback `observation`, each native `action`, a source-fenced `RELOCATE_TO_BRANCH` reversal and a **distinct** `UNDO_MATERIAL_EDIT` reversal whose hash/byte-bound native history receipt and actual_changed_cells=1 are independently audited. The closed `provenance` record binds these events, native material byte evidence, original stored-material PNGs, source SHA and independent replay pass.

## Phase 2: short sequential native control (only after phase 1 PASS)

Start a **third** fresh native Workbench session. Deterministic host issues **four** successively selected legal one-cell actions, with a new native observation and exact source fence before each. Every proposed legal catalog offers a STOP alternative. Confirm full material readbacks, corresponding real native Art receipts, brush-up logical cursor updates and distinct ordered event IDs. Retain a named trunk branch after the first action. After all four native edits, relocate logically to trunk (no material writes), then issue one real native PAINT Undo that reverses *only the fourth action*, retaining the earlier three. Verify source-fenced M1 records and genuine native readback, Stop and cleanup.

**Important boundary:** This is **four sequential deterministic host decisions**, not four d1-2B neural choices. It tests the source-fenced short-horizon *native interaction machinery*. Qualifying four actual model-selected decisions and true multimodal feedback is a separate follow-up before any 36-decision A1/A2/A3 comparisons.

## Budgets and gate

Total ceiling across the three native sessions: **8 forward one-cell Art edits** (2 original, 2 independent native replay, 4 short episode), **≤3 native PAINT history Undo operations**, **≤2 branch relocations**, **4 short episode forward decisions**, no paid API/GPU/model weights/network inference, no native physical cursor teleport, no production change. One finite opt-in Actions request, GitHub-hosted `ubuntu-24.04`, source-build capped, failure artifacts uploaded even when incomplete. CI policy explicitly bounds matrix (none here).

The workflow triggers no native build from PR updates; only the exact, intentional `qualification-request.json` push on the dedicated branch admits its heavyweight job. Cheap static and M1 tests run on Draft PRs.

Any partial or failed native result stays **FAIL/PARTIAL** with full original diagnostics. No automatic re-run, silently revised test fixture, or positive conformance claim from synthetic receipt data. Native GO only after receipt and full World replay evidence are independently inspected. Preserve M1, all Draft/HOLD PRs and the original M3 pilot.
