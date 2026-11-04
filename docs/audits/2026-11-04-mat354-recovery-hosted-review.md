---
title: MAT-AUTH-002 recovery independent hosted evidence review
status: Current
document-kind: evidence
scope: Independent authentication of PR377 hosted ordinary campaigns and retained Windows failures; no production implementation or merge admission
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-mat354-findings.md, 2026-11-04-mat354-correction-admission.md, ../operations/material-liveness-investigation.md]
---

# Independent review of recovered hosted evidence

## Disposition

**PASS for the latest source-qualified ordinary Linux/Windows native evidence.**
The recovery audit downloaded the GitHub artifacts directly, checked their ZIP
digests against GitHub's artifact metadata, reran the current independent reducer
and scientific reader on every original trace, independently compared all source
inventory records against raw Git blobs, and compared every physical tick across
operating systems. The ordinary two-OS qualification gap described in the stale
PR body is closed by existing run41817101140. A new ordinary campaign is not
needed merely to republish these unchanged test inputs and evidence.

This is a Phase A evidence decision. It neither implements the proposed cooling
correction nor admits a production change, merge, default change, thermal law,
perpetual generic retry policy, or compatibility-lock refresh. PR377 remains
draft/open/unmerged and issue354 remains open.

## Verified source and current checks

The PR head and branch ref both resolved to
`1a06a0d88d295ed99983e7b1f6149b9fff84f1b3`, tree
`b1991936cd998e0c0f6caed04d6fc06150e0a559`, during this review. Accepted
production main is `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`.
Comparing these commits finds no changes under native/src, native/include, or
materials/catalogue/compatibility-lock.json.

[Run41817101140](https://github.com/techrote/cybersand/actions/runs/41817101140)
completed both focused jobs successfully. Documentation/provenance run41817101158
and native source-scope advisory run41817101146 also passed at that head.
Broad Native, GDExtension/Godot and palette workflows were **skipped**, not
passing native/runtime results. The hosted logs record95 focused apparatus tests
passing on each OS.

| Evidence | Linux | Windows |
|---|---|---|
| Job ID | 126530507905 | 126530508677 |
| Artifact ID | 13315146918 | 13315116917 |
| Artifact bytes | 8,249,249 | 7,905,128 |
| Source commit | 1a06a0d88d295ed99983e7b1f6149b9fff84f1b3 | 1a06a0d88d295ed99983e7b1f6149b9fff84f1b3 |
| Native cases | 552 | 552 |
| Owner steps | 88,384 | 88,384 |
| Matching worker/repeat groups | 261 | 261 |
| Four-worker distributed cases observing4 actual claimants | 8/8 | 8/8 |
| Raw Git input records checked | 67/67 | 67/67 |
| Actual compiler dependency inputs checked | 38/38 | 38/38 |
| Authenticated process stdout/stderr files | 1,116 | 1,116 |
| Independently authenticated compiler dependency files | 4 | 4 |

Linux artifact ZIP SHA-256:
`07897edcf0c30f763e68db56f8cf5a6c29177db7efeedaae8fbeaf67f562332a`.

Windows artifact ZIP SHA-256:
`88259c361f917f4e71ae62bb36411c8d9e86f3b2ee32a6a37d0f2e7d7dc0baaf`.

Both broad input inventories and actual compiler dependency inventories match
exactly across the two hosts. Their shared input-inventory SHA-256 is
`fc9086a283492fd51cd08e101606d62a59688dbd5c617f792982e618478e8796`.
Each recorded compiler dependency was independently recovered from the original
four .d files, normalized only as a *path*, and matched against the corresponding
raw source byte hash. Source text received no line-ending normalization.

The independent audit compared all88,384 tuples of
(reset_epoch, world_tick, physical_hash) across all552 matching cases, with zero
mismatches. Every reducer trajectory digest also agrees. This establishes
physical-state parity for the registered native cases; scheduling diagnostics
and wall time are not assumed identical.

## Preserved Windows failures

**Run1 remains a failure before native execution.**
[Run41812690658](https://github.com/techrote/cybersand/actions/runs/41812690658),
Windows job126515609434, used source
`cabc93ee40bf8afb9d5adba5a95d4640101b96b3`. Its apparatus stage ran80 tests:
two failed and five were skipped. The failures were
test_actual_dependencies_resolve_from_compiler_directory_and_require_world and
test_output_cannot_overwrite_checkout_or_previous_attempt. The logs show the
Windows long/short-path alias disagreement, then explicitly state that the
campaign did not start. Native compilation and both native observation/reduction
steps were skipped. There is no552-case Windows result at this source.

Artifact13312609131 is324 bytes and contains only hosted-context.json.
Its ZIP SHA-256 is
`f69fa3e1d47bc4b8d889bc56e70587fbc2dd004962845f820b9d5c6bf53d0d98`.
The recovery retains this original context, decoded job log, job-step metadata
and artifact identity.

**Run2 remains unqualified for raw source bytes.**
[Run41813960884](https://github.com/techrote/cybersand/actions/runs/41813960884),
Windows job126519889664, used source
`594a79bf184df60d0c2b61b63cc68ebf8e5af887`, tree
`1204a1e8842bcddfa9785a37c143ec30aca11f6c`. It did execute all552 cases.
The original process outputs, receipts and independent scientific reduction
authenticate, and all88,384 physical tick tuples match the latest Windows
campaign. These observations remain useful.

However, independently checking all67 inventory entries against that commit
finds **eight raw-byte mismatches**: Makefile plus seven actually compiled
native includes:

- native/src/world_inertial.inc
- native/src/world_pressure.inc
- native/src/world_pressure_cache.inc
- native/src/world_pressure_cache_state.inc
- native/src/world_pressure_gas_cache.inc
- native/src/world_pressure_state.inc
- native/src/world_quantity.inc

In each case, applying LF-to-CRLF conversion to the committed bytes reproduces
the receipt's recorded length and SHA-256 exactly. Normalized agreement does
not establish raw-byte qualification. The original receipt's older
source_qualified=true is preserved as historical data; it is explicitly
superseded by the independent **FAIL** source decision. No original receipt is
rewritten.

Artifact13312958982 is7,965,858 bytes, ZIP SHA-256
`57d0bb99c649baa8ca5376f9c36986d7002750e6a57a01edd3cbc7693134be4d`.
All raw traces, its original receipt/reduction, context, compiler dependency
files, transport shards and original decoded log are retained.

## Transport and limits

All three retained native campaign transports were decoded independently.
For latest Linux, latest Windows and failed-source Windows run2, all11 shards
and1,122 contained files authenticate and reproduce the downloaded original
bytes exactly. The source failure of Windows run2 persists after transport;
successful packaging does not qualify that attempt.

This review verifies native fixture execution and evidence custody. It does not
establish graphical acceptance, production gameplay acceptance, leak freedom,
or independent physical hardware replication. The hosted machines have distinct
recorded hostnames and CPU descriptions; their underlying physical placement
is not established. Ordinary campaigns are not sanitizer executions. Native
executable hashes are retained, but executable bytes were intentionally excluded
from these evidence artifacts.

The independent scientific reader continues to distinguish source-derived
indefinite thermal fixed points from finite traces, whole-World aggregate
counters from cell-specific singleton observations, and generic resting policy
from Water-CY's stronger separately tested retry obligation.

## Remaining publication work

Publish the authenticated raw transports, compact independent reports and
retained failure evidence; update the stale PR description and issue354 with
the verified state. Bind any new documentation-only publication to the tested
source1a06a0d and explicitly verify that executable inputs are unchanged.
Preserve honest custody limits for older local evidence that cannot be recovered;
fresh replacement executions must have their own identity and must not relabel
earlier failures. Keep the proposed protected-source scheduler correction at its
separate owner/compatibility authorization boundary.


## Reproducing the independent source and trajectory audit

Restore the latest ordinary transport bundles to linux/campaign and
windows/campaign beneath a chosen audit root. Preserve each hosted-context.json
beside its platform's campaign directory. Rerun reduce.py and analyze.py with
--raw-root against those restored campaigns, producing
linux-reduction-verified.json, windows-reduction-verified.json,
linux-analysis-verified.json and windows-analysis-verified.json at the audit root.
The independently retained verify_hosted.py then accepts explicit locations:

```sh
python verify_hosted.py \
  --repo /path/to/cybersand \
  --audit-root /path/to/restored-hosted-evidence \
  --output /path/to/new-independent-audit.json
```

The checkout must contain recorded commit1a06a0d and its Git objects. The output
must be new; the script refuses overwriting a prior audit. Its own SHA-256 is
included in the output. This audit was rerun once after adding these portable
arguments; the result remains PASS with the same source, inventory counts and
full trajectory parity. It does not execute a new native campaign.
