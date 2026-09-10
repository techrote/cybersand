# Issue #13: Experiment Tower and optional transport

Dates: 2026-09-09–10. Work is on `codex/issue-13-experiment-tower` in
`C:/kybersand/source`. Intake exactly matched
`372bfb3ac3cbbb8005b594cd0995ed5e71d6c530` on
`codex/issue-10-player-and-exchange`. The sole tracked delta was the intentional
Windows DLL, SHA-256 `d363cadf71674eab72df54c154bac3aeccbfaa63884c8c3a6b92fe585e1039eb`.
Its bytes are preserved in `C:/kybersand/validation/local/2026-09-09-issue-13/intake/`.
No tilde DLL existed at intake; none was removed. The companion repository was
clean. Functional deliverables in `C:/cybersand` remain untouched.

## Reference and tower checkpoint

The [runbook](../operations/experiment-tower.md) owns recipe and command semantics.
Raw prefix: `C:/kybersand/validation/local/2026-09-09-issue-13/`.
`baseline/manifest.json` records actual source inputs and the freshly compiled
Windows reference CLI. `baseline/references.json` retains 60 fresh 1800-tick
controls with exact matching one/four-worker samples at each seed. Every run
has zero diagnostic overflow. These were captured before solver changes.
Baseline values are preservation references, not a new transport tuning decision.

The native DLL was freshly rebuilt (`baseline-native-build.log`, 10.13 seconds,
wrapper `20260909-232211`). `tower-test.log` passes deterministic construction,
safe landings, all reservoir plugs, invalid candidate preservation, exact recipe
reset, actual desktop owner startup and exactly one paused single step. Both
controller scene resources load. This headless test is not a visual walkthrough.

Checkpoint documentation mapping: this new runbook owns tower controls and fixture
inputs; ownership and interfaces link it for the queued replacement boundary;
configuration links construction/command budgets; tests, handover, roadmap,
source identity and evidence route the new work. Material and Water solver,
granular policy, ADR-008/011, cell state, saves and reactions are unchanged at
this first checkpoint. Profile infrastructure and new transport follow separately.

Real Web execution, visual review, experimental transport/profile validation,
performance comparisons and final regression/documentation checks are pending.
Published runtime provenance remains a separate known mismatch; it is not repaired
or relabelled by this issue. Historical #9/#10 and M11 records remain intact.

Reference checkpoint gates: native suite **52/52**; documentation, retained M11,
eight checker-contract tests, both retrieval evaluations and `git diff --check`
pass. [Gate commands and outcomes](issue-13-2026-09-09/tower-validation.json)
retain the separate repository failure: **14 published-runtime mismatches**, the
same six inputs per platform plus dirty Windows bytes/LFS identity inherited
from #10. Frozen [baseline samples](issue-13-2026-09-09/baseline-references.json)
and [source/artifact manifest](issue-13-2026-09-09/baseline-manifest.json) are
retained in source. The full Godot suite was started and remains in progress at
this focused checkpoint; its later outcome will be recorded independently.

## Profile infrastructure checkpoint

Reference/tower commit: `f88423fe8ccacdfbac642b33513fee8680d0c3f3`. The completed
first-checkpoint Godot suite passes **22/22**, including F01/F02, player async,
Water/save/render and the new tower fixture (`tower-godot-test.log`).

The next delta adds [versioned authoring](../systems/flow-transport-and-profiles.md),
fixed native tables, validated replacement, lab profile retention and explicit
pair permeability. The motion hooks follow in the next checkpoint. The DLL
was rebuilt after adding the diagnostic profile input; `profile-checkpoint/`
captures source delta, snapshots and artifact hashes. Profile tests pass all three
preset round trips, effective origins/inheritance, symmetric overrides, field
extremes/minima and malformed-profile/world-preservation checks. Tower owner
and render handoff tests pass; the native suite remains **52/52**. The rebuilt
60-control baseline exactly matches every frozen pre-change sample.

The first native build rejected hashing a C++ bool through the integer template;
an explicit byte cast fixed compilation. Its failed log is retained. Actual
desktop inspection found native exchange serials restarting at replacement could
leave old visuals displayed; worker publication serials now stay monotonic and
the regression checks this. A second visual failure showed transparent tuning
controls; `profile-ui-failed-transparent.png` retains it. The editor now uses an
opaque centered panel; its final visual confirmation is pending.

Profile-stage docs/history/checker tests/retrieval/diff gates pass. Repository
publication identity still fails independently; its raw error list is retained
in `profile-gates/repository.log`. No published hash was edited. The profile
manifest hash is `3db510feb1576fe08970ac1e2217d71ccac197ed5622b8490d2d7f4e8f024774`.
Presets resolve to Baseline `1b27b4e934dc7560e6901eb09e634ed604c0111dcf26d5dac6b10885a3e5e268`,
Gentle `a4593c9c8632463d5b9100233809b530ef7043502bcd66444fa7930a422816e7`,
Erosion `57d8ed905b2ad52c6f1372560c4fafb9dad5a03135ca987dee05f6167428e079`.

## Shared motion checkpoint

Profile commit: `af80634`. Optional powder mixing and Water grain pickup now use
the [shared bounded policy](../systems/flow-transport-and-profiles.md). DLL build
`transport-native-build.log` precedes `transport-godot.json`: nine native Godot
cases pass exact species/Water conservation, all preset Mercury fronts through
33 grains at 990 ticks, shared tower construction/landings/plugs and invalid
replacement. The shared probe is release-safe for subsequent real Web execution.

Native suite **54/54** passes (`transport-native-test-v3.log`, 69.566 seconds).
New tests cover resting packed beds/pools, supported films and hard separators
at seven signed seam positions, state-byte/temperature preservation during pickup,
exact one/four-worker state checks, zero prepared allocations and exclusion.
The resolved Baseline's 60 fresh controls exactly match every frozen pre-change
sample (`transport-v3-baseline/`).

Early implementation screens are retained. First surface-only powder candidates
produced just six swaps and 297 versus 293 interface contacts in seed 0. The
final coflow candidate uses the successful fall's vacated route and an exposed
unlike neighbour: 1864 swaps and 492 interface contacts, preserving final counts
and returning to zero late powder movement. It does not shuffle same-material
Sand, helping preserve indirect Mercury references. `transport-smoke/` retains
the earlier erosion screen (Gentle 4 versus Erosion 110 pickups in the packed
slope; 15 versus 164 in the loose fixture), not a final tuning acceptance claim.

Two failed native fixture expectations remain recorded: the first film fixture
was open at its sides and its finite crop lost falling Water; adding sidewalls
made conservation meaningful. The first 300-tick packed-slope expectation required
Gentle to erode grains; that was incorrect for a profile excluding packed pickup.
The positive packed-slope assertion now applies to Erosion, while the independent
loose benchmark measures Gentle pickup. No reaction or fire cadence was changed.

The full fixed-profile screen is retained separately in `transport-screen/`.
At this checkpoint sampling values are authorable but not yet consumed, so its
sampled-policy runs are controls, not evidence of reduced work or speedup. The
next focused checkpoint implements and measures that approximation explicitly.

## Sampling and final experiment checkpoint, 2026-09-10

Shared motion commit: `1290e0aa60ea70716fd219ef2c04225e89c4cb00`. The fourth
checkpoint consumes horizontal/cadence settings independently of carrying
strength, adds resident activity-block accounting, completes the independent
control screen and real-platform walkthrough, and records the numeric v1 decision.
The three presets remain opt-in templates with horizontal 2 and cadence 1.
No reaction probability, ignition/lifetime, fire cadence, barrel or soliding policy
is retuned. The current issue was re-read through the GitHub connector on
September 10; its last update remains September 9, 21:08:10 UTC, with no comments.

### Regressions and actual platforms

The rebuilt core passes **54/54 native tests** in
`sampling-extreme-native-test-v2.log` (110.759 seconds). This includes one/four
worker exact state/temperature comparisons for full sampling, one lateral sample,
and cadence 60; seven signed seam/rest/film/barrier positions; and F01/F02 failure
and exclusion tests with both default and extreme transport configuration.
`complete-godot-tests.log` passes **24/24 Godot fixtures**, including desktop
asynchronous owner/player, render, Water/save, worker, profile and tower tests.
The later recipe-4 Metal-bed fixture passes separately in `tower-v4-test.log`:
Acid stays behind its closed plug for 180 ticks and corrodes the prepared Metal
bed after manual release. The final UI-only change removes keyboard focus from
lab buttons/pickers so Space cannot accidentally reactivate Pause.

Core DLL rebuild is `final-native-build.log`; full native Web module builds are
`final-web-build.log` and `final-threaded-build.log`. Recipe/UI exports are dated
separately; use the final artifact manifest, not an earlier file named "final".
The Web export's embedded source-acquisition label is not an attestation of this
working source. Exact module/PCK/DLL/tool hashes and source-file hashes are retained.
Godot is 4.7 stable, Rapier 0.35.2, Clang 23.1 and Emscripten 4.0.20; pins and
published manifests were not changed.

The release-safe transport probe executes six profile/sampling combinations ×
four fixtures (packed Mercury, powder coflow, packed slope, loose grains), with
990 Mercury ticks and 600 other ticks per case. Both actual native Web profiles
pass all 24 cases and their controller F01/F02 probes. Web compatibility uses
one worker; the threaded transport probe uses four and its actual controller
auto-selects six on this host. The two Web profiles produce identical result
rows. Desktop native rows match species, Water, profile identity and event counts;
their `state_hash` differs because the existing hash includes a platform-width
`size_t` chunk population value (64-bit native, 32-bit Wasm). This is not evidence
of cell divergence, nor a claim of cross-platform state-hash equality. The
separate Windows CLI content hashes are the exact frozen-reference gate. No
GDScript fallback implementation of transport is claimed: the tower requires
the native bridge in these desktop/Web profiles.

### Corrected measurements and retained failures

The initial sampling matrix completed 480 runs, but its final report correctly
rejected the sustained Water ledger. The fixture used `set` on existing partial
Water, which preserves same-material state; its ledger incorrectly counted those
top-ups as delivered. The corrected injector uses explicit `set_cell_state` only
when mass is added. This changes fixture input, not solver conservation.
`sampling-report-failure.log` and the entire original `sampling-matrix/` remain.
An interrupted blanket rerun is retained in `sampling-matrix-v2/`.

The final `sampling-matrix-corrected/` retains 384 unaffected original runs and
reruns 96: every sustained case and both workers for seed-zero erosion/loose/sparse
cases. Each retained execution has its original command and artifact manifest;
the new matrix carries both source manifests and an explicit `reused` flag.
The latter three fresh layouts correct a second measurement error: the initial
erosion-depth query included the immutable bottom wall. The corrected depth and
`eroded_initial_sites` only measure cells occupied by initial Sand. The old
`eroded_sites` field remains unchanged solely for frozen-reference compatibility;
it is not the corrected erosion metric. Depth has **one translation** per group
for these layouts, five for sustained. The summary explicitly records that sample
count and null for layouts without a fresh depth measurement.

The new CLI also passes all **60 fresh Baseline controls**, exactly matching every
frozen pre-change field, in `corrected-benchmark-v2/`. Earlier profile/motion and
sampling reference runs remain retained rather than relabelled. Grain and Water
conservation, unchanged default Mercury samples, worker parity, late powder/film
rest, zero chunk/temperature allocations and diagnostic overflow are checked by
`transport_report.py` before a summary is emitted. These allocation counters are
specific prepared-world counters, not a blanket claim about every engine/UI allocation.

The instrumented whole-tick timing screen runs on a shared Windows host, with
some overlapping builds, UI and other validation. It measures p50/p95/max, total
tick cost and ns/visited cell alongside visited cells, resident active blocks,
scheduled cores, eligible lateral probes, successful transferred Water mass,
powder swaps and grain pickups. It does not establish isolated or universal
speedup. Erosion depth includes ordinary initial slump; fresh Baseline is essential.
Sustained input deliberately continues, so its late movement is not a rest failure.

### Independent controls and numeric version decision

`knob-screen/` contains 33 independent 1800-tick, seed-zero, one-worker comparisons
with exact conservation, zero prepared chunk/temperature allocations and overflow.
The Erosion template's powder coflow produced 1864 swaps and 904 unoriented
Sand/Dust interface edges. Mixing 0 produced 0/507; mixing 255 produced 3202/703.
Thus more swaps did not monotonically improve final interleaving. The earlier
one-sided `interface_contacts` count is retained but differs from this unoriented
edge metric. Powder mixing settings left Water pickup unchanged.

For loose / packed-slope Water fixtures respectively, Erosion produced 164 / 110
pickups. Carrying 0 or 64 stopped pickup; pickup 255 or packing 32 also stopped it.
Pickup 0 and packing 0 each produced 325 / 263, consistent with the documented
fixed 64-unit lower disturbance bound. Cadence 4 gave 221 / 229; cadence 60 gave
21 / 23. Lower frequency therefore does not necessarily mean a proportionally
weaker outcome. These Water controls left the powder fixture's final content
unchanged. `permeability-screen/` adds six one/four-worker packed references:
at tick 300, permeability periods 1 / 30 / 60 produced depths 32 / 10 / 5, with
exact counts and worker equality. These are explicitly authored Mercury user-copy
experiments; production and all protected presets retain period 30.

Decision: retain profile schema **v1**, mixing **96**, carrying **255**, pickup
**64**, packing **8**, and the Gentle/Erosion exposed-packing distinction. Keep
horizontal **2**, cadence **1** and Mercury permeability **30** in every preset.
These are bounded gameplay experiment values, not calibrated physical units or
owner approval of a new gameplay default. Each control has a declared independent
role; values below the fixed disturbance floor can intentionally share outcomes.

### Visual walkthrough and recipe revisions

Actual desktop and both actual native Web applications were inspected, not just
headless counters. Dated captures retain the active profile label and world view.
Desktop walkthrough covered all five floors: flowing powder release/rest, narrow
Water drainage onto Sand, the liquid gallery, packed Mercury progression and
separated fuels with manual ignition. Compatibility Web covered profile editing,
save/load, malformed JSON rejection, restart application and both ends of the
liquid gallery. Threaded Web covered preset provenance, restart at tick zero,
floor/tube selection and a +30/+90 Sand-then-Mercury pour; the retained view shows
Mercury below the Sand slope and in the catch basin at tick 3212. Single-step
advanced exactly to 3213 while paused; fresh reset restored tick zero with the
same floor and profile.

The walkthrough found and corrected real problems, retained under `walkthrough/`:

- Recipe 1's landing shelves blocked the shaft and its powder outlets yielded
  conspicuously clean bands. Recipe 2 opens a continuous passage and converges the
  first outlets. `desktop-v2-powder-rest.png` shows interleaving and zero late work.
  Its obsolete hard-coded "recipe v1" status label was subsequently corrected.
- An early transparent profile panel obscured controls. The opaque replacement
  was inspected on desktop and Web. The final Web font did not provide the arrow
  glyph, so the effective-pair label uses plain "to". Editing JSON now clears an
  earlier valid status until revalidation.
- Recipe 2 Acid dissolved its amber outlet and gallery gates without input.
  Recipe 3 adds inert Acid-facing layers, removed by the same three-row plug
  action. The captured final Acid release remains in its own bay.
- Recipe 4 adds a Metal bed in the chemistry catch pit: the solid Metal tube
  itself cannot drain, so the earlier arrangement did not initiate the intended
  contact just by opening Acid. This is a map correction, not reaction tuning.
- Lab controls could consume Space after mouse use. Removing their keyboard
  focus preserves the jetpack binding; subsequent Web input did not toggle Pause.

The manual fuel observation at about tick 2285 showed Oil consumed, with substantial
Wood and Coal remaining after top ignition. This short observation has no matched
ignition-dose/rate comparison and does not calibrate fire. Preserve the owner's
separate report that reduced fire cadence made Wood smoulder while Oil and Coal
felt good. No attempt was made to restore faster burning here.

### Scope and remaining limits

Agent walkthrough establishes readable labels, selectable bays, release/reset
operation and the captured outcomes. The owner's subjective Mercury feel and
preferred erosion strength remain for hands-on review; neither is inferred from
passing counters. Horizontal sampling applied to all liquids is an explicit user
experiment and can change poured Mercury trajectories; it is not promoted into
any preset. Other liquids keep disabled new entrainment. Chemistry can change
with contact geometry and elapsed active ticks; no isolated chemistry tuning study
or turbulence field is included. Complete brush/player replay remains Planned;
the bounded observation input log is not that replay. No deliverable was published
or historical publication hash rewritten.

The final compatibility chemistry walkthrough retained a Salt pile in liquid,
a rock barrier forming at the Water/Lava contact with Lava still present, and
Acid corroding the new Metal bed while the neighbouring fuel bays stayed separated.
Its tick 10,655 image follows camera changes: it is not 10,655 active ticks for
every reagent. The closed solid Metal tube remains visibly intact above the pit.
Continuous held-key jetpack flight was not automated; the complete shaft was
checked for player-box clearance and normal player regressions passed. Mouse
navigation, camera focus, landings and the Space/focus correction were inspected.

### Retained identities, walkthrough and final gates

[Runtime manifest](issue-13-2026-09-09/runtime-manifest.json) records tested
`1290e0a` plus local source SHA-256
`cd596c3f2969e827b63a5b3e1c43d0ea5054425e4e3e8c72349b7ac5fe807665`.
It includes per-file hashes and the exact rebuilt DLL, compatibility/threaded
modules and final recipe-4 PCKs. Raw `runtime-complete-identity/` also retains the tracked
patch and changed/new source snapshots. The corrected native CLI hash is
`a4365f0e25845e767f215f716e3b66b82bc4b5353cad6b7cf6e6c2c77c94c095`;
the rebuilt, intentionally uncommitted Windows DLL hash is
`8eba58362aabf124842ee92d0660634d6a101610e2712dbff00960c228a25d25`.
The intake DLL copy still hashes to the original value at the start of this audit.

Final recipe-4 probes pass **24/24 each** on
[native Godot](issue-13-2026-09-09/native-v4-probe.json),
[compatibility Web](issue-13-2026-09-09/web-compat-v4-probe.json) and
[threaded Web](issue-13-2026-09-09/web-threaded-v4-probe.json), including the
shared tower constructor. Web controller failures/interest probes pass separately
inside their reports. Recipe-3 reports remain retained as earlier evidence.
[Profiles](issue-13-2026-09-09/profiles.json),
[independent controls](issue-13-2026-09-09/knob-results.json),
[permeability fronts](issue-13-2026-09-09/permeability-results.json), and the
[sampling input manifest](issue-13-2026-09-09/sampling-manifest.json) with its
[reused-run manifest](issue-13-2026-09-09/sampling-reused-manifest.json) retain
the effective-policy identities and measured observations.

| Walkthrough evidence | Purpose |
|---|---|
| [Final desktop](issue-13-2026-09-09/desktop-v4-final.png) | Recipe 4, Baseline, paused landing and tall tubes |
| [Powder at rest](issue-13-2026-09-09/desktop-v2-powder-rest.png) | Interleaved catch pile after real flow; dated recipe-2 label caveat above |
| [Water release](issue-13-2026-09-09/desktop-v2-water-drained.png) | Narrow stream, Sand slope and catch pool |
| [Failed Acid gate](issue-13-2026-09-09/desktop-v2-acid-autorelease-failure.png) | Retained unintended release before the inert-facing correction |
| [Contained Acid](issue-13-2026-09-09/web-compat-acid-contained-after-release.png) | Corrected gallery release stays within its bay |
| [Profile origins](issue-13-2026-09-09/web-threaded-final-profile.png) | Actual threaded Web effective values and pair/family origins |
| [Poured Mercury](issue-13-2026-09-09/web-threaded-mercury-pour.png) | Scheduled Sand then Mercury at tick 3212 |
| [Single step](issue-13-2026-09-09/web-threaded-single-step.png) | Same view at exactly tick 3213, paused |
| [Chemistry before](issue-13-2026-09-09/web-compat-v4-chemistry-before.png) / [after](issue-13-2026-09-09/web-compat-v4-chemistry-after.png) | Final separated contacts and the Metal bed |
| [Manual fuel observation](issue-13-2026-09-09/desktop-v3-fuels-observation.png) | Unretuned ignition observation, not a calibrated comparison |

The [final gate commands](issue-13-2026-09-09/final-validation.json) cover docs,
retained M11, repository publication identity, eight checker tests, frozen retrieval,
supplementary challenges and diff whitespace, each with a 180-second timeout.
The [repository result](issue-13-2026-09-09/final-repository.json) still fails
**16 publication mismatches**: seven source inputs per Windows/Linux platform,
plus changed Windows bytes and committed LFS identity. This is two more than the
first checkpoint's 14 because the sampling work also changes `world.hpp`.
Current builds are evidenced separately; old publication hashes remain intact.
Documentation, retained M11, eight checker tests and diff checks pass. Frozen
retrieval remains 32 questions, with 23 top-one / 32 top-five canonical hits and
MRR 0.8385; 14 supplementary challenges have 11 top-one / 14 top-five, MRR 0.8750.
C13 and C14 retrieve the Tower and transport contracts first. These lexical
scores do not independently certify answer correctness.

Canonical synchronization maps the new behavior to material/Water/granular and
activity contracts, invariant register, ownership/lifetimes, interfaces,
configuration/capacity, Tower controls, tests/retrieval, ADR-008/011, roadmap,
handover and recoverable source checkpoints. Large turbulence, #11/#12, later
chemistry tuning, Linux publication and owner feel review remain separate.

### Final sampling results

The final report passes **480 cases / 14,880 samples**: exact nonreactive counts, Water plus explicit injection ledger, one/four-worker sample and event equality, unchanged unsampled packed/poured Mercury across presets, and zero prepared chunk/temperature allocations or overflow. Full [96-group measurements](issue-13-2026-09-09/sampling-summary.json) include both worker counts. Tables below use one worker; each statistic is the median across five translations, except Max is the maximum observed tick. `h` is the allowed lateral candidate count; cadence remains 1.

**Sparse Water timing**, instrumented shared host.

| Profile | h | p50 ms | p95 ms | Max ms | Total seconds | ns/visited |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 2 | 0.967 | 1.265 | 4.713 | 1.844 | 225.6 |
| Baseline | 1 | 0.936 | 1.252 | 5.825 | 1.785 | 218.2 |
| Gentle | 2 | 0.972 | 1.248 | 2.545 | 1.844 | 227.1 |
| Gentle | 1 | 0.940 | 1.199 | 2.082 | 1.752 | 214.1 |
| Erosion | 2 | 1.066 | 1.496 | 8.752 | 1.941 | 261.3 |
| Erosion | 1 | 0.943 | 1.350 | 146.392 | 1.835 | 224.2 |

| Profile | h | Lateral probes | Water mass transferred | Visited cells | Active block sum | Pickups |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 2 | 1,271,366 | 7,557,420 | 7,774,462 | 44,067 | 0 |
| Baseline | 1 | 670,726 | 4,526,661 | 8,182,135 | 45,521 | 0 |
| Gentle | 2 | 1,271,012 | 7,547,357 | 7,773,805 | 44,069 | 1 |
| Gentle | 1 | 670,725 | 4,526,661 | 8,182,135 | 45,521 | 0 |
| Erosion | 2 | 1,284,576 | 7,496,969 | 7,981,073 | 45,565 | 68 |
| Erosion | 1 | 670,575 | 4,536,696 | 8,181,933 | 45,541 | 207 |

**Sustained Water timing**, instrumented shared host.

| Profile | h | p50 ms | p95 ms | Max ms | Total seconds | ns/visited |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 2 | 4.437 | 5.529 | 26.642 | 7.989 | 472.7 |
| Baseline | 1 | 3.839 | 4.753 | 11.575 | 6.880 | 412.8 |
| Gentle | 2 | 4.399 | 5.987 | 12.281 | 8.008 | 474.0 |
| Gentle | 1 | 3.852 | 4.633 | 10.083 | 6.826 | 409.5 |
| Erosion | 2 | 4.908 | 6.379 | 27.129 | 8.858 | 523.8 |
| Erosion | 1 | 3.872 | 4.684 | 10.661 | 6.963 | 417.7 |

| Profile | h | Lateral probes | Water mass transferred | Visited cells | Active block sum | Pickups |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 2 | 18,484,024 | 63,056,430 | 16,905,004 | 70,464 | 0 |
| Baseline | 1 | 9,004,687 | 39,023,406 | 16,664,624 | 67,865 | 0 |
| Gentle | 2 | 18,484,014 | 63,056,430 | 16,904,866 | 70,464 | 1 |
| Gentle | 1 | 9,004,601 | 39,023,406 | 16,664,624 | 67,865 | 0 |
| Erosion | 2 | 18,484,106 | 63,008,801 | 16,902,372 | 70,427 | 206 |
| Erosion | 1 | 9,010,840 | 39,499,242 | 16,669,693 | 67,847 | 142 |

Fewer lateral probes changed quality and total work. Sparse Erosion pickups rose from 68 to 207 with one sample, while visited cells rose from 7.98M to 8.18M and late movement from 5,309 to 9,851. Sustained Erosion pickups fell from 206 to 142, despite downstream deposited grains rising from 93 to 103. The sampled sparse Erosion run includes a 146.392 ms outlier. The Baseline loose fixture even had a higher median total tick cost (5.622 versus 5.323 seconds) with fewer samples. The screen therefore does not justify a blanket speedup or strength-preservation claim.

For full sampling, median coflow interface edges rose from 505 (Baseline) to 884 (both experimental presets), with 1,740 powder swaps and zero movement over the final 120 ticks. Packed/loose Water pickup medians were 0/0 (Baseline), 1/12 (Gentle), and 206/164 (Erosion). Final downstream Sand counts were respectively 89/102, 89/102 and 93/109. These deposit counts include ordinary falling and are not counts of unique picked-up grains.

Fresh seed-zero packed/loose depth measurements were 12/12 cells for Baseline and Gentle, and 11/11 for Erosion. Initially occupied sites cleared were 210/208, 210/208 and 218/213 respectively. Thus the threshold profile moved more grains but did **not** increase maximum depth in these layouts; ordinary slump dominates that scalar. Sustained five-seed medians likewise show depths 12/12/11 and cleared sites 197/197/211. This is a measured limit of this screen, not evidence of deep excavation.

All unsampled Mercury references match across presets, including indirect Sand effects. Sampling all liquids changes the poured scene: median downstream Sand rises from 1 to 4 cells, Mercury lateral probes fall from 1,856,513 to 942,817, and late movement from 2,932 to 1,553. Its packed period-30 gate still passes, but that alone would miss the poured-scene change. Keep sampled Mercury explicitly opt-in.
