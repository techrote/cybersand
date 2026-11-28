# A1 zero-coverage experiment — independent Linux v2 review

## Decision and exact boundary

**The corrected experiment is valid and shows a useful bounded improvement.
Architectural still fails the registered rate criterion; Gameplay Clarity
narrowly meets the numeric rate and physical-tail criteria on this hosted
fixture. The frozen application remains unchanged and on PERFORMANCE HOLD.**

This review concerns external observer
`55951750466dc76e0482954f3d9e8bd9a9d1ada4`, tree
`edc750a1e2205b079dca5fd284af9091038aca6d`, against immutable application
`fd0830abcfadd9ae19162e5677943bb131223e59`. The application tree remains
`fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499`. The original shader is
`b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb`;
the process-local A1 candidate is
`50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f`.

The original [Linux artifact 15077982082](https://github.com/techrote/cybersand/actions/runs/45733231981/artifacts/15077982082)
from run 45733231981 is 14,800,104 bytes, ZIP SHA256
`70eccf59fc91c96d88c0f390cc48995454022a5567405457d7ea7c1c8e51464a`.
Its GitHub digest and byte length were checked before safe extraction. The
unchanged v2 strict reader independently completed with exit 0 against the
original files and exact frozen application. The [machine-readable review](optical-a1-v2-linux-review-a.json)
retains full three-repeat summaries, source/runtime identities, every process
receipt hash, the original diagnostic and the reader invocation. Raw originals
remain in the artifact; no log is rewritten or omitted to obtain this result.

## Identity, pixel and native correctness

The actual renderer was Godot 4.7 Compatibility on OpenGL 4.5 Mesa 25.2.8,
llvmpipe LLVM 20.1.2, on a hosted Linux x86_64 machine with four logical CPUs.
This is software-rendered comparative evidence, not physical NVIDIA evidence.
The driver completed 4,256 checks with zero failures.

The separate headless identity process demonstrated the relevant evaluation
behavior on this host: runtime Shader variables and an attached material see
A1 code after mutation, while the constant/resource expression and application
`statistics()` preserve the original source value. The original code was
restored. This diagnostic is not graphical or performance qualification; the
subsequent graphical processes supply that evidence.

All 15 native timing windows retained matching pre/post direct Shader and
ShaderMaterial attachment identities. All three actual rear-plane drawables
used the selected code; fresh Classic had zero optical materials and restored
its original materials. One shared Shader resource was observed and restored.
Source and asset snapshots before and after the complete run were exact.
The v1 annexes remain rejected; this result does not retroactively fill them in.

Both isolated actual graphical fixtures passed all 109 unchanged assertions.
All 18 original/A1 PNG pairs were exact after decoding, comparing 884,736 RGBA
bytes. That includes the literal Classic haze/partial-opacity comparison and
dense-frequency/white-hue witnesses. The six matched native-world comparisons
were also exact across 4,515,012 pixels, including alpha. These are same-host,
same-repeat comparisons of Architectural and Gameplay Clarity. They do not
qualify every possible parameter combination or every corpus scene.

The timed windows retained 1,350 callbacks, all 1,350 completed Rapier steps and
1,335 native counter increments, with zero optical native captures or decorative
uploads. Four initial native plane hashes, initial actor poses, full optical
settings and camera states matched between windows. Native publication
observations remain separate from the complete Rapier completion population.
Every timed source, pose and attachment check passed; no nominal FPS was used.

## Matched performance outcome

The comparison retains all three forward/reverse/forward repeats. The criterion
is the ratio of each case's median rate to Classic's median rate. It is not
changed after the run to a median of paired ratios. The required rate remains
at least 90%; the physical-p95 limit is 207.762 ms, the larger of 1.20 times Classic's
173.135 ms median p95 or that median plus 10 ms.

| Case | Native ticks/s median | Rapier steps/s median | Rate relative to Classic | Physical p95 median | Registered numeric result |
| --- | ---: | ---: | ---: | ---: | --- |
| Classic original | 6.879500 | 6.956798 | 100.000000% | 173.135 ms | Reference |
| Architectural original | 5.652690 | 5.716203 | 82.167161% | 214.941 ms | Rate and tail miss |
| Architectural A1 | 6.169678 | 6.239001 | 89.682079% | 201.378 ms | Rate misses; tail meets |
| Gameplay Clarity original | 5.345909 | 5.405976 | 77.707817% | 240.610 ms | Rate and tail miss |
| Gameplay Clarity A1 | 6.223626 | 6.293554 | 90.466258% | 183.013 ms | Rate and tail meet on this fixture |

A1 increased Architectural's median native and Rapier rates by 9.145890% over
its same-profile original, with p95 reduced by 6.310104%. Gameplay Clarity's
corresponding gain was 16.418478%, with p95 reduced by 23.937908%. All three
same-repeat A1/original rate ratios exceeded 1 in both profiles:

| Profile | Repeat 0 | Repeat 1 | Repeat 2 |
| --- | ---: | ---: | ---: |
| Architectural | 1.080462 | 1.121873 | 1.074519 |
| Gameplay Clarity | 1.161682 | 1.189949 | 1.161682 |

Architectural's 89.682079% must not be rounded into a 90% pass. Clarity's small
0.466258 percentage-point margin is a numerical observation, not broad
performance acceptance. Three sequential repeats are not a statistical
independence claim. Original application results from another job use their
own Classic control; absolute rates from those runs must not be pooled with
this experiment to manufacture a different comparison.

Initial native challenge admission took 12.991 s. Each of the 15 replacement
admissions took 1.680–2.329 s, so all met 45 s on this small hosted fixture. These
observations do not replace the original five large extracted Windows failures
or qualify startup improvements for those environments.

## Resource scope and disposition

The 15 windows contain 222.456819 s of timed progression. The complete native
process lasted 378.336 s and includes startup, admissions, shader changes and
compilation, native hashes, graphical readbacks, warmups and teardown. Its
sampled whole-process CPU total was 764.49 s, with peak sampled process-tree
RSS 1,432,399,872 bytes and 750 observations at 0.5 s intervals. These are
whole-process observations; they do not attribute CPU, memory or GPU time to
one profile. They are not evidence of indefinite leak freedom or input-to-photon
latency.

The source hypothesis is supported on this scene: skipping downstream work in
exactly empty centre/neighbourhood coverage preserves the compared output and
reduces cost. It retains kernel sampling, so dense coverage and other backends
may benefit less. The cross-filter anisotropy, published-mask alignment risks
and artistic limits documented for the original implementation remain.

At this checkpoint the corresponding Windows v2 job is still in progress.
No application adoption, changed default, merge, Ready promotion or owner
acceptance follows from this research. A changed application would need its own
source identity and qualification. The original fd0830ab enabled-optics failure
remains valid negative evidence and the product disposition remains Draft/HOLD.
