---
title: SOL-DETACH-001 real native-tree implementation and qualification checkpoint
status: Current
document-kind: audit
scope: Exact 741bc077 experimental native ownership and Linux async Rapier proof, Windows native and sanitizer results, preserved failures and unpassed integration gates
canonical-for: [sol281-20261027-native-tree-evidence]
last-reviewed: 2026-10-27
related-documents: [../systems/solid-detachment.md, ../operations/soliding-structural-detachment-programme.md, 2026-10-27-issue12-stage3b-reassessment.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# SOL-DETACH-001 native-tree checkpoint — 2026-10-27

## Disposition and exact source

**Implemented experimental vertical slice; not full #281 closure or production
acceptance.** A real native-cell tree-shaped solid is cut, its exact payload is
transferred and a live compound Rapier body topples and moves horizontally on
contact. The [runtime contract](../systems/solid-detachment.md) owns limits.

- Main inspected: `c9ebe39c6cab086b7f7207ee3d80a6de2cb21f59`.
- Documentation parent: `c087ca8569f1df394d67cdc4dbe1c6b46c2bcfb2`, draft #282.
- Implementation branch: `work/sol281-native-detachment-20261027`.
- **Executed final source:** `741bc0775c190be98e2f5d23da3d47dd354fef99`;
  tree `8da1f7716e01811d91f30fe7e4c66574e0530363`.
- Qualification workflow trigger: `9ebd36f0f4514c536e7201543fd0c019a5a327c0`.
  Its assembly job verified the exact locally exercised source byte hashes,
  materialized the ordinary source changes, removed one-shot tooling and
  normally fast-forwarded the isolated branch to **741bc077**. Each execution
  job then explicitly checked out **741bc077**, not merely the trigger SHA.
- [Exact-source workflow 40592308871](https://github.com/techrote/cybersand/actions/runs/40592308871):
  assembly, Windows native, Linux ASan/UBSan, Linux actual native/Rapier and
  rendered-capture steps all completed successfully.

Temporary source assembly/preparation workflows and helper scripts are absent
from the final implementation tree. No main mutation, runtime replacement on
main, forced branch update, new default solver or material law occurred. Later
non-executable documentation commits do not constitute new engine executions.

## Hosted execution results

| Lane | Actual execution / result | Limits |
|---|---|---|
| Linux native | GCC 13.3.0, `make solid-detachment-test`: **8 groups, 13,074 checks pass** | Native receipt tests use synthetic body acknowledgements |
| Windows native | Real Windows-2022 MSVC compile and execution: **8 groups, 13,074 checks pass** | Not a Windows Godot/Rapier or graphical result |
| Linux sanitizer | GCC 13 ASan+UBSan: **8 groups, 13,074 checks pass** | `detect_leaks=0`, `UBSAN_OPTIONS=halt_on_error=1`; not TSan or whole-repository sanitizer acceptance |
| Linux live host | Godot **4.7.stable.official.5b4e0cb0f**, Rapier2D **0.35.2**: **21 checks pass** | Actual source-matched GDExtension, existing asynchronous native worker, real main-thread RIDs and manual Rapier stepping |
| Linux live failure paths | Same runtime: **20 checks pass** | Actual inactive body, native source retirement, wrong collision receipt, restoration, static repair and session-reset rejection |
| Linux rendering | Xvfb, GL compatibility, Mesa llvmpipe: four actual frame captures, all save outcomes zero | Render readback and visual inspection; not owner feel approval or target-hardware frame pacing |

The Linux GDExtension was freshly built from 741bc077 using the repository's
pinned build script and source-pinned godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`.
Its actual SHA-256 is
`48ddf4075e17b25c812440f8c1cb2ebcdb9a9b1eb856b56d9c23c7a2ec955b5f`.
The downloaded engine ZIP is checked against
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
The hosted artifact includes all native/adapter/script input hashes and the
exact source SHA. The old checked-in native binary is **not** promoted as
matching this new source. Formal release runtime publication remains open.

## What the real motion test proves

The authored fixture contains RedBrick trunk/crown/branch pixels, an actual
one-pixel hole, a Wall floor, a retained stump and an unrelated native control
structure. A 4×2 trunk cut is applied by the native diagnostic editing API.
The isolated component is **520 original native cells** and **6 exact compound
rectangles**; mass is 520 unit-cell masses and inertia is
70453.6493589743 in the declared cell-based units.

Prepared inspection observes all 520 original native members still present.
After commit it observes zero native source members and exactly 520
aggregate-owned members. Full member tuple comparison, not hash equality alone,
proves the material/state/temperature payload is retained during 600 real
Rapier steps. Source stump, ground and unrelated structure stay native.

| Observable | Hosted measured maximum |
|---|---:|
| Downward COM movement | 20.259220123291 cells |
| Horizontal COM movement | 25.6351585388184 cells |
| Rotation magnitude | 1.07524764537811 rad (approximately 61.6 degrees) |
| Angular speed | 1.27385640144348 rad/s |
| Rapier manual steps | 600 |
| Independently paced native ticks at final observation | 600 |

The body is placed once at its computed initial COM. Subsequent motion comes
from gravity and actual contact, not per-frame orientation assignment. The
motion includes toppling and horizontal/rotational contact response; this
single shape is not a universal sustained-rolling or dynamic-fracture proof.
The supported native configuration uses four workers; configured count and
real worker participation/performance are not conflated.

Rendered captures `tree-anchored.png`, `tree-tick060.png`, `tree-tick120.png`
and `tree-tick240.png` show the copied native image losing the source pixels
and the exact payload following the Rapier transform. The inspected 120-step
frame shows a roughly 44.8-degree angle, separated source stump and preserved
control structure. No mock picture is substituted for engine readback.

## Retained evidence identities

All three archives below were downloaded and their reported SHA-256 checked.
They belong to [run 40592308871](https://github.com/techrote/cybersand/actions/runs/40592308871).

| Artifact | ID | ZIP SHA-256 |
|---|---:|---|
| `sol281-linux-actual-741bc0775c190be98e2f5d23da3d47dd354fef99` | 12775605462 | `715ab3a1c60337b1c2bf5271eb3c37bb5b5eea85187abd25950644de60f0837c` |
| `sol281-windows-native-741bc0775c190be98e2f5d23da3d47dd354fef99` | 12774586889 | `eb5f6398a399b9d993d2ec530fab30d3b57efc3e74054dc2fbb6585e61b9b8d6` |
| `sol281-linux-sanitize-741bc0775c190be98e2f5d23da3d47dd354fef99` | 12774288832 | `0cc622e577031f44638b83659eefbecf04955a4bf8a29982d95717f8a1bcc1a1` |

The Linux archive contains `rapier.json`, live failure results, native/import/
build/render output, compiler/source/runtime/input manifests and four PNGs.
Its retention expires 2026-11-26; the other hosted archives report 2027-01-25.
These are scoped CI artifacts, not a published game release or indefinite
storage guarantee. The compact repository receipt retains the key identities
and measured results in `sol281-2026-10-27/receipt.json`.

## Earlier proof, repairs and preserved failures

- [Initial native run 40586880222](https://github.com/techrote/cybersand/actions/runs/40586880222)
  executed source `4669f448d4091b4491c552f8c6b695e57aed7467`:
  **7 groups / 10,976 checks**, real native World but synthetic bridge receipts.
  This is not the later live Rapier proof. Archive 12772246718 ZIP hash
  `fd3cd3e24a9aa981badf6b0fa532e4827040e6100fc5a41ab5b32ddbd070c1c0`.
- Review added revision reservation for **both commit and rollback**, not only
  commit, and corrected diagnostic accounting for partial restoration failure.
  Added exhaustion and failed-World tests produced the later 13,074-check suite.
- A local right-side-neighbour fixture physically obstructed the falling tree.
  It rotated only approximately 0.485 rad and failed the greater-than-0.7-rad
  free-topple assertion. It is retained as a blocked-fall control. The subsequent
  clear-fall scenario moves only the unrelated tree from x88 to x8; released
  geometry, force law and toppling threshold are unchanged. This fixture
  adjustment is disclosed, not a claim that the obstructed trial passed.
- A local rendered-scene attempt hit a GDScript typed-inference parse error;
  explicit `Vector2` typing repaired it before the retained hosted captures.
- [Workflow 40592095533](https://github.com/techrote/cybersand/actions/runs/40592095533)
  failed at workflow validation because a runner-context path was used at job
  environment scope; no test executed. Moving path construction into a runner
  step produced the successful successor run above.
- Local preliminary proof used GCC14.2/binutils2.44 and an explicit permitted
  toolchain-drift override. Its local native-extension hash was
  `73d667f0a2c21d5ab3d9db37b66257bd006d35d10d857e65aae6c5beced21c0a`.
  It is separate from the hosted pinned GCC13 runtime and is not release evidence.
- A broad local ordinary native suite was bounded at 240 seconds and did not
  complete. Many prefix tests ran, but the run is **incomplete, not a pass**.
  The focused source-qualified lanes do not replace full required PR gates.

## Explicit outstanding acceptance

1. Independent architectural/code review, exact-final-head full repository gates
   and formal source-matched release runtime publication.
2. Actual **Windows Godot/Rapier** host execution; Windows native C++ success is
   useful but not the whole requested desktop platform proof.
3. Compound native material occupancy/sweep/contact coupling. The dry fixture
   deliberately does not lie by sending the tree's filled AABB to the native
   body interface. Surrounding active powders/liquids remain unqualified.
4. Reactive Wood/bark and heterogeneous cohesion, continued aggregate chemistry,
   multiple objects, general structural discovery and full-application admission.
5. Supported dynamic rest/demotion or fracture beyond inactive-body cancellation;
   no arbitrary rotated body-to-cells restoration, aggregate saves or welding.
6. Owner visual/feel acceptance and representative cost/memory/frame-pacing
   measurements; this result neither closes #12 nor admits Stage 3B/4.

The [first feature issue #281](https://github.com/techrote/cybersand/issues/281)
therefore remains **open**. This checkpoint demonstrates concrete native
ownership and actual tree-like motion, while retaining the above production
and issue-acceptance boundaries.
