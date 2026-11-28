# Independent admission of narrow unchanged-source recovery

Specialist C, 2026-11-26. **ADMIT the proposed retries after each affected
workflow is terminal. No merge approval is granted by this review.**

The fixed candidate is `26317ada6a1f40637e96d732ec28f55c70cd53a2`, tree
`984c94a6e312261120dffb4ad3625a6030d2f359`, equivalent to reviewed local
`d64b3886`. Its GDE synthetic checkout is
`a83b44dee96b6db382e8cd9def727c963a979eaf`, with accepted main `c8421a81`
and candidate `26317ada` as parents.

## GDE Windows producer and all descendants

Retry failed Windows producer job `139602551095` in run `45727973062`,
including every dependent Windows shard, the Windows coverage reducer and
dependent advisory timing. Regenerate both
`windows-lfs-runtime-<run>-<attempt>` and
`native-candidate-windows-<run>-<attempt>` at the new attempt.

The current workflow's Windows reducer does **not** download an attempt-specific
execution-plan artifact. It uses successful plan outputs from the unchanged
source. The reducer independently reconstructs the full applicable case
inventory, shard assignments and tested source inputs, then requires all
Windows reports, runtime identities, raw logs and complete outcomes at the new
attempt. Reusing that successful unchanged-source plan does not mix Windows
execution artifacts across attempts.

Linux build, Linux shards, Linux graphical smoke and Linux reducer are not
descendants of the Windows producer. Their original attempt-1 evidence may be
retained explicitly as attempt 1; they supply no runtime artifact to the Windows
chain. The final acceptance record must say **Linux attempt 1 / Windows attempt
2** if that is what actually passes, rather than claim a complete uniform
attempt 2.

The advisory timing job reads current-attempt artifacts and retains observed
platform/source/attempt identities. Its job-performance collector queries the
exact run-attempt jobs endpoint. An attempt-2 advisory built from Windows
observations cannot be described as new Linux timing evidence.

This is a narrower, evidence-supported option than the earlier common-ancestor
retry guidance. It is valid because a complete platform producer/consumer/
reducer chain is rerun and the exact source is unchanged. Retrying only failed
Windows consumers remains invalid when their producer artifacts belong to
another attempt.

## Independent Art Windows job

Retry Art session-logging Windows job `139602549515` in terminal run
`45727972762`. The Linux and Windows jobs have no dependency between them and
no aggregate artifact consumer. C read the original Windows log: Git LFS failed
before Godot or the evidence directory was created. Therefore this particular
retry will not collide with an existing Windows artifact bearing the
source-based name. Preserve Linux's original attempt and inspect every fresh
Windows test and receipt after completion.

## Original failure custody and remaining admission

C independently verified the original failed Windows producer ZIP
`15075561307` against its published SHA-256
`8669ccf5f58b8537d5f83ea5522fec8c6dbef22296e5ab9f7ce16b5a5728226c`.
The first pull reported the admitted batch-service timeout; the second returned
HTTP 503 and was correctly refused further retry. Both processes joined.
The stage failed after 21.481 seconds and retained no usable manifest.

C also verified the successful Palette producer ZIP `15074558949`, all
manifest member hashes, original command logs and all four payloads. Its source
is exact `26317ada`; it succeeded with one pull. This is separate from the
remaining graphical reducer and complete application qualification decisions.

Keep the source, native inputs, test inventories, watchdogs, runtime byte
contracts and current checks unchanged. Preserve every original failed job,
attempt and artifact. Before merge, independently read the terminal successful
platform reducers and every applicable workflow, binding them to their actual
attempts. No retry, source edit or remote mutation was performed by C.

