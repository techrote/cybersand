# SWARM-004/005 R3 exact-source scientific/native audit

**Disposition: GO for the inspected R3 hosted Linux source, native and scientific evidence. No P1/P2 finding was identified in this scope.** Owner acceptance, full resulting-source CI and runtime publication remain separate admission gates.

Reviewed [run 44953582341](https://github.com/techrote/cybersand/actions/runs/44953582341), attempt **1**, using immutable execution source `96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f`, frozen source `79b8a0a4a1c2ace435d709b35114ee7065c935e6`, and accepted main `846fe0533b3170e7b01f690518da49fc40cc24d1`. Review date: 2026-11-21.

All source comparisons use those immutable commits, not the checkout's moving HEAD. The later publication-request child `a7c0a6d42f4a41622faf183c01818ffb73c56899` was observed to change only `.github/swarm45-runtime-publication-request.json`; it is not substituted for the original R3 producer identity. No source, fixture, donor, original receipt or SWARM-006 content was edited, and no remote action was taken.

## Exact source and producer custody

The native definition remains:

`217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7`

All **43 definition inputs**, all **147 native source inputs**, and all **106 extension source inputs** are unchanged from R2. The definition was independently recomputed from its ordered raw Git blobs. The full **1,763-entry build ledger** was checked against R3 Git blobs with the existing declared source-file normalization. The changed build inputs are the declared Godot inspection/tests and source/package staging files; no research fixture, native generation rule, policy or budget was tuned.

The request receipt, build record, runtime provenance, replay manifest and native execution receipt agree on source, tree, run and attempt. The frozen/source-only request ancestry and all declared donor/main ancestors were verified.

The root source manifest `frozen-source-provenance-r3.json` retains SHA-256 `f335475d7df31e2a370613d185ce97e354984ce09c983d0d6897ac633af75489`. Its source/build ledgers agree with the hosted records. All **150 listed frozen-source inventory entries** were checked against frozen commit `79b8a0a4…`, including exact bytes, SHA-256 and Git blob identity.

Its committed copy at control commit `395b93393adcc379dabeffeb75be9eb19557ad33`, under `evidence/swarm45-mainline/`, is byte-identical. The committed prior R2 independent audit and prior scientific difference classification also match their retained originals.

| Archive | Artifact ID | Bytes | Verified SHA-256 |
|---|---:|---:|---|
| linux-runtime.zip | 14726659913 | 77,157,548 | `5bb7b48ce0156e359c1c1394d32e45a68e4badef6154191300a2c254face4302` |
| linux-evidence.zip | 14726599971 | 79,930,037 | `4de8f1a18fb95d508a073945c4d2c28a47b7a00d1f7c3ea60fbc050e8503353b` |

Direct archive-member comparison verified **419 scientific/native evidence members** and **16 runtime members** against extracted bytes. All fifteen declared payload files matched their hashes/lengths and all binaries had the expected Linux ELF64/x86-64 format.

All **fourteen binaries are byte-identical to their R2 counterparts**. The only declared payload-file difference is `toolchain.txt`, which records the new source commit. R3's new runtime provenance and execution receipts retain the R3 identity; R2 records remain attached to their original producer. Byte equality is evidence of deterministic unchanged native payloads, not permission to relabel old receipts.

## Full 360-output comparison: no output normalization required

R3's producer reports **360/360 executions, zero errors and 159.539 seconds**. The independent audit verified each exact matrix key, actual option set, schema/type, source/seed/definition, measured metrics, Apply invariants and closure availability.

For every case, both R3 and R2 gzip bytes were read, their recorded compressed and raw hashes/lengths checked, and their decompressed native JSON compared directly:

- **360/360 raw JSON outputs are byte-identical.**
- **360/360 gzip files are byte-identical.**
- All **720 gzip files**, and their corresponding decompressed hashes, were reverified.
- Each run retains **1,590,991,388 bytes** of native JSON.

No output normalization was needed. Thus material arrays, provenance, graph/connector/obligation evidence, all request limits, all work accounting, statuses, reasons, digests and unavailable closure match exactly. The prior identity normalizer remains unchanged and was not broadened.

| Policy | Complete / Blocked / Exhausted |
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

The primary BOTH versus OFF/OFF result remains negative: **zero new/lost Apply successes and no increase/decrease in joint counts**. Each primary arm retains 21 closure-unknown outputs with null unavailable summary metrics. Fixed territory retains 19 unknown closures; hard-only retains twelve.

The previously reviewed difference classification versus frozen #697 remains intact: 251 normalized-identical executions, 96 work-counter-only changes, one remaining-proposal-allowance change and twelve fixed-territory admission/failure-trace changes. Its original SHA-256 remains `08bd9a02baf43470f4de43924ce0d735ac7c849c4cb8889c033e0ac55b895787`, including the byte-identical committed copy.

Diagnostic case 19 still reaches **Blocked**, four joints and one unresolved obligation after the accounting repair; Apply remains false. The other eleven changed diagnostic traces remain Exhausted/closure unknown. R3 introduces no new scientific outcome, denominator, holdout or generalization claim.

## Native execution and control checks

All eight build-command records and their logs, eleven process receipts, and all 46 native-evidence file hashes verified. All native processes returned zero without timeout. Five strict suites and the corresponding ASan/UBSan suites pass; the additional V3 harness retains eight paired native cases and four denied malformed requests.

The eight actual V3 JSON outputs are also byte-identical to R2. Their source/options, occupied material counts, status, joint count, closure and Apply authority were checked. Viaduct remains Blocked under all four switch combinations. Irregular's compact-OFF cases remain Blocked at 6,034 cells; compact-ON cases remain Complete at 6,026 cells, zero outstanding and zero joints. These are synthetic native reproductions, not physical-owner acceptance.

The replay executable retains SHA-256 `35f0dc15d35b158e508edd45f4da6f1726f43892de93b86850c7992a2815f72c`. R3 runtime provenance SHA-256 is `bf0d615a184cb6d2ca9cab0fb1eea254a4db7d8459b6994d13d1fe227a05fb1b`; replay manifest SHA-256 is `1ea616848f6a3796587fe9363459feca68dfa72fbae736c14e79ff047ceecc82`.

## Auditable records and limits

The complete machine-readable audit is `swarm45-hosted-r3-native-science-audit-96b8d3f.json`, SHA-256:

**`092da9142ae67ec1db9a5aabc732207069125c1f6786300e1950cd52c4693be4`**

The scientific-chain record is `swarm45-hosted-r3-scientific-chain.json`, SHA-256 `97bbf5d9adf3e5c57f375fe97beeb86778f648033f256ff3a79a0a248b393f2a`. It binds this audit to the independently verified R2 audit and the unchanged earlier difference classification.

This concludes the exact R3 scientific/native delta review with **GO**. It does not replace independent Windows/package/UI review, the full CI result on the actual published runtime HEAD, runtime publication custody, or the owner's physical NVIDIA/original-map/visual/gameplay acceptance. Original R2 and R3 source/runtime labels remain unchanged, and no automatic merge is authorized by this report.

