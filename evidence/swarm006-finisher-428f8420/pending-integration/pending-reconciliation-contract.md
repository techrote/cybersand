# Pending accepted-main reconciliation contract — ca634458 projection

**Disposition: pending an actual accepted-main merge.** This is a read-only conflict and source-custody projection, not an integration, an approval of PR715, or a donor-to-accepted-main mapping. PR715 is still open, Draft and unmerged. No candidate source was checked out or imported; no candidate executable was materialized or run. Only Git objects, manifests and LFS pointer records were read. The two `merge-tree --write-tree` calls created unreachable simulation trees containing unresolved conflicts.

## Live admission facts and exact comparison inputs

Read-only GitHub API observations at **2026-11-21 22:43:36 UTC** and **22:50:34 UTC** agree that accepted main is unchanged. PR715 advanced from the head originally supplied for this task to a runtime-publication head. The second observation is retained in `github-final-recheck.json`; the first observation and PR body are in `github-observation.json`.

| Role | Exact commit or tree |
| --- | --- |
| Accepted main | `846fe0533b3170e7b01f690518da49fc40cc24d1` |
| Published SWARM006 successor | `ca63445888d818ed868f71869abb37ae4d00975e` |
| Published successor tree | `0ae689ea2757dbeee926ffac692a8e46f65a1862` |
| PR715 frozen source | `79b8a0a4a1c2ace435d709b35114ee7065c935e6` |
| PR715 frozen-source tree | `db1393c21a5e58137f06e6b6008f1001775da89f` |
| PR715 reported qualification execution, request-only child | `96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f` |
| PR715 live, unaccepted publication head | `919134a39d31461947c410c233d59d1965c48414` |
| PR715 live tree | `78d6df75cb3534238c81b40e7bcdbe0cf693d012` |
| Requested ca634458 / 96b8 unresolved simulation | `4ba29d767e60dd76721378d96d76c4d654e37c4e` |
| Current ca634458 / 919134a unresolved simulation | `eff7ed15cf588a4e21bcb85cc0cdf64f29070828` |

Both simulations exit **1** with ten content conflicts. Both have two merge bases: accepted main `846fe053…` and shared Workbench donor `8ec6d3c62197f3ef4088d79e4aa2910f5eaa36f7`. Git recursively synthesizes those bases. Accepted main must not be substituted as the sole merge base when reasoning about additions and deletions.

The previous `pending-pr715-reconciliation/` directory remains unchanged. Its 8cf93e48 / 10fe808a projection is historical evidence. This directory contains a separate **230-path** inventory with mode, Git blob, SHA-256 and length for accepted main, shared donor, reviewed successor, published successor, frozen candidate, execution candidate, live candidate and both simulations. There are **73 projected changed paths** between ca634458 and the live unresolved simulation. The inventory records equal before/after HEAD, branch, index hash, ref inventory, clean status and hashes of the entire earlier report directory.

## What the newer PR715 head actually changes

Frozen source 79b8 to execution head 96b8 changes only `.github/swarm45-mainline-request.json`. Execution head 96b8 to live head 919134a changes one publication request and eight runtime records:

| Kind | Paths |
| --- | --- |
| Publication request | `.github/swarm45-runtime-publication-request.json` |
| Adapter LFS pointers | `godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so`; `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll` |
| Adapter provenance | `godot/addons/cybersand_native/runtime-provenance.linux.json`; `godot/addons/cybersand_native/runtime-provenance.json` |
| Reciprocal CLI LFS pointers | `godot/tools/gentek_reciprocal`; `godot/tools/gentek_reciprocal.exe` |
| Platform CLI bindings | `godot/tools/swarm004-runtime.linux.json`; `godot/tools/swarm004-runtime.windows.json` |

All candidate definition inputs and implementation/test/loader/archive source bytes remain the frozen 79b8 source. The four manifests identify execution source **96b8**, tree `a3312e00b971cf6859922b2b70eb8ed5da0f66b7`, and definition `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7`. Their own scoped qualification and pending owner-acceptance labels are candidate metadata, not independently accepted evidence in this projection. `semantic-projection.json` retains the exact pointer text and compact manifest identities. No LFS payload was downloaded or executed.

## Conflicts and required additive resolutions

| Conflicted path | Reconciliation obligation after actual acceptance |
| --- | --- |
| `docs/README.md` | Retain SWARM004/005 mainline and SWARM006 entries with their separate admission scopes. |
| `docs/operations/cybersand-codex-development-handover.md` | Reconcile accepted baseline facts and pending successor work without rewriting historical outcomes. |
| `docs/operations/swarm005-workbench-playtest.md` | Preserve V3 owner controls and references while retaining the successor V4/inspection route. |
| `docs/reference/retrieval-corpus.json` | Retain both canonical owners and the explicit current/historical authority boundary. |
| `docs/reference/retrieval-index.md` | Route both programmes without replacing one with the other. |
| `docs/reference/status-and-roadmap.md` | Separate accepted 004/005 state, still-scoped 006 evidence and remaining owner gates. |
| `godot/scripts/workbench_reciprocal_panel.gd` | Combine input retirement, read-only inspection and platform loading with exact final/provisional selection and V4 controls. |
| `godot/scripts/workbench_reciprocal_protocol.gd` | Reconcile historical decoder boundaries and current definition binding while preserving V1–V3 and all V4/schema-6 refusal rules. |
| `godot/tests/swarm45_reciprocal_controls.gd` | Resolve the renamed shared controls test by retaining both actual typed-input coverage and 006 inspector/transport coverage. |
| `godot/tests/test_workbench_reciprocal_protocol.gd` | Retain historical/fresh decoding distinctions plus all 006 recovery/header/receipt/adversarial checks. This is the tenth conflict, newly present relative to the old projection. |

Native V4 additions do **not** disappear from the recursive simulation merely because they are absent on the candidate branch. That absence is not a deletion: the V4 files were also absent from the relevant common bases. The nine successor-only `.cpp`/`.hpp` definition inputs remain present. Likewise the simulation preserves the successor's exact `shared_workbench.gd` bytes, including its independently authored reciprocal busy guards. The two native extension host seams and `godot/scripts/main.gd` are byte-identical across successor, candidate and simulation.

### Input retirement and World ownership

The branches independently authored similar repairs. Choose one coherent implementation of each invariant, retaining the strongest already-reviewed coverage; do not duplicate callbacks merely to preserve both texts.

- Shared and independent numeric `LineEdit.text_changed` must retire an applicable preview immediately. Panel buttons commit the focused field before their action; direct Generate and Apply retain their defensive commit before admission. New seed must commit pending text before incrementing it.
- The first admitted territory/protection press retires authority before changing points. Candidate `_finish_gesture()` checks `_dragging` before clearing it; the current successor sets `_dragging=event.pressed` before its inline release handler. **Combining that assignment with the candidate helper would clear the flag before the helper and lose gesture completion.** Resolve the release lifecycle as a whole, including release outside the canvas.
- Retain the successor's reciprocal-specific `SharedWorkbench._world_input` guard before Paint routing and `art_history_guard` refusal. The candidate panel's local busy consumption follows visibility/territory-mode checks; it cannot replace the shared guard for hidden/OFF mode or World Undo/Redo. Preserve ordinary Paint, its active-stroke/cancellation routing and focused text Undo.
- Preserve complete authority retirement on failed runtime admission, source/history changes, child failures and reset. Keep the immutable previous request snapshot intact when replacing prepared data.
- Retain actual `swarm006_reciprocal_input.gd` and its required seven-case, 20-plane, five-native-pair gate in source, pristine-package and Linux preservation routes. Do not substitute programme-level phase assignment or a dropdown model for actual keys, mouse, Apply, live child, Paint and history behavior.

### Renamed test routing is a separate clean-merge hazard

PR715 renames `test_workbench_reciprocal_controls.gd` to `swarm45_reciprocal_controls.gd` and `test_workbench_reciprocal_ui.gd` to `swarm45_reciprocal_ui.gd`. The simulation removes the old paths. The 004/005 consumers update automatically, but these two 006 references remain stale without a textual conflict:

- `tools/swarm006/qualify_workbench.py`: `controls-native` still names `test_workbench_reciprocal_controls.gd`.
- `tools/swarm006/qualify_preserved_workbench.py`: `controls-inspector` still names that removed file.

After resolving the test contents, route both consumers to the chosen extant file and update exact script inventories/expected process records together. Retain the `SWARM004_CONTROLS` completion contract, V1–V4 transport coverage, Materials pixel/native pick checks, final-only layer behavior and existing 006 report keys. Preserve the candidate's actual pending shared/independent text and return-to-V2 checks. Keep the separate 006 UI and input tests, source/profile isolation and all qualification refusal tests.

## Historical Inspect and current transaction authority

PR715 r3 introduces an explicit saved-definition decoder and a persistent historical-only latch in the panel. Its reviewed saved list includes `57ff699b…`, `12a4816d…`, `fe62e154…` and its current `217bfa71…`. The published 006 protocol already supports inspection of exact `57ff699b…`, `12a4816d…` and `afbae85a…` historical definitions, in addition to current `72779688…`, and validates schema 5 or 6 according to the reconstructed request.

These are overlapping compatibility contracts, not interchangeable decoder implementations. The future combined path must retain exact map/receipt/evidence hashes, identical FRAMEWEAVER/MOSAIC definition identity, bounded resource limits, schema-specific controls and original raw `can_apply` evidence. Only the specifically reviewed old schema-5 SWARM004 format may interpret its missing 005 options as false under the candidate rule. Do not broaden the current live decoder to arbitrary old definitions or silently relabel saved JSON. Validate the compatibility of each retained definition/schema pair before adding it to the combined inspection whitelist, including the accepted candidate definition and the superseded 006 definition.

Historical inspection must remain read-only across edits, cancel/reset and failed replacement generation. Actual Apply, direct submission/attestation and construction Undo must not acquire authority from a loaded save. Only a successful fresh generation using the combined current definition, actual runtime and current source capture may restore transaction authority. The candidate latch and 006 phase checks can be reconciled, but neither branch's safety property may be dropped.

There is **no newly reproduced historical-inspection defect in ca634458**. Our separate actual old-707/current-006 probe retained a genuine `afbae85a…` saved triplet, passed 76 current UI checks including final and three provisional round pixels/picks, denied both actual-button and direct Apply and preserved World/history. That receipt is at `../historical-inspection-dev-attempt2/historical-inspection-final-receipt.json`; the earlier launch refusal is retained separately. Other historical pins had source/synthetic coverage, not newly executed historical UI cases. Future merged compatibility must be tested on its own source.

## Platform manifests, archives and custody

The candidate loader prefers `swarm004-runtime.<platform>.json`; it falls back to generic `swarm004-runtime.json` only when the platform file is absent. A present stale or malformed platform manifest fails closed. It additionally validates platform and any declared native definition. Preserve this refusal behavior when accepted.

**A mechanically merged SWARM006 owner package would retain a stale preferred manifest.** The accepted candidate's Windows manifest would bind definition217/source96b8. Current `tools/swarm006/package_owner.py` installs the new 006 CLI and writes only the generic `swarm004-runtime.json`. The candidate general archiver retains the Windows platform manifest, so the loader would prefer the old binding and reject the new CLI. A generic manifest must not silently override it. Reconcile `package_owner.py`, `seal_owner.py`, `owner_launcher.ps1.in`, `compare_saved_setup.ps1`, their fixtures and exact package inventories so the chosen platform-specific binding is replaced atomically with the rebuilt combined CLI, and every advertised manifest agrees. Exercise no-environment source/package loading, stale-present refusal and opposite-platform refusal.

The two archive repairs are complementary. The successor's `*.import text eol=lf` fixes checkout and archive bytes for all four tracked Rapier import descriptors and is included in preservation source-input custody. PR715's `committed_archive()` passes child-only `core.autocrlf=false` and `core.eol=lf` while preserving explicit per-file attributes, binary data and import sidecars; its Windows stager excludes the Linux CLI and binding. The simulated attributes retain both the successor import rule and the candidate's explicit CLI LFS rules. Preserve actual committed bytes, Windows `.bat`/`.ps1` rules, target-platform LFS validation and Linux executable mode. Do not change Git configuration or normalize execution hashes to conceal edits.

Candidate source tests stage verified installations outside the checkout; that is a distinct harness architecture. The successor currently enforces raw source inputs, tracked-import/asset/source rejection, retained refusal evidence and a terminal source/runtime identity recheck after graphical consumers. Any future staging adoption must retain those guarantees, changed-file negative tests, stage inventories and final identity comparison. It must not turn generated UID handling into a broad source exclusion.

## Native SWARM005 accounting versus SWARM006 recovery

Four native/build files auto-merge relative to ca634458:

| Path | Projected delta and necessary qualification |
| --- | --- |
| `native/experiments/gentek_swarm/reciprocal_mosaic.cpp` | Replaces fixed receptor-scan estimates with bounded charged record/cell visits; validates finite planes/masks/footprints, checks cancellation, and charges actual finalization traversals before publication. Retain atomic refusal and unchanged original ceilings. This shared path can affect V3 and V4 initial/reciprocal receiver work and remaining proposal allowance. |
| `native/experiments/gentek_swarm/swarm005_research_tests.cpp` | Adds maximum-footprint accounting and pre-cancelled/atomic-refusal controls. These test bytes also participate in the definition fingerprint. |
| `native/experiments/gentek_swarm/reciprocal_main.cpp` | Five console sites switch to C stdio for the candidate Linux symbol floor. Preserve the successor's V4 parser and transport routes; console changes still alter definition/source custody. |
| `native/experiments/gentek_swarm/Makefile.reciprocal` | Adds CPPFLAGS forwarding and the external known-005 replay target. Preserve all 006 core objects, strict/sanitizer suites, transport tests and complete-input fingerprint algorithm. |

The original 006 reserve-before-mutation/finalization-debit repair in `mosaic_recovery.cpp` is untouched by this textual simulation. That does **not** qualify its interaction with the candidate's shared 005 accounting. Rejected searches must consume their actual charged work without refunds; finalization must not overdraw the remaining allowance; failed/cancelled/exhausted proposals must not publish partial receptors or copied receipts attached to empty proposal planes. Previously selected snapshots remain intact. Exhausted/unavailable closure must not be described as a successful zero-unresolved result.

V1/V2 transport and options-OFF compatibility remain explicit controls. V3 retains its two opt-ins and schema-5 evidence; V4 retains negotiated recovery, schema 6, exact programme/identity, required offer policy, header-only admission-refusal handling, receipt/round/ledger constraints and existing solver/generator/capacity ceilings. No default, registration, policy or budget promotion is authorized by reconciliation. Known/revealed replay outcomes remain regression evidence, not a new holdout.

## Definition, binary and qualification renewal contract

| Source subset | Inputs | Computed native definition SHA-256 |
| --- | ---: | --- |
| Reviewed 8cf and published ca634458 | 52 | `72779688b897e4707d89ac1f6e692046abbc806bd27b4c129bd77fcd995093a0` |
| Candidate frozen79b8 / execution96b8 / live919 | 43 | `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7` |
| Both unresolved combined simulations, native subset only | 52 | `74e24ee632902655e1f5cb230300f430251b545cbec700df3b90d77537eb8438` |

The simulation definition is diagnostic only. The full simulated source is unresolved and unbuildable; no bridge should be pinned to this value until actual accepted reconciliation produces and independently reviews its exact native inputs. Recompute after any C++/header/test change rather than assuming this value survives.

Upon an **actual accepted-main merge**, the pending work is:

1. Revalidate live main and PR state. Record the actual accepted merge SHA/tree and its relationship to frozen79b8, execution96b8 and publication919. Fetch that accepted main into the owned successor only under the current integration authorization. Recompute all merge bases and record any additional accepted changes. The present simulation cannot substitute for that mapping.
2. Resolve the ten conflicts and clean-merge hazards additively. Keep existing main authoring/native seams and all 006 selected-round/input/receipt gates. Review the raw combined diff independently, including the shared 005 accounting/recovery interaction. Keep every donor, failed attempt and original registration unchanged.
3. Freeze the resolved source, complete source-input ledger, chosen test names and full definition inputs. Update the current protocol pin, exact expected identities and both platform manifests consistently. Keep old definitions only in their separately verified saved-inspection scope.
4. Build fresh source-matched Linux and Windows CLIs and adapter artifacts with the pinned toolchains/Godot/Godot-CPP/Rapier contracts. Record exact build/execution/source hashes and LFS pointer custody. Rebuild provenance or obtain explicit unchanged-input proof under the actual accepted-source policy; never relabel existing binaries or graft old success receipts onto new source.
5. Rerun applicable strict and sanitizer suites; V1–V4 parser/transport/refusal tests; receptor-scan and recovery-reserve regression cases; registered known/revealed 004/005 controls and the bounded 006 corpus with raw JSON and exact source/runtime inventories. Explain genuine counter, trace or terminal-outcome differences without hiding them through broad normalization.
6. Run actual Workbench control, inspector, typed-input, busy Paint/Undo/Redo, stale source/settings/runtime and tamper refusal gates; applicable positive Apply/Undo/Save/fresh-process reopen; negative non-Apply previews; historical saved evidence and fresh-generation recovery. Require full native planes, native selection/pick witnesses, exact report/raw round bindings and unchanged-world evidence for refusals.
7. Qualify the final source and genuinely pristine extracted Windows package; verify no-environment platform loading, manifest tampering, committed import/archive bytes and executable/LFS custody. Keep ordinary Paint/Water/Art/Flatten/actor preservation and terminal identity revalidation after graphics. Retain exact failed receipts. Refresh standard resulting-source checks and independent source/science/platform evidence review. Physical owner acceptance remains a separate pending gate; no Ready, merge or default promotion follows from this projection.

## Independent native review projected onto published ca634458

`native-source-review-projection.json` proves all **52** ordered definition labels, Git modes/blobs, SHA-256 values and current working bytes equal the independently reviewed 8cf inputs. Only two experiment-native files differ from the integrated foundation `5722f254144fb8bf84a94fa2881e8860c9512316`:

| Reviewed file | SHA-256 |
| --- | --- |
| `native/experiments/gentek_swarm/mosaic_recovery.cpp` | `ec9dbe6dd227b7b376763961c51b12b94ff7cb143f43e4999d3a6e2eec678850` |
| `native/experiments/gentek_swarm/swarm006_recovery_tests.cpp` | `f099a2841fdb78f5bbadfd418719a7ec04f7bf7cebfed776a85fcf3d2418ffc9` |

**Exact-source sign-off:** the independently reviewed reserve/debit/failure-receipt repair remains byte-identical at published ca634458. The original V1–V3 preservation conclusion for that two-file repair retains its exact scope. This projection does not approve the candidate receiver-accounting delta, the unresolved combined definition, a future resolved source, or a new runtime/platform result. No broad tests were rerun for this read-only task.

## Retained artifacts

- `github-observation.json` and `github-final-recheck.json`: live read-only admission observations.
- `simulation.json` and both `merge-tree-*.stdout.txt` / `.stderr.txt`: exact commands' results and ten conflict paths.
- `source-custody.json`: full 230-path additive source map, all definition inputs, host seams and unchanged checkout/historical-report proof.
- `semantic-projection.json`: relevant source identities, exact renamed-control routing and unmaterialized candidate runtime pointer/manifest records.
- `native-source-review-projection.json`: exact 52-input native review projection.
- `successor-to-simulation.diff` and `successor-to-requested_simulation.diff`: unresolved diagnostic diffs, never applied.
- `inventory.py`: reproducible Git-object-only inventory procedure.

All evidence in this directory is separate from the candidate branch and its campaigns. Accepted main is the sole reconciliation trigger.
