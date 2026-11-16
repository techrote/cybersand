# D-1A → M3 wire boundary (read-only qualification)

**Version:** d1a-m3-wire-preflight/1; **M1:** owner-accepted commit
8fa90de6be209ed0b7bd125039e6ec8b332fb1a6, schema SHA-256
ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d.

D-1A offline m1_preflight.legal_catalog() declares N1/S1/E1/W1
(and 2/4/8-step variants) as cursor_move, brush **up**, material effect
**none**. M3-A's real native one-cell smoke offered MOVE_DOWN_ONE with the
*same* (12,24) → (12,25) cursor displacement but add_material, brush **add**,
one rectangle operation and one real material-58 cell edit. The movement
**geometry** agrees, but the **action/effect contract is not interchangeable**.
Never count D-1A cursor positions or synthetic replay as native paint receipts,
and never silently map a cursor-only candidate to material-writing native work.

**Original native evidence inspected offline:** immutable M3-A source
012e77001b30823836360ea09f16a674cdfdca13, Actions run
https://github.com/techrote/cybersand/actions/runs/43625519948,
artifact 14126460193, original ZIP SHA-256
120ef20cae26c5796e8eabfb1ad05ee16090a79e8e84d122e6ab06004c7f5cac.
Checked execution/events.jsonl, execution/host-offered-legal-catalog.json,
native one-cell receipt and execution/summary.json; the new preflight correctly
refuses the real add_material action as a D-1A inert cursor move. This negative
**compatibility finding** does not invalidate the actual M3 native smoke.

m3_wire_preflight.cursor_wire_preflight() implements a versioned read-only
check of synthetic-direction sweep, original native host-offered candidate
path, source World, episode/observation/budget continuity, brush/material
semantics and native receipt absence. It accepts only candidate/selected,
uncommitted brush-up movement as **structurally compatible**, returning
native_qualified=false and sequential_native_receipts=0. A later owner-
approved adapter must distinguish cursor travel from native painting,
recompute host hard legality, verify fresh World bytes and each native
receipt, enforce Stop/partial-prefix/cancellation and original source replay.

Local isolated Python 3.13.5 first-pass tests: **11/11 PASS**. This is not the
full exact-HEAD D-1A test suite (176 methods authored after this addition).
Held-out behaviour/model outcomes remain sealed. No new native session,
inference, training, paid/GPU work, merge or Ready promotion.
