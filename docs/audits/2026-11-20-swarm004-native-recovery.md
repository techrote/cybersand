---
title: SWARM-004 native recovery, causal controls and policy freeze
status: Current
document-kind: audit
scope: Dated recovery of V1 source and known corpus, independent causal controls, reporting repair and pre-holdout selection; no final-source or Windows acceptance
last-reviewed: 2026-11-20
related-documents: [../systems/gentek-reciprocal-assembly.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md]
---

# SWARM-004 native recovery, causal controls and policy freeze

**Disposition: the interrupted native V1 implementation and its known-seed research campaign are recovered and independently reproducible. Select `fixed_territory`, two rounds, and freeze its source inputs before holdouts. This dated recovery record does not establish final-source, Windows/Workbench or whole-programme acceptance. Preserve Draft/HOLD.**

Evidence audit date: 20 November 2026. Source under review: `7fa0911e7ec3d0f2d52ecde7b538c55514d5d54d`, tree `fe59bdce3604580868138ec442002441a507ff52`. Research parent: `cd0de74b83a66b5408668f81c82d854db45479ce`. This audit does not adopt the separate articulation V2 branch or open holdout seeds.

## Recovery and source custody

The original workspace at `/workspace/scratch/9a0933ad6744` contains the native branch, a separate experimental Workbench branch, source snapshots, Linux and cross-built Windows binaries, raw corpus records, build/test logs and independent Workbench probes. These are actual files and Git commits, not merely conversation claims.

All 56 native source-input hashes and 64 complete harness/donor hashes in the retained native manifest matched the recovered V1 tree during this audit. All 16 completed command-log hashes matched their recorded values in the final receipt, including the campaign and gallery commands. The known-seed campaign was still running when the audit started; it completed at 21:54:54 UTC. Its complete `campaign.json` contains 2,174 records: 1,404 registered native policy cases, historical controls and conditional matched-final-FRAME controls. Records may share a raw historical control file. All 1,958 compressed raw artifact files, totaling 283,986,723 bytes, matched `storage.json` checksums. The independent candidate audit also decompressed and verified all 1,404 native policy records against their raw hashes.

The outer qualification manifest initially remained `RUNNING` while the gallery continued. It sealed **PASS at 2026-11-20T22:01:27.369345+00:00**, with `source_custody_revalidated=true`, all 16 commands passing and 7,172 inventoried artifacts. Its SHA-256 is `d687ed89900f03cdd46b926f5ee1c2f21cd9fde1cb5bb82c612e2b4b80999c78`. The independent final-runner receipt verifies all command-log hashes. The original gallery audit passed its own checks; the independent review below still identified reporting and causal-interpretation defects that that gallery did not detect.

The surviving Workbench checkpoint is `cc471d6362b49cc4b6cbedfc61c888234e7e629e`. Its manifest's recorded artifacts all matched. Of 728 recorded source inputs, only `.github/workflows/swarm004-workbench-windows.yml` had changed since that checkpoint manifest. Its source/Windows claims therefore need the final integration identity, not an assumption that an old clean manifest still describes the current worktree.

## Independently reproduced native execution

The auditor exported V1 directly with `git archive`, built it in a separate source/build tree and ran the retained focused suites. The result did not depend on the old build directory.

| Fresh execution | Result |
| --- | --- |
| Assembly suite | PASS, 99,729 checks |
| MOSAIC reciprocal suite | PASS, 8 tests and 274,661 checks |
| Reciprocal suite | PASS, 219,547 checks; its scoped fixture output reports three both-revision examples and nine joints, with zero complete examples in that particular suite |
| `island / branching_irregular / 4099 / reciprocal_2 / rounds=2`, first run | Complete; four native joints; six foreign requirements explicitly joined; Apply authorized |
| Same exact case, second run | Byte-identical to the first run |
| Fresh result versus original campaign raw case | Byte-identical |

Fresh CLI SHA-256: `b4fcf31527c913c7f6b1125aa935189f4c8d5f126341e2552a0b63bc6a78e79f`. Reproduced case SHA-256: `883a74f34a08492091f2719f3eb639cb7ea0c6685f6f7b7c5a13ab1a8d6ad6ba`.

In this real positive example, MOSAIC changes 652 occupied/empty cells in round one and FRAME changes ten in round two. The independent native reviewer additionally confirms a 16-cell MOSAIC occupied-footprint effect when its incoming offers are removed under matched round-one conditions. The four joints have cardinal facing, exact adjacent foreign faces, distinct receptors and contiguous native material paths. This is a valid bounded reciprocal example. It does not establish physical stability or broad success across the corpus.

`independent-v1-reproduction.json` retains commands, timings, stdout, identities and comparisons. `audit_v1_corpus.py` is a separate checker that does not import the implementation's gallery/reporting code. Its completed audit checked all registered cases, array-derived footprint changes, native joint witnesses, original required obligations, Apply semantics and the registered work ceilings. Additional checks validated every accepted final material plane against its owning proposals/context, protected-space preservation and solid-material joint paths: 946,458 checks across the 44 applicable policy-case outputs. These 44 outputs are not 44 distinct seeds/worlds; policies share fixtures.

The auditor's first pass incorrectly treated an absent final `both_genteks_revised` metric as an explicit false claim for 34 early exhausted outputs. The original checker and report are retained. Each affected raw record was re-read, confirmed to have no final composition or Apply authorization, and the auditor was corrected to validate the metric only when emitted. No implementation or raw research record was changed to obtain the final independent audit PASS.

## Known-seed outcome and reporting correction

Every registered policy has the same 108 cases: six fixtures × three profiles × six development seeds, with no missing or duplicate cases. The independent audit confirms zero Apply authorization for incomplete or validator-disabled results, no deleted original required obligation in an accepted result and no observed registered work-ceiling violation.

| Policy | Complete/Apply | Blocked | UNSAT | Exhausted | Nominal both-footprint revisions with native joints | Applicable nominal both-revision cases |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| No negotiation | 2 | 83 | 23 | 0 | 0 | 0 |
| Legacy vocabulary | 2 | 76 | 30 | 0 | 0 | 0 |
| Vocabulary only | 2 | 76 | 30 | 0 | 0 | 0 |
| Flat assembly | 5 | 55 | 23 | 25 | 0 | 0 |
| Fixed territory | 9 | 51 | 30 | 18 | 46 | 9 |
| MOSAIC only | 5 | 55 | 23 | 25 | 0 | 0 |
| FRAME only | 2 | 83 | 23 | 0 | 0 | 0 |
| Reciprocal, one round | 5 | 55 | 23 | 25 | 0 | 0 |
| Reciprocal, two rounds | 5 | 55 | 23 | 25 | 12 | 4 |
| Reciprocal, three rounds | 1 | 47 | 23 | 37 | 0 | 0 |
| Reciprocal, four rounds | 1 | 47 | 23 | 37 | 0 | 0 |
| Native bearing off | 5 | 57 | 23 | 23 | 14 | 4 |
| Validation off diagnostic | 0 | 60 | 23 | 25 | 0 | 0 |

There is a real V1 reporting defect: its campaign index defaults `closure_evaluated=true` even for some early outputs with no final cell plane and no `still_required` metric. The generic metric lookup then prints zero. Across the 1,404 native cases, **560 have no evaluated final closure**. Those are unknown/refused closure outcomes, not successful zero-obligation worlds. They remain UNSAT or exhausted, cannot Apply and are retained in all denominators. The independent report fixes the interpretation without rewriting the original evidence.

For fixed territory, final closure is evaluated in 60 cases and unavailable in 48. The evaluated cases contain 136 still-required obligations in total. For two-round shared territory, the corresponding values are 60 evaluated, 48 unavailable and 147 still-required. These sums are conditional on evaluated closure; never compare them as if each policy had successfully evaluated every case. The recovery reporting fix now emits this availability distinction in the campaign index, CSV/comparison records, summary and gallery; a mismatch between the index and native ledger fails the audit. It changes reporting only, without changing any generator, grammar, coordinator decision or final authorization.

All policies retained the 2M FRAME, 2M MOSAIC, 4M categorical, 2M shared and 10M aggregate work ceilings, 16MiB admitted memory envelope, 64 FRAME instances, 192 MOSAIC instances and eight transition reservations. Median total charged work is 5,507,586 for fixed territory and 5,683,557.5 for two-round shared territory. Historical controls have different receipt semantics and must not be presented as directly comparable candidate totals without that qualification.

## Causal control and selection rationale

Changed occupied footprints alone do not prove that exchanged offers caused the change. The independent native reviewer found that masks preserved from an earlier proposal can cause MOSAIC to change even when the offers are removed. The stronger control replays round one with the same peer material, preserved protection, shared mask and remaining allowance, but no offered slots.

The independent native reviewer then regenerated all 1,404 known cases across all 13 policies and applied this control to all 84 compositions reporting both revisions. A second control freezes the initial MOSAIC proposal through the full same-policy coordinator, verifies that the initial pair is unchanged and checks whether FRAME's final footprint differs. All 84 FRAME comparisons have a nonzero footprint effect. All no-offer MOSAIC controls completed; 36 show no occupied-footprint effect from offers and must not be described as reciprocal causal successes.

The evidence auditor read the full harness and independently recomputed the 84-row summary from its log, matched every Apply/joint count to the original corpus, verified driver/binary/log hashes and verified that all 14 linked native object hashes exactly match the auditor's separate fresh V1 build. The full audit, source, binary, log and manifest are copied into `causal-full-custody/`. This full audit supersedes an initial 58-case discovery probe whose driver and binary were overwritten when the reviewer extended the harness; the original discovery log and its recorded hashes are retained, but final claims use the complete, preserved audit.

| Known-case measure | Fixed territory | Two-round shared territory |
| --- | ---: | ---: |
| Both footprints revised, with valid native joints | 46 | 12 |
| Such cases passing both the matched MOSAIC offer control and the frozen-peer FRAME control | 28 | 6 |
| Fully closed/Apply-valid nominal both-revision cases | 9 | 4 |
| Fully closed/Apply-valid cases also passing both causal controls | 6 | 2 |
| Nominal both-revision cases with no occupied-footprint offer effect | 18 | 6 |

Use the precise label **both native footprints respond under matched counterfactual controls**. This test is stronger than observing two changed arrays, but is not a general proof of architectural intelligence, physical support or all possible bidirectional counterfactuals. A material-only repaint is not a footprint effect. The `native_bearing_off` ablation has eight such causal cases, including two that are fully closed and applicable. The validator-disabled diagnostic has six causal footprint examples but no qualified joints and no Apply authorization. All remaining policies have zero qualifying both-direction causal cases in this comparison.

**Select `fixed_territory`, two rounds, for the frozen V1 research comparison and experimental authoring default.** This follows the preregistered first criterion. It wins 46 versus 12 on the originally recorded fixed/shared measure, and 28 versus six after both-direction causal controls. Its next strongest causal competitor, `native_bearing_off`, has eight qualifying cases. Selection therefore does not depend on speculative extrapolation of untested causal counts, on treating absent closure as zero, or on post-hoc per-case policy picking.

The initial `reciprocal_2` shared-territory hypothesis is **not supported as the strongest policy**. Its two applicable offer-causal examples remain useful experimental evidence; retain shared mode as a separately labeled experiment. The registered shared-ownership three/four-round results also provide a clear negative result: extra rounds exhaust more cases without improving this gate. Fixed-territory one/three/four-round variants were outside this frozen 13-policy comparison; two rounds is the selected tested configuration, not a demonstrated optimum over those untested variants. This selection does not authorize a production-default promotion or merge.

The retained matched-final-FRAME no-offer controls answer a different question and must remain. They hold the revised final frame fixed and isolate MOSAIC's conditional response. For the reproduced shared island/4099 example, the conditional no-offer result differs by 16 material cells and three categories. For fixed territory on the same example, that final-frame comparison has zero differences. Neither stronger closure nor a changed frame is evidence that the underlying categorical solver improved.

## Recovery apparatus and source-freeze boundary

The recovery adds meaningful regressions for the shared island/branching seeds
605 and 4099. The former retains its nominal two-sided changes and native joints,
but its matched-mask no-offer result has no MOSAIC footprint effect; it remains a
negative causal/Apply example. The latter must pass both counterfactual effects,
full closure, Apply and reversed invocation-order determinism. The focused
preflight passed 263,015 reciprocal checks.

The new `reciprocal_causal.cpp` audit regenerates every registered candidate, then
retains the complete native candidate, matched no-offer request/result and frozen
peer composition for every explicitly reported both-revision case. A development
replay reproduced all 1,404 cases and all 84 control pairs: fixed 28/6, shared2
6/2 and bearing-off 8/2 causal-with-joint/Apply cases. The diagnostic has six causal
footprint cases, zero causal-with-joint cases and zero Apply cases. All 84 controls were
available. Their separate work does not enlarge a candidate's original ceiling.
The qualification runner binds these raw outputs and their summary to its source,
performs lossless compression with raw and compressed checksums, and renders
nominal and causal measures separately.

The implementation change is restricted to regression tests, qualification and
gallery apparatus, closure availability reporting and this selection/documentation.
The authored assembly, FRAMEWEAVER/MOSAIC grammar, solver and reciprocal
coordinator are unchanged from recovered V1. The separate articulation V2 branch
is preserved as unadopted work. Final source qualification begins only after the
committed selection and public source identity are available. This pre-holdout
record must not be retroactively relabeled as that later execution.

Independent source review checked the added masks, remaining budgets, frozen
initial pair, unchanged candidate policies and negative/positive regressions.
It required two reporting guards before freeze: a refused control with a
full-sized partial array cannot establish causality, and unavailable controls
are classified as unknown instead of negative. Source/lane and complete policy
coverage are checked before a causal receipt can enter the gallery.

The documentation, repository-identity and historical M11 checks passed at the
freeze checkpoint. The unchanged frozen32 retrieval set retains exactly its
baseline ranks: 19 top-one and 30 top-five canonical hits, MRR 0.7292; Q19 and
Q32 remain misses. The additive five-question SWARM-004 set retrieves the
canonical contract first in all five cases. The returned contexts were inspected
for the source/Windows boundary, fixed selection, matched-control distinction
and unknown-closure rule; a route hit alone is not treated as answer correctness.

## Preserved controls and remaining gates

A late commit appeared in the original native worktree during recovery:
`a8250376635ebf95c3c2777b212769b638c13ca0`. Its separate fixed-territory
round-policy expansion is preserved without entering the frozen comparison.
Independent review did reproduce one useful reporting repair: the gallery
rejected the native `damage_lost_internal` obligation origin. An actual
fixed4099 authoring request with destruction 0.25 produced a blocked native
result with 26 revoked required sockets and no Apply authority; the old gallery
incorrectly reported 26 unidentified-origin errors.

Only that damage-ledger audit repair and its 11 adversarial tests are recovered.
The audit now verifies the exact original fulfilled required sockets that damage
revoked, their unchanged source identity, zero foreign slot, absence of a local
termination, and continued `STILL_REQUIRED` status. Deleted, invented or falsely
joined obligations remain failures. The candidate generator and all 13 policy
definitions remain unchanged. Registered known and holdout profiles have
destruction zero; the reporting repair does not change policy selection.

The pre-holdout selection fingerprint is refreshed for this reporting-only
source update. Qualification of the earlier public checkpoint is retained under
its own identity and cannot be reused as evidence for a different commit. The
final public source must repeat full known qualification and then the unchanged
selected holdouts through the existing strict source-identity gate.

The historical B/C admission qualification has a retained PASS manifest and raw evidence. The independent E8/E8-hard-only reproduction completed 216 exact behavioral matches, 108 for each policy, against the frozen research parent. Its enumerated normalization removes source identities and source-dependent digest/definition strings; it does not substitute prose equivalences or erase failed outputs. The V1 unit suites also passed ASan/UBSan in the retained prior run. Leak checking was explicitly disabled under the host instrumentation and no leak pass is claimed.

No holdout seed was opened by this audit. Seeds `19457` and `32771` remain the registered holdouts. Before opening them, commit the final source, truthful reporting correction and selection document with the exact source-input fingerprint. Any implementation tuning beyond reporting requires its own supported comparison first. The original `native-selection-recommendation.json` remains a preserved recommendation. The committed [selection gate](../../native/experiments/gentek_swarm/SELECTION-RECIPROCAL.json) freezes the final native input fingerprint and this decision; it is not a holdout result.

The recovered Workbench evidence establishes real Linux native transactions, cancellation/timeout retirement, Undo and ordinary save/fresh-process reconstruction. Its recorded positive authoring example changes 4,834 native cells and explicitly has zero joints and zero required foreign obligations. That is good transaction evidence and must not be relabeled reciprocal-construction acceptance. The surviving Windows executable and DLL were cross-built; they were not actually executed on Windows in the recovered evidence.

At this pre-holdout checkpoint, the remaining programme gates are publication and qualification of the frozen source; registered holdout execution without tuning; a true reciprocal Workbench positive path from the selected integrated source; exact-source Windows graphical Generate/Apply/Undo/Save/exit/reopen; pristine owner-ZIP repetition and framebuffer inspection; final source/runtime custody; and independent review of those exact deliverables. Keep both implementation PRs Draft/HOLD throughout. This report makes no completed-Windows, completed-programme or merge-readiness claim.

## Evidence files

The immutable recovery audit artifacts listed below are retained under `/workspace/scratch/f37e52b9b84e/recovery-evidence-audit/`. They accompany this dated source record; build outputs and raw evidence are not committed into the repository. Their hashes identify the evidence independently of a later archive location.

| File | Purpose | SHA-256 |
| --- | --- | --- |
| `independent-v1-reproduction.json` | Fresh build, focused execution and byte-exact positive reproduction | `b74cdc88a8e0582788a43675076059ec61a7c779002d3f154b4f50b60f82c7a8` |
| `independent-v1-corpus-audit.json` | All 1,404 candidate cases, closure availability, resource and acceptance checks, retained audit correction | `809e1495d29c77a709e7d8c3f2087ddd3fc046e17740bae9d2ad263d38d9a270` |
| `independent-v1-causal-full-summary.json` | All-policy causal audit, 84 detailed comparisons and independent source/object custody | `64acd9f1d6e057cf17d23855622fdcab5f6d45aa49384ee1a6d58e50327d1487` |
| `native-selection-recommendation.json` | Machine-readable selection reasoning and required freeze gates | `4a5cf160481ca44eb95385914d8fd4332195249b4352b7dbf950dcc77edfff59` |
| `independent-v1-final-runner-receipt.json` | Final outer PASS and all 16 command-log hashes | `9c21802a890735cccdd5000c9b87c3fb1912acecc389411a6aa9d35043c3c4ac` |

Full causal audit source, binary, log and manifest: `causal-full-custody/`. Original corpus: `/workspace/scratch/9a0933ad6744/evidence/native-known-7fa0911/known`. Original Workbench independent probes: `/workspace/scratch/9a0933ad6744/evidence/workbench-independent-review-cc471d63`.
