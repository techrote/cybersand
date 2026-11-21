# Independent SWARM-004/005 CI and publication source review

**Checkpoint verdict: GO to freeze and execute the defined hosted qualification. No confirmed unresolved P1/P2 finding in the reviewed source checkpoint. This is not merge admission or a claim that hosted tests have already passed.**

Reviewer: `/root/swarm45_publication_review`, independent of both the CI/publication implementer and root's packaging changes. The reviewer made no repository edits, commits, pushes, workflow requests, PR changes or SWARM-006 changes. Review observations and isolated test artifacts were written outside the worktree.

Repository examined: `/workspace/scratch/038267c40e11/cybersand-swarm45-mainline`, dedicated integration of accepted main `0f0161af337d6d0cee8fa961a9667aff570a75b0` and frozen donor chain ending `580ff82f285b7aeda8fb4a2a0d034425f0d0401d`. This checkpoint was taken before committing the integration tree; reviewed file hashes, rather than the old working HEAD, identify the source.

The machine-readable checkpoint lists **32 exact source-file SHA-256 values** and the independently executed test records:

- `swarm45-publication-review-evidence/source-checkpoint.json`
- Checkpoint SHA-256: `9098b7c7ede9d64edcc992130ae7abb149595ac0e2ed6b820319b8be1be65cce`

## Scope and source custody

I read the new `tools/swarm45` helpers and both dedicated qualification/publication workflows, including their existing donor process validators and generic Workbench/package dependencies. I reviewed root's narrow Windows archive/materialization repair, the CI implementer's Linux archive/materialization repair, their regressions and the optional Makefile compiler-preprocessor hook. The replay harness was inspected for custody and qualification claims; scientific policy equivalence and native geometry correctness remain the separate native/science reviewers' scope.

The source custody helper inventories actual checked-in native, extension, test, script, shader, authoring, example, build and dependency inputs. It rejects dirty or untracked build inputs during qualifying execution. Its compiled-definition calculation reproduces the Makefile ordering, and its canonical input ledger is cross-platform LF normalized. Producer and consumers bind the actual execution commit/tree, native definition, files, platform, workflow, run and attempt. A local diagnostic manifest cannot be admitted as hosted evidence. Windows also retains the existing independently checked native-candidate identity.

Source-matched qualification remains distinct from preserved historical evidence. The fixed 360-case replay explicitly records `unseen: false`; it does not relabel revealed controls as a new held-out result. Every case retains compressed native JSON and hashes, including exhausted/blocked outcomes. Definition/geometry policy changes are not silently hidden by publisher metadata.

## Qualification workflow

The new workflow has read-only repository permissions and runs on standard GitHub-hosted Ubuntu and Windows runners. Its push path is one explicit request file on the dedicated integration branch. The request guard binds separately published source, exact accepted-main/donor ancestry, native definition, exact branch and ordinary non-force update. Every intervening commit must contain only the request file; temporary source changes followed by reverts are refused. Manual dispatch stays confined to the same authorized branch and source checks.

The platform graph builds each platform payload once. Linux requires strict native tests, ASan/UBSan, V3 request tests, the known360 replay, real graphical Godot authoring and accepted-main smoke. Windows runs native tests on Windows, then real source-layout graphical tests and a separately extracted evaluator in parallel. Source and evaluator runs use their actual target adapter and CLI. Ordinary source-layout tests now install a platform binding and remove all `CYBERSAND_SWARM004_*` generator overrides, so the real shipping lookup is exercised. Only the process-lifecycle fixture deliberately supplies a different executable.

The graphical gate requires all fourteen child-process records, all four declared examples, the actual target OS and a non-headless display, exact Godot/test/native identities, positive assertion counts, source-bound receipts, complete native material planes and original framebuffer PNGs. Create and reopen require distinct OS process IDs. Preview/Undo equality and blocked-world preservation are checked independently of positive Apply. The zero-joint V3 local termination case is explicitly distinct from the reciprocal foreign-joint witness. The lifecycle fixture is mandatory, not an ignored or skipped case.

The evaluator is a real ZIP extraction with a full inventory comparison. It runs its own extracted engine and project. Its complete source-built runtime manifest, adapter and CLI bytes remain checked. The publisher cannot use a failed or incomplete package job. Accepted-main smoke covers Paint author/reopen, generated Paint, Water, Art, actors and Flatten, and is explicitly supplemental to the unchanged full native/GDExtension admission workflows.

## Publication/security review

The new publisher is a separate explicitly requested transaction. It has no Ready, merge or owner-acceptance operation. Write permission is scoped to its one job; its branch, event, repository, workflow identity, expected parent and live remote lease are checked repeatedly. Qualified source must be an ancestor through only linear publication-request commits. The qualified run must be complete and successful on the exact source/branch/workflow/run attempt. A later rerun cannot inherit a prior attempt's success or artifact identity.

The immutable artifact has a pinned ID, name, source producer, archive SHA-256 and size. Extraction admits exactly nine files: the eight runtime paths and their publication plan. Unexpected paths, duplicate/missing payload members, symlinks and excessive uncompressed size are refused. The plan and both platform manifests preserve the original build commit/tree; source equivalence is checked against the current checkout rather than retagging binaries to the publication commit.

The eight permitted tracked paths are the two native adapters, their two provenance records, two reciprocal CLIs and two platform bindings. The staged index must contain exactly those paths. All four binaries must be exact Git LFS pointers for the actual payload, and the Linux CLI must retain executable mode. The commit must have the request HEAD as its sole parent, and the push uses that exact live lease. Existing historical publisher fences are not widened.

All publication records keep owner visual acceptance `pending` and reciprocal programme acceptance false. Scoped qualification is not represented as complete source admission, physical owner acceptance or proof that reciprocal negotiation is generally solved.

## Confirmed defect and repaired delta

I found one P2 integration defect before freeze: placing retained reciprocal CLI LFS objects under `godot/tools` would break existing post-publication package assembly. Generic archives included both platform CLIs, while package workflows materialized only Rapier. The initial pre-publication scoped run would not expose this because the CLI objects were not tracked yet. Linux archive writing also discarded executable permission.

The reviewed repair is narrow and complete for the current package paths:

- Windows archive staging omits the Linux CLI/binding and still refuses unmaterialized or changed Windows LFS bytes. Existing direct Windows package workflows fetch the Windows CLI beside their original Rapier fetch.
- Linux archive staging omits the Windows CLI/binding, preserves archive executable mode, and supports an explicitly verified same-run Linux CLI candidate. The existing installed Workbench workflow fetches the retained Linux CLI when using that path.
- The new Windows qualification materializes the old retained CLI before package assembly, then the SWARM wrapper installs the qualified CLI and its current platform/legacy bindings into the evaluator. Source-layout installation occurs after LFS restoration, avoiding accidental replacement by retained bytes.
- Isolated tests cover mixed-platform pointer archives, missing opposite-platform objects, unchanged source/adapter handling, wrong Windows payload refusal and Linux executable mode.

The standalone Linux compiler uses the existing portable wrapper and pinned GCC13.3. The optional old libstdc++ string ABI flag applies to the complete standalone reciprocal native/test/replay object set, which communicates with Godot through text/JSON; it does not change the GDExtension C++ ABI. A mandatory ELF import check enforces GLIBC <=2.34, GLIBCXX <=3.4.30 and CXXABI <=1.3.9 for both the adapter and CLI. Actual pinned-hosted success is still required; local GCC14 observations are not accepted in its place.

## Independently executed checks

I independently executed the final new helper suite: **22 tests passed, zero failures**. I separately executed root's post-publication Windows archive regression: **1 test passed, zero failures**. These are custody/package tests, not graphical runtime acceptance.

I also exercised `verify_bundle` using an isolated synthetic eight-path payload. All **8 checks passed**: a valid payload was accepted; altered original build identity, owner-acceptance claim, native definition, source, platform, Draft/HOLD status and an extra path were refused. For mutation cases I recomputed the outer inventory, so these checks exercised the inner semantic bindings rather than merely detecting an unchanged outer hash. Synthetic ELF/PE headers in that audit were never executed and are not described as native execution evidence.

Evidence is retained in `swarm45-publication-review-evidence/` and `swarm45-publication-payload-review.json`. The final helper logs and exact file hashes are in the checkpoint JSON. The implementation agent additionally reported actionlint and runtime-binding tests; this review does not substitute that report for actual hosted qualification.

## Remaining admission gates

The reviewed source is suitable for its frozen hosted run. Before publication/admission, independently inspect the actual exact-source Linux/Windows build and execution receipts, all required graphical/native/known360 results, the extracted evaluator and its SHA-256, measured Linux ABI floors, source-equivalent publication commit and ordinary full native/GDExtension/documentation gates. Any repair requires affected requalification and independent delta review.

The original-map physical Windows/NVIDIA owner evaluation remains a separate external gate. Earlier donor evaluation cannot stand in for acceptance of the newly reconstructed package. Until that mandatory gate and all other admission conditions are met, the candidate remains **Draft/HOLD**. This source checkpoint provides no permission to record owner PASS, mark Ready or merge early.

Nonblocking documentation observation: the evaluator initially selected the historical SWARM005 guide as its README, whose current integration note links the newer runbook. The final handoff should provide the current exact package instructions and clarify historical hashes; including both guides in the evaluator would keep that clarification available offline.
