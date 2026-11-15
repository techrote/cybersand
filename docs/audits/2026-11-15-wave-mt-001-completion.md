---
title: WAVE-MT-001 PR 618 completion and qualification ledger
status: Current
document-kind: evidence
scope: 15 November 2026 independent PR 618 completion; source repairs, protected-source transitions, experimental Godot integration, pinned runtime publication, native benchmark method and exact-head acceptance custody
canonical-for: []
last-reviewed: 2026-11-15
related-documents: [../architecture/wave-flow-v1.md, ../operations/wave-flow-evaluation.md, ../operations/github-development-and-release.md, ../operations/ci-execution-and-performance.md]
---

# WAVE-MT-001 PR #618 completion

This record belongs to [PR #618](https://github.com/techrote/cybersand/pull/618)
on `codex/wave-mt-001-parallel-20261115`. The original Claude PR #617 remains
separate and is not modified. The owner authorizes implementation, repairs,
source-matched builds, repeated CI execution and Ready-for-Review activation.
Merge, auto-merge and production Water-default promotion are not authorized.

Run-specific results, exact HEAD/tree identities, retained artifact links and
the final independent Astra verdict are recorded in the PR's qualification
ledger. A workflow definition or local predecessor pass is not a final-head
pass. This source record describes the concrete changes and acceptance method;
it does not substitute for that live run ledger.

## Source custody

| Reference | Verified starting commit |
|---|---|
| Accepted main | `018bd09503d7f079ddac52e225c2f7daf8d678bf` |
| Independent reconciliation checkpoint | `5e8ff8391f58516c18ea640986b6c4a49e0f8257` |
| Claude PR #617, inspected read-only | `50d60c5d4e69c193f74306553ff33c9341922be7` |

The [original audit](2026-11-15-wave-mt-001-wave-flow.md) remains unchanged.
Its Windows timings and review are historical results for the original source;
they are not reused as proof for this candidate.

## Repaired contracts

- One-unit transfers and pending nonzero flux keep the relevant region awake;
  deterministic seam, thin-film and falling-drop regressions exercise this.
- Selected simulation regions own complete selected cores. Excluded cores and
  faces freeze; reentry resumes retained state. Native tests compare 1/2/4/6
  workers, negative coordinates, edits and moving masks with fixed seeds.
- Complete physical identity is version 6 and includes retained flux, round,
  configuration and sparse scheduling metadata. Physical save format 0 and
  explicit save/restore refusal prevent silent loss of continuation state.
- Additive versioned C construction and uint16 mass readback preserve the old
  ABI. The old uint8 getter saturates; tests use actual overfilled cells.
- Receiver capacity arithmetic cannot underflow, sealed overfill is bounded,
  metered external removal preserves full mass, edits retire stale face flux,
  and unrepresentable coordinate halos refuse before mutation.
- Water population accounting, neighbouring material wakes, symmetric damping
  and adhesion settings have explicit regression coverage.
- Water-owned pair chemistry, coherence and lighter-fluid exchange remain
  intentional experimental limitations. Nonzero coherent writes and custom
  transport profiles refuse. Other materials retain their initiating kernels.

The native default-off path and registered policy families remain unchanged.
The experiment remains a `WorldConfig::wave_flow` override of the FreeMass
Water carrier; no catalogue identity or production policy family is added.

## Linux ABI diagnosis

The original `alignas(64) WaveHalf` raised the containing Wave allocation's
alignment. ELF symbol inspection of the original executable confirmed aligned
`operator new` and `operator delete` imports requiring `CXXABI_1.3.11`.
Ordinarily aligned storage with 64 trailing padding bytes separates the useful
per-worker counters without invoking that allocator. The runtime-floor checker
is unchanged: the actual pinned runtime must still pass the existing GLIBC,
GLIBCXX and `CXXABI_1.3.9` checks. Local development uses GCC 14.2/ld 2.44 and
does not establish the pinned build's floor; hosted builds use the repository's
approved GCC 13.3/ld 2.42 and LLVM-MinGW 20260826 inputs.

## Godot and packaged execution

The desktop feature launcher and `--wave-flow` route construct a real native
Wave World. The [guide](../operations/wave-flow-evaluation.md) describes the ten
fixtures, comparison solvers, native/Rapier rates, substeps, worker readback,
quantity and memory diagnostics. The moving barrel and Needle reuse the actual
Rapier bridge and authored actor paths. Copied render values remain separate
from mutable native authority; native pool workers call no Godot APIs.

`godot/tests/test_wave_flow.gd` requires all nine completion sections:
native configuration, mass readback, region pause, state identity, save refusal,
solver comparison, fixtures, real Rapier contact and real Needle contact.
The publisher rejects missing/false/malformed/duplicate completion, failures,
skips, nonzero exit, source changes and log digest mismatch. Existing liquid
policy, pressure reference and PressureFlow/Rapier controls execute alongside it.
All ordinary discovered Godot shards remain separately required.

The Windows package contains pinned Godot 4.7, the source-built native DLL,
pinned Rapier, applicable verified VC runtime files and notices, committed
game/fixture source, the guide, native/source provenance and a SHA-256 file
manifest. `Test It.cmd` imports and launches the Wave evaluator without local
developer paths. The workflow extracts the final ZIP into a separate directory,
verifies its complete payload, then executes import, the strict Wave suite and
launcher startup on Windows. Actual physical GPU and human gameplay acceptance
remain separate from automated headless execution.

## Benchmark method and retained negatives

The hosted Windows matrix measures complete `World::tick()` calls with one
fresh process per row on the same machine/compiler/build. It covers 256²,
1024² and 2048²; dam, repeated wave disturbance, disconnected sparse reservoirs
and idle pools; FreeMass, Inertial, PressureFlow cached/dormant, and Wave substeps
1 and 3; requested workers 1/2/4/6; two repeats, 30 warm-up ticks and 60 measured
ticks (240 warm-up for idle). Every measured law uses the same allocation
instrumentation and quantity/ledger closure checks.

Raw CSV, per-row JSONL, executable/source/tree/compiler/machine identities,
allocation counts and bytes, steady storage, actual participants and
median/p95/p99/max complete-tick times are retained in the Actions artifact.
Phase timings include only the measurement window. The runner fails on malformed
or missing rows, timeout, nonzero exit, mass/accounting mismatch or source
mutation. It preserves failed rows and logs instead of dropping negative results.
The reducer reports matched ratios; targets are evaluated from actual output.

The local 20-row 256² apparatus smoke used deliberately short eight-tick
measurement windows with concurrent development work. All rows passed quantity
closure and measured zero tick allocations. It validates apparatus operation,
not performance targets or parallel speedup. The complete hosted matrix is the
candidate evidence for performance.

## Publication and exact-head acceptance

`tools/ci/wave_mt_runtime_publication.py` privately composes the established
shared-contract publisher. It retains source/Git/LFS/input-ledger, target-OS,
binary architecture, log-integrity, exact branch-lease and four-file staging
guards. An explicit versioned request on the owned branch arms builds. The
workflow cannot modify Claude's branch or main. The single-parent append and
exact source lease reject a branch that changes while builds run.

The publication job waits for the native normal, ASan/UBSan and TSan suites,
both target-OS focused regressions, Linux ABI checks, and extracted Windows
package qualification. Its only committed paths are the two native binaries
and their two provenance manifests. The original shared publisher and runtime
floor policy remain unchanged.

The resulting PR HEAD then requires Documentation/provenance and protected
source checks, the complete native aggregate/sanitizer families, Linux and
Windows source-built GDExtension plus all discovered Godot shards and coverage
reducers, applicable Water/PressureFlow/inertial/architecture gates, and the new
Wave suite and matched Windows matrix. Draft skips and classifier-only results
do not satisfy execution. Any later native change invalidates affected binaries;
every later HEAD requires its own applicable CI conclusions.

Only after those checks are green is a separate explicitly selected Astra
reviewer commissioned against the frozen HEAD/tree, accepted main, complete
diff, actual logs, raw timings and artifact provenance. Blocking findings require
repair, requalification and renewed independent review. The final PR remains
unmerged for the owner.

## Protected-source transition records

Each reviewed transition below authenticates its retained source commit and
exact LF hashes. The immutable baseline catalogue lock is not edited. The
transition chain requires retaining the named commits, so eventual integration
must use a merge commit rather than squash or rebase.


### PR #618 source checkpoint

Reviewed source commit: `1e7fac9eb909b982c961f34eefe7859430728de8`, tree
`0d33bdc063d3c05aeca1941ab004ba894de5dbc0`. The implementation review compared
these three protected consumers with accepted main. Wave-owned construction,
transport, wake and physical-state additions are conditional on the opt-in
World; catalogue IDs, definitions, digest inputs and admitted production
policy/physical formats are unchanged. The shared receiver-capacity expression
now returns zero when already full; all legal legacy receivers retain the same
capacity. No immutable lock or historical transition is rewritten.

The reviewed `world_quantity.inc` addition changes only the number of Water
cells after conservative bulk transport; it cannot create a quantity source
or sink. `world_pressure.inc` changes only Wave's versioned complete-state
identity and explicit unsupported continuation refusal. `world.cpp` wires the
conditional side state, bulk passes, wakes, edits and validated carrier bounds.

Local execution at this checkpoint includes the expanded 22-case optimized
native suite (build and execution passed with identical before/after input
digest `4b4bd578807f3d5e94aa837758690ad319d9b00692faba98d778d3ea4e5087a5`),
the Godot 4.7 development fixture suite (4,981 assertions, zero failures), the unchanged Linux runtime-floor check, three publisher/package
adversarial tests, thirty inherited publisher guards, documentation/M11 and
retrieval checks. Later exact-source adapter, sanitizer, target-OS, complete legacy-family
and exact-head CI results remain separately identified in the PR ledger.
The first local ASan/UBSan execution passed all 21 predecessor cases but failed
at LeakSanitizer shutdown because this local environment runs under ptrace;
that process is recorded as failed, and hosted leak checking is not disabled.
The source review authenticates this bounded transition; it does not waive
those runtime gates or assert merge approval. PR #618 is the tracking issue
for these three transition entries.

| Protected path | Previously admitted LF SHA-256 | Reviewed LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `36f928740f554cde7542bc16e8ef897317ea51f3897af665ff6bb7f9e1ca812b` | `9600f625792929db95481f45cca2233716df921ff5001a052d0839de043ff384` |
| `native/src/world_pressure.inc` | `899ada71b89d30ba063e047bdd5b02346948008f1b7c0bec9fa0f2272e4d86ec` | `a545d153f0f68c930837c59be449ac455b3fd35f36e268f21cffbfc940cb6da9` |
| `native/src/world_quantity.inc` | `d9e6835d092193e4976c728d90121c6dee4b421337e056b5fc3c74975491af6e` | `1dc5ac99aacb1bac6a41edb0aa7479ed4dbef2b493e1d26b02e185aaff9c3e1d` |
