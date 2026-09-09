# Issue #13: Experiment Tower and optional transport

Date: 2026-09-09. Work is on `codex/issue-13-experiment-tower` in
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
