# Provider conversation-edit preparation checkpoint

Baseline is principal `e536d128f85e948223b25e13931a7a801faf956d`. This isolated implementation responds to the separately pinned ordinary Apply profile: complete 16,769,024-byte Apply took 681.146ms locally, with explicit redaction 347.725ms and audit 288.351ms. The raw profile and complete original audit are preserved on provider-evidence commit `185aa8643338e523cb4002df20d08bf1b0cc1cb8`; no hosted Windows attribution is implied.

The provider reuses the existing finite preparation registry with a `conversation_edit` value direction. It owns typed immutable snapshots, credentials, redaction, pre-encoding, cancellation and authenticated one-shot prepared handles. It never sets HTTP `active`, dispatches inference or gives a worker filesystem/native/SceneTree ownership. Art panel UI, editor generations and current World/revision guards remain the product lane's ownership.

The contract is:

- `begin_conversation_edit(turns,last_result,identity,completion,guard) -> {ok,handle,error}`
- deferred `completion(handle,identity,error)`; readiness is not append authority
- `prepared_conversation_edit_turns(handle,identity) -> copied redacted Array or null`
- `commit_conversation_edit(handle,identity,adopt,guard) -> {ok,committed,adopted,error}`
- `adopt(clean_turns) -> true`, invoked immediately after durable append and before traffic observers
- `cancel_conversation_edit(handle,identity,reason) -> bool`
- `conversation_edit_state() -> {active,phase,handle}`, where phase is idle/preparing/ready/committing/stopping

Actual append rechecks the provider serial, owned journal path/event index, exact credential snapshot and live guards. A first bounded metadata record establishes the journal before worker admission, avoiding first-journal callbacks inside the later edited commit. No cancelled/stale job appends raw draft or `conversation_edited`. The existing complete audit and image/history validator remain authoritative. Main-thread commit consumes a private registered preparation object, never arbitrary caller bytes.

Development mechanism test `test_art_conversation_preparation.gd` passed 54 checks with real WorkerThreadPool tasks and the native atomic journal owner. It covers immutable input, wrong/forged handles, credential changes, cancellation and rapid retries, UTF-8 capacity refusal, owner free, no-op retirement, final-guard reentrancy, and adoption before a reentrant traffic observer starts a successor. There were zero HTTP exchanges and zero ordinary paint completions. This is mechanism evidence with host guard fixtures; UI/native World lifecycle and measured large-Apply qualification remain separate pending integration gates.

The source-backed transport paragraph also corrects current 64KiB to 256KiB. Historical 64KiB measurements remain unchanged.

## Independent review correction: refused draft visibility

C identified that the first prepared-edit implementation formatted the live Traffic
projections before the last owner/credential guard. That guard correctly refused
the disk append, but could leave a refused draft in live Traffic. The corrected
path stages both projections locally and publishes them only after the final
admission and complete durable append succeed, before live adoption and observers.
Ordinary event failure-preview behavior remains unchanged. A real worker regression
rotates the credential set inside the final guard and checks byte-identical archive,
raw Traffic and readable Traffic, including absence of the unpublished draft marker.
The earlier54-check checkpoint did not exercise this visibility edge; retain it as
an intermediate result, not qualification of the correction.

The lead's independent review additionally required the Provider's own queued
teardown to invalidate admission and commit before the SceneTree deletion flush,
even if an injected host guard still returns true. The Provider now checks its
in-tree and queued-deletion lifecycle before admission and on both sides of a
reentrant owner guard. The mechanism test holds a real ready worker value, queues
the Provider for deletion, then synchronously attempts admission, preview and
commit; all refuse before the owner is freed and neither live projection nor the
archive changes.
