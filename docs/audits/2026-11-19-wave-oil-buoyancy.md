---
title: Oil rising through Wave Water
status: Current
document-kind: audit
scope: Draft evaluation of vertical Water–Oil exchange and splash recovery after falling Sand
last-reviewed: 2026-11-19
related-documents: [../architecture/wave-flow-v1.md, ../operations/workbench-water-lab.md, ../architecture/liquid-solver-family-policy.md]
---

# Oil rising through Wave Water

In the Windows full-face playtest, a buried band of 48 Oil cells stayed submerged for 600 ticks. In a separately run FreeMass control, all 48 surfaced by tick 60. Wave excluded Water from the per-cell scheduler and treated Oil as an obstruction. Oil had no move for rising through Water. Sand disturbed the interface and the resulting spray could persist after Sand landed.

## Design choices

The active Oil cell checks for Water one cell overhead after Oil's usual fire and extinguishing rules. The heavier Water can trade places with Oil once a tick. The ordinary density-swap path carries both complete cell states and their temperatures. A solid cell, a paused endpoint or a body mask can block exchange. A sealed pocket can remain submerged.

The exchange alone left occasional spray after the Sand had landed. On the 48-column tank it threw another 53 Water units between ticks 540 and 600. Preventing random sideways moves in floating Oil alone also left late spray. We combined two changes. An Oil cell already resting on Water, or on one other Oil cell directly on Water, takes a downward opening before settling. Wave treats a floating slick as a movable cover. Water can accumulate under it without the pressure kick used for a rigid roof. Oil directly under a wall, body mask or paused boundary still transmits a rigid cap. Both changes reuse existing passes and storage. The per-material solver and tuning target is recorded in the [solver policy](../architecture/liquid-solver-family-policy.md#status). Reverting the four native commits below recovers the earlier behavior.

## Independent review

The reviewer found two boundary cases. A Water cell arriving from an earlier update could sink twice in one tick. A worker could also encounter a warm Water cell immediately over a cold Oil cell across a storage chunk boundary, with no temperature field prepared for the destination. The second native commit checks the Water update stamp and prepares a destination temperature field on the owner for that contact. Regression fixtures exercise phase order, warm Water above cold Oil, paused cells, masks and Water quantities of 1 and 65,535.

## Protected source review

The Wave behavior changes. The material descriptors, density ordering and authored catalogue IDs stay the same. Each source commit precedes its compatibility entry.

| Protected source | Previous LF SHA-256 | New LF SHA-256 | Source commit |
|---|---|---|---|
| `native/src/world.cpp` | `fef05d7f0318f0a54948144ee22f30721555a567ac3963309c927b60fbfb0cf0` | `fd8052ee6630ee5c9a664ff30611eddcbf9d74ac88203ac5143bbc9a2bcb52fc` | `b8db73ce7d0f37c1a38690ea34749d1ccba3474b` |
| `native/src/world.cpp` | `fd8052ee6630ee5c9a664ff30611eddcbf9d74ac88203ac5143bbc9a2bcb52fc` | `c5b768aa5b2f80782f2c70327f8e267936bd0bc862f7fdcc72117d364e84bd0b` | `0b2a46cee3598ae8e6ce481167ff3f482f83580f` |
| `native/src/world.cpp` | `c5b768aa5b2f80782f2c70327f8e267936bd0bc862f7fdcc72117d364e84bd0b` | `9969471e50b6f462dcd62dd66c9986d453b037f71d84d21f14a50859c86bebaf` | `932a811c474de7f2720719f258a9fd38d8aecdfd` |
| `native/src/world.cpp` | `9969471e50b6f462dcd62dd66c9986d453b037f71d84d21f14a50859c86bebaf` | `ec3034850af97e790dfc3855411bba5be60c820cb623a6df62ca09c70aeb761a` | `461b1c1485418bcd8f83f29efe1cccf7ef4a9928` |
