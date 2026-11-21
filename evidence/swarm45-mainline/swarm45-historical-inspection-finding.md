# Confirmed P2: historical saved evidence rejected after definition-pin changes

Date: 2026-11-21 UTC. Independent reviewer: `/root/swarm45_native_review`. Affected frozen source: `96cc2772b0b7cf8e273526d3efd081596be1ad85`, request `10fe808ac7f6a4b9c07f7d168763b41957359e57` (PR715).

**Confirmed P2 compatibility regression: previously valid saved construction evidence cannot be inspected after the native definition pin changes. Ordinary saved-map restoration remains correct.** This finding qualifies the earlier r2 source GO: its absence-of-known-P1/P2 conclusion no longer applies to historical inspection. Existing r2 execution evidence remains evidence for that immutable source; it does not resolve this newly reproduced defect.

## Cause and user-visible impact

`godot/scripts/workbench_reciprocal_protocol.gd:470` routes `load_saved()` through `decode_document()`. The decoder's identity loop around lines284–286 requires both native fingerprints to use the **current** compiled definition `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7`. Valid saved records from r1 retain their original `fe62e15412459c22c6f81e479fa1ff2917d7359d747581c9891b83fbf2f75618` fingerprints and are rejected with:

> Native evidence changed the qualified Gentek identity, definition or authoring fixture.

The rejection prevents **Inspect saved evidence** from opening the old construction's recipe, original source/CLI receipt, round previews, ownership/revision data, sockets, joints, and unresolved obligations. It occurs even for this transition's console-I/O-only native change. The original map, receipt, and evidence files are intact and correctly hash-bound.

The strict current-definition policy remains appropriate for live generation/admission. It is insufficient as a policy for discarding historical inspection under the requested historical-semantics preservation: the panel explicitly treats saved evidence as historical and requires a fresh generation for Apply. The integration runbook states that historical recipe semantics remain unchanged and that saved evidence is inspection-only (`docs/operations/swarm45-mainline-integration.md:110–112`); the authoring contract likewise describes hash-bound historical inspection (`docs/architecture/experimental-workbench-authoring-patch.md:207–210`). Current tests cover same-definition save/reopen but not this upgrade boundary.

## Reproduction using genuine retained records

I copied three genuine **hosted-r1 Windows-source** saved triples without modifying their original bytes:

- Transaction: `transaction/.../workbench/setup-swarm004-interactive-evaluation.json`.
- Reciprocal example: `reciprocal/.../workbench/setup-swarm004-interactive-evaluation.json`.
- V3 Irregular: `swarm005_irregular/.../workbench/setup-swarm005-v3-irregular-evaluation.json`.

The full original paths and per-file hashes are in `hosted-inputs.json`. Each triple consists of the ordinary map plus the appended `.swarm004.json` receipt and `.swarm004-evidence.json` document. All map/evidence/proposal SHA bindings agree, and receipt/document/FRAME/MOSAIC source labels all equal the original request commit `9b688aed1f06f031f983c27f50d1f17821446e43`.

A minimal isolated Godot4.7 project loads unmodified protocol files extracted directly from r1 `a08c0e7` and r2 `96cc2772`, plus the unchanged palette helper. Results:

| Genuine saved case | r1 protocol | r2 protocol |
|---|---|---|
| Transaction, 12,288 evidence cells | Accepts | Rejects at native-definition identity |
| Reciprocal, 12,288 evidence cells | Accepts | Rejects at native-definition identity |
| V3 Irregular, 21,504 evidence cells | Accepts | Rejects at native-definition identity |

The identical pattern was separately reproduced on three original local preflight saved triples. These parsing reproductions were bounded to 30 seconds per process and completed in about 4 seconds. They launched no native generator and held no World or controller authority. Hashes of every original and copied triple were rechecked afterward and remain unchanged.

## Ordinary native World restoration is independently preserved

I also ran the **unchanged existing UI reopen fixture** in a new copied preflight project with the exact committed r2 protocol, against the copied genuine hosted-r1 transaction map and its retained expected native plane. This was a local Linux/headless diagnostic using the existing GCC14 native adapter; it is not a new hosted or physical-owner result.

The ordinary **Load start** completed, retained the authored edit history, and restored the entire 512×512 native material plane byte-for-byte. Both expected and reopened plane SHA-256 values are:

`2a7166559b1e23af4a2324ebe088db99727d045c1564da62d79f803939c02fc6`

Only the subsequent historical-inspection step failed. The fixture exited 1 after 37.965 seconds with exactly two failures: historical evidence did not open, and the overall sequence therefore did not complete. No map/plane/history assertion failed. Diagnostics show a settled native World, no worker failure, reciprocal phase `idle`, no active thread, and child PID −1.

Source tracing agrees: `shared_workbench.gd` ordinary `load_setup()` reads the saved setup independently of `Protocol.load_saved()`. The evidence path is entered only by the explicit inspector action. This is **not** saved-map corruption, a failure to reconstruct the native World, or a new Apply-authority bypass.

## Minimal repair requirements

The root has assigned implementation separately. This reviewer made no source repair. The appropriate narrow solution is a dedicated historical-only path for explicitly reviewed compatible schema 5 definitions, while leaving live decode/current identity admission unchanged.

- Preserve the original map, receipt, raw evidence bytes, source labels, CLI hash, and both typed Gentek fingerprints. Do not rewrite old definitions to the new pin or regenerate old evidence.
- Require a known historical definition, the exact FRAME/MOSAIC names, version 0, authoring fixture and prefixes, matching definition suffixes, and all existing source, size, resource, mask, structural, map/evidence/proposal hash checks. Unknown/mixed/SWARM006 definitions remain refused.
- Keep historical results explicitly inspection-only. The original native `can_apply` field is historical evidence, not controller permission. Apply/attestation must remain unavailable until a fresh admitted generation; an old controller Undo lease must not be repurposed by loading history.
- Handle #693's known older format deliberately: donor `16a11ef2...` uses schema 5 and definition `57ff699bf5c9833a2a5e2198ff2ef0b07cfd051069013776e6427f1e9d6694ec`, with the same typed identities and limits, but omits both SWARM005 option fields. Historical absence may mean false only for that known format. The live decoder currently requires actual Boolean option fields; it must stay strict. Donor #697/580 uses definition `12a4816d...` with the SWARM005 fields.
- Regression coverage should retain these genuine old triples, exercise old/current/unknown/mixed definitions and tampering, prove that live decode still refuses old definitions, and verify no Apply/attestation/Undo authority is created by inspection.

#693 format facts above were verified from immutable donor source, not from a genuine #693 saved triple. Crop 256×128, output 32 MiB, receipt 1 MiB, and existing native work/solver/resource ceilings need no increase.

## Retained evidence

Evidence directory: `/workspace/scratch/038267c40e11/swarm45-historical-inspection-review`.

| File | SHA-256 |
|---|---|
| `hosted-inputs.json` | `09c890f0401b4e7c024821ceb14f6b8176a05f0c6df4fab6e07fb57a08b12152` |
| `hosted-result.json` | `1286493f670f76f74a516d61e372fcf9811e0028fbdf61b7c8a0dcd277288c09` |
| `hosted-run.log` | `a79a631313a46e59b39545c7f579bc38f34750bcf248301fa1d07a893d23a4f6` |
| `result.json` | `c8c6be7b3375906f41ca1bb453c34b9c6ae6e6ffaa8711c3bc5ce554e0bac11b` |
| `run.log` | `1400abab1d8269230835e76c384579183ef5a6d8313823fbfafd24cb6ca4ee89` |
| `ordinary-restore/reopen.json` | `7e39a7f232781e59a572223521534982656d2257cb9c2018ad96f136e6644462` |
| `ordinary-restore/reopen.log` | `468a9bd8eb764722935d6410c15b2d3bb59217576190cfe0a9a0b18b59d61165` |
| `ordinary-restore/execution.json` | `a600aea7cbcdaf5f0778f9be8ef12120d2f4205d7f20421af90f7c98b47faedd` |

The copied protocol hashes are r1 `5bfe67fe0e3b4587e584bd45f5e7a003ad796ed319a54ba420b8e760c9cf1694` and r2 `8c1e392a108884e1d6a4340d80c9ddf2b6a2b0e28e2d4d9b934ea50927f1ef72`. No repository source, original saved record, donor, or remote state was changed by this investigation. Independent repair review and affected requalification are still required before closing this P2.
