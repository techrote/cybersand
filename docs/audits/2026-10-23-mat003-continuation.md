---
title: MAT-003 continuation qualification checkpoint
status: Current
document-kind: audit
scope: Dated source identities, untimed apparatus evidence and explicit unadmitted performance boundary for S2P, WCLEAR-001 and C128-001
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [../research/mat003-continuation.md, ../operations/mat-003prepass-registration.md, ../operations/current-and-historical-validation.md]
---

# MAT-003 continuation qualification checkpoint

## Inputs and recoverable checkpoints

Intake root `C:/khybersand`, HEAD `620826f59fbe248f93a45c45e786a7297f2e5288`,
branch `mat/material-fidelity-pass-2`, has unrelated native World/rules/tests,
runtime DLL and untracked Godot UID/benchmark work. None was changed. Historical
handover paths name `C:/kybersand/source`; actual Git root takes precedence.
Remote is `https://github.com/techrote/cybersand.git`; no tag points at intake.
Dependency pins remain GCC13.3/binutils2.42, Godot4.7, godot-cpp101ae380,
SCons4.10.1 and LLVM-MinGW20260826. Experimental native tests do not load LFS
Godot runtimes. The isolated worktree leaves its LFS pointers unmaterialized;
this is not Godot runtime acceptance.

Continuation root is
`C:/Users/_/.codex/worktrees/mat003-continuation/khybersand`, branch
`codex/mat003-continuation`, created at accepted S2A head
`2b2a1dd64f16dc46d5e812b757de73f47df0fb2b`.
Preregistration commit `61a935f` precedes implementation `36c9f8c`.
Independent source review prompted stricter verifier inventories, Git-anchored
source checks and pre-compile generated-source seals in `07c87a0`.
All are recoverable Git checkpoints published in draft
[PR221](https://github.com/techrote/cybersand/pull/221). Production native,
accepted experimental files and PR211 are unchanged.

## Retained local diagnostics and failures

Local toolchain is MSYS2 GCC16.2.0 on Windows x86-64, explicitly outside the
registered Linux GCC13.3 platform. No WSL installation exists. The independent
storage model passes; observed size/alignment is 16/16 for native U128 and 16/8
for DUAL64. Six Python evidence-contract tests and the CI provider policy check
pass. These are untimed diagnostics, not admitted performance or full platform
qualification. Build receipts remain in the ignored continuation build directory.

The first local S2P collector attempt `local-s2p-01` stopped after the compiler
emitted `.exe` while the collector tried an extensionless path. Its output and
failure are retained; subsequent source explicitly handles Windows suffixes.
Local WCLEAR diagnostic `local-wclear-01` collected208 untimed cases without
fixture failure, with `qualified_toolchain=false`. Its source contained local
deltas and is not a Git-clean admitted source or independently accepted result.
It is retained as development evidence, without timings or speed claims.

Initial local documentation/repository checks reported five missing companion
workspace files (six question references). Those exact fixtures were materialized
outside the source checkout from pinned companion commit
`6a58311982941b75f46e22109a0829e5acb83c7e`, preserving existing files. Documentation
then passed. This repairs local check topology, not source provenance or runtime
acceptance. Hosted documentation uses the pinned companion checkout directly.
Historical M11 integrity passed:18 records and 28 source hashes, no historical
hash rewrites. Final current checks are recorded separately below.

## Independent source review and held admission

The independent reviewer identified and the implementation addressed: an
overbroad WideCell tail-capacity API; missing E24/E32 byte-map tests; inaccurate
label-swap wording; expected rather than observed clear counts; lack of feasible
natural E16 comparison; event worker attribution; full-high64 World preservation;
incomplete build/command inventories; metadata not bound to context IDs; source
seals lacking a reviewed Git anchor; and generated-source seal ordering.
Review is independent source inspection, not execution authority or timing admission.
The completed collector/verifier and hosted artifacts still require exact source
readback and independent disposition. No reviewer has admitted formal timing.

The first hosted untimed run is
[39881371873](https://github.com/techrote/cybersand/actions/runs/39881371873)
at branch source36c9f8c. Its results must retain the above verifier qualifications
even if the workflow exits successfully. A subsequent run uses corrected source;
all attempts and raw artifacts are retained. No partial matrix is accepted as
completed qualification and no clear-cost samples are collected.

## Retained hosted failures and source review closure

| Run / branch input | Retained artifact and SHA-256 | Disposition |
|---|---|---|
| [39881371873](https://github.com/techrote/cybersand/actions/runs/39881371873),36c9f8c | [12470773556](https://github.com/techrote/cybersand/actions/runs/39881371873/artifacts/12470773556), `48124a7d1bbc3ebe1260794af80f1ae02cac382cc94971636a0363239f1c078f` | Complete 208 WCLEAR collection rejected at first pre-record: zero/default stats referred to a different tick. S2P assembly is diagnostic; no timing/whole-attempt acceptance. |
| [39881795109](https://github.com/techrote/cybersand/actions/runs/39881795109),07c87a0 | GitHub cancellation log; API returned no raw artifact | Manually superseded while correcting the known pre-record defect. Partial raw collector output is unavailable; it is not reconstructed or accepted. |
| [39882646067](https://github.com/techrote/cybersand/actions/runs/39882646067),1fec40c | [12471606431](https://github.com/techrote/cybersand/actions/runs/39882646067/artifacts/12471606431), `5ccd46514bf552d2ec9e24ee05982e2bc45d46a7665c106d60ec12327dbbde40` | WCLEAR208 and four C128 fixture executions completed. C128 recursive readback rejected an unsealed bytecode cache introduced by the S2P reader itself. Whole attempt remains failed. |
| [39883050638](https://github.com/techrote/cybersand/actions/runs/39883050638),86a8ddc | [12471563260](https://github.com/techrote/cybersand/actions/runs/39883050638/artifacts/12471563260), `9e25399cac0903a0ab365f2821941f3f29fd7a04718bee029ed8559dc3565bdb` | Same recursive-reader mutation defect; all raw observations retained. C128 cross-lane assembly is diagnostic, not accepted performance. |

Intermediate queued workflows replaced by the concurrency policy never executed
fixtures; their cancelled states remain in GitHub. The read-only bytecode guard
in 33db7ff fixes the observed mutation. Latest source also binds candidate IDs to
width/representation/ABI, checks exact compiler flags/macros and source identities,
seals storage binaries before execution and emits actual before/after epoch
transitions. No missing raw observation is reconstructed and no partial matrix
is accepted. All new execution so far is untimed.

Independent source review through c7d7bf6 confirmed the previously identified
source-level blockers resolved and supported completion of untimed qualification.
It explicitly granted neither artifact qualification nor timing admission.
The final readback cache first requires complete raw-byte equality before reusing
a decoded control; independent review confirmed this retains every file/byte and
per-arm contract check. Raw before/after epochs now derive actual clear counts.
Scientific limits remain the frozen preparation/cache condition, prepared wide
rather than naturally reached raw epoch history, observer-twin qualification of
background participation and descriptive seven-event tail summaries. The active
[v3 registration](../../tools/experiments/mat003_continuation/wclear-registration-v3.json)
and gated timing source must still receive exact-artifact independent disposition.

## Documentation obligation mapping

The [continuation report](../research/mat003-continuation.md) owns the new
experimental decisions and routes from storage, epoch, handoff, programme,
roadmap and documentation index. The explicit corpus and new supplementary
retrieval questions route there; existing frozen questions and accepted
statistical definitions remain unchanged. Production interfaces, ownership,
capacity defaults, ADR decisions, user controls and runtime provenance need no
implementation update because only generated experimental copies changed.
Build/test entry points are the new untimed workflow and collector. No native
pool/Godot or persistence ownership changes occurred.

## Exact next manual action

After complete untimed artifact readback, an independent reviewer must pin the
qualified source, compiler/linker, registrations, fixtures, all binaries,
observer/off equivalence, verifier and immutable artifact hashes. They must
explicitly admit a reviewed WCLEAR timing registration and establish execution
authority. Only then may a separate manual-only timing workflow be committed
and dispatched at that exact admitted ref. At this checkpoint there is no valid
formal dispatch command: the timing workflow and admission do not exist.

The existing `MAT-003 continuation untimed qualification` workflow can be rerun
manually at the published reviewed branch for apparatus qualification only.
The exact CLI is `gh workflow run mat003-continuation.yml --repo techrote/cybersand
--ref codex/mat003-continuation`. It never executes a timing campaign.

## Current structural and retrieval checks

`python tools/ci/check_docs.py`, `check_repository.py`, historical
`check_m11_consistency.py`, the CI provider-policy checker, ten continuation
contract tests and `git diff --check` pass locally with the pinned companion
retrieval fixtures present. Frozen retrieval remains 21/32 at 1 and 32/32 at 5,
MRR 0.7937. Supplementary retrieval is 96/119 at 1 and 119/119 at 5, MRR 0.8847;
all three new questions route at rank 1. Frozen 32 and previous supplementary
question objects remain unchanged. Manual new-question review confirms the
required status, no-performance-admission, source/platform and schema limits.
These lexical metrics do not establish answer correctness or runtime acceptance.
The final hosted documentation result and exact-current artifact disposition
are recorded below when available.
