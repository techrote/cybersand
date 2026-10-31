---
title: Bounded worldgen build investigation
status: Current
document-kind: evidence
scope: Original post-merge worldgen timeout, unchanged-deadline two-job prerequisite candidate, inventory controls and retained local qualification failures
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../operations/local-build-and-validation.md, ../operations/github-development-and-release.md, 2026-10-31-ci-parallel-production-integration.md, 2026-10-21-gen004-hierarchical-generation.md]
---

# Bounded worldgen build investigation

This isolated candidate starts from accepted main
`5c709f837a0e2b3248bc9df85baf6da9c8a88a0b`, tree
`901166624bfde7cf2691c57a8937e59d3402febc`, on
`work/worldgen-bounded-build`. It changes only the two Native workflow worldgen
invocations, adds a nonexecuting inventory checker and adverse controls, and
records their evidence. The Makefile, native sources, scientific tests and solver
defaults remain byte-identical to that base. Committed runtime LFS identities
and dependency pins are unchanged; no Godot/Rapier runtime payload is loaded for
this native-build investigation. This is a source candidate, not an integration
or cold-build pass.

## Accepted-main integration preparation

The original candidate remains preserved at
`5afaabc01ed892bdb5e882544d61933dced32efa`, tree
`876207af6edc6f1ffd46c439c920d90d955b2328`. A new isolated branch,
`work/worldgen-bounded-integration`, starts from accepted main
`afa8185c8dc57405ef54765a6cdf71cb7bfbf6e4`, tree
`6ec0ca07a9f49c4c3039b52c87d15414582c31e5`, which includes accepted INPUT010
PR #318. The unchanged candidate cherry-picks without conflicts as
`85fae19cd0ff814a68f3fdeb7d4617da5ecc76bf`, tree
`f83a05937f6fd5e52f45b106989106e57885c2e5`. This integration note is a later
documentation-only addition.

The Native workflow, inventory checker and twelve-test source are byte-identical
to the original candidate. The Makefile, native sources, complete Godot tree,
committed runtimes, dependency pins and protected scientific inputs remain
identical to accepted main `afa8185c`. Only the original five candidate paths
differ from that accepted main. All twenty Native timeout-wrapped commands
retain their original order and limits, modulo exactly the two authorized
worldgen wrappers described below.

Integration preparation runs inventory/adverse, provider, Native evidence,
documentation, repository identity, M11 and retrieval controls only. It performs
**no native compilation or engine execution**, chmod of failed outputs, or
retry. The normal and sanitizer failures below retain their original **5c709f
base plus local candidate delta** identities; cherry-picking them onto a newer
main does not requalify or relabel those executions. Full resulting-head hosted
gates and independent final review remain required.

## Original hosted failure

Post-merge Native run
[41175310972](https://github.com/techrote/cybersand/actions/runs/41175310972),
attempt 1, worldgen job
[124461524540](https://github.com/techrote/cybersand/actions/runs/41175310972/job/124461524540),
used that accepted source on GitHub-hosted Ubuntu 24.04.5 image
`20261025.353.1`, GCC 13.3.0 and GNU Make 4.3. The preceding physics CLI
qualification passed its 154 invocations, and all nine normal worldgen binaries
passed. The subsequent unchanged `timeout 10m ... make worldgen-sanitize`
returned **124**.

| Original timestamp, UTC | Observation |
|---|---|
| 06:32:31.942899 | Sanitized target begins its prerequisite work |
| 06:32:31.945217 | First sanitizer compilation command |
| 06:41:42.848836 | First sanitized test executable starts |
| 06:41:50.781937 | First sanitized test prints PASS |
| 06:42:05.926291 | Ninth test, `test_generation_planes_sanitized`, starts |
| 06:42:32.000577 | Make is terminated at recipe line 223 by the original command budget |

Prerequisite compilation/linking consumed approximately **550.906 seconds**.
Eight of nine sanitized tests printed PASS. The ninth ran approximately
**26.074 seconds** before termination and has no completed result. This is an
aggregate build-plus-test budget failure with an incomplete final executed test;
it is neither solely a compilation failure nor a passing nine-test suite. The
log contains no compiler error or sanitizer finding in this phase. Existing
conversion warnings remain intact.

The original complete job log is retained as
`317-postmerge-worldgen-124461524540-original.log`, SHA-256
`b94fb68efe7a3e9c9da3d8363cae653afcd836dc01765f28e346382e1ad21186`.
The original run, attempt, log and artifact catalogue are not replaced by this
candidate or its local diagnostic results.

## Bounded candidate and unchanged command inventory

Only these two actual compiler/test commands change:

```sh
timeout 5m /usr/bin/time -v make -j2 worldgen-test
timeout 10m env ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1 /usr/bin/time -v make -j2 worldgen-sanitize
```

There is no precompilation, cache restoration, retry or wider deadline. Both
compilation and test execution stay inside the original 300/600-second limits.
The other 18 timeout-wrapped Native commands, sanitizer environments, six family
jobs, 90-minute job ceilings, first-failure capture and independent aggregate
gate remain unchanged. TSan and soliding limits are unchanged. GitHub-hosted
runner routing remains literal `ubuntu-24.04`.

The existing Makefile already separates normal, normal-threaded, sanitized and
sanitized-threaded generation objects. Each aggregate has twelve distinct object
compilations and nine binary compile/link recipes. Shared prerequisites are
deduplicated by make; no normal/threaded variant shares an output path. GNU Make
waits for all prerequisites before starting the aggregate recipe. Its nine
commands remain sequential, in this unchanged order:

1. World generation.
2. World generation installation.
3. Generation fields.
4. Generation modifiers.
5. Typed generation.
6. Typed integration.
7. Spatial generation.
8. Semantic grammar.
9. Semantic planes.

`-j2` limits concurrent make prerequisite recipes to two. It may increase memory
pressure compared with serial compilation; source graph inspection does not
prove a hosted memory or timing margin. The retained `nproc`, `MemTotal` and
`time -v` output establish host context and actual command resource use. GNU
time's maximum RSS is a maximum child observation, **not concurrent aggregate
RSS**. No capacity or throughput claim substitutes for full execution.

[`check_worldgen_build_inventory.py`](../../tools/ci/check_worldgen_build_inventory.py)
forces cold `make --dry-run --always-make -j1/-j2` inventories with a deliberately
nonexistent compiler sentinel. It executes no compiler or test, clears inherited
`MAKEFLAGS`/`MFLAGS`, and checks exact per-output sources, flags, twelve object
outputs, nine binaries and nine ordered tests. Both serial and two-job command
sets are checked against the explicit accepted source/flag contract; identical
corruption of both streams cannot pass by equivalence alone. Its raw dry-run
streams and SHA-256 identities are retained in the normal Native artifact.

The twelve checker tests include omitted prerequisite, omitted ninth test,
reordered tests, sanitizer flags removed from both streams, normal warning-policy
loss, threaded/plain output aliasing, compilation after test start, unknown
executable and invalid/unbounded target controls. A disposable actual make tree
with inherited touch flags and an empty-object canary verifies that all four
dry runs create or touch no build inputs or outputs. The candidate policy step
runs these controls alongside the existing provider and Native evidence tests.

## Local execution and unresolved failure

The local Linux x86_64 host has GCC 13.3.0, GNU Make 4.3, nine visible logical
CPUs, an eight-CPU cgroup quota and an 8 GiB cgroup memory ceiling. Native and
Makefile bytes were checked against accepted main immediately before execution.
Each variant begins with all 21 expected output files absent. Local command
receipts identify the accepted base plus explicit workflow/helper source deltas;
they are not relabeled as execution of a later committed or merged tree.

The first normal command, `timeout 5m make -j2 worldgen-test`, failed with exit
**2** after **76.734 seconds**. No test executable ran. The dependent modifiers
link reported missing `GrammarPlan` symbols, and
`build/worldgen-objects/normal/generation_grammar.o` was zero bytes. The
threaded variant was 7,520,112 bytes with the expected symbols. Make advanced
past the normal compiler command without a compiler diagnostic, implying that
make observed successful completion; its individual compiler/assembler exits
were not instrumented in that first run. The original log, empty object,
inode/timestamps, object hashes and process receipt remain preserved. The log
SHA-256 is `7281bfca35341b3e921f51da6fb7d8c3004f1081ff3f3e8b9573781b17965984`.
The reported maximum child RSS was 703,788 KiB. The cgroup reported no OOM kills;
this does not establish the unexplained empty object's cause.

The graph has unique normal/threaded output paths and a full dependency from
the failed link to the normal grammar object. Dry-run output preservation was
tested directly, including inherited touch flags; the initial cold receipt also
records no preexisting normal objects. Neither a duplicate target nor an
inventory helper mutation has been demonstrated. **The first local normal
qualification remains failed and its cause unresolved.** There is no unchanged
full normal retry to manufacture a green result.

A separately authorized single-translation-unit diagnostic compiled the same
normal grammar source/flags to a fresh disposable output under 300 seconds. A
diagnostic assembler wrapper recorded the actual assembler command, its exit
and its input assembly. GCC and assembler both returned 0 in **11.409 seconds**
overall, producing 7,520,112 bytes and the required symbols. Object SHA-256
`8080ade6c9512f10a09bb524cdb744b5988f7a0e68f6aaee8b27a1367aad2e12`
also matches the first run's threaded object. This rules out missing definitions
in the unchanged source but does not explain the failed concurrent build. The
diagnostic object is never copied into a qualification output directory.

The first cold sanitizer target separately failed with exit **2** after
**239.666 seconds**, below its 600-second limit. All nine binaries linked and
`test_world_generation_sanitized` printed PASS. The second command,
`test_world_generation_install_sanitized`, failed with `Permission denied`, and
the remaining seven commands did not run. Installation, fields and modifiers
ELF files were mode 0644; the other six sanitized executables were mode 0755.
Their bytes, permissions, inode/timestamps and hashes remain untouched. The
installation binary is 46,308,808 bytes, SHA-256
`142c64128299f962dd3d741291de588b5bfb94aecf51904d06ee5c0238abc188`.
Original log SHA-256 is
`36f80195951cc06511f2931fe7651dd7df193c331f83c53f3bfcdf7fe3ab0eec`;
maximum child RSS is 1,156,884 KiB. This is a failed local execution attempt,
not a timing, nine-test or sanitizer correctness pass. No chmod or retry repairs
these original outputs.

A disposable-file diagnostic tested one local executor hypothesis: a concurrent
read observed an empty mode-0644 file, then its writer completed content and
mode 0755 before the reader ended. The writer's later observation retained the
new bytes and permissions. This control did not reproduce stale metadata
restoration. A preceding control observed only the already-completed file and
was insufficient to test overlap; both records remain retained. Neither local
build failure has a demonstrated root cause, and neither is attributed to a
source race or the environment without evidence.

The local `/usr/bin/time` executable is absent. Local receipts therefore use
Python child resource accounting, explicitly labeled maximum child RSS rather
than aggregate concurrent memory. Hosted commands retain the existing GNU time
tooling, inside the unchanged command limits.

## Validation and integration boundary

The inventory controls pass **12/12**, the provider controls **6/6**, and the
Native evidence controls **38/38**. These are apparatus results, not native
execution passes. A separate local workflow comparison preserves all twenty
timeout-wrapped commands and finds only the two authorized worldgen differences.
Its first overbroad comparison incorrectly removed an already-existing soliding
time wrapper from one side; that failed apparatus report is preserved, and the
corrected comparison normalizes only the two explicit worldgen changes.

Documentation, current repository identity and retained M11 integrity checks
pass. Current repository identity verifies committed LFS pointer identities in
this source-only worktree; it is not materialized runtime or engine execution.
Frozen retrieval retains 32/32 top-five canonical hits. Challenge retrieval
retains 151/152, with the same existing `LCB03` miss as the exact accepted-main
documentation snapshot. The only rank change is `GEN25` from first to second;
its authoritative hierarchy text and expected facts are unchanged. These
lexical metrics do not establish runtime correctness or complete answer quality.

The executed Makefile and candidate workflow/checker identities are:

| Input | SHA-256 |
|---|---|
| Unchanged `Makefile` | `4ca9ac249ab54ef3129d920a2c6bccc6d023103f29a64a8ec32d3686aa793c4a` |
| Candidate Native workflow | `93c0736b559b269c5f16f390a38452b91713af7b6f0343a6f71741142b5dd22c` |
| Inventory checker | `d05a67387af495b3f53f4ad394ca349dbc587aa9853692c42440962f193c8e4b` |
| Final twelve-test control source | `4e6174a65dd24a86813f57cf970f7a881dec3210ba066dc5e72f51e4a1e7f2f2` |

Raw local receipts and the file-hash manifest are retained under the parent
run's `qualification-worldgen-build` evidence directory. The first normal run
used the earlier eleven-test control file, SHA-256
`427ff30e4af5d9a6e0aef57b73eeb2aecd46bc0aff6dc5533dbc9b8da134a050`;
the added dry-run mutation control changes no compiler or native input.

All original hosted and local failures remain part of the review. Exact
resulting-head Documentation/provenance, all Native families and their
aggregate, complete applicable Windows/Linux Godot gates, and independent final
source/evidence review are required before a guarded integration decision. A
green hosted build would qualify that source and runner; it must not erase the
unexplained local failure. This investigation does not alter PLAY graphical,
physical-device or human-judgment acceptance, any held/frozen PR, shader work or
the paused Scheduswarm state.

The canonical build guide links this focused record. Native ownership, ABI,
runtime inputs, scientific semantics, user controls, product roadmap and ADRs
are unchanged by this CI-only proposal; project-wide integration routing remains
owned by the parent engineering run.
