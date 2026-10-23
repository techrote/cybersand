---
title: MAT-003 exact 5380c76 build-only attempt and binary-admission disposition
status: Current
document-kind: audit
scope: Native Windows toolchain preflight and incomplete build-only checkpoint; no candidate cases, correctness qualification or timing
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [2026-10-23-mat003-apparatus-source-closure.md, ../research/mat003-correctness-only-plan.md, ../research/mat003-continuation.md]
---

# Authorized source and stop boundary

Owner authorized toolchain/platform preflight, build-only qualification at `5380c763c2a745169d1dd488fce4d5645fe46502`, then independent binary admission, with an explicit stop before qualification cases or timing. The tested Git tree is `d6373964eda71a7379dc97fe71d3a4acd3c4b21c`. The source remains frozen throughout preflight and the single apparatus build attempt. The [earlier source review](2026-10-23-mat003-apparatus-source-closure.md) did not establish compilation or platform success; this is the first actual build gate for that source.

Native Windows is available; WSL is not installed and no Linux runner was dispatched. This record cannot establish Linux GCC13.3/binutils2.42 build results. No existing campaign or accepted observation is rerun. Production/Water/GEN-006, accepted experiment sources and evidence, reviewed plan/maps and both PR heads/stacks are preserved except subsequent documentation publication on PR221. R16-T1 remains conditional. PR211/221 remain draft.

## Toolchain/platform preflight

The official native Windows [LLVM-MinGW20260826 UCRT x86-64 ZIP](https://github.com/mstorsjo/llvm-mingw/releases/download/20260826/llvm-mingw-20260826-ucrt-x86_64.zip) is190,721,391bytes, SHA-256 `ae601f4e0f72bbdf441ad2df8bb16f037e2e9251559ea6b37b4057aef39c06c3`, matching retained release metadata. It supplies Clang23.1.0, LLD23.1.0 and target `x86_64-w64-windows-gnu`. This is a distinct official artifact from the Linux-hosted Windows cross-compiler archive in the repository lock; no lock was changed. License/component notices remain inside the retained archive.

Python is3.12.10, native Windows AMD64; exact OS/release/version/executable hashes are in the build authority. A new isolated venv uses psutil7.0.0. The native wheel SHA-256 `4cf3d4eb1aa9b348dec30105c55cd9b7d4629285735a102beb4441e38db90553` matches retained [PyPI7.0.0 metadata](https://pypi.org/pypi/psutil/7.0.0/json). No global dependency or repository pin is changed. Exact compiler/linker, all9,069 distribution inputs,29 monitored package files, driver resolution, dependency files, environment overrides and runtime imports are sealed.

Normal flags are `-std=c++20 -O2 -DNDEBUG -Wall -Wextra -Wpedantic -pthread`; sanitized flags are `-std=c++20 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -Wall -Wextra -Wpedantic -pthread`. Windows linker binding is the absolute `--ld-path=.../ld.lld.exe`; `-lpsapi` is explicit. Compiler/include/library overrides were cleared and the toolchain bin directory was prepended to PATH. Windows ASan uses `detect_leaks=0:halt_on_error=1`; UBSan uses `halt_on_error=1:print_stacktrace=1`. No LSan qualification follows.

The first external probe failed before any apparatus compilation: its extra `-Wl,--trace` linker instrumentation was unsupported. Exit1, no watchdog stop and complete argv/stdout/stderr/receipt are retained. This flag is absent from frozen apparatus commands. Independent review approved a separately sealed v2 preflight, removing only that extra trace flag and retaining v1. Four new tiny compilations plus the first failed probe give five cumulative preflight compilations, separately counted from the unchanged32 apparatus limit. This is a disclosed apparatus-preparation correction, not a retried qualification observation or a changed accepted registration.

V2 compiled four tiny tool probes without diagnostics. Normal and combined-ASan/UBSan benign probes exited0 with native peak-RSS receipts; intentional heap overflow and signed overflow probes emitted the expected ASan/UBSan diagnostics and exited1. The ASan-specific failing function disables undefined instrumentation only to isolate ASan activation. Timeout/descendant cleanup and suspended-process assignment/resume/Job-close passed. Supplemental read-only PE inspection confirmed AMD64 and ASan/libc++/libunwind/UCRT imports. These are external toolchain fixtures, not MAT-003 qualification cases.

Independent reviewer `/root/independent_review` checked all59 retained preflight files, all9,069 toolchain files against the official ZIP,29 monitor files against the wheel, commands/binaries/dependencies/diagnostics and absence of candidate execution. It accepted this exact Windows preflight for build preparation only. The sealed pending proof is preserved; a separate derived qualified proof binds the disposition and raw seals.

| Preflight evidence | SHA-256 |
|---|---|
| Accepted v2 script | `f4f6a78a8fef7eb50a8458c66eab5c14e1159674e632bea451ebec8a0b9295d8` |
| V2 report | `c03bb8c6d7c09365a44094a14dc335cb4ec18dac06a95783a8cda4f3f0aa8eb6` |
| Pending proof | `f06e092db1306bbaf15c0fa962c217df5fe7d70819e87402e6a7d3d7317e5fa5` |
| V2 inventory | `44c2aeafb44aebb5c46a6be60b929143e1e892f6ac9df7532e4c468b2836eed0` |
| Compiler executable | `bf58cf0e544a308660645aad1fe65ae9cbc44b0871e4010278f3d9551f86a690` |
| Linker executable | `284daba5d41833c41d164d3b8b4715a41a11f0c8fd22c19eabc0929cbf081db8` |

The fast normal tool probe's sampled RSS peak was0, while the native peak was13,504,512bytes; sanitized native peak was18,001,920bytes. Sampled RSS is not the OS peak receipt. Job assignment/resume/termination was exercised, but its commit-memory ceiling was not stress-tested. No maximum-residency, leak-detection, latency, app-memory or World correctness claim follows.

## Frozen build-only attempt

External build authority SHA-256 is `27f3db6b53f5a7ff34030e0bcae32c6def8e1e254ff8de8604fdc220b036b690`. It binds the source commit/tree/input hashes, platform, reviewed preflight proof, compiler/linker/monitor, flags and environment. `owner_build_authorized=true`; `owner_execution_authorized=false`; independent binary admission is not yet granted. No execution authority is created.

Invocation uses the unchanged `collect.build(authority, output, exact_authority_sha256)` stage, under the frozen collector's180s/3GiB compiler guards and aggregate/output ceilings. Actual argv/working directory, diagnostics, watchdog/resource observations and binary seals are retained. Source and generated files were sealed before compilation. No candidate binary was invoked.

The first K64-E8 normal storage compilation exited0 with empty stderr and was recorded as one clean build. The next K64-E8 normal World compilation also exited0 and produced an executable, but wrote1,667bytes of diagnostics. The collector rejects any nonempty stderr, so it stopped immediately with `status=incomplete` and `retained failed invocation: builds/K64-E8-0-world`:

- Generated unchanged Current World line2731: unused lambda capture `this` (`-Wunused-lambda-capture`).
- Isolated `world.cpp` line15: copied `const std::string role` loop variable (`-Wrange-loop-construct`), with a compiler note suggesting a reference.

These are compiler warnings, not a failed compiler exit or a sanitizer finding. They are nevertheless a failed apparatus build under the frozen diagnostic contract. There were exactly two compiler attempts, one clean recorded build, two retained physical executables and one generated arm. The32-binary/eight-arm build matrix is incomplete. The extra executable is retained evidence, not an admitted candidate. No flag was suppressed, source corrected, failed invocation retried or remaining matrix subset launched.

| Failed checkpoint evidence | SHA-256 |
|---|---|
| `built.json` | `38d46be6ddcaf8d82ee1a33f8df5f1acf4c2065b62af91070adba694ef3b6d5d` |
| `build-inventory.json` | `1935bbac95e5f126f3ad89236a7cce7cf27ecf556b798e46a9d5fb70234653c9` |
| Retained storage executable | `efe1d6a743957d1225e9ef7c96fc2428415b5d9aff668e62c16c98ee31d60e03` |
| Retained World executable | `a95d6d1c58a0e6539dad6c1201080b4c581f5b8edb47c571b9d75c7b52bd9932` |
| World diagnostic stream | `56613ecffb9e96d6762e38334510cd9361c1ad9c51287e2e925c944195b83a44` |

## Independent admission and next gate

**Independent binary admission: refused.** Reviewer `/root/independent_review` verified all198 retained files,93 source files against the exact Git commit/tree,61 generated files against the precompile seal and generated manifest, both complete compiler commands, tool/monitor/authority identities and the complete partial-build inventory. It confirmed two attempts, one clean registered build, two physical executables, one generated arm and correct enforcement of the diagnostic gate. Neither physical executable is admitted. The refusal is bound to the exact `built.json`, inventory, authority and binary hashes in the [compact build/admission summary](mat003-correctness-2026-10-23/build-only-summary.json).

There is no `cases/` directory or `execution-attempt.json`, and neither retained executable was run. No execution authority or admitted-binary receipt was created. Any subsequent source or diagnostic-policy correction requires a separately authorized, independently reviewed new source/contract checkpoint and a new bounded build attempt; it cannot change this failed record, suppress diagnostics retroactively or silently complete the same attempt. Production and accepted baseline sources must remain unchanged, including if a future generated-copy patch removes the unused capture. This is a native Windows compiler/build finding, not evidence of universal Linux failure or runtime cell incorrectness. Earlier frozen README/source-review build-pending statements are historical preparation state, superseded for this actual attempt by this dated audit.

## Retention and maintenance

Complete raw preflight attempts, official archive/wheel/provenance, source snapshot, generated sources, both physical binaries, command streams/resource receipts and immutable inventories are preserved outside Git. The durable archive is `C:/Users/_/mat003-evidence-20261023/windows-5380c76-build-evidence.zip`,192,264,155bytes,297 entries, SHA-256 `feae39f75842c428b2997c76cbb08ea0910340b590cdadefc7733a5590b36db9`. It includes the full original official compiler archive with license/runtime contents and all raw failed/successful preflight evidence; the9069-file distribution can be reconstructed without relying on its temporary extraction directory. The outer retention-inventory SHA-256 is `5468c68d9c62980f98758576f5112b0da0f02fdcfe1e7e5ddf1ae37f1f64bf43`. The unmodified build checkpoint remains at `C:/Users/_/mat003-evidence-20261023/windows-build-5380c76`; preflight originals remain under `C:/Users/_/.codex/tmp/mat003-build-5380c76-20261023` as an additional working copy. Raw build output and logs are not committed.

This checkpoint publishes only documentation and compact evidence identities. Canonical routes update the continuation report, roadmap, documentation/retrieval indexes and a supplementary retrieval question. No apparatus implementation, production ownership/interfaces/invariants/configuration, dependency pins, workflows or user controls change. Maintenance checks and archive readback are recorded below before publication. Publication uses `[skip ci]`; no workflow is added/dispatched and no qualification case or timing executes.

Independent retention readback confirmed the complete297-entry ZIP, clean CRCs, all296 payload hashes/lengths, all three nested inventories and byte identity to the original198 build files,22 failed-v1 files and59 v2 files. It also checked both PE reports, wheel and14 control files including the official compiler archive and refusal. It confirmed the audit/summary accurately scope native Windows refusal, Linux unexecuted and zero candidate cases/timing. This is a separate retention pass, not a changed binary-admission decision.

`python tools/ci/check_docs.py`, `python tools/ci/check_repository.py`, `python tools/ci/check_m11_consistency.py` and `git diff --check` passed. M11 checked18 retained records/28 source hashes. `python tools/docs/retrieval_eval.py --output build/mat003-continuation/build-only-retrieval.json` retains frozen32 results21 rank1/32 top5/MRR0.7937. The supplementary invocation with `--queries docs/reference/retrieval-challenges.json` yields101/127 rank1,126/127 top5, MRR0.8769; new MATSCHEMA08 ranks1 and retains the diagnostic/refusal/no-execution qualifiers. MATSCHEMA07 expected status now distinguishes its historical no-build checkpoint from this later failed build; prior125 objects and all prior query wording/frozen32 remain unchanged. C09 remains the disclosed lexical miss. These are development-set lexical results, not runtime correctness or unseen retrieval validation. The [maintenance summary](mat003-correctness-2026-10-23/build-only-maintenance-summary.json) seals the full local reports; no candidate test is hidden in these checks.
