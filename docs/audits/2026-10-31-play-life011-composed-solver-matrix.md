---
title: PLAY-LIFE-011 all-eight-policy composed-session lifecycle matrix
status: Planned
document-kind: evidence
scope: Source-pinned local Linux headless shared-Main qualification across five mechanical rigs and eight admitted solver presets; exact integrated Windows/Linux hosted qualification remains pending
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../architecture/liquid-solver-family-policy.md, ../architecture/liquid-prepared-setup-and-receipts.md, ../operations/current-and-historical-validation.md, 2026-10-28-play-life002-solver-reconstruction.md, 2026-10-27-play-life001-shared-host-lifecycle-candidate.md]
---

# PLAY-LIFE-011 composed solver matrix — 2026-10-31

## Gap, source and ownership

The shared liquid selector registers eight construction-time presets. Accepted
LIFE002/PACE002 and the separate PACE004 qualification exercise Current and
pressure-reference on all five mechanical rigs. Other admitted variants have
native/reference-host coverage; they did not have the same all-five composed
`main.tscn` construction/reset contract. Read-only inspection of held PR #308,
head `2443a78378d649df588efeac9db7c54084473329`, confirms its LIFE006/PACE003
composed configurations also select presets zero and two. This test-only package
fills the remaining matrix without modifying that held implementation.

The isolated base is local commit
`6f394aeff26a1da14556393c87362b87fe906084`, tree
`8b19ba953d3d73cd06017270074dfe8a47a94518`, identical to published #319
`b255bd83d24c8656724f5f067b6e3ecd80f88bbb`'s tree. This base identity is not an
assertion that #319 or its original failed Windows evidence was accepted.
The complete executable LIFE011 source is
**`704de34cc2d0bbd12647fc28b11cf7094a963666`**, tree
**`cdc38e3d779f31b5db64e7d95cb7a9389137f2fc`**. The seven source additions are
the common fixture, five automatically discovered rig wrappers and independent
Python receipt verifier. This subsequent audit append is not another engine
execution and does not transfer the local pass to a later integrated head.

No production script, native implementation, default, scientific fixture,
runtime binary, shader, worker ownership or existing regression changes.
The existing worker remains the sole native World owner. Main callbacks and
main-thread Rapier remain inherited production behavior. The only positive
input seam is the existing test technique of reporting window focus; real OS
focus and physical devices are not qualified. Source-bound observations copy
Main's immutable publications and main-thread session state. The test never
queries the live native World from Main, manually steps physics or creates a
second worker. It reads the adapter's weak identity only after the worker joins.

## Frozen fixture contract

Each of Stunt Buggy, Trials Bike, Acrobat, Arcade Lander and Jet Barrel runs one
fresh shared Main/worker lifetime. Within that lifetime, all eight presets pass
through the ordinary panel build and retained-policy reset transactions:

| Preset | Requested Water assignment | Requested Brine assignment | Explicit radius | Water normalization |
| --- | --- | --- | ---: | --- |
| 0 Current | `freemass_v1/reference` | `cellular_yield_v1/reference` | 2 | None |
| 1 Whole-cell | `cellular_yield_v1/reference` | `cellular_yield_v1/reference` | 2 | `water-normalize-v1` |
| 2 Pressure reference | `pressure_flow_v1/reference` | `cellular_yield_v1/reference` | 2 | None |
| 3 Pressure cached | `pressure_flow_v1/cached` | `cellular_yield_v1/reference` | 2 | None |
| 4 Pressure dormant | `pressure_flow_v1/cached_dormant` | `cellular_yield_v1/reference` | 2 | None |
| 5 Water inertial | `inertial_cellular_v1/reference` | `cellular_yield_v1/reference` | 3 | `water-normalize-v1` |
| 6 Mixed pressure/inertial | `pressure_flow_v1/reference` | `inertial_cellular_v1/reference` | 3 | None |
| 7 Mixed Current/inertial | `freemass_v1/reference` | `inertial_cellular_v1/reference` | 3 | None |

All eleven liquid assignments are checked; unlisted materials retain their
Current `cellular_yield_v1/reference` assignment. Radius three is required by
any inertial assignment, including Water inertial. This explicit test selection
does not change production geometry or solver defaults. The authored course,
rig topology, keyboard controls, lap rules and follow camera remain unchanged.

Each preset must provide the following evidence:

1. A newer native World generation and main-thread session epoch from actual
   construction, with the same exclusive worker and a distinct Rapier graph.
   The old session, bodies, terrain RIDs and viewport retire after adoption.
2. Exact requested/applied assignments, policy envelope, policy hash, complete
   native construction receipt, applied geometry and normalization. IN parameters
   identify the applied World and its state contract; pressure variants retain
   their distinct optimization extension identities. The receipt remains
   explicitly exploratory and ineligible for full matched scientific evidence.
3. Reset of the **applied** configuration while different policy, geometry and
   normalization choices are visible but unsubmitted in the panel. Reset cannot
   silently consume those pending choices or reuse the retired graph.
4. Real native completed-tick progress and three copied nonneutral completed
   Rapier steps after build, after reset and after refusal. Each step binds its
   before/after owner, control generation, command sequence, admitted command
   count, actor tick and actual bridge step. A neutral action or rising native
   clock alone cannot satisfy this condition.
5. A pre-reset command rejected specifically as `run_or_epoch`. An observation
   revoked by actual Main input cancellation is rejected specifically as
   `observation_not_issued`, while still within its tick lease and with a fresh
   command sequence. A newly issued observation on the same owner is admitted
   as the matched positive. That direct packet is an **admission-only** control;
   the separate normal keyboard phases establish completed physical application.
6. Unsupported Oil/pressure submission reaching the actual native transaction
   and returning `combination_rejected`. Every inertial preset also submits
   radius two and receives the precise complete-radius-three refusal. The
   staged graph retires; the valid session, World, policy, receipt, setup and
   options survive and then resume real native/Rapier progress.
7. Preservation of the earlier immutable publication, followed by final scene
   exit, complete worker join, graph retirement and worker/native-adapter
   destruction within the original limits.

There are 75 bounded predicate receipts per rig. Limits remain **30 seconds**
from before scene load to the first inherited Main `_process` return,
**15 seconds** per operation, **150 seconds** per fixture, **180 seconds** per
process and **240 seconds** per import. There are no retries or skips.
These five worker lifetimes and eighty constructed/reset graphs supplement
the accepted **fifty-real-lifetimes-per-platform** LIFE001 baseline.

## Independent readback and adverse controls

`tools/ci/verify_play_life011.py` reconstructs the eight expected policies using
an independent fixed assignment map and source-derived LCB catalogue/capability
digests. It checks complete native receipt SHA256 plus the canonical
construction/native prefix: request and applied policy, active-plane status,
generation, geometry and worker capacity. The rest of the native receipt bytes
remain authenticated by their native digest; this bounded decoder does not
claim full scientific receipt equivalence.

The verifier also checks complete cohort/wait inventories, actual graph
identity, applied physical steps, input generation/lease reasons, preserved
valid sessions and complete destruction. Original process identity, exit,
deadline, platform, pinned engine and log-to-raw-result digest are mandatory.
A success summary followed by a nonzero process exit remains a failure.
The ordinary runner remains responsible for full source/runtime provenance.

All **37 reason-specific in-memory adverse mutations** reject on each original
positive raw result, both normally and with `python -O` (370 adverse executions).
Controls include relabelled presets, missing materials, wrong variants or
geometry, forged IN readback, rehashed inactive-plane receipt, altered canonical
bytes, wrong worker capacity, missing native/physical progress, neutral or
unadmitted input, stale generations/bridges, wrong refusal reasons, changed
retained contexts and unjoined/live owners. Eight additional original-log/process
controls reject contradictory outer/row source identities, a post-summary
`0xC0000005`, a skip, a relaxed deadline, wrong case, absent summary and altered
raw bytes. All mutations use copies; original results remain unchanged.

## Original local Linux execution

The source-pinned five-case campaign at `704de34` passed clean import in
**3.925627 seconds**, then **591 assertions / zero failures per rig**:

| Rig | Process seconds | Fixture seconds | Main acknowledgement seconds | Longest operation seconds | Teardown seconds |
| --- | ---: | ---: | ---: | ---: | ---: |
| Stunt Buggy | 22.783 | 21.354355 | 0.278238 | 0.951995 | 0.072013 |
| Trials Bike | 22.979 | 21.598732 | 0.275060 | 1.004750 | 0.071630 |
| Acrobat | 22.708 | 21.271330 | 0.290001 | 0.956174 | 0.064018 |
| Arcade Lander | 22.506 | 21.061970 | 0.315172 | 0.942410 | 0.077685 |
| Jet Barrel | 22.607 | 21.241910 | 0.310345 | 0.967248 | 0.073068 |

Total **2,955/0**, forty complete policy cohorts, forty constructions plus forty
resets, eighty retired graphs, 360 nonneutral completed physical-step samples,
forty old-owner and forty lease-valid old-generation rejections, forty fresh
observation admission positives, forty Oil/pressure and fifteen radius-two IN
refusals, and five joined/destroyed workers and native adapters. The 947 captured
source inputs are byte-identical before and after execution. These single local
timings establish bounded completion, not comparative performance or FPS.

Pinned engine: `4.7.stable.official.5b4e0cb0f`. Official Linux archive SHA256
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`,
75,664,355 bytes; archive CRC and executed binary equality independently pass.
Accepted native runtime SHA256
`496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6`,
4,222,304 bytes, retains all eighty exact compiled source inputs from its
published development provenance. Accepted Rapier SHA256
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`,
117,275,416 bytes, retains all four provenance source inputs. Both actual
binaries match their canonical committed LFS pointers and provenance records.

Original evidence root is `build/life011-full-704de34` in the isolated
`cybersand-life011` worktree. Important SHA256 identities:

| Record | SHA256 |
| --- | --- |
| Campaign identity | `528293085ce26de60aabc975dc655663ffad70f4c70c9114a4c4c375d38c1506` |
| Original process inventory | `4b3eb41a6bb8bba4b6410798d451b5c0b553367190502867edd37a50aa4910df` |
| Before/after source inventory | `2d427d61dc51fa328ddb8e9d0e2cd8ccfaf2f524446e7b8dc02e6f3384a466f5` |
| Sealed 27-original-file manifest | `8517d76a2ee308dde712cf02bc6c6676daa74f6125e442c4cf42e15789d290d8` |
| Runtime/optimized/context readback | `a537a1947ee51effecc22803f855c38e3e2a9d5b21f58e08f49b9d1f5e8e0f1e` |

The last two records are retained under
`evidence/life011-local-readback-704de34` in the shared workspace. The original
driver and readback scripts are `evidence/run_life011_local.py` and
`evidence/verify_life011_local.py`; they do not become repository source.
Reproduce each case using the ordinary discovered case/180-second runner,
`CYBERSAND_SOURCE_REVISION` set to the checked-out exact head and its per-case
`CYBERSAND_TEST_ARTIFACT_DIR`. Read the retained evidence without rerunning:

```sh
python3 tools/ci/verify_play_life011.py \
  --result build/life011-full-704de34/test_play_life011_acrobat-artifacts/acrobat-life011.json \
  --log build/life011-full-704de34/test_play_life011_acrobat.log \
  --process-json build/life011-full-704de34/test_play_life011_acrobat-process.json \
  --source 704de34cc2d0bbd12647fc28b11cf7094a963666 --platform Linux --self-test
```

## Earlier evidence and qualification boundary

The initial development import at `0a42cd1` returned zero but contained socket
and `/root/.config/godot` write errors. Its original log and explicit
`failed` classification identifying the environment restrictions remain in
`build/life011-feasibility`; it is not a passing import. A separate correctly
owned XDG configuration/socket-capable invocation at the same source completed
clean import in 3.925637 seconds and an Acrobat mixed-IN probe with 50/0 in
2.818830 fixture seconds. The original first complete eight-preset Acrobat
candidate at `2d8ec73` passed 590/0 in 22.128720 fixture seconds. Those records
remain separate from the later explicit-Main-ack/independent-verifier campaign.

Independent source review corrected a pre-execution decoder assumption: the
canonical receipt header contains plane activity, not platform. The final
decoder requires active-plane status identically on Windows and Linux, and
checks platform through the separately pinned process/native-policy identity.
Its rehashed inactive-plane negative detects the intended field error.

Local structural checks pass: Documentation/provenance, repository identity,
historical M11 integrity (eighteen records/twenty-eight hashes) and whitespace.
The unchanged canonical retrieval corpus retains 32/32 at five, 19/32 at one,
MRR 0.7536. These checks establish structure and retained historical identity;
they do not add runtime or hosted acceptance.

This package is a local Linux headless qualification candidate. Integrated
exact-head Documentation/provenance, Native, Windows/Linux Godot, applicable
scope/provenance gates and independent final review remain required. Ordinary
CI discovers all five wrappers automatically; integration must attach the
independent readback to the same original process receipts. No claim closes
#269, #270 or #263. Graphical rendering, display cadence, physical controllers,
real OS focus and subjective human playability remain separate requirements.
Deferred shader work, held #308/#310, frozen #312/#316 and the paused scheduler
remain outside this package.

## INPUT011 stack and mandatory ordinary readback integration

The next isolated branch consumes INPUT011 integration
`f70680c78e89fe404aa6ea9fbdac6f2dc7f7d362`, tree
`d1c5cbb690ef34634c90255cec9772ffaa681083`, which in turn consumes LIFE010
local `9edbec0e1b6680191de8d853e6e31b883fa3eaf8` (tree-identical to published
#323 `480f896d8bedf128e798ee0c6221782064fad8d9`). These are candidate-stack
identities, not assertions that any remaining hosted gate has passed or that
the branches have merged.

The resulting executable source is
**`76111a782f1fd814ac54e2b35ab531262af6eb43`**, tree
**`f133892f7c05b9400acc7b40b2a1743d02487ad0`**. All seven original LIFE011
fixture/wrapper/verifier files remain byte-identical to `704de34`. The sole
production change in this integration is the geometry tooltip's first sentence:
“Any inertial solver requires explicit radius three.” The existing Water-IN
and mixed-Brine-IN refusal observations support that wording. Solver assignments,
geometry defaults, native semantics, shaders, runtime binaries and scientific
fixtures are unchanged. The original test-only statement above retains its
original 704de34 scope.

The ordinary runner adds one `ReadbackContract` entry. It reuses INPUT011's
existing parent mechanism and LIFE010's original process receipt behavior.
Each LIFE011 case now requires eight presets, eight constructions, eight resets,
72 samples of completed nonneutral Rapier progress, eight old-owner refusals,
eight old-generation refusals, eight fresh observation admissions, eight actual
Oil/pressure refusals, three actual radius-two inertial refusals, sixteen retired
graphs, 75 bounded waits and 37 distinct reason-specific adverse controls.
The samples cover the three captured completed steps in each of 24 phases;
they are not a count of all physics callbacks or all steps during the lifetime.

Canonical and actual source hashes bind the verifier and nine dependencies:
the fixture, preset script, selected rig wrapper, inherited shared-host helper,
`tools/lcb/policy_contract.py`, `tools/lcb/inertial_parameter_contract.py`,
`docs/reference/liquid-solver-capability-matrix.json`, `material.hpp` and
`interaction_rules.hpp`. The Windows input ledger gains the exact verifier,
two Python and JSON paths; its existing native-header scope remains. The
overall 15-second readback budget includes all source checks, verifier execution
and output validation. Original process/log/result and source bytes must remain
unchanged. The parent retains their digests, the original engine receipt,
reduced-result digest and verifier-log digest. A failed verifier cannot promote
a zero engine exit, and an existing receipt directory cannot be overwritten.

### Preserved original readback and source substitution control

The integrated, byte-identical verifier independently re-read all five original
704de34 cases: five 591/0 results and 185 reason-specific adverse controls.
All 27 files in the original sealed manifest remained unchanged. The readback
explicitly supplied the original preset script extracted from Git 704de34;
using the current tooltip script instead fails for `fixture_identity`.
This negative preserves the full source identity even though the preset mapping
itself did not change. No engine ran during this original-result readback, and
these older results are not relabelled as integrated-source execution.

The fresh readback receipt is
`qualification-life011-integration/original704-readback/receipt.json`, SHA-256
`2526dbdd22e4c17aa13b5f43db63ac8166c952d9fef26ae9846a1d6044835de9`.
The original manifest keeps SHA-256
`8517d76a2ee308dde712cf02bc6c6676daa74f6125e442c4cf42e15789d290d8`.

### Actual resulting-head Linux execution

The composed source introduces INPUT011's immediate UI-authority cancellation
and a changed preset-source hash alongside the new mandatory parent readback.
Those integration risks were checked with five new ordinary-runner cases at
the frozen 76111a7 source. They use actual `main.tscn`, the sole native owner,
automatic callbacks and main-thread Rapier. The official Godot binary and
accepted Linux native/Rapier runtime bytes retain the earlier hashes above.
Independent runtime custody reverified all 80 native and four Rapier source
inputs, both committed LFS pointers and their materialized binaries. This does
not assert that the historical 549-entry broader native build capture matches
all later gameplay scripts.

The clean import passed in 4.840135 seconds under its original 240-second bound.
Every import/case before-and-after capture retains 969 unchanged tracked inputs
and the unchanged engine hash. Cases ran sequentially once, with no retries.

| Rig | Assertions / failures | Engine process seconds | Fixture seconds | Parent readback seconds | Final join/destruction microseconds |
| --- | ---: | ---: | ---: | ---: | ---: |
| Stunt Buggy | 591 / 0 | 24.280 | 22.728685 | 0.545354 | 81,475 |
| Trials Bike | 591 / 0 | 25.631 | 24.171617 | 0.602568 | 77,004 |
| Acrobat | 591 / 0 | 25.289 | 23.816748 | 0.581419 | 72,585 |
| Arcade Lander | 591 / 0 | 24.875 | 23.243475 | 0.599900 | 74,801 |
| Jet Barrel | 591 / 0 | 23.953 | 22.386423 | 0.556432 | 92,117 |

The complete new campaign has 2,955 assertions, zero failures, 40 policy cohorts,
80 constructed/reset graphs, 360 completed nonneutral physical samples, 40
old-owner and 40 still-valid-lease old-generation refusals, 55 actual native
unsupported-policy refusals and five joined/destroyed worker/adapter lifetimes.
Each parent gate independently passed all 37 adverse controls. The longest
bounded operation was 1,182,837 microseconds. First Main callbacks occurred
292,242–393,716 microseconds after the recorded before-scene-load origin.
The original 30-second first-Main, 15-second operation/teardown, 150-second
fixture, 180-second engine and 15-second readback bounds are unchanged.
These are local elapsed observations, not comparative speedup or display-FPS
measurements. Physical devices and real OS focus remain untested.

Original raw results, ordinary process receipts, logs, readbacks and all source
captures live under `qualification-life011-integration/final-<rig>`; the retained
`run_local.py` and `run_campaign.py` drivers record the exact commands. In an
ordinary checkout the complete Linux runner is invoked with
`python tools/ci/run_godot_regressions.py --godot GODOT --output OUTPUT`;
normal shard arguments preserve complete coverage. The fixture is automatically
discovered, and its readback is mandatory in both ordinary platform runners.

### Parent controls and remaining gates

The normal parent unit suite records 84 passing tests and one explicit
Windows-only observer skip on Linux. The 59 focused readback methods pass under
Python optimization; independent review also passes all 59 in normal and
optimized modes at exact 76111a7. Windows runner controls pass 18/18 and shard
verifier controls pass 28/28. New controls reject incomplete policy/physics/
refusal inventories, missing or duplicate controls, wrong rig/source, substituted
or changing policy dependencies, changed raw results and exhaustion of the
single 15-second source-check/readback budget.

The first full optimized local unit invocation returned zero through the tool
but retained only 80 progress dots and no completion summary. It remains
classified **incomplete**, not passed. Two initial Windows discovery commands
used nonmatching filenames and exited five with zero tests; their logs remain
separate from the corrected named discoveries. These local tooling outcomes do
not alter the five successful engine cases or authorize any timeout change.

Independent source review of the new contract and all unchanged original
executable files is recorded in
`qualification-life011-independent-review/integration-76111a7/review.json`,
SHA-256 `7e0b72a516ca026f69246df2cb4694a4cf335472706a6822a6ca7688e0e98dd8`.
Full resulting-head hosted Documentation/provenance, Native, Windows/Linux Godot,
scope checks and final independent evidence review remain required for guarded
integration. This Linux headless campaign does not close #269, #270 or #263.
