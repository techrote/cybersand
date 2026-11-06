---
title: SOL contact and gravity ordering experiment
status: Current
document-kind: audit
scope: Dependent pure and actual cut-structure ordering experiment; negative settling result with unchanged masses, caps and guards
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../systems/solid-detachment.md, ../architecture/rigid-body-and-cellular-coupling.md, ../operations/local-build-and-validation.md, 2026-11-06-sol-stage-and-mass-readiness.md]
---

# SOL contact and gravity ordering experiment

## Decision and scope

**NO-GO for post ordering as the packed cut-tree/building settling fix.** The
registered32 fresh720-step episodes pass ownership, geometry, mass/inertia and
execution checks, but current/pre and post each pass0/8 packed rest screens.
Post increases terminal Sand intersection and late vertical drift in8/8 matched
setup comparisons. Retain it as an explicit opt-in diagnostic, keep the child
PR Draft, and leave parent [#460](https://github.com/techrote/cybersand/pull/460)
stable and Draft. No physics gain, mass, force cap or energy guard was tuned.

The original520-member/six-proxy RedBrick tree includes the hole at(60,32) and
open concavity at(68,50). The separately authored building has356 members/five
proxies. Both use real native support cut(50,65,4,2), native commit/finalize,
one authoritative aggregate and one actual Rapier body. Unit mass/member gives
M520/356; server I70453.6484375/59192.15234375. Gravity Y92.1199951171875,
linear/angular total damping .14/1.04, ordinary impulse cap3 and correction cap.5
remain unchanged. There is no thrust or user drive. Catalogue density ranks
still do not calibrate relative physical Sand/object weight.

This is source-local historical SOL, not an admitted #394 LA/SOL composition.
It does not reproduce the old rotated initial burial's complete live authority,
admit Wood/reactive/mixed cohesion, restore#365, or introduce E1/E2 authority.

## Sources, runtime and custody

Owner branch `codex/sol-contact-gravity-order-20261106` starts at exact parent
`61924a9788f507620706dfa19d28dc12d819156b`, preserving #393e4/#347159/#407bbca
ancestry. The parent branch is `codex/sol-structure-cut-20261106`; it was clean
and unchanged at every guarded execution. All native/catalogue protected inputs
remain byte-identical to the chosen #393 source. Current main was queried as
`06522e300dcf91efbab0ac8f4f4370af72cf2029`; it is not this branch's base.

| Evidence | Executed source | Qualification |
|---|---|---|
| values-003 | `7b5d40c4a32ebd98b69274392902179d5e77ee76` | Two real Godot hosts, pure values; no World/body |
| live-001 | `c47f96e053ec42e9eb9f233bf2c28055af3fc993` |32 fresh actual-cut episodes,23,040 steps; input tree `5837b37d065af8e4f373b8ba1b73490ab130c444` |
| fences-001 | `003872df2e206eb10855160befa2dd9f0776a4dd` |38 new dispatch checks/host, original planner/fences, four further post episodes/2,880 steps |

The latter source fixes opt-in persistence on close, adds returned value-only
skip/retirement dispositions and guards test capture after close. Its four
post episodes are qualification, not replacements for the registered matrix.
Final documentation/reducer descendants are not relabelled as executed physics.

Actual Windows and WSL Ubuntu Linux Godot4.7/Rapier0.35.2 were executed. Parent
source-authenticated native binaries are reused because no native source changed.
This is actual Windows-host execution; it is not a new MSVC native compilation.

| Host | Godot executable SHA-256 | Native extension SHA-256 | Rapier SHA-256 |
|---|---|---|---|
| Windows | `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` | `9e68d2d7927a2434ce60bd2d367498d9de72c010f28a52bc743fa7f9bad46abd` | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |
| Linux | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` | `8bf350d9ef1f3cca81bbd7cc41018d2cd74d473a5259e83e2e62a69bbed4c172` | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |

Raw evidence stays under the owner's local `build/sol-contact-order`, separate
from the read-only parent's nearly exhausted4GiB collection. This collection is
preregistered at2GiB with5GiB free-space reserve; after fences it held1,361,695,277
bytes with16,253,530,112 free. Later reductions/check logs are additional bounded
work. Raw logs/build products are not committed. Receipts include every executed
qualification command, timeout, exit, log hash, project inventory, compiled
artifact identities, report hashes, resource measurements and source equality.

| Retained receipt | SHA-256 |
|---|---|
| values-003/receipt.json | `61a2f75dd39daf0e2bfde3c2efd55d70ebd8051ff424ea07b713f4500e3bb90b` |
| live-001/receipt.json | `5e29c6966bb48e5092298f26d79c783509ab3ebd380a9609e76075e9746eae53` |
| fences-001/receipt.json | `ca66d6175e9a47fa9686e68122d9d8f7865794726e7b0cac28ad19d88e10ddb5` |

## Registration and mechanism

Pure registration `SOL-CONTACT-ORDER-VALUES-001` precedes its runs at334a39a6;
live registration `SOL-CONTACT-ORDER-LIVE-001` precedes live results atc0611ccb.
The JSON profiles are in `native/tests/fixtures`. New scripts are under
`tools/sol281/order_*`; `test_sol_contact_order.gd` qualifies the dispatch seam.

Current order is ordinary native response/correction/velocity clipping → Sand
planner/application → Rapier gravity/damping/contact → publication. The opt-in
post arm moves only Sand application after exactly one confirmed Rapier step,
before publication. It copies the original observation/identity into one local
envelope, validates the same owner/body/RID/epoch/token and consumes it once.
No envelope survives `physics_step()`, terrain skip, pause, failure or retirement.
Returned step dispositions retain skipped work independently of actual bridge
evaluation counts. Failed readback stops before publication, preserving the lease.
`close()` restores pre; no launcher, global default or user fleet changes.

The publication clock increments at packing; native tick, snapshot serial and
actual Rapier step are separate clocks. Post uses captured current sample+1
modulo1,000,000 after the confirmed physical advance, without restamping source
data. Incoming age0/1 becomes1/2; the original maximum-age-one gate rejects2.
Geometry drift.25, one-use suppression, planner sweeps, source witness validation,
force/correction caps and both energy gates remain unchanged. No native Sand is
recaptured or moved by a new path. Native pool workers call no Godot APIs.

The pure prediction arm adds recorded gravity and damping to velocity only.
It is never applied early:2,922/5,573 numerically accepted prediction plans would
increase actual earlier-state kinetic energy. In the primary late window every
numerically accepted prediction does, by216.50–597.79 units. Dissipation against
an invented future velocity does not license a wrench against the current body.

## Pure comparison and retained apparatus failures

Both engines pass17,053 checks each on16 retained sessions×360 states. Results
are byte-identical SHA-256
`e72afde6490c2ae2c00f52e03b4fc691df17cff3099eb001795db88b7db9d06f`.
The unchanged current arm reproduces2,826 source outcomes and2,706 exact wrenches.

Primary Linux/w1/building/SandOn, steps240–359, denominator120:

| Arm | Eligible accepted | Other effective outcomes | Upward J / M g dt over all120 |
|---|---:|---|---:|
| Current S1 |119|1 not executed|0.087057|
| Predicted velocity |115|4 non-dissipative,1 not executed|1.035792, ineligible for early application|
| Recorded post S3 |1|118 stale,1 not executed|0.008202|

S3 includes the baseline pre-Sand action and follows publication. This is a
conditional value re-evaluation, not an observed counterfactual trajectory or
the live post/prepublication state. Wrapper refusals and numerical plans behind
them remain separate. Alternative shadow leases do not double-apply real samples.

Retain values-001/002 unchanged: values-001 had2,826 apparatus identity failures
from JSON generation string `2.0` instead of integer string `2`. Values-002
reproduced outcomes but1,266 exact in-engine JSON-reference comparisons failed.
Values-003 preserves reference scalar bits rather than loosening a physics
tolerance. The first reducer invocation failed on a float JSON step index; an
exact integer conversion repaired that apparatus error. No failed physical run
was replaced or its thresholds changed.

## Actual physical comparison

Each arm uses a fresh authoritative World/session, fixed720 steps and a
prospectively frozen rest window600–719: COM speed≤.5, |omega|≤.02, each position
axis span≤.5 and angle span≤.05. These are rest screens, not SOL364-D's proposed
clearance clock. Native and main loops retain independently paced60Hz scheduling;
equal setups do not promise identical trajectories or publication phase.

Dry8/8 rest passes. Packed pre0/8, post0/8, Off2/8. Both quiet Off cases are Linux
buildings buried with Sand area186–188 cell²/depth2.705 cells. Pre Sand terminal
area45.68–69.11; post78.42–194.10 cell² and depth2.679–4.046 cells. Post worsens
vertical drift and terminal Sand overlap8/8; improves horizontal span8/8, maximum
speed4/8 and maximum angular speed5/8. Its increased support is not a settling fix.

| Full packed outcome, denominator5,760 per arm | Pre | Post |
|---|---:|---:|
| Accepted |5595|4217|
| Non-dissipative |150|8|
| Pose drift |4|555|
| Stale sample |0|893|
| Invalid witness |0|8|
| Cleared contact |0|3|
| Not evaluated |11|76|

Mean upward Sand J / M g dt across all frames increases0.111918→0.650358.
Many post steps still integrate downward displacement before stopping velocity.
No new positional correction is introduced. All original tuples, exact proxy
unions, mass/inertia/COM and sole ownership pass; native quantities are conserved
and the inert hard map stays constant. Independent hard geometry is available
every step. Sand endpoint geometry is measured against the paused final census;
per-step synchronized Sand clearance remains unavailable. Hard-depth tail passes
pre0/8/post6/8 do not accept Sand clearance or original SOL.

The independent audit checks69,120 principal states and22,866 Sand boundary states
for finite values, validity, frozen state, M/I, actual RID/instance, owner/epoch,
terrain, damping and COM. It confirms inter-frame bit continuity. Two accepted
post actions have positive scalar64 KE delta+0.000161161 at KE20,869.633, within
the unchanged2.08696 readback tolerance. All accepted applications stay within
the existing energy gate; do not claim strictly nonincreasing actual KE.

Keep `reduction.json` unchanged. `reduction-v002.json` hardens state admission and
uses transformed actual COM for potential energy. The old origin-based potential
differs by up to.0562256 units/step; this is a derived-ledger correction, not a
physics/run change. Net body mechanical energy declines; native Sand physical
energy and weight remain uncalibrated, so no closed conservation proof follows.
Corrected reduction SHA-256:
`ceba872c7d2864195bf611650920618d49764139df19d078f891b17253b19ec3`.
Preserved first reduction SHA-256:
`a3352b15a567df4e9c82ceb96b0de5c5619ff24f129b540bb7ce221f1aa49a06`.

## Performance and qualification limits

All720 frames, refusals and non-evaluations remain in diagnostic timing
denominators. Cumulative worker attempts include refused/overwritten publication
work. Main observer-heavy means range Off.513–1.523ms, pre1.976–2.573ms,
post1.357–2.663ms; maxima19.288/8.256/15.564ms. This includes test state capture
and is not the original inclusive24-group×3-repeat SOL CPU gate. No universal
60Hz/cost pass or optimization claim is made. Peak resident/native material
memory and the original CPU gate are unexecuted here.

Configured workers1/4 are authenticated by native readback. Every sampled dispatch
observes one task claimer, including worker4; the small patch schedules one job
per parity phase. Each episode repeats46–47 distinct samples across720 captures.
These are configured-worker tests, not four-way utilization proof. Native pool
work and main-thread Rapier application remain separate owners.

Existing planner and actual-Rapier fence suites pass both hosts. New38-check
dispatch suites cover clock wrap, absent admitted observation, generation/epoch/
token/worker/bridge/body retirement, pause/failure/busy, pending terrain,
nonadvancing step, reset default, real post-impulse invalid readback, retained
lease and failed publication after a finite real application. No retry/unpause
bypasses terminal failure. Four fresh latest-source post episodes also complete.
This narrow Godot-only change does not add a new optimized/strict ASan/UBSan/MSVC
native campaign; inherited native qualification remains source-scoped. Broad
authored fleet, hot/foreign/masked/material refusal campaigns are not rerun here.

`order_check.py --run NEW` records documentation, historical M11, materialized
repository/runtime, frozen material guard, original/additive retrieval, adverse
state admission, geometry controls and diff checks at one clean exact source.
The initial docs check failed because five companion-workspace files were absent;
byte-identical read-only-parent copies restore only those historical link targets,
with hashes retained in `companion-custody.json`. They are outside this source
repository and do not change historical provenance. A successful docs check is
separate from the inherited World material-lock failure and eight published
native-runtime source mismatches; neither guard may be refreshed for this work.

At documentation source `e8d04b30e492858f2a8626043b275a30f1c6bf34`,
`checks-001` passes docs, historical M11, three adverse-state tests, seven geometry
controls and diff checks. Original retrieval retains32/32 top-five canonical
routes (19 first); additive post-result questions retain3/3 first. These are
retrieval results, not answer/scientific acceptance. Repository check exits1 for
the same eight inherited Windows/Linux source-input mismatches. Frozen material
guard exits1 for World: expected LF SHA-256
`b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1`, actual
`91cecf308d01ef214f491f3dc1f353f10c9db17a55162b983fc4ecf80e6363e6`.
These remain integration blockers. The final documentation descendant receives
a separately retained exact-head `order_check` receipt; do not relabel this dated
source as the final commit or rewrite its source-qualified runtime evidence.

## Decisions and next action

| Question | Decision at these sources |
|---|---|
| LA-SELECTIVE intended primary granular gameplay response | CONDITIONAL; owner direction preserved, no matched LA arm or default change here |
| LA-SELECTIVE measured benefit to actual SOL collisions | UNAVAILABLE in this uncomposed source |
| Post ordering fixes cut-tree/building packed settling | NO-GO:0/8 and worse overlap/vertical drift8/8 |
| Original SOL physical clearance | NO-GO / not proved; quiet burial and hard-tail changes are insufficient |
| Frame-local same-owner order experiment | PASS scoped execution/fences; broader material/source integration remains NO-GO |

Preserve original84/84 synchronized sustained-clearance failures,64/84 depth
failures,36/36 asynchronous final overlaps,1,452/1,452 fixed-orientation refusals,
old CPU failures, frozen material compatibility guard and#365 restoration block.
Wall1/hard exclusions and tiny RedBrick1e-9 filter remain binding. No historical
hash, denominator, material transition or failure is rewritten.

Next is independent adversarial review of this negative result. A later separately
registered readiness gate could hold a coupled Rapier step until the sole native
owner supplies the current exact body sample, retaining age-one admission after
the step. It changes relative solver pacing and needs bounded nonblocking hold,
timeout/reset/terrain disposition and native-tick accounting; it is not implemented
or claimed to solve the remaining position integration/bearing problem. Establish
physical material units before any force-law/weight change. No cap tuning follows.

LA general-desktop promotion remains separate: authenticate admitted #394 material
composition, preserve LA/LA-EVENT-OFF/RFT and liquid policy, test actual supported
hosts/fleet and source-matched overhead, then obtain independent owner review.
Do not change accepted main, make a dependent PR Ready, or integrate this result.

## Reproduction and documentation map

Run `python tools/sol281/order_values.py --run NEW`, then
`python tools/sol281/order_reduce_values.py --run NEW`. This requires retained
authenticated parent artifacts at the source-bound paths in `order_common.py`.
Run `python tools/sol281/order_live.py --run NEW` for the registered matrix or
add `--gates-only` for focused tests plus four latest-source post qualifications.
Reduce with `python tools/sol281/order_reduce_live.py --run NEW`; use a new output
name rather than replacing a derivation. Commands have300s host/900s pure limits;
Linux receives an actual timeout wrapper. Parent/source/runtime mismatches stop.

The canonical detachment contract owns routing/default/capacity; coupling and
ownership pages own clock/lifetime semantics; interfaces own returned dispositions;
build guide owns commands; roadmap/handover/index/corpus route this dated result.
Existing force-law ADRs, native/material/storage configuration, user controls,
save/load, painting and liquid policies do not change. This completes the change
map without creating a new solver or rewriting historical documentation.

## Complete coordinate ledger

All32 registered episodes,720 steps each. Sand area/depth are paused terminal values.
Mean main time includes full observer work; rest uses the fixed600–719 window.

| Host | Workers | Structure | Surroundings | Arm | Rest | Max speed | Y span | Sand area | Sand depth | Main mean ms |
|---|---:|---|---|---|---|---:|---:|---:|---:|---:|
| windows | 1 | tree | empty | off | True | 0 | 0 | 0 | 0 | 0.597128 |
| windows | 1 | tree | packed_sand | off | False | 10.6135 | 1.94868 | 160.05 | 4.05775 | 1.01571 |
| windows | 1 | tree | packed_sand | pre | False | 1.43993 | 0.69928 | 47.2697 | 2.7885 | 2.08395 |
| windows | 1 | tree | packed_sand | post | False | 0.630147 | 1.65719 | 191.971 | 4.02597 | 2.15713 |
| windows | 1 | building | empty | off | True | 0 | 0 | 0 | 0 | 0.534057 |
| windows | 1 | building | packed_sand | off | False | 1.52363 | 1.22187 | 112.416 | 2.70257 | 0.802419 |
| windows | 1 | building | packed_sand | pre | False | 1.27067 | 0.925636 | 61.8927 | 2.68692 | 2.05252 |
| windows | 1 | building | packed_sand | post | False | 0.323942 | 1.57486 | 104.443 | 2.69038 | 2.66257 |
| windows | 4 | tree | empty | off | True | 0 | 0 | 0 | 0 | 0.513082 |
| windows | 4 | tree | packed_sand | off | False | 3.04857 | 1.23219 | 138.75 | 3.93465 | 0.8269 |
| windows | 4 | tree | packed_sand | pre | False | 1.43993 | 0.69928 | 47.2697 | 2.7885 | 1.97553 |
| windows | 4 | tree | packed_sand | post | False | 1.56963 | 1.48553 | 189.09 | 4.04071 | 2.14613 |
| windows | 4 | building | empty | off | True | 0 | 0 | 0 | 0 | 0.542624 |
| windows | 4 | building | packed_sand | off | False | 1.52363 | 1.22187 | 112.416 | 2.70257 | 0.846911 |
| windows | 4 | building | packed_sand | pre | False | 1.27067 | 0.925636 | 61.8927 | 2.68692 | 2.08527 |
| windows | 4 | building | packed_sand | post | False | 1.56452 | 1.56797 | 104.337 | 2.68941 | 2.57777 |
| linux | 1 | tree | empty | off | True | 0 | 0 | 0 | 0 | 0.751147 |
| linux | 1 | tree | packed_sand | off | False | 16.5986 | 2.54464 | 225.391 | 4.10809 | 0.96454 |
| linux | 1 | tree | packed_sand | pre | False | 1.03831 | 0.69619 | 53.0936 | 3.08034 | 2.14175 |
| linux | 1 | tree | packed_sand | post | False | 3.0768 | 1.00925 | 78.4233 | 4.04599 | 1.35681 |
| linux | 1 | building | empty | off | True | 0 | 0 | 0 | 0 | 0.692156 |
| linux | 1 | building | packed_sand | off | True | 3.57782e-05 | 0 | 187.762 | 2.7047 | 1.31474 |
| linux | 1 | building | packed_sand | pre | False | 2.02459 | 0.891922 | 69.106 | 2.65385 | 2.57257 |
| linux | 1 | building | packed_sand | post | False | 1.53461 | 1.22799 | 90.7824 | 2.70324 | 1.91787 |
| linux | 4 | tree | empty | off | True | 0 | 0 | 0 | 0 | 0.824451 |
| linux | 4 | tree | packed_sand | off | False | 3.55533 | 0.119064 | 288.989 | 4.1854 | 1.29056 |
| linux | 4 | tree | packed_sand | pre | False | 1.04907 | 0.691353 | 45.6756 | 2.6971 | 2.25522 |
| linux | 4 | tree | packed_sand | post | False | 1.53979 | 1.49697 | 194.096 | 3.67155 | 2.54308 |
| linux | 4 | building | empty | off | True | 0 | 0 | 0 | 0 | 0.663715 |
| linux | 4 | building | packed_sand | off | True | 0.000871386 | 0 | 186.066 | 2.70492 | 1.52292 |
| linux | 4 | building | packed_sand | pre | False | 1.97483 | 0.933594 | 61.999 | 2.69613 | 2.10524 |
| linux | 4 | building | packed_sand | post | False | 1.55371 | 1.5727 | 93.198 | 2.67922 | 2.52914 |
