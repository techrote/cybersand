---
title: PF471 independently reviewed in-chunk neighbour cursor source transition
status: Approved design
document-kind: audit
scope: Explicitly reviewed legacy World source update, source-pinned exactness and native-tick performance; no merge or runtime publication
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [2026-11-06-fast-neighbour-cursor-independent-qualification.md, 2026-11-04-mat-auth-reviewed-transitions.md, ../operations/material-catalogue-shadow.md]
---

# PF471 — reviewed, source-pinned `world.cpp` per-file transition

**Current status: prepared in a separate Draft PR for compatibility qualification, not merged or released.** The original cursor implementation lives in [#471](https://github.com/techrote/cybersand/pull/471); implementation qualification, focused tests and the present guarded transition are held in independent [Draft #477](https://github.com/techrote/cybersand/pull/477). The source-review issue is [#485](https://github.com/techrote/cybersand/issues/485).

| Required authenticated field | Reviewed value |
|---|---|
| `path` | `native/src/world.cpp` |
| `from_lf_sha256` | `5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d` |
| `to_lf_sha256` | `bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868` |
| `source_commit` | `b51f01536db6408458442c532d75256d33422fba` |
| `record` | `docs/audits/2026-11-07-pf471-reviewed-world-transition.md` |
| `issue` | `485` |
| `pr` | `471` |

**Ancestry:** Source introducing the exact new bytes is one commit after accepted #406 baseline `4a80af2a891332176a3912a235582d77d076a185`; its most recent admitted `world.cpp` predecessor is `0b408ae97c061d7263a3322022429aa32a0385a6`. A separate direct Git comparison establishes the predecessor as an ancestor of the new source commit and the source commit as an ancestor of both #471 and #477. The current code-pinned reviewed-transition chain for `world.cpp` ends at exactly the `from_lf_sha256` above. Only the new transition entry permits the `to_lf_sha256`; the retained `BASELINE` and immutable `materials/catalogue/compatibility-lock.json` are unchanged.

## Source-review outcome

[Independent review on #485](https://github.com/techrote/cybersand/issues/485#issuecomment-6699706678): **ACCEPT for preparation of a reviewed source transition.** The same-chunk cursor checks transient body masks on each visible read; bounds unsigned-safe signed deltas and indices to the source chunk; returns current material values rather than caching them across writes; falls back to unchanged `stored_material` at chunk/missing boundaries. Chunk pointers remain valid under `unique_ptr` ownership during phased work. The protected change does not modify native material identity, state/epoch semantics, movement/writes, reactions, thermal sources, PressureFlow/inertial sidecars, physical hashes, persistence or scheduling authority. All 35 removed and 87 added `world.cpp` lines were inspected against original `World::get` semantics.

## Executed qualification

- [Owner-side exact-head Native + full cursor-oracle, ASan/UBSan and TSan](https://github.com/techrote/cybersand/actions/runs/42313096990): **188 native, 188 oracle, 188 ASan/UBSan and 188 TSan tests passed**, signed-mask 96-tick adversary plus ABBA hash/work parity.
- [Independent focused signed/non-power-of-two/mask/epoch exactness](https://github.com/techrote/cybersand/actions/runs/42312672077): 16 source×worker 520-tick replays, eight full ASan/UBSan focused replays, two six-worker TSan focused replays, **all state/physical/content checkpoints and deterministic work identical**.
- [Balanced 600-tick parent/cursor performance](https://github.com/techrote/cybersand/actions/runs/42303273494): six paired cycles and 24 actual measurements; 1-worker mean **+4.14%** (95% paired CI **+1.51..+6.77%**), 6-worker mean **+2.24%** (CI **−0.29..+4.78%**), with all checkpoint hashes and work exact.
- [Sustained 1,800-tick six-worker comparison](https://github.com/techrote/cybersand/actions/runs/42313589873): 12 runs, six balanced pairs. Total tick **41.775095 ms baseline → 40.655751 ms cursor**, **+2.6771%** paired mean (95% CI **+2.0865..+3.2677%**); activity-grown ticks 1201–1800 **+2.5714%** (CI **+1.7409..+3.4018%**), all hashes and deterministic work identical.
- [Source-neutral Callgrind function and line profiles](https://github.com/techrote/cybersand/actions/runs/42314416637): same 16 early single-worker ticks, **14,690,762,574 → 13,828,652,071 executed instructions (−5.8684%)**, with identical native state/work. Distinguish instructions from elapsed tick speed.
- Source-derived Godot stress-canvas fixture: 119 authored stamps → **129 exact** merged rectangles; no differences in the complete 2048×1024 material raster.

These measurements show a genuine, statistically supported *modest* gain, not the original aspirational 5–10% whole-tick target. The hosted performance runner exposed four logical CPUs with six workers oversubscribed, so no six-physical-core/12-thread target-host result or Godot/Rapier gameplay FPS improvement is claimed. Native Linux `perf` was refused by `perf_event_paranoid=4` on this host; the separate Callgrind evidence is valid only for instruction-level attribution. A true 6-core/12-thread repeat remains useful but is not misrepresented as having been executed.

## Admission/merge boundaries

The **new** compatibility entry is a scoped per-file `REVIEWED_TRANSITIONS` record, not a baseline refresh. No identity input, generated catalogue file, policy contract, immutable compatibility lock or unrelated producer/consumer may be altered to pass it. The repository's `compatibility.py` checks exact protected bytes, source ancestry, reviewed record existence and lock authenticity; these checks must be executed against the resulting exact HEAD and its GitHub synthetic PR merge ref.

At this stage this is an **ACCEPT FOR FURTHER ADMISSION** *engineering decision*, **not production or merge authorization**. Keep #471 and #477 Draft/unmerged; no runtime publication. Any eventual merge must preserve Git ancestry (merge commit, never squash/rebase), pass exact-head documentation/provenance, native and applicable Godot validation, receive owner approval of the smaller performance gain, and independently reconcile current main. A further source edit requires a new reviewed step.

For the full raw evidence, commands, machine/CPU details, failures and per-run counters, see [the independent qualification audit](2026-11-06-fast-neighbour-cursor-independent-qualification.md).