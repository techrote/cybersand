# GOLDMAPS final delivery and downstream consumer acknowledgment

This read-only refresh is bound to [sandmapsreference PR217](https://github.com/techrote/sandmapsreference/pull/217), head `0634a8eee4b172c28a6936b957dbe2998b664ddb`. The [live final run 45500179792](https://github.com/techrote/sandmapsreference/actions/runs/45500179792), on `8c709093672c6761d1056187399ccc487760606b`, completed successfully. The decision packet records technical completion and a published, verified owner package while keeping `DRAFT_HOLD`, `production_acceptance: false` and `owner_accepted: false`. The PR remains Draft and unmerged. Its stale in-progress narrative is not the run-status authority.

## Exact identity comparison

The final [primary owner-kit record](https://github.com/techrote/sandmapsreference/blob/0634a8eee4b172c28a6936b957dbe2998b664ddb/docs/corpus/goldmaps-owner-delivery-001/batch-handoff/PRIMARY-OWNER-KIT.v1.json) identifies `CyberSand-GOLDMAPS-Owner-Evaluator-8c709093672c.zip`, 101,213,343 bytes, SHA-256 `ba3d75bf97943af4148ee4427fdfcb2c6df41ede2453c80ef69e3bd6577dfea9`, artifact `14971496709`. These final archive identities and current native overlays are upstream's reported and independently reviewed authority; B did not download or rerun the final evaluator package.

B independently recomputed the Git blob identity and SHA-256 of the knowledge bytes already consumed from the earlier actual archive. They match the latest committed final-package member exactly:

| Field | Earlier actually consumed bytes and latest committed final-package bytes |
| --- | --- |
| Member | `corpus-export/knowledge.v1.json` |
| Bytes | 1,640,704 |
| SHA-256 | `711e501597f0c9fa90a2553a643aabdbcbe5552693efc2dd578e626ca6c56557` |
| Git blob SHA-1 | `18afb94ff8305648bf1e4353f9d0824eab889dc0` |

The latest member is retained at `qualification/windows-final-8c709093672c/package/corpus-export/knowledge.v1.json` under the owner-delivery audit directory. Its exact Git tree entry was checked, and the pinned [final actual-archive corpus review](https://github.com/techrote/sandmapsreference/blob/0634a8eee4b172c28a6936b957dbe2998b664ddb/docs/corpus/goldmaps-owner-delivery-001/corpus/final-delivery-corpus-review.v1.json) separately records the same byte identity. This establishes knowledge-input continuity without copying artwork, changing the application or rerunning an unchanged consumer. The frozen 25-card corpus remains SHA-256 `9153480ea622d5dc6a78543269840af64b3adbef43074af8cf78cfe685d0b057`.

## Consumer result and authority boundary

The existing actual-export invocation at consumer source `b49a0947e614e09a7807dd35043f20f88e31381b` passed **31 checks**: nineteen synthetic contract checks, eleven actual-export checks and one retention check. It consumed the member from producer `b4ed0fc462a5e10f3d502b4b5593ef9b4ce70041`, run `45481683557`, artifact `14966411591`. The [original consumer review](goldmaps-consumer-review-b.md) retains archive custody, the initial long-tag refusal, the bounded reader correction and reproduction commands. The actual-consumer report SHA-256 remains `e041123d2e22806c5fef05c307f080a6e3f1d8fef5ff910fd5a5d066fdf26794`.

The final delivery's separate overlay reports 70 qualified unique setups out of 72, with original PR155 and PR183 still refused; its qualified canonical-map count is 68. Those delivery counts must not replace the distinct frozen 67-map primary scientific policy/schema population. The knowledge consumer has not applied the newer overlay or upgraded historical observations. It exposes 70 source records and 27 non-geometric part hints; it supplies no verified importable modules or inferred sockets. Frozen cards, training cohorts and original negative evidence remain unchanged. No native module import, World construction, model request, training or owner acceptance followed from consumption.

## Coordination record and proposed downstream note

At this refresh, PR217 had no issue comments, so no equivalent downstream consumer acknowledgment was found. This task made no reference-repository write and posted no comment. The following concise acknowledgment is ready for the technical lead's coordination:

> CyberSand's M6/M7 read-only consumer has actually consumed the identified `knowledge.v1.json` under pinned Godot 4.7 at source `b49a0947e614e09a7807dd35043f20f88e31381b`: 31/31 checks passed (19 synthetic, 11 actual-export, one retention). The consumed b4 archive member is byte-identical to the final 8c709 package's committed member: 1,640,704 bytes, SHA-256 `711e501597f0c9fa90a2553a643aabdbcbe5552693efc2dd578e626ca6c56557`, Git blob `18afb94ff8305648bf1e4353f9d0824eab889dc0`. This confirms schema and compact read-only browsing continuity. The 25-card corpus is unchanged; original PR155/183 refusals remain explicit, and 27 hints remain non-geometric. The final delivery overlay was not silently applied. No native module admission, model call, training or owner acceptance is inferred. Evidence: CyberSand `docs/audits/2026-11-24-world-steer-m6-m7/goldmaps-consumer-review-b.md` and `goldmaps-actual-consumer-review-b.json` (report SHA-256 `e041123d2e22806c5fef05c307f080a6e3f1d8fef5ff910fd5a5d066fdf26794`).

The [machine-readable refresh](goldmaps-successor-consumer-review-b.json) records the observed upstream head/run, exact identity comparison, prior executed consumer result and preserved limits.
