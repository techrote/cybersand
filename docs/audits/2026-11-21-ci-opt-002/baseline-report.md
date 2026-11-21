# CI-OPT-002 read-only performance baseline — 21 November 2026

## Main finding

The latest accepted-main cohort at `0f0161af337d6d0cee8fa961a9667aff570a75b0`
completed its observed routine workflows in **30m37s elapsed**, using **298.70
unweighted runner-minutes** across seven workflows. Native is the limiting
workflow. Its worldgen family spent **29m23s**, of which the sanitizer command
took **23m24.917s**. This routine cohort must not be conflated with the full
Gentek native/publication/owner-package campaign, which can exceed two hours.

No optimisation speedup is claimed by this baseline. The selected records
include successful, failed, conditionally skipped and zero-job workflows.
`baseline-summary.json` contains the complete metrics and all retrieved jobs;
the `jobs-*.json` files preserve the original GitHub API pages.

## Accepted-main cohort

| Workflow | Run | Elapsed from event to last executed job | Runner-minutes | Executed / conditional skipped jobs |
| --- | --- | ---: | ---: | ---: |
| Native | [44941414576](https://github.com/techrote/cybersand/actions/runs/44941414576) | 30m37s | 89.95 | 8 / 1 |
| GDExtension | [44941414698](https://github.com/techrote/cybersand/actions/runs/44941414698) | 19m11s | 169.80 | 54 / 2 |
| Documentation | [44941414603](https://github.com/techrote/cybersand/actions/runs/44941414603) | 9m10s | 9.12 | 1 / 0 |
| Palette GL/ANGLE | [44941414560](https://github.com/techrote/cybersand/actions/runs/44941414560) | 7m14s | 15.95 | 8 / 0 |
| Wave Flow | [44941414598](https://github.com/techrote/cybersand/actions/runs/44941414598) | 5m22s | 13.05 | 4 / 1 |
| GEN-007 publication guards | [44941414570](https://github.com/techrote/cybersand/actions/runs/44941414570) | 26s | 0.38 | 1 / 4 |
| Report-only Native scope | [44941414743](https://github.com/techrote/cybersand/actions/runs/44941414743) | 31s | 0.45 | 1 / 0 |

All seven workflows report success, but their conditional skips are explicitly
retained. In particular, the GEN-007 full native/package publisher did not run
in this main cohort. The ordinary Native six families and all 47 GDExtension
platform shards did execute. First successful job was the Palette planning/admission
result at **25s**; the GEN-007 publication guard followed at **26s**. These are
admission/policy results, not complete native test qualification. Initial job-start delays were approximately 3–4 seconds.

The six Native family job times were worldgen **1763s**, soliding-asan **1259s**,
tsan **860s**, asan-ubsan **770s**, native-normal **522s**, and soliding-normal
**159s**. Its aggregate required `native` result followed all six.

GDExtension's Linux build took **425s** and Windows build **260s**. Platform
shards ran in bounded waves; the final Windows shard finished at 19:49:58Z,
followed by source/inventory aggregation and performance-history retention.
Per-shard Godot preparation is only a small part of this path (representative
Linux preparations were 6–7 seconds). Sharing downloads might save acquisition
work, but cannot remove the current Native bottleneck.

## Stage A: observed wasted work before late rejection

| Existing failing run | Failure | Executed job time | Preceding material + LCB compilation |
| --- | --- | ---: | ---: |
| [44898745316](https://github.com/techrote/cybersand/actions/runs/44898745316) | Runtime manifests require rebuild for world_generation / cyber_world_generator source inputs | 427s | 354 + 35 = **389s** |
| [44912434764](https://github.com/techrote/cybersand/actions/runs/44912434764) | Runtime manifests require rebuild for cyber_native_cell_world source inputs | 509s | 436 + 42 = **478s** |
| [44855435069](https://github.com/techrote/cybersand/actions/runs/44855435069) | Existing check_docs rejects missing required frontmatter | 428s | 343 + 33 = **376s** |

The failures and exact source-input/frontmatter messages were confirmed in the
original logs. Moving those same admission checks ahead of expensive compilation
can avoid this observed work on an invalid candidate. These are historical
before measurements; the values are not an observed after result or a claim
that successful routine CI is 30% faster.

## Stage B: worldgen attribution and modest split candidate

The exact main worldgen artifact is
[14722054189](https://github.com/techrote/cybersand/actions/runs/44941414576/artifacts/14722054189),
ZIP SHA-256 `77adf07cbe9e5753043041c2ad0124188eb30257a39285e85fef33f25d22ef99`.
Its actual command receipts record:

| Unchanged command | Seconds |
| --- | ---: |
| Physics characterisation with ASan/UBSan | 97.899 |
| `make -j2 worldgen-test` | 241.918 |
| `make -j2 worldgen-sanitize` | 1404.917 |

The sanitizer GNU-time report gives user CPU **1649.71s**, system CPU **19.43s**,
average CPU **118%**, max-child RSS **1,695,292 KiB**, and zero swaps. The runner
had four logical CPUs. Max-child RSS is not aggregate concurrent memory.
The telemetry field marked `direct_process_only` is the wrapper's memory and
must not be mistaken for native/compiler peak RSS. Low aggregate CPU utilisation
suggests substantial serial execution, but existing logs cannot isolate its
duration: nested command runners buffer output, and the raw command log contains
no per-command timestamps.

The safest modest proposal is a separate clean-runner `worldgen-sanitize` family,
while retaining physics and ordinary worldgen in the existing `worldgen` family.
The retained independent build inventory contains **28 normal outputs and 28
sanitized outputs, with zero shared output paths**, and **16 ordered tests in
each mode**. Existing normal/sanitized compilation already uses separate shared
object directories, so separating jobs loses no established cross-mode object
reuse. Physics custody remains in its original family.

This removes an estimated **339.817 seconds of serial dependency** from the
sanitizer path, before extra runner setup and scheduling effects. It is an
estimate, not an observed speedup. Keep the six-runner parallel cap and schedule
the short soliding-normal family after the long groups. The required `native`
aggregate would have to require all seven exact-source receipts; missing,
duplicated, mixed-source, failed, cancelled and timed-out evidence must remain
red. Preserve all original twenty command definitions and test order within
each command. Same-job overlap is less attractive because it shares filesystem
and CPU resources; changing to `-j4` is not justified by these timings alone.

Temporary transparent profiling helpers are available only in this ignored
audit directory. `profile_make_shell.py` retains `/bin/sh` arguments, environment,
streams and original exit/signal outcomes while writing completion records.
`profile_process_tree.py` samples descendant sum-RSS every 500ms and records
physical/cgroup memory information. They create no new process groups. Samples
can miss short peaks and sum-RSS can double-count shared pages. The existing
seven-showcase shell loop remains one observed command; nine remaining tests
are separate shell commands. These tools provide diagnostic evidence, not a
replacement qualification gate.

## Variability, expensive acceptance and failed-run accounting

Two successful Native runs at the identical premerge head `8fbfa41208aa…`
recorded worldgen job times of **2181s** and **1459s**:
[44935621498](https://github.com/techrote/cybersand/actions/runs/44935621498) and
[44941398009](https://github.com/techrote/cybersand/actions/runs/44941398009).
The accepted-main observation was 1763s. A single old/new pair can therefore
mislead. A candidate needs a source-compatible control, known command/test
inventory, compiler/platform identity and explicit runner variability.

The failed full Gentek campaign
[44893010398](https://github.com/techrote/cybersand/actions/runs/44893010398)
lasted **154m54s** to the final executed job and used **231.43 runner-minutes**.
Linux ran **76m41s** and Windows **148m59s**, then failed late attestation;
publication itself was skipped. Windows all-80-style qualification consumed
4187s and packaging/re-execution 3942s. This is expensive acceptance/publication
work, not the ordinary main CI critical path.

A separate successful SWARM Windows graphical qualification
[44928289786](https://github.com/techrote/cybersand/actions/runs/44928289786)
took **47m28s** elapsed / **47.37 runner-minutes**. Its two independent source
and pristine-package graphical cohorts consumed 1102s and 1068s. The Paint
owner-package example [44939560729](https://github.com/techrote/cybersand/actions/runs/44939560729)
took **5m17s** elapsed / **5.18 runner-minutes**. These are different coverage
contracts and cannot be compared as optimisation arms.

The failed GDE run [44930163662](https://github.com/techrote/cybersand/actions/runs/44930163662)
retains all 56 job records, including two failed regression shards and failed
platform aggregates. Its **176.83 runner-minutes** remain counted. Zero-job
failure [44930160731](https://github.com/techrote/cybersand/actions/runs/44930160731)
has no measured execution interval; metadata `updated_at` occurred two hours
after creation, which must not be reported as two hours of runner execution.

## Measurement method

- Retrieve all job pages and require returned count to equal `total_count`.
- Wall time is event creation to the last actually executed job's completion.
- Runner-minutes sum every executed job, including failures; conditional skips
  contribute zero. Platform billing multipliers are not applied.
- Initial queue delay is directly observed. Later job-start delay combines
  dependencies, bounded matrix scheduling and runner queueing until a workflow
  dependency model separates them.
- Keep raw source/attempt identities, statuses and job metadata. Distinct commits
  require explicitly audited relevant-source and test/command equivalence;
  an identical commit SHA alone is neither always possible nor sufficient for
  a before/after workflow change.
- No warm compiler-cache path has been established; the Native examples are
  fresh-runner builds without a compiler-cache step.
