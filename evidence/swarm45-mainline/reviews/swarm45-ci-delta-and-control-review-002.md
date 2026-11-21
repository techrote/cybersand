# Independent SWARM45 CI delta and dispatch-control review 002

**Source-delta verdict: GO to freeze and requalify. No confirmed unresolved P1/P2 finding in the reviewed staging, portability-evidence and accepted-main reconciliation delta.**

**Dispatch-control verdict: GO for the bounded design, conditional on a final pin-only review before use. The inspected `ACCEPTED_MAIN` and `CONTROL_BASE` values intentionally remain old and must be updated to the new accepted main/frozen source.**

Neither verdict is hosted acceptance or merge admission. The reported cold extracted-package startup problem is not resolved or waived by this source review. All mandatory platform, publication, full admission, independent final review and physical-owner gates remain separate.

Reviewer: `/root/swarm45_publication_review`. Read-only review; no repository edits, workflow triggers, remote branch changes, PR changes or SWARM-006 activity. The review artifacts are outside the repository.

## Exact checkpoint

The machine-readable record is `swarm45-publication-review-evidence/delta-002-and-control-checkpoint.json`, SHA-256:

`266bf8ddf31647193e4bbb7673981e5edc126833fdafe11a13ee95ee2b6f943f`

It lists canonical-LF hashes for the eight supplied CI checkpoint files, five additional candidate files, and all four isolated control files. I independently verified that all eight supplied hashes match the actual working files.

The compiled native definition recorded for this delta is `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7`.

## Isolated source staging

`stage_source.py` stages a new project directory outside the source checkout using `git archive HEAD`. It checks the original runtime/source custody before staging, installs the verified same-run runtime, verifies the staged project against the exact build-input ledger, and checks the original runtime/source custody again afterward.

The original source-cleanliness guard is unchanged. Generated Godot `.gd.uid` files and imports belong to the isolated test project; they do not become ignored source changes or a cleanliness exception. The isolated tests prove generated UID metadata does not enter the source checkout and that the original project/script bytes remain unchanged.

The archive rejects symlinks and unsafe parent traversal. It retains only the target platform's Rapier binary, checks that binary against the committed LFS identity and target format, excludes retained/foreign reciprocal CLIs and bindings, and installs the exact qualified CLI plus current platform binding. Linux CLI mode is explicitly executable. Old native provenance is renamed as a historical reference so it does not describe the newly installed adapter. Canonical generator profiles remain derived from the archived source.

The Linux and Windows source jobs now pass this isolated project into the existing graphical and accepted-main smoke harnesses. The strict native custody checks continue to examine the untouched source checkout. This fixes the source-layout mutation problem without reducing the checked source inventory or graphical scope.

I independently ran the complete new helper suite after this delta: **25 tests passed, zero failures**. The added tests cover both platform layouts, exact installed runtime/source bytes, opposite-platform absence, Linux executable mode, generated UID isolation, and refusal of an existing or source-contained destination.

## Portability delta and evidence

The runtime floor ceilings remain unchanged: GLIBC 2.34, GLIBCXX 3.4.30 and CXXABI 1.3.9. The floor inspector now retains both binaries' original `objdump -T` output and a structured failure identifying the offending binary before refusing the run. Its added regression verifies a CLI GLIBCXX 3.4.32 rejection, the adapter's separate passing status, both retained symbol-table hashes and the offending iostream initializer symbol.

I inspected the five CLI progress/error output substitutions from iostream to C stdio. Their format arguments use explicit portable integer casts, `%zu` for sizes, `%s` for strings and explicit flushing where the old campaign output used `std::endl`. The native request parser, JSON writer, assembly policy, budgets and material computation are untouched by this delta. Native semantic review is also separately owned by the native reviewer. Actual pinned hosted compilation, ABI-floor measurement and runtime qualification remain mandatory; this report does not promote local portability diagnostics into hosted PASS.

## Accepted-main reconciliation

I checked both working-tree and staged-index bytes for `.github/workflows/documentation.yml` and `docs/operations/ci-execution-and-performance.md` against accepted main `846fe0533b3170e7b01f690518da49fc40cc24d1`. Both files are exactly identical to that accepted commit.

The only `run_request.py` change is the `ACCEPTED_MAIN` pin from `0f0161af337d6d0cee8fa961a9667aff570a75b0` to `846fe0533b3170e7b01f690518da49fc40cc24d1`. Existing frozen donor identities and request semantics are unchanged. The current integration runbook accurately adds this reconciliation and the CLI output-only portability change. No run-request JSON was changed as part of the reviewed delta.

## Isolated dispatch bridge

The bridge lives outside the integration source on `ci/swarm45-final-admission-dispatch-20261121`. Its job has `contents: read`, `pull-requests: read` and `actions: write`; checkout does not persist credentials. The script's entire API write surface is exactly five fixed workflow-dispatch endpoints with exactly one fixed integration branch payload and no inputs:

- `documentation.yml`
- `native.yml`
- `gdextension.yml`
- `palette-shader-qualification.yml`
- `play-desktop-packet.yml`

There is no source commit/push, Ready, merge, auto-merge or arbitrary endpoint operation. The five existing workflows support manual dispatch. Their normal inputs remain in effect, including disabled optional physical actor stress and Rapier comparison controls.

The control requires an ordinary request-only push on the exact control branch, an exact parent lease, a bounded strict JSON contract, attempt 1 and the expected repository/workflow context. Before dispatch it checks the live control branch, integration branch, accepted main and open Draft PR715 identities. Source ancestry must contain accepted main and the reviewed integration base. The final publication commit must be a single-parent, exactly-eight-path runtime update with the expected commit identity, following only publication-request commits after the qualifying source.

Both the qualifier and publisher must have completed successfully on the exact source, run, attempt, branch and workflow. The bridge independently downloads the original immutable qualifier artifact and checks its archive digest/size, exact nine-file inventory, publication plan, original build/source identity, both platform manifests and native-definition ledgers. It compares all eight published files to that artifact, verifies exact LFS pointers and Git modes, and reads every ledger input directly from both the qualified and published Git revisions. The five dispatched workflow definitions and publisher workflow must match the reviewed control base byte-for-byte.

Before each POST and after every accepted dispatch, it rechecks live leases. A matching active or successful manual run is recorded without dispatching a duplicate. A new request can recover a partially completed batch by dispatching only missing/failed workflows. New accepted dispatches must resolve within a bounded interval to an unambiguous exact-head manual run. Branch movement or ambiguous discovery fails with an incomplete receipt. Successful dispatch confirmation still reports admission and owner acceptance as pending.

I independently ran the isolated bridge tests: **12 passed, zero failures**. They exercise request/API scope refusal, malformed identities, original provenance and pending-owner preservation, main/PR/head changes, wrong run attempts and workflow identities, exact-head query checks, the fixed five POSTs, duplicate avoidance, partial receipts and ambiguity refusal. No real API calls or dispatches were made by those tests.

## Conditions before execution and final admission

Before creating the final control request, repin `ACCEPTED_MAIN` to `846fe0533b3170e7b01f690518da49fc40cc24d1` and `CONTROL_BASE` to the next frozen integration source containing the accepted workflow definitions. Independently verify that these are the only control-code changes. The current old pins intentionally fail closed against the new live main; this design approval does not authorize using stale pins or weakening their guards.

After the next candidate is frozen, verify committed hashes against this checkpoint and run the affected hosted qualification. Inspect actual Linux/Windows and pristine-package outcomes, runtime publication bytes, the final workflow results and required physical owner evidence. A new report must distinguish any surviving startup failure from completed source/native cases. No source review, successful dispatch or earlier donor evaluation substitutes for those admission gates.
