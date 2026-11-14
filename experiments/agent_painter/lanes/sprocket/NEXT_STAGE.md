# SPROCKET next-stage structural curriculum handoff (proposal only)

**Status:** NOT NATIVE-ADMITTED; NOT A TRAINING REQUEST; NOT A BENCHMARK FREEZE.
**Owner:** Sprocket lane in [issue #568](https://github.com/techrote/cybersand/issues/568). Review/selection and shared corpus admission belong to the shepherd and independent reviewer. PR #576 remains Draft/HOLD.

## Evidence and scientific rationale

The independently re-audited original [96-step training](https://github.com/techrote/cybersand/actions/runs/43563494771) used 12 native-positive TRAIN seed rows but only **six independent structures**. The strict [DEVELOPMENT comparison](https://github.com/techrote/cybersand/actions/runs/43536717867) admitted 1/6 unique step96 generations (2/12 seed views). Genuine [native replay](https://github.com/techrote/cybersand/actions/runs/43543003937) changed 620 cells per host view but **failed** the requested vertical room/shaft geometry. Syntax/optimizers/native painting are not artistic conformance. Do not repeat old-corpus dose sweeps.

The following **18 candidates** are *composition hypotheses*, not teacher examples, compiler-valid programs, native-admitted cases, or structural novelty proofs. Each would require an actual model-target-independent version-2 program and positive native Art material replay. Candidate IDs are local proposals, not official corpus IDs. Do not copy an existing held-out DEVELOPMENT design into TRAIN. Sealed FINAL targets/images must not be opened.

## Six proposed Greeble composition groups

| ID | Distinct composition | Semantic/visual witness |
| --- | --- | --- |
| G01 | Dominant cassette plus two small service clusters around a broad access void | Unequal panel hierarchy, three separated clusters, continuous negative-space channel |
| G02 | Four independent corner assemblies surrounding a large empty central opening | Four isolated clusters and central void; axis-aligned panels |
| G03 | Cantilevered vertical cassette spine, progressively offset, with open side bays | Several stacked panel levels and clear lateral negative space, not simply repeated ribs |
| G04 | Nested pair of differently sized inset/plate hierarchies | Distinct nested composition, not just changed border/density |
| G05 | Two remote machine banks with repeating narrow-rib motifs and open center gap | Mirrored bank silhouette and maintained open access, no implied pipe connection |
| G06 | Step-diagonal *placement* of orthogonal panels with one deliberately missing interval | Asymmetric panel grouping and substantial missing module; strictly side elevation |

## Six proposed connected Pipework composition groups

| ID | Distinct topology | Semantic/physical witness |
| --- | --- | --- |
| P01 | Branching tree whose lateral branch itself branches | Connected; cycle rank 0; at least two degree-3 junctions |
| P02 | Comb distribution tree with orthogonal trunk and three outlet teeth | Connected; cycle rank 0; three distinct branch nodes |
| P03 | One closed rectangular circuit with a terminal spur from a corner | Connected; cycle rank 1; exactly one terminal spur |
| P04 | One closed ring with external branches at two different corners | Connected; cycle rank 1; two terminal branches |
| P05 | Two orthogonal loops meeting at one explicit junction, plus a terminal spur | Connected; cycle rank 2; no accidental contact or undeclared crossing |
| P06 | Four-cell orthogonal service mesh with perimeter and internal junctions | Connected; cycle rank 4; no hidden intersections |

Every proposed Pipework program must use explicit nodes/edges, declared connected=true and cycles 0–4, a **uniform diameter** selected from 3/5/7/9, and no overlapping ambiguous segments. Verify physical centerline continuity, junctions, endpoints, cross-section and loop count against genuine native readback. Do not count a different seed, thickness, scale, position or wording as a new structural group.

## Six proposed orthographic Architecture composition groups

| ID | Distinct composition | Semantic/physical witness |
| --- | --- | --- |
| A01 | Horizontal utility hall with three unequal side alcoves | Central corridor plus three attached openings; requested geometric clearance |
| A02 | Open machinery well crossed by a supported walkway, with side service bays | Spanning platform, distinct support/room geometry, clear negative-space well |
| A03 | Open-air courtyard void framed by separated low building masses | Multiple distinct masses, central empty region, explicit doorway route |
| A04 | Horizontal transit gallery with alternating upper/lower maintenance recesses | Alternating alcove adjacency and uninterrupted central passage |
| A05 | Staggered standalone platforms connected by bounded stairs/supports | Separate platform/floor/support roles, stair geometry and clearance |
| A06 | One-sided excavation with two projecting supported gantries and perimeter exit | Gantry/support relationships, large open void and exit |

All geometry must be exactly axis-aligned 2D side elevation. Do not infer jump/climb/gravity playability from mere cell-clearance checks. Each composition must pass independent reviewer split analysis: these proposals are **not established as disjoint** from existing TRAIN/DEVELOPMENT/FINAL structural groups.

## Shared native admission and evaluation requirements

1. Shepherd selects/revises 18–36 *actually independent* TRAIN-only groups, aiming at 6–12 novel groups per family. Composition/topology, not random seeds or paraphrases, defines independence. Review against public TRAIN/DEVELOPMENT and permitted partition metadata without opening sealed FINAL targets/images. No per-lane replacement benchmark.
2. Produce strict version-2 JSON, within 96-unit integer grid, 12-component and bounded-operation/cell-work limits. Require real first-pass compiler acceptance; do not repair invalid model completions or falsify native samples as teachers.
3. Rebuild source-specific native Godot/Art. Execute **two deterministic host seeds per group**, independently verify real applied/changed material cells, protected regions, Stop/history, native receipts, complete readbacks and original PNGs. Compiler-only plans or synthetic fixtures are not positives.
4. Freeze one source-qualified public TRAIN manifest, source/renderer/receipt/compiler digests and exact group-vs-row counts with reviewer approval. Preserve the old 12 TRAIN / 12 DEVELOPMENT / 6 FINAL corpus and the historical trainer artifacts unchanged.
5. Separately freeze **3 families × 4 held-out structural assignments × 5 fixed formulations = 60 independent language requests**, exact prompts and host contexts *before* using any new candidate for selection. Distinguish 60 requests from seed variants; never use FINAL for tuning.

## Sprocket-specific version-2 migration gates (after shared admission)

- Retain the root Instruct kandivault/sprocket-500m at revision eb157d4ddddc4619e661d4a2426bb2dd000fc668, real upstream Jinja, EOS5, 182 exact LoRA projections, 4,739,072 rank8 trainable parameters, and portable-cpu-fp32-v1 / one-thread CPU math unless a new qualified version explicitly changes these.
- **Do not overwrite or reinterpret** historical campaign.py, audit_96.py, old checkpoint-000096, campaign request or any previously published data/source hash. Create separately named lane-owned v2 request/wrapper/workflow with fresh experiment lease, source/native/corpus/recipe hashes, short finite optimizer target and deadline, checkpoint cadence and failure/partial artifact retention.
- A new corpus or changed lane-source identity **invalidates full optimizer-state resume** from the original fresh96 historical checkpoint. If experimenting with copied historical weights, explicitly label **weights-only warm initialization** with a new optimizer/new stage; never claim it is exact-state continuation. The proposed fresh-parent vs copied-useful-vN matched comparison is conditional on genuinely useful vN existing.
- First run a measured small pilot. Keep all first-pass token IDs, true EOS, raw malformed completions, strict schema/compiler refusals, genuine gradients, frozen-base equality and atomic checkpoint readback. Expand optimization only on held-out evidence, not falling TRAIN loss.
- Use original unchanged DEVELOPMENT and the independently frozen expanded suite; score per distinct request and family, separate host-seed native results, and demand real source-built Art/material/PNG proof plus human visual acceptance before a useful vN freeze. Max two active hosted training VMs for this lane; one model per VM; never train solely because of an hourly tick.

**Disposition on 14 November 2026:** No newly native-admitted TRAIN groups, frozen 60-request suite, useful Sprocket candidate or authorized new experiment is created by this document. Keep Draft/HOLD, unchanged FINAL protection and no default provider promotion.