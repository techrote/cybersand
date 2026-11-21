# Independent actual R3 publication and final-dispatch checkpoint

**GO: the actual eight-path runtime publication and the bounded final-workflow dispatch are verified. No P1/P2 publication or dispatch finding. Overall admission remains HOLD pending separate final-CI review and physical owner acceptance.**

This closes the actual-publication scope left open in the preceding independent R3 Windows/evaluator review. It does not approve Ready, merge, auto-merge or physical acceptance.

## Published source and payload identity

| Item | Verified identity |
| --- | --- |
| Published integration commit | `919134a39d31461947c410c233d59d1965c48414` |
| Published tree | `78d6df75cb3534238c81b40e7bcdbe0cf693d012` |
| Sole parent / publication request | `a7c0a6d42f4a41622faf183c01818ffb73c56899` |
| Original qualified build/source | `96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f` |
| Original qualified source tree | `a3312e00b971cf6859922b2b70eb8ed5da0f66b7` |
| Native definition | `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7` |
| Actual publisher run | [44956855133](https://github.com/techrote/cybersand/actions/runs/44956855133), attempt 1, success |
| Reviewed publication artifact | ID `14727612467`, SHA256 `271294630bcd8282cdc1c4914392d8a24a39defc034ab125f1b9f2794440f14c` |

The reviewer independently read Git commit/tree objects and GitHub's commit/run/job metadata. The request is a sole child of the qualified source, changing only `.github/swarm45-runtime-publication-request.json`. The publication is a sole child of that request and changes exactly the eight permitted paths, with no additional source delta.

All four committed JSON files are byte-identical to the reviewed publication candidate. All four binary Git blobs are exactly the canonical LFS pointer for the candidate payload's SHA256 and size. The Linux CLI has Git mode **100755**; the remaining seven paths have mode **100644**.

| Published binary | Payload SHA256 | Bytes |
| --- | --- | ---: |
| Windows native adapter | `c7fc1fbfea2999489ae83a6da100ca795b336dc6efa251af7e5003071a2bb43d` | 5,844,992 |
| Linux native adapter | `1db5702cf59f02d1ca4b6e7c0b34a73f3d106e67cec73b4901c0c10cd4c1cbb1` | 5,278,840 |
| Windows reciprocal CLI | `001672a6961c113f51b4f483e33cbb97702fec09616a60949c26a991a5a18105` | 3,100,672 |
| Linux reciprocal CLI | `a3690011da97b12a6bfdc8d461e33dde9f98c1418fef89a3f3de994bd239da53` | 1,312,360 |

Both adapter provenance records and both CLI bindings retain the original qualified source/build commit, original source tree, native definition and pending owner status. None is retagged as a new binary build at the publication commit. All 1,763 configured build inputs and the native/extension/definition ledgers remain equal to the qualified source.

The independently fetched publisher job log records successful bounded staging, the eight-file commit, **four of four LFS object uploads**, and the leased push from `a7c0a6d42` to `919134a39`. All publisher steps conclude success. Its original admission receipt identifies the successful original qualifier run/attempt, exact candidate artifact and matching committed request hash.

The local checkout currently contains LFS pointers for all four binaries. This review does not infer local execution or claim those files are materialised. The qualified artifact payloads were separately verified, and the actual publisher log supplies the upload evidence.

## Bounded final dispatch

[Dispatcher run 44957145764](https://github.com/techrote/cybersand/actions/runs/44957145764), attempt 1, succeeded at control commit `c7e3f577d0fdfb1d49d03593f7df2ee5b4873bee`. GitHub independently confirms that commit is the sole child of `395b93393adcc379dabeffeb75be9eb19557ad33` and changes only the explicit final-admission request.

The original dispatcher artifact contains exactly five accepted HTTP 204 requests and independently discovered matching executions, all targeting `919134a39d31461947c410c233d59d1965c48414` on the integration branch:

| Fixed workflow | Exact-head run |
| --- | --- |
| Documentation | [44957191341](https://github.com/techrote/cybersand/actions/runs/44957191341) |
| Native C++ | [44957198003](https://github.com/techrote/cybersand/actions/runs/44957198003) |
| GDExtension | [44957204571](https://github.com/techrote/cybersand/actions/runs/44957204571) |
| Palette shader qualification | [44957211504](https://github.com/techrote/cybersand/actions/runs/44957211504) |
| PLAY desktop packet | [44957219135](https://github.com/techrote/cybersand/actions/runs/44957219135) |

The dispatcher receipt preserves the original source/publication chain, exact eight-path artifact identity and Draft PR lease. It expressly records `source_branch_mutated=false`, `ready_or_merge_authorized=false`, owner acceptance pending, and admission pending until execution results are reviewed. Successful dispatch is not recorded as successful final qualification.

## Current handoff and remaining gates

The reviewer checked the publication fields of the additive handoff manifest `published-source-provenance-r3.json`, SHA256 `805ebd2893a157b87e50e6aadc2008e51822448ea877b6ea991c8efd245228b3`. Its eight path/blob/mode/payload records equal the independent Git inspection. The native reviewer separately owns the full donor/scientific/defaults interpretation of that manifest.

At the independent PR snapshot, PR 715 is open, Draft, mergeable, unmerged, with no auto-merge configuration; its head is `919134a…` and base/main remains `846fe0533b3170e7b01f690518da49fc40cc24d1`. This is a snapshot, not permission to ignore a later base or head change.

Final workflow completion/evidence must still be reviewed separately. The physical owner original-map/NVIDIA gate remains pending regardless of automated CI results. The already-qualified exact owner ZIP and its current guide can be handed to the owner now with this HOLD stated explicitly.

## Retained review evidence

- `swarm45-publication-review-evidence/r3-actual-publication-checkpoint.json` — SHA256 `bd39848ba627071e915624bb66c629c64345d600af16f9bd53accf6463e10323`.
- Independently downloaded publisher receipt ZIP — SHA256 `74912918e7191d68189d6d01e40f06d0c7727212354191693e9699299ac45cae`.
- Independently downloaded dispatcher receipt ZIP — SHA256 `b8b523de73bc06fd08a9de2216730c259aa2274774a484ce39aefbe6f9f99b6f`.
- `r3-publisher-job.log`, `r3-actual-publication-api.json`, `r3-actual-publication-github-git.json` and `r3-final-admission-initial-snapshot.json` retain the independent hosted/Git observations.

No repository source, branches, PRs, CI configuration or SWARM006 material was changed by this reviewer. No additional workflow was triggered.
