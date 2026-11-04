# SOL281 final readback-failure review and local iteration evidence

The original contact candidate was recovered at publication 3ac7701. All thirteen file hashes in its prior independent review match that publication. The candidate retained the earlier spin, revision, immutable-publication, accounting and live-exercise corrections. The new review identified one conditional failure-handling gap: NaN actual energy evaded a greater-than check, and backend velocity/angular-velocity readbacks had no separate finite check. No old hosted result is claimed to contain this failure.

## Repair and source binding

The repair is local commit d673a5c2550088287a1187952ea7d0535fe261c4, integrated by the parent as 4b9dbf80826f24c7bea7381c18c06046ef9656d5. The seven file blobs below match both commits and the tested isolated worktree. Tests ran before the local commit was created, against the identical source delta; these receipts do not claim hosted whole-commit qualification.

The bridge now validates every actual readback vector/scalar, retains the original energy tolerance, and distinguishes terminal post-application failure from mutation-free refusal. It retains the consumed sample lease and possible-mutation evidence. The session counts failed responses separately and latches its existing pause before another main-thread Rapier step. Unpause cannot bypass the latch. Native code, ordinary policy, planner mechanics, ownership, transfer bounds and registered thresholds are unchanged.

## Independent review

The original review and new implementation were performed by /root/implementation_review. The final patch was independently reviewed by /root/implementation_review/native_review. The independent reviewer found no remaining implementation blocker after two test repairs: corrected indentation/scope in the recovery fixture, and strengthened duplicate negatives to demand the exact preflight outcome plus no extra readback-seam call. Separate native review and sanitizer details are preserved under native-review/.

This is engineering review, not human gameplay acceptance or merge authorization.

## Local validation and exact scope

| Check | Result |
|---|---|
| Pinned Linux Godot/Rapier contact fences | 135 assertions, zero failures, all twelve named fault cases |
| Unchanged actual-Rapier mechanism | 90 assertions, zero failures; flat reduction 100%; off-centre reduction 91.1883194468% |
| Changed populated-recovery script | Parse/load check only; passed |
| Qualification reader | Eleven tests passed; independently repeated by reviewer |
| Whitespace and native source scope | Passed; no native/native-extension changes |

Fault values are injected into copied readbacks after genuine finite Rapier impulses. The fixture verifies the real session latch and refusal to execute a next step, but starts no native worker for those injected cases. It does not induce a backend NaN/Inf fault. Finite real readback remains accepted when injection is disabled.

These were bounded direct local runs. The shared process-ownership monitor cannot operate in this sandbox, so these results remain iteration evidence. No runner/monitor/watchdog policy was changed or bypassed in the repository. Fresh exact-source hosted Linux/Windows qualification is required.

The four Godot logs are byte-for-byte copies of retained local files. The qualification-reader output is explicitly labelled as a transcript because the original console bytes were not saved. Import output is preparation evidence only: its original shell command did not separately preserve the engine exit code. The JSON receipt records commands, runtime hashes, source hashes, outcomes, artifact hashes and these limitations.

## Reviewed file inventory

| Path | SHA-256 |
|---|---|
| docs/systems/solid-detachment.md | f9b4685409849e6a9badc8161dd6dbf8c483a9d7b254f52e6bb3cb1cd0d09fc7 |
| godot/scripts/rapier_physics_bridge.gd | 9ea0736c16db5089b817728388c88be2ef8e5fc6db8545992608473cf526851d |
| godot/scripts/solid_detachment_session.gd | 9edd54f21013a2bcd30d1e332496248dc9da38d319ad96342bafecefd6f91310 |
| godot/tests/test_solid_contact_fences.gd | fce75140e61fb7826d18e2596a39a4ac6486a48a02c75ec4434f24f675eb54cb |
| godot/tests/test_solid_detachment_contact_recovery.gd | e5967594fa5a4315f265e5a69762a107b839f32bd9ac062304d8f35c11fdfc99 |
| tools/sol281/run_qualification.py | bebc2a959504dc565735d04e340f9d7252aae1efd9afe5c9cea0d7361f4828a1 |
| tools/sol281/test_qualification.py | 5d3d3c98b6fb92298edb2ae2aedf597e750fb4d19e582f5a06026f89b78d5fdd |

## Remaining gates

Dense-material penetration and sustained clearance, restoration, broader lifecycle work, representative GPU pacing and genuine human acceptance remain unresolved. Neither this guard nor its local tests authorizes merge, default promotion or issue closure.
