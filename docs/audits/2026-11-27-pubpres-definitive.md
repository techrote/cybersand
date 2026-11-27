# PUBPRES on consolidated Workbench

[Draft PR 767](https://github.com/techrote/cybersand/pull/767) joins accepted main
`7a15691a7c537d07ff10a1bc4da9d46491c0b9d6` and recovered PUBPRES
`ce4f40c8be234617fa3c33957bc423bd5ca7b54f` at
`13c0b731b0659d4a8bd00cbd5d85e5e5b66fc72b`. The accepted main commit is the
fixed comparison source for this campaign. Physical owner acceptance is on hold.

The independently verified pre-refresh [Windows evaluator](https://github.com/techrote/cybersand/actions/runs/46040083640/artifacts/15222321415)
contains application `be9195c9c81df63cf5b8322405a5518218a663ae`. Its inner
ZIP SHA-256 is `4f63110b2efda9c4020dc63ec2f09099311e66620a50527d3a80a6a14544cb09`.
All 2,849 payload files matched their manifest. All 14 launcher runs exited
normally. The selected and fallback installations each passed 215 graphical
authoring and 71 fresh-process reopen checks. [Launcher, collector, Save and reopen receipts](https://github.com/techrote/cybersand/actions/runs/46040083640/artifacts/15222521328)

## Resulting application

The pre-refresh comparison source is `e17ce40722a3fabdd6130990eecfca384bf5b6dd`.
The campaign built both platform libraries from that revision. The Windows
DLL SHA-256 is `ca5a9c751ef5c9cc4305333544c7740798202446bb4d3e6525161e8eb942e2e7`.
The Linux SO SHA-256 is `56ecc606e0f8111816ec96e4022789aeb280feef52e73292f5e9d2b9026da6b1`.
The build receipts agree on all 110 source inputs and 2,259 dependency inputs.
[Windows builds](https://github.com/techrote/cybersand/actions/runs/46032856091/artifacts/15216190801)
· [Linux builds](https://github.com/techrote/cybersand/actions/runs/46032856091/artifacts/15215219033)

Linux Stock Safe passed 204 mounted Water checks, 574 multipart checks,
12 held-placement checks, the 19 frozen outcomes and 150 native-owner checks.
One member was withheld in 4,930 draws. At dry-to-wet entry all 21 cells
under slot 0 contained Water, but the guard had reached 2,888 µs after
charging 1,202 of 24,000 cells. The other three slots remained visible.
Both 2,338-draw pauses, restoration and multipart motion had zero omissions.
The five framebuffer controls restored exactly, including the moving runner's
foot. All six members shared physical step 8 and upload 166.
[Draws, pixels, contact and owner evidence](https://github.com/techrote/cybersand/actions/runs/46032856091/artifacts/15215284913)

Windows Stock Safe passed its mounted native, held placement, frozen, multipart
and Water groups. The Water replay observed 4,831 draws and zero withheld
members. Independent PNG decoding matched all 1,125 sampled channels, with
zero error in all five restored controls. A separate comparison VM timed out
while starting the 2048² blank before its 1024×512 multipart fixture. Its only
failed assertion was initial Workbench readiness. The fixture now creates the
ordinary initial World at its registered workshop extent and records pending
owner and native state. [Windows Stock Safe qualification](https://github.com/techrote/cybersand/actions/runs/46032856091/artifacts/15217833508)
· [Comparison VM startup evidence](https://github.com/techrote/cybersand/actions/runs/46032856091/artifacts/15218951657)

In the resulting-source Linux Water-on N/C/C/N, Wave512 reached 16.29–16.61
physical steps/s against main's 15.93–16.12. No gap exceeded 100 ms. The
registered direction was **not established** because p99 failed and the
candidate's worst gap was 72.70 ms against 71.61 ms on main. Wave2048 passed
every relative predicate. Its rate rose from 7.84–7.95 to 8.94–8.99 steps/s
and p95 fell from 184–185 to 169–171 ms. That p95 still misses the 100 ms
product target. The first 144 physical trajectories and input hashes matched
in all eight arms. This host used four AMD EPYC 9V45 vCPUs. The earlier
Linux comparisons used four Intel Xeon 6975P-C vCPUs. Both used llvmpipe
LLVM 20.1.2. [Resulting-source Linux comparison](https://github.com/techrote/cybersand/actions/runs/46032856091/artifacts/15217755913)

Windows on `e17ce407` also missed the registered Wave512 direction. The
candidate reached 11.40 and 11.06 steps/s against main's 11.34 and 11.33.
One candidate gap reached 530 ms, versus 294 ms worst on main. Wave2048
passed the relative criteria at 3.29–3.61 versus 2.33–2.36 steps/s. Its
candidate p95 was 418–577 ms and its maximum was 952 ms. Main reached
1,039 ms and both main arms had gaps exceeding one second.
[Resulting-source Windows comparison](https://github.com/techrote/cybersand/actions/runs/46032856091/artifacts/15218924656)

The 530 ms Wave512 gap occurred between steps 2 and 3. A matching native
packet was ready 7.05 ms after step 2. Main started its upload at 7.58 ms,
spent 514.44 ms there, and the next scheduled physics callback began at
528.73 ms. Wave2048's 952 ms gap occurred between steps 81 and 82. A
matching packet was available at 149.65 ms, but it required a newer hard
terrain revision. The previous physics callback had already ended. The next
callback ran at 948.03 ms. These traces explain why publication timing alone
cannot guarantee an earlier correct physical step. The short CPU solver
intervals and upload calls establish neither GPU completion nor scanout.
[Raw callback, publication, upload and completion clocks](https://github.com/techrote/cybersand/actions/runs/46032856091/artifacts/15218924656)

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

Separate's deferred post-draw callback could describe a previously queued
image. During Separate4 restored authoring, 217,390 pixels differed between
the first shown image and the restoration, while hiding the actor changed
4,936. The original isolated fixture reproduced all four failures on Linux.
Ordering the first read after a single explicit Separate draw passed 137 checks
on each render thread. The mounted control now requires a later accepted draw
for each policy transition and drains the submitted work before reading.
All five RGB oracles retain their original thresholds and identity checks.

The focused Separate4 Windows run then passed. Separate0 exposed a different
failure. A full transport refresh rotated two byte-identical textures during
a pause. Slot 0 had 21 Water cells and slot 3 had 192, but the shared deadline
expired at 2,492 µs after 968 cells. A stationary, already-certified Water
sweep can now survive that specific rotation. Reuse requires the same World,
revision, physical member, geometry, image content and shape on the active
layers, and the exact front/back resource pair. Native authority and the new
submission identity are checked again. Changed Sand, an unknown previous
image or a different member still requires a fresh proof.
[Separate0 failure](https://github.com/techrote/cybersand/actions/runs/46039009759/artifacts/15220170938)
· [Separate4 control](https://github.com/techrote/cybersand/actions/runs/46039009759/artifacts/15219178238)

After the stationary-coverage repair, both Windows renderers retained
every member during both long pauses, including across an observed rotation
with zero additional cells scanned. Separate4 passed the mounted suite.
Separate0 withheld one 212-cell Water-covered member in the first accepted
frame of the restored World. The first three members consumed 224 cells and
the selection had reached 2,182 µs before checking the fourth. Its native
owner and World were new, so prior-owner coverage could not justify drawing
it. The resolver now checks stationary footprints together before constructing
per-member native proofs on the first valid paused tick-zero frame. The shared
2 ms and 24,000-cell limits, independent native checks and Sand veto still
apply. [Original Separate0 restored draw](https://github.com/techrote/cybersand/actions/runs/46042058637/artifacts/15221193719)
· [Separate4 pixels and completion records](https://github.com/techrote/cybersand/actions/runs/46042058637/artifacts/15220024134)

In a private Linux Xvfb replay of the first-frame change (`862b8659a`), the
restored draw showed all four members. The shared allowance had 1,818 µs
remaining when the resolver began checking their 666 cells. The work took
200 µs and the full guard took 790 µs. All 207 assertions and five restored
framebuffer controls passed over 4,920 observed draws. Six member withholds
across two dry-to-wet draws remain in that run. Each draw retained a visible
member. The two long pauses, restoration and multipart motion had zero
withholds. The raw receipt SHA-256 is
`54aabadab8f5d443936f6ed397175a93c479e9300a629032800365ed6a96d454`.
[Focused Windows evaluation of this repair](https://github.com/techrote/cybersand/actions/runs/46046512132)

## Integrated Workbench checks

On packaged application source `00478f29b`, 15 private graphical runs passed
2,165 assertions with the selected Stock Safe policy. They exercised pilot and
manipulation, AMBIENT takeover and handback, Goblin native gameplay and verified
storage, live Material Audition, Actor Compose, native Art and Architecture,
SWARM reciprocal, and Gentek 2048² authoring and fresh-process reopening. The
ordinary pilot case passed all 183 checks. [Resulting-source fixture, library and raw log identities](2026-11-27-pubpres-cross-feature.json)

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
| Windows ANGLE Basic, Stock Water on | Wave512 | 13.40–13.45 | 17.20–18.64 | 157.48–158.10 | 162.68–164.18 |
| Windows ANGLE Basic, Stock Water on | Wave2048 | 3.92–3.93 | 5.09–5.19 | 297.42–383.90 | 519.00–550.30 |

All eight rows pass the pre-registered relative direction.
All Windows cases missed the absolute p95 target. Only Wave512 with Water on
stayed within the 250 ms maximum on Windows. Different hosts
ran the two Linux treatments. [Linux Water off](https://github.com/techrote/cybersand/actions/runs/46022262388/artifacts/15212292477)
· [Linux Water on](https://github.com/techrote/cybersand/actions/runs/46025029508/artifacts/15213265135)
· [Windows Water off](https://github.com/techrote/cybersand/actions/runs/46022262388/artifacts/15212507592)
· [Windows Water on](https://github.com/techrote/cybersand/actions/runs/46022262388/artifacts/15215017931)

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

The same application's Windows Water-off N/C/C/N increased Wave512 from
11.14–12.15 to 13.47–14.05 completed physical steps/s, and Wave2048 from
2.76–2.92 to 4.04–4.07. At 2048, candidate p95 gaps were 388–497 ms and
maxima were 722–803 ms. Across the two candidate arms, 12 gaps exceeded
500 ms, down from 32 on main. At 512 the candidate's native tick took
3–5 ms p95 and the first handoff to physical execution took 219–221 ms p95.
[Windows fallback N/C/C/N and material-family controls](https://github.com/techrote/cybersand/actions/runs/46027331150/artifacts/15214593993)

The Windows Water-on sessions at 512, 1024, 2048 and mixed 2048 completed
5,963, 5,232, 4,748 and 3,970 physical steps in five minutes each. Each
accepted all 79 actions and shut down normally. Final-minute observed p95
gaps were 106, 115, 130 and 136 ms. Peak process RSS ranged from 764 to
951 MiB, with two persistent material texture RIDs. The sampled intervals
exclude a late gap above 500 ms. In the last three worlds, 13, 23 and
38 multi-step intervals respectively could conceal a gap above 250 ms.
[Ordinary session clocks, resource samples and framebuffer images](https://github.com/techrote/cybersand/actions/runs/46027331150/artifacts/15215066942)
