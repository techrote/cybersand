# ULTIMA storage donor: independent integration handoff

## Disposition and source

Specialist A approves the narrowly identified storage mechanisms at protected PR #783 checkpoint `77eafd13d8ec7a541db2cb9e6e6dd12c1975c6d7` for coordinated resulting-source preparation. This is a read-only source and evidence review. No programme source, active campaign, current Art worktree, or accepted-main ref was modified.

#783 remains **Draft/HOLD**. Its comment [7177472609](https://github.com/techrote/cybersand/pull/783#issuecomment-7177472609) distinguishes the published storage corrections from the still-pending settings and operation-receipt repairs and expanded hosted gates. The lead requested a complete narrow donor in comments [7177081321](https://github.com/techrote/cybersand/pull/783#issuecomment-7177081321) and [7177952318](https://github.com/techrote/cybersand/pull/783#issuecomment-7177952318). Those pending repairs are not counted closed here.

## Exact donor set

| Responsibility | Source identity | Required scope |
|---|---|---|
| Shared verified whole-file writer | Introduced by `e55921c56b746da43874ef05fdd3b8b5f3265104`; current wording from `f59ebc889cf995b6c9c41ba8e870c4a11d98f343` | Project `workbench_file_transaction.gd` only, plus its applicable tests. The original e559 commit also changes three unrelated save consumers. |
| Utility boundary regression | Final `test_workbench_file_transaction.gd` at `6d2b9200144ecc8e938e625b32ad48e1c227ba69` | Retain 84 deterministic/native boundary checks, including stale staging links. |
| Shared storage test harness | Final `run_workbench_save_qualification.py` at `0395a0e1dcb8d397943883a675ca9861cf62acdd`; child from e559 | Required Windows locking and common assertion/hash helpers; full ordinary-save matrix requires its own repaired consumers. |
| Art export and event storage | `a03b83eab8cba84f095043888075b370659d1aac` | All six files: provider, archive, panel, integrity test, OS fault child, and Art qualification runner. |
| Goblin001 fixed audit storage | `e3b8fbe14c2efb9d4570c7bd8fa9cce89da1359e` | Controller consumer plus shared verified-file utility. |
| Goblin guarded OS fault fixture | `08058e3fc3f7227052ef4324465a7bd4254f3709` | Child and extended diagnostic runner; restrict narrow execution honestly to Goblin cases until other diagnostic consumers are included and qualified. |

The two product fixes share the **already accepted native replacement primitive**, not a single GDScript helper. Art uses bounded streaming `Archive.ClosedFileVerification`; it does **not** depend on `workbench_file_transaction.gd`. Goblin uses that whole-file utility. Art's Windows OS-fault runner imports `windows_lock` from the shared save qualification harness. All exact delivered file hashes and last path commits are in the machine register.

## Mechanism and evidence

The shared utility retains the previous destination until a complete sibling staging file has been written, flushed, closed, reopened, and compared byte-for-byte. It then uses `CyberDemoBridge.replace_material_baseline_file`, already present on accepted main and the current Art candidate. That C++ file has the same SHA-256 `03d7793bddc38414bca87d01f55d6c8d87553d49582bae547aef9bc6bbfd0873` at all three inspected sources. The utility refuses invalid paths, unavailable capability, collisions, write/readback/replacement failures, and reports a retained staging path when cleanup fails. It does not claim fsync, power-loss durability, or a multi-file transaction. Current utility hash `d4f7eb8b60247d24f1105c661ff7c431356101ee541ac5abfbd257660afea64a` matches the later independent Goblin review. The original utility review records 84 boundary checks and 13 cases covering real failures, replacement, fresh reload, termination, and complete concurrent commits.

Art computes a digest of the actual submitted output buffers, closes the file, and verifies the bounded staged stream before native replacement. Export verification yields to polling and remains cancellable; destination/source alias checks stay in place. New session events verify header plus event before publication or acknowledgement. Append verifies only the newly submitted region, preserves the previous complete prefix, and freezes further session writes if the append is refused. An interrupted append can leave an incomplete unacknowledged tail; replay recovers previous complete events. This is not a claim that the whole appended file rolls back.

The retained Art before/after campaign has six real Linux OS cases. Before repair, buffered short writes falsely acknowledged a 128-byte export, a truncated new event, and a truncated append. After repair all six cases pass: the old 84-byte export remains exact, a refused new event publishes no path or stored acknowledgement, and a failed append retains and replays the prior complete event. C independently executed the six-case matrix and 278 assertions across five integrity/panel/session regressions. C's later small-delta review matches the delivered provider hash; the lead's final after-execution receipt also matches the delivered provider/archive/child exactly. Original working-head labels are retained and are not relabelled as the later published commit.

The Goblin donor retains actual fixed-path and disposable-profile guards. Its current controller hash matches the independently executed extended 12-case diagnostic matrix, of which three cases concern the guarded Goblin writer: normal/retry, a real Linux buffered-write limit, and denied directory permissions. The scope is fixed audit writing, not a new Goblin gameplay campaign.

This mergedown review independently checked exact source hashes against those receipts and reconstructed/verified all 169 original archived files by size and SHA-256. Both retained cross-review ZIPs pass their CRC checks. It did not rerun the original OS campaign or claim Windows completion. The original archive is 50,283 bytes with SHA-256 `c746dc03abd8c18f79a04dafd391b79db537c82e0fd1769d37202434f7f8d679`; source-bound evidence links and hashes are in the machine register.

## Reconciliation with current Art

A read-only merge-tree of the a03 donor against current integration `97585a0af02f1534eb254adf2d2fbe9036a281b2` produced two textual hunks in `art_batch_panel.gd`: export progress and cancellation. Resolve both by retaining the donor's verification/refusal messages and the current `_set_traffic_path` helper, which preserves the newer lazy presentation behavior. Do not restore direct `traffic_path.text` writes.

Provider and Archive merged mechanically, but that does not qualify the result. Preserve the current asynchronous encoded/prepared-byte `_store_event` path, namespace checks, history admission, exact provider/World/session guards, and Architecture-owned preview/approval/Undo. Run the real storage-fault and integrity cases plus current request admission/preparation, response preparation, session logging, owned transport, and the mounted native Architecture case. The event verification read is bounded by the existing record limit but synchronous; current large-record preparation and responsiveness controls must remain meaningful. Do not overwrite the current provider or panel with their earlier donor files wholesale.

## Reconciliation with Goblin002

The successor at `21c9a667` has a larger fixed output allowlist, compact JSON, separate Corpus/Transcript bounds, and a cumulative profile-evidence budget. The Goblin001 donor function is simpler and uses formatted JSON. Copying it wholesale would remove the successor's existing limits.

Keep the successor's guards, compact serialization, `Corpus.MAX_BYTES` versus `Transcript.MAX_BYTES`, and `MAX_PROFILE_EVIDENCE_BYTES` checks before creating staging. Replace only direct write/flush/rename with the verified utility. Then exercise the actual storage faults, wrong-path/profile refusal, budget exhaustion, corpus/replay/reduction persistence, and complete current controller checks. Separate transcript, summary, corpus, and replay files remain separate transactions.

The extended diagnostic harness runs four kinds by default and depends on additional diagnostic-consumer repairs outside this narrow set. A narrow adoption must supply an explicitly selected Goblin route or a separately reviewed small driver using the existing fixture; it must not claim the entire 12-case matrix passed on unrelated unrepaired consumers.

## Remaining gates

Preserve the coordinated donor handoff, qualify each actual resulting application and Windows locking behavior, and retain the pending Art settings/operation-receipt findings until their own reviewed correction appears. This preparation does not import the unfinished documentation programme, grant physical/creative owner acceptance, or authorize a runtime/public release.
