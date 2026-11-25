# Independent review of the coordinated CI wave

**APPROVE Ready qualification** of source `e85b1f73d5649158bc628834d169917d5d60ff16`, tree `209c5521024d0c4d5cfa96b9a4aa5eee4a37cf88`. This review does not approve merging until every required resulting-source hosted gate passes.

The candidate preserves #771 original `911a3448e8e331cb097f1654bf861e20d77f57ca`, accepted main `be87b18b30506ccead610c7035ae1ffa8e65a347`, and exact #778 donor `585520e7e62b67ce8c4c86605b08e1f8cc920bba` through two ordinary ancestry-preserving merges. The 34-file delta is CI, tooling and documentation. Native, production Godot and third-party source/pins/runtimes are byte-identical to accepted main. The already accepted Palette concurrency line is absent from the remaining delta; no GDExtension fanout or RAM-first experiment is adopted.

## Source and negative-control review

The reviewer inspected the complete #778 acquisition/planner/reducer change and both #771 helper implementations. Godot acquisition changes only the route to the same locked bytes. The stale 24-shard test assumption is replaced by source-derived bounds and a 400-case/25-shard witness, while the original 16-case cap, expected cost, full watchdogs, hosted matrix ceiling and eight concurrent jobs per platform remain unchanged. Both coverage reducers reject missing or failed planning before invoking malformed commands. Actual coverage and original-log verification are retained.

Campaign coordination remains GET-only and distinguishes original run/attempt/source, reported success, missing/partial/non-atomic snapshots and owner qualification. It cannot dispatch or cancel any run. The publication helper requires an external contract pin, the exact same captured bytes that are parsed, original report/log joins, canonical local LFS objects, exact branch/index leases and a publication-only child. Its output explicitly denies publication authority, remote-LFS proof and semantic qualification. No active programme publisher has been migrated by this candidate.

## Independent executed checks

| Check | Actual result |
| --- | --- |
| Source-derived Godot planner | 12 methods PASS |
| Campaign coordination, `python3 -O` | 28 methods PASS |
| Publication custody, `python3 -O` | 39 methods PASS in 17.878 seconds |
| Direct Bash reducer predicates | 12 controls PASS: valid 1/25 counts admitted; empty/zero/negative/leading-zero/spaced/non-numeric counts and failed/skipped/cancelled/missing plans refused |

Optimized-Python execution confirms the helpers' decisive refusals survive removal of Python assertions. Separate source inspection verified no native/product dependency input changed. B owns additional full local policy/provenance tests; this record independently complements those results without substituting for hosted Native/GDExtension/Palette and documentation gates.

## Remaining gate

Run one complete applicable Ready cohort for this source, preserve all original failures, and review the actual complete job inventory, source/attempt bindings and required coverage reducers before merge. This combined tooling wave avoids two redundant heavyweight campaigns while retaining each donor identity and rollback path. Physical owner acceptance remains separate for product programmes.
