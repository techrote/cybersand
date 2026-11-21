# Independent R3 Windows build and runtime custody checkpoint

**Verdict: GO for the retained Windows cross-build and runtime source custody only. Overall admission remains HOLD/pending.** No P1/P2 defect was found in this bounded evidence review. This is not a final Windows graphical, evaluator, publication, scientific or merge approval.

## Exact identity

| Item | Reviewed identity |
| --- | --- |
| Repository / integration PR | `techrote/cybersand`, Draft/HOLD PR 715 |
| Frozen implementation | `79b8a0a4a1c2ace435d709b35114ee7065c935e6` |
| Qualification execution source | `96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f` |
| Execution source tree | `a3312e00b971cf6859922b2b70eb8ed5da0f66b7` |
| Native definition | `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7` |
| Accepted main ancestor | `846fe0533b3170e7b01f690518da49fc40cc24d1` |
| Qualified workflow / attempt | `swarm45-mainline-qualification.yml`, run `44953582341`, attempt `1` |
| Runtime artifact | `14726647933`, `swarm45-windows-runtime-44953582341-1` |
| Runtime ZIP | 10,226,912 bytes; SHA256 `16f729d519019089becf566e71d19acd355b7f4bb1dcdf42d3afdf87bda3d794` |
| Build evidence artifact | `14726234776`, `swarm45-windows-build-evidence-44953582341-1` |
| Build evidence ZIP | 104,840 bytes; SHA256 `f381c157b234c1c47b80367913db7ea44552eb441f2863fc8daaf4d50c9105cf` |

The reviewer independently retrieved the run and its artifact listing from GitHub. Both retained ZIP digests, sizes, artifact IDs/names, repository, branch, run and source SHA match that listing. All ZIP members have safe unique paths, and all extracted bytes equal their corresponding ZIP members: 11 runtime members and 9 build-evidence members. The runtime artifact contains nine inventoried payloads plus the two original provenance manifests.

## Checks performed and outcomes

The reviewer read immutable Git blobs at the execution commit, independently reconstructed the complete configured inventory, and compared every recorded hash: **1,763 build inputs, 147 native inputs, 106 extension inputs and 43 native-definition inputs all match.** The native definition was separately recomputed from the exact ordered path-and-byte concatenation used by the native build, not inferred from the receipt's declared value. The adapter candidate's original native input ledger equals the runtime manifest's extension ledger. The retained build record's complete source identity equals the actual clean source identity.

The original runtime manifest SHA256 is `fbeee25f6723166d1beeac3ead33de73f97dd941f9c454d2a55506521285dee5`. Every payload digest and size matches it. All eight retained executables/libraries have AMD64 PE headers. The CLI embeds the expected `217bfa…` native definition. The production runtime verifier also passed in explicit inspection mode (`same_run=False`), which verifies source/bytes without pretending that this reviewer is a hosted test execution. The manifest separately binds the actual hosted producer run and attempt, retains its original build commit, and records owner visual acceptance as pending.

The source-built Windows adapter is 5,844,992 bytes with SHA256 `c7fc1fbfea2999489ae83a6da100ca795b336dc6efa251af7e5003071a2bb43d`. The standalone Windows CLI is 3,100,672 bytes with SHA256 `001672a6961c113f51b4f483e33cbb97702fec09616a60949c26a991a5a18105`. Their original provenance was neither retagged nor rewritten for this review.

All six retained build-command records have return code zero and matching raw log digests: pinned Godot C++ build, adapter, strict reciprocal build, strict process fixture, strict authoring-patch syntax, and linked authoring-patch executable. The strict compile flags are present in the actual command/log evidence. Logs complete normally and contain no error or skipped-test success substitution. The pinned compiler preparation step and Windows cross-build job are independently reported successful by GitHub. The cross-build ran on `ubuntu-24.04`; this alone is not a claim of Windows execution.

Git history confirms that the execution commit is the sole request-only child of the frozen implementation, and the sole changed file is `.github/swarm45-mainline-request.json`. The retained request hash matches that committed file. Accepted main, frozen donor #700 and the immutable `10fe808ac7f6a4b9c07f7d168763b41957359e57` control anchor are ancestors. The five fixed final-admission workflow files and runtime-publication workflow remain byte-identical to that reviewed anchor.

## Evidence limits and outstanding gates

At this checkpoint, GitHub records the actual Windows native test step as successful on a `windows-2022` runner. Its detailed native result/log artifact is not yet retained here, so this is an API-observed step result, not completed independent review of its assertions. Both Windows graphical jobs were still running when the API snapshot was taken.

The remaining review must inspect the Windows native result logs; source graphical lifecycle and accepted-main smokes; pristine extracted evaluator graphical lifecycle and smokes; actual owner ZIP and current handoff identities; Linux strict/sanitizer/graphical/control evidence; all eight publication candidate paths and the actual publication commit; and all five final workflow results. The physical owner original-map/NVIDIA evaluation remains a separate pending admission gate. No unfinished or skipped gate is recorded as PASS.

The previously assessed P3 offline documentation-link limitation is unchanged. A primary current evaluator handoff beside the unchanged exact ZIP and on PR 715 is acceptable; final delivery review must verify its actual source/package hashes and immutable runbook link.

## Retained audit evidence

- `swarm45-publication-review-evidence/r3-windows-build-runtime-api.json`: independent GitHub run, artifact and job snapshot.
- `swarm45-publication-review-evidence/r3-windows-build-runtime-checkpoint.json`: verified binary inventory, source-ledger counts, six command/log records, exact identity and pending gates. SHA256 `f76a547ba7eacf60ccf73da7fc842621656f4ff5da2f4b296f8c3c971daba107`.

This review was read-only with respect to repository source, branches, PRs and CI. Only reviewer evidence outside the repository was written. No SWARM006 source or evidence was changed.
