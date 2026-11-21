# Independent P2 historical-inspection closure review

**Decision: GO for the frozen five-file source delta.** The previously reproduced P2 historical-inspection regression is closed at source. No new confirmed P1/P2 was found in this delta. Exact-source hosted r3 gates remain required; this receipt grants no package-custody, publication, merge or owner acceptance.

Reviewed at 2026-11-21T21:50:10.088935+00:00. Base/request HEAD remains `10fe808ac7f6a4b9c07f7d168763b41957359e57`. The five reviewed files match the worktree, index and root-prepared staged tree `db1393c21a5e58137f06e6b6008f1001775da89f` byte for byte. The broader staged tree contains separately reviewed changes outside this receipt's scope.

## What closes the P2

The old report is retained unchanged at `/workspace/scratch/038267c40e11/swarm45-historical-inspection-finding.md` (SHA256 `f1f01afe212d904984878ee3e7bf17f9884176e94cc93c51175689c3a2b0c08b`). It established that genuine r1 saved maps restored their complete native World correctly while current217 historical inspection rejected their fe62 native identities. This review is additive and does not erase that failed checkpoint.

The repaired public `decode` and `decode_document` paths still require current native definition `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7`. Only `load_saved` selects an explicitly reviewed matching FRAME/MOSAIC pair from #693 `57ff699bf5c9833a2a5e2198ff2ef0b07cfd051069013776e6427f1e9d6694ec`, #697 `12a4816dab749a9c872a4d531836db8ec6a170aab31576d70086efa80eeb3b6b`, r1 `fe62e15412459c22c6f81e479fa1ff2917d7359d747581c9891b83fbf2f75618`, or current217. Historical identity substitutions are made on a deep copy; current identities are not modified.

All successful saved loads, including current217, return outer `historical_only=true`. The original native result and raw `can_apply` remain evidence, with their original bytes and identity. Unknown or mixed definitions, non-schema5 documents and a V4 type remain refused. The original map/evidence/proposal/source binding checks, masks, resource limits and geometric validation remain in the common validator. Only exact historical #693 permits absent later SWARM005 switches, interpreted as false; explicit capability promotion or malformed values are refused. Later saved versions and live output still require explicit valid switches.

The panel's persistent latch guards Apply, direct `_submit`, `attests`, Undo and both transaction buttons. Cancellation, control invalidation, new World installation and proposal clearing cannot remove it. The only production assignment clearing the latch is after a successfully decoded current output, zero child exit, unchanged source fence and unchanged authored history. Historical loads return earlier; marked historical results on the generation path are refused. Existing capture, stale-source, nonzero-child, cancellation and transaction acknowledgement checks remain intact.

## Independent targeted execution

I copied the project into `/workspace/scratch/038267c40e11/swarm45-p2-independent-review/project`, compared all 687 tracked GDScript/scene/resource/project source files against the integration worktree, and confirmed the five frozen hashes before and after testing. A separate minimal protocol project and fresh per-case user profiles kept generated data outside the repository and original evidence. The focused recovery harness was inspected in full (SHA256 `f45a3a2371c6de5332456fa988cabd7c7ecef1c8ed910582bc7a48d77a8f85d8`); it subclasses the frozen UI fixture and starts with ordinary Load and Inspect of the genuine hosted-r1 transaction triple.

| Independently executed check | Assertions | Result / exit | Log SHA256 |
|---|---:|---|---|
| protocol | 182 | PASS / 0 | `976221190472ca66da785d066ece4d6b1b4506a9caff40227f85bc110ca0682e` |
| controller | 40 | PASS / 0 | `fda9cd5eda13c938bd49729ececebda059d8abda89166b4922e9160171a02b0c` |
| r1-green | 13 | PASS / 0 | `3b7100e50abe2d59958c4ec6342c7ae8da6f194dd8035d6837beb5b8456972bc` |
| r1-recovery | 24 | PASS / 0 | `28ca4a9f888aef965a40d259f5b3a2ffb37a7baa48c37c05c894fabcc43ceae4` |

**259 assertions passed.** The genuine r1 reopen enters `historical`, retains raw native `can_apply=true`, disables Apply and Undo, rejects direct Apply/submission/attestation/Undo, and preserves the complete 512×512 plane: expected and observed SHA256 `2a7166559b1e23af4a2324ebe088db99727d045c1564da62d79f803939c02fc6`. The previously failing inspection now completes.

The recovery run then installs a fresh blank source and uses real control/canvas input. The latch remains set until an actual current217 child generates a valid replacement; phase becomes `ready`, the live proposal marker becomes false, and Apply becomes enabled. Generation does not mutate native cells or authored history. Controller negatives separately prove that a valid existing Undo and forged matching pending attestation cannot bypass historical authority, including after cancellation/invalidation.

Original r1 map/receipt/evidence and both independent loaded-copy triples were hash-identical after both runs. All five production/test file hashes also remained unchanged. No repository implementation files were modified by this reviewer.

## Reviewed supporting evidence and limits

I parsed the engineer's nine complete logs, independently confirmed their aggregate **408 passing assertions**, and hashed all 12 original files across the three genuine hosted-r1 triples and genuine #697 triple. Their logs show exact full-plane restoration and historical-only authority. Current217 create/reopen and the real historical-to-current recovery logs also passed. The full per-log hashes, results and verified original hashes are in `wb-evidence-audit.json`.

The engineer's frozen checkpoint hashes were verified: checkpoint `31acafda190977255faaa835b7ebc3e5633e0b9045c6488b7036c243b501c072`, report `aca3abebd8af2396224e1c941673f4954ca9132632b54e5b83d0baead8c4000d`, patch `b8a18d69c587ed4a9a376ec0e532f122c7b3e8ff7674b8ec33fe0b3087826a99`.

No genuine #693 saved triple is available. Its coverage consists of controlled transport fixtures and the previously inspected immutable donor schema/option contract; this is not represented as a genuine #693 native or graphical replay.

Independent execution used exact Godot `4.7.stable.official.5b4e0cb0f` and verified hosted-r2 source10fe Linux native artifacts: CLI SHA256 `a3690011da97b12a6bfdc8d461e33dde9f98c1418fef89a3f3de994bd239da53` and GDExtension SHA256 `1db5702cf59f02d1ca4b6e7c0b34a73f3d106e67cec73b4901c0c10cd4c1cbb1`. These are local Linux **headless** diagnostics over the new GDScript delta with unchanged native inputs, not hosted r3 results or a fresh platform qualification. No native/native-extension source changes are present relative to HEAD. Native definition and historical control evidence are unchanged.

## Exact reviewed source

| File | SHA256 |
|---|---|
| `godot/scripts/workbench_reciprocal_protocol.gd` | `1c2c4da1c379e83e1a01455a90eb899c7b98411d79eda75989a523ab395109d1` |
| `godot/scripts/workbench_reciprocal_panel.gd` | `b53951bad17ef2e50add2afccf8c0575aa143969fa6b06eb7f03635112d39413` |
| `godot/tests/test_workbench_reciprocal_protocol.gd` | `ece8fc6a491b06e8ee6adfc5d973150bb6099a6f54182632c0f05b567143222a` |
| `godot/tests/test_workbench_reciprocal_controller.gd` | `cbae21dfcd94a223c62a1cc136c0fc42958c69c61136403d898f6c4e012dadf5` |
| `godot/tests/swarm45_reciprocal_ui.gd` | `a57618ed8491431aee4865936077082ffcd2b62d52980a72374cb2443301fac8` |

## Independent evidence custody

All following artifacts are under `/workspace/scratch/038267c40e11/swarm45-p2-independent-review`. `execution.json` contains exact commands, case runtimes, results and log paths. `review-receipt.json` records the source decision and boundaries in machine-readable form.

| Artifact | SHA256 |
|---|---|
| `inputs.json` | `a5ee4aee1f4f79f8a7cf0fe1a60900f9d41be2726526fb2dcabff66ea628897f` |
| `execution.json` | `e6aae2c5a2acf8aa887b7721caedd27910568a25e089121672170dabbb3dbc96` |
| `immutability.json` | `729e8661994b3c46e176c12bc85a2a3c5e562688ffee7751d36d88d40654b25b` |
| `wb-evidence-audit.json` | `0ae72622a911a0323aee573102730dea4424cb98c206f86f9ee9d582e716aad6` |
| `review-receipt.json` | `12f12fd702583abb2bf99748585f1d6641c16acee85c9d67bbf71521d1e0abf7` |

The source repair may proceed to the next frozen checkpoint and required hosted validation. This review does not convert earlier r2 runtime evidence into r3 evidence, resolve the separately owned package-custody gate, or authorize publication/merge.
