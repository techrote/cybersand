---
title: IN-TOOLS 361 source and implementation-admission review
status: Current
document-kind: evidence
scope: Dated documentation and test-only source review, Linux native primitive evidence, proposed-command adversaries and bounded implementation handover; no production gameplay completion
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../architecture/in-tools-gameplay-admission.md, ../operations/in-tools-fixtures-and-playtest.md, 2026-11-03-lcb-reassessment.md, ../systems/actor-usables.md]
---

# IN-TOOLS 361 source and implementation-admission review

## Disposition

**Preparation/admission package only.** Recommend the existing physical Liquid
Drain as the first narrow opt-in implementation, with exact Water/Brine
metering and existing actor ownership. A registered resident reversible port
can follow through the current owner with complete preflight and fault handling.
Geometry-directed sources can use fresh whole-cell edits and finite supply.
Native momentum input and stronger atomic native command receipts need separate
authorization; upward launch stays #362. Keep #361 open and this PR draft.

The [architecture](../architecture/in-tools-gameplay-admission.md) is the
implementation contract; the [runbook](../operations/in-tools-fixtures-and-playtest.md)
contains reproducible commands and the future host/playtest matrix. The new
host fixture manifest is explicitly Planned. No production World, adapter,
native law, Godot script, #370 recorder, default, runtime, CI workflow or old
fixture is changed by this candidate.

## Inspected source and ownership

| Input | Live/source identity at inspection |
|---|---|
| Accepted main | `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1` |
| Main tree | `36ce5a01e754a141c321f41cac7f1c6b6059c371` |
| New branch | `docs/in-tools-361-admission-20261104`, isolated worktree |
| #359 prerequisite | #367 merged; current-main reassessment consumed |
| #370 comparison | Unmerged draft `fbe82bcab8f821aac442c2bf59eb57b279717873` |
| #358 materials | Unmerged draft `7383946a3ed384966e9e5fb72553fc267f9aacb7`; no imported IDs/carriers |
| #347 structural/contact | Open implementation; #364 contact recovery remains separate ownership |
| #201 / #362 | Pressure optimization / impact and upward-spray research remain separate |

Read root AGENTS, handover, README/index/roadmap, native policy/IN/prepared
contracts, actor-usables and current source. No descendant AGENTS was present.
The two requested #370 documents are not on accepted main; they were inspected
at the pinned PR object, with their historical claims kept source-bound.

The new plan locks 25 current-source files and nine comparison inputs. Its
byte-equality checker is explicitly narrower than complete runtime qualification.
The native runner separately seals all 56 compiled source/header/include/test
inputs before and after execution, plus compiler, executable and runner identity.
Uncommitted test additions are identified by their hashes; base commit/tree
alone does not identify the test executable.

## Independent findings and corrections

Three independent source lanes covered native contracts, application ownership
and #370 comparison reuse. Cross-review then exercised the new validator and
native result wrapper. Findings were repaired in test/doc scope:

- Raw setters can replace Wall/liquid. Nonempty writes reject native masks,
  but Empty erasure can remove stored material beneath a mask. Every proposed
  tool therefore checks selected material, port ownership, mask and domain.
- Same-material raw paint can retire IN motion without changing quantity.
  Fresh source targets must be Empty; no paint-as-acceleration shortcut.
- Legacy rectangle helpers are not atomic. External-edit exceptions may not
  set native `has_failed`; the proposed application owner must become terminal
  on an unexpected edit fault, even while the native health flag stays clear.
- Physical U10 confirms material changes; sampled counters are optimistic.
  Both count slots, so fractional FM removal needs actual native quantities.
  Fixed successful U10 activation cost is 0.85; power does not scale that cost.
- #370 bottom drains are internal openings, not removal sinks. Schema 2 cannot
  restore Wall or schedule Brine fill. Captures account scheduled edits only.
- Brine's baseline is CY. #370's Water-centric IN completeness flag is not proof
  of complete Brine coverage. Synthetic new-ID tests do not qualify #358 union.
- The first proposed-receipt checker accepted contradictory local/full-World
  quantities, impossible non-source motion and an overlarge command schedule.
  It now checks those contradictions, all copied motion bounds, real family/radius
  admission, native construction identity and explicit owner-ledger units.
- The first native wrapper trusted root `status`/schema without a complete case
  census, and malformed root values could leave an old report. Its bounded repair
  validates complete case structure and writes a nonpass record on malformed
  results. Adversarial parser tests are separate from simulation evidence.

No review grants ordinary gameplay, physical-device or human-feel acceptance.
The first reviewer reports are retained in the working evidence; this record
summarizes their concrete findings and resolutions without claiming an external
human PR approval.

## Actual native evidence

The final repaired-wrapper Linux GCC 13.3 run passed 8,761,999 assertions.
It uses unchanged native simulation sources with one new standalone C++ test.
Sixteen flow comparisons represent 32 native runs: Water FM/IN and Brine CY/IN,
widths 1/4, leak/drain, workers 1/4, 224 ticks each. All paired physical-state hash
traces agree, and every configured-four arm observed four claimants in this run.
Native phase jobs are recorded. The repeated cell-level assertions are not
8.7 million independent scenarios.

Each arm starts with eight reservoirs, 1,296 full selected-liquid cells: 330,480
Water units at 8 bits, or 1,296 Brine cells. All leak arms retain their full
quantity in the complete reservoir+sump system. Floors/side-wall positions and
adjacent outside bands remain intact. Separate native body-mask barrier controls
run 64 ticks per material/family, without Rapier.

| Actual explicit drain arm, 224 ticks | Width | Removed | Remaining |
|---|---:|---:|---:|
| Water / FreeMass | 1 | 321,961 units | 8,519 units |
| Water / FreeMass | 4 | 325,167 units | 5,313 units |
| Water / IN | 1 | 163,200 units | 167,280 units |
| Water / IN | 4 | 216,240 units | 114,240 units |
| Brine / CY | 1 | 1,271 cells | 25 cells |
| Brine / CY | 4 | 1,295 cells | 1 cell |
| Brine / IN | 1 | 640 cells | 656 cells |
| Brine / IN | 4 | 848 cells | 448 cells |

These are actual bounded outcomes, not a preferred solver or complete tank
exhaustion. A separate immediate second intake removal proves zero additional
removal and unchanged state after the selected targets are empty.

For IN leak arms, width 1 admitted closure at loop index 24; width 4 at 100 after 76
occupied-target refusals. Source schedules reopening eight ticks after actual closure; the test checks the
edit and continued state, but emits no separate observed reopen receipt.
FM Water closed at 185/97 for widths 1/4; CY Brine at 178/83. The test waits for
all registered cells to become Empty; it does not overwrite liquid to force
closure. These eight-tank operations are test composition, not a production
16-cell command or Rapier-safe terrain insertion proof.

Other controls verify full Water quanta 7/255, exact normalization gross counters,
fractional and invalid material/radius refusal, an actual capacity exception,
failed-tick quarantine, zero-motion repaint behavior, guarded native-mask
refusal and physical save/restore plus eight continuation ticks. Three fresh
setup pairs per arm reproduce their initial native physical identity. Host
masks, bodies, equipment, queues and native diagnostic-ledger parity are not
established by those physical hashes.

The `first_flow_tick` observation means first interior-reservoir census decrease,
not downstream crossing flux or shutdown-tail duration. A future flux observer
or precisely labelled control-volume proxy is still required. Source-motion
and negative-vy limits come from actual primitive tests and source review; no
successful diagnostic velocity injection seeds these fixtures.

### Memory and timing interpretation

The native fixture reserves 24 chunks of 128²: 393,216 resident cells. IN slot
capacity is 2,359,296 bytes at six bytes/cell. Reported IN components total 2,982,945
bytes, compared with 623,073 for its no-IN control: a marginal 2,359,872 bytes,
including vector-owner objects. Resident cell storage separately reports
3,151,872 bytes. Allocator overhead, shared resources and process RSS are not
included by this native component census.

Instrumented run time includes full-state hashing, whole fixture scans,
serialization and millions of assertions. It is not a native-kernel performance
comparison, host pacing result, GPU FPS measure or worker speedup claim.

### Retained development history

| Attempt | Status and interpretation | Report SHA-256 |
|---|---|---|
| Initial test compile | Wrong test accessor `.hash` corrected to `.policy_hash()`; transcript-reported development error; raw failing stderr unavailable | Not invented |
| First development run | Pass 4,341,483 checks, but C++ changed during compilation; not source-qualified | `1284e77ea45c012629140650877c0796466ba1ee8003b4a3a5c2c768ecb2b742` |
| First final-source run | Pass 8,761,999; manually checked inputs, older wrapper without before/after custody | `4a9c8de4ea59aae733e9b983a32e1fc831fc848ed345e30dddff1871c07de73e` |
| First custody-qualified run | Pass 8,761,999; both input/runner guards true; later parser repair is a separate test-tool change | `2fac3364bfd7d62c7b110b2e0984e2e5d954604aafe4af0764adb1ec2f61a09f` |

The last two used native binary SHA-256
`8df32444330080d81ea4a4fa9a3d0a2ce553f28a81a137ae59f932bacd404ed3`.
No retained native execution had an assertion failure or timeout. Successful
empty stderr files do not preserve the earlier development compile error.
The final repaired-wrapper execution and check summary are appended below.

### Final repaired-wrapper execution

The exact [native qualification packet](in-tools-361-2026-11-04/native-qualification.json)
records **pass**, compile/run exit 0, and unchanged source, runner, compiler and
executable identities. UTC interval: **2026-11-04 10:24:08.017012Z–10:26:12.383964Z**.
Compilation took 27.981 s; the instrumented executable took 96.332 s, with
600 s compile/run limits. This repeats the same 8,761,999 assertions and 16 flow
pairs after the result-validator repair. It is not a performance benchmark.

| Identity | SHA-256 |
|---|---|
| Exact qualification JSON bytes | `8e4bc9932c06b30c89c01d7f107d739c6db26fb9bae8060201fe82ab77d2a276` |
| Standalone native executable | `8df32444330080d81ea4a4fa9a3d0a2ce553f28a81a137ae59f932bacd404ed3` |
| Native test source | `f743a2c8beef02caa40b44c4803511c4822cccc3bd3fea77f82e06776dfcbb3c` |
| Repaired runner | `926512fe3f85d27cebb1c8839502103b6ef1a364816132c63ba98b7f169383a4` |
| Native stdout | `f7150fae674c74b8ef3669861d9bda18d3e33df8a876a1c6208a980448b94b58` |

The packet embeds the parsed native results and all 56 input hashes. Raw local
stdout was independently matched to both its digest and the embedded object;
all recorded current-file hashes were rechecked. The base Git commit identifies
production source; the additional test/runner hashes identify this precommit
executable. Runtime binaries, build output and raw logs are not committed.

## Current validation and recoverable handover

The final source-custody packet and [local check summary](in-tools-361-2026-11-04/local-checks.json) accompany this record.
Documentation, repository/LFS provenance, retained M11, existing capability/
policy/normalization/receipt checks, focused Python tests and retrieval are
separate gates; none substitute for actual desktop execution. The draft PR
ledger records the resulting commit and hosted check status.

The first documentation check found absent companion-workspace reference files.
Five exact existing companion files were copied to their required sibling
locations; no repository content or historical expected hash was weakened.
Current runtime provenance checks use all 18 unchanged, SHA-256/size-verified
LFS payloads. Those are artifact identity checks, not execution of the packaged
Windows/Linux libraries. Frozen 32 and existing 157 query objects are unchanged;
six new #361 questions are evaluated separately, with rank shifts disclosed.

### Check and retrieval disposition

The focused Python suite has **49 passing tests**: 32 proposal/copy-consistency
checks and 17 native-runner parser/custody adversaries. Run separately with:

```sh
python3 -m unittest discover -s tools/lcb -p test_in_tools_contract.py -v
python3 -m unittest discover -s tools/lcb -p test_in_tools_native_runner.py -v
```

These do not authenticate a native gameplay receipt. The six fixture plans,
25 current-source pins and nine pinned comparison inputs pass the plan/source
checker. Current documentation/repository provenance, retained M11 integrity,
existing policy tests, capability derivation, policy artifacts, construction
receipt vectors, normalization vectors and scenario catalogue checks passed.
The structured summary records commands, source identities and output digests.

| Unchanged query registration | Before: top 1 / top 5 / MRR@5 | After: top 1 / top 5 / MRR@5 |
|---|---|---|
| Frozen 32 | 19 / 32 / 0.7536 | 19 / 32 / 0.7536 |
| Existing 157 challenges | 124 / 156 / 0.8734 | 123 / 155 / 0.8678 |
| New six #361 questions | No pre-existing registration | 2 / 6 / 0.5972 |

The existing challenge regression is disclosed: ACT14 moved rank 1→2, LCB08
moved 2→3, and USABLE02 moved 5→outside top five; its expected canonical document
was displaced by the new Planned usable material. Existing LCB03 remains a miss.
No old query, expected canonical, evaluator, stemming or ranking rule changed.
This is a lexical development baseline, not a proof of answer correctness.

The new six initially had five top-five hits. Adding the meaningful **Matched
FreeMass and inertial comparison** heading brought that to six; question wording
stayed fixed. Independent expected-fact review found the source/normalization,
valve/sink, nozzle, ordinary usable, ownership and comparator qualifications
present in the linked canonical documents. The final bounded review found no
remaining documentation/fixture contradiction. That is automated-agent source
review, not human gameplay approval.

## Stop boundary and next implementation agent

Build only the opt-in application metering slice first. Recheck live main/#370
and actor/PLAY ownership; preserve this plan's original source pins as evidence.
Reuse physical U10, native copied observations and construction identity, exact
Water/Brine units and existing cancellation/fresh-owner fences. Qualify actual
partial-FM, IN Water and Brine sinks, no-effect/blocked/empty/stale outcomes and
unchanged ordinary controls before adding a registered resident valve.

The valve must use Empty-only closure, current masks and an owner-local complete
preflight, with explicit terminal handling of unexpected partial execution.
A source uses finite actual supply and zero fresh motion. If required readback,
atomicity or momentum cannot be supplied by those existing contracts, stop at
the source-localized native proposal rather than mutate tuples or weaken owner
authority. Obtain separate authorization before native/adapter/shared coupling
changes. Do not merge automatically or declare the full #361 feature complete.
