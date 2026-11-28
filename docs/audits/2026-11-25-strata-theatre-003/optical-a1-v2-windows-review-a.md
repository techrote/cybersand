# A1 zero-coverage experiment — Windows and two-host disposition

## Independent decision

**Windows confirms exact compared output and meaningful same-profile cost
reductions. Both tested A1 profiles narrowly meet the registered numeric rate
and tail criteria on this hosted Windows fixture. Initial admission still
fails 45 seconds, and Linux Architectural still misses the rate criterion.**
This is a qualified isolated experiment, not a retroactive performance pass for
the unchanged fd0830ab application or permission to adopt a new default.

Observer `55951750466dc76e0482954f3d9e8bd9a9d1ada4` executes separately from
application `fd0830abcfadd9ae19162e5677943bb131223e59`. Original shader
`b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb` and
process-local A1 `50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f`
retain the same bounds, uniforms, materials and native ownership. The sole
candidate change is the previously documented exact-zero coverage branch.

The original [Windows artifact 15078960632](https://github.com/techrote/cybersand/actions/runs/45733231981/artifacts/15078960632)
from run 45733231981 is 12,530,465 bytes, ZIP SHA256
`ca2a65fc25e40e5e6bdaad898fdc8ba8fc1c7d9314bf100c81b8b4d2bb7f59e4`.
The download matched GitHub's digest and size and was safely extracted. The
unchanged strict reader independently returned exit 0 against the original
artifact and frozen application. The [machine-readable review](optical-a1-v2-windows-review-a.json)
retains source/runtime identities, receipt hashes, exact command, all three
repeat populations, diagnostic, resource counters and the cross-host numeric
summary. The [Linux review](optical-a1-v2-linux-review-a.md) remains separate;
its initial pending-Windows checkpoint is superseded by this dated result.

## Actual Windows correctness

The host was Windows Server 2022, four logical CPUs. Godot 4.7 Compatibility
used ANGLE OpenGL ES 3.0 over Microsoft Basic Render Driver/D3D11. This is
software rendering, not the owner's Windows 11/NVIDIA machine. The complete
native driver passed 4,255 checks with zero failures.

The mandatory headless resource diagnostic reproduced the original-source
expression versus live-code distinction on Windows itself. Runtime and attached
material code reported A1, while the constant/property expression and application
statistics retained the original source value; restoration succeeded. That
headless result is kept separate from the actual graphical qualification.

Before and after each of the 15 timed windows, the actual renderer resource,
three cached ShaderMaterials and three drawable attachments agreed with the
selected shader code. Fresh Classic retained zero optical materials and the
original material objects. One live Shader resource was observed and restored.
Application source and asset snapshots were unchanged across the complete run.

Original and candidate isolated fixtures each passed 109 actual graphical
assertions. Their 18 PNG pairs were byte-exact after decoding all 884,736 RGBA
bytes, including the Classic haze/partial-opacity and dense-frequency cases.
The six matched native-world image pairs were also exact across 4,515,012
pixels, including alpha. Inspection of the original retained native captures
confirmed nonempty scene content, physical material, rear construction, Water,
Sand and the actor marker. These are paused matched-image checks; they do not
prove every moving frame is equal or add a new perceptual study.

The 15 populations retain 1,350 callbacks, all 1,349 completed Rapier steps and
1,334 native counter increments. Callback count is not substituted for physical
steps. All actual completion sequence and counter checks passed. Four initial
native plane hashes, camera, actor pose and full optical settings matched;
optical native capture and decorative upload deltas were zero.

## Windows cost and admission

The registered ratios use each case's median rate divided by this job's Classic
median. The physical-p95 allowance is 401.8224 ms, derived from Classic's
334.852 ms median and the unchanged 1.20-times/plus-10-ms rule. No repeat is
dropped or reweighted.

| Case | Native ticks/s median | Rapier steps/s median | Native / Rapier rate relative to Classic | Physical p95 median | Numeric result |
| --- | ---: | ---: | --- | ---: | --- |
| Classic original | 2.951667 | 2.984832 | 100% / 100% | 334.852 ms | Reference |
| Architectural original | 2.364515 | 2.391385 | 80.107803% / 80.117917% | 417.686 ms | Rate and tail miss |
| Architectural A1 | 2.678722 | 2.708820 | 90.752856% / 90.752856% | 370.074 ms | Rate and tail meet |
| Gameplay Clarity original | 2.191808 | 2.216715 | 74.256614% / 74.265990% | 452.992 ms | Rate and tail miss |
| Gameplay Clarity A1 | 2.662265 | 2.692178 | 90.195292% / 90.195292% | 372.136 ms | Rate and tail meet |

Architectural A1's median native gain over its same-profile original was
13.288410%; the Rapier gain was 13.274108%. Gameplay Clarity gained 21.464321%
native and 21.448986% Rapier. Their median physical p95 fell 11.398994% and
17.849322%, respectively. The small native/Rapier differences are retained
rather than assumed away.

| Profile | Repeat 0 native / Rapier ratio | Repeat 1 native / Rapier ratio | Repeat 2 native / Rapier ratio |
| --- | --- | --- | --- |
| Architectural A1 / original | 1.119602 / 1.119602 | 1.135418 / 1.135275 | 1.110327 / 1.110464 |
| Clarity A1 / original | 1.218839 / 1.218839 | 1.214643 / 1.214490 | 1.221735 / 1.221585 |

Initial challenge admission took **63.802 seconds**, failing the unchanged
45-second target. The 15 subsequent replacement admissions took 6.305–7.683
seconds. Warm replacements do not erase the initial failure or the five earlier
large Windows environment failures. A1 addresses downstream fragment work; this
experiment does not establish a startup fix.

The timed windows total 525.253402 seconds. The complete native process lasted
946.250 seconds and reported 3,075.203125 sampled CPU seconds, peak sampled
process-tree RSS 1,083,588,608 bytes and 1,396 resource observations. The observer
requests a 0.5-second sampling interval; actual timestamps and observation cost
are retained. These whole-process values include admissions, compilation,
readbacks, warmups and teardown. They are neither per-profile CPU/GPU timings
nor proof of long-term memory stability.

## Two-host interpretation and next decision

| Hosted case | A1 native rate relative to same-job Classic | A1 / same-profile original | A1 physical p95 / allowed p95 | Registered observation |
| --- | ---: | ---: | --- | --- |
| Linux Architectural | 89.682079% | 1.091459 | 201.378 / 207.762 ms | Rate misses; tail meets |
| Linux Clarity | 90.466258% | 1.164185 | 183.013 / 207.762 ms | Both meet narrowly |
| Windows Architectural | 90.752856% | 1.132884 | 370.074 / 401.8224 ms | Both meet narrowly |
| Windows Clarity | 90.195292% | 1.214643 | 372.136 / 401.8224 ms | Both meet narrowly |

All twelve same-repeat original/A1 profile rate comparisons improved across
these two hosted jobs. That supports retaining A1 as a useful implementation
candidate. Both backends preserved the compared output and actual native
ownership. The gains are consistent with the source hypothesis, but this is
not a direct measurement of skipped GPU instructions or an audited compiler
optimization result.

The remaining boundary is material: Linux Architectural is still below 90%,
Windows Clarity's margin is only 0.195292 percentage points, and the Windows
startup target still fails. Three sequential repeats on two software-rendering
hosts cannot establish robust headroom on every scene, every quality tier or
the owner's hardware. Native publication observations can coalesce; the separate
Rapier hook covers every completed physical step. Neither metric is presented FPS.

The current application has not adopted A1. Its existing receipts and Windows
package cannot be relabelled as executing this candidate. If the lead selects
A1 for a new application revision, that revision needs a new explicit source
identity and appropriate source-bound qualification and delivery. The separate
texel-fetch idea remains source-only and provides no additional measured saving.
The final owner artistic, physical performance and unprimed readability gates
remain open; Draft/HOLD is unchanged.
