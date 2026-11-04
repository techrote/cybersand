---
title: IN-TOOLS PR383 successor correction and bounded Linux qualification
status: Current
document-kind: evidence
scope: A01 claimant admission, A02 material-work accounting, fresh source-qualified Linux execution and preserved historical custody; Draft only, no integration or full acceptance
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/in-tools-metered-drain.md, ../operations/cybersand-codex-development-handover.md, ../reference/configuration-reference.md, ../reference/interfaces-and-message-contracts.md, 2026-11-04-in-tools-361a-metered-drain.md, ../operations/current-and-historical-validation.md]
---

# PR383 successor correction and bounded Linux qualification

## Publication continuation and current coordination — 21:40 UTC

The original successor chat filled during publication. The owner requested its
completion, and a new isolated checkout recovered the original clean source,
all raw run directories and the uploaded Git objects. Fresh independent
[custody verification](in-tools-383-successor-2026-11-04/continuation-custody-review.json)
reauthenticated the original logs, compiler/executable, 1,109 host inputs, 55
native compilation inputs and all 18 runtime payloads. This was a new readback
of the existing execution cohort, not a new native or Godot run. The independent
[source review](in-tools-383-successor-2026-11-04/continuation-source-review.json)
found no blocking A01/A02 defect and separately reran all 28 parser controls.

Command-line Git publication lacked credentials in the original checkout. The
authenticated publisher recreates commit metadata, so the publication identities
are deliberately separate from the execution identity:

| Role | Commit | Complete tree |
|---|---|---|
| Actual executed source, archived local commit | `e11b452f1e90a8a014ab4d721b7c65724a508597` | `22a35293c7373ea4583b78121778b00ecdf6eeee` |
| Authenticated implementation, source-equivalent publication | `f2f673e4a961207347dd8708dce7d6b63788a432` | `22a35293c7373ea4583b78121778b00ecdf6eeee` |
| Original local evidence addendum, archived | `7b35d05bc846328fd66f710f797de4db99ebd582` | `5b4913da6e7e107e059b8e0d0182f4af34859a18` |
| Authenticated original evidence addendum | `83e9825f4b4c30153361809d74d273abcf33587f` | `5b4913da6e7e107e059b8e0d0182f4af34859a18` |

The implementation's sole parent remains original PR head `73b10f9b`; the
authenticated evidence addendum's sole parent is `f2f673e4`. A final publication
supplement adds only evidence, the transport checker and directly affected
documentation. The [transport identity](in-tools-383-successor-2026-11-04/transport-identity.json)
archives the actual raw local commit bytes and original final-head review.
The portable checker verifies their Git object hashes and the identical complete
published implementation tree before using it for source lookup. It requires
only the published ancestry, not unreachable local commit objects. Execution
remains attributed to `e11b452f`; later commits receive explicit source-equivalence
qualification. Publication requires an unchanged expected remote `73b10f9b`
and a non-force update. The final PR head and tree are authenticated separately
after that update; this prepublication record does not claim it already occurred.

Review found and corrected an unfinished transport-checker output defect: a
tick-observation loop shadowed the authenticated identity variable. The three
reference changes restore the identity dictionary in the output. The
[checker review](in-tools-383-successor-2026-11-04/transport-checker-review.json)
retains the original and corrected hashes and seven rejection controls. This
does not change a measured test, fixture, production source or admission threshold.

At continuation intake, live main remained `751edc0b` and #383 remained Draft at
`73b10f9b`, with auto-merge disabled and no competing writer recorded.
**#379 has progressed beyond the earlier source-admission stop preserved below.**
Its owner published `b30ae3cc496534fdad5e13f36ef049c4a00024ac`, tree
`51133e19ecab5154ee4c3435731a9f5537dd69de`, then recorded
[HOLD after a Windows process failure](https://github.com/techrote/cybersand/pull/379#issuecomment-6642233489).
The Windows `test_liquid_desktop_default_host` process returned `0xC0000005`;
the required Windows coverage gate also failed. Those separate results neither
qualify nor disqualify this source-local Linux correction. #379 remains unmerged
and separately owned. Its current disposition replaces the earlier pending
source-admission status for planning; all dated evidence below keeps its
original meaning. No main or #379 change is included here.

## Disposition and custody

**A01 corrected. A02 qualified as the narrower material-work contract. Keep
[PR #383](https://github.com/techrote/cybersand/pull/383) Draft.** This is a bounded
successor correction on the existing `feat/in-tools-361a-metered-liquid-drain`
branch, not a replacement implementation or PR. The owner assigned the stopped
branch to this successor. Live PR/branch readbacks agreed with the assigned head,
the recent discussions recorded both predecessor agents stopped, and no competing
writer or newer target head was found before local work. The
[custody record](in-tools-383-successor-2026-11-04/custody.json) contains the local
exclusive-writer record, original clean/untracked inventory, all 1,976 baseline
Git blob entries, main overlap inventory and runtime/companion authentication.
The local record is coordination evidence, not a server-side lock; publication
requires a fresh head/discussion check and a normal fast-forward push.

| Cohort or authority | Commit | Tree or qualification |
|---|---|---|
| Original executed implementation, historical | `f4878302fd66975468dd307a94bb035529af5ecd` | `b5743bdb4b7a6c3e8fc6c1f8d331aa08ce21b719` |
| Adopted existing PR head, historical | `73b10f9b800e72f358f22f470e57a4531002c168` | `31c5a9a4b986820985658d3ed2228ebe9008828a` |
| Frozen independent Linux evidence, historical | `c83984c029080b49ad1776a2b3de8c16f7ad5892` | `f58c3298a2ab1f22d91a7fa228ff8caae9789373`; separate branch, no files imported |
| Freshly measured successor implementation | `e11b452f1e90a8a014ab4d721b7c65724a508597` | `22a35293c7373ea4583b78121778b00ecdf6eeee` |
| Live main inspected, not integrated | `751edc0b495dc85484ad5509a7c95f863651c76b` | Includes #377 and #390; shared worker-interest changes need later reconciliation |
| Separately owned #379, untouched | `1aaab324a9bccbaa7f868798dbb4f9fd9b4a7718` | Open, Ready, unmerged; current-main integration blocked on source re-admission |

The original [implementation audit](2026-11-04-in-tools-361a-metered-drain.md)
and its packets are unchanged. The frozen independent index's 30 members, its
publication readback and its host coverage review were authenticated as a
separate historical cohort. Its 31 audit files were neither cherry-picked nor
overwritten. Old tests do not qualify `e11b452f`.

The correction commit changes only nine implementation/test/contract paths.
Production native source, includes, adapter/ABI, material data, dependency/runtime
trees, ordinary-v1 budget, worker implementation and #370 comparison apparatus
are unchanged. No main or #379 merge was performed. The subsequent addendum is
documentation/evidence only; its [publication qualification](in-tools-383-successor-2026-11-04/publication-qualification.json)
independently compares all measured inputs before final publication. Runtime
execution remains attributed to `e11b452f`, not silently reassigned to that
addendum.

## A01: exact claimant admission

Source anchors are
[`worker_controls`](../../native/tests/test_metered_liquid_drain.cpp),
[`parse_result`](../../tools/lcb/run_metered_drain_native.py), and the
[parser controls](../../tools/lcb/test_metered_drain_native.py).
The original native predicate accepted at least two claimants and the parser
accepted two through four, although the registered large-tank claim was four.
Historical observations already reported four. This was an evidence-admission
defect, not evidence that native scheduling had failed.

The corrected predicate and typed parser require **one observed claimant in
each one-worker arm and four in each of the eight registered large four-worker
arms**. The native statistic is the largest number of distinct workers observed
claiming jobs in one phase during the arm. It establishes four observed phase
claimants at least once in each arm; it is not an assertion about every tick or
simultaneous CPU occupancy. Reported observations still come from actual native
statistics and are not replaced with configured values.

Independent synthetic two-claimant and three-claimant negatives each cover all
eight worker rows. Missing fields, Boolean values, fractional values and
integer-valued floats fail closed for both claimant fields. The valid integer
one/four packet remains accepted. Before the fix, the new 28-test suite produced
16 expected failing subtests against the original parser: both invalid counts
were admitted in every registered worker row. That negative-control failure is
retained in [parser-controls.json](in-tools-383-successor-2026-11-04/parser-controls.json),
with its actual original source plus local test delta and log hashes.

A newly compiled executable at `e11b452f` passed **30 native cases**, including all
eight actual one/four-worker pairs, physical-state parity and separate IN-ledger
parity. Every large four-worker arm observed four claimants. The recorded
**14,023,753 assertions are repeated assertions, predominantly positional census
checks**, not independent experiments. All 28 parser/custody tests then passed
at the same committed source. The complete [native record](in-tools-383-successor-2026-11-04/native-qualification.json)
binds 55 source inputs, compiler, fresh executable, four original log hashes,
bounded 600-second compile/240-second run timeouts and actual result rows.

The 312-cell Godot fixture is a different host. Its configured one/four-worker
arms observed one/two claimants. Its threshold remains appropriate to that small
fixture, and no four-claimant application claim is made.

## A02: precise counting contract and call path

**No aggregate 2,048 limit on every native call or getter is claimed.** The
existing invariant is a per-step **material-work** allowance, now named
`read_accounting = material-work-units-v1` in helper and admission-only receipts.
The misleading `conservative-native-call-units` label is retired. The 2,048-read
and 128-write limits, ordinary-v1 U10 budget and safety inspection algorithm
are unchanged. This disposition corrects an accounting-scope mismatch with
source-localized documentation, receipt naming and new instrumented runtime
controls; it does not represent documentation as proof of the stronger cap.

| Path or operation | Actual source and accounting |
|---|---|
| Worker preparation and ownership | `simulation_worker.gd::_worker_loop` prepares native masks/coupling from the captured frame. `_consume_physical_usables` holds the existing cancellation mutex across admission and execution. Its refresh, loop refresh, scalar setup/interest/window work and mask/geometry preparation are outside the material-work counter. |
| Runtime lifecycle/setup | `physical_usable_runtime.gd::advance_physical` refreshes the metered owner before resetting step counters. Existing Object capability probes and native health/scalar calls are outside this counter. No claim absorbs the whole worker tick into 2,048. |
| Original source clearance | `_source_clear`, `_source_cell_clear`, `_body_at` and inherited `_read` charge each actual body-mask/material read. Repeated mask reads are distinct calls and remain charged; source clearance is not silently deduplicated against helper reads. |
| Helper setup and metadata | `metered_liquid_drain.gd::apply` reserves ten units for refresh plus tick/revision setup, six for `_identity_matches` before writing, and eight for final identity plus tick/revision copies. Short-circuit branches can make fewer calls than the reservations. |
| Preflight material/geometry reads | `_read` charges every actual `CyberDemoBridge.inspect_cell` call once. Its cache reuses an already inspected coordinate across intake candidates and per-target supercover paths. Before each inspection it checks bounds and the read limit that preserves post-readback/identity reservations; the complete target plan is established before the first erase. |
| Adapter internals | One bridge inspection aggregates native health/tick/material/state/body-mask/temperature/configuration field reads. One charged inspection is not a count of every internal C++ getter. |
| Destructive writes and post-readbacks | Intended radius-zero `emit_disc(..., EMPTY)` erases are reserved against remaining 128-write capacity before the first write. Runtime `write_count_last` adds verified transitions; `writes_attempted` separately preserves attempts, and faults terminate further work. Each attempted target gets a fresh, separately charged post-inspection; cached preflight data cannot substitute. Final identity checks are reserved before the first write. |
| Optional observation/publication | `_observe_local` performs an 81-cell material patch only when all 81 units remain. Copied outcome/snapshot data and `observation(owner)` without a World make no new native reads. Terminal faults skip optional observation and further work. |

These source paths are in
[`metered_liquid_drain.gd`](../../godot/scripts/metered_liquid_drain.gd),
[`physical_usable_runtime.gd`](../../godot/scripts/physical_usable_runtime.gd),
[`simulation_worker.gd`](../../godot/scripts/simulation_worker.gd) and the
[native inspection adapter](../../godot/native_extension/cyber_demo_bridge.hpp).
The contract is owned by the [current operations guide](../operations/in-tools-metered-drain.md)
and its linked configuration/interface references.

For a completed helper operation with `P` unique preflight inspections and
`T <= 16` post-inspections, charged helper work is `P + T + 24`.
Before entry admission a refusal charges zero. After refresh, refusals charge ten
plus inspections actually attempted and six only if pre-write identity was
entered; they do not invent completed final identity work. A fault on attempt `k`
after pre-write identity charges `10 + P + 6 + k`, without pretending final
identity or complete quantity verification occurred.

A conservative source-local upper bound is 61 radius-4.25 candidate offsets,
at most 702 distinct cells in the rectangular union of successful bounded
supercover paths, and thus at most `702 + 16 + 24 = 742` helper units. The
original source-clearance loop has the unconditional bound
`1 + 128 * 7 + 2 = 899` charged reads; this deliberately uses the loop bound
rather than assuming epsilon corner stepping always terminates at the endpoint.
For one command on an otherwise idle actor, adding one optional patch gives at most
`899 + 742 + 81 = 1,722` charged units. These are conservative bounds, not a
tight measured maximum and not all-native-call counts. Multiple actors, earlier
projectiles/devices and other prior work still share the enforced 2,048 budget.

## A02: instrumented paths and capacity boundary

The new `MaterialWorkProbe` in
[`test_physical_metered_drain.gd`](../../godot/tests/test_physical_metered_drain.gd)
forwards actual native inspections and erases, records unique preflight cells,
fresh post-readbacks, identity hooks and first-write state, and independently
reconstructs the documented ten/six/eight reservations. It does not fabricate
native observations or reuse production accounting constants as its oracle.
The eight bounded controls exercise the existing `_execute` seam on a real
native World; the full runtime/worker/Main routes are separately executed.
Source-clearance contribution is read from the parent counter and checked
against the source path, not presented as an independent all-getter census.

| Path | Pre-inspections | Post-inspections / erases | Helper units | Source units | Optional units | Prior seeded units | Final shared units | Actual Water loss |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Full 16-target Q255 pulse | 54 | 16 / 16 | 94 | 13 | 81 | 0 | 188 | 4,080 |
| Exactly sufficient capacity | 54 | 16 / 16 | 94 | 13 | 0 | 1,941 | **2,048** | 4,080 |
| One unit less available | 53 | 0 / 0 | 63 | 13 | 0 | 1,942 | **2,018** | **0** |
| Fractional FreeMass, 63 units/cell | 54 | 16 / 16 | 94 | 13 | 81 | 0 | 188 | 1,008 |
| Empty intake/no effect | 30 | 0 / 0 | 40 | 13 | 81 | 0 | 134 | 0 |
| Actual corner-supercover blocker | 2 | 0 / 0 | 12 | 13 | 81 | 0 | 106 | 0 |
| Exhausted finite stock | 0 | 0 / 0 | 10 | 13 | 81 | 0 | 104 | 0 |
| Injected post-copy readback fault | 54 | 1 / 1 | 71 | 13 | 0 | 0 | 84 | **255, unverified** |

The 1,941/1,942 values are explicitly synthetic prior counter consumption, not
claims that those native calls were executed. At exact fit, the first write
occurs after 70 helper units, with capacity still reserved for all 16 fresh
post-readbacks and eight final identity units. The terminal uncertainty latch is
already set, and finite stock has not been prematurely debited. All 16 erases
complete and quantity closes exactly.

With one unit less capacity, the helper cannot finish preflight. It refuses
`read_capacity` before any erase and preserves the complete native census,
physical hash, stock, charge and cooldown. Unused reserved space stays unused;
there is no requirement to consume all 2,048 units on refusal. Both boundary
cases skip the optional patch. Existing independent write-capacity controls
continue to protect the 128-write step limit and 16-target operation cap.

The new fault control performs an actual native erase and actual post-inspection,
then deliberately corrupts the copied return. The World loses 255 units while
verified sink remains zero. The result retains `quantity_complete=false`; the
independent census records the 255-unit loss. It enters terminal quarantine, skips optional
observation and attempts no retry on a subsequent real step. It is not converted
to normal refusal, rollback or a successful zero-residual operation.

The corner test uses a real side-cell wall with an empty diagonal cell and a
separate Water witness; supercover cannot skip the wall. Complete evidence and
independently recomputed reductions are in the
[native-host packet](in-tools-383-successor-2026-11-04/metered-drain-native-host.json)
and [independent review](in-tools-383-successor-2026-11-04/independent-review.json).

## Fresh execution and runtime identities

All runs use new output directories and the committed `e11b452f` source.
The [host identity](in-tools-383-successor-2026-11-04/host-source-identity.json)
seals 1,109 source/runtime inputs and both 80-input native runtime manifests.
The retained native/Rapier libraries were authenticated and materialized, not
rebuilt or represented as newly built. Production native inputs are unchanged.
The standalone test executable was freshly compiled. Original outputs, logs and
packets were sealed before the documentation addendum.

| Tool/artifact | Identity / SHA-256 |
|---|---|
| Platform | Linux x86_64, Ubuntu 24.04 environment; exact kernel/OS/Python in the host identity |
| Compiler | GCC 13.3.0, Ubuntu `13.3.0-6ubuntu2~24.04`; `52f1ddb33fe78b9441e0f42e9cd22c571f1101938e046c8a26582494e041cc73` |
| Fresh standalone native executable | `033daec99be25d9c5f6b428bb5c99012aa67517acba1edc07f3e90f0c7cdba2e` |
| Godot executable | `4.7.stable.official.5b4e0cb0f`; `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Linux native runtime | `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45` |
| Linux Rapier runtime | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Windows native, identity only | `ee09f7ab485f817b5f58e767ddb26f2e430439bb3dd4f185019eda028f47199a` |
| Windows Rapier, identity only | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |

The [unchanged strict runner](../../tools/ci/run_godot_regressions.py) executed
import and all 15 scoped Godot suites through the recorded
[harness](in-tools-383-successor-2026-11-04/run-host-successor.py), with natural
zero exits, no skips, no runtime errors and no watchdog failure. The
[process records](in-tools-383-successor-2026-11-04/host-qualification.json)
retain exact commands, timeout policy, original log hashes and success footers.

| Godot route | Counted assertions/checks |
|---|---:|
| Metered native-backed runtime/worker | 1,811 |
| Metered equipment/session | 99 |
| Actual Main/worker/Rapier, injected Godot input | 148 |
| Ordinary physical runtime / admission / desktop | 243 / 35 / 28 |
| Sampled usables | 196 |
| Physical equipment / lifecycle / actor session | 307 / 39 / 113 |
| Actor rig session | 8,425 |
| Liquid solver policy / physical preparation / Water reference body | 642 / 62 / 75 |
| Genuine native failed-tick regression | PASS, no numeric assertion footer |
| **Total counted** | **12,223**, plus the separate uncounted failed-tick suite |

The native-backed and Main packets are written before their final writable
assertions, so packet counts 1,810 and 147 correctly precede footers 1,811 and 148.
Equipment's 99 checks use real Rapier but explicitly synthetic copied outcomes;
they are not a native quantity experiment. Injected post-edit faults are separate
from the genuine native failed-tick control.

All 16 application quantity arms close independent initial/remaining inventories
and verified sinks at actual one/four configured workers: Q7 Water removes
112 units, Q255 Water removes 4,080, fractional FreeMass removes 1,008 and Brine
removes 16 cells. Post-shutoff native transport retains quantity and each paired
configuration retains physical parity. The packet contains 76 report rows and
79 command observations: 32 applied, 41 refused, three incomplete injected faults
and three separate ordinary-v1 controls. Independent reduction verifies selected
material dimensions, actual transition sums, allowance closure and resources.

Finite per-native-generation actor-slot 32Q/32 stock, selection without refill,
fixed 0.85 charge and 0.10-second cooldown, PressureFlow/imported-IN refusal,
walls/corner paths, actual native body masks, cancellation/focus/play/restart,
and terminal ownership remain covered. Main's fresh observations are:

| Actual Main path | Initial | Removal | Final |
|---|---:|---:|---:|
| IN Water, two pulses | 538,560 | 4,080 | 534,480 |
| Fresh IN reset | 538,560 | 2,040 | 536,520 |
| IN Brine, separate cell units | 2,112 | 8 | 2,104 |
| Fractional FreeMass | 538,560 | **1,594** | 536,966 |
| Ordinary U10, separate joined-census control | 538,560 | **27** | 538,533 |

These are the new [Main packet](in-tools-383-successor-2026-11-04/metered-drain-desktop-host.json)
observations, not replacements for earlier asynchronous Main measurements.
The ordinary-v1 value is a joined-census difference, not an invented command
quantity receipt. Six actual masked Water positions preserve material, Q255
quantity and body ID while native ticks advance 63 to 69. Wall and mask refusals
preserve measured quantities.

## Evidence publication, validation and remaining gates

An independent reviewer who did not author the correction inspected the nine-file
diff and original executable/log/packet artifacts, checked runtime/source custody,
and recomputed packet conservation/accounting. Its conclusion is **PASS within
the bounded Draft scope**, with no blocking source finding. It is an automated
independent review, not human/account approval or permission to integrate.

The [evidence index](in-tools-383-successor-2026-11-04/evidence-index.json) binds
published bytes. The two complete observation packets use whitespace-only
compaction outside JSON strings, preserving every token, key order, numeric
lexeme and string. Their new published hashes and original raw hashes/sizes are
separately recorded in `custody.json`; no original packet was overwritten.
Raw process logs and executables are not committed under repository policy.
The original independent review authenticated them locally; the portable
[published-evidence checker](in-tools-383-successor-2026-11-04/check-published.py)
distinguishes that raw-artifact review from checks reproducible using only the
published packet. The retained [raw-cohort checker](in-tools-383-successor-2026-11-04/check-raw-cohort.py)
requires the original run-directory layout and artifacts.

The [final local checks](in-tools-383-successor-2026-11-04/final-validation.json)
record documentation, repository/materialized provenance, historical M11,
retrieval, LFS and whitespace results. Frozen retrieval questions, existing
challenge questions, ranking logic and thresholds are unchanged. The historical
LCB03 challenge miss remains disclosed. Two additive A01/A02 questions are
evaluated separately from those cohorts and the original four metered questions.
Route hits establish discoverability, not semantic correctness.

| Documentation/implementation obligation | Disposition |
|---|---|
| Canonical contract and capacity | Updated operations guide, configuration reference and interface receipt scope |
| Runtime/test source | Exact native predicate and typed parser; additive native-backed instrumentation; receipt accounting label |
| Ownership/ABI/materials/default policy | No change; existing canonical ownership remains authoritative |
| Retrieval/corpus | Existing canonical guide remains in corpus; new dated evidence excluded from default answers; two additive questions kept separate |
| Handover/history | New successor entry and evidence link; original measured and frozen audit cohorts retained |
| Programme scope/ADR/roadmap | No new admission, implementation programme, ownership or integration decision; no programme rewrite required |

**Remaining owner actions:** preserve Draft for this checkpoint; coordinate with
the exclusive #379 integration owner and accepted live main before any later
source reconciliation, especially #390's worker-interest delta. After separately
authorized integration work, requalify the actual resulting source/runtime and
run all applicable exact-head hosted Documentation/materialized provenance,
Native, GDExtension/Godot and scoped Water/actor gates. Draft skips or stale
greens are not execution passes.

The [#379 owner's 20:06 UTC continuation](https://github.com/techrote/cybersand/pull/379#issuecomment-6640850821)
explicitly stops current-main integration: #390 changes its immutable
`simulation_worker.gd` source lock, so a bounded successor source-admission record
is required before reconciliation. The original v1 fixture registration and its
historical green checks must be preserved, not refreshed silently. That owner
made no #383 change and retains exclusive #379 ownership. This separate admission
block does not reassign #379 work to the present isolated #383 correction.

Windows native/Godot execution, physical mouse/keyboard/gamepad input, real OS
focus behavior, rendered desktop pacing and owner handling acceptance are
**NOT RUN / UNTESTED** here. No hosted workflow was dispatched. No Ready change,
approval, merge, auto-merge or #361 closure is authorized or performed. The
stronger aggregate all-native-getter budget remains unproved and unpromised;
any future requirement for it needs an independently scoped counting/ownership
design, not a raised threshold or silent safety exclusion. #361-B valves/nozzles,
general liquid tools, native movement/pressure changes and material migration
remain outside this task.
