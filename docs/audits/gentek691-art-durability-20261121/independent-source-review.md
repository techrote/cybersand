# Independent Art durability source review — prequalification

**Date:** 2026-11-21 14:30 UTC.
**Reviewer:** independent reviewer agent; no repository implementation edits and no remote review posting.
**Scope:** dirty candidate based on reviewed commit `c163f1af722e37f802eb0a89a7aff6fa76634e04`, PR #691.
**Verdict:** **SOURCE CLEAR FOR FOCUSED QUALIFICATION; overall HOLD remains.** No confirmed blocking source defect remains from this independent pass. This is not final-source CI acceptance, Windows qualification, publication/provenance acceptance, or physical Windows/NVIDIA acceptance.

## Original findings and independent findings

The original unreadable-profile P2 is closed in source by distinguishing a genuine absence from invalid, incomplete, unreadable or unlistable storage, retaining an earlier trustworthy session association, and reporting an unknown association explicitly. The original loaded-Art P2 is closed by staging before raw/visible writes, tracking those commits separately, checkpointing the saved session, and unlinking only after complete success. I inspected the original baseline evidence and implementation tests; I did not rerun the unmodified baseline during this independent pass.

Five additional P2 defects were independently demonstrated during review and then closed. The before/after logs are retained beside this report. All listed probes used pinned Godot 4.7 and the actual native-backed Workbench with real file/directory/permission faults. Completion fixtures enter through the mounted history-completion signal; these isolated probes are not a substitute for the formal suite's actual PAINT → native Undo/Redo interactions.

| Independently found defect | Before | Verified correction / after |
|---|---|---|
| Cleanup of an older committed receipt rewound `last_result` after a newer result | `stale-context.log`: exit **1**; latest visible turn newer, latest result older; journal 0 | `stale-context-fixed.log`: exit **0**, newer result and turn retained; 3 turns, journal 0. Cleanup-only replay no longer updates live context. |
| Expected visible digest depended on memory-only redaction secrets | `redaction-seed.log`: exit **0**; separate-process `redaction-recover.log`: exit **1**, restoration refused, turns 0, journal 1 | `redaction-seed-fixed.log` and `redaction-recover-fixed.log`: both exit **0**, restored 2 turns, journal 0. Schema 2 freezes sanitized raw/projection data, with epoch and projection digest bound into the receipt. |
| Execute-only prior storage was mistaken for empty storage | `unreadable-storage-execute.log`: exit **1**, mode 0100 incorrectly classified as `no_session`. Mode 0000 control in `unreadable-storage.log`: exit **0** | `unreadable-storage-execute-fixed.log`: exit **0**, explicit storage-inspection error. Enumeration success is checked before profile absence, journal emptiness or quotas are inferred. |
| Automatic retries leaked a newly published raw-only segment on every failed first profile checkpoint | `checkpoint-growth-coherent.log`: files grew **[2,3,4,5,6]**, then 7 after repair. Observational probe exit **0**, despite the bad growth | `checkpoint-growth-fixed.log`: files stay **[2,2,2,2,2]**, then 2 after repair; exit **0**, original hash unchanged, exactly one result added, journal 0. One bounded, verified segment is reused for checkpoint retries. |
| Clock rollback plus an unlistable journal reversed eventual receipt chronology | `listing-clock-seed.log`: exit **0**; separate-process `listing-clock-recover.log`: exit **1**, `[newer-second, older-first]`, journal 0 | `listing-clock-seed-fixed.log` / `listing-clock-recover-fixed.log`: exit **0** / **0**, `[older-first, newer-second]`, journal 0. Immutable identity is separate from validated durable publication order. |

Every log has a matching `.returncode` file. Reproducers are `probe_stale_context.gd`, `probe_redaction_restart.gd`, `probe_unreadable_prior_storage.gd`, `probe_unreadable_prior_storage_execute.gd`, `probe_checkpoint_retry_growth.gd`, and `probe_listing_clock_order.gd`.

An additional design check covered two continuing completion callbacks where the first journal write fails and storage recovers before the second callback, before the retry timer runs. Both `volatile-sequence-loaded.log` and `volatile-sequence-unopened.log` exit **0**: two receipts retained, original ID unchanged, older/newer order preserved and journal 0. Reproducer: `probe_volatile_sequence.gd`. Both queues now serialize publication behind earlier volatile receipts. The native owner's grouped continuation bypasses the guard on starting a new history action, so that ordering guard is necessary.

The clock fixture uses the real capture/publication path with its initial monotonic clock advanced ten minutes; a separate process resumes with the normal clock. It does not change the host system clock. Permission probes restore permissions on their isolated fixture directories.

## State transitions and safety branches reviewed

Line references refer to the source hashes below and may move after further edits.

- `art_batch_panel.gd:249,259`: authoritative incremental restoration, cleared live-turn staging, pending receipt registration before replay, and explicit profile repair. An unknown late journal record initiates incremental replay.
- `art_batch_panel.gd:756,870`: atomic profile replacement; unreadable/incomplete/absent profile distinctions; directory enumeration failure; cached association through outages. No historical transcript scan is introduced into a native callback.
- `art_batch_panel.gd:923,935,959,967,1019`: strict journal filename/order parsing, bounded enumeration and quotas, frozen projection/epoch validation, source/ID checks, temporary-file atomic publication (short same-directory `pending-<random>.partial` names at line 1005 avoid unnecessary Windows path length), immutable capture identity, and order assignment only after successful enumeration. Legacy schema-1 journal filenames remain readable.
- `art_batch_panel.gd:1044,1072,1105,1113`: unopened and loaded staging, bounded volatile fallback, serialized retries, strict UTF-8/newline/size/read-result checks, malformed or aliased journal refusal, and validated durable order sorting.
- `art_batch_panel.gd:1166,1207,1214`: source-ancestry filtering; raw → turn → checkpoint → unlink transitions; exact retry identity; crash cleanup; duplicate suppression; cleanup-only context preservation.
- `art_batch_panel.gd:1281,1302,1333`: later conversation/model traffic gating, saved-profile association checks and refusal to overwrite an unrelated selected session.
- `art_provider.gd:204,280,468`: bounded pending-only identity tracking; schema-2 frozen raw/turn hashes; exact role/content/epoch/event shape; prior raw requirement; source ancestry; structural IDs retained through conversation validation.
- `art_provider.gd:323,525,561`: refused cross-session rebinding while a first history checkpoint is pending; provisional replay state; cancelled/corrupt replay rejection; clear/edit semantics; structural history-turn recognition when the free-text prefix was redacted.
- `art_provider.gd:720,808,848`: frozen sanitized writes accepted only against registered exact hashes; commit observation after actual storage success; one bounded pending segment; canonical-path, alias, size, digest, parent identity, payload and admission validation before retry adoption. The retry reads only its newly written bounded header-plus-receipt file, not an inherited transcript.
- `shared_workbench.gd:312,319,375,1306,1541`: lazy completion path, cached session source, serialized unopened queue, transfer to Art, later-history guards and retry behavior.

Source association retains the established saved pathname plus validated archive ancestry. It does not independently authenticate replacement of a root at exactly the same pathname. I found no demonstrated ordinary session-switch contamination and no justification to add callback transcript reads or a new session architecture. Credential values are sanitized at capture; schema-2 digest matching prevents changed raw/turn data from taking the frozen-write path.

The inspected delta contains Art persistence code, focused tests/runner/workflow and documentation. It changes **no Gentek geometry, Water behavior, actor composition, native history ownership or production defaults**. `art_traffic_archive.gd` and the compiled native sources are unchanged. `git diff --check` passed.

## Runner and publication review

The focused runner checks real process return codes, one completion marker, positive assertion counts, zero reported failures and error diagnostics. It records source/script/runtime/engine hashes, isolates profiles, rejects source drift, uses separate restart processes, and uses a flushed witness plus a real process kill for the committed-turn crash boundary. I inspected its updated schema-2 order/identity crash-witness validation. The original graphical 512×512 Flatten author/reopen and recovery commands remain in the focused workflow; headless Art probes do not substitute for them.

The guarded publisher change at `.github/workflows/gentek80-water-merged-requalification.yml:544–584` replaces `--force-with-lease` with an ordinary fast-forward push, retaining an exact transport lease through a bounded pre-push hook. The hook requires exactly one update to the owning integration ref, the advertised old OID equal to the qualified source, the new OID equal to local HEAD and HEAD to be a direct child of that source. It forwards the original arguments and stdin to the actual Git LFS pre-push operation. Existing source validation at lines 57/512/539, four-file staging at 529, index validation at 533/540 and the single-parent check at 544 remain. No new publication mechanism or force update is introduced.

I independently extracted that exact hook and exercised actual local Git push/receive against an isolated bare repository. All **five** transport cases behaved correctly: matching source publishes (exit 0); an ancestor reset before advertisement, a newer sibling and a deleted target refuse (each exit 1); a remote update injected after the hook checked the advertisement also refuses at receive (exit 1), preserving the newer ref. The last case invokes the actual Git LFS helper after injecting the local race. Evidence: `publication-lease-probe.json`, bound to workflow SHA-256 `edb1c67b1e9d4f79ac40602faa4c9ce4f37edaa84ffeb87a38967958f7a3b374`. This transport probe does not replace actual four-file native publication qualification.

No obsolete workflow was dispatched and no remote state was changed by this reviewer. The final reviewer must still independently inspect the frozen source SHA, Linux/Windows focused evidence, guarded publication's four paths and hashes, complete same-source CI matrix, extracted Windows package replay and owner handoff.

## Current file identities

These identify the production/runner source reviewed at the close of this pass. The before/after probes were run during the repair sequence; this table does not relabel those development probes as final-commit acceptance.

| File | SHA-256 |
|---|---|
| `godot/scripts/art_batch_panel.gd` | `29da7f411f618bfb9aabc3c2d342cf0ae965b52d6767cb8b0984f2e263e96b85` |
| `godot/scripts/art_provider.gd` | `dabad42f3385d06d62463f8a1e4a36c173cbccbaec9075ae83ccc92e83f3a09f` |
| `godot/scripts/shared_workbench.gd` | `fcd89085d5a3aff47d3bdf6c8d6013ebfdcb015ff8a8db33d328f2a1fca34185` |
| `.github/workflows/gentek691-art-history-repro.yml` | `31412eac12140cb116dee575b29da5acb57ec834cfcd8b16310c42e802a6e42a` |
| `.github/workflows/gentek80-water-merged-requalification.yml` | `edb1c67b1e9d4f79ac40602faa4c9ce4f37edaa84ffeb87a38967958f7a3b374` |
| `tools/ci/run_art_history_recovery.py` | `58a0f92d59a9994911c760b3d36cadbab735923ea51e808097f3377c74007895` |
| `godot/tests/test_art_history_receipt_identity.gd` | `7988e8d6c5a9ab6827d21d09a671da7893d29f62e0f75de9c9ee58677008f149` |

The development probes used Godot `4.7.stable.official.5b4e0cb0f`, Linux engine SHA-256 `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`, and retained Linux native library SHA-256 `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`. These existing compiled-input identities support the development probes; new broad source/package acceptance remains outstanding.

**No final CI acceptance is claimed. Preserve Draft/HOLD, no merge, no Ready promotion, no production-default changes, and no physical Windows/NVIDIA claim.**
