# CI-OPT-003: bounded showcase runtime concurrency investigation

Disposition: **source-level GO for a bounded two-job experiment**, subject to sanitizer runtime/RSS measurement and actual failure/cancellation tests. No source changes made for this investigation. The soliding candidate and first worldgen candidate remain frozen.

## Independence finding

The seven ordinary, no-argument showcase executables are scientifically independent. Each constructs its own generators, deterministic fixtures and material oracles. Assertions, gates, measurements and seed-survey containers are process-local. There is no cross-executable file, RNG, network or mutable-state dependency in the ordinary invocation.

| Executable source | Ordinary entry point and calls | File-writing paths excluded from ordinary invocation |
| --- | --- | --- |
| `native/tests/test_megatruss_station.cpp` | lines 476–495: deterministic contracts, controls/seed programmes, geometric hierarchy | `legacy_snapshot` line 270, requires `--legacy PATH` |
| `native/tests/test_seeded_typology_megablock.cpp` | lines 480–494: six complete contracts; 148 repaired CLASSIC maps and 32 declared seeds | No file I/O |
| `native/tests/test_metabolist_spine.cpp` | lines 421–441: deterministic contracts, controls/seed programmes, geometric hierarchy | `legacy_snapshot` line 321 / `viaduct_snapshot` line 352 require explicit argument |
| `native/tests/test_interlaced_viaduct.cpp` | lines 356–374: deterministic contracts and controls/seed programmes | `legacy_snapshot` line 269 requires explicit argument |
| `native/tests/test_rosework_gatehouse.cpp` | lines 457–477: deterministic contracts, controls/seed programmes, geometric hierarchy | `legacy_snapshot` line 280 / `viaduct_snapshot` line 437 require explicit argument |
| `native/tests/test_interlock_brutalism.cpp` | lines 433–452: deterministic contracts, controls/seed programmes, geometric hierarchy | `legacy_snapshot` line 285 requires explicit argument |
| `native/tests/test_suspended_arcology.cpp` | lines 420–439: deterministic contracts, controls/seed programmes, geometric hierarchy | `legacy_snapshot` line 285 requires explicit argument |

The optional `--benchmark` paths use wall-clock timing; none is selected by the canonical Makefile. Ordinary assertions compare exact cells, hashes, receipts, geometry, known counts, connectivity or refusal outcomes, not elapsed time. Shared generation implementation contains no file or process-global external-state mechanism.

Each executable contains one bounded `std::async(std::launch::async, ...)` regression (Megablock invokes it once for each of its two fixed origins). Each waits with `future.get()` before continuing. Two concurrent test processes can therefore briefly create four runnable test threads, fitting the observed four-CPU host. With GNU Make's existing two job slots, one compiler plus one test is at most three runnable compiler/test threads; launching an independent two-process pool inside a Make recipe could instead overlap a third Make job and oversubscribe this bound.

Source authority: unchanged files at `846fe0533b3170e7b01f690518da49fc40cc24d1`; e.g. https://github.com/techrote/cybersand/blob/846fe0533b3170e7b01f690518da49fc40cc24d1/native/tests/test_megatruss_station.cpp .

## Existing measured evidence and limits

The admitted normal same-host profile at `performance/artifact-14729210780/worldgen-test` measured a 121.321706775-second sequential seven-showcase loop. Individual stdout boundaries give approximately 9.68, 25.96, 26.27, 7.93, 19.45, 14.56 and 17.47 seconds in manifest order. The loop's own `command-index.json` record reports max-child RSS **21,672 KiB**; the roughly 90 MiB maximum across all test invocations is outside this seven-child loop. These are per-process maxima, not concurrent aggregate RSS.

At unchanged per-process speeds, a two-slot work-conserving queue in original order would take approximately 68 seconds instead of 121 seconds, eliminating approximately 53 seconds from this normal tail. Against the measured 235-second normal make command, that is a **hypothetical ~23% command-level saving**, not an observed CI speedup. Compilation overlap, scheduler overhead and CPU contention can change it. The ASan/UBSan pair is still needed: no sanitizer runtime or RSS saving is claimed here.

Source fixture arrays are modest (typically 512²/1024² material maps and bounded connectivity vectors). This supports investigation but cannot replace measured ASan RSS, including its allocator/quarantine overhead. Do not infer memory safety from normal RSS alone.

## Smallest candidate design

Prefer using **GNU Make's existing `-j2` jobserver** rather than adding another scheduler:

1. Introduce seven phony per-binary execution targets for each normal/sanitized mode. Each depends on its original binary and runs that binary once with no arguments and the exact existing sanitizer environment.
2. Make `gentek-showcases-test` / `gentek-showcases-sanitize` depend on those seven execution targets. Existing worldgen targets continue to require the showcase aggregate before running the nine original principal test recipe lines.
3. The execution targets must remain phony so warm objects never cause tests to be skipped. All compilation/source/flag contracts remain unchanged.
4. Keep each process's stdout/stderr together. The smallest console-only approach is GNU Make `--output-sync=target`, explicitly added to both canonical worldgen make argv and their independent policy inventory. That is an intentional logging-option change, not byte-identical outer argv. An alternative is per-test private logs and ordered final replay, but it adds log-retention/error-path machinery.
5. Preserve family/source/run/attempt receipts and the existing command/family watchdogs. No test result is accepted until all seven showcase executions plus the nine principal executions pass.

The test process completion order is intentionally no longer fixed. Update `check_worldgen_build_inventory.py` honestly: preserve an exact seven-member showcase obligation and the ordered nine-test principal tail, rather than retaining an inaccurate claim that all 16 execute serially. Dry-run matching alone is insufficient; actual process tests must prove every phony obligation executes once and the ninth principal test is still required.

**Failure nuance:** GNU Make stops scheduling after a recipe failure but waits for already running peers. A failing child plus a stuck peer therefore relies on the outer watchdog to finish cleanup; current parallel compilation already has this behavior. A requirement for immediate peer termination would justify a small dedicated runner instead, with a complete compile-before-run barrier or proper jobserver participation. Do not add an unconstrained thread/process pool merely to avoid this design choice.

## Necessary adversarial and hosted gates

- Every original binary runs once, including warm-build invocation; no duplicate, omitted or substitute executable is admitted.
- At most two Make jobs; prove two process overlap, maximum concurrency and the ordered nine-test tail using barrier executables, not sleep-duration performance claims.
- A nonzero first/last showcase, crash, launch failure and missing binary prevent aggregate success and prevent the principal tail from being represented as complete.
- A failure plus a blocked peer, SIGTERM during two active tests, and outer timeout kill/reap all owned descendants and retain failure logs; no surviving child or false success marker.
- No log interleaving destroys a JSON scientific result; each original assertion count/material result remains readable and attributable.
- Manifest mutations (omitted/duplicate showcase, removed ASan/UBSan variable, premature aggregate completion) fail closed.
- One source-matched, same-host sequential-versus-two-job experiment for the complete normal and sanitized commands, retaining every compiler invocation, test output and aggregate receipt. Measure child and aggregate concurrent RSS, not only max-child RSS.

Recommendation: wait for the admitted sanitizer profile to locate the dominant serial work, then implement this isolated runtime candidate if its seven-showcase tail is material. This is a more direct runtime opportunity than repeatedly trying to improve the already-small longest-TU scheduling result.
