---
title: MAT-AUTH-002 stalled-session recovery and final Phase A qualification
status: Current
document-kind: evidence
scope: Recovered ordinary Windows/Linux evidence, fresh local sanitizers and protected controls, durable raw custody, independent review and source-qualified Phase A handover; no production correction or merge
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-mat354-findings.md, 2026-11-04-mat354-correction-admission.md, 2026-11-04-mat354-recovery-scientific-review.md, 2026-11-04-mat354-recovery-hosted-review.md, ../operations/material-liveness-investigation.md, ../reference/validation-evidence.md]
---

# MAT-AUTH-002 recovery and Phase A handover

## Delivered result and boundary

The stalled investigation is recoverable through draft
[PR #377](https://github.com/techrote/cybersand/pull/377). Its real-World fixtures,
source-bound apparatus and causal findings were already published. Recovery
finishes the missing evidence publication, independently authenticates the
latest Windows/Linux execution, replaces unavailable local qualification with
new recorded executions, and corrects stale retention claims.

**H1 is a confirmed scheduling omission. H2 is the existing mutual-heating law.
H3 is the existing generic resting policy, preserved pending any separate
gameplay decision.** The [findings](2026-11-04-mat354-findings.md) retain detailed
positive/negative controls and the
[ranked correction memo](2026-11-04-mat354-correction-admission.md) specifies the
finite next implementation. Neither production source nor its compatibility
guards, defaults, physics, runtimes or identity locks change here. PR #377 stays
draft and unmerged; #354 stays open for its separately admitted production work.

The investigation is scientifically qualified for the registered native scope.
One historical custody limitation remains: original prior-session local raw
bytes were never published and could not be recovered. Fresh evidence does not
retroactively repair that loss. The complete available evidence, original
published failure identities and this limitation are preserved together.

## Source identity and isolation

| Authority | Exact identity |
|---|---|
| Accepted production main | `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1` |
| Accepted production tree | `36ce5a01e754a141c321f41cac7f1c6b6059c371` |
| Recovered and executed apparatus source | `1a06a0d88d295ed99983e7b1f6149b9fff84f1b3` |
| Executed apparatus tree | `b1991936cd998e0c0f6caed04d6fc06150e0a559` |
| Retained legacy compatibility baseline | `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` |

Recovery used its own private Git clone and worktree. A second clean detached
worktree at the recorded apparatus commit supplied all new native executions;
source edits and generated output were kept separate. Other active checkouts
and experimental branches were inspected only for ownership and were not edited.

The final continuation changes documentation and evidence only. Its recorded
source-scope check compares all 67 campaign inputs and all 88 protected-control
build inputs directly to the tested bytes. All 27 compatibility-protected
production files still authenticate. Later publication commits are not relabeled
as the original execution commit, and historical source identities remain intact.

## Qualified executions

| Execution | Result | Source and qualification |
|---|---|---|
| Hosted Linux ordinary | PASS: 552 cases / 88,384 owner steps | Run 41817101140, job 126530507905; original raw streams and source bytes independently authenticated |
| Hosted Windows ordinary | PASS: 552 cases / 88,384 owner steps | Same run, job 126530508677; original raw streams and source bytes independently authenticated |
| Fresh local ASan/UBSan | PASS: 552 cases / 88,384 owner steps | Source 1a06a0d; explicit `--disable-leak-check`; LeakSanitizer unexecuted |
| Fresh local ThreadSanitizer | PASS: 552 cases / 88,384 owner steps | Source 1a06a0d; actual instrumented execution and independent reduction |
| Fresh protected controls | PASS: 12 invocations selecting 14 existing tests | Source 1a06a0d; 18 translation units, 88 recorded inputs, 70 actual compiler dependencies |
| Apparatus unit suite | PASS: 95 tests | Existing runner/reducer/analysis/transport tests; distinct from native physical evidence |

Each full campaign has 261 matching worker/repeat groups and eight distributed
capacity-four cases that observed four actual task claimants. Small fixtures
still expose only the amount of parallel work they actually generate.

The independent hosted audit authenticated 1,116 process stdout/stderr files,
all 67 broad source inventory entries and all 38 actual compiler dependencies
per OS. It reconstructed dependencies from the original `.d` files and checked
raw Git bytes without source line-ending normalization. Every one of the 88,384
`(reset_epoch, world_tick, physical_hash)` tuples matches across the 552 Windows
and Linux cases. The recovery comparison also authenticates the new sanitizer
trajectories against the ordinary Linux reference; its exact report is indexed.

| Execution | Executable SHA-256 |
|---|---|
| Hosted Linux | `639e33d63a047855cf3b9b0db4124575a07e1c296624c5edc602c1fecec24738` |
| Hosted Windows | `76dd3acd904e9e6fe2e45d0ec61814cf350b8a529a15c2809867125c5843f0b7` |
| Local ASan/UBSan | `f6b0af5f4706d1b65c31f082eb967d32bf5da81dae855ecd2859f52a50bfb0da` |
| Local TSan | `260674fb1ad7e53ebb454abffc1bdd13dd1076280e616a3e34cdcf6fa1cc26dd` |
| Protected controls | `7e55b18a769aab093c059522b2791e90b71b84cf1d0a9d29991a0f65891187b0` |

Original receipts retain compiler/version, complete flags, host identity,
limits, input inventories, binary size/hash, case arguments and every outcome.
Local sanitizer runs used the unchanged 60-second case, 900-second build and
1,800-second campaign bounds. Their elapsed totals include compilation and
evidence handling and are not native performance acceptance. Independent
physical hardware placement is not established by separate hosted OS jobs.

The protected controls cover persistent MAT-001 contact, Ice/deadline lifecycle,
mask/region/reset/discovery, inert rest, Mercury lanes, observer parity,
Water-CY retry/cadence/material hooks, pressure rest, worker publication,
Water IN pause and exact native quantity accounting. This is the selected
14-test set, not a full Native or Godot matrix.

## Independent review and causal interpretation

The [scientific reviewer](2026-11-04-mat354-recovery-scientific-review.md)
independently checked 21,484 singleton thermal transitions and 13,214 admitted
generic mobility draws directly against inspected native source, authenticated
all 1,104 case streams, and derived the worker/repeat and awake-neighbor
comparisons independently. The separate
[hosted reviewer](2026-11-04-mat354-recovery-hosted-review.md) owns cross-OS source,
artifact and full-trajectory authentication.

For H1, the first omitted cooling opportunities remain ticks 4/5/6/7 for phases
0/1/2/3. Both awake controls convert at ticks 720/717/718/719. Zero scheduled jobs
and zero actual subject entries distinguish an omitted visit from unchanged
rendering. H2's awake touching-pool controls really execute the heat-reset rule;
infinite retention is a source-derived fixed-point inference from finite traces.
H3's selected primary witnesses execute three mobility failures then rest;
awake Paste/Slush/Brine/Mercury first move at ticks 19/7/4/6.

Review added two explicit qualifications. Preserving generic rest is not new
owner approval of every material's late-rest desirability, especially Brine.
A future MoltenGlass cooling deadline can also admit more ordinary movement
opportunities while cooling remains eligible; its new trajectories and cost
must be qualified, even though the thermal formula remains unchanged.

No remaining scientific blocker to this Phase A handover was found. These
independent agent reviews are technical analyses, not human gameplay acceptance
or an external-account merge approval.

## Preserved failures and unavailable originals

| Attempt | Retained current disposition |
|---|---|
| Original local ordinary, source 23ca8074 | Historical reported FAIL: one truncated distributed-Paste raw file. Published expected/observed hashes survive; original receipt and raw bytes are unavailable. |
| Original local repeat | Historical reported FAIL: executable mode/spawn after 15 completed cases. Original bytes are unavailable. |
| Original local LeakSanitizer attempt | Historical reported environment FAIL. No leak-freedom claim; original raw bytes are unavailable. |
| Original checkout preflight refusal | Historical reported FAIL before compilation. No native execution; original temporary artifact is unavailable. |
| Prior local ordinary / ASan / TSan passes | Historical reported results only. Their published identities/reviews survive, but the current packet cannot authenticate the missing originals. |
| Hosted Windows run 41812690658 | Recovered FAIL before native compilation: two path-alias apparatus test failures; zero native cases. Original context, job log, job steps and artifact identity retained. |
| Hosted Windows run 41813960884 | Recovered 552-case observations, but strict raw-source qualification remains FAIL: Makefile plus seven compiled includes were CRLF. Original receipts/raw bytes are unchanged. |

For the second Windows run, applying LF-to-CRLF to the corresponding committed
bytes reproduces each recorded mismatch exactly. Its observations match the
latest trajectories, but that does not upgrade raw-source qualification. The
old receipt's `source_qualified=true` remains original historical data with an
explicit independent FAIL disposition.

Recovery checked the available scratch workspaces, the published branch/history
and saved-file candidates; no original local evidence bundle was recovered.
The stalled index is retained byte for byte. No synthetic reconstruction is
presented as the missing original. Any later recovery of those exact files must
authenticate the old receipt and preserve its original failure status.

## Durable packet and reproduction

The [evidence index](mat354-2026-11-04/evidence-index.json) identifies each lossless
transport manifest, source, receipt hash, qualification and independent review.
The packet includes both latest hosted campaigns, fresh sanitizer campaigns,
protected controls, recoverable Windows failures, complete independent analyses
and retained job logs. Native executables and object files are excluded.

To reproduce the latest Linux evidence reduction, choose a new output directory:

```sh
python3 tools/material_liveness/pack.py unpack \
  docs/audits/mat354-2026-11-04/recovery/hosted-linux/transport/linux-normal.manifest.json \
  /absolute/new/mat354-linux
python3 tools/material_liveness/reduce.py \
  /absolute/new/mat354-linux/campaign.json --raw-root /absolute/new/mat354-linux \
  --output /absolute/new/linux-reduction.json
python3 tools/material_liveness/analyze.py \
  /absolute/new/mat354-linux/campaign.json --raw-root /absolute/new/mat354-linux \
  --output /absolute/new/linux-analysis.json
```

Use the corresponding indexed manifest for Windows or either sanitizer.
The retained `verify_hosted.py` accepts `--repo`, `--audit-root` and `--output`;
the hosted review describes its restored directory layout. Historical Windows
run2's raw source audit is a separate required check: its older receipt alone
must not decide qualification. Packing or unpacking only authenticates transport.

The exact final documentation/provenance and retrieval results are retained in
the packet and final PR ledger. The unchanged native inputs are compared with
the executed source; documentation-only publication does not require another
ordinary 552-case run. Broad draft-suppressed Native/Godot/palette jobs remain
skipped. No production runtime publication is performed by this continuation.

## Documentation mapping and next admitted step

The findings, operational reproduction/custody guide, validation ledger and
handover are synchronized. The correction memo records the reviewed movement
consequence. An additive recovery retrieval fixture checks the custody and
source-qualified result boundary without changing the original eight MAT354
questions or frozen general/challenge questions. Native ownership, ABI,
configuration, capacities, user controls and physical contracts have no
implementation delta; their existing canonical homes still apply.

The next production task requires explicit admission for the narrow H1 repair
in protected `native/src/world.cpp` and its reviewed compatibility transition.
Retain the earliest necessary existing thermal lane using coalesced block wakes;
preserve hot-at-180 sleep, shared obligations, masks, region pause, worker
ownership, thermal law and generic retry policy. Revalidate current main and
shared #355/#347/#358 ownership before those writes. Runtime rebuilding,
publication and integration acceptance belong to that separate task.

This continuation records progress and stops at Phase A. It neither merges
PR #377 nor declares the broader #354 correction complete.
