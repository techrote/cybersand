# Correctness checkpoint, 2026-09-08

The owner authorized publication and finalisation. Source and workspace remain
separate Git histories in the private `techrote/cybersand` repository.

- Source `main`: `ab4851e9e6a3ee182aba1a31a8f66d135e87df3a`, annotated tag
  `correctness-2026-09-08`.
- Workspace: branch `codex/workspace-docs`, paired annotated tag
  `workspace-correctness-2026-09-08`; SOURCE-CHECKPOINT.json binds this workspace
  to that source revision. Ignored local tools/exports/logs are not Git payloads.
- [PR #6](https://github.com/techrote/cybersand/pull/6) merged the separate issue
  #1/#2 commits and validation/runtime publication. Both issues closed completed.
- [PR #7](https://github.com/techrote/cybersand/pull/7) fixes release hash upload
  naming for branches containing `/`. Actual corrected upload passed in
  [run 34287868476](https://github.com/techrote/cybersand/actions/runs/34287868476).
- [Private development prerelease](https://github.com/techrote/cybersand/releases/tag/correctness-2026-09-08)
  records the paired checkpoint. This is not an all-platform production release.

The defects had independent causes: F01 reproduces without regions; F02 remained
after F01 was fixed and reproduces without events/failure. Failed worlds now
quarantine partial state and require explicit reset or validated replacement,
without rollback/retry/event replay. Phased exclusion retains activity and wakes
newly included blocks once without catch-up. Serial behavior remains deliberate.
Failed-world region requests take effect through the explicit recovery path.

## Acceptance and historical disposition

Source [reconciliation evidence](../source/docs/audits/2026-09-08-validation-reconciliation.md)
and the separate issue audits identify tools, inputs, worker counts, timeouts,
artifacts and limits. Windows: 46 native tests plus C11 header, rebuilt adapter and
16 Godot runners. Actual Chromium compatibility/threaded exports cover failure,
re-entry/recovery and within-mode worker equality. Linux: 46 native tests,
ASan/UBSan (leaks disabled), TSan; rebuilt Godot library passes 16 test scripts,
two profiles, import/scene smoke and ABI checks in run `34286177653`.

Published Windows DLL SHA-256:
`fda49d0acb0a4786f9aeeb6cb4289fc2fd10ac8103512cc1663f98598a49049b`.
Published Linux ELF SHA-256:
`8f68fd2c7cb2b449173f5ee2c3ce267b6966ac8a9d8381fdacdd05dfc2d9c31a`.
Both are tested artifacts with canonical source-input manifests. Subsequent
publication/tooling commits change no native/adapter/owner/test source inputs.

All 18 required LFS files were downloaded and verified. Git integrity passed;
two unreferenced blobs were preserved. The M11 historical gate verifies all
28 original source hashes against audited commit `05ea45f...` and freezes 18
retained records including the original checker. Original hashes/tags/audits
remain unchanged. Strict current-versus-M11 comparison still reports 12
implementation/runtime differences, with zero historical integrity errors; the
Linux difference now represents the rebuilt library, not a missing LFS payload.
These differences are not unresolved current release-gate failures.

Current docs/provenance, eight checker regressions, retrieval and LFS CI passed.
Final lexical corpus: 50 canonical documents; 23/32 hit@1, 32/32 hit@5,
MRR0.8385; supplementary 5/6, 6/6, MRR0.9167. Canonical hits are not full answer
proof; C04's previously recorded bounded-capacity detail gap remains explicit.
No macOS/WSL, Firefox/Safari, LeakSanitizer, complete replay or general physics
acceptance is claimed. Separate [issue #3](https://github.com/techrote/cybersand/issues/3)
retains Web CI toolchain/argument/export-template/source-provenance obligations.

## Reconstruct without overwriting an existing workspace

Use a new empty destination and clone the workspace tag first, then the source
tag into its `source` directory. Run `git -C source lfs pull`, the current
`check_repository.py --require-materialized` gate and the separate historical
M11 integrity check. Restore toolchains/templates from their exact pins before
building; Git/LFS availability is not a toolchain backup or all-platform run.
Keep the existing USB backup user-confirmed; it was not searched or inspected.

Historical `m11-audited`, `docs-correctness-2026-09-08` and
`workspace-docs-correctness-2026-09-08` tags remain unchanged and retrievable.
