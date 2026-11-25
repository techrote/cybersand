---
title: Independent review of bounded Conversation Apply preparation
status: Planned
document-kind: audit
scope: Cross-lane provider, editor, World and teardown ownership review
last-reviewed: 2026-11-25
---

# Independent Conversation Apply review

The native/context specialist independently reviewed the Provider lane's
implementation, the experience lane's editor integration and the lead's narrow
coordinator fence. **No remaining source blocker was found at
`8a015efbeb7926a3c835303d3b163c01d353aca3`, tree
`ad991f1fe8e2c8945120526377d85392d0a3212a`.** Runtime and package
qualification remain separate from that source conclusion.

The reviewer did not implement these Provider/editor changes. The reviewed
sequence is explicit: A's initial `1ac6da6a`, the projection fix at
`05c274b2`, queued-owner fixes at `f9099628`, retired-child cleanup at
`f6054aaf`, and the final fixture-order correction at `8a015efb`.
Production panel and Provider bytes at the final pin are identical to the
reviewed f605 source; the later UI test reopens its editor after an acknowledged
proposal legitimately advances the live conversation revision.

## Admission, copied values and worker lifetime

The [Provider source](https://github.com/techrote/cybersand/blob/8a015efbeb7926a3c835303d3b163c01d353aca3/godot/scripts/art_provider.gd)
uses a separate conversation-edit handle and owner identity. It does not create
another Provider, HTTP route or ordinary paint completion. Opening the editor
does not start preparation; explicit Apply admits it.

Inputs are reconstructed through the existing typed conversation validator:
user/assistant roles, text and admitted structural image/history references.
Unknown live objects are not copied into the worker. Turn/text admission and
actual UTF-8 replay/record limits remain bounded. Current credentials are copied
into an immutable redaction snapshot and compared again before publication.

The [preparation worker](https://github.com/techrote/cybersand/blob/8a015efbeb7926a3c835303d3b163c01d353aca3/godot/scripts/art_response_preparation.gd)
only redacts, counts and encodes copied values. It owns no World, native
executor, GUI state or journal writer. The existing pending registry retains
the finite value job after owner destruction, and the deferred main-thread
reaper waits only after the pool reports completion. Cancelling an unfinished
job does not synchronously join it on the UI thread. The same Provider refuses
another request/edit while its cancelled value job is still being reaped.

A caller receives copied prepared turns, not the private encoded audit value.
Only the exact registered job can activate the prepared-value append path.
An arbitrary job object, replacement payload, wrong handle or wrong identity
cannot authorize that path.

## Exact commit and observation order

The Provider captures its serial, journal path and event index alongside the
host identity. Readiness and the final actual append recheck that identity,
current secrets and the live host guard after callback reentrancy. A guard that
admits a newer journal event invalidates the older prepared snapshot.

The first journal is established before worker admission with small preparation
metadata, excluding the unpublished draft. This avoids a first-segment pointer
callback occurring between an edited snapshot's durable write and adoption.
The large edited record uses the existing complete, ordered, flushed journal
append and error protocol.

The verified order is:

1. Final prepared-job and live-owner checks.
2. Complete durable edited snapshot append.
3. Live conversation adoption and revision advancement.
4. Traffic observers.

Later observers can Stop or admit a successor without the retired commit
clearing that successor. Failure leaves the draft available and does not adopt
an uncommitted live conversation. This source review does not treat a queued
job or completed encoding as a committed edit.

## Host state and owner control

The [panel/editor integration](https://github.com/techrote/cybersand/blob/8a015efbeb7926a3c835303d3b163c01d353aca3/godot/scripts/art_batch_panel.gd)
binds preparation to its own generation, the live conversation revision, the
editor baseline revision, actual World epoch, Provider serial and existing
native-result text. It retains a copied draft and repeats full baseline/draft
comparison before commit. Cheap per-frame guards avoid comparing the complete
large conversation on every frame.

Pending Apply makes mutating editor actions read-only, including direct signal
and paste handlers, while retaining navigation, complete 4096-character parts
and Cancel. Stop, editor Hide and reopened conversation retire the UI identity
before scoped Provider cancellation. A previously queued ready notification
cannot restore that retired identity.

The final guards reject queued, detached or invalid owner hierarchies before
the deletion flush: panel, editor, Provider, Workbench and host. Cleanup paths
also avoid calling retired editor/Provider children. The Provider independently
rejects its own queued or detached state at admission, prepared-value access
and commit, including after reentrant owner guards.

The [coordinator fence](https://github.com/techrote/cybersand/blob/8a015efbeb7926a3c835303d3b163c01d353aca3/godot/scripts/art_collaboration_session.gd)
treats pending Apply as existing direct-work ownership. Ordinary collaborative
Send, Inspect and Approve therefore cannot dispatch, start a new capture or
consume an already valid native preview while the conversation edit is pending.
Native history and execution remain under their existing owners.

## Findings retained and closed

**Prepared Traffic publication preceded its final guard.** Specialist C found
that the first implementation assigned live Traffic/readable projections before
the last credential/owner check. A credential rotated in that guard could leave
old-secret unpublished draft content visible even though the archive append
was refused. The reviewer independently inspected the corrected source:
prepared projections now remain local until the final guard and durable append
succeed. Ordinary log-event failure-preview semantics are preserved. The added
regression checks unchanged archive bytes and both unchanged live projections
after a final credential rotation/refusal.

**Queued owner deletion was not yet a live-guard boundary.** This reviewer found
that the initial UI guard checked inside-tree/visibility but not queued deletion.
A parent can remain in-tree until deletion flush while its child Provider reaps
a completed job. The correction adds the queued hierarchy checks above. Its
focused test holds only delivery of an actual completed worker, queues the Art
owner, then delivers readiness before deletion flush and checks no edited
append/adoption. A separate Provider test covers its own ready-then-queued state.
Retired-child cleanup was subsequently tightened without weakening the guards.

**Two attempted tests did not qualify the feature.** The first f909 UI test
failed to parse because its helper `seed()` collided with Godot's global
function. The f605 attempt reported 154 checks with 11 failures because loading
the offline example admitted a newer proposal turn while the test kept an older
editor baseline. The test now explicitly reopens against that acknowledged
revision before preparing the edit. These failures are retained; the stale
guard was not relaxed to make the fixture pass.

## Verified actual execution and complete audit custody

The original lifecycle bundle is durable at
[evidence commit 807250](https://github.com/techrote/cybersand/tree/807250dc0a1fbcfb5a6ee85747b523aa5a46ffca/docs/audits/2026-11-25-art-workbench-collaborative-002/provider-independent-evidence).
It includes the actual 66-check Provider mechanism run, the final 154-check
ordinary headless Workbench lifecycle run, complete original audit records and
the failed earlier attempts. The final Provider and mechanism-test bytes are
identical to the 7e0 checkpoint, with SHA-256 values respectively
c9c24d8aac45e09f5ee291699d09ed34eadc5945b28545c098eb30b500821891 and
09d16bb492f7018c3f6b24b1e7bac0cc9bf096b93c38dfbec862ad84dd9069ad.

Specialist B independently authored
[the original-byte preparation verifier](../../../tools/ci/verify_art_conversation_preparation_evidence.py).
The lead executed that exact script unchanged against the original archive.
The result passed **295 checks**, authenticating all 64 original payload files,
their SHA-256 values and ZIP CRCs, the actual 154/0 and 66/0 process markers,
the complete 13,641,575-byte admitted audit and its 28 contiguous events.

The audit contains 14 conversation events, 12 complete edited snapshots and
two collaboration records. The independently reconstructed successful edited
value is exactly 1,048,599 characters, SHA-256
326174c77f57722f97786401a4ee5356c7fd261aeb8c4d176d52b41010e3cff4.
No registered fixture credential or model request survives in that audit.
The verifier retains the f909 parse failure, the f605 11-check failure and both
exit-minus-nine near-cap attempts; it does not recategorize them as passes.

The complete verifier stdout and execution custody are source-pinned at
[d3222f29](https://github.com/techrote/cybersand/tree/d3222f291bb96cee78af6f46d4a4a17e4892024d/docs/audits/2026-11-25-art-workbench-collaborative-002/independent-apply).
Preparation stdout SHA-256 is
21e285170159b6e26ba542a6388d4f93aeb0750d5d3e2e194ddd3b63db340888.
B subsequently fetched those original records, independently checked both
verifier source digests and complete stdout identities, and reconciled the
reported counts in **27 additional checks**. The method and output are retained
in [the reconciliation record](independent-apply-review-reconciliation.json).

This division of work is explicit: B authored the verification method; the lead
brokered the original-byte execution; B independently authenticated and reduced
the published outputs. This is not another native application run.

## Independently checked near-cap responsiveness pair

A later fresh-host pair completed at baseline
e536d128f85e948223b25e13931a7a801faf956d and prepared candidate
8a015efbeb7926a3c835303d3b163c01d353aca3.
[The original evidence](https://github.com/techrote/cybersand/tree/956b0abcac1649344d11164cda7951daed042887/docs/audits/2026-11-25-art-workbench-collaborative-002/provider-independent-evidence)
contains one sequential baseline-first headless pair with fresh profiles.
The inherited native test's input, ordinary key-edit path and complete-value
assertions are unchanged; the candidate adds only the awaited asynchronous
completion assertion and explicit timing fields.

The independently authored
[pair verifier](../../../tools/ci/verify_art_apply_pair_evidence.py) passed
**161 checks** when executed unchanged by the lead. It checked all 29 original
payload files and both complete 33,538,622-byte audits, then reconstructed
the exact edited value as one *Z* followed by 16,769,023 *x* characters.
Both original native processes retained the identical complete 16,769,024-byte
value, SHA-256
ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a.
Their actual results are 22/0 and 23/0; the candidate's extra assertion waits
for asynchronous completion. Neither arm sent a model request.

| Observation | Baseline e536 | Prepared candidate 8a |
| --- | ---: | ---: |
| Apply action return | 620.436 ms | 43.440 ms |
| Complete edited value available | 620.436 ms | 644.979 ms |
| Maximum frame gap across Apply and completion | 639.012 ms | 73.356 ms |
| Complete main-owner audit append | 259.717 ms | 46.978 ms |
| Editor opening action | 15.768 ms | 17.491 ms |

The useful result is shorter blocking. **Total completion is 24.543 ms slower**
in the candidate, and editor opening is also slower in this observation. The
remaining 73.356 ms maximum Apply frame is material. The 12 baseline and 91
candidate frame samples are different denominators; their P95 values are
within-arm descriptions, not a matched distribution estimate.

Pair stdout SHA-256 is
ca367e4a9bc2a70578121b86a0b5053bde67d881b9dfa0d234e31128ef812f61,
retained in the same d322 original-byte execution record. The pair result's
historically named runtime_hash_record field contains evidence-file hashes;
runtime-binary qualification is supplied by source-specific provenance and
package records, not by that field name.

The host was Linux 6.18.57, Intel Xeon Platinum 8573C, nine logical CPUs, with
the unchanged pinned Godot/native/Rapier runtimes. This one headless pair is
not a statistical distribution, a cold-start result, a graphical Windows test
or physical owner acceptance. The earlier incomplete low-memory attempts remain
separate evidence and are not erased by the fresh success.

## Final integration and acceptance boundary

B independently fetched frozen application
bcc92927ce3894a16d5544923cfbf7b1d0339fda, tree
517164084860a19f18b36cb94f77597eb3220578.
Its Provider, panel, editor and collaboration session are byte-identical to the
reviewed final 8a sources. The seven-file mapping and the isolated context
disclosure differences are retained in
[final-bcc-source-independent-review.json](final-bcc-source-independent-review.json).
No additional source blocker was found.

Fresh full Linux/Windows application gates, portable package custody and physical
owner acceptance are tracked separately. Draft/HOLD remains in force. The review
adds no automatic cross-session restoration, paid inference, new native execution
authority or unsupported owner-hardware claim.
