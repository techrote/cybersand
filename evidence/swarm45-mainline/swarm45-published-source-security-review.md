# Independent published-source, protocol and security review

**Decision: GO for source/protocol/security continuity through published commit `919134a39d31461947c410c233d59d1965c48414`.** No new confirmed P1/P2 was found. The historical-inspection P2 remains closed at the exact published source. This is not a final ordinary-CI, physical owner, scientific programme or merge approval.

Review recorded 2026-11-21T22:40:44.436641+00:00. No implementation files, donor worktrees or remote state were changed by this reviewer. The tracked integration worktree matches the published commit.

## Exact publication boundary

| Role | Commit | Tree |
|---|---|---|
| Qualified r3 source | `96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f` | `a3312e00b971cf6859922b2b70eb8ed5da0f66b7` |
| Publication request | `a7c0a6d42f4a41622faf183c01818ffb73c56899` | `ff989cbd8d8ff0cef39cefec5ea0890346b0f65d` |
| Published candidate | `919134a39d31461947c410c233d59d1965c48414` | `78d6df75cb3534238c81b40e7bcdbe0cf693d012` |

Both later commits are direct-parent children. Qualified source to publication request adds only `.github/swarm45-runtime-publication-request.json`. The request binds qualification run `44953582341`, attempt1, source96b8 and artifact14727612467. Request to published commit changes exactly eight runtime/provenance/manifest paths, listed below. There are no implementation changes, including native, Godot scripts/tests, extension source, project/scene definitions or extension-loading configuration. The Linux CLI is committed with Git mode `100755`.

All published manifests preserve the actual qualified build/source identity96b8 and source tree; they do not relabel runtime builds as919134. The declared native definition remains `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7`.

## Runtime and source custody

I independently matched all eight downloaded publication payloads to the actual published Git blobs or LFS OIDs and lengths. Both extension provenance documents bind their actual binary hashes, 106 extension source files and 1,763 build-input files. Both CLI manifests bind their actual executable hashes and 43 native-definition files. Every per-file digest matches published committed source, with no mismatches. The ordinary source/CLI provenance gate passed for Linux and Windows.

The local checkout has four LFS pointer files. This review used the original downloaded r3 publication payloads to verify executable/library bytes; it does not claim execution from the unhydrated checkout. No broad native corpus was repeated for this runtime-publication-only delta.

| Published path | Payload bytes | Payload SHA256 |
|---|---:|---|
| `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll` | 5844992 | `c7fc1fbfea2999489ae83a6da100ca795b336dc6efa251af7e5003071a2bb43d` |
| `godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so` | 5278840 | `1db5702cf59f02d1ca4b6e7c0b34a73f3d106e67cec73b4901c0c10cd4c1cbb1` |
| `godot/addons/cybersand_native/runtime-provenance.json` | 226532 | `bd05d2280e5f4692888d47da2ddc3539f7e0da65a0e22ab76c7bdaa85331e513` |
| `godot/addons/cybersand_native/runtime-provenance.linux.json` | 226175 | `7b021644bdfb7212ad138b1d701db310618f0b6a608091b20be66a4d65d30e52` |
| `godot/tools/gentek_reciprocal` | 1312360 | `a3690011da97b12a6bfdc8d461e33dde9f98c1418fef89a3f3de994bd239da53` |
| `godot/tools/gentek_reciprocal.exe` | 3100672 | `001672a6961c113f51b4f483e33cbb97702fec09616a60949c26a991a5a18105` |
| `godot/tools/swarm004-runtime.linux.json` | 6355 | `89ef9fc7313c901a69e270d12dff335c0b5dd18787bb8187e8eff7b95baf3dbc` |
| `godot/tools/swarm004-runtime.windows.json` | 6361 | `4500f86447fdab4206dc8a6fca95b10c2e3dccd4268ebba741a10d42f1805fe2` |

## Protocol, defaults and authority continuity

Native request parsing still admits only SWARM004 V1/V2 and opt-in SWARM005 V3. The current composition serializer remains schema5 `reciprocal_assembly`. The Workbench emits V1 for the shared legacy case, V2 for independent controls or fixed ownership, and V3 only when a SWARM005 switch is enabled. Native and UI material, mask, budget and source-definition checks are unchanged.

The ordinary Workbench entry remains lazy: opening the dock creates it on demand and does not generate. Source-feasible terminal parts, supported MOSAIC receptors and negotiated sharing start OFF in that dock. Retained native `Options.shared_ownership=true` for historical V1 semantics remains unchanged. The manifest now explicitly states this defaults scope; its initial unscoped wording was clarified without implementation changes.

Platform-specific installed manifests remain the normal runtime path. A present stale/malformed platform manifest fails closed; legacy fallback applies only if the platform-specific file is absent. Executable hash, platform and current definition checks remain intact. The publication supplies both ordinary OS paths rather than requiring evaluation-only environment variables.

The reviewed pending-text, gesture, busy-input and failed-runtime stale-authority repairs are byte-identical to qualified r3. The historical repair is likewise unchanged: only known matched FRAME/MOSAIC definitions can be inspected, every saved load is explicitly read-only, and original evidence/`can_apply` is retained. Apply, direct transaction submission, attestation and Undo stay blocked across cancellation/invalidation until a zero-exit fresh current decode passes source/history fences. Ordinary saved-map reconstruction is independent and preserved.

This continuity carries the prior independent 259-assertion P2 review and its preserved red/green evidence; it is not a new execution of those fixtures on919134. Exact retained source hashes are:

| File | SHA256 |
|---|---|
| `godot/scripts/workbench_reciprocal_protocol.gd` | `1c2c4da1c379e83e1a01455a90eb899c7b98411d79eda75989a523ab395109d1` |
| `godot/scripts/workbench_reciprocal_panel.gd` | `b53951bad17ef2e50add2afccf8c0575aa143969fa6b06eb7f03635112d39413` |
| `godot/tests/test_workbench_reciprocal_protocol.gd` | `ece8fc6a491b06e8ee6adfc5d973150bb6099a6f54182632c0f05b567143222a` |
| `godot/tests/test_workbench_reciprocal_controller.gd` | `cbae21dfcd94a223c62a1cc136c0fc42958c69c61136403d898f6c4e012dadf5` |
| `godot/tests/swarm45_reciprocal_ui.gd` | `a57618ed8491431aee4865936077082ffcd2b62d52980a72374cb2443301fac8` |

## Published manifest and donor boundary

I independently checked the final additive manifest at `/workspace/scratch/038267c40e11/cybersand-swarm45-mainline/evidence/swarm45-local/published-source-provenance-r3.json`: **414742 bytes, SHA256 `805ebd2893a157b87e50e6aadc2008e51822448ea877b6ea991c8efd245228b3`**. Its source chain, all159 changed-path records, Git modes/types/blob identities/hashes, eight LFS/payload bindings, 85 donor-identical records and 81 unchanged pre-existing accepted-main native source files all match Git.

All four manifest source ledgers match qualified96b8 and published919134: 1,763 build inputs, 147 source inputs, 106 extension inputs and 43 native-definition inputs. I recomputed the current native definition and all five frozen donor definitions directly from immutable committed source; each matches the recorded value. The prior source-only manifest's length/hash also matches.

No donor/history source mutation occurs in this publication delta. No SWARM006 source import is present in native/Godot source, and the exact reviewed implementation is unchanged. The pre-existing schema6 `matched_final_frame_no_offer` control serializer is byte-identical to frozen donor580ff82 (`reciprocal_io.cpp` SHA256 `cc21b79130f5aaec4bf0f4f13268f40dfa4208d92e528bd7bfc2c51df9f76172`); it is distinct from schema5 composition and does not admit SWARM006/V4 composition.

The manifest correctly retains historical negative evidence and regression-only limits, separates final-admission dispatch from resulting gates, and leaves physical owner acceptance pending. Remote run conclusions were not independently re-adjudicated in this source/security review.

## Evidence and decision limits

The prior closure report `/workspace/scratch/038267c40e11/swarm45-historical-inspection-fix-review.md` remains SHA256 `7acb555d8ca062720b5a4b9b73b032c6af3d896901da412442b82377c85bfed4`; the r3 committed-source human review remains SHA256 `eb696df7fc6542b4c2e130d5e32801e79ac281e921a160c28f99accf5558d196`.

New independent receipts are under `/workspace/scratch/038267c40e11/swarm45-published-source-security-review`:

| Receipt | SHA256 |
|---|---|
| `verification.json` | `59739d8a2e533e6fb752d3cfc58ca68f9877956a2be9e09783cf24a6d804602c` |
| `manifest-verification.json` | `0759b03b8a2d18e461d9a99d5cad4ea08fa130808131cdba67a4c7977ca8b096` |
| `ordinary-runtime-binding.json` | `80bd2b18541ad48e63c48e94564073483f48a6e6d088c2cc3526882d252049e4` |
| `decision.json` | `b0dcb04dc97a9daa57f3d8321a973811b8652071ab3d2de8b046a4bf89a367e3` |

Final ordinary Documentation, Native, GDExtension, Palette and Play admission for exact919134 must be read from their own results. Physical original-user-map/NVIDIA owner acceptance remains outstanding. Neither runtime publication nor this source/security GO substitutes for those gates or authorizes merge, Ready or auto-merge.
