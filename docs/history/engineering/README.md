---
title: Engineering archaeology historical index
status: Historical
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Dated M1 capture; no current instructions or execution permission
last-reviewed: 2026-11-14
---

# Engineering archaeology historical index

**Historical, non-authoritative; deliberate research only.** This archive preserves engineering knowledge and source provenance. Old words such as “Approved,” “Current,” “must,” schedules and acceptance gates remain dated source statements. They do not instruct ordinary coding agents, authorise work or reinstate abandoned obligations.

The [M1 report](REPORT.md) is the entry point. The [separate owner-intent record](../../decisions/2026-11-14-owner-authoring-intent.md) preserves explicitly confirmed present direction. The [#571 plan/authorization record](https://github.com/techrote/cybersand/issues/571#issuecomment-6871615830) authorises this isolated capture, not merge, new successor issues, retirement, broad documentation changes or implementation.

## What was captured

At **2026-11-14 04:19:41 UTC**, accepted main was `ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`. The full individual assessment scope is **274 open records**: 271 frozen M0 items plus #580–#582. Another **308 closed or merged records** are indexed as a reference universe; they have not all been individually excavated. Important closed bridges are followed in the family analyses. See [deltas.json](deltas.json) for later source movement; this is a time-qualified capture.

| Record | Purpose |
|---|---|
| [Report](REPORT.md) | Findings, corrections, limitations, opportunities and readiness |
| [Individual coverage view](views/coverage.md) / [coverage.json](coverage.json) | Every item, justified depth, separate ticket/idea/code/evidence fates, transfer and protection |
| [Salvage and negative knowledge](views/salvage.md) | Reusable algorithms, tests, methods, original results and failed approaches |
| [Historical doctrine](views/doctrine.md) | Scope, rationale, changes and five explicit validity classes |
| [Opportunity inputs](views/opportunities.md) | Thematic synthesis candidates; no successor issues created |
| [findings.json](findings.json) | Maintained typed finding store; views above are generated |
| [Schema and maintenance](SCHEMA.md) | Depth, provenance, transfer semantics and generation commands |
| [Evidence custody](evidence/manifest.json) | Originals actually recovered, hashes, recovery locations and explicit gaps |
| [Independent challenge](qa/review.md) / [validation receipt](qa/validation.json) | Checks performed, defects corrected and practical limits |
| [Frozen M0 report](sources/m0-report.md) / [inventory](sources/m0-inventory.json) | Earlier evidence baseline, preserved with additive M1 corrections |

## Family routes

| Lane | In-scope items | Subfamilies | Analysis |
|---|---:|---:|---|
| Simulation and materials | 112 | 12 | [Soliding, contact, liquids, pressure, performance and materials](families/simulation.md) |
| State, persistence and authoring data | 60 | 7 | [Carriers, areas, recording, maps, capture, generation and Flatten](families/state.md) |
| Runtime and creative composition | 85 | 15 | [Actors, presentation, Workbench, agents and painter research](families/runtime.md) |
| Governance and provenance | 17 | 4 | [Remediation, investigations, coordination and owner authority](families/governance.md) |

## Retrieval boundary

Default repository retrieval excludes `docs/history/` and `docs/audits/`, including aliases and tagged historical copies. It does not expand document links. Explicit historical search uses its own [manifest](retrieval-corpus.json), and every resulting chunk carries `historical-non-authoritative`, `explicit-history-only` and a warning that it is not a current instruction. Imported old status labels cannot override that envelope.

For deliberate research from the repository root:

```bash
python3 tools/docs/retrieval_eval.py --historical --queries docs/history/engineering/retrieval-questions.json --output /tmp/cybersand-history-retrieval.json
```

This command reads evidence; it does not implement findings or grant later-phase permission. External importers must preserve the authority envelope and rebuild older caches. A directory name and prose warning cannot control arbitrary third-party crawlers. Current documentation still contains known stale claims; their full reconciliation is a separate authorised programme.
