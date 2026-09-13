---
title: Issue 11 barrel-support reconciliation, 2026-09-12
status: Current
document-kind: audit
scope: Current-source inspection and minimal Windows validation of issue 11 closure, barrel bearing, masked feedback and barrier-aware ejection
canonical-for: []
last-reviewed: 2026-09-12
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, ../operations/physics-characterisation.md, 2026-09-09-physics-characterisation.md, 2026-09-09-issue-10-granular-policy.md]
---

# Issue #11 barrel-support reconciliation, 2026-09-12

## Current disposition

**#11 substantively unresolved despite administrative closure.** The live issue is
closed as completed, but it has no comments and its timeline closes without a commit
or pull-request reference. Current source still has no persistent granular bearing
mechanism for Rapier barrels. The 2026-09-12 source-matched ordinary Sand fixture
reaches the deep hard floor at tick 155, so this is not an evidence-only gap.

The [issue #9 baseline](2026-09-09-physics-characterisation.md) remains credible
historical evidence for the same implementation family. It is not relabelled as
current-source acceptance. Issue #10's material/packing support is implemented for
the sampled character only and explicitly excludes barrel bearing.

## Source, artifact and live-issue identity

| Input | Inspected or tested identity |
|---|---|
| Git root and isolated worktree | `C:/kybersand/source`; `C:/kybersand/worktrees/issue-11-reconciliation` |
| Branch and base HEAD | `codex/issue-11-reconciliation`; `dfa95b3a787b7a3ed8dd65db5c263359f53f762c` (`Add normalized Water policy and blind controls`) |
| Base selection | Newest local code-bearing descendant of #9, #10, #13, #17 and synchronized programme documentation. The active #19 worktree was not modified. The fetched orchestration-only line diverges at `ab4851e` and lacks the #9/#10 implementation, so it was read for policy but rejected as the source base. |
| Tracked state before validation | Clean. All 18 LFS entries were materialized. |
| Runtime delta during validation | Rebuilt `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll` only; source files were unchanged. Intake SHA-256 `fda49d0acb0a4786f9aeeb6cb4289fc2fd10ac8103512cc1663f98598a49049b`, preserved under `validation/local/2026-09-12-issue-11-reconciliation/intake/`; rebuilt SHA-256 `39c26835ba7b09a779596c751ec46bf20194dca4843a352cd867a1fc19ba5258`. |
| Platform and dependencies | Windows 11 build 26200, AMD64; Godot `4.7.stable.official.5b4e0cb0f`, SHA-256 `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`; Rapier2D `v0.35.2`, Windows DLL SHA-256 `4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180`; godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`; LLVM-MinGW Clang 23.1.0; Python 3.12.14. |
| Live GitHub state | [Issue #11](https://github.com/techrote/cybersand/issues/11) closed as completed at `2026-09-10T09:40:42Z`; no comments; closure timeline event has no commit. [Issue #12](https://github.com/techrote/cybersand/issues/12) remains open and its programme supplement explicitly requires actual support evidence before support-dependent integration. |

Raw build/test logs and the source/artifact manifest are under
`C:/kybersand/validation/local/2026-09-12-issue-11-reconciliation/`.

## Current implementation answers

| Question | Current-source answer |
|---|---|
| 1. Persistent granular barrel bearing? | **No.** `CyberNativeCellWorld::prepare_rigid_body_coupling` clears observations on every sample and produces only overlap-displacement, endpoint-boundary and cellular movement-contact impulses. No support state, packing load, yield response or continuous force is retained. |
| 2. Authoritative implementation? | There is no barrel-bearing implementation. `World::granular_support_at` in `native/src/world.cpp` is authoritative only for the sampled character through `character_box_collides`; `CyberSampledCharacter` owns that response. |
| 3. What makes support persist? | Nothing for a barrel. Rapier may sleep on hard terrain, but no powder collider or force supports a barrel at rest. Transient observations are rebuilt and capped per coupling preparation. |
| 4. What removes support after excavation/collapse? | No barrel support exists to remove. Player support disappears on the next owner query because the 3x3 material/stability samples change. Historical contact-off excavation demonstrates renewed barrel motion only for a diagnostic variant, not production bearing. |
| 5. Packing-aware or clamp/freeze? | Neither: the barrel path never calls the packing query and has no clamp/freeze. Body displacement and boundary impulses use movable material and density, not an actual supported load path. |
| 6. One solver owner per current mode? | Yes for implemented modes: Rapier owns hard-terrain contact; cellular coupling owns movable-material displacement/impulses; the sampled character owns its packing collision. The missing #11 bearing mode has no selected owner or contract. |
| 7. Double-solved by Rapier and cells? | Not for current powder support, because no powder collider exists. Hard materials become Rapier static shapes and the cellular overlap/boundary paths explicitly skip their second correction/support. |
| 8. Does sample age alter bearing? | There is no bearing, but age materially alters transient feedback: corrections are suppressed above age one, impulses scale by `1/(1+0.25*age)`, and results above age eight are rejected. Historical delay-four ordinary runs reach the floor. |
| 9. Masked-source feedback distortion? | **Yes.** `World::update_cell` selects the stored powder kernel while `update_rule_kernel` reads the mask-visible `Wall`; the current native regression reproduces three downward attempts and raw `y=4800` from one stored Sand grain. |
| 10. Barrier-crossing ejection? | **Yes.** `find_ejection_target` checks only candidate occupancy/emptiness, not the path. The current Godot regression still moves one Water cell across a one-cell hard floor during coupling preparation. |
| 11. Distinct liquid behavior? | The cellular kernels and hard-floor owner remain distinct, and the full-world Water accounting control preserves mass. However, the shared body-ejection defect can relocate Water across barriers, and no liquid is evidence for granular bearing. |
| 12. Seam, sleep/re-entry and failed-world contracts? | They remain relevant and preserved by current native regressions. They were not broadened into barrel-support acceptance; a future support state must define their semantics and rerun the affected desktop/Web cases. |

## Programme concerns against current source

| Concern | Classification | Current basis |
|---|---|---|
| Missing persistent barrel bearing | **Still present** | No barrel packing/support state or force exists; source-matched Sand barrel reaches the deep floor. |
| Masked-source feedback | **Still present** | Current exact native characterization reproduces the Wall-proxy weighting. |
| Barrier-crossing ejection | **Still present** | Current source still performs endpoint-only search; source-matched Godot characterization reproduces the crossing. |

## Acceptance matrix

| Original acceptance family | Status | Current conclusion |
|---|---|---|
| Ordinary 8x14 mass-1 impacts embed near half-depth on Sand | **Not satisfied** | One-height, seed-0, 180-tick source-matched run reaches the floor at tick 155; peak/final depth is `384.0018` cells, versus the provisional `8`-cell envelope. |
| Representative-powder support | **Not satisfied** | No material/packing-aware barrel support path exists. Historical Dust, Salt, Oil, Mercury and Water controls did not establish a supported equilibrium. |
| Thirty-second stability and 120-second creep | **Not satisfied** | Production behavior fails after about 2.58 seconds, so broad long-duration reruns cannot change disposition. Historical contact-off finalist motion is not a sleeping bearing and exceeds the impact envelope. |
| Excavation/support-loss release | **Not satisfied** | Production has no accepted support state to release. Historical contact-off excavation falls, but that diagnostic variant is not the current solver. |
| Mass, orientation, size, slope and multiple-barrel stress envelope | **Partially evidenced** | Historical #9 covers masses 0.5/1/2, 45/90 degrees, size/drop/stress variants and selected slopes; none establishes bearing. Multiple-barrel load paths remain untested. |
| Liquid control and conservation | **Partially evidenced** | Historical full-world Water mass is exact and kernels remain distinct, but barrier-crossing ejection remains and no floating/support equilibrium is accepted. |
| Hard-floor control | **Satisfied** | Current source-matched 180-tick control has zero reported peak depth; Rapier remains the sole hard-contact owner. |
| Sample-age/latency sensitivity | **Partially evidenced** | Age policy is source-visible and #9 measured delay sensitivity; the current focused run covers age zero only. |
| Desktop asynchronous behavior | **Partially evidenced** | Historical source-matched #9 async runs reached the floor and recorded ages 0..5. No new async run was needed after the current synchronous fixture failed decisively. |
| Real Web compatibility/threaded behavior | **Partially evidenced** | #9 executed both real Web profiles for the unchanged baseline family. No current-HEAD Web export was rebuilt; neither profile has accepted bearing. |
| Seams, sleep/re-entry and failed-world preservation | **Partially evidenced** | Current 56-test native suite preserves worker, seam, sleep/re-entry and F01/F02 contracts, but no persistent bearing exists to exercise those contracts. |
| Bounded telemetry/contact work/body capacity | **Partially evidenced** | Existing 16-body, bounded sweep/ejection and fixed diagnostics remain. The focused barrel produced 2,460 intermediate caps, 117 final caps, 128 displacements and 16,878 repeated unresolved observations; no support-work budget exists. |
| Ownership, units/configuration and dated evidence | **Partially evidenced** | Existing owners and transient impulse units are documented; the missing bearing owner, calibrated load units and support configuration remain undecided. |
| New torque/CCD/substep scope | **Out of currently justified scope** | This reconciliation changes no code or solver; current per-body cast-shape CCD and existing hard-floor contract are preserved. |

## Focused validation

| Command / fixture | Duration and configuration | Result |
|---|---|---|
| `tools/build_native_extension_windows.sh` with pinned local godot-cpp/LLVM-MinGW | Source HEAD above; Windows Debug bindings library; release extension | Initial launch failed before compilation because PortableGit utilities were absent from child `PATH`; retained in `native-build.log`. Rerun with documented paths passed and produced SHA-256 `39c268...5258`. |
| `python tools/physics/run.py godot --group smoke --seeds 1 --ticks 180 --output <raw>/godot-smoke` | Five fresh fixtures; manual main-thread Rapier; native cellular world, default one worker; age zero | 5/5 runner completion. Sand barrel hits floor tick 155; hard-floor peak 0; freefall has not reached the deep floor at tick 180; sampled Sand/Dust players remain supported. This runner's `ok` means fixture execution, not #11 acceptance. |
| Godot `res://tests/test_physics_instrumentation.gd` | 180-tick observer/worker/duplicate/hard-floor cases plus stored-Water and one-cell ejection checks | Exit 0; the test deliberately passes when the known barrier-crossing characterization remains reproducible. |
| `mingw32-make test` with pinned Clang | Current worktree, native Debug suite | 56/56 pass. Exact masked-Sand result is `3` downward contacts, raw `y=4800`, stored Sand retained. F01/F02, seam, sleep/re-entry and worker contracts pass. Existing conversion/unused-capture warnings are retained in the raw log. |

No 30/120-second, mass/orientation, excavation, desktop-async or Web campaign was
rerun: the ordinary current-source fixture fails before three seconds and source
inspection proves the required mechanism absent. Broader execution cannot turn
that implementation state into A, B or C.

## Documentation validation

`tools/ci/check_m11_consistency.py` passes all 18 historical records and 28 source
hashes, and `tools/docs/retrieval_eval.py` finds every canonical answer within its
top-k results (`22/32` at rank one, MRR `0.8229`). `git diff --check` also passes.

`tools/ci/check_docs.py` and therefore `tools/ci/check_repository.py` retain the
base commit's unrelated failures: the issue #19 Water-feel experiment is not yet
classified in the retrieval corpus, and seven frozen-question sources point to
files absent from this checkout. The repository aggregate additionally reports
the pre-existing Windows/Linux native artifact provenance drift for eight source
inputs. The #11 audit itself has an explicit exclusion entry and introduces no new
reported documentation error. Raw outputs are retained beside the runtime logs.

## Effect on issue #12

Issue #12 may proceed with candidate diagnostics, connectivity/rest measurement,
ownership design and other work that does not assume a supported Rapier barrel.
It may also rely on the existing sampled-player packing query and Rapier hard-terrain
contact within their documented scopes.

Support-dependent stationary-proxy integration and the one-island/one-barrel
support/reversal proof remain blocked. #12 must not treat the closed issue as proof
of excavation-sensitive granular bearing, correct masked contact, or barrier-aware
displacement. An explicit narrower #12 scope decision could avoid that dependency,
but administrative closure alone cannot.

## Minimal follow-up scope

Freeze one ordinary rectangle contract before implementation: an 8x14, mass-1
barrel dropped one height onto a flat, deep Sand bed must peak/finalize within the
approved embedding envelope, remain supported without a hard floor, and move again
after a bounded bed excavation. The affected path is
`CyberNativeCellWorld::prepare_rigid_body_coupling` and its overlap/contact helpers,
plus `World::update_cell`/`update_rule_kernel` contact semantics and the Rapier result
application owner.

The package must select one material/packing-aware support owner; correct masked
source attribution; reject or retain barrier-blocked ejection without deleting
compact state; and add three source-matched regressions: ordinary Sand support,
excavation release, and one-cell barrier non-crossing. Dependencies are ADR-007/009,
issue #9 telemetry and issue #10 material capability. Non-goals are #12 ownership
transfer, structural integrity, generalized shapes, torque, new CCD/substeps,
fracture, ballistics and broad retuning. Passing that narrow screen would unlock
support-dependent #12 integration; only then should the wider original #11 stress
and platform envelope be reconsidered.
