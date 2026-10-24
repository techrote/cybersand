---
title: MAT-003 bounded correctness-only qualification plan
status: Planned
document-kind: design
scope: Future bounded neutral-state correctness qualification proposal; no harness implementation, execution or new timing authority
canonical-for: [mat003-bounded-correctness-plan]
last-reviewed: 2026-10-23
related-documents: [mat003-concrete-owner-offer.md, mat003-state-schema-proposal.md, ../decisions/ADR-015-material-state-schema-and-carrier-gates.md]
---

# MAT-003 bounded correctness-only plan

## Authority and entry gates

Prepared at owner request after budget acceptance; **plan only**. No implementation, build, test execution or timing campaign starts here. Budgets are Approved design qualification targets, not achieved limits. R16-T1, the new physical map and carrier/epoch adoption remain conditional. The source intake is `20c2249d498abe14f3c48f7925e2883d79bb98ea`; preserve all accepted source/artifacts/statistics and PR211/221 draft state.

Before future execution, obtain separate authority to build an isolated apparatus, review exact candidate mappings and source identity, freeze the case matrix/fixtures/verifier/binaries/budgets and tool/platform receipts, and independently review apparatus readback. Any gate failure blocks the relevant suite. No existing campaign is rerun to fill gaps; applicable evidence is reused by exact identity. This is not a timing registration.

## Scope and candidate contracts

Prepare three isolated candidate layouts: safe compact C72, safe compact C80 and DUAL64, each E8/E16, plus C64-word E8/E16 controls: eight arm contracts. These are intended contracts, not currently implemented new layouts. The exact proposed maps below preserve the reviewed E8 epoch placement and use the proposed contiguous map for expanded E16 arms. They are contracts for document review, not implemented layouts or approval of R16-T1. C64/E16 retains its existing experimental map as a capability/refusal control.

Exercise an **opaque neutral16 test payload**, with no Water mass/history meaning or feedback. For arms whose frozen map has fewer than16 free bits (C64-E16), nonzero R16 writes must refuse before changing a record; supported smaller raw fields may be tested separately. Matching a payload capacity does not qualify R16-T1 semantics. C64 controls retain current semantic domains; high raw state roundtrip does not widen public validity.

Retain full high64 neutral preservation probes for DUAL64 so neutral16 tests cannot hide corruption above it. Whole moves/swaps copy complete records, partial setters preserve unrelated bits, declared replacement resets follow the frozen schema, and clear preserves non-epoch state. Temperature, nonzero Empty, high state_a boundaries, Water source/sink ledgers, granular support and scheduling predicates remain independent checks. No signed overflow, aliasing violations, mutable snapshots or per-cell physics objects are introduced.

## Exact eight-arm mapping contracts

Bit numbers are logical unsigned bit positions, independent of native byte order. All arms use material bits0–15, state_a16–31 and state_b32–39. R denotes an **opaque unsigned neutral16** test field, never the conditional history/overfill interpretation. A span a–b includes both endpoints. Unassigned bits are U; they are zero in schema-valid test records, while raw-only probes may assign sentinels to test preservation.

| Arm ID | Representation and target size/alignment/stride (bytes) | Epoch bits | R bits | U bits | R admission |
|---|---|---|---|---|---|
| K64-E8 | Word;8/8/8 |56–63|40–55|none|0…65535|
| K64-E16 | Word;8/8/8 |48–63|unsupported|40–47|only0; every nonzero R refuses|
| K72-E8 | safe memcpy compact;9/1/9 |56–63|40–55|64–71|0…65535|
| K72-E16 | safe memcpy compact;9/1/9 |40–55|56–71|none|0…65535|
| K80-E8 | safe memcpy compact;10/1/10 |56–63|40–55|64–79|0…65535|
| K80-E16 | safe memcpy compact;10/1/10 |40–55|56–71|72–79|0…65535|
| D128-E8 | two explicit uint64 lanes;16/8/16 |56–63|40–55|64–127|0…65535|
| D128-E16 | two explicit uint64 lanes;16/8/16 |40–55|56–71|72–127|0…65535|

Size/alignment entries are intended Linux/Windows x86-64 ABI contracts to verify before future execution, not portable guarantees. DUAL64 low/high lane offsets must be0/8, with no padding bytes; mismatch blocks that platform. Compact storage is a byte array; word access remains defined memcpy with explicit little-endian interpretation and bytewise fallback. No unaligned typed pointer is permitted. Word/lanes are numeric uint64 values; canonical record bytes always encode least-significant byte first. No raw native struct becomes a persistence format.

For every arm, masks must be exhaustive and pairwise disjoint. The shared semantic mask is low `0x000000ffffffffff`. E8 epoch mask is low `0xff00000000000000`; R mask is low `0x00ffff0000000000`. K64-E16 epoch mask is low `0xffff000000000000`, R mask0, U mask low `0x0000ff0000000000`. Expanded E16 epoch mask is low `0x00ffff0000000000`; R has low mask `0xff00000000000000` and high mask `0x00000000000000ff`. High denotes logical bits64 onward even for compact byte arrays; valid high widths are8/16/64 for K72/K80/D128. All remaining in-capacity bits are U; bits beyond capacity do not exist. The independent oracle derives masks by enumerating the table's bit positions, not importing these constants or candidate masks.

This deliberately changes expanded E16 epoch placement from the tested48–63 arrangement. No previously tested E16 record may be reinterpreted under it. These are fresh isolated fixture Worlds, with identity per map and source manifest; conversion of saved/accepted records is excluded. E8 neutral16 lives in reserved low-word bits, not in the existing `extra()` tail API. K64-E8 is an experimental word contract with a future checked test interface, not a claim that the production/source-control adapter already exposes neutral16. Accepted controls/source remain immutable: common zero-extension behavior is compared to the frozen source control; a future isolated neutral interface must itself be qualified. Existing tail-only accessors cannot be reused as a uniform R interface.

### Operation and refusal rules

Define two distinct modes before building any apparatus. **Schema-valid mode** admits current-domain semantic fields, epoch in range and U=0. **Raw mode** admits all material16/state_a16/state_b8 bit patterns, in-range epoch/R and arbitrary in-capacity U, without claiming public material validity. For K64-E16, U40–47 is a separate raw8 probe only; even R=1 must refuse through the neutral16 interface. Do not alias R to U on this arm. R outside0…65535 refuses everywhere; validate integer width/signedness before narrowing.

Default record is all raw bits0; World creation/declared material replacement uses its separately frozen Current initialization rules and sets R/U=0. Partial setters change only their named field. Whole copy, relocation and swap transport all in-capacity bits; movement never synthesizes Water history in this neutral profile. Clear changes epoch only. Any replacement is a separately identified operation, not an implicit consequence of a partial material-ID write; the latter preserves R/U and nonzero Empty state. Temperature follows Current sidecar movement rules and is never embedded in R.

For a field update, expected new bits are `(old & ~field_mask) | encoded_value`; compare every other bit. In D128-E16, an R update may change high bits0–7 only and must preserve high bits8–63; epoch updates preserve all64 high bits. In D128-E8, R/epoch updates preserve all64 high bits. Whole copies/swaps preserve the complete high lane by transport, not by leaving the destination unchanged. Raw nonzero U sentinels are storage probes and cannot be submitted as schema-valid records. The old diagnostic cross16 span60–75 overlaps epoch and is excluded from all eight World mapping contracts.

Every checked external record/field admission prevalidates schema identity, integer domains, capability, required capacity and sidecar staging before publication. Refusal leaves target record(s), relevant sidecars, World clocks/activity/support, ledgers and committed capacity unchanged; a separately counted attempt/refusal receipt may advance. Internal raw primitives are not semantic admission and may not serve as the refusal oracle. Current in-tick failure quarantine remains distinct; no transactional whole-tick rollback is promised. Exact Current failure categories must be frozen by source-backed fixture, not invented to fit a refusal expectation.

## Independent oracle and evidence contract

The future verifier must have a hand-authored logical model independent of candidate getters/setters, packers, generated headers, collector decoders and their mask constants. Its authoritative record is a tuple `(material_u16, a_u16, b_u8, epoch_unsigned, R_u16, U_bits)`, plus map ID/mode; unsupported R is logically0 with an explicit capability flag. Derive expected canonical bytes by iterating the mapping table's bit positions. Implement expected operations on logical values first, encode afterward, and compare the full8/9/10/16-byte representation. Freeze oracle source/hash, specification revision, seed and complete65536-operation storage schedule before future execution. Candidate roundtrip alone cannot establish correctness.

Required deterministic storage coverage includes each field's0/1/max−1/max, each one-hot bit, alternating/all-one patterns, lane-boundary R values `0x00ff`, `0x0100`, `0xff00`, `0x8000`, and every pair of setters in both orders, copy/swap/clear/replacement and refusal. Include negative and one-past-maximum inputs before narrowing, wrong/unknown schema IDs, invalid semantic IDs/states and capacity failure. Record the operation index, typed input, expected outcome, pre/post logical values and complete pre/post canonical bytes. For semantic-invalid cases distinguish raw acceptance from checked admission refusal. Freeze coverage counts as well as the seed; a random schedule does not replace named obligations.

For real World runs, C64 comparisons cover common material/state/temperature/ledgers and normalized scheduling predicates under equivalent fixtures. Nonzero R behavior is checked by the independent payload/transport model; K64-E16 is a refusal control and is never compared as a successful payload World. Preserve a distinct zero-R common-control lane in every World fixture. Cross-width epoch labels are not byte-equality targets: record exact labels for each oracle and separately compare `stamp == current_epoch`, support eligibility and completed-tick/clear identities. No normalization may erase R/U, high state_a, nonzero Empty, temperature, Water amount or failure-state differences.

Opaque R has no physics feedback. Its World transition oracle must enumerate source-bound movement/swap/partial-write/replacement sites and fixture actions, recording stable coordinates and complete pre/post participating records; expected R follows the operation rules above. Verify operation coverage from the retained fixture schedule and full state differences, not solely the candidate's claimed event log. Missing or ambiguous transition coverage blocks that fixture. Instrumentation remains correctness-only and independently source-reviewed; no observer-off performance implication follows.

### Complete endpoint and lifecycle readback

Each large process retains exactly eight **complete World endpoint datasets**, not eight sampled cells: for each of event/reference roles, after255 setup ticks (B), immediately after preparation (P), after the next real tick (Q), and after four further ticks (R). Each role constructs/destroys its World sequentially. The reference uses the same semantic setup with a non-clear epoch preparation; freeze the exact event/reference predicate-preserving transformation and expected differing epoch labels before execution. B/P comparisons must independently prove only the authorized epoch/counter restoration changed; Q/R must prove real clear/non-clear behavior and equivalent qualified scheduling/support. Prepared/natural equivalence remains mandatory and source-bound, not inferred from identical occupied cells.

Each dataset streams every resident chunk and every cell in stable chunk-coordinate/local-index order, including sleeping, interest-excluded and Empty cells: complete canonical carrier bytes and optional-temperature presence/values, with logical fields independently decoded by the reader. Serialize fixed-width binary cell records (at most16 carrier bytes +2 temperature bytes); coordinates are implied by the verified ordered complete grid, and decoded logical values are not duplicated in the raw stream. Include World configuration/schema/map/current epoch/completed ticks, sorted resident identities/incarnations, activity/sleep/interest state, support/stamps/deadlines, scheduling/phase jobs and actual worker participation, ledgers/diagnostics and failure/capacity receipts. All relevant sidecar/continuation owners need exact source-symbol-to-record-field inventory, with explicit nonapplicable fields; unknown or unexported relevant state blocks completion. Activity/work observations are receipts, not a replacement for full state.

Freeze full small/natural checkpoints at tick0,1,255,256,257 and final tick; natural E16 adds65534,65535,65536,65537,65540. Record per-tick work/ledger/clear receipts throughout. Store per-operation records for the refusal/lifecycle suite. Before execution, bind every dataset to its exact fixture/action schedule and inventory, and derive byte ceilings using resident counts, field widths and metadata, including the complete large datasets for both platforms. Bound metadata to64KiB per chunk plus1MiB per World endpoint, per-tick receipts to1024bytes, and all storage-operation/refusal/build-log/manifest streams together to4GiB across both platforms. With at most18bytes per cell, the fixed large matrix consumes less than50GiB across both platforms including endpoint metadata; small/natural checkpoints and their receipts fit within another4GiB. Freeze exact source-field encodings within these ceilings before apparatus admission; if relevant state cannot fit, refuse admission and review the plan rather than omit it. The64GiB cap is a stop bound, not permission to sample or omit fields.

The independent reader checks the entire manifest/inventory and all records, hashes, schema/map IDs, operations, refusal diffs, field domains, ledgers, epoch predicates and endpoint transitions. Hashes are integrity checks, never substitutes for parsing or semantic comparison. Collector summaries and material-only hashes cannot authorize a pass. Freeze negative verifier fixtures for missing/reordered/duplicate cells or datasets, wrong maps, corrupted high lanes, false refusals, dropped sidecars and natural/prepared mismatch. These are future harness checks within the separately reviewed build plan; no verifier is implemented or executed here.

## Bounded future matrix

| Suite | Exact bounds | Maximum process count |
|---|---|---:|
| Storage/oracle boundaries | Eight arms × normal and ASan/UBSan; deterministic65536-operation schedule per process, independent byte/field oracle; max1024 live test records |16|
| Small real-World equivalence | Eight arms × Serial1/Phased1/Phased4 × normal/sanitized;256² residency,2048 completed ticks, bounded boundary/material/temperature fixtures |48|
| Feasible natural E16 check | Four E16 contracts × normal/sanitized;128² residency, Serial1,65540 completed ticks, first natural clear65536; deterministic small input schedule |8|
| Resident clear and reentry | Four E16 contracts × sides512/2048 × sleeping/excluded or active-window/excluded × Phased1/Phased4 × normal/sanitized;255 setup ticks, prepared real clear, matched non-clear reference and4 reentry ticks |64|
| Admission/refusal/lifecycle | Eight arms × normal/sanitized; max4 resident chunks,256 attempted operations covering invalid fields, capacity, pause/reentry, construction and failed-world outcomes |16|
| Total per platform | No subsets may claim completion of the whole platform matrix |152|

The matrix is152 processes per native platform,304 for both Linux and Windows. Validate sanitizer/runtime availability before freezing platform builds; unsupported sanitizer execution blocks that platform disposition rather than silently omitting cases.

Matched clear/reference Worlds run sequentially in one correctness process, never simultaneously as an unbudgeted pair. They are not independent performance replicates. Each large case retains the eight complete World endpoint datasets defined above (B/P/Q/R for each role); stream and losslessly compress outside simulation. Small/natural suites retain full records at declared checkpoints and per-tick work/ledger receipts, not a full-world snapshot every tick. The checkpoint identities above are fixed; exact fixture actions and serialized field inventory remain entry gates before execution. Worker4 participation must be demonstrated by observed active fixtures; the natural one-chunk Serial case supplies no worker4 claim.

Reuse accepted full S1 E16 two-wrap evidence where source remains applicable. New mappings still need their own feasible natural first-clear check; modular counter storage tests cover multiple wraps. Prepared events must independently match natural first-clear semantics and exact current-stamp predicates. If restoration equivalence cannot be proved, refuse that arm/suite rather than infer success from low-cost isolated clearing. No E24/E32,4096², natural wide long-run claim or new physical solver is in scope.

## Resource and stop bounds

Bound builds to32 compiler invocations per platform (16 storage and16 reusable World binaries for eight normal/sanitized arm contracts). Freeze a maximum180seconds per compile,300seconds per storage/small/refusal case,600seconds per natural/large case and6hours aggregate wall budget per platform (12hours for both), with one process at a time. Wall time is a harness watchdog only; record no tick latency/startup/input timing samples, ratios or performance rankings. An aggregate budget stop is incomplete, not permission to drop cases. No automatic retries, selective reruns or missing-evidence reconstruction.

Cap retained raw uncompressed semantic output at64GiB for the full matrix and require enough local/artifact capacity before starting; preserve complete streams and hashes. Freeze actual byte/record ceilings for each fixture before execution; exceeding a ceiling records failure and retains emitted evidence. No selective compression or omission of failed states. Build outputs, snapshots and logs stay outside Git.

The proposed harness RSS ceiling is2GiB per normal process and3GiB per sanitized process, including oracle/retention buffers and sanitizer overhead. These are future harness safety budgets, not replacements for the owner's512MiB cellular/2GiB application targets. Account actual engine-owned allocations separately from harness/sanitizer costs. An overrun refuses suite completion; any revised apparatus budget requires explicit review before a replacement attempt. Correctness resource receipts cannot certify a rendered application or p95/p99/tick budgets.

## Independent readback and exit

Use pinned Linux and Windows native toolchains for intended platform correctness; record source/local delta, generated map/header hashes, compiler/linker/version, binary seals before execution, flags, fixture seed, workers and exact invocation. Keep accepted controls unchanged and overlays isolated. Independent verification must parse retained records rather than trust collector summaries, compare all representable semantic fields against controls/oracle, validate refusals leave the relevant admission state unchanged, and distinguish partially mutated failed ticks from atomic external record refusal. Verify ledgers, temperature, high lanes, source/sink accounting, stamps/support, jobs and actual workers separately.

Frozen baseline/source changes or mismatched build/case/order/inventory/hash, nonzero exit, sanitizer finding, stderr diagnostic, timeout, missing state or failed natural/prepared equivalence blocks completion. Retain all failures. Partial suite findings may be reported with their exact scope, never as full qualification. Keep observer-off/observed twins a future performance prerequisite; correctness instrumentation is not a measured observer-off speed result.

Exit artifact: complete immutable152-process-per-platform evidence, independent readback and explicit arm/suite dispositions, with gaps and platform limits. These would qualify only the frozen neutral-state mappings/invariants. R16-T1 requires separate owner semantic approval and solver-programme reconciliation before tests of its authoritative amounts, transfers, conversion yields or feedback. Numeric memory/latency compliance needs separately authorized future apparatus; no benchmark is launched here. Adoption/merge authority remains separate, and both PRs stay draft.
