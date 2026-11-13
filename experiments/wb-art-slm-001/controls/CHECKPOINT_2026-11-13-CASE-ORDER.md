# WB-ART-SLM-001 Controls — native case-stream chronology guard

Date: 13 November 2026. Owner: Controls. Branch: `codex/wb-art-slm-controls`; [shared Draft #567](https://github.com/techrote/cybersand/pull/567) is Integration-owned and unchanged by this checkpoint.

## Actual source, dependency and prior repair

Accepted main: `63f8b1ba6559906fe85f3ad0269aa296e4141d67` (includes #563). Integration branch observed: `8e7d3638afb9dad39287c07355c1849acee6dc88` (last imported Controls `b7e9db37`). Earlier `test_material_readback_tampering_refused` mismatch was fixed in Controls' 08:12 checkpoint, and the updated full Integration offline smoke succeeded on [43398250411](https://github.com/techrote/cybersand/actions/runs/43398250411), [43398257670](https://github.com/techrote/cybersand/actions/runs/43398257670), and [43398456790](https://github.com/techrote/cybersand/actions/runs/43398456790). These runs **precede the present Controls changes**. The corrected assertion still checks the exact message `stored native crop disagrees with receipt chain`; no native tamper-refusal path was relaxed.

#564 remained Draft at `6319ab1d`. #565 advanced to `11b809a579ecade05baaeded59461ab8fc3f6c39`; its new Windows/Linux publication campaign was not terminal at review. **No source-compatible Windows acceptance can be claimed.** The historical Linux headless pilot `90719c72` is not current-main qualification.

## New implemented fail-closed validation

Re-read the pinned `evaluation/native_replay.gd` execution contract. It explicitly executes `protection_probe()`, then `stop_probe()`, then loops sequentially through its input cases. The existing Controls checker independently reconstructs each case's native receipt and four history snapshots. Its previous improvement enforced draw-before-history within each case but did **not** enforce that the full JSONL event stream follows the harness's cross-case execution order.

`controls/audit_v11_native_pairs.py` now checks the original JSONL stream before per-case reconstruction. It:

- accepts only actual requested case IDs or the two registered native invariant case IDs (`invariant-protection`, `invariant-stop`);
- refuses missing/non-string case IDs and ambiguous receipt/capture event envelopes;
- requires the invariant events to precede all pattern events and occur in protection-then-Stop order, when present;
- requires pattern case indices to be non-decreasing in frozen input order, rejecting a complete block moved before an earlier case;
- preserves the previously enforced within-case draw, Undo, Redo, save/reopen chronology, raw material readbacks, hashes and all fifteen global native gates.

This is an *evidence admission* change. It changes no compiler geometry, source/native capability, existing aliases, model, Art provider, world state or production default.

Three new adverse tests mutate/rehash the raw JSONL to reorder complete blocks, insert an unregistered case or append an invariant after pattern execution. A fourth confirms a valid invariant prefix is still accepted, and a fifth rejects reversing protection/Stop. Total defined Controls suite: **20 methods** (previously 15).

**Published source commits:** `e7a0cd7639c16d0c1a48f50befd95dc1be10e8bc` (guard), `c238a8c0c932db31621459acf82caeec3a0d493a` (first tests), `cee087701b2537b858338b9a327508627006ef25` (JSONL newline correction), `8eb26a8593a776bc815bf8cfa3e07bf8479dda44` (deduplicated preflight), `8810b3583f80346c5b23dd36cdc4344af0d646de` (positive/negative invariant controls).

## Actual verification boundary

Seven *isolated logic-level* Python 3.13.5 smoke tests passed (normal order, legal invariant prefix, reordered complete blocks, unregistered event, late invariant, reversed invariants, invalid case type). The smoke uses the same predicates but **is not an execution of the exact complete repository auditor**, and is not native qualification. The full **20-method exact-source** regression suite must be run in a complete source checkout, and Integration must import these Controls-only blobs and run exact-head combined CI. There is no new real paired native 32-case run or human visual review.

Execution on a complete checkout:

```bash
cd experiments/wb-art-slm-001/controls
python3 -m unittest test_audit_v11_native_pairs -v
```

## Handoff and ownership

Only `controls/audit_v11_native_pairs.py`, `controls/test_audit_v11_native_pairs.py`, and Controls-owned documentation were changed. Integration must compare the previous imported Controls blobs to this branch and consume only its owned delta, without overwriting other worker paths. The real next acceptance gate is 32 matched v1/v1.1 native coral cases with `--history each`, original native readbacks, and blind visual review on qualified compatible source. #567 stays **Draft/HOLD**. Do not claim retraining, Windows, graphics, human, new native or production success.
