# Independent r2 committed native/protocol review receipt

Date: 2026-11-21 UTC. Reviewer: `/root/swarm45_native_review`. Repository: `/workspace/scratch/038267c40e11/cybersand-swarm45-mainline`. PR715.

**GO for the exact committed native/protocol source reviewed below. No confirmed unresolved P1/P2 finding in this scope.** This is source review only: it does not claim hosted PASS, resolve or waive the earlier runtime failures, approve publication, mark Ready, or grant merge admission.

## Exact committed identity

| Identity | Verified value |
|---|---|
| r2 frozen source | `96cc2772b0b7cf8e273526d3efd081596be1ad85` |
| Frozen source Git tree | `550224ac8447ac2c6748dab840da974ed9d13c57` |
| Source merge parents | `9b688aed1f06f031f983c27f50d1f17821446e43` and accepted main `846fe0533b3170e7b01f690518da49fc40cc24d1` |
| r2 request commit / examined HEAD | `10fe808ac7f6a4b9c07f7d168763b41957359e57` |
| Request Git tree | `1259e2a16cd0e598fe0f758eff72fd88891ab98a` |
| Request JSON SHA-256 | `300e92f37eb7e74589856da7a4625b969878e9e1635eec107e0fa73067b4ffdd` |
| Recomputed native definition and protocol pin | `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7` |

The request commit has the frozen source as its sole parent and changes only `.github/swarm45-mainline-request.json`. It pins the exact r2 source, accepted main, existing frozen donor identities, and native definition. The working checkout had no tracked changes; the existing evidence directory was untracked.

## Native and protocol checks

All **seven file hashes** in the approved stdio-portability checkpoint match the frozen source and request commits exactly. The reviewed report remains SHA-256 `42a53a7e99da3ab8b3e4a8a7b107d0ef8e282d640a2234d9bffb8b56b07ba15e` at `swarm45-stdio-portability-review.md`.

Among the **43 compiled native definition inputs**, the only change from r1 frozen source `a08c0e77601c9451ece3a15248d4255164911d5f` is the already-reviewed console-I/O change in `reciprocal_main.cpp`. The receptor geometry/accounting repair, original scientific fixtures, policy implementation, budgets, and native JSON serializer are unchanged.

The **81 existing `native/src` and `native/include` files from accepted main** match r2 byte-for-byte. The only additional file in those directories is the previously reviewed `workbench_authoring_patch.hpp`; all **82 files** in those directories match r1. The complete **106 native-extension input files** likewise match r1 byte-for-byte, with no added or removed inputs.

Eleven of the twelve final preflight Godot snapshot files remain unchanged. The twelfth is the protocol file, whose only change is the approved native-definition pin. Workbench still writes V1/V2 SWARM004 or opt-in V3 SWARM005 requests and admits reciprocal-assembly JSON schema5. There are no SWARM006 paths or new V4/Workbench-schema6 imports. The older `matched_final_frame_no_offer` control serializer happens to use schema6; its file remains byte-for-byte equal to the frozen donor, and it does not expand Workbench admission. This receipt does not mislabel that historical control format as a new import.

## Protection and receipt review

The runtime custody, publication candidate, publisher, shared receipt checks, ordinary runtime gate, and Workbench panel are unchanged from r1. Their source/hash, same-run, pending-owner, and proposal-authority fences therefore retain the prior reviewed bytes.

I also read the new source-stage path and the r2 request guard. Staging verifies original runtime/source custody, archives committed source into a new directory outside the checkout, rejects unsafe archive paths and symlinks, verifies the installed platform project/runtime, and rechecks original custody afterward. Generated Godot imports do not create a source-cleanliness exemption. The request guard retains strict bounded JSON, branch/ancestry checks, a published frozen-source predecessor, and request-only linear commits after that freeze. I found no additional concrete P1/P2 in this inspection. The CI/publication reviewer's separate 13-file delta review remains the comprehensive staging/workflow review; this receipt does not duplicate its execution claims.

## Committed file hashes

| Reviewed repository-relative file | SHA-256 at both r2 commits |
|---|---|
| `native/experiments/gentek_swarm/reciprocal_main.cpp` | `85610d2d00e997278394d3ed6310097c546b26ab6588b6b16b7f30de6b46c1ac` |
| `tools/swarm45/linux_floor.py` | `b875adefdd56fa1cd3727b25ab22f435ecce4dad9b482eb86cee4e4aed693b5d` |
| `tools/swarm45/native_checks.py` | `16b8a1bb7d37a4f912a54483c1315cf07112fd7507dfa928c888b0c2fddc4349` |
| `tools/swarm45/test_custody.py` | `223c0fa59b36f787a88c267c191edc6b5c636cd830745c206121fe2a7eceb8f0` |
| `godot/scripts/workbench_reciprocal_protocol.gd` | `8c1e392a108884e1d6a4340d80c9ddf2b6a2b0e28e2d4d9b934ea50927f1ef72` |
| `native/experiments/gentek_swarm/reciprocal_mosaic.cpp` | `94a38e05026e6f16b84d1ba2e506775f4159e21424c958e4886e4981cc65579d` |
| `native/experiments/gentek_swarm/swarm005_research_tests.cpp` | `c7226cae0f92858dad52ff8e285eee22b40274e7c1a01d45d7e840fd3a4861b1` |

The full commit/request metadata, 106-file extension hash inventory, native-file comparisons, protocol-scope checks, and unchanged protection-file hashes are in `swarm45-r2-committed-source-review-inputs.json`, SHA-256 `4af54e5ed58f4317d46388ec67f71e2ea68664c8dc55bcc6ae6e4cceaf8c34a0`. All review artifacts are under `/workspace/scratch/038267c40e11`.

## Admission boundary

This checkpoint used read-only Git object extraction, source inspection, byte comparisons, and definition recomputation. No repository file, remote state, prior report, or donor was changed; no native corpus was rerun.

Hosted run `44950154534` was reported in progress by the parent. This review has not inspected or accepted its Linux/Windows, ABI-floor, graphical, extracted-evaluator, publication, or full-CI outcomes. Earlier r1 failures remain evidence and cannot be overwritten by this source verdict. The actual r2 outcomes and final runtime publication must receive their own review, and physical owner acceptance remains separate. The candidate remains **Draft/HOLD** until its admission conditions are met.
