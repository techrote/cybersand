# Goblin002 verified audit storage integration

Exact candidate `7f7095a0664afc1225346d782deb42ab04f81aeb`, tree `a78ea1ac28af809d41ac14f0c172c8e523abd207`, preserves prepared successor `21c9a667` and its original qualified predecessor ancestry. The change adopts ULTIMA's reviewed complete-file verification and native replacement mechanism without importing the unrelated diagnostic or authoring consumers.

## Reproduced defect and actual repair

The production-identical fixture source `9f3c479efbf356832a691aa2f9c1dbe947c34d32` falsely acknowledged success when a real RLIMIT_FSIZE boundary replaced a valid 1,689-byte output with 128 bytes. The original log, returned success, malformed bytes and previous complete bytes are retained. The repaired source refuses that same short write and actual directory-permission failure, keeps the earlier complete 1,689-byte file, and successfully retries after the fault is removed. Unrelated old staging is retained.

The successor's exact output allowlist, actual disposable-profile guard, compact JSON, 2 MiB corpus limit, 32 MiB transcript limit and 512 MiB cumulative archive limit remain authoritative. Bounds are checked before staging. The utility writes, flushes, closes and reopens staging, verifies every byte, then uses the already accepted native sibling replacement primitive. Distinct output files remain separate transactions.

## Resulting-source qualification

All three real Linux storage scenarios pass. The new 67-check contract covers all ten fixed paths and actual byte ceilings. The unchanged donor's 84 native and injected-I/O boundary controls pass. All six canonical Goblin cases pass: storage, real controller, laboratory/replay/memory, discovery, authored lineage and the actual 447-check AMBIENT handoff/persistence test. The complete Python suite passes 136 tests with the explicit pure-language parity engine configured and no skips. Fresh imports, original 300-second case/240-second import watchdogs and 3072 MiB owned-process bound remain intact.

The packet retains complete source maps, source/runtime provenance, process receipts, actual profiles, original failures and log hashes. Native105/Rapier4 inputs and actual retained runtimes remain unchanged. Python parity remains a synthetic control, distinct from the actual native gameplay tests.

Actual Windows locking/current-source package qualification and independent review remain pending. This is prepared #781 work, not a mainline merge, physical acceptance or resolution of the original 512/1024-action timeout limitations.

Evidence: `goblin-storage-evidence.zip`, 3943246 bytes, SHA256 `4a5b897d3792c83576fe629bf374b3c346ad0e6f49805be20d68fb6f2237326a`.

The evidence manifest records six excluded derived engine-documentation caches and five exact-byte aliases to the retained identical source ZIP. All original process receipts, actual output bytes, application source, raw logs and assertions remain present. This is storage deduplication, not an execution or qualification change.
