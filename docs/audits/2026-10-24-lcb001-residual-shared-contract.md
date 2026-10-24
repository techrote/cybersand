---
title: LCB-001 residual native shared-contract checkpoint
status: Current
document-kind: evidence
scope: Dated local source and execution evidence for the unmerged residual #200 whole-cell Water, setup normalization, native receipts and quantity-accounting checkpoint; publication and full final-head acceptance remain open
canonical-for: [lcb001-residual-shared-contract-evidence]
last-reviewed: 2026-10-24
related-documents: [../architecture/liquid-prepared-setup-and-receipts.md, ../architecture/liquid-solver-family-policy.md, ../architecture/pressure-flow-v1.md, ../reference/status-and-roadmap.md, 2026-10-24-lcb001-pressure-reference-publication.md]
---

# LCB-001 residual native shared-contract checkpoint

## Source, ownership and completion boundary

The owner requested a handover boundary after completing PR #245 and consolidating
the current residual #200 work. Branch `codex/lcb001-shared-contract` owns this
checkpoint. Its preparation began at pressure source
`349d59359a45ebbe4f92af879945b43b591d412a`. PR #245 subsequently passed all
required exact-head gates and merged at fresh main
`03785c3dcaa5c82df000eeca1471bd6ec698be00`. The prepared successor integrates
that main checkpoint and scoped publisher retirement `446016a8` while preserving
the reviewed native `ffeaabd`, Godot `32c284f` and documentation `386ffded`
commits as reachable recovery points. The successor PR records its final head.

This evidence describes **unmerged source and local execution**, with exact
native input manifests below. It does not declare #200 complete. Source-matched
published Windows/Linux runtimes, full non-draft final-head CI and the remaining
application-host acceptance are required before implementation merge. The
retained pressure runtimes qualify their recorded #245 source, not this native
delta.

No #201 cache/dormancy or #212 inertial implementation is included. The existing
inertial branch and the three uncommitted #202 adapter files were preserved.
The original material worktree was not changed.

## Completed source scope

- Water can explicitly select `cellular_yield_v1/reference` with its own
  material block v2, `viscosity_index` 0–255, default 0. It retains Water's
  chemistry, identity, coherence, thermal state, body contacts and real moved
  quantity. Whole cells contain `maximum()`; no FreeMass fallback is permitted.
- Rare viscosity misses no longer strand mobile Water through ordinary sleep.
  Cadence deadlines are independent of the random yield decision, and bounded
  future wakes retain legal lateral opportunities. Fully blocked pools can sleep.
- Immutable final native tuples support explicit `water-normalize-v1` for
  either comparator arm. A whole-cell partial setup without opt-in refuses.
  Native preparation preserves foreign tuples and nonambient Empty thermal state,
  verifies the actual prepared payload/quantity, and books the declared setup
  source/sink once at tick zero.
- Native-issued outcomes distinguish policy/setup refusal from preparation
  failure and bind either exact raw policy words or a declared normalized
  envelope. Caller-invented reasons cannot manufacture a native outcome.
- The native setup, normalization, run/attempt receipt and quantity-accounting
  schemas use explicit v1 domains and presence rules. Applied receipts and failed
  attempts are separate owned values. Native capture reads the actual admitted
  World, including selected/applied cores and masked stored temperatures.
- The World maintains exact visible/overfill Water and per-material populations.
  Fixed job aggregates book external edits, generation, deferred events, pair
  products and kernel conversions. Conservative transfers do not book sources
  or sinks. Rule aggregates bind the native catalogue; no ordered replay or
  common cross-species mass is claimed.
- Complete physical hashing and CYPS advance to v2 and include accounting.
  Format v1 refuses explicitly. Historical content/state hashes, production
  defaults and the Cell carrier remain unchanged.
- The explicit Godot policy constructor admits full-cell Water, resolves final
  fill overlays, preserves zero-fill no-ops and refuses final partial Water
  transactionally. Godot normalization opt-in remains a native-only integration
  gap. Full normal-application routing and controls remain #202.

The [native contract](../architecture/liquid-prepared-setup-and-receipts.md)
owns the current interfaces and qualifications; the existing
[Water comparison law](../operations/lcb-water-comparison-and-fixtures.md#water-quantity-normalization)
owns the rounding rule.

## Final native execution

Both final builds used the same complete native implementation/test input
manifest, SHA-256
`9b6344ee27e198bd2aadb2c7e8a76cd8c3c56e1cfef5028571cceab374f81b4d`.
Before/after manifests are identical. Both executables use a 1,048,576-byte
stack reserve and 4,096-byte commit.

| Toolchain and flags | Result | Executable SHA-256 |
|---|---|---|
| LLVM-MinGW 20260826 / Clang 23.1.0; C++20, Wall/Wextra/Wpedantic/Wconversion/Wshadow, O1 | 121/121; compile 36.906 s, run 29.453 s | `ff1d66dc9f858bed9619d23ad261d5bef7b5c219c0ae75e4882da8d364097286` |
| MSVC 19.38.33145.0; C++20, EHsc, W4, Od, Zi, STACK:1048576 | 121/121; run 227.657 s | `23bda6d9b30faff08669b492bd86731f1fba16ac658d25b8b1ef937ea6db42dc` |

The identical successful stdout logs hash to
`06fa80f050d9bf59c384aa7c6f27efe867f4c65e197e695dfb0540471400afa3`.
Commands, per-input hashes, compiler output, PE headers and result receipts are
retained locally under
`C:/Users/_/.codex/tmp/lcb200-quantity-prep/final-integrated/` and `msvc/`.
The detailed local `VALIDATION-NOTES.md` hash is
`68233c7133569f1168beb9c9b9e8b89aaab2a3859cedceea4399e8e974daba3a`.
These paths are recoverable machine-local evidence, not committed build output.

The frozen receipt harness passes 63 assertions, or 70 while emitting its seven
vectors. The independent Python struct/hashlib implementation matches all seven
complete native byte strings. Eight independent normalization vectors and the
six integrated native normalization groups also pass; the value module was
checked under MSVC debug RTC1 and optimized W4/WX builds. Neither oracle claims
to independently implement the complete physical-state hash.

## Scoped Windows Godot execution

A fresh scratch extension was built from 767 captured tracked/new inputs, all
unchanged after execution. Their canonical manifest SHA-256 is
`6e35f6f78f8ceac6d4d237adadb5dbbacc833f8f19e3664fd6296fd9dd8e90ed`.
The 4,397,056-byte DLL hashes to
`e6b954366c11316c545e41d8198d6d0920e04774747b9d32742e94ce6ee7d718`.
It was staged only in the scratch project; retained release runtimes were not
overwritten or reattested.

Tools were Godot `4.7.stable.official.5b4e0cb0f`, LLVM-MinGW 20260826 /
Clang 23.1.0, SCons 4.10.1, fresh pinned godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496` and Rapier2D 0.35.2 (runtime
SHA-256 `4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180`).
The extension used C++20/O3/NDEBUG, static runtime, shared pthreads and
`lto=none`; compilation/linking took 48.765 seconds with empty diagnostics.

| Gate | Result | Timeout |
|---|---|---:|
| Clean headless editor import | PASS, both extensions loaded | 180 s |
| `test_liquid_solver_policy.gd` | 385 assertions, 0 failures | 360 s |
| `test_lcb_pressure_reference.gd` | 1,934 assertions, 0 failures, 12 sections | 900 s |
| `test_liquid_policy_worker.gd` | 29 assertions, 0 failures | 360 s |
| `test_microscenario_native_observation.gd` | 100 assertions, 0 failures | 240 s |
| `test_wex001_water_body_baseline.gd` | 16 cases PASS | 600 s |

Each script ran with the official console executable, `--headless --path
C:/Users/_/.codex/tmp/lcb200-godot-proof/project --script res://tests/<test>.gd`.
Import used `--editor --import --quit`. No engine ERROR, SCRIPT ERROR or WARNING
lines were captured. WEX ran for 99.484 seconds, with forbidden Water peak 0,
hard floor penetration 0.000366210953416157, moderate penetration
0.00229022219258468 and mirrored peak-above counts 7395/7395. These are the
existing fixture's characterization checks, not pressure-to-body force evidence.

The detailed local report is
`C:/Users/_/.codex/tmp/lcb200-godot-proof/REPORT.md`, SHA-256
`1b12ba6729cbbc983b47dfc2be977ad2124324e1bc338fa9d3d497c1c93163bd`.
Its receipts retain exact argv, UTC times, elapsed times, timeout/exit values,
log hashes, tool identities, source snapshot and artifact.

Two preparation failures remain recorded there: an initial check-only launch
loaded LFS pointers (Error 193), whose zero exit was rejected as runtime proof;
and an external archiver wrapper exceeded Windows command length. Restoring
upstream's existing argument splitter by dropping the wrapper executable suffix
completed the archive without dependency or toolchain source changes.

### Current-registry follow-up

After regenerating the current W-CY capability metadata, four directly affected
LCB cases ran in a fresh separate project at clean source checkpoint
`386ffded5699a5dedb7f502e5b16cc568831f547`: negative contracts **74/0**,
catalogue **774/0** across 27 scenarios, protected fixtures **26/0** and physics
contracts **174/0** (1,048 assertions, zero failures). Clean import and every
process exited zero without captured engine errors or warnings. The campaign
arm statuses/measurements remain unchanged; admission is not campaign acceptance.

All 73 native/build/adapter inputs match the same sealed DLL build. The fresh
stage copied 557 tracked Godot files and the regenerated registry; input fences,
runtime bytes and the original sealed evidence were unchanged. Report:
`C:/Users/_/.codex/tmp/lcb200-godot-registry-proof-70bf/REPORT.md`, SHA-256
`787302dbc4167507becabccdb0d151386c755804ed884713a0ad9b5c11924cb7`;
19-file manifest SHA-256
`f50cd84420628c9be6fce53db6b469bbf143fc8e8dd873b1c81bb75a4dfc7e17`.
The directory retains its initially requested `70bf` label; the receipt binds
actual `386ffded` and preserves the initial revision-guard stop.

## Preserved failures and adversarial review

- W-CY viscosity 255 reproduced sleep starvation against an always-awake
  control. Regressions cover workers 1/4, cadence 1/17, horizontal sampling 1/2,
  legal future motion, blocked rest and body probes.
- Down-rounding could hide a Water coherence lane invalid under the selected
  policy. Original tuples now validate before normalization. Unsupported
  backends refuse before a prepared candidate is admitted.
- Equal normalized after-payloads could be paired with different before masses
  and deltas. Receipt binding now checks the actual construction seed, including
  the original payload, exact counters and normalization digest; omission and
  substitution refuse.
- External counter overflow could allocate an absent chunk before refusing.
  Accounting preflight now precedes allocation. Tests require unchanged chunk
  count, complete physical hash and ledger. Worker overflow retains the existing
  failed-World quarantine contract.
- Rehashed CYPS2 payloads could claim impossible source/kind roles or a prepared
  Water population inconsistent with its initial quantity. Role/quantum and
  population checks reject those cases. Structural consistency and a digest do
  not authenticate arbitrary edited lifetime history.
- MSVC debug execution initially exhausted its ordinary 1 MiB stack in pressure
  restore. `WorldConfig` is 39,856 bytes and `World` 46,288 bytes in the measured
  build. Passing restore configuration by const reference and heap-owning its
  preparation copy removes avoidable large stack layers without tick allocation,
  stack-limit increases or continuation changes. The failing binary/log and final
  passing reruns are retained. An earlier oversized default-behavior test was
  independently moved to heap-owned fixtures with its assertions preserved.

Independent reviews found no remaining actionable issue in the bounded
FM/PF/W-CY native mutation, normalization, outcome, receipt, accounting and
continuation scope. The checks do not constitute full application acceptance.

## Resource cost and remaining acceptance

Fixed accounting adds 3,816 bytes per scheduling slot: 15,630,336 bytes
(about 14.91 MiB) at the default 4,096 slots, plus a 6,088-byte World snapshot
and a 208-byte construction seed. This is an explicit cost, not an optimization.
No new tick-time allocation, per-cell lock or per-material thread is introduced.

Remaining acceptance includes source-matched release runtime publication on both
platforms, full non-draft final-head CI and actual host collection/verification.
The native v1 receipt does not upgrade source/runtime caller claims to verified
provenance or controlled/matched evidence. Its native-only coverage and host
gaps remain explicit; the existing experimental Godot dictionary getter is a
different contract.

**Downstream #201 requirement:** stationary Water's failed motion probes can
report body contacts. A rest certificate must preserve those reports, mandatory
material stages and other-liquid work; initial certificates should decline body
and swept-body neighborhoods unless exact equivalence is established. Zero
rounded flux is not proof that retained flow is at rest. This checkpoint
implements no certificate or cache.

The retained #212 contract generator currently says a static closed pool keeps
its physical hash constant across ticks. That conflicts with the complete
continuation hash's tick/scheduler coverage. Before #212 qualification, register
an explicit tuple/velocity/accumulator rest projection while retaining exact
complete-hash parity at the same completed tick across workers. This checkpoint
records the contradiction and leaves the historical contract fixtures intact;
it neither weakens the complete hash nor qualifies the old inertial branch.

Recommended order is to finish residual #200 acceptance and shared host seams,
then fan out #201/#202/#212 where write sets permit, and finally complete #203.

## Documentation and identity change map

| Changed claim | Canonical home and checkpoint disposition |
|---|---|
| W-CY policy, Water block v2 and material hooks | `liquid-solver-family-policy.md`; derived capability/wire/native identity and current scenario registry regenerated; historical control ledgers unchanged |
| Final setup, authority/lifetime, refusals, normalization and receipts | `liquid-prepared-setup-and-receipts.md`; immutable owned values and exclusive native capture; host collection/provenance still qualified |
| Lifecycle and quantity continuation | `liquid-state-transition-matrix.md`, `pressure-flow-v1.md`, interfaces, invariants and save/replay references; physical hash/CYPS2 refusal is explicit |
| Precision, bounds and fixed memory | Configuration reference and native contract; no new tick allocation or changed Cell carrier |
| Execution order, source/runtime evidence and recovery | Roadmap, development handover, this audit and focused successor PR; #200 remains open |
| Retrieval | Documentation index, retrieval index/corpus and independent challenge questions updated together; frozen question wording preserved |
| Build/tests and controls | Make/MSVC test sources plus documentation CI oracle checks; existing explicit Godot policy constructor only, no new full-app UX |
| Architecture decisions | Native authority, worker ownership and current Cell/Rapier boundaries remain as approved; no new global ABI, replay or representation decision |

## Documentation validation checkpoint

The pinned companion layout at
`C:/Users/_/.codex/tmp/lcb245-validation/workspace/source200` was advanced to
`32c284f576c103cb831cf4c187042802d388d744` (native contracts `ffeaabd` and
controlled Godot constructor `32c284f`), then received the exact 20 uncommitted
documentation/CI files. All input fences were unchanged during validation.

- `python tools/ci/check_docs.py`: 112 documents, 220 claims, zero errors or
  warnings.
- `python tools/ci/check_m11_consistency.py`: 18 retained records and 28
  historical source hashes pass.
- CI-provider checker and `git diff --check`: pass.
- Frozen retrieval: 32/32 top five, 20 top one, MRR 0.7781. Supplementary
  challenges: 125/125 top five, 97 top one, MRR 0.8713. The four new independent
  questions rank 2/1/2/2. Prior query wording is preserved; expectation
  corrections are disclosed in the challenge metadata. These are lexical route
  scores; source review supplies the status/platform qualifications.
- `python tools/ci/check_repository.py --require-materialized`: all 18 runtime
  payloads materialized; the only failures are the expected 20 stale recorded
  source-input mismatches (the same ten changed paths in each Linux/Windows
  manifest). No runtime was reattested to hide this publication requirement.
- Python LCB suite: 120/120; both new oracles, source-derived capability/policy/
  native artifacts/current registry, all retained reledgers and six physics
  contract fixtures pass.

Full commands, mismatch paths, copied-file hashes, source fences and log hashes
are retained in
`C:/Users/_/.codex/tmp/lcb245-validation/final200/validation-receipt.json` and
`sync-manifest.json`. This result precedes the evidence-only addition of this
section and the final fresh-main integration; the focused successor PR records its
final committed-head checks.

The live #201 mirror records the body-contact/rest-certificate requirement.
Historical failed publications, #245 screens, old hashes and M11 records remain
unchanged. Final documentation/retrieval results and recoverable Git heads are
recorded with the successor checkpoint after refreshing main.
