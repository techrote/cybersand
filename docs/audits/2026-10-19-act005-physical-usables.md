---
title: ACT-005 / USABLE-002 physical equipment integration and acceptance
status: Current
document-kind: audit
scope: Issue 182 implementation checkpoints, source and runtime identities, focused regression results and exact-head hosted acceptance
canonical-for: []
last-reviewed: 2026-10-19
related-documents: [../systems/physical-actor-rigs.md, ../systems/actor-usables.md, ../systems/thunderbowl-control-reference.md, ../operations/github-development-and-release.md]
---

# ACT-005 / USABLE-002 physical equipment integration

## Authority and work in progress

The owner requested completion of [issue #182](https://github.com/techrote/cybersand/issues/182)
and recoverable progress in the repository at least every thirty minutes during
active work. Work began on 2026-10-19 at 00:31 UTC on
`codex/issue-182-physical-usables`.

The source baseline is USABLE-001 PR #180 head
`64b2e264f3778a8d74e47b264bd6885f42a26a36`, which already contains the ACT-004
mainline merge `f2e34cf9b6fbaa5d9dedf9aa2cbc721a87472497`. It preserves all 32
U01-U32 catalogue entries alongside the 41 articulated actor mechanisms. Its
sampled equipment path remains a compatibility reference; physical integration
is the implementation owned by this issue.

## Implementation boundaries

Rapier bodies, mount ownership, aiming and recoil remain main-thread owned.
The simulation worker exclusively owns native material edits, sparse projectile
progression and processor recipes. Copied physical frames, requests and result
receipts bind those owners. Controllers share the physical actor's issued
observation and bounded lease admission; no producer writes bodies or native
cells directly.

Every actor has a defined demonstrative loadout. Release and pickup retain the
same physical body and stable coupling slot. Pending action cancellation and
already committed autonomous effects have separate lifetimes; reset retires
both with the world/session identity.

## Checkpoints

### 2026-10-19 00:37 UTC — reconciled baseline and ownership

- Read live issue, main, PR #180 and ACT-004 source and acceptance contracts.
- Created an isolated branch from the reconciled source; required LFS runtimes
  materialized without modifying dependency pins.
- Independent review identified weak sampled command freshness, sampled AABB
  origins, logical-only processors and asynchronous stale-receipt handling as
  the principal integration risks.
- Began parallel physical-owner and cellular-owner implementation, plus authored
  loadouts, scripted control, course integration and regression preparation.
- Implementation and hosted acceptance are in progress; this checkpoint does
  not claim that the issue is complete or validated.

## Validation record

### 2026-10-19 00:44 UTC — first published checkpoint

Published commit `5e5ee12c0fe3314cdc1c1421d80be41cd8a83837` on the issue branch
and opened draft [PR #183](https://github.com/techrote/cybersand/pull/183).
This checkpoint contains all 41 explicit loadouts, the shared script producer
integration and this authority record. The 32 usable IDs all appear in the
authored default loadout coverage.

### 2026-10-19 01:13 UTC — physical/worker and course integration checkpoint

Implemented the real held equipment body, local release/reattach, independent
mount aiming, incarnation-checked requests and receipts, native per-part source
occlusion, actual deployed processor ownership, all 32 equipment selections in
the desktop and a separate eight-section usable course. The copied worker frame
and matching body states are admitted atomically. Cancellation retires pending
work, while committed payloads remain autonomous until reset or expiry.

Source review and the first integrated runs exposed and corrected overlapping
source-mask attribution, aim-limit branch oscillation, late cancellation,
processor read-budget atomicity and early payload activation incorrectly gated
by launch resources. Ground, flight, and heavy delivery examples have exercised
the real runtime. Digger targeting is still being tuned against protected floor
geometry; this checkpoint is not the acceptance head.

The course processor test has exercised physical drop, free fall, settling and
fixing; blocked output without intake consumption; an authored Stone-to-Sand
cycle; and approach/pickup of the same body. A first Linux OpenGL/llvmpipe render
confirmed the production course and all 32 picker entries. Overlay clipping,
labels and equipment power presentation remain under review.

### Local validation to date

The pinned runtime is Godot `4.7.stable.official.5b4e0cb0f` on Linux with the
retained native GDExtension and Rapier. All 37 native source-sensitive input
hashes match the retained runtime provenance; this change currently modifies no
native source or dependency pin. Tests use writable isolated XDG directories and
the actual native/Rapier extensions, with 90-second focused-test timeouts.

| Scope | Result at this checkpoint |
|---|---|
| Frozen baseline native core | 71 tests passed |
| Frozen baseline ASan/UBSan | 71 tests passed; 64 MiB stack, leak detection disabled |
| Frozen baseline TSan | 71 tests passed; 64 MiB stack |
| Existing U01–U32 / session / desktop integration | 196 / 28 / 29 assertions passed |
| New physical native runtime / worker admission | 243 / 35 assertions passed |
| New physical equipment / lifecycle | 229 / 36 assertions passed before final aim additions |
| Existing physical session / desktop integration | 113 / 354 assertions passed |
| Raw ACT-004 articulation | 41 rigs × 1,200 ticks passed; raw actuation 86 assertions passed |
| New copied-observation equipment scripts | 3,993 assertions passed before final targeting additions |
| New real desktop physical equipment integration | 28 assertions passed |
| Documentation / M11 / materialized runtime identity | Passed; final exact-head rerun pending |
| Retrieval | Frozen 32/32 hit@5; all 70 prior challenges retained, three new challenges hit@5 |

Baseline command logs and local screenshots are temporary validation evidence;
the source audit, regression code and repository commits are the recoverable
record. Final integrated tests, visual corrections, independent review and
exact-head hosted merge gates are pending. Windows cross-build/inspection will
be recorded separately from interactive Windows execution. No owner feel
acceptance or browser qualification is implied.

### Final integrated local acceptance — 2026-10-19

The second recoverable checkpoint is
`90ded8d5ea6c31c34e0a611cbc7a5c91e04b6c31`, published at 01:13 UTC. PR #180
subsequently merged as current main
`42d19253c71ec3cc45fc959d11b218aeb45fbe62`. The final PR #183 source incorporates
that mainline ancestry and the validated delta described below. The exact
published acceptance head and hosted receipts are recorded on PR #183; the
earlier checkpoint results above remain historical observations.

Integrated runs corrected the Digger's fallback target to the carrier's usable
height, keeping its ordinary prepared side mount. A tested nose-specific mount
experiment was removed. Inchworm now completes its slower first gait before
processor placement; any in-progress charged jump completes before a placement
window. Processor recovery targets the observed grip, and the Heavylift closes
the remaining vertical pickup distance. The 1,800-tick Heavylift course run
physically releases, picks up and redeploys the same body, with equipment epoch
advancement rather than replacement equipment.

The real desktop course now labels equipment power, shows assembled part counts,
separates actor labels and clips effects inside the selected viewport. Equipment
aim continues through its joint when locomotion effort is zero. Early activation
of committed staged payloads remains independent of new-launch resources, power,
cooldown and muzzle clearance, and applies no second recoil. A zero-power
processor request is refused before release.

| Final local scope | Result |
|---|---|
| Physical equipment / lifecycle | 282 / 39 assertions passed |
| Physical native runtime / worker admission | 243 / 35 assertions passed |
| Copied-observation equipment scripts | 3,995 assertions passed |
| Real desktop physical equipment integration | 28 assertions passed |
| Existing physical session / desktop integration | 113 / 354 assertions passed |
| Raw ACT-004 articulation / actuation | 41 rigs × 1,200 ticks; 86 assertions passed |
| Coupled physical actor arena | 814 assertions passed, including all 41 rigs and eight actors / 64 bodies |
| Physical usable course | 71 assertions passed; all eight mixed actors accepted native equipment work |
| Retained sampled U01–U32 / session / desktop | 196 / 28 / 29 assertions passed |
| Retained physical effect admission | 32 assertions passed |
| Native core / ASan+UBSan / TSan baseline | 71 / 71 / 71 test cases passed; source inputs unchanged |

The arena regression checks actual native excavation and the corresponding
Rapier terrain collider update. Its upward Lineshank blade fixture is positioned
at `(328, 270)`, preserving the intended intersecting-earth test rather than
requiring a downward cutter contrary to the authored mount. The usable course
checks physical processor fall/settling/fixing, jammed-output refusal, an exact
Stone-to-Sand recipe, explicit pickup and reset. The jam fixture uses fixed
IndustrialBrick; loose Stone would itself fall away during a native tick.
Native recipe tests separately prove exact intake preservation when the final
required output slot or the remaining read budget prevents an atomic cycle.

Representative course results include Digger five accepted operations and 64
edited cells, Runner seven accepted operations and 25 edits, Ripper seven
accepted launches, Astra 18 accepted operations and 28 edits, and Tricopter 16
accepted operations and 35 edits. Heavylift accepts two deployments around a
successful recovery. Edited-cell totals include autonomous impacts and processor
cycles exactly once per native tick; a launch alone need not edit a cell.

Focused Godot tests use the pinned Linux executable with isolated writable XDG
directories and the following command shape, under a 90-second timeout per test:

```sh
timeout 90s "$ACT005_GODOT" --headless --path godot \
  --script res://tests/test_physical_usable_course.gd
```

Other focused scripts in the table are `test_physical_usable_equipment.gd`,
`test_physical_usable_lifecycle.gd`, `test_physical_usables_runtime.gd`,
`test_physical_usables_admission.gd`, `test_physical_usable_script.gd`,
`test_physical_usables_desktop.gd` and the retained physical/sample suites.
The real coupled CLI is independently reproducible with:

```sh
"$ACT005_GODOT" --headless --path godot \
  --script res://examples/thunderbowl/run_physical_thunderbowl.gd -- \
  --course=usables-v1 --rig=heavylift --actors=1 --ticks=1800 \
  --output=/tmp/act005-heavylift.json
```

Documentation, `check_repository.py --require-materialized`, historical M11 and
whitespace checks pass. The frozen 32-question retrieval set retains 32/32 hit@5,
22 rank-one results and MRR 0.8333. The expanded 73-question supplementary set has
73/73 hit@5, 56 rank-one results and MRR 0.8628. Updated ACT14/USABLE01 expectations
follow their current canonical subsystem ownership; three added questions cover
equipment freshness, persistent processor resources and course authority. This
is maintained fixture coverage, without a claim about unseen retrieval quality.

Independent source/coverage review found no further blocking defect in shared
command authority, incarnation fences, cancellation after extraction, consumed
receipts, same-body pickup, per-part source clearance or processor atomicity.

#### Rendered inspection and physical recoil

The production Physical Thunderbowl scene was inspected at 1280×720 and 1600×900
through Linux Mesa llvmpipe OpenGL compatibility, Godot
`4.7.stable.official.5b4e0cb0f`, Rapier `0.35.2` and Dummy audio. Course, follow
view, all 32 equipment choices, terrain, bodies and effect clipping were rendered.
A separate capture supplied ordinary issued-observation commands for a hop and
three firing edges; it did not directly write transforms, velocities, materials
or equipment resources.

At the 01:19 UTC capture the first accepted airborne shot changed the real
chassis horizontal velocity from −0.0632 to −2.8579 cells/s, with accepted recoil
`(−7.9850, −0.4893)`. The next two admitted shots likewise applied finite physical
reaction, while normal gravity, joints and contacts continued advancing. That
capture ran 240 physical ticks and produced 90 rendered frames. Its source was
unchanged during execution; later controller refinements are tested above and
the final capture identity is attached to the PR acceptance receipt.

The retained Linux native binary SHA-256 is
`5bdc55e7f355004fc8a6468234b0d018d3919339ebfe47faca9997de3af17847`;
Rapier is
`147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831`.
All 37 native source inputs remain source-matched. Native sanitizer evidence uses
a 64 MiB stack; ASan/UBSan disables leak detection and does not claim LeakSanitizer.
The graphical evidence establishes Linux software-rendered execution and visible
Rapier reaction, without a Windows interactive, hardware-performance or owner
feel-acceptance claim. Initial failed display attempts and source-changing
captures are excluded from acceptance.

#### Hosted acceptance transition

This local source checkpoint is ready for normal hosted validation. Before merge,
PR #183 must record passing results for its exact published head:

- Documentation and provenance / consistency;
- Native C++ validation / native;
- GDExtension build and current Godot regression / windows x86_64;
- GDExtension build and current Godot regression / linux x86_64, including all
  required build/regression shards and any enabled serial-equivalence check.

The Issue 49 Water apparatus is not path-applicable: this change touches no
matching native source/header, Water harness or `tools/physics` path. Draft skips
are not acceptance evidence. The hosted result, accepted head and resulting
mainline merge must be verified and recorded on PR #183 before issue closure.

### Hosted import correction — 2026-10-19 01:47 UTC

Candidate `cb39c6822248f1aa59abb22c0ed01d88bae0f326` passed ready-state
[Documentation/provenance](https://github.com/techrote/cybersand/actions/runs/39185998567),
the Windows cross-build and Linux extension build. In
[GDExtension run 39185998542](https://github.com/techrote/cybersand/actions/runs/39185998542),
Linux shards 2 and 3 each passed all 27 assigned regression cases, then failed
the required post-test `git diff --exit-code`: editor import registered the new
`CyberPhysicalUsableCourse` class in the tracked portable global class cache.
The course itself passed all 71 assertions, including real Heavylift recovery.

The correction records that eight-line class entry in
`godot/.godot/global_script_class_cache.cfg`, one of the repository's three
permitted portable bootstrap files. Regeneration produced exactly the same Git
blob (`7fa217b`) reported by both hosted jobs. A repeated editor import completed
without error diagnostics and did not change that result. The first local
sandboxed editor attempt could not create its TCP listener; only the subsequent
successful import with local editor sockets available is accepted. No gameplay
source, test behavior, native input, runtime or dependency pin changed.

Fresh rendered captures at 01:32:41–01:32:52 UTC had already matched all 253
Godot source files against the candidate, with no changes during execution.
The bootstrap-only correction preserves every captured source hash, so that
graphical and numerical evidence still applies. The final corrected head must
obtain its own normal exact-head hosted gates; the failed cleanliness jobs are
retained as historical evidence and are not treated as passing acceptance.
