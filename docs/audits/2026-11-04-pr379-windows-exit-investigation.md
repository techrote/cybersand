---
title: PR379 current-source Windows exit investigation
status: Current
document-kind: audit
scope: Bounded exception-capture admission for the unchanged b30 Windows failure; no production repair, runtime substitution, passing qualification or merge approval
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-in-tools-379-current-main-readmission.md, 2026-10-25-lcb003-desktop-native-default-host.md, ../operations/ci-execution-and-performance.md, ../reference/validation-evidence.md]
---

# PR379 current-source Windows exit investigation

## Owner boundary and retained failure

The owner authorized a separately bounded investigation and repair of the
Windows process failure, followed by resulting-head qualification and independent
review, or retention of the hold. This is not merge approval. The
[continuation record](https://github.com/techrote/cybersand/pull/379#issuecomment-6642793909)
retains one source writer on the existing #379 branch. #383/#370, their evidence
branches and other owners' checkouts remain separate and unwritten.

The [original hold](https://github.com/techrote/cybersand/pull/379#issuecomment-6642233489)
binds PR head `b30ae3cc496534fdad5e13f36ef049c4a00024ac`, tree
`51133e19ecab5154ee4c3435731a9f5537dd69de`, main
`751edc0b495dc85484ad5509a7c95f863651c76b`, and actual GitHub test merge
`d3404bad28013f3eb2dbd49382781276279e34c5` with the same complete tree.
[Windows job126850142112](https://github.com/techrote/cybersand/actions/runs/41908547425/job/126850142112)
executed `test_liquid_desktop_default_host`: all86 assertions passed, followed by
process exit3221225477 (`0xC0000005`) in13.581seconds. The required Windows
coverage gate correctly failed. The original artifact13361273122 has SHA256
`a4b74d2e563a0ce959951b7cb3ea87bbb9756e87290b5cd40203291272133266`;
its failed log SHA256 is
`c0467d784cb64bcf26fc643e1e1b54d6751ab691a9e3e261645d950c3605fddc`.
An assertion footer is not a successful process exit. No transient infrastructure
cause or current-source crash stack was retained.

## Source findings and historical evidence

The [25 October audit](2026-10-25-lcb003-desktop-native-default-host.md#preserved-shutdown-failures-and-test-resource-ownership)
already preserves this footer/exit combination, failed finalizer-delay and partial
helper-extraction attempts, and a bounded later acceptance of five externalized
test helpers. Those results are historical and do not clear the new failure.
The successful current path explicitly joins the simulation worker before freeing
its desktop, and Main's exit path joins again. No source defect has yet been
established that justifies a production change or another timing workaround.

Independent read-only inspection located an existing exception apparatus in
[#329](https://github.com/techrote/cybersand/pull/329), pinned source
`d53ae1204ebb992d8ebfe265b6ea1ed211dc3f21`. Its
[historical forensic record](https://github.com/techrote/cybersand/blob/d53ae1204ebb992d8ebfe265b6ea1ed211dc3f21/docs/audits/2026-10-31-play-windows-crash-forensics.json)
describes the same fixture at older source319d507a and an older native DLL:
run41247373741, artifact13060835779, SHA256
`e153c6c74920926cebdc8b11f0310e3d71303ebcb5dc1d333a8a66ae9dc7ac0e`.
Three exception captures and exact-image unwind metadata point to engine script
finalization, fault RVA `0x3e1e7c1`, and freed-pattern values. Function names are
source-correlated inferences, not symbolized proof. Missing heap/allocation history
and the different native DLL prevent treating this as the current cause.

## Explicit diagnostic-source admission

The eight `tools/play/*windows_crash*` / `*windows_build*` source and test files
are derived from that exact #329 source; no #329 branch history or old runtime
result is adopted as current qualification. The C++ broker/control, dump parser,
owned-build implementation and their ownership predicates remain unchanged.
The successor runner explicitly binds b30 as its immutable protected baseline,
original run41908547425 and actual checkout/tree above, and uses the distinct
`pr379-windows-exit-campaign-v1` receipt schema. Old campaign schemas are refused.

The protected equality fence still covers all `godot`, `native`, `third_party`,
`tools/ci` and the ordinary GDExtension workflow. A baseline reproduction cannot
silently change production, the failing fixture, runtime pins or existing gates.
The original six #361 plans, 25-lock map, successor worker admission, nine #370
pins, native oracle, historical evidence and all18 LFS identities remain intact.

The diagnostic captures the actual current committed source and scoped Git blobs
in a self-contained source pack, authenticates canonical and working bytes, and
checks them again after execution. It validates the retained Windows native DLL's
complete source inventory and exact materialized native/Rapier/engine bytes.
Actual debug-event process images and loaded modules must match those identities.
Credential-bearing environment entries are removed from child processes; the
exact effective environment is hashed without publishing unrelated values.

## Prescribed execution and refusal rules

The branch-scoped GitHub-hosted Windows job runs fresh portable adverse tests,
five real build-ownership controls and six real debugger controls. It builds the
unchanged debugger/control sources using the existing pinned clang-cl/lld-link
20.1.8 executable hashes, preserving full descendant accounting and empty-job joins.
There is no compiler fallback, process-name exemption or global process kill.

The versioned successor watchdog matches the current registered fixture's complete
3940-second allowance; operation/import allowances remain300/1200seconds and
cleanup10seconds. The broker is freshly compiled with that complete maximum.
The180-minute diagnostic stage and45-minute dependency preparation fit inside the
270-minute parent with setup/readback/upload headroom. Adverse hung controls keep
their deliberately short, separately identified deadlines.

After strict import, there is exactly **one prescribed unchanged-fixture attempt**.
No retry-until-green is admitted. First/second-chance faults retain bounded dumps,
raw exception/context records, original module loads, engine logs and complete
process exits. A missing dump, failed control, nonzero child, timeout, source
drift or incomplete capture is not a pass. All original records are retained;
the offline reader must reproduce the original disposition. Even an observed
clean diagnostic process does not explain or clear the original failed gate.

## Qualification state and next decision

This source checkpoint supplies diagnostic apparatus and admission, **not a
production repair or executed Windows result**. The PR ledger records subsequent
exact-head local checks, actual hosted execution, forensic findings and independent
review. Source inspection, historical captures, Python tests and compilation do
not substitute for the pending Windows process.

If the new capture supports a bounded source repair, preserve the counterevidence,
make the repair on #379 only, and qualify the resulting exact head against all
applicable Documentation/provenance, Native/sanitizer, Linux/Windows Godot,
shader-v3 and diagnostic gates. A changed protected source requires explicit
diagnostic/source admission; never refresh locks blindly. Shader-v2 diagnostic
FAIL, LCB03's miss and other recorded qualification limits remain disclosed.
An engine/dependency migration is not implied by an upstream similarity.

If no defensible bounded repair follows from the evidence, retain **HOLD**.
Stop before merge, auto-merge, self-approval, re-draft or #361 closure. All six
#361 gameplay-host plans remain Planned/NOT_RUN.

## Documentation change map

The validation ledger, handover, roadmap and navigation route this dated record;
the retrieval manifest excludes its historical/diagnostic details from default
answers. Existing runtime ownership, interfaces, invariants, gameplay controls,
material laws, native build inputs, source locks and dependency contracts do not
change. The ordinary CI gates are unchanged and gain no exemption.
