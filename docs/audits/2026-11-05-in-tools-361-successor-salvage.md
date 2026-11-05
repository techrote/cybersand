---
title: IN-TOOLS 361 current-main succession salvage audit
status: Current
document-kind: audit
scope: Read-only classification of PR 379 artifacts before current-main successor admission; no PR 379 source modification and no PR 383 integration
last-reviewed: 2026-11-05
---

# IN-TOOLS #361 current-main succession salvage audit

## Source custody

- Historical predecessor: PR #379, frozen head `e7e404b696fb9fc48cdadc95a69baf3a6f5fc6d1`, tree `3b5acd41fd7fb49ac8b06c94719fa1a700d8fd57`.
- Historical tested main: `751edc0b495dc85484ad5509a7c95f863651c76b`.
- Adopted successor base: live `main` `ba9cbc89029be88b812af59b19e5c59829bbcd90`, merged as #394 at 2026-11-05 02:00:57 UTC.
- PR #379 remains open, unmerged and source-frozen. Its 86/0 assertion footer followed by process exit `3221225477 / 0xC0000005` in run 41920193030 remains a genuine historical blocker of that exact source.
- PR #383 is not modified by this programme.

Classification meanings: **A** carry forward; **B** rewrite against current main; **C** historical only; **D** obsolete/superseded.

## Complete PR #379 salvage classification

| PR #379 path / artifact | #379 role | Class | Rationale / current-main authority | Copy bytes? | Rewrite / new test? |
|---|---|---:|---|---|---|
| `.github/workflows/documentation.yml` | Added #379 source-admission checks | B | Hard-wired to the old admission model; successor uses an isolated checker before deciding whether shared CI should change. | No | Rewrite only if shared CI promotion is later justified. |
| `.github/workflows/play-windows-crash-capture.yml` | Exact #379 Windows diagnostic | B | Valuable structure, but branch/head/campaign identities are #379-specific. | No | New successor Windows gate required. |
| `docs/README.md` | Routed #379 docs | B | Current documentation topology has advanced through #394. | No | Add successor routing only if needed after review. |
| `docs/architecture/in-tools-gameplay-admission.md` | Planned #361 command/quantity/ownership contract | B | Requirements remain useful; inspected source and ownership topology are stale. | No | Re-author against current U10/World/worker/workbench authority. |
| `docs/architecture/inertial-cellular-v1.md` | Link to planned #361 successor | B | Current IN text has advanced; only the requirement link is reusable. | No | Reconcile only after successor acceptance. |
| `docs/audits/2026-11-04-in-tools-379-current-main-readmission.md` | Old 25-lock re-admission | C | Immutable evidence tied to `751edc0b…`; not current authority. | Historical only | No. |
| `docs/audits/2026-11-04-in-tools-379-independent-review.md` | Independent review/evidence corrections | C | Review conclusions are source-qualified historical evidence. | Historical only | Reuse requirements, not result claims. |
| `docs/audits/2026-11-04-in-tools-admission.md` | Original source/implementation admission | C | Inspected source predates current workbench/native transitions. | Historical only | Requirements may inform successor design. |
| `docs/audits/2026-11-04-pr379-windows-exit-investigation.md` | Shutdown failure dossier | C | Must retain original failure identity and causal uncertainty. | Historical only | New run gets a distinct record. |
| `docs/audits/in-tools-361-2026-11-04/local-checks.json` | Original local results | C | Results qualify old bytes only. | Historical only | Fresh successor checks required. |
| `docs/audits/in-tools-361-2026-11-04/native-qualification.json` | Original native primitive evidence | C | Exact compiler/executable/source packet is historical. | Historical only | Fresh native execution if broad qualification proceeds. |
| `docs/audits/in-tools-379-review-2026-11-04/companion-inputs.json` | Evidence packet input hashes | C | Packet identity is immutable historical evidence. | Historical only | No. |
| `docs/audits/in-tools-379-review-2026-11-04/evidence-tool-corrections.json` | Independent evidence-tool corrections | C | Findings remain useful, but recorded outputs are historical. | Historical only | Carry requirements into successor tests. |
| `docs/audits/in-tools-379-review-2026-11-04/independent-review.json` | Independent decision | C | Decision applies only to its exact reviewed source. | Historical only | New independent review required. |
| `docs/audits/in-tools-379-review-2026-11-04/intake.json` | Intake/source custody | C | Exact live metadata from 2026-11-04. | Historical only | Fresh intake is this audit/programme. |
| `docs/audits/in-tools-379-review-2026-11-04/native-qualification-v2.json` | Corrected native packet | C | Exact old-source result. | Historical only | Fresh native result required if used. |
| `docs/audits/in-tools-379-review-2026-11-04/original-native-reproduction.json` | Reproduction record | C | Historical source/executable only. | Historical only | No. |
| `docs/audits/in-tools-379-review-2026-11-04/original-validation.json` | Original validation inventory | C | Historical qualification inventory. | Historical only | No. |
| `docs/audits/in-tools-379-review-2026-11-04/retrieval-review.json` | Retrieval result comparison | C | Corpus/ranks changed after #379. | Historical only | Fresh retrieval only if successor corpus changes. |
| `docs/operations/cybersand-codex-development-handover.md` | Handover/status note | B | Main has newer handover state. | No | Current-main successor note only. |
| `docs/operations/in-tools-fixtures-and-playtest.md` | Six planned fixture concepts/runbook | B | Fixture concepts remain useful; host/workbench mechanics changed. | No | Re-register successor plans as Planned/NOT_RUN. |
| `docs/operations/local-build-and-validation.md` | Added #379 validation route | B | Current runner/runtime publication evolved. | No | Use current hosted Windows harness. |
| `docs/reference/retrieval-corpus.json` | Added #361 retrieval content | B | Global corpus changed after #379. | No | Touch only if successor docs require it; rerun retrieval. |
| `docs/reference/retrieval-in-tools-361.json` | #361 query cohort | A | Questions express useful requirements independent of old source results. | Yes, as query intent only | Any result/rank must be regenerated. |
| `docs/reference/retrieval-index.md` | Routed query cohort | B | Current index changed. | No | Reconcile if query cohort is republished. |
| `docs/reference/status-and-roadmap.md` | #361 status | B | Current status/workbench changed. | No | Update after successor decision, not before evidence. |
| `docs/reference/validation-evidence.md` | #379 evidence references | C | Existing links/results are historical. | Historical only | New successor evidence gets separate entries. |
| `docs/systems/actor-usables.md` | Current U10 behavior documentation | B | Main's current U10 remains authority, but #379 edits are stale. | No | Successor references current-main document/source. |
| `godot/tests/fixtures/lcb/in_tools/in-tools-admission.v1.json` | Six-plan registration and old source locks | B | Six concepts survive; old source map/status bytes do not. | No | New successor registration, Planned/NOT_RUN. |
| `godot/tests/fixtures/lcb/in_tools/in-tools-source-admission.2026-11-04.json` | #390-era 25-input transition | D | Purpose is superseded by current-main successor authority. Retain only in #379 history. | No | Replace with minimal current-main authority record. |
| `native/tests/test_in_tools_361_contract.cpp` | Native primitive/conservation probes | A | Test concepts and independent census are useful; exact old executable results are not. | Selectively | Re-run/reconcile before claiming successor qualification. |
| `tools/lcb/in_tools_contract.py` | Proposal/refusal/fixture validation | A | Fail-closed contract concepts remain useful. | Selectively | Rewrite source assumptions and current host ownership. |
| `tools/lcb/in_tools_source_admission.py` | Old 25-lock transition checker | D | Encodes the superseded #390 transition and accepted tree. | No | New minimal checker. |
| `tools/lcb/run_in_tools_native.py` | Native probe runner/evidence custody | A | Custody and independent accounting approach remain useful. | Selectively | Rebind to current source before broad qualification. |
| `tools/lcb/test_in_tools_contract.py` | Proposal/refusal adversaries | A | Negative-control ideas remain valid. | Selectively | Reconcile with successor contract. |
| `tools/lcb/test_in_tools_native_runner.py` | Runner/evidence adversaries | A | Stale-binary/census/adversarial ideas remain valid. | Selectively | Reconcile before re-use. |
| `tools/lcb/test_in_tools_source_admission.py` | Old transition-checker adversaries | D | Tests a checker that is intentionally retired. | No | New successor checker tests. |
| `tools/play/run_windows_crash_capture.py` | One-attempt actual-Windows crash campaign | A | Campaign discipline, source/runtime custody and natural-exit distinction remain useful. | Selectively | Rebind to successor; initial gate uses current runner and preserves nonzero exit. |
| `tools/play/test_windows_build_process.py` | Process ownership/deadline adversaries | A | Generic Windows process evidence tests. | Yes if full capture is needed | Re-run under successor capture campaign. |
| `tools/play/test_windows_crash_contract.py` | Crash evidence reader/adversaries | A | Generic fail-closed crash record tests. | Yes if full capture is needed | Re-run under successor capture campaign. |
| `tools/play/windows_build_process.py` | Windows Job/process exit observation | A | Generic actual-Windows process ownership. | Yes if full capture is needed | No semantic production dependency. |
| `tools/play/windows_crash_contract.py` | Fail-closed minidump/event reader | A | Generic evidence contract. | Yes if full capture is needed | Rebind campaign identity only. |
| `tools/play/windows_crash_control.c` | Known-crash/child-crash control | A | Generic adverse control. | Yes if full capture is needed | Compile/run with successor campaign. |
| `tools/play/windows_crash_debugger.cpp` | Bounded Windows debugger/minidump helper | A | Generic capture implementation. | Yes if full capture is needed | Compile/run with successor campaign. |
| `tools/play/windows_crash_policy.py` | #379 watchdog policy | B | Limits/campaign labels are source-specific. | No | Successor gate uses current execution-policy watchdogs. |

## Result

The successor does **not** inherit #379's 25-lock map. The minimal current production authority required to describe the first #361 slice is the U10 catalogue/runtime/physical-usable path, the physical equipment request and exclusive physical-usable execution owners, physical-session and simulation-worker owners, native adapter, World quantity/edit authority, Water normalization, and IN implementation. Thirteen exact production inputs are therefore registered by the successor record.

The six historical fixture ideas remain design inputs only. Until a successor host command is actually implemented and executed they remain **Planned / NOT_RUN**. Current U10 behavior is Current only because it exists on the adopted main, not because #379 said so.
