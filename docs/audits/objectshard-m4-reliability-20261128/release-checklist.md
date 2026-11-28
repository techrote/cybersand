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

**Disposition: Draft/HOLD. Final combined source and evaluator are pending.**
This checklist records the concrete evidence required for delivery. A passing
early renderer fixture, successful DLL build or generated archive does not
complete the remaining gates. Physical owner acceptance is separate.

## Source and publication custody

| Gate | Required record | Current state |
| --- | --- | --- |
| Accepted integration baseline | Accepted-main commit, merge parent, qualified application commit and tree. Preserve any later reconciliation requirement explicitly. | Accepted baseline `9920e7a7369f24e2818313c007cc33616c1a6a83`; principal records final source. |
| Native input freeze | Exact final application commit/tree, complete native input ledger, pinned godot-cpp/toolchain identities and production request sequence. | Final source pending ordinary-edit investigation and evidence integration. |
| Guarded production publication | `[objectshard-m4-publish]` on the existing integration branch, expected-head lease held until terminal result; no merge or Ready operation. | Principal owns the ref and trigger. |
| Linux/Windows runtime tuple | Produced binary size/hash, native build source, test source, manifest hash, successful producer run/attempt and guarded publication commit. | Fresh production campaign pending. Retained historical binaries do not qualify changed native source. |

The final report must distinguish the qualified application/build/package
source from the later guarded four-file runtime publication commit. Any later
documentation-only evidence commit must be identified separately. An arbitrary
runtime copied from another candidate is not an admissible substitute.

## Combined execution gates

| Gate | Receipt and observations to inspect | Current state |
| --- | --- | --- |
| Native correctness | Native sanitizer/contact/coordinator/ordinary-World campaign, material compatibility transition, exact-source ledger. | Pending final source campaign. First combined source failed the preserved shader byte guard; the reviewed transition fixes the next source only. |
| Linux source | `headless/qualification.json` and `graphical/qualification.json`, each successful and source-bound; actual native/Rapier identities. | Pending final source campaign. |
| Windows source | Same primary and actual ANGLE graphical receipts, including ordinary Workbench painting, Water, actors/equipment, pause/resume and authored reopen. | Pending final source campaign. |
| Physics regressions | Low-inertia fragment, natural native-ACK chain, sparse retained parent, remote/fresh barrel, moving edits, truthful paused brush revision, quantity conservation, Lab Sand lodging/Water extinguishing and existing collapse/lifecycle tests. | Registered in source and clean extracted replay; final executions pending. |
| Throughput | Disabled/empty/tower/stress/sleeping, recording off/on, exact source/native, admitted/awake cohorts and clocks. | B owns matched measurements; all rates remain scoped to their actual headless/hosted/physical environment. |
| Material rendering | Actual preparation positive Wood/Empty proof and resource retirement; exact shared shader reuse; ordinary/detached crop/rotation/material parity and texture incarnation identity. | Early actual Linux/Windows run `46096895793` passed. Final source and extracted replay still required. |
| Mounted presentation | Actual Workbench camera lifecycle receipt, positive native RG8 identity, active/paused/Held view/clip coherence, resize, Restore, scene replacement and preparation status. | Local final-COM headless replay passed 210 checks. Actual source and extracted renderer executions pending. |

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
| Immutable inner archive | `objectshard-workbench-evaluator.zip`, exact byte count and SHA-256, source commit/tree and package manifest. | Pending. |
| Actual normal launch path | `launcher/result.json` successful for clean spaces, parentheses, Unicode and nested roots; each executes `Verify Workbench.cmd` and `Open Workbench.cmd --self-test`. | Pending. |
| Launcher applicability | Same shipped graphical executable, ANGLE flags, actual `feature_launcher.tscn` to ordinary `main.tscn`, Tower scene, real native/Rapier progression and acknowledged poses. | Probe and verifier enforce this; final receipts pending. |
| Tamper/provenance refusal | Altered payload, unlisted loadable input and candidate/retained/source provenance controls refuse specifically; original ZIP hash unchanged afterwards. | Pending. |
| Pristine package replay | `package-replay/qualification.json` successful, every Godot input located inside the clean extraction, engine and native hashes match shipped manifest, actual mounted camera and material captures retained. | Pending. |
| Independent download | Verify GitHub artifact digest before extraction; independently hash inner ZIP and execute trusted-source package verifier against a separate extraction. | C owns this after the final artifact appears. |
| Runtime reconciliation | Compare packaged DLL and candidate input ledger against Windows producer receipt and guarded published runtime/provenance; separately verify Linux published hash. | Pending. |
| Owner entry and instructions | `Open Workbench.cmd` normal entry; packaged `READ-ME.md` equals the committed current playtest guide. Tower is selected without developer configuration; recording defaults off. | Source contract checked; final archive inspection pending. |

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

Delivery remains **Qualified Draft/HOLD for physical owner evaluation** only
if every applicable engineering gate above completes. Any failed, pending or
unsupported gate remains explicit. No physical TITAN RTX performance claim,
owner acceptance, merge or Ready promotion follows from hosted qualification.
