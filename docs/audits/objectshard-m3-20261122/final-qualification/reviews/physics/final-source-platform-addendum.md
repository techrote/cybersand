# Independent final ObjectShard M3 physics and presentation review

**Reviewed runtime source:** `e034f2294663e0485cfb9adcc8ada46a6e977cee`, tree `246e7324ca618d98c43a0ed54fe19bc86a155877`. **Disposition:** final exact-source and fresh Linux/Windows artifact review completed with no unresolved Class A/B finding in the reviewed supported experimental paths. Draft/HOLD remains. This addendum closes the fresh-platform-pending status in the immutable earlier local review; it does not replace the retained original negative evidence.

## Source, runtime and navigation evidence

The exact published local run completed 651 parent assertions across 10 suites plus 18 assertions in an actual quit child, 669/0. It included 52 independent actual-worker/Rapier physics assertions, 24 independent live-admission assertions, 49 independent navigation lifecycle/fence assertions, and maintained tests. That local run reused an input-equivalent native runtime; campaign 44999117090 separately built and exercised the final source on both platforms.

| Execution | Completed qualification cases | Navigation parent / actual quit child | Native runtime SHA256 |
|---|---:|---:|---|
| Fresh Windows source |41|135/0 +18/0|`05cc1f55d812b93462e73e7bc79f82d3f892d9f5b8fececc6a4753b705b3c651`|
| Delivered Windows ZIP rerun |32|135/0 +18/0|Same delivered DLL, exact manifest-bound ZIP|
| Fresh Linux source |41|135/0 +18/0|`64e67fc021a202f245fb5bdd49a21eb5394ea557147b68cf21053aa3432040dd`|

Every qualification case's natural completion and retained log hash was checked. Windows binds 186 unique Git blobs: 116 native inputs, 51 Lab inputs and 19 qualification-tool inputs. Linux adds five build-contract files, 191 blobs. The fresh Linux compile receipt/log and source provenance passed; Windows selected DLL provenance matches all 116 qualified native inputs. Actual owner ZIP engine, console launcher, DLL, Rapier, manifest and all 51 Lab files were checked. This review's raw artifact checks are repeated consistency assertions over stored rows, not additional runtime test cases.

The original 68235b12 F2 defect remains a retained Class B high-severity finding against that source: scene destruction orphaned a live native worker and real RIDs, allowed re-entry to overlap owners, and retained the wrong quit policy. The repaired controlled F2/window-close handshake waits for acknowledged disposal, joins the worker, releases RIDs, restores prior quit policy and fences deferred completion by scene identity. All three final execution locations passed the eight maintained lifecycle scenarios and real quit child. Direct externally forced scene replacement/free remains unsupported.

## Sustained physics and material outcomes

Each source-platform run and the delivered Windows rerun retains 44,819 raw rows, 3,599 completed intervals from native tick 1 to endpoint 3600, 14,388 acknowledged nonempty motion segments plus two empty physical steps, 14,390 physical steps total, and 540 accepted edits. All 540 action records remain present with a complete footer. Every nonempty segment has an ordered applied native motion receipt before another segment; accepted owner/session/generation/geometry/pose identities agree with completion records. The same-platform Windows source/package non-timing trajectories and native accounting match.

The three real bodies move about 19.977, 19.977 and 20.138 cells, report contacts and naturally sleep. The tick 2400 resting-owner erase updates owner 1 mass 490→489 and geometry revision 5→6. Subsequent maximum translation is about 0.000067919 cells and rotation 0.0000035882 rad on both platforms; final owners are sleeping. The raw rows support finite mass, COM, inertia and velocity, with consistent geometry and accepted-pose identities; the native quantity ledger is source-bound and is not reconstructed from a full per-cell history, which is not stored in every row.

| Evidence | Actual material outcome | Scope |
|---|---|---|
| Long three-body run |241 erases, 99 authored Sand, 100 authored Water, 100 authored Fire; chemistry creates 34 Fire and 10 Smoke and destroys 9 Wood |Zero Sand/Water ingestion and zero extinctions in this run|
| Separate maintained Lab fixture, 379/0 |Five World Sand cells become four World cells plus one cargo cell; carried tuple: material 2, states 0/0, temperature 200, incarnation 2 |Actual inventory-conserving Sand transfer; separate from long-run workload|
| Same maintained Water fixture |Water contact of 255 quanta extinguishes the same surviving Wood cell/incarnation; Water ingestion remains 0 |Liquid stays with World; source-bound outcome assertions|
| Separate naturally sleeping chemistry fixture |Burn state 237→227 across 10 sleeping opportunities; retained and World Fire/Smoke observed, geometry changes |Material chemistry continues during actual sleep|
| M3 worker pocket capture |498 structure + 1 Sand cargo, mass 499, 6 shapes, zero Water extinctions |Visible cargo is established; this image does not establish Water extinction|

## Matched pump timing and actual presentation

Within each platform, pump 0 and 4000 use the same 240 completed intervals/publication digests, native ledger, 60 live inputs and 954 physical steps. The requested callback cadence is 60 Hz. The table reports semantic progression and interval completion time; these are not display FPS.

| Platform / pump budget | Semantic intervals per wall second | Interval p50 / p95 / p99 / max (µs) | Actual pump p50 / p95 / p99 / max (µs) |
|---|---:|---|---|
|Windows / 0µs|8.25606|111588 / 128240 / 162415 / 178547|No pump|
|Windows / 4000µs|17.13821|49302 / 61659 / 64976 / 93344|5089 / 5795 / 5914 / 5996|
|Linux / 0µs|8.25643|113021 / 129686 / 163643 / 179800|No pump|
|Linux / 4000µs|16.60678|60587 / 65143 / 65395 / 80037|4046 / 4353 / 4455 / 4517|

The measured semantic progression ratios are 2.07583× on Windows and 2.01138× on Linux. The 4 ms budget is soft and checked between complete handlers: actual maxima are 5.996 ms and 4.517 ms. This rendezvous grants no extra native or physical time. No cross-platform bit identity or target-hardware performance is asserted.

The separate actual-rendered stress scene retains 153 original pointer intents/results on each platform, with captured≤admitted≤completed timestamps. Original input→result and scene-queue distributions were recomputed from retained values. Source-bound frame_post_draw instrumentation reports 153 input-presentation observations on each platform. The underlying per-present raw timestamp stream is not retained, so the presentation aggregates are not claimed to have been independently reconstructed from raw draw events.

| Platform | Presented publication observations | Input→presented p50 / p95 / p99 / max (µs) | Publication→presented p50 / p95 / p99 / max (µs) |
|---|---:|---|---|
|Windows|120|763739 / 1753913 / 1913506 / 1929452|11466 / 15277 / 27229 / 27254|
|Linux|90|786486 / 1702973 / 1838450 / 1838490|19161 / 25004 / 68162 / 68162|

These timings include deliberate backlog, stale-target and held-receipt cases; they do not describe normal steady play. Windows rendered through ANGLE/Microsoft Basic Render Driver; Linux through Mesa llvmpipe. The scheduling profiles deliberately do not call mark_presented. Actual rendered replay matches each platform's own trace: Windows 155 actions / 38 intervals, 387/0; Linux 155 / 39, 389/0. The scheduling-dependent difference is retained, not forced into a cross-platform equality claim.

## Rendered evidence and publication boundaries

All seven fresh worker PNGs on each platform were individually opened, visually inspected and matched to qualification hashes: supported Wood, actual falling owner, settled post-erase owner, large-structure priority with deferred offcuts, Sand pocket, actual external flame, and the 320×192 three-owner scene. The accepted external Fire fixture is 83 cells in this Windows capture and 84 in Linux. Those are authored flame counts, distinct from chemistry-created Fire.

The PNG and adjacent post-draw host report are separate observations. The source saves the image after frame_post_draw, then samples diagnostics. Windows priority shows native 7 / published 6 and a motion wait, while its later report is 7/7 Idle; the pocket shows 101/100 and a prepare wait, while the report is 101/101 Idle. Linux's settled PNG shows 471/470 AwaitingNative, while the later report is 471/471 Idle. The complete capture campaign records 120 continued host intervals after erosion; that does not make the earlier visible publication an exact 120-interval image. The audit stores visible HUD telemetry separately from backend bodies and does not substitute adjacent backend transforms as exact displayed poses.

The exact-source view path uses accepted publication material and pose together, without a live-RID override. Ordinary pointer targets come from view.frame. Maintained tests retain an older displayed snapshot while a newer accepted pose overlaps the same pixel: the stale target explicitly returns TargetChanged and leaves inventory unchanged, while the distinct fresh target removes exactly one cell. Delayed receipts preserve publication and physical-step counts. The independent actual-worker/Rapier probe separately exercises genuine withheld motion receipts; bridge-only unit fixtures are not represented as that full native-worker evidence.

## Retained record and remaining scope

No new Class A/B finding arose from the final source/platform review. The original F2 failure, no-cleanup leak logs, earlier harness failures, and editor-import SIGABRT/retry evidence remain preserved. The final exact-source first import and required local tests passed, followed by the fresh final CI builds and qualification runs. There is no physical Windows 11/NVIDIA owner acceptance, ordinary worker adoption, Ready/merge/default promotion or runtime publication established by this review.

The machine-readable addendum binds the detailed platform audits, all source/case log/trace/PNG hashes, exact reviewed source and retained original finding. Complete source and evidence claims remain in those files; this prose is a comparison guide.

| Review artifact | SHA256 |
|---|---|
|`build/review-physics/final-e034f229/review-final.json`|`092718bdf8f8e84d4255d75f36e208c96b46251ebb351be740b2c1707f4b0d8d`|
|`build/review-physics/platform-windows-final-e034-review.json`|`44dfd53ae642084864a5c24bdcd73ebbf4d42cfaa3e9f51156a8323c0f093166`|
|`build/review-physics/platform-linux-final-e034-review.json`|`7574e581ead459d245f6428e14e8eee507795b445bc4dc00002851060e514eda`|
|`build/review-physics/final-publication-source-review.json`|`7f323e30e63f6ce1f4eb94d0cc489f9f2af45e921f52a8e7031b2a44cd235593`|
