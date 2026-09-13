---
title: Validation evidence ledger
status: Current
document-kind: reference
scope: Dated source and runtime evidence with platform, artifact identity, coverage and missing gates
canonical-for: [validation-results, platform-evidence, historical-evidence-boundaries]
last-reviewed: 2026-09-12
related-documents: [../operations/testing-validation-and-replay.md, level-saves-and-replay.md, ../audits/m11/README.md]
---

# Validation evidence ledger

## What has actually passed?

**Current evidence policy:** a result applies to its recorded source/artifact,
platform, profile and fixture. A source inspection, checksum, headless run,
browser run and visual review establish different things. None silently
certifies a later binary, another platform or complete replay.

| Evidence ID/date | Executed check and outcome | Limits and record |
|---|---|---|
| E-PHYS, 2026-09-09 | Fresh Windows adapter: 49 native tests, 19 Godot runners; deterministic P1–P4 matrices, five-seed desktop async and 25 fixtures per real Web profile | [Issue #9 measured report](../audits/2026-09-09-physics-characterisation.md) separates symptoms, controls, long creep, hashes and gaps. Local diagnostic artifacts do not update published Linux/Windows runtime provenance. |
| E-PUBLISH, 2026-09-08 | Pushed source passes Linux 46-test native, ASan/UBSan and TSan runs; rebuilt Linux Godot passes 16 runners plus profiles/import/scene; both extension builds pass | [Publication reconciliation](../audits/2026-09-08-validation-reconciliation.md) records exact revisions, workflows and limits, plus separate current/M11 gates |
| E-F02, 2026-09-08 | 46 native regressions; rebuilt Windows adapter/owners and 16 Godot runners passed; paired Web exports exercised | [Issue #2 and combined record](../audits/2026-09-08-issue-2-interest-regions.md) identifies browser results, worker/profile and artifact scope; historical failures remain preserved |
| E-F01, 2026-09-08 | 42 native regressions; rebuilt Windows adapter and desktop/Web owner checks; 16 Godot runners passed | [Issue #1 dated record](../audits/2026-09-08-issue-1-failed-ticks.md); browser and combined region acceptance recorded separately |
| E-M11, 2026-08-28 | Historical audited M11: 34 passed, one inconclusive LeakSanitizer run | Linux-era audit; Windows format/import inspection was not runtime execution. [Retained records](../audits/m11/README.md) |
| E-SETUP, 2026-09-07 | 39 native tests, 11 Godot fixture runners; Chromium compatibility demo/save checks | Before threaded/Rapier Web work. `C:/kybersand/LOCAL-DEV-SETUP-REPORT.md` retains original results |
| E-RAPIER-WEB, 2026-09-08 | Windows/Chromium compatibility 1-worker and threaded 6-worker rectangle proof: 600 ticks, 308,087 contacts, 151 displaced cells; no recorded browser errors/warnings | Retained browser record lacks complete immutable source/export binding; not a fresh browser run at the current HEAD. `validation/local/rapier-web-20260908/browser-results.json` |
| E-AUDIT-TOOLS, 2026-09-08 | Six `dev.cmd doctor` version checks passed | `validation/local/20260908-201008/` |
| E-AUDIT-NATIVE, 2026-09-08 | 39/39 freshly compiled native Debug tests plus C11 header check, 21.621 s | Windows x86_64, Clang 23.1.0; one unused-capture warning at `world.cpp:1419`, no sanitizer run. `validation/local/20260908-201010/native-test.json` |
| E-AUDIT-GODOT, 2026-09-08 | Import and 15/15 fixture runners, 48.473 s fixture total | Windows Godot 4.7, retained extension DLL, not rebuilt. 240 s import/180 s per-fixture timeouts. `validation/local/20260908-201106/godot-fixtures.json` |
| E-AUDIT-EXPORT, 2026-09-08 | Existing compatibility and threaded exports each matched 18/18 manifest entries | Checksum evidence only; no new compile, HTTP or browser execution. [Audit evidence JSON](../audits/2026-09-08-documentation-audit-evidence.json) |
| E-INTEREST, 2026-09-08 | Fresh native diagnostic confirms excluded phased blocks can sleep without re-entry wake, and serial ignores region filtering | A reproduced limitation, not a pass for intended waking. [Canonical behavior](../systems/world-storage-and-interest-region.md), [diagnostic record](../audits/2026-09-08-foundation-diagnostics.md); `validation/local/20260908-rag-interest-probe/result.json` |
| E-TICK-FAIL, 2026-09-08 | Fresh source-built diagnostic confirms planning failure advances tick identity and retains an applied explosion while draining its queue | Windows x86_64, Clang 23.1.0 Debug, one worker/core capacity one; compile/run exits 0 with 60 s/10 s limits. Reproduced limitation, not transactional acceptance. [Diagnostic record](../audits/2026-09-08-foundation-diagnostics.md) |

Local `validation/...` paths above are relative to `C:/kybersand` and are retained
outside source history. The curated audit JSON preserves command and artifact
references when those local logs are unavailable.

## Which binaries and dependencies did E-AUDIT use?

- Godot: `4.7.stable.official.5b4e0cb0f`, Windows x86_64, `C:/Godot47`.
- Native CyberSand DLL SHA-256:
  `402732d3b1625eace69e2130356137f0ebef14d9113d3d8d22716d9e4ea2bb17`.
- Rapier Windows DLL SHA-256:
  `4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180`.
- Separate native/Web `godot-cpp` checkouts were clean at
  `101ae38034304346a46ea9ea84ae156d3e860496`.
- Python 3.12.14, SCons 4.10.1, Clang 23.1.0 and Emscripten 4.0.20 were observed.

The implementation bytes were subsequently checkpointed at
`126175cfc4dd1fb8659212f62b9b517bac54d8c2`; this does not retroactively prove the
retained extension was rebuilt from that source. See
[source identity](../operations/source-checkpoint-and-recovery.md).

## What do the Rapier and save passes not prove?

The three-rectangle fixture permits transient floor penetration: maximum body
centre y=160.317276, settled y=159.000656, approximately 1.32 pixels transient
penetration, within the fixture's two-pixel acceptance bound. It is not
zero-penetration, arbitrary-shape, high-count or universal
CCD coverage. Body restoration allows `1e-5` error. Exact cellular payload
restoration is not full next-tick or Rapier replay; see
[level saves](level-saves-and-replay.md).

A Windows headless runner named `test_web_rapier.gd` executes the Web scene on
Windows. Browser WASM execution requires a separately identified exported build.
Nine groups inside `test_cell_world.gd` count as one runner, not nine extra files.

## Which gates remain absent or failing?

- No macOS/WSL or Firefox/Safari runtime acceptance. All 18 required local LFS
  payloads are now materialized; rebuilt platform execution has separate evidence.
- Current Chromium compatibility/threaded acceptance is recorded by E-F02.
- Linux ASan/UBSan and TSan passed in the publication run; LeakSanitizer was
  disabled, and these do not attest to every platform or toolchain.
- No full replay persistence, generalized shapes, exhaustive boundary matrix or
  transactional tick-failure guarantee.
- The issue #1 run of the unchanged M11 checker reports 12 historical source/hash
  mismatches (the earlier audit reported seven). Those failures remain preserved;
  the [reconciliation](../audits/2026-09-08-validation-reconciliation.md) verifies
  all original hashes against M11 and separates current acceptance. Strict
  current-versus-M11 comparison still reports differences; no hashes were rewritten.
- Web CI arguments/toolchain and historical template-lock metadata conflict with
  the local builder; [build guide](../operations/local-build-and-validation.md)
  records those exact gaps.

New results belong in a new evidence record with command, timeout, date,
platform/profile, source identity, input/worker configuration, artifact hashes,
exit status and explicit limits. Historical records are never rewritten to
make a later checkpoint look validated.

## Issue #10 player checkpoint, 2026-09-09

The intermediate support commit passed 50 native tests and the shared Godot
native/fallback probe for all nine powders, landing/walking, excavation, loose
Dust, bounded enclosure and interior hard cells. This dated support result is
superseded for current acceptance by the exchange checkpoint below.

Intermediate support validation: all 20 Godot runners pass (logs
`C:/kybersand/validation/local/20260909-200717/`); docs and retained M11 checks
pass. Repository publication identity reports 14 expected source/artifact drift
errors; published runtime manifests stay unchanged. Raw checker/retrieval results
are under `C:/kybersand/validation/local/2026-09-09-issue-10/support-*`.

## Issue #10 exchange acceptance, 2026-09-09

The [dated audit](../audits/2026-09-09-issue-10-granular-policy.md) records 52 native
tests, 21 Godot runners, 1,070 native matrix runs, 257 sampled-player runs,
production desktop owner checks and real compatibility/threaded Web execution.
Version 1 selects the measured 30-fold Mercury slowdown and 8/9 downward packing.
Exact within-platform worker/repeat comparison, explicit material/reaction
accounting and retained Water regressions pass in that scope. Current published
runtime provenance, Linux/sanitizers and issue #11 barrel behavior remain separate
limits; the preserved historical manifests do not attest these new artifacts.


## Issue #13 experiment checkpoint

The [issue #13 audit](../audits/2026-09-09-issue-13-transport.md) records the four
transport checkpoints, frozen Baseline/Mercury samples, profile/control screens,
actual desktop and both native Web runs, walkthrough captures and corrected
sampling measurements. Native/Godot, real Web, visual and performance evidence
are distinct gates. The failed sustained-input ledger and initial depth query
remain recorded; publication provenance still fails independently.

## Water leveling, 2026-09-10

[The dated follow-up](../audits/2026-09-10-water-leveling.md) records 24 old/new
closed-basin cases per implementation, 55 native tests, 24 isolated Godot fixtures,
30 retained non-Water reference cases and 72 native/real-Web transport cases.
Its retained editor-import failure is an environment result; the rebuilt isolated
project passed. Faster leveling is fixture-specific, not universal instant flow.

## Programme gate reconciliation, 2026-09-11

The [reconciliation audit](../audits/2026-09-11-programme-gate-reconciliation.md)
verifies #16 result/timing source identities, retained binaries and reduction
hashes without rerunning the campaign. Its 2324 timing processes are reused
evidence, not new execution. Docs/M11 intake pass; repository validation retains
16 publication/provenance/LFS failures. No current runtime release is claimed.

Issue15 acceptance reuses its352 behavior/224 timing processes and55 unchanged-input
native regressions. All576 raw output hashes and both executable/source manifests
were verified, with no new physics execution. [Coverage and limits](../audits/2026-09-11-issue-15-coverage.md)
support G-C completion and bounded P admission;85/112 cost flags remain evidence,
not an all-green performance or migration claim.

## Issue17 fixed-carrier state precision, 2026-09-11

[Completed native Windows evidence](../audits/2026-09-11-issue-17-state-precision.md):
1328 exact behavior processes,392 timed processes,36 extended per-tick controls,
all eight same-phase concurrency configurations, and55 native tests each for
unmodified source/fixed-carrier mass8. Delay4 is Water-specific semantically exact;
G-P retains mass8 as reference. Shared-desktop cost limits and inherited provenance
failures remain explicit. No fresh Web/Linux/Godot or production migration acceptance.

## Issue #19 Water Feel Lab, 2026-09-12

The [dated completion record](../audits/2026-09-12-issue-19-water-feel-lab.md)
records 61 native passes, 29 Windows Godot runners, actual OpenGL Water coverage/
orientation pixels and real Chrome compatibility/threaded probes. Each browser
profile built from the recorded source passed 70 scenario cases, 110 actions,
invalid-policy preservation and presentation-authority preservation with matching
catalogue/default hashes. A stale compatibility WASM failure is retained separately
and was resolved by rebuilding, not by suppressing the case.

This evidence establishes a technically safe, reproducible H-ready apparatus.
It is not a human preference study, a production precision/packing selection,
#18 admission, #20 admission, representative GPU performance result or G-final.
