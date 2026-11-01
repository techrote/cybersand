---
title: GCR admission evidence files and reductions
status: Current
document-kind: evidence
scope: File routes, raw archive integrity and reproducible read-only reductions for the source3d admission experiment
canonical-for: []
last-reviewed: 2026-11-01
related-documents: [../../2026-11-01-gcr-admission-qualification.md, ../../../operations/granular-contact-admission-plan.md]
---

# Evidence files and reductions

The [qualification audit](../../2026-11-01-gcr-admission-qualification.md) owns the disposition. This directory contains compact observations and original qualification receipts. [Scope and limitations](scope-and-limitations.json) distinguishes Windows-only physical acquisition, Linux scoped gates, recorded source identities, geometric floor flags and unsupported measurements.

[Primary](primary-summary.json), [async](async-summary.json), [controls](controls-summary.json), [replay](replay-summary.json) and [timing](timing-summary.json) summaries cover237 captures. Native/query/oracle/adapter gates are separately recorded in [mechanical-gate.json](mechanical-gate.json) and [native-qualification.json](native-qualification.json). The [host receipt](host-qualification.json) and [selected actual-host motion](host-physical-summary.json) retain their source3d plus four publication-delta scope. Human acceptance remains unrecorded.

[Timing detail](timing-detail.json) is the unchanged original reduction. Its generic sentence about differing GDScript sources does not apply to this pair: timing and primary reference both record source3d. There are39 supported exact telemetry-on/off comparisons and six unsupported R2 heavy/stream comparisons. [Retained R2](R2-retention.json) and [heavy/stream retention](R2-heavy-stream-retention.json) are separate comparisons across explicitly different source/native identities. They are selected physical observations, not full cell-state equivalence.

[Heavy allocation](heavy-allocation.json) uses the retained source73 R2 full ledger and source3d A1 ledger. Its fixed count-proportional allocation observations do not establish a dominant cause or a counterfactual result. [Late motion](late-motion-summary.json) is descriptive and adds no rest/sleep gate.

The [raw receipt manifest](raw-receipt-manifest.json) retains every original capture/log hash. The [archive record](raw-archive.json) identifies the local ignored compressed bundle; [member hashes](archive-member-manifest.json) include237 original capture pairs, qualification logs/failures/scripts and26 separately labelled historical R2 references. Raw logs, binaries and archives are not committed. [Failed preflights](failed-preflight-index.json) retain their original status.

After extracting the ignored archive at a checkout with the recorded source and current analysis tools, the following commands reduce existing data. They do not launch Godot or native simulation. Output paths remain under ignored `build/`.

```powershell
python tools/experiments/export_gcr_admission_evidence.py --campaign primary=build/admission-primary/campaign.json --campaign async=build/admission-async/campaign.json --campaign controls=build/admission-controls/campaign.json --campaign replay=build/admission-replay/campaign.json --campaign timing=build/admission-timing/campaign.json --output build/reduced-admission
python tools/experiments/analyze_gcr_admission_timing.py --timing build/admission-timing/campaign.json --reference build/admission-primary/campaign.json --output build/reduced-admission-timing.json
python tools/experiments/compare_gcr_admission_replay.py
python tools/experiments/compare_gcr_admission_controls.py
python tools/experiments/compare_gcr_admission_r2.py --reference historical/gcr001-final-primary/campaign.json --successor build/admission-primary/campaign.json --output build/reduced-R2-retention.json
python tools/experiments/characterize_gcr_admission_heavy.py --r2 historical/gcr001-final-primary/sync-heavy-90-GCR-r0.json --a1 build/admission-primary/sync-heavy-90-GCR-A1-r0.json --output build/reduced-heavy-allocation.json
python tools/experiments/describe_gcr_admission_late_motion.py build/admission-primary/campaign.json --output build/reduced-late-motion.json
```

Portable wrappers retain the physical projections of their original ignored helpers. [Reduction tools](reduction-tools.json) records published tool hashes and projection checks; the archive also preserves the original helper bytes. [Artifact manifest](artifact-manifest.json) hashes the committed evidence files separately from the original raw bundle.
