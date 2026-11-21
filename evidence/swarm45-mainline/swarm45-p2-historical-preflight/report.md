# SWARM004/005 P2 historical saved inspection — local checkpoint

The bounded historical-inspection repair is implemented in five Godot files. Live generation still accepts only the current `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7` native definition. Hash-bound saved inspection additionally accepts matching FRAME/MOSAIC pairs from reviewed Workbench definitions #693 (`57ff699b…`), #697 (`12a4816d…`) and r1 (`fe62e154…`). Unknown or mixed definitions, other schemas, and future protocol families remain refused.

Only exact #693 saved evidence may omit the two later SWARM005 switches; those fields mean false, and that historical definition cannot enable either capability. The common schema/source/mask/limit/receipt/geometry validation remains shared with strict live admission.

Every successful `load_saved`, including a current-definition saved record, has outer `historical_only=true`. The original native result, including its original `can_apply`, remains unchanged. The panel guards Apply, direct submission, attestation and Undo with that authority. Cancellation, control edits and replacement of the displayed proposal do not clear the guard. A successfully decoded fresh current-source child is required to clear it.

## Targeted verification

| Check | Assertions | Result |
|---|---:|---|
| Protocol admission | 182 | PASS |
| Mechanical controller authority | 40 | PASS |
| r1_transaction | 13 | PASS |
| r1_reciprocal | 14 | PASS |
| r1_swarm005_irregular | 13 | PASS |
| legacy697_irregular | 13 | PASS |
| current217_transaction / create | 96 | PASS |
| current217_transaction / reopen | 13 | PASS |
| r1_to_current217_recovery / reopen | 24 | PASS |

The genuine #697 irregular map and all three r1 maps restored their complete 512×512 native planes exactly through ordinary Workbench Load. Inspect retained the original successful native evidence, entered phase `historical`, disabled Apply and Undo, refused direct transaction actions, and left original and loaded-copy map/receipt/evidence hashes unchanged.

A separate focused harness first inspected the genuine r1 transaction record, then installed a fresh blank source. Parameter edits and real canvas input left the read-only guard set. Clicking Generate with the verified current native runtime produced a new current-definition proposal and enabled Apply; generation still made no native or history mutation. The old saved triple stayed unchanged.

The normal current-definition transaction also passed actual Apply, exact Undo, regeneration, Save and a fresh-process reopen. Protocol negatives cover old/current live admission, legacy option absence, unknown/mixed identities, future schemas/types, tampered receipt/source/hash fields, rebound invalid masks/limits, and saved-file immutability. The controller fixture proves that an otherwise valid preexisting Undo and matching pending attestation cannot bypass historical authority.

## Runtime and scope

Godot is exact `4.7.stable.official.5b4e0cb0f`. Native CLI and GDExtension bytes are the verified hosted-r2 Linux artifacts built from source `10fe808ac7f6a4b9c07f7d168763b41957359e57`; they retain that source identity. The Godot files are the new local uncommitted P2 delta. These are Linux headless diagnostics, not newly qualified hosted or graphical results.

- CLI SHA256: `a3690011da97b12a6bfdc8d461e33dde9f98c1418fef89a3f3de994bd239da53`.
- GDExtension SHA256: `1db5702cf59f02d1ca4b6e7c0b34a73f3d106e67cec73b4901c0c10cd4c1cbb1`.
- Genuine #697 input archive SHA256: `0fb7484c6658a5eed88bd71956198dc7faca5f3a32dd4d201ff2b3b12d7c2f74`.

No genuine #693 saved triple was found. Its controlled transport coverage uses the independently reviewed immutable donor schema5 contract, including absence of the later switches; it is not represented as native construction or graphical evidence. Native source, native definition, production defaults and the 60-second startup gate are unchanged. No commits, pushes or CI triggers were performed by this engineer. Independent review and exact-source hosted qualification remain required.

## Source checkpoint

| File | SHA256 |
|---|---|
| `godot/scripts/workbench_reciprocal_protocol.gd` | `1c2c4da1c379e83e1a01455a90eb899c7b98411d79eda75989a523ab395109d1` |
| `godot/scripts/workbench_reciprocal_panel.gd` | `b53951bad17ef2e50add2afccf8c0575aa143969fa6b06eb7f03635112d39413` |
| `godot/tests/test_workbench_reciprocal_protocol.gd` | `ece8fc6a491b06e8ee6adfc5d973150bb6099a6f54182632c0f05b567143222a` |
| `godot/tests/test_workbench_reciprocal_controller.gd` | `cbae21dfcd94a223c62a1cc136c0fc42958c69c61136403d898f6c4e012dadf5` |
| `godot/tests/swarm45_reciprocal_ui.gd` | `a57618ed8491431aee4865936077082ffcd2b62d52980a72374cb2443301fac8` |

Complete machine-readable results, absolute log paths through their case directories, source/runtime hashes and original saved-input hashes are recorded in `checkpoint.json`. The exact five-file patch is `historical-inspection.patch`.
