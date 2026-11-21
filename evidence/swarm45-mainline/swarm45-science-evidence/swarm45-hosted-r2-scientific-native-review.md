# SWARM-004/005 hosted R2 scientific/native audit

**Disposition: GO for the actual hosted Linux native/scientific evidence described here. No P1/P2 finding was identified in this scope.** This is not full integration, Windows package, publication or physical-owner admission.

Reviewed [GitHub run 44950154534](https://github.com/techrote/cybersand/actions/runs/44950154534), attempt **1**, execution HEAD `10fe808ac7f6a4b9c07f7d168763b41957359e57`, frozen substantive source `96cc2772b0b7cf8e273526d3efd081596be1ad85`, accepted main `846fe0533b3170e7b01f690518da49fc40cc24d1`. Review date: 2026-11-21.

The reviewer made no repository edits, remote actions, CI triggers, research/fixture changes, donor changes or original-receipt changes. Evidence and additive audit outputs were read/written only in the provided scratch locations.

## Source, archive and executable custody

The independently recomputed native definition is:

`217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7`

The request receipt, replay manifest, build record, runtime provenance and native execution receipt agree on the exact execution source. Git checks confirm the recorded accepted-main/frozen-donor ancestry and that execution HEAD differs from its frozen source only in the request JSON.

Every recorded source ledger was checked against immutable execution-commit blobs, using its declared CRLF-to-LF source normalization:

| Ledger | Verified entries |
|---|---:|
| Build inputs | 1,763 |
| Native source inputs | 147 |
| Extension source inputs | 106 |
| Native definition inputs | 43 |

The definition itself was recomputed from the exact ordered path-and-raw-byte algorithm. Compared with the previously reviewed `fe62e154…` native source, **42 of 43 definition inputs are byte-identical**. Only `reciprocal_main.cpp` changed, replacing CLI progress/error iostream output with stdio. The experimental engine, fixtures, profiles, selection, registration, external replay driver, runner and custody helper are unchanged. This is not scientific policy tuning.

| Retained archive | Artifact ID | Bytes | SHA-256 |
|---|---:|---:|---|
| linux-evidence.zip | 14726047323 | 79,926,546 | `ec8b5d85349624cbfee53cd35ea7dc49ca6edac0a256c687206f4408dae91101` |
| linux-runtime.zip | 14725977620 | 77,157,570 | `13991e3c6dd5013c515ee96489a810e5f87c7ba9fc5b3da001a79267c6fd6158` |

Both archive hashes and lengths independently verified. Direct archive-member comparison also verified **419 scientific/native evidence members** and **16 runtime members** against the extracted files. This closes the archive-to-extracted-file link without relying only on filenames.

All fifteen declared runtime payload files matched their hashes and lengths; every binary had the expected Linux ELF64/x86-64 format. The exact replay executable SHA-256 is:

`35f0dc15d35b158e508edd45f4da6f1726f43892de93b86850c7992a2815f72c`

Runtime provenance SHA-256 is `4663668f58e6d4ac9ca0c917c05eacf1ae3b9f93f80209a449a05afbabf839a9`; hosted replay manifest SHA-256 is `d48348c41a745e732cf214cd4dc7ffb9a716d2f0c5060e878f86d89df3c1a4d2`. Build context identifies the exact repository, integration workflow, run and attempt. The retained toolchain is pinned Ubuntu GCC 13.3.0 with drift disabled and the disclosed standalone ABI0 flags.

## Complete hosted-versus-local 360 comparison

The hosted producer reports **360/360 executions, zero errors, 122.991 seconds**. Independent review verified all 360 unique matrix keys, actual output option records, schema-5/type identity, input source/seed/definition, metrics, closure availability and Apply invariants.

All **720 hosted and prior-local gzip files and decompressed raw hashes** were reverified. Each side contains **1,590,991,388 bytes** of native JSON. The earlier independent local audit and its manifest were themselves checked against their previously recorded SHA-256 identities.

**360/360 hosted outputs are behavior-identical to the previously reviewed local `fe62e154…` candidates under the existing identity normalization.** The hosted behavior hashes were recomputed from actual JSON. No broader exclusion was introduced.

The unchanged normalizer excludes only compiled-definition suffixes and native Result request/result digests that incorporate the definition. Material/role/provenance arrays, graph/connector/obligation data, masks, limits, work counters, status, failure reasons, composition hashes and assembly/round hashes remain exact.

Raw equality is **0/360**, as expected from the distinct compiled identity. Those raw outputs retain their own hashes; no source retagging or historical receipt substitution occurred.

| Policy | Hosted Complete / Blocked / Exhausted |
|---|---:|
| off_off | 1 / 14 / 21 |
| compact_only | 1 / 14 / 21 |
| receptor_only | 1 / 14 / 21 |
| both | 1 / 14 / 21 |
| both_round1 | 1 / 14 / 21 |
| both_round0 | 0 / 36 / 0 |
| both_frame_frozen | 1 / 14 / 21 |
| both_mosaic_frozen | 0 / 36 / 0 |
| both_hard_only | 8 / 16 / 12 |
| both_fixed_territory | 5 / 12 / 19 |

These results exactly preserve the previously audited accounting-repair outcomes, including diagnostic case 19's Blocked/four-joint/one-unresolved result and all retained failure traces. The primary OFF/OFF versus BOTH conclusion remains negative: no new Apply success, no lost Apply success, and no gain or loss in joint counts.

Unavailable closure remains explicit. Each primary arm retains 21 closure-unknown cases with null summary metrics; the fixed-territory diagnostic retains 19 and hard-only retains 12. They are not counted as closed. This is the already revealed matrix, not new unseen qualification.

## Native execution checks

Eight build-command logs and eleven native execution/process receipts were verified against their recorded hashes. All eleven executions returned zero, did not time out and reported PASS. The ten direct native processes bind to the exact payload hashes; the additional V3 request harness uses the source-bound CLI.

The five strict suites and corresponding ASan/UBSan suites retain the reported checks:

| Suite | Reported successful checks |
|---|---:|
| Assembly | 99,729 |
| Reciprocal MOSAIC | 274,661 |
| Reciprocal coordinator | 263,015 |
| SWARM-005 | 7 tests / 42 assertions |
| Workbench authoring patch | 131,158 |

All 46 native-evidence file hashes were checked. The explicit receptor-bound test retains a maximum-footprint refusal at the unchanged 2,000,000 work ceiling. This review does not expand the retained sanitizer scope into a full sanitized 360-case campaign.

The eight raw V3 synthetic outputs were independently checked for compiled definition, exact switch bits, occupied native material counts, status, closure, joint count and Apply invariants. Viaduct remains Blocked with 6,035 occupied cells and one unresolved obligation under all four switch combinations. Irregular remains Blocked at 6,034 cells when compact termination is OFF; compact ON produces Complete at 6,026 cells, zero outstanding and zero joints, with or without supported receptors. The harness also records four denied malformed requests. These remain synthetic native reproductions, not the owner's original map or physical GPU acceptance.

## Audit records and remaining scope

- `swarm45-hosted-r2-native-science-audit-10fe808.json` — complete source/build/runtime/360-output audit; SHA-256 **`40764003ef42f523649c3f6c081fe36396fba96507785950de9dac5af591caac`**.
- `swarm45-hosted-r2-archive-member-custody.json` — direct archive-member binding; SHA-256 `3b547fd47b1d234c372b171db8cc0bea20ce28c247ce3f5bf1a72d0fbee5a5a2`.
- `swarm45-hosted-r2-v3-native-audit.json` — independent eight-case raw V3 verification; SHA-256 `062b3d2127d045813abc832f88205b6677788c4f5a493838f4d39db5d4c4f589`.

The evidence supports **hosted Linux native/scientific GO at this exact source**, while preserving the original negative research conclusions and current bounded accounting-repair interpretation.

This audit does not clear the pending package/import custody and historical-receipt inspection work, certify a later R3 source, publish retained runtimes, or accept the owner's physical NVIDIA/original-map evaluation. R3 requires its own exact-head hash/delta and artifact checks; the present R2 native evidence remains valid under its original identities. Full integration admission and manual merge remain governed by the separate outstanding gates.

