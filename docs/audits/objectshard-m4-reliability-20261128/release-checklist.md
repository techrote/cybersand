---
title: ObjectShard M4 reliability evaluator release checklist
status: Historical record
document-kind: audit
scope: Exact-source qualification, portable Windows archive custody and independent delivery review for the 28 November convergence candidate
canonical-for: []
last-reviewed: 2026-11-28
related-documents: [presentation-delivery.md, physics.md, ../../operations/objectshard-workbench-playtest.md]
---

# Source-bound evaluator closure

**Disposition: Qualified Draft/HOLD for physical owner evaluation. Source b7d889b925ab3244d10e6fe48f487fbe0dc1ce73, combined campaign 46103413203, exact-source runtime publication and independent evaluator verification passed.**
This checklist records the concrete evidence required for delivery. A passing
early renderer fixture, successful DLL build or generated archive does not
replace the actual final checks recorded below. Physical owner acceptance is separate.

## Source and publication custody

| Gate | Required record | Current state |
| --- | --- | --- |
| Accepted integration baseline | Accepted-main commit, merge parent, qualified application commit and tree. Preserve any later reconciliation requirement explicitly. | Accepted baseline `9920e7a7369f24e2818313c007cc33616c1a6a83`; source/tree are in [delivery-record.json](delivery-record.json). Later Strata main requires reconciliation. |
| Native input freeze | Exact final application commit/tree, complete native input ledger, pinned godot-cpp/toolchain identities and production request sequence. | Final source frozen; all 126 native production inputs verified; request sequence 4. Truthful no-op edit correction and its regression are integrated. |
| Guarded production publication | `[objectshard-m4-publish]` on the existing integration branch, expected-head lease held until terminal result; no merge or Ready operation. | Passed at publication `d5bb74cdc8b3350ea85ba7899e46d6d0038074b8`; principal verified exact b7 parent, four paths and unchanged binary/manifest identities. |
| Linux/Windows runtime tuple | Produced binary size/hash, native build source, test source, manifest hash, successful producer run/attempt and guarded publication commit. | Both validated producers and published files independently reconciled: identical source/tree, 126 native inputs and 1,378 build inputs. Package DLL equals the published Windows DLL. |

The final report must distinguish the qualified application/build/package
source from the later guarded four-file runtime publication commit. Any later
documentation-only evidence commit must be identified separately. An arbitrary
runtime copied from another candidate is not an admissible substitute.

## Combined execution gates

| Gate | Receipt and observations to inspect | Current state |
| --- | --- | --- |
| Native correctness | Native sanitizer/contact/coordinator/ordinary-World campaign, material compatibility transition, exact-source ledger. | Final b7 passed 131,759 native assertions, 192 World tests, 85 Python contracts, 231 material contracts and 74 retained budget limits; no hosted skips. A independently checked all 133 native-suite input hashes. Earlier failures remain preserved. |
| Linux source | `headless/qualification.json` and `graphical/qualification.json`, each successful and source-bound; actual native/Rapier identities. | Final exact-source Linux job passed. B retained the validated producer and independently checked its source, full ledgers, binary and execution logs. |
| Windows source | Same primary and actual ANGLE graphical receipts, including ordinary Workbench painting, Water, actors/equipment, pause/resume and authored reopen. | Passed and independently audited: 65 headless cases plus 52 mixed graphical-profile cases (28 rendered, 24 headless helpers). |
| Physics regressions | Low-inertia fragment, natural native-ACK chain, sparse retained parent, remote/fresh barrel, moving edits, truthful paused brush revision, quantity conservation, Lab Sand lodging/Water extinguishing and existing collapse/lifecycle tests. | Passed in final source and clean extracted replay; A independently reviewed 44 selected physics receipts and exact native/fixture hashes. |
| Throughput | Disabled/empty/tower/stress/sleeping, recording off/on, exact source/native, admitted/awake cohorts and clocks. | B owns matched measurements; all rates remain scoped to their actual headless/hosted/physical environment. |
| Material rendering | Actual preparation positive Wood/Empty proof and resource retirement; exact shared shader reuse; ordinary/detached crop/rotation/material parity and texture incarnation identity. | Final b7 actual Linux/Windows material smoke passed (13 preparation, 28 parity/view, 11 identity and 27 shader guards). Final extracted preparation/parity/identity replay also passed. |
| Mounted presentation | Actual Workbench camera lifecycle receipt, positive native RG8 identity, active/paused/Held view/clip coherence, resize, Restore, scene replacement and preparation status. | Final b7 early native Windows camera226/brush159 passed with 246/233 positive renderer callbacks, zero incoherence and seven independently reviewed full Workbench PNGs. Final extracted camera226 also passed with 247 positive renderer observations, zero incoherence and seven inspected mounted captures. |

The camera fixture writes full Workbench PNGs to
`camera-lifecycle-captures/` in both actual source graphical and extracted
qualification outputs. Required views include `active-overview.png`,
`active-pan-zoom.png`, `paused-pan-zoom.png`, `paused-resize.png`,
`held-pan-zoom.png`, `held-resize.png`, `restored-paused-before-play.png`,
`lease-cropped-active.png`, `held-lease-far-pan.png`, `held-lease-resize.png`
and `scene-replacement.png`. The Held fixtures deliberately inject protective
holds; they do not reconstruct the owner's original cutting sequence. The
1,024-cell active-lease case preserves exact retained image bytes, material
publication, native tick and lease while navigating outside its initial crop.

Independent visual review must inspect the shipped application captures,
including the leading actionable Held text, material appearance and World
letterboxing. A synthetic 64×64 material swatch does not replace those views.

## Portable Windows archive and extracted execution

| Gate | Required record | Current state |
| --- | --- | --- |
| Immutable inner archive | `objectshard-workbench-evaluator.zip`, exact byte count and SHA-256, source commit/tree and package manifest. | Passed: 96,694,450 bytes, SHA-256 `04308deb50e8044054c624a4adf200a04bc1b7c8034621e0576338b79009d8e7`; artifact `15249152001`. |
| Actual normal launch path | `launcher/result.json` successful for clean spaces, parentheses, Unicode and nested roots; each executes `Verify Workbench.cmd` and `Open Workbench.cmd --self-test`. | Passed: all four actual Windows probes, 73 checks each; independent review joins each to the immutable inner ZIP. |
| Launcher applicability | Same shipped graphical executable, ANGLE flags, actual `feature_launcher.tscn` to ordinary `main.tscn`, Tower scene, real native/Rapier progression and acknowledged poses. | Passed: actual shipped graphical engine/ANGLE, startup path, source/native identity and acknowledged progression are present in all four receipts. |
| Tamper/provenance refusal | Altered payload, unlisted loadable input and candidate/retained/source provenance controls refuse specifically; original ZIP hash unchanged afterwards. | Passed: eight provenance refusals plus altered-payload and unlisted-input controls; immutable ZIP unchanged. |
| Pristine package replay | `package-replay/qualification.json` successful, every Godot input located inside the clean extraction, engine and native hashes match shipped manifest, actual mounted camera and material captures retained. | Passed: 32 cases, five rendered and 27 headless, all actual command paths inside the clean Windows extraction. |
| Independent download | Verify GitHub artifact digest before extraction; independently hash inner ZIP and execute trusted-source package verifier against a separate extraction. | Passed: C verified both API digests, extracted independently, checked 1,484 files and full source/runtime custody; root independently repeated the package verifier. |
| Runtime reconciliation | Compare packaged DLL and candidate input ledger against Windows producer receipt and guarded published runtime/provenance; separately verify Linux published hash. | Passed: package DLL `a4b75f…cc503` equals the validated/published Windows DLL; published ELF `059c58…53fe4` and both manifests match producers. Full hashes are in the delivery record. |
| Owner entry and instructions | `Open Workbench.cmd` normal entry; packaged `READ-ME.md` equals the committed current playtest guide. Tower is selected without developer configuration; recording defaults off. | Passed: exact source guide and generated launcher bytes match; Tower and opt-in arguments are verified from actual execution. |

The workflow already supplies the shared 1,200-second graphical watchdog to
each shipped CMD process. Individual fixture operations use 300 seconds. No
allowance was expanded for material preparation. The observed software ANGLE
cold preparation is reported separately from subsequent semantic progression
and physical display performance.

The trusted checkout verifier can be run without executing the Windows engine:

```text
python tools/objectshard/verify_workbench_package.py /absolute/path/to/independent-extraction
```

That command proves file/provenance consistency only. The actual Windows
launcher receipts and pristine replay establish execution. Retain the source
workflow URL, artifact download URL, artifact digest, inner ZIP identity,
manifest hash and verification output together in the final delivery record.

## Owner route and remaining authority

Source review confirms the guide's exact controls: **Structures…** is between
**Art batches** and **Batch Lab…**; **Water Lab…** precedes the camera selector
and **−/+** controls. The mode selector contains **Cut moving**, **Ignite
moving** and **Settle into canvas**. The Structures panel places **Record
performance timings (optional)** below its five scenes, then **Save
diagnostics** beside **Open diagnostics folder**, with the result path below.
**Save start [Ctrl+S]** and **Load start** are neighboring drawing-row controls;
**Restore start** follows **Reset selected [R]**. The guide includes the first
**Preparing structure materials…** admission and a restart route for
**MaterialPreparationFailed**.

Every applicable engineering gate above completed. Delivery remains
**Qualified Draft/HOLD for physical owner evaluation**. The eight-awake-body
performance objective and later Strata/mainline reconciliation remain explicit. No physical TITAN RTX performance claim,
owner acceptance, merge or Ready promotion follows from hosted qualification.
