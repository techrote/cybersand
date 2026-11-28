# Independent review of same-attempt runtime distribution

Specialist C reviewed candidate `4bb903109321bdc343eaebcb3da86bfec19bd4dc`,
tree `985955bf0f9cec25b1b78742950deb8000900fc0`, parent
`120f0d0825e1fcdf9ea1ea9d8d50a0d5b32735d6`.

**Disposition: APPROVE SOURCE ADMISSION FOR FULL READY QUALIFICATION.**
This is not approval to merge before the resulting-source platform and
graphical gates finish. The original failed attempts remain failed.

## Scope and ownership

The ten-file difference contains CI workflow plumbing, one transport helper
and its adversarial controls, source-custody inclusion, Palette dependency
preparation/budget accounting, and documentation. It changes no Godot product
code, native input, committed runtime binary, source provenance, test inventory,
test watchdog, native compile allowance or concurrency setting.

The existing Windows native build acquires the committed Windows Rapier object
once, before its consumers can run. It retains a separate artifact and leaves
the established source-built native candidate contract intact. Palette's
existing plan acquires the four exact retained Linux/Windows native and Rapier
objects once. The six consumers verify the full available inventory and install
only their platform's pair. Linux GDE retains its existing acquisition path.

## Custody and refusal properties

Both producer and consumer require the exact checkout commit, workflow run and
attempt. Artifact names bind the same run/attempt and no consumer falls back to
network acquisition, another source or another runtime. The consumer obtains
the expected object digests and sizes from its own committed canonical LFS
pointers, so a resealed producer manifest cannot authorize changed bytes.

Review covered the complete expected inventory; duplicate and colliding paths;
source movement; missing, extra and aliased artifact members; original
acquisition command identity, exit status, owned completion, receipt and log
hashes; legal retry sequences; complete payload verification before installing
selected files; and final installed bytes. Late manifest or receipt writes
remain within the shared deadline and leave failed evidence without a usable
successful seal. Stale output and staging files are preserved rather than
silently replaced.

The new transport helper is part of Windows tested-input custody and Palette's
required apparatus. Existing native/Rapier provenance validation, exact
application source checks, native and ANGLE pixel execution, cache-lineage
checks and complete same-attempt reducers remain in force.

## Workflow budgets and recovery

Windows consumers replace one ten-minute acquisition step with a five-minute
artifact download and five-minute install. Their original 4,200-second setup
reservation is unchanged. The producer preserves its original 240-minute
envelope and adds the moved ten-minute acquisition plus five-minute retention.

Palette preserves all execution and dependency clocks, adds one real metadata
download step per cohort, and increases the plan envelope from 30 to 55 minutes
to include the moved twenty-minute acquisition and separate five-minute
retention. Its explicit plan steps total 45 minutes, retaining ten minutes of
headroom. Current cohort parents remain at or below 350 minutes, under the
360-minute policy limit; the reducer is unchanged.

Because consumers demand the current attempt, recovery must include producers:
the common GDE `ready_scope` ancestor or Palette's `plan`, with all dependent
consumers and reducers. A failed-consumer-only rerun cannot reuse the prior
attempt's artifact.

## Independent verification

C independently executed **106 controls**: 20 transport, 38 Palette, 12 planner,
14 checkout-custody and 22 Windows-runner tests. All passed. The CI provider
policy and actionlint 1.7.12 on both changed workflows also passed. Before/after
hashes of all ten reviewed execution/policy inputs were unchanged; their exact
Git blobs match the frozen candidate. Raw logs and SHA-256 receipts are under
`qa-artifacts/lfs-fanout-independent`; the companion register retains the
complete source/test receipt.

These are source and synthetic custody controls. No new hosted runtime artifact
or full resulting-source qualification is claimed by this review. C also flagged
one obsolete documentation sentence above the new explanation that still said
Rapier was fetched inside each shard; correcting that sentence is documentation
only and does not change this engineering disposition.


## Final source follow-up

The final candidate is `d64b3886f27a3a3ffa0415bc516db993a112e5f1`, tree
`984c94a6e312261120dffb4ad3625a6030d2f359`. Its two-file follow-up corrects
the obsolete documentation sentence and resolves the synthetic temporary
fixture root before comparing it to the producer/consumer root. This matches
the production helper's existing canonical root handling, including Windows
TEMP 8.3 aliases; all destination and artifact alias-refusal controls remain.
There is no production or workflow change from the approved source.

C independently reran all twenty transport controls at this exact final source:
**PASS**, 1.032 seconds within the test runner, with original log SHA-256
`8f1941778879c44201cc4b2ac8badd486dc805d0934cac0dc1ae8469b13a416f`.
The source-admission approval extends to this final candidate. Actual complete
hosted qualification and its independent readback remain required before merge.
