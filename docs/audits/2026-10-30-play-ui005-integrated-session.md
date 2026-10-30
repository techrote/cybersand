---
title: PLAY-UI-005 integrated shared-host session selection
status: Current
document-kind: audit
scope: Source-bound integrated course/rig/control/rule/policy/camera selection and device rearm; local execution, retained negatives and pending promotion gates
canonical-for: []
last-reviewed: 2026-10-30
related-documents: [../systems/player-control-playground.md, ../reference/product-intent-and-priorities.md, ../reference/status-and-roadmap.md, ../operations/local-build-and-validation.md, ../operations/github-development-and-release.md]
---

# PLAY-UI-005 integrated shared-host session selection

## Decision and fresh baseline

The [owner decision](https://github.com/techrote/cybersand/issues/263#issuecomment-6522029843)
accepts merged #302 for the mandatory real-native-busy responsiveness,
outstanding-job shutdown and resource-ordering gate. #304 is optional,
non-blocking and still failed at its last authoritative run. This work follows
the actual product path #268 → #269 → #270 → #263 and adds no native-busy apparatus.

Fresh baseline: main `8d2dd843dfe457d34f32ebd015a924cf58b3c1ce`, tree
`155aa2542efa12a220c01b09a880dd8cd783562a`. The working branch is
`codex/play-ui005-integrated-session-20261030`. Root AGENTS, development handover,
canonical architecture/RAG/release/CI instructions, epic/children, open PLAY
PRs, reviews/threads, exact-head jobs and retained artifacts were reread.
Main's [Docs 41001464129](https://github.com/techrote/cybersand/actions/runs/41001464129),
[Native 41001464140](https://github.com/techrote/cybersand/actions/runs/41001464140)
and [Godot 41001464151](https://github.com/techrote/cybersand/actions/runs/41001464151)
passed. Skipped optional jobs were not counted as passes. These are baseline
results, not execution claims for this candidate.

#266/#267/#273 were closed/completed; #265 closed/Not Planned; #271 deferred;
#268/#269/#270 and the epic open. #272 is conditional fallback. The open
#290/#295/#298/#301 render-copy stack and conflicting #262 standalone feature
branch are separate work; no changes or acceptance claims are imported from them.

## Implementation and engineering review

The feature launcher and in-host button expose one composed selection panel.
It calls `main.gd::apply_playable_session` once with the original authored map,
one of five mechanical rigs, controls, rules, solver request and camera. The
existing prepared native/physical transaction retains exclusive asynchronous
ownership and main-thread Rapier. Copied options become applied only on the
matching acknowledgement. Native refusal preserves the old World/actor/options
and retires the candidate. Reset retains accepted options; the panel's next
unsubmitted selection cannot change the applied session.

The native-backed liquid editor is reused in selection-only mode. Its ordinary
comparison/import entry points retain default behavior. The new panel shows
requested/applied families and the actual native receipt variant separately,
with applied hashes in a tooltip. No solver code, family support, default,
native envelope or live-swap behavior changes. Protected scientific/blind and
deferred-swarm requests refuse before inappropriate owner replacement.

Keyboard-only excludes pad polling and button forwarding. Free play suppresses
the lap tracker/HUD. Selected-controller changes cancel through the original
physical command/edge and native-effect route and require neutral rearm.
Unrelated secondary-pad events do not cancel selected authority. Focus uses
the original Window predicate through a narrow test seam; production behavior
does not substitute synthetic focus.

Root performed source, evidence and integration review in the active session.
Support agents inventoried issues/tooling and downloaded/checksummed archives;
they did not supply an independent review. A later owner-account COMMENT review
must not be described as a separate-account GitHub approval.

## Source and runtime provenance

All 18 LFS entries were materialized and `git lfs fsck` passed. Strict current
repository provenance passed once the actual pinned companion reference files
were restored from `6a58311982941b75f46e22109a0829e5acb83c7e`, tree
`2d52f4046458ce90ce7a884d733cff5789b67f21`. The initial missing-companion failure
was retained. Native source and manifest inputs are unchanged, permitting
retained native runtime reuse under the existing GDScript-only policy. Historical
build manifests are not claimed as executions of the new scripts.

Local runtime was Linux x86_64, Godot `4.7.stable.official.5b4e0cb0f`:

| Input | SHA-256 |
|---|---|
| Godot archive | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c` |
| Godot executable | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Linux CyberSand native library | `496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6` |
| Linux Rapier library | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |

The retained local bundle records exact script/input hashes, commands, timeouts,
logs and outcomes. Final publication must bind the candidate Git head/tree and
verify that these executable inputs are unchanged, then require new exact-head
ordinary CI. Source identity and hosted status are not inherited from main.

Published [PR #307](https://github.com/techrote/cybersand/pull/307) implementation
head `ee9375dabc40636392159b57290042b306983b94` has tree
`023f32758398dfccfa40e77658d8f1e4af6cffeb`, identical to local implementation
commit `d6afbbe022247e9117fb58d9d916b51e17961128`. All seven Git blobs were
compared during publication. `final-source-manifest.json` binds all 808 tracked
Godot/native inputs with SHA-256
`1476e4d75ddfb18758e3355988d485a6425eafa88e5e0bec40d15b4cd1dcd225`.
The accompanying documentation commit changes no executable or runtime input;
its final hosted checks remain separate from the local executions below.

## Focused execution and original negatives

The actual-host fixture substitutes only OS focus and connected-device
enumeration. It builds five real sessions, performs five policy-retaining resets,
observes actual native receipts/identity/Rapier retirement, tests actual native
Oil/pressure refusal, protects specialist fixtures and checks device/focus rearm.
It does not simulate a physical controller or natural course traversal.

Initial functional execution returned 83/0; added movement-deadline assertions
returned 88/0. Existing course composition returned 126/0, gamepad event bridge
32/0, liquid editor 116/0 and real physics-cadence lap sampling 41/0 on their
recorded local inputs. These remain separate iterations, not final-head hosted
passes. Results before the subsequent launcher correction are:

| Test / evidence file | Assertions / failures | Log SHA-256 |
|---|---|---|
| `final-test_play_ui005_session_selection.log` | 88 / 0 | `74e5f95477ec0bc6685300d21c56964b671cb66564ca66e3edefc33000c35efa` |
| `final-test_play_comp002_five_rig_course.log` | 126 / 0 | `f4b5198f278653d14f4792004d76260da82beee39134fca011a5e943eae70c77` |
| `final-test_play_ui004_gamepad_events.log` | 32 / 0 | `2c00837c3efbcd32ab904235023ed36ebc64e9199703a18cedece2e81e697d4c` |
| `final-test_liquid_comparison_ui.log` | 116 / 0 | `141c4bd095650b8d9f2cdeafd4400936cafc564fb6ed3babf8480334c837a815` |
| `final-test_play_ui003_physics_cadence.log` | 41 / 0 | `457091e0c5251b5311c3edfbb3fa48322b97ade7087f2027e273d179039a039f` |

Each used `godot --headless --path godot --script res://tests/<test>.gd`,
with a 180-second bound. Final UI005 took 14.714 seconds. Other regressions used
the same final production-script bytes; the subsequent UI005-only change marks
window geometry unexecuted on headless displays. No earlier-run claim is
transferred over a production-source change.

The first graphical layout probe used the normal `main.tscn`, no special native
hold, Godot OpenGL compatibility, Xvfb and Mesa llvmpipe. It completed actual
Acrobat construction and exited zero after 97.983 seconds, but visual inspection
**failed**: the popup reached 680×6424 and its requested variant said unavailable.
The raw log, huge original screenshots and probe script are retained. Exit zero
did not make that UI acceptable. The correction disables popup auto-growth from
not-yet-laid-out wrapped labels, bounds the scrolling form and reads the actual
native `applied_variant` field from request validation. The fixture now checks
non-placeholder policy text and, only with a real display, popup/action-bar
bounds. The second graphical capture remained clipped despite a bounded window;
seeding the wrapped labels' initial width fixed the underlying content minimum.
Two attempted headless geometry checks returned 93 assertions / 5 failures
because that display supplies a 1×1 popup area. Those failures remain retained;
the final headless result explicitly says `window_layout_checked=false` and
does not count those five checks as passes.

The final ordinary graphical probe, `layout-03.log`, completed in 36.185 seconds
within its 100-second bound, returned zero, built the real Acrobat course and
was visually inspected. Popup size was 680×740; its action bar ended at y720.
The requested/applied Water variant both displayed `reference`. Its raw log
SHA-256 is `84585c3f2b77d658189acda54bc56aaf05e139cffc8f0ecf2e6f7ff1e419423a`.
Three final captures retain initial selector, applied selector and ordinary
paused course. This is software-rendered layout/construction evidence, not
representative frame pacing, physical input or human feel. No World view,
shader, renderer setting or native hold was substituted to obtain it.

Other preserved local negatives: the first import encountered unwritable
default XDG paths; the first test exited134 before script execution because its
user log path was unwritable. Subsequent runs used writable XDG directories.
The first graphical run reported unavailable audio and fell back to Dummy;
the next layout command selects Dummy explicitly. None is silently reclassified.
No local ASan/TSan campaign ran; no general race/leak/UB absence is asserted.

## First ready CI failure and launcher correction

The first ready head `64bbd818fb4b1da4c2ac5b4067f204dadca1a35b`, tree
`a1c3372159aa38595aabdf85df070990eecf45c4`, reached ordinary hosted execution in
[run41074846660](https://github.com/techrote/cybersand/actions/runs/41074846660).
Its actual merge checkout `178cfa9ccf2753231db3e2bc59ca4e2c106f0f41` has exactly
that tree and parents main8d2dd843/head64bbd818. UI005 itself returned 88/0 on
both Windows and Linux, but the full matrix **failed**: the unchanged
`test_microscenario_controllers.gd` returned 55 assertions / 3 failures on both
platforms. Its real mouse click could no longer enter Experiment Tower; the
following count assertions therefore also failed. Every assigned case executed:
Windows 201 and Linux 213, with this one failing case per platform. Windows
coverage was skipped and the Linux aggregate failed; neither is a pass.

The original eight run artifacts, including both failed shards, are retained
unchanged with provider digests, sizes, full member hashes and safe-path/CRC
checks. Root inspected raw results and all assigned-case outcomes, checked the
Linux runtime bytes, and matched Windows' 80 canonical native inputs. Of its
760 actual checkout input hashes, 634 match Git blob bytes directly, 124 match
exact LF-to-CRLF checkout conversion, and two match their LFS object IDs, sizes
and materialized runtime bytes. Both the initial raw-byte comparison and the
explicit checkout-transform reconciliation are retained; no unexplained
source mismatch was waived.

The same failure reproduced locally on head64bbd818 in 4.842 seconds, exit1,
55/3, log SHA-256
`e6607eba97a4ff9c594ab434de0bd6e1b4c8c0f900a0c2f684adb6f27c0d0397`.
The product correction places Play session in the existing wrapping action bar
instead of adding a full vertical launcher row. It also follows that bar's HUD
visibility. The original controller test and its real-click assertions are
unchanged. UI005 adds two assertions for the visible Play button and actual
viewport mouse entry into the selector.

Corrected local source hashes:

| File | SHA-256 |
|---|---|
| `godot/scripts/main.gd` | `b46a77049e4323f64a1dd9547b0171c13956d77fd69113dd59e47fd692b67596` |
| `godot/tests/test_play_ui005_session_selection.gd` | `5b3f4c108cd678f88cf0716bdcf2779548f88629260db3ecf60cf191c92f7266` |

| Corrected local execution | Result | Seconds | Log SHA-256 |
|---|---|---:|---|
| Original MicroScenario controllers, headless / 180s bound | 55/0 | 5.668 | `7c4c327a2f1af017dc1def0a35a4de4f23e0414ec79f2ef09cb60e7b2ff21061` |
| UI005 actual host, headless / 180s bound | 90/0 | 14.512 | `3449b8a5b72030923f46da79f79e9a0e868e4bb720c670da8056cd55323f4872` |
| Normal X11/OpenGL Main, actual mouse entry and Acrobat construction / 100s bound | Exit0 and root visual inspection | 7.257 | `b8e5718b99c25369c14d342375d380433d51597d1ce28f36d49ee08dca792513` |

The last capture uses the same Godot/native/Rapier pins, Xvfb and llvmpipe,
without a native hold or substitute World view. The virtual viewport is
1920×1080, captured at 1280×720 by the project's existing stretch settings; the
popup remains 680×740 in UI coordinates with actions ending at y720. The Play
button is within the viewport and actual mouse events open it. Screenshots,
probe script and original warnings are retained. This is bounded layout and
construction evidence, not physical input, human feel or representative pacing.

No earlier execution is transferred over these source changes. The corrected
publication must record its exact head/tree and run new ordinary required CI;
the first ready failure remains failed. PR #307 owns that final execution record.

## Original #302 and #304 evidence custody

The original provider ZIPs were downloaded, matched against provider size and
SHA-256, checked for safe paths/CRC, and retained unchanged. Root checked raw
#302 result rows against receipts, log hashes and all eight exact-source input
hashes. Both #302 OS results are 34/0, with five tasks/four held, Main19/physics7/
input2/Rapier7 and strict stop/release/drain/return ordering. Same-run #304 001B
controls are separate from its failed 001C graphical jobs.

| Run / artifact | Original ZIP SHA-256 |
|---|---|
| 40987544825 / 12947942476 — #302 Linux | `45f2f059d4782c1368d86a149ac330e4566a4c9929c960c3763f06ed8d4246ca` |
| 40987544825 / 12947713349 — #302 Windows | `8c4715921eb1129c272f2e4b4eb1d0f5dec7555347e7fa8c1ce752ef92115b53` |
| 40987544825 / 12948315575 — #302 Windows build | `836bf987214cf70799c01c94ff99afc44b5e9b74827e3e8e14c92d25e1d980a9` |
| 41046902349 / 12973576226 — #304 Linux failure | `3394d5f1200b14ed166e64019a15f6ac1a2f73031b357009a6b40b8a574f47a1` |
| 41046902349 / 12973072343 — #304 Windows failure | `c22524b7a822dd40bb93d4c497edc6e1d512954df71cdf935047a46a3c410e7e` |
| 41046902349 / 12972882926 — #304 Windows build | `a5b956e1908d8fe8807ff49c38ae3716a02565b233155a823303e39be1529e24` |

#302's special binaries are qualification-only. #304's authoritative Windows
and Linux host jobs remain failed; debugger or other diagnostic execution is
not an authoritative pass. Nothing here makes #304 a dependency of this change.

## Documentation change map and remaining gates

The player contract owns current behavior; owner-intent owns the changed
acceptance boundary. Roadmap, handover, documentation/retrieval indexes and build
instructions route to them. Three supplementary PLAY questions are added; the
frozen 32-question evaluation stays unchanged. The historical audit stays outside
the default canonical corpus. Existing architecture gets the accepted boundary
reference; native ownership, interface layouts, capacities and solver ADRs do
not change.

Local documentation/current-provenance checks and LFS integrity passed. The
first historical M11/validation-contract attempt failed because the partial
clone lacked the promised historical `material.hpp` blob. Fetching that exact
Git object allowed the normal checker to verify all 18 records and 28 source
hashes, and all 14 validation-contract tests passed; the initial failures remain
in the bundle. Frozen retrieval was 19/32 at rank1 and 32/32 in top5; challenges
121/152 at rank1 and 151/152 in top5; supplementary PLAY 9/9 at rank1 and top5.
Root inspected the new boundary/selector/device contexts and their qualifiers.
The LCB03 pressure-flow challenge misses its canonical page in top5 and is
reported unchanged as a limitation; no frozen wording was tuned to hide it.

Required before merge: final source review and exact-head Documentation/Native/
Windows/Linux Godot gates. Required before PLAY promotion: remaining meaningful
#269 stress/measurement, representative rendered tick/frame/snapshot/Main-wait
evidence and the [physical/human checklist](https://github.com/techrote/cybersand/issues/270#issuecomment-6485284121).
Physical gamepad, actual OS focus delivery, five-rig natural playability and human
feel remain **unexecuted**. #268/#269/#270/#263 remain open. A bounded software
layout capture is not pacing acceptance or a human sign-off.
