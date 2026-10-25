---
title: LCB-001 shared native contract accepted on main
status: Current
document-kind: evidence
scope: PR 246 accepted source/tree, exact-head required gates, executed Windows/Linux runtime identities, preserved failures and remaining application-host ownership; no downstream completion or production-default change
canonical-for: [lcb001-shared-contract-acceptance]
last-reviewed: 2026-10-25
related-documents: [../architecture/liquid-prepared-setup-and-receipts.md, ../architecture/pressure-flow-v1.md, ../architecture/liquid-state-transition-matrix.md, ../architecture/liquid-solver-family-policy.md, ../reference/status-and-roadmap.md, ../reference/validation-evidence.md, 2026-10-24-lcb001-residual-shared-contract.md]
---

# LCB-001 shared native contract accepted on main

## Accepted source and completion boundary

[PR #246](https://github.com/techrote/cybersand/pull/246) merged on
2026-10-25 at 00:33:56 UTC as
`ec58d919b3d904fbd338eaccc25de35782c41a24`. Its final tested head is
`560f9a4143852c5a508b5f33a4a7f2059edbcbdc`; CI actually checked out synthetic
merge `2aa4e456fc7228a68f4d369686fd5eefbbe3a0ef`. All three have tree
`e8e999899bd35bf20df4b03cf9c0620d86089ff1`, verified from Git objects and
independent checkout receipts. The merge therefore accepts that exact tested tree.

**Current on accepted main:** opt-in whole-cell Water `cellular_yield_v1/reference`
(W-CY), its viscosity material block v2 and retained cadence/stochastic liveness;
explicit final-tuple `water-normalize-v1`; immutable prepared candidates;
native-issued refusal/failure values; typed native-v1 run/attempt receipts;
exact Water source/sink and material-population accounting; complete physical
hash **2** and **CYPS2** continuation. Historical CYPS1 explicitly refuses.
PF reference remains opt-in, production defaults and C64-E8 are unchanged, and
historical `content_hash`/`state_hash` definitions are retained. The
[canonical shared contract](../architecture/liquid-prepared-setup-and-receipts.md)
owns the detailed codecs, construction transaction, qualifications and bounds.

**Remaining ownership:** #200 stays open pending ownership reconciliation.
Normal application constructors, Godot typed normalization opt-in, typed host
evidence/provenance and input/session fences, UX and Web integration remain
#202 work. The existing Godot dictionary/string receipt is distinct from the
typed native-v1 encoding. Native-v1 caller source/runtime/host qualifications
remain explicit and full matched-evidence eligibility remains **false**.
#201 cache/dormancy, #212 inertial integration/qualification and #203 packaged
comparison coverage have separate gates; this record does not accept those
streams, generic cell↔Rapier force, a production carrier migration or a global ABI.

## Exact-head required matrix

The ready PR's final matrix executed at the tree above. All four required runs
completed successfully; the independent readers checked raw coverage, logs,
input identities and actual execution rather than relying only on green badges.

| Gate | Hosted run | Executed scope |
|---|---|---|
| Documentation/provenance | [40144712901](https://github.com/techrote/cybersand/actions/runs/40144712901) | Non-draft current provenance and materialized runtime checks; documentation/corpus Git-blob agreement; retained M11 integrity; provider, native policy/setup/receipt, scenario/registry and retrieval gates |
| Native | [40144712872](https://github.com/techrote/cybersand/actions/runs/40144712872) | All **126** ordinary cases, all 126 ASan+UBSan cases and all 126 TSan cases; generation/chunk-admission, physics CLI, soliding/discovery/apparatus, shared-library and benchmark lanes; all eight soliding sanitizer executables actually run; no strict sanitizer findings |
| GDExtension/Godot | [40144712946](https://github.com/techrote/cybersand/actions/runs/40144712946) | **145 Linux + 133 Windows** cases and **five imports**, including **twelve actual X11-rendered Linux cases**; full applicable Windows retained-runtime execution and separate fresh build/ABI lanes |
| Retained #49 apparatus v2 | [40144712913](https://github.com/techrote/cybersand/actions/runs/40144712913) | Sanitized harness, **120/120** registered cases and **60** worker-parity pairs; retained categorical equilibrium outcomes remain as observed, not a new PF or sealed-law calibration |

Native's complete job took **2,148 s (35 min 48 s)**, including compilation and
the additional lanes. Its dense, phased, preallocated shared benchmark ran
120 ticks on a 512×512 region with one worker: mean tick 20.43 ms, zero chunk
and zero temperature-field allocations. This is that registered CI smoke result,
not a general optimization or target-PC performance claim.

The Godot reduction retains **55** physical timing observations (28 Linux,
27 Windows), zero timeouts and zero other failures. These are descriptive
ordinary-gate observations, separate from the #234 stress campaign. Optional
physical-actor stress and Linux serial-equivalence jobs were skipped outside the
required matrix; those skips supply no acceptance evidence. The independent
Windows construction readback records `test_exploratory_actor_selection` passing
in **71.240 s under the unchanged 180 s limit**.

The native/host tests retain configured one/four-worker comparisons and an
actual batch with at least four jobs. That establishes dispatch coverage, not
four distinct worker participants or general parallel speedup.

## Published and executed runtime identities

Scoped publication [40143202793](https://github.com/techrote/cybersand/actions/runs/40143202793)
built source `66506d1aea029d39fcaebb17554f8a58bd6c3a13`, tree
`55b413e6fbbc4bdf6bf5e0c2733dc0c9af2f2468`, and executed import plus the twelve
required target-OS cases on both Windows and Linux, including all sixteen WEX
body-mask cases. The runtime append and later workflow/test-record changes lead to final head `560f9a4…`;
the final receipts verify the immutable native/build/test input sets and the
materialized provenance gate confirms the published source inputs still match.

| Artifact used for actual execution | SHA-256 | Bytes / scope |
|---|---|---|
| Retained Windows CyberSand DLL | `89a20e5bf278eb1801342ff82329667a58e375fb4e141dc6f32116baa4062aaf` | 4,397,568; actual Windows headless suite |
| Linux CyberSand library | `ce62448ceb81add84b9ccbf1e176f21360a99c2ddc21cffe76a1ed85e6244abb` | 3,781,256; actual Linux regression/rendered lanes |
| Selected Windows Rapier backport | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` | Qualified desktop x86_64 dependency, unchanged by #246 |
| Selected Linux Rapier backport | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` | Qualified desktop x86_64 dependency, unchanged by #246 |

The final fresh Windows cross-build is separately identified as
`ff33bd6a70c8749ee3daa60d3d6b126838b0e1e1fec531ab7a768b5927430116`.
It is build evidence; it must not replace the identity of the retained Windows
DLL actually executed above. The existing
[Windows](../../godot/addons/cybersand_native/runtime-provenance.json) and
[Linux](../../godot/addons/cybersand_native/runtime-provenance.linux.json)
manifests retain their original scoped-publication claims; this audit adds the
final matrix without rewriting those manifests.

Pinned tools remain Godot `4.7.stable.official.5b4e0cb0f`, godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`, SCons 4.10.1, Linux GCC 13.3.0 /
binutils 2.42, and Windows LLVM-MinGW 20260826 UCRT / Clang 23.1.0.
The selected Rapier v0.35.2 desktop backport and its locks remain unchanged.
Other platforms/Web, owner feel, full application replay and target-PC/GPU
acceptance do not follow from the matrix.

## Preserved failures and corrections

The [earlier residual audit](2026-10-24-lcb001-residual-shared-contract.md)
retains its original source hashes, local results and publication attempts.
The cancelled first publication at source `9704e993…` is not accepted runtime
proof. Quantity rectangle endpoints, pending-event radius-plus-two coordinates
and non-wrapping gas-ID creation/split/restore now have meaningful regressions;
their failing controls remain outside Git in the retained evidence.

The earlier full Windows run `40140021724` hit the original 180-second
exploratory-construction deadline with a hot native thread. The retained unwind
identified repeated complete quantity-ledger copy/256-slot work in the serial
construction path. The narrow scalar transaction checks every affected field
and lifetime bound before ledger/authority installation, preserving exact gross
rule inputs/products, pair events, no-op semantics and failed-World quarantine;
the full parallel reduction was not weakened. Final hosted construction passes
at 71.240 s. Original failed output and local control/fixed cost receipts remain
in the earlier ledger and acceptance directory; no timeout or test assertion was
relaxed to obtain this result.

## Independent receipt custody

Receipts are retained outside Git under
`C:/Users/_/.codex/tmp/lcb246-acceptance/final3-head/`. The delegated index
completed Docs/Godot/#49 before Native finished; its native-pending field is a
dated boundary, not a contradiction of the later authoritative Native receipt.

| Relative receipt | SHA-256 |
|---|---|
| `root-native-review/native-acceptance.json` | `d6e509f8a04eefecd26f378092e3b06d3e9e13a7301fdecf5bce6c7472b6ca41` |
| `independent-review/owned-final-acceptance-index.json` | `2e110685c731ac38ba5dbcf6e59660d7572baad36f96720245d2a50f33012ce5` |
| `independent-review/docs-independent-acceptance.json` | `43687ee1ff554da9c0e18233c45fe9dfbb350b039c67f26d84fbd44e914c2447` |
| `independent-review/godot-independent-acceptance.json` | `5bca02c28fa4038e6bd6fdeacb901b89173c5158903a70cdc191838b2b7a7cbf` |
| `independent-review/issue49-independent-acceptance.json` | `47c2acfa83909c5f8620874211f9cb5e5e250c2715be4f8f765d89067c54b01c` |
| `independent-review/final-adversarial-review.json` | `5de2c01a9e2ba86504f35345d9d4c7e0ec34b296dff098821000868acaf29b84` |

The final adversarial source review has no unresolved findings in its bounded
scope. It was completed before some gates finished and expressly did not claim
those unfinished results; use the completed receipts above for acceptance.

## Documentation reconciliation and validation

This follow-up changes documentation only from accepted merge `ec58d919` on
`codex/lcb001-accepted-checkpoint`. Canonical setup/receipt, transition, family,
pressure and save/interface/invariant pages now identify accepted main v2;
roadmap/handover, navigation/corpus and supplementary retrieval expectations
route to that scope. Earlier dated audits, frozen results, capability/source
artifacts, runtimes and workflows are not changed. The old heading anchors
remain usable, and #200/#202 ownership is explicit rather than inferred from
the native codec acceptance.

Documentation-checkpoint validation is recorded here after execution; the
runtime gates above are retained #246 evidence, not rerun by this docs change.

Validation used Windows, Python 3.12.10 and Git 2.55.0.windows.5 in a
separate source checkout beneath the read-only materialized companion parent
at commit `6a58311982941b75f46e22109a0829e5acb83c7e`. That parent is not itself
a Git checkout: all five required companion files were checked against the
pinned Git blobs after LF normalization and fenced before/after. All eighteen
required LFS payloads were materialized and checked against their committed
size/SHA-256 identities in the validation checkout. The source worktree's
68 runtime source inputs and two provenance manifests were unchanged.

| Command / scope | Result |
|---|---|
| `python tools/ci/check_docs.py` | PASS: 113 canonical documents, 224 owned claims, 2,771 local links, 333 heading anchors; no errors/warnings |
| `python tools/ci/check_m11_consistency.py` | PASS: 18 retained records, 28 historical source hashes at `05ea45fd`; no historical rewrite or current-runtime reattestation |
| `python tools/ci/check_repository.py --require-materialized` | PASS: source/provenance plus all eighteen materialized runtime identities |
| `python tools/ci/check_ci_provider_policy.py` | PASS; workflow/provider configuration unchanged |
| `python -m unittest discover -s tools/ci -p test_validation_contracts.py` | 14/14 PASS, including the checkers' failure contracts |
| `python -m unittest discover -s tools/ci -p test_ci_provider_policy.py` | 6/6 PASS |
| `python tools/docs/retrieval_eval.py` (frozen 32) | 20/32 top-1, 32/32 top-5, MRR 0.7729; identical to the accepted-merge control |
| Retrieval on the unchanged prior 126 query strings | 98/126 top-1 and 126/126 top-5 in both controls; MRR 0.8710 → 0.8704 because LCB05 moves from rank 3 to 4 |
| Current supplementary 127, including new LCB10 | 99/127 top-1, 127/127 top-5, MRR 0.8714; new LCB10 rank 1, reported separately rather than as retrieval improvement |
| `git diff --check` and source/artifact fences | PASS; documentation-only write set |

The existing frozen question fixture and all prior supplementary query strings
are unchanged. Manual expected-fact review of LCB02/LCB03/LCB04/LCB06/LCB10 checks the
accepted-main v2/native-v1 distinction, exact accepted tree and required gates,
explicit old-format refusal and remaining #200/#202 ownership against the
canonical pages and the receipts above. Lexical ranking alone does not prove
answer correctness. Historical characterization question LCB05 retains its
original source qualification; its small rank decrease is preserved.

Commands, raw JSON/logs, query/control snapshots and before/after input and
companion fences are retained outside Git at
`C:/Users/_/.codex/tmp/lcb246-accepted-docs/`. This documentation validation
neither reruns nor expands the accepted runtime matrix.
