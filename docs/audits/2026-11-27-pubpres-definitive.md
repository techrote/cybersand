# PUBPRES on consolidated Workbench

[Draft PR 767](https://github.com/techrote/cybersand/pull/767) joins accepted main
`7a15691a7c537d07ff10a1bc4da9d46491c0b9d6` and recovered PUBPRES
`ce4f40c8be234617fa3c33957bc423bd5ca7b54f` at
`13c0b731b0659d4a8bd00cbd5d85e5e5b66fc72b`. The accepted main commit is the
fixed comparison source for this campaign. Physical owner acceptance is on hold.

## Protected World source transition

The LF SHA-256 of [world.cpp](../../native/src/world.cpp) changed from
`98254d531ca7ca8f8e76f6d963f15b26b772777dc5633718a92cc637217eb77c`
to `fd7079d6cf4798275280eeb99ed996258482327c4bfeae64a2efb02655daac3e`.
Review `git diff 7a15691a 13c0b731 -- native/src/world.cpp`. The file imports
the recovered persistent worker pool, passes its constructor the immutable
World selector, and exposes its completion counters. The material laws and
Material Audition owner calls in this file match accepted main. Wave's
occupied-mask optimization is separately implemented in `world_wave.inc`.

The evaluation selects all-worker completion. The [eight-arm native result](2026-11-26-pubpres-closure/qualification/native-abba-independent-55dea.md)
records why the alternative was rejected. The closure checks the bytes of
every native input and separately checks the generated godot-cpp dependency.
At the join, N and C share 104 native files byte for byte. Five differ, and C
adds `persistent_worker_pool.hpp`.

## Presentation and input

Grab and Place now resolve the pointer through the submitted camera and pick
the displayed physical member in draw order. A live grab revalidates the
session, epoch, actor, part and body identity before applying force at that
member's local anchor. Paused Place translates the captured live assembly until
the displayed limb's local contact reaches the pointer. Release checks the body
and generation again. A private graphical control displaced and rotated the
paused Runner while its framebuffer stayed fixed. The prior implementation
misplaced the preview, and the fix installed the selected foot within 0.00004
world units of the release point. Ordinary JSON Save also retains the full
precision of a fractional authored spawn. Mouse-driven create and fresh reopen
passed 92 and 15 checks. The tests exercise a new Sand upload before a draw and
retired or withheld members. The multipart tests use the authored logical
capacity and the actual maximum physical roster for their respective bounds.

On Windows, the Stock Safe held-limb control passed 12 checks. Each build02
mode (Safe0, Separate0 and Separate4) passed 125 checks, including accepted-frame
picking and placing the rotated limb. The original 60-second run timed out while
creating a 2048² blank before its 512² input case. The replay started directly
with the registered 512² extent and recorded the native/Workbench installation.
[Four Windows input receipts](https://github.com/techrote/cybersand/actions/runs/46030558777)

Windows Stock Safe and build02 Safe0 passed the actual Water gates on
`2ac2c020`. Separate0 and Separate4 failed the opacity, clipping and
restore framebuffer controls. The experimental engine therefore failed its
registered Water qualification. The standalone package selects official
Stock Safe, two slots and Water composition, with a Stock Safe Water-off
fallback. Both use all-worker native completion.
[Original Windows renders and logs](https://github.com/techrote/cybersand/actions/runs/46022262388/artifacts/15215285088)

## Integrated Workbench checks

On 27 November, the source at `cc0a8475` passed actor manipulation (78 checks),
AMBIENT defaults and handback (68), Material Audition across World replacement
(86), native Actor Compose (351), Art and Architecture (85), native authoring
(132) and the SWARM controller (48). SWARM reciprocal creation and fresh-process
reopen passed 264 and 81 checks. Gentek 2048² authoring and fresh-process reopen
passed 73 and 53. A cold pilot test timed out during blank Workbench installation
on a contended software display. The unchanged pilot test passed 183 checks on a
fresh private Xvfb screen. The [test, runtime and log identities](2026-11-27-pubpres-cross-feature.json)
include both outcomes. These tests preceded the final Water staging guard.

On application `2ac2c020`, Wave1024 (four workers), Pressure512 and FreeMass2048
each completed 144 physical and 144 native steps and reproduced the current GPU
material plane. All 724, 921 and 812 inputs respectively were accepted. These
Linux software-display runs used restricted CPU affinity and establish
functional controls. The [Water receipt](2026-11-27-pubpres-water-visibility.json)
separately records moving limbs, exact framebuffer comparisons, deadline refusals
and the rejected row-classification experiment.


Goblin's mounted runner passed 447 mixed actor and human-handback checks, 149
native Sand/Wood construction checks and 67 verified-storage checks. The
original capacity assertion counted Actor Compose's eight-actor default as its
maximum. Correcting that fixture preserved the installed actors, eight Rapier
bodies and native World through pilot, drive, handback and Save. Fresh reopen
restored the authored digest in a new owner at tick zero. [Exact mounted
commands and source delta](2026-11-27-pubpres-goblin-mounted.json)

## Matched execution before the final input repair

The table compares completed physical steps on integrated application
`2ac2c020` and main `7a15691a`. Each range spans the two matching arms in
N/C/C/N order. The first 144 completed trajectories and admitted inputs match
in each comparison. Final input, save and resulting-package gates are separate.

| Hosted adapter and treatment | World | Main steps/s | PUBPRES steps/s | PUBPRES p95 gap (ms) | PUBPRES maximum gap (ms) |
| --- | --- | ---: | ---: | ---: | ---: |
| Linux llvmpipe, Stock Water off | Wave512 | 12.04–12.10 | 12.62–12.69 | 82.35–82.46 | 84.42–84.72 |
| Linux llvmpipe, Stock Water off | Wave2048 | 5.17–5.31 | 6.86–7.05 | 221.72–221.89 | 226.19–227.01 |
| Linux llvmpipe, Stock Water on | Wave512 | 11.64–11.91 | 12.22–12.26 | 84.25–84.68 | 87.39–87.69 |
| Linux llvmpipe, Stock Water on | Wave2048 | 4.85–4.89 | 6.23 | 233.03–233.26 | 238.63–239.04 |
| Windows ANGLE Basic, Stock Water off | Wave512 | 10.81–10.86 | 11.70–11.92 | 256.50–263.74 | 263.52–279.83 |
| Windows ANGLE Basic, Stock Water off | Wave2048 | 2.36–2.38 | 3.42–3.58 | 404.52–495.11 | 600.68–871.84 |

All six rows pass the pre-registered relative direction.
The Windows cases miss the absolute p95 and maximum targets. Different hosts
ran the two Linux treatments. [Linux Water off](https://github.com/techrote/cybersand/actions/runs/46022262388/artifacts/15212292477)
· [Linux Water on](https://github.com/techrote/cybersand/actions/runs/46025029508/artifacts/15213265135)
· [Windows Water off](https://github.com/techrote/cybersand/actions/runs/46022262388/artifacts/15212507592)

The Windows Water-off candidate's small world took 4.1–4.7 ms p95 per native
tick, while the interval from the worker's first physics handoff to execution
start was 248–257 ms p95. The large world had 285–315 ms p95 native ticks,
289–315 ms p95 from handoff to execution start, and 6–24 ms p95 from Rapier
execution start to completion. These clocks can overlap. The Linux small-world
handoff interval was 77 ms p95 against 5 ms native and under 1 ms Rapier.
Accepted main lacks the separate handoff stamps. The measurements identify a
main-thread scheduling delay at 512 and an additional native cost at 2048.

Four separate Windows Stock Water-on sessions each ran five minutes with 79
accepted actions. Wave512, Wave1024, Wave2048 and Mixed2048 completed 5,087,
4,635, 4,508 and 3,584 physical steps. Final-minute observed consecutive-step
p95 gaps were 115, 128, 129 and 130 ms, with maxima 124, 196, 146 and 198 ms.
The enclosing multi-step intervals exclude gaps above 500 ms across covered
late intervals, and above 250 ms for Wave512. For the other worlds, 14, 30
and 35 late intervals respectively could conceal a gap above 250 ms. The
longest mixed late gap overlapped a 220 ms SceneTree interval. The next paint
and camera actions followed the gap. The medium case's 196 ms gap overlapped
a 204 ms SceneTree interval without an action within one second. Each case
retained two sampled texture RIDs, had zero pending hard-terrain chunks at
sampling, and exited cleanly. Peak process RSS ranged from 772 to 961 MiB.
[Session receipts, clocks and process data](https://github.com/techrote/cybersand/actions/runs/46022262388/artifacts/15213445404)

## Measurements after the input repair

Linux application `88bb920c` passed the registered N/C/C/N direction on both
worlds with Stock Safe Water on and off. With Water on, Wave512 rose from
11.50–11.65 to 12.13 physical steps/s and Wave2048 rose from 5.00–5.05 to
6.38–6.73. Wave2048 p95 fell from 260–263 to 228–230 ms. Both candidate
arms stayed below 234 ms maximum, while the main arms had 84 and 70 gaps over
250 ms. The large case still missed the 100 ms p95 target. The native Water
replay recorded eight withheld member-draws in 4,928 draws and all five
restored RGB controls matched exactly.
[Water-on comparison](https://github.com/techrote/cybersand/actions/runs/46027331150/artifacts/15214796281)
· [Water-off comparison](https://github.com/techrote/cybersand/actions/runs/46027331150/artifacts/15213628842)
· [Graphical and native receipts](https://github.com/techrote/cybersand/actions/runs/46027331150/artifacts/15214485857)
