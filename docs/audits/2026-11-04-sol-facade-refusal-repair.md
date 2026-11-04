---
title: SOL public refusal and authoritative readback repair
status: Current
document-kind: evidence
scope: Isolated dependent facade repair, authenticated before/after qualification and retained physical/material admission blockers
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../systems/solid-detachment.md, ../reference/interfaces-and-message-contracts.md, 2026-11-04-sol364b-corridor-result.md]
---

# SOL public refusal and authoritative readback repair

## Authority and branch ownership

This bounded implementation starts from verified draft #347 head
`1598115c9065239cc1eaec11e99077274b457be1`, tree
`eff31c3597347f06a4b23193cd64b58350386c29`, whose sole parent is executed
`9597abd76c01e4a940ff3ea26ff01fca43bf55a6`. The separate branch is
`fix/sol347-facade-refusal-20261104-095628`; its first source checkpoint is
`1caffe16c21bc411e7219ed7a6157d8b17a6ff51`, tree
`2bfa829513b0ea4a363f3c4d89e909b0c5dab2c3`, with the verified #347 head as its sole
parent. The worktree and object store are separate from every earlier worker.
The [Git API source map](sol-facade-20261104/source-publication-map.json)
records metadata-only publication as `f4f2adf99f63375f296632948e607f6d1cc5ffd9`
and `bb2daad5cb22054bd69bba94cbf3016c43cd422a`. Their exact trees and ordered
parents are independently read back; local qualification is not silently
relabeled as execution of different Git metadata.
The current accepted main control is `0103de80d11304388868f89f7b26c672ad6100ad`,
tree `0ba07dc799afca43716bbab966f48266fa924718`; it is not merged here.

The read-only reference is [draft #386](https://github.com/techrote/cybersand/pull/386)
at `b661a6f354f8c51e79759d22ad4573a875964b43`. Its 122-case probe is copied
byte-for-byte as a small reproducibility input, not imported as a branch or
accepted material authority. Its SHA-256 is
`07fe277d561b4f912cab410cd3f04b34239fbbe0b2fc1819512a252112a420e6`.
The frozen material authority stays `0fd4af5987e77db4da3e37c757cf2c0917ae9e15`.

No writes are authorized to #347, #386, #364, #281, #12, #352/#353 or #365.
Any publication is one Draft dependent PR targeting `sol-detach-001-current-main`.
Ready, merge, composition, material transition and restoration remain outside
this task. A later independent read-only audit and explicit owner decision are
required even if every facade test passes.

## Reproduced baseline

Fresh Linux Godot execution at the exact #347 intake reproduces all original
122 results, with zero outcome or returned-result mismatches. Every one of the
88 native/extension source inputs matches the retained runtime's authenticated
build inputs. The retained binary was built historically at `9edc4f8f`; this is
new execution with freshly checked source equivalence, not a new baseline build.

| Original defect/control | Original and freshly reproduced count |
|---|---:|
| Successful controls | 66 |
| Physical/comparison hash SIGABRT | 30 |
| Simulation-window enable SIGABRT | 8 |
| Safe native save refusals | 10 |
| Facade/native adhesion disagreements | 8 |
| Total processes, workers 1 and 4 | 122 |

The native library SHA-256 is
`de38c0de458b2a30d43cb36c633cb7ee3b469f8d84f7a3e512fafc9838bb82a5`.
Actual Godot is `4.7.stable.official.5b4e0cb0f`, executable SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
The fixture uses real 520-member/six-proxy native ownership with synthetic,
source-bound body reservations. It certifies no live Rapier trajectory.

## Root causes and scoped implementation

`World::physical_state_hash_impl` correctly refuses non-Idle SOL serialization.
The physical and two valid comparison getters previously let that exception
escape the GDExtension boundary. Additive structured results now preserve the
native refusal. Success alone contains a 16-character hash under `value`;
legacy String getters return an invalid-length empty string and retain an
explicit diagnostic. No zero, legacy state hash or incomplete CYPS substitute
is generated. No non-test application caller compares these legacy getters on
this branch; existing test/probe equality is supplemented with explicit status
and value-shape assertions.

Both window setters previously changed facade intent before invoking the fenced
native region setter. They now stage all fields and commit them after native
acceptance. Native region selection, selected cores and tick-applied cores are
separately exposed as copied observations. Both reset helper callers already
operate on a fresh World inside exception handlers. All native validation is
before region assignment; the subsequent native cache/discovery helpers are
nonthrowing. Extreme buffer operands are bounded without changing accepted
cached intent or overflowing signed arithmetic.

The native adhesion setter is nonthrowing and silently fenced. The facade now
reads the existing authoritative getter after a request and reports the actual
applied value. `diagnostic_reset` synchronizes the retained cache to the new
World, preventing a previously accepted false value from surviving a reset to
native true. Run-receipt adhesion also reads native state.

The same boundary repair catches the first fenced mask-clear in coupling,
refuses fenced or masked diagnostic fills before any write/revision change,
and catches retained-World hash refusal before prepared-liquid World swap.
The prepared token is still one-use on refusal. Native physics, World source,
material semantics, limits, 11/9 body ABI and thread ownership are unchanged.
The synchronous Web controller still represents its own UI intent; asynchronous
desktop commands remain queued owner intent. This task does not redesign those
controller acknowledgment protocols or admit SOL into normal gameplay.

Common successful frame operations retain a fixed scalar/literal status record;
the public Dictionary is created only when observed. Refusal/explicit hash
results contain copied values. Last status belongs to the exclusive owner and
records the operation's phase, not an always-current cross-thread phase query.

The catches are not general rollback machinery: the SOL, masked-fill and argument
preflights are nonmutating, but no guarantee is made that every hypothetical
later allocation/quantity/internal exception can undo earlier work. No native
transaction or failure-injection hook is added to claim otherwise.

### Discovered import/mask limitation

The first extended run exposed a separate, pre-existing native import limit.
CYPS omits transient masks, and the existing bridge's import path does not
configure the new World's transient mask domain. Four source-qualified diagnosis
processes (original and repaired runtime, workers 1 and 4) confirm that an
imported adapter cannot republish the marker until an explicit fresh reset.
Adhesion readback and byte-exact CYPS re-export pass before that attempted mask
publication. This is not an adhesion-cache equality substitute.

The new coupling status initially called that silent failure `applied`. The
successor repair checks each covered cell's existing native readback when mask
publication returns false: nonzero occupancy preserves existing first-body
arbitration, while an empty cell raises a translated refusal. No bridge import
initialization change is admitted here, and the protected native restoration
source `native/src/world_pressure.inc` remains unchanged.
Because this late refusal can occur after frame observations/body samples were
retired, it does not promise a general coupling rollback. The SOL fence still
refuses before those changes. Full hash parity with a source transient mask is
explicitly unavailable after this import; the native adhesion and exact CYPS
re-export witnesses remain mandatory and independent.

## Qualification and reproducibility

The source-bound [qualifier](../../tools/sol281/qualify_facade_refusal.py) records
source/tree and individual input hashes, actual OS/compiler/editor/runtime,
commands, timestamps, process limits, exit codes, raw output and before/after
identities. Original and status-instrumented 122-case arms remain separate.
The [supplemental public regression](../../godot/tests/test_sol_facade_refusals.gd)
runs workers 1 and 4 and asserts lifecycle ownership, explicit refusal, repeated
calls, all region fields, independent CYPS adhesion import/re-export, reset,
failed transactions, prepared-token retirement and real failed-World recovery.

At first source checkpoint `1caffe16`, the new Linux extension build passed
(GCC 13.3.0; 4,375,808 bytes; SHA-256
`e67e21ea542b0cd775082d3ca4fc25d5fb8c6df67725b768163df2d577d08d8b`).
Both 122-process arms passed with zero process aborts. The unchanged arm
preserved all 66 controls and 10 safe export refusals; the instrumented arm
proved 46 explicit native refusals (38 former aborts and 8 refused adhesion
requests), with all 8 independent native adhesion witnesses agreeing.

The first extended run **failed** at both workers: 16 cases and 3,070 assertions
per worker, with 15 assertion failures each. Fourteen arose from attempting
unsupported imported-mask republication/full hash parity; one expected an
empty disabled region instead of the existing finite full-world region
`[0,0,1024,1024]`. All raw failures remain retained. The successor fixes the
misleading coupling acknowledgment and makes the apparatus state these native
limits; a fresh successor run is required before claiming qualification.

The first checkpoint's native GCC suites passed both optimized and strict
ASan/UBSan execution: solid detachment 19,338 checks, conservative displacement
281, exact contact geometry 6,817, and the separate lifecycle model 384
transitions/12 refusals/8 quarantine guards. All eight exits were zero with
empty stderr. LeakSanitizer's separate capability invocation aborted on
unavailable `/proc` task access; it is **UNAVAILABLE**, not passed. The four
strict ASan/UBSan runs explicitly used `detect_leaks=0` and fatal sanitizer
settings. These receipts remain bound to their original checkpoint.

### Corrected Linux checkpoint

Fresh source `2aca1bb250cde4ff7b0bcc668c2898ac897cfd13`, tree
`ead90c43eb12293c99500cc8d3839a566dce7069`, passes a new Linux build and all
three actual Godot arms. This source is a child of `1caffe16`; it includes the
mask-publication refusal, corrected independent witness and explicit selection
of the authenticated godot-cpp library in the build environment. All 103 build
inputs, dependency bytes, compiler/linker and engine identities remain unchanged
across the execution. The new library is 4,375,952 bytes, SHA-256
`7a76def6d85f3a3187fc8c58ea467797490caada06eb6972b887670be33ce57b`.

| Original matrix class | Reproduced before | Corrected instrumented after |
|---|---:|---|
| Physical and liquid hash boundary | 30 SIGABRT | 30 explicit native refusals; no value/hash fabricated |
| Window enable boundary | 8 SIGABRT | 8 explicit native refusals; state preserved |
| Adhesion authority | 8 disagreements | 8 explicit request refusals; 8 native CYPS witnesses agree |
| Successful controls | 66 | 66 exact returned results preserved |
| Safe export refusals | 10 | 10 exact returned results preserved |
| Total | 122 processes | 122 processes; zero aborts and zero authority disagreements |

The unchanged original-probe arm also executes all 122 cases; it deliberately
labels the 46 repaired outcomes `RETURNED_REQUIRES_STATUS` until the separate
instrumented arm proves the status contract. The extended suite passes all
16 named cases and 3,259 assertions at each of workers 1 and 4, including the
new imported-mask refusals, overlap arbitration and escaped-body controls.

Fresh native GCC execution at this same checkpoint passes nine executables:
the four focused suites both optimized and under strict ASan/UBSan, plus the
unfiltered existing core suite (165/165 tests, including material/policy,
physical-hash/CYPS, quantity and native receipt oracles). The receipt subset has
70 assertions and seven canonical vectors. All nine exits are zero, all stderr
is empty, and all 93 native/test/oracle inputs match their committed bytes before
and after. LeakSanitizer remains unavailable; the original actual capability
failure is retained, not retried or relabelled as a pass. Native manifest SHA-256:
`ec7908c3ed41420fe0e2ba08b25ca07ec7d748649d41815ea4f72283408d5644`.

Local documentation, historical M11, provider/scheduling policy, whitespace,
22 guard adverse tests and 15 policy-contract tests pass. Frozen retrieval is
19/32 at rank 1 and 32/32 at rank 5; supplementary facade retrieval is 3/3 at
rank 1. The earlier supplementary 2/3 rank-1 result remains retained separately;
the added canonical scope qualifiers do not establish unseen answer quality.
Repository/provenance exits 1 for eight old-runtime source mismatches: the four
changed facade files in each retained Linux/Windows runtime manifest. No runtime
pointer or historical provenance is refreshed to suppress those failures.

The new [branch-only hosted workflow](../../.github/workflows/sol-facade-refusal.yml)
requests a pinned Windows cross-build, three actual Windows Godot arms and four
actual MSVC native cases. At this local evidence checkpoint those hosted results
are **NOT RUN**. Publication and any later exact-published-head execution are
separate receipts, reported in the dependent PR and final handoff. The workflow
has read-only repository permissions and no publisher, Ready or merge operation.

The [evidence index](sol-facade-20261104/manifest.json),
[all 122 before/after rows](sol-facade-20261104/before-after.json), and
[complete Linux receipt inventory](sol-facade-20261104/candidate2-manifest.json)
bind the raw packet without committing binaries, caches or log archives.

Example fresh Linux build, with a previously absent output outside the checkout:

```text
python3 tools/sol281/qualify_facade_refusal.py build --source <checkout> --commit <exact-head> --target linux --godot-cpp <authenticated-bindings> --compiler /usr/bin/g++-13 --output <fresh-build>
python3 tools/sol281/qualify_facade_refusal.py matrix --source <checkout> --commit <exact-head> --build-receipt <fresh-build>/build.json --runtime <fresh-build>/libcybersand_native.linux.x86_64.so --godot <pinned-editor> --godot-archive <pinned-archive> --original-matrix <pinned-386-matrix.json> --output <fresh-original-arm>
python3 tools/sol281/qualify_facade_refusal.py matrix --source <checkout> --commit <exact-head> --build-receipt <fresh-build>/build.json --runtime <fresh-build>/libcybersand_native.linux.x86_64.so --godot <pinned-editor> --godot-archive <pinned-archive> --original-matrix <pinned-386-matrix.json> --output <fresh-status-arm> --instrumented
python3 tools/sol281/qualify_facade_refusal.py extended --source <checkout> --commit <exact-head> --build-receipt <fresh-build>/build.json --runtime <fresh-build>/libcybersand_native.linux.x86_64.so --godot <pinned-editor> --godot-archive <pinned-archive> --output <fresh-extended>
```

Fresh candidates use the existing shared generous watchdogs; original 30-second
baseline receipts retain their historical limit. The arm admits each child only
if its full allowance and cleanup/readback reserve fit. Missing/unstarted cases
fail coverage. Source/API/probe/fixture corrections and initial failures remain
separate evidence, never deleted to manufacture success.

Actual Godot Quarantined-phase injection is **NOT RUN**: production exposes no
deterministic route to its internal unexpected-transfer exception. Real failed
World execution and native lifecycle/model tests retain their narrower scopes.
Failed World region selection is intentionally allowed by the existing recovery
contract and does not revive its simulation. No fabricated phase is accepted.

## Frozen guard and retained blockers

The original 27-role checker passes against an exact exported accepted-main
control and still exits 1 on SOL. The repair changes none of the 27 files, the
lock, checker/compiler, catalogue, policy digests or expected hashes. The first
control-export attempt omitted three tool consumers and failed setup; the
complete exported control passes without modifying the checker or its input
authority. Source admission remains an independent failure.

The physical decision remains **NO-GO**: original 84/84 sustained-clearance
failures, 64 depth failures, 36 asynchronous final overlaps, the 120+60-step
criteria and all earlier CPU negatives remain. The 24-group worst-of-three
ceiling remains 2 ms; no facade process result qualifies that complete CPU
matrix. Prior source-archive publication failure at 144,679,823 bytes against
the 128 MiB limit remains failed. No checked-in runtime/provenance is replaced
or relabelled as freshly built by this repair.

## Documentation change map

Canonical behavior and interface additions are in the detachment contract and
interface reference; the handover, roadmap and retrieval routes identify the
isolated dependent scope. Supplementary refusal questions keep every original
frozen question unchanged. Native ownership, physics/capacity policies, ADRs,
player controls and controller scheduling are unaffected; their existing gates
are retained, not silently recertified. Final execution and publication receipts
are added after qualification without overwriting historical evidence.
