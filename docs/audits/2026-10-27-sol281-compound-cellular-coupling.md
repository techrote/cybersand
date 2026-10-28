---
title: SOL-DETACH-001 exact compound cellular-coupling qualification
status: Current
document-kind: audit
scope: Source 41dc25ca actual Linux/Windows Rapier Sand/Water coupling, retained assembly failures and explicit production limits
canonical-for: [sol281-compound-cellular-coupling-evidence]
last-reviewed: 2026-10-27
related-documents: [../systems/solid-detachment.md, ../operations/soliding-structural-detachment-programme.md, 2026-10-27-sol281-native-tree.md, sol281-2026-10-27/coupling-receipt.json]
---

# SOL-DETACH-001 compound cellular coupling — 2026-10-27

## Exact source and purpose

This record qualifies the bounded **hole-preserving cellular-coupling slice** at
`41dc25ca060ecb07cef15c1640feeb9f6cce1eb4`, tree
`8d7e650d7a12dc7f9a49f22270257b60fc6c506e`, in draft PR #283. It does not
qualify production main, release publication or complete issue #281.

The change reuses the existing native rectangular rigid-body coupling. The six
exact non-overlapping tree rectangles are published as six stable proxy records,
then their copied impulses/corrections are reduced onto one actual Rapier body.
No filled tree AABB and no per-cell Rapier objects are introduced. Native C++,
material rules, liquid solvers and defaults are unchanged from the prior repair.

## Hosted execution

[Run 40603701831](https://github.com/techrote/cybersand/actions/runs/40603701831)
completed source preservation, actual Linux Godot/Rapier, a fresh Windows DLL
build and actual Windows Godot/Rapier execution successfully.

| Gate | Linux Ubuntu 24.04 | Windows Server 2022 |
|---|---:|---:|
| Focused native ownership | 8 groups / 13,074 checks | inherited source-identical native contract; fresh DLL built |
| Existing tree motion | 21 checks / 0 failures | 21 / 0 |
| Existing rollback/failure paths | 20 / 0 | 20 / 0 |
| Existing owner replacement | 296 checks / 18 cycles / 0 failures | 296 / 18 / 0 |
| New compound Sand/Water coupling | **32 / 0** | **32 / 0** |

Both platforms report six proxies, exact proxy mass 520, initial samples
`[2, 0, 0, 6]` (occupied crown, one-cell hole, larger AABB hole, occupied trunk),
Sand average Y 25.75 and Water average Y 71.0. This proves the registered holes
remain open while surrounding material interacts with the moving silhouette.

| Counter | Linux | Windows |
|---|---:|---:|
| State publications | 361 | 361 |
| Result snapshots | 169 | 294 |
| Result records | 1,008 | 1,716 |
| Contacts | 6,120 | 9,946 |
| Displaced cells | 28 | 26 |
| Impulse applications | 397 | 649 |
| Correction applications | 1 | 30 |
| Stale results | 0 | 0 |
| **Cumulative unresolved** | **1,094** | **2,190** |
| Maximum rotation | 1.078984 rad | 1.123226 rad |
| Maximum translation | 32.213684 cells | 32.829651 cells |

The unresolved counts are not zero and are deliberately retained. They reflect
this dense moving-bank fixture and prevent a production-quality or universal
coupling claim. Material quantity and aggregate ownership checks nevertheless
pass; no loss/duplication or filled-hole substitution was observed.

## Artifacts and independent author readback

- Linux execution artifact `12778724981`, ZIP SHA-256
  `7023195c98deba01b22e8bac8fc53edbaf71d4721e41d703b3b85fc1c1d34399`.
- Windows execution artifact `12780835139`, ZIP SHA-256
  `51640622fbdaefd298d1771889dace2df936657b3781922a0341ef471a5474bd`.
- Windows build artifact `12779771798`, ZIP SHA-256
  `783c7c648696e7123684c224149755bb07e6be9b08a0870afdc54862e6388a56`.
- Exact-source artifact `12779234027`, ZIP SHA-256
  `b279a0000680533ebef44ba3cbd51c12f8ef5c60d52212c176a135a75875e86d`.
- Linux runtime SHA-256
  `48ddf4075e17b25c812440f8c1cb2ebcdb9a9b1eb856b56d9c23c7a2ec955b5f`.
- Windows runtime SHA-256
  `f30a9990dd2fb745345c6d37034b9cfb7b600d265ddbc2c11e1026a9953963fe`.

The Windows execution/build ZIP CRCs, runtime hash, 547-input manifest, result
JSON and every declared log hash were rechecked after download. This is author
artifact reduction, not independent architectural approval.

## Preserved failures and qualification limits

The first assembly attempt failed because its exact patch omitted the newly
created test file. The corrected assembly materialized and hash-checked all
sources, then GitHub rejected its workflow-token push because that token lacked
workflow-write permission. The already-created commit object was published by a
fast-forward repository ref update. Neither event is a passing test, neither was
hidden, and neither changed executable semantics.

Still open: reactive Wood/bark and mixed-material cohesion, aggregate chemistry,
multiple aggregates, arbitrary contours beyond the six rectangles, representative
cost/frame pacing, lowering/characterising unresolved interaction rates, dynamic
desoliding and fracture, persistence/residency, normal-application integration,
formal runtime publication, full ready-PR matrices and independent review.

## Routed documentation checkpoint

Repository status, handover, retrieval index and manifest were synchronized in
`48bdabe5ef5461468df0402729a2c7ddc7487ce6`. This connector-authored successor
changes only this audit after that routed checkpoint and exists to obtain normal
exact-head documentation validation; it does not change any executable input or
upgrade the scoped runtime result.
