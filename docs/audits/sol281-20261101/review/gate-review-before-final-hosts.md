# SOL-DETACH-001 — independent acceptance-gate review

Review cutoff: **2026-11-01 17:29 UTC**. Reviewer: `native_core` agent. This is a read-only reconciliation of the issue requirements, current audit, implementation, prior independent review and already available execution evidence. No shared source, runtime or workflow was changed by this review.

## Disposition

**The implementation is a functional, reviewable bounded increment. Issue #281 and the broader #12 milestone remain open.** The recovered native tree and the new conservative displacement transaction have source-matched Linux execution evidence, including a GitHub-hosted run. The first complete two-platform attempt failed because all Windows cohorts refused the checkout before Godot execution. A corrected-source rerun is required; the first attempt cannot qualify that later source.

Dense granular resistance/acceptable penetration, representative GPU pacing, accepted-GCR integration, transformed active restoration, fracture and normal gameplay are not passed. Independent code review is complete for its stated surfaces and repaired findings; it should no longer share a generic “pending” status with GPU acceptance. Unexpected native commit-exception injection remains untested.

This reviewer implemented the native detachment/transaction files. The host ownership review was independent of the Godot session/worker/render/bridge authorship, and the physical/transaction review was performed by the separate `displacement_review` agent. This report is not an independent review of the reviewer's own native implementation.

## 1. Source and evidence boundaries

The live [issue #281](https://github.com/techrote/cybersand/issues/281) was re-read through GitHub. Its original six implementation requirements and separate evidence gates remain in force beneath the historical updates. [Issue #12](https://github.com/techrote/cybersand/issues/12) and the canonical `docs/operations/soliding-programme.md` retain the larger reversible representation programme. The current audit read for this review is `docs/audits/2026-11-01-sol281-current-main.md`.

| Evidence set | Exact source and runtime | What it establishes |
|---|---|---|
| Initial source-matched local Linux | Source `c8c81a8b81677abd173de199a9d436f46de2268b`; tree `214f927af0e9feeb65c664e981b32b7fbc15e39b`; native runtime SHA-256 `7cd91126f1c59f8b43e7e93f56f916f5dc4ec009f9f92e6bac298b1555d5426e`, 4,302,552 bytes | Core, contact-w1 and contact-w4 all pass; source and raw checkout inventories unchanged. Local contact processes overlapped, so these runs are functional evidence, not comparative timing acceptance. |
| First GitHub-hosted attempt | [Run 41329746261, attempt 1](https://github.com/techrote/cybersand/actions/runs/41329746261), same source/tree as above; hosted Linux native SHA-256 `d556a9d615840761f5c0a4a6a14c39fa62e154c95a11ae16014cdca09bfb7a63`, 4,302,552 bytes | Both platform builds succeeded. All three Linux host cohorts and focused Linux native/sanitizer tests passed. All Windows cohorts failed before Godot. Reducer failed; runtime publication skipped. |
| Corrected source observed at review cutoff | HEAD `8e86ffd4eb2eb769178808a1012701076e3a4d19`; tree `b1f965508b24f9b10658907fff26cf1165e2d520` | Adds Windows checkout repair, qualification regression and preserved first-attempt records. Its complete source-matched platform qualification is **pending**, regardless of unchanged native/host implementation files. |
| Earlier graphical smoke | Local source `dd18bca6`; matching source tree preserved by remote implementation commit `83a12466`; original complete identity remains in the graphical receipt | Real dry/mixed rendering under Xvfb and Mesa/llvmpipe. It establishes usable visual presentation at its own source, not representative hardware GPU frame pacing or acceptance of a later source. |

Both local and hosted Linux use Godot `4.7.stable.official.5b4e0cb0f`, executable SHA-256 `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`, pinned archive SHA-256 `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`. Rapier is SHA-256 `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`, 117,275,416 bytes; release lock SHA-256 `df24cf6fb1adc17b2c1675b1387db19c93ee31d6cbf497c9295647ec98371285`.

The local and hosted native runtimes are distinct build artifacts. Equal sizes and the same declared source do not authorize replacing either runtime hash with the other. A later publication or documentation commit must continue to name the actual compiled/executed source.

### Original evidence reopened

Repository-relative first-attempt root:

`docs/audits/sol281-20261101/hosted/c8c81a8b81677abd173de199a9d436f46de2268b/first-attempt/`

| Record | SHA-256 | Disposition |
|---|---|---|
| `linux-core/report.json` | `f82f460c412ccb0d4f6659b74820383e8495726133988cc283331e067ef0779b` | 11 scripts passed: 502 structured assertions plus four ordinary regression scripts whose reports do not expose an assertion count. |
| `linux-contact-w1/report.json` | `3a1d62f9b8666593de3fc8c22d0554e8a188df3304e5ee710c5e367e4498dcb8` | Nine cases / 417 assertions passed. |
| `linux-contact-w4/report.json` | `71cc71f5915764a1a41f0b6fb55fa84b5c2a3b9f202d5bd8bb25fc48a841ca72` | Nine cases / 417 assertions passed. |
| `windows-core/report.json` | `33f0c3737575021aa492051dfde1a04bd6ba58518fbbea029921eb0765b922fd` | Source validation failed; zero physics cases executed. |
| `windows-contact-w1/report.json` | `dce1c308e888d7c2cf3bd4111017c49650f79a49e4cb85660e465a631699eddd` | Source validation failed; zero physics cases executed. |
| `windows-contact-w4/report.json` | `824b34ae1b9f7d4cdd526894cdc889905e34a72a9cf579680f50e24e59a6f022` | Source validation failed; zero physics cases executed. |

All Linux case processes in these reports completed naturally with exit 0, no recorded failures or skips, and unchanged canonical/raw source inventories. Total: **1,336 structured assertions**, plus the four ordinary scripts. Do not call 1,336 the complete assertion count of every script.

GitHub job API was independently re-read for run 41329746261. The Linux build job `124917146138` also reports 19,338 detachment checks and 281 displacement checks, each passing normally and under ASan/UBSan. Windows build success is cross-compilation, not an executed Windows native test suite. Windows core job `124919826818` records `Checkout .gitattributes differs from Git` before engine launch. The other two Windows reports record the same refusal. The exact source gate worked; this is neither a Windows physics failure nor a Windows physics pass.

Local original reports are outside the repository under `/workspace/scratch/59ce0c87fdea/evidence/sol281-local-guarded/`:

- `core-c8c81a8b-approved/report.json`: SHA-256 `1ff1c205b7ddbb976bc73d0ca6f4d1bdb1be160aebdc7d7a0641ddb650fc791c`.
- `contact-w1-c8c81a8b/report.json`: SHA-256 `63c180672d5008b2d1b86d0309c6cb2722aca3635383d46e0e3fa3818b8c1cc7`.
- `contact-w4-c8c81a8b/report.json`: SHA-256 `b4b59c0d8eb7da1b62404041159b9f862ba764b2877485b13ea480cd0176ac15`.

The local sandbox/editor-socket failure is separately preserved. It is not silently replaced by the subsequently approved successful local run.

## 2. Precise gate disposition

“Passed — scoped” below means the specified source and bounded fixture passed. It does not mean the corrected-source rerun or the whole milestone passed. “Not tested” includes a pending execution gate; “explicitly deferred” describes functionality excluded from this increment, not a claim that the original requirement disappeared.

| #281/user acceptance gate | Disposition at cutoff | Evidence and exact boundary |
|---|---|---|
| Reconcile accepted main, preserve frozen history and current production rendering | **Passed — source review** | Fresh branch from main `809fd30d`, fast-forward to accepted `a8f08a67` before first implementation commit; #344 and accepted PLAY #331 retained. Frozen #283 `254235ec…` and unmerged #282 are not repurposed. Native/host kernel port is selective. |
| Genuine initially native tree, anchored control and actual support edit | **Passed — scoped Linux/native** | Real RedBrick source, explicit applied trunk cut, exactly 520 eligible cells. Actual host `motion-w1/w4` each 22 checks; populated cases also verify intact `Anchored` refusal before release. This is a diagnostic cut-and-discover command after a real edit, not a general automatic trigger after every gameplay edit. |
| Bounded connectivity, anchor classification and safe uncertainty/capacity refusal | **Passed — focused native scope** | Four-connected homogeneous ambient Wall/RedBrick, one fully resident/included domain up to 64×64, at most 1,024 members, bounded shapes/proxy interval. Unknown edge, unsupported/hot/reactive material, foreign masks, stale source and exhausted capacity refuse. Sand/ordinary Water remain noncohesive native neighbours; no global support solver is claimed. |
| Exact material/state/temperature and one representation owner | **Passed — scoped native and Linux host** | Exact captured tuples survive prepare/commit/active/rollback; source is native until commit, then empty while aggregate owns 520 tuples. Motion/populated tests compare full aggregate payload, not only a digest. No simultaneous live terrain/body authority during admitted handoff. |
| Static collider retirement, inactive rollback and collision refresh | **Passed — scoped Linux/native** | No Rapier step during handoff; activation follows source retirement and collision receipt. Failure suites each 40 checks include inactive restoration/static repair. Terrain test verifies real excavation followed by renewed fall. No general active transformed restoration is established. |
| Correct exact compound geometry, holes, COM and inertia | **Passed — bounded fixture** | One Rapier body, six rectangles, two holes; native geometry checks plus actual compound mask/shape probes (33 coupling checks per worker). Native unit-cell mass/COM/inertia calculations remain exact for admitted members. No per-cell Rapier objects or filled bounding box. |
| Gravity-driven fall and rotation/toppling | **Passed — dry Linux fixture** | 600 Rapier steps: maximum downward translation 20.259220 cells, horizontal translation 25.635159 cells, rotation 1.075248 rad and angular velocity 1.273856 rad/s, workers 1 and 4. Initial placement is the only authored pose; subsequent movement is actual Rapier motion. |
| Plausible impact/rolling and attributable off-centre torque | **Passed — narrow motion/torque controls; full physical quality unpassed** | Actual response suite 33 checks includes off-centre angular response and rotated offset. Dry motion test checks horizontal displacement after contact, not a no-slip rolling ratio or dense-bed plausibility metric. Torque is applied at proxy centres at compound resolution, not exact per-cell contact locations. |
| Ground, stump, unrelated structures and noncohesive controls remain native | **Passed — scoped** | Motion tests probe retained ground/stump/control tree; native tests verify surrounding tuples/hole cells and anchored controls. General leafy/reactive-Wood semantics are not implemented. |
| Deterministic active-material replay | **Passed — scoped native/actual adapter** | 17 cases / 292 checks on workers 1 and 4, four accepted analytical boundary controls and thirteen mutation-free refusals including preserved source-pinned historical contacts. These are frozen-geometry transactions, separate from asynchronous full-host trajectories. |
| Physically admissible bounded local displacement | **Passed — bounded parcel/geometry/ownership invariant** | At most four one-cell cardinal parcel moves into an existing vacancy, no cycles, exact expected tuples, source lease/mask, resident/included destinations, full-square proxy clearance and fixed scratch/touched capacity. Native no-allocation and thermal-preflight gates pass. This is exact material conservation, not calibrated momentum/energy conservation or a bulk granular solver. |
| Packed, partially embedded and mixed Sand/Water actual interaction | **Passed — execution and quantities only** | Both policies in all three environments, workers 1 and 4, run on actual Linux Godot/Rapier. Six candidate cases accept 351 transactions / 778 parcel moves in first hosted Linux. Exact Sand counts and Water mass retained. Tests do not enforce a penetration or bearing-resistance threshold. |
| Dense granular resistance and acceptable penetration | **FAILED / NOT PASSED** | Remaining visible penetration and weak current-main response are acknowledged. Candidate motion/unresolved totals vary and do not establish improved physical quality. No acceptance threshold or demonstrated dense-rest bearing criterion has passed. Preserve this as a negative gate even if all current tests return success. |
| Multiple contacts do not duplicate displacement or impulses | **Passed — bounded regression/source scope** | All accepted path coordinates are reserved per sample; repeated/stale/invalid/mixed compound responses refuse. Compound modular forward progression closes N,N−1,N replay and wrap controls. No extra reaction is applied for intermediate relocated parcels. This is not an exhaustive concurrency proof. |
| Stale revisions, worker replacement, cancellation, reset and interrupted ownership transitions | **Passed — tested Linux/native cases** | Lifecycle 328 checks / 20 actual replacements at ten await boundaries across workers 1 and 4. Active reset/scenario routes refuse while preserving exact payload/token/RID; full session reset joins and retires owners together. Failed publications latch Rapier stopped. |
| Unexpected commit exception/quarantine containment | **Passed — source review; direct fault injection NOT TESTED** | H4 return guards prevent further masks/forces after failed World and route to the existing failure publication. H2 host tests inject the actual failure publisher, not an unexpected native commit exception. Ordinary native capacity-failure execution is a separate control. |
| Excavation below detached/resting aggregate changes support | **Passed — scoped Linux fixture** | Terrain-w1/w4 each eight checks, real native support removal and collision refresh, subsequent fall about 304.692/308.192 cells respectively. This proves excavation response, not a desirable penetration bound or zero-latency collision publication. |
| Source-matched Linux native plus actual host, workers 1 and 4 | **Passed at c8c81a8b only; corrected-source rerun pending** | Both local guarded and first hosted evidence exist, with distinct runtime hashes. Normal/sanitized native checks and 1,336 structured host assertions pass. No later source is relabelled as executed. |
| Actual Windows Godot/Rapier, workers 1 and 4 | **NOT TESTED for this implementation** | First attempt refused source validation before engine execution. Fresh pinned Windows runtime build succeeded, but does not close actual-host qualification. Corrected-source Windows execution remains required. |
| Complete two-platform qualification and runtime publication | **FAILED first attempt; corrected-source gate PENDING** | Reducer correctly rejected incomplete Windows evidence and skipped publication. Do not describe source `c8c81a8b` as globally qualified. A successful new complete run and provenance publication can later update this row without rewriting the first attempt. |
| Safe rest/fragment/desolid lifecycle after actual motion | **Explicitly DEFERRED beyond retained aggregate/inactive rollback** | Inactive rollback is tested. Active transformed body-to-cell restoration, destination admission after motion, coherent fragment lifecycle and repeated release/restoration are not implemented. Ordinary retained aggregate/sleeping ownership is only an intermediate state. |
| Reactive Wood/bark and heterogeneous cohesion | **Explicitly DEFERRED** | Eligibility is intentionally ambient inert homogeneous Wall/RedBrick. Unsupported/reactive regions refuse rather than silently gaining rigidity. |
| Arbitrary fracture, fragment inherited motion, aggregate persistence/multiplicity | **Explicitly DEFERRED** | General fracture is downstream in #12. Unsupported aggregate save/state-hash paths refuse; no persistence pass or universal resolding. One aggregate only. |
| Current-main GCR independence and later accepted candidate integration | **Independence passed by source review; integration NOT TESTED / deferred until accepted candidate** | Current-main contact law remains control, no competing branch edits and no duplicate friction/impulse owner. GCR candidate branch's ownership and registered results remain separate. The user's Y-family preference is not evidence that combined-source physics has been qualified. |
| Playable lab, controls and actual rendered review | **Passed — diagnostic presentation at recorded graphical source** | Native cut, pause, reset, worker choice, dry/packed/embedded/mixed selection, excavation and inspection are provided. Existing Xvfb/llvmpipe captures expose dense penetration. Normal launcher integration and owner physical acceptance remain deferred. |
| Worker/native cost, allocation, main sync and collider refresh accounting | **Measured within limited headless scope; performance acceptance NOT PASSED** | Native admission/no-allocation gates and bounded capacities are verified; actual host reports retain sampled worker/native, main sync, Rapier and refresh costs plus direct-process resource measurements. Sampled totals are not every native tick; local concurrent processes are not timing controls. No broad scalability claim. |
| Representative interactive GPU frame pacing | **NOT TESTED** | Software OpenGL rendering and headless CPU timing cannot qualify representative GPU FPS or pacing. |
| Independent final implementation review | **Passed — specified source surfaces, scoped disposition** | Physical/transaction review and host review resolved significant findings; H1–H4 closed at source level. H1/H2/H3 have source-matched Linux host regressions; H4 direct exception injection remains untested. Principal implementer retains final integration acceptance. |
| Final-source docs/provenance CI, draft PR and owner approval | **PENDING at cutoff** | The bounded draft deliverable must retain actual execution/build identity and complete required metadata checks. Full ready-for-review CI is not implied by the focused workflow. No merge authorization, no #281/#12 closure. |

## 3. Physical results that must remain visible

The first-hosted Linux candidate/baseline readbacks below are measurements of independently paced real hosts at source `c8c81a8b`. They are **not** a frozen-contact causal A/B comparison and are not identical to the separately recorded local runs.

| Workers / environment / arm | Candidate chain transactions / parcel moves | Maximum translation, cells | Maximum rotation, rad | Main-consumed unresolved contacts |
|---|---:|---:|---:|---:|
| 1 / packed / candidate | 72 / 170 | 46.974 | 1.206663 | 16,631 |
| 1 / packed / baseline | not enabled | 43.050 | 0.989192 | 23,339 |
| 1 / embedded / candidate | 108 / 233 | 31.911 | 0.450543 | 28,218 |
| 1 / embedded / baseline | not enabled | 36.381 | 0.529202 | 25,704 |
| 1 / mixed / candidate | 25 / 52 | 37.360 | 0.957764 | 38,345 |
| 1 / mixed / baseline | not enabled | 48.824 | 1.140686 | 15,059 |
| 4 / packed / candidate | 18 / 36 | 37.310 | 0.995725 | 36,843 |
| 4 / packed / baseline | not enabled | 46.800 | 1.072592 | 8,622 |
| 4 / embedded / candidate | 45 / 82 | 37.672 | 0.990893 | 54,851 |
| 4 / embedded / baseline | not enabled | 31.709 | 0.436084 | 23,106 |
| 4 / mixed / candidate | 83 / 205 | 40.344 | 0.670969 | 10,775 |
| 4 / mixed / baseline | not enabled | 46.923 | 1.098464 | 12,060 |

Every arm retains Sand exactly: packed 1,176; embedded 2,016; mixed 658. Mixed Water mass remains 132,090; the other two environments contain zero Water. Full original aggregate tuples remain equal to the captured source. These checks establish quantities and structural payload retention. Ordinary Water/granular evolution remains active, so one should not claim every surrounding cellular state remains constant throughout a host run.

The accepted counts exceed one parcel per transaction in aggregate in every candidate environment. Unlike the archived two adjacent one-parcel successes, this is actual host admission of multi-parcel transactions. It does not demonstrate that the mechanism solves fully buried contacts. Across all six candidate readbacks there are 259,234 classified attempts: 351 applied, 176,166 capacity refusals, 53,935 `ForeignOccupancy`, 28,494 `GeometryBlocked`, 128 unsupported-material and 160 `NoVacancy`. All other final outcome counts, including quarantine and native-transaction refusal, are zero in those runs.

Those labels require careful interpretation. `Capacity` includes the fixed 64-search per-sample admission budget. `ForeignOccupancy` covers any masked destination, including the aggregate's own compound/swept mask, not only unrelated bodies. Final failure attribution uses a priority among multiple encountered blockers; per-probe geometry/occupancy/material counters are different populations. Therefore the small final `NoVacancy` count does not overturn the archived strict-route census or prove its dominant blocker solved. Native cumulative transaction counts also need not equal the main thread's sampled consumed displacement count.

The native/adapter rule is physically bounded and conservative in material ownership: each parcel advances one adjacent cardinal position, geometry is preflighted, and no matter is removed on safe refusal. Mechanical energy/momentum conservation, bearing adequacy, tangential friction/yielding calibration and dense penetration are separate and unpassed. The fixture retains a 3.0 aggregate impulse cap, 0.5 correction cap, 0.094 gravity scale and 0.04 damping; their adequacy for a 520-unit aggregate is not established by these passing checks.

## 4. Required audit/documentation corrections

1. **Update the validation ledger without overwriting its checkpoint.** Label the existing table as initial iteration evidence, then add a source-specific current table: local Linux source `c8c81a8b`, first hosted source `c8c81a8b`, and repaired-source retry. Do not keep “full focused host matrix pending” as the only Linux statement after the complete first-hosted Linux matrix passed.
2. **Avoid globally calling the failed attempt “qualified source.”** The current first-attempt paragraph begins “qualified source”; change this to “attempted qualification of source” or “ran at source.” Immediately retain Linux success, all three Windows pre-launch refusals, failed reducer and skipped publication. The current preservation paragraph otherwise correctly records the failure and narrow EOL repair.
3. **Replace the stale #281 gate table using scoped dispositions above.** Linux motion, ownership/failure, compound geometry, excavation and replay have actual host results now. Windows and repaired-source combined qualification remain pending. Split combined gates whenever one subgate passes and another does not.
4. **Split independent review from GPU pacing.** The current last row says “Not tested / review in progress.” Source-level review is complete with repaired findings and source witnesses; representative GPU pacing remains not tested. Retain the explicit H4 no-fault-injection qualification.
5. **State the exact physical limit beside populated “pass” counts.** Fourteen checks per populated case assert quantities, full aggregate ownership, contact presence and some motion. There is no penetration, bearing, resistance, dense-rest stability or plausible-roll threshold. Dense resistance remains failed/unpassed, including in a future all-green two-platform run.
6. **Keep rolling language proportional to its test.** The dry host proves natural translation and rotation through impact plus horizontal displacement. Its rolling assertion is a displacement threshold, not a calibrated no-slip or sustained rolling criterion. The compound response tests establish attributable torque at proxy-centre resolution.
7. **Distinguish state preservation by transition from ordinary material evolution.** Exact tuples are conserved through the native handoff and each admitted transaction. The populated asynchronous test conserves Sand count/Water mass and full aggregate payload; it does not prove an unchanged whole-world state tuple multiset while the ordinary solvers advance.
8. **Preserve all source/runtime identities separately.** Local guarded `.so` is `7cd91126…`; first-hosted Linux `.so` is `d556a9d6…`; new build artifacts require their own identities. Publication commit must continue to identify its actual build/execution parent. Do not reattribute earlier smoke, first-hosted Linux, or unchanged implementation code to a newly qualified complete source before execution finishes.
9. **Retain old negatives and new negatives together.** B=289 stays NO-GO; 8,084/7,892 strict-route results and #338 two one-parcel successes retain original sources. The new SAT rejection, first Windows checkout failure, local sandbox failure, fixture-setup failures and current dense penetration remain visible. No renewed radius-tuning inference follows from capacity or final refusal labels.
10. **Make pending final delivery gates concrete.** After the corrected-source workflow completes, cite its run/attempt, both actual host platforms, both worker counts, reducer result and exact runtime/provenance artifacts. If it fails, retain the failure and publish the largest correct bounded increment honestly. Source-matched Windows, final metadata CI and runnable provenance must not disappear under a general “draft” exemption.

## 5. Suggested final claim

At the present cutoff, an accurate engineering claim is:

> The branch implements actual 520-cell native structural detachment into one six-shape Rapier body and a bounded conservative Sand/Water displacement transaction. Source-matched Linux native, sanitizer, deterministic replay and actual-host ownership/motion/contact regressions pass at `c8c81a8b`; real multi-parcel host admission and exact material quantities are demonstrated. The first two-platform attempt failed before Windows physics because strict checkout validation rejected line endings. Corrected-source platform qualification is pending. Dense penetration/resistance, representative GPU pacing, accepted-GCR integration and active restoration/fracture/gameplay remain unpassed or deferred; this increment does not complete #281 or #12.

After a successful new run, update only the relevant source/platform/publication clauses using that run's original evidence. The physical and deferred boundaries do not change merely because CI becomes green.
