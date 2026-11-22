# Native Wave invalidation: source-bound live-state evidence

The first PUBPRES-003 native correction avoids storing `false`/`0` into already-invalidated Wave column marks on every changed wet cell. The adjacent strip owns different scalar array elements, but those elements and other frequently read Wave metadata share cache lines. The correction preserves the exact values and ownership; it does not change Water laws, budgets, worker counts, native tick credit or any Workbench setting.

This evidence establishes exact native state and inventory parity. The separate [balanced native-phase campaign](../native-column-abba01/REPORT.md) reports a modest favorable timing signal and retains its run variance. This is not a claim that large-canvas playability is solved.

## Exact source and executable identities

| Role | Source commit | Native SHA-256 |
|---|---|---|
| D0 diagnostic application, unchanged native baseline | `1dc272df857407187596bbdc52b4125e2252551c` | `a842d77977644ea330d826710ac7cf50a7b1150f0e8b65a27101e481e73b06ae` |
| C1 conditional native stores | `4215a9b2b3681b11a0115fc896c23fbde3d6ed6f` | `f4b4ab71d4900a9244d76253cf5294f774b6e15a70ebb181fef50b660f44ca71` |
| Native test harness only | `1e912084362ea92f03f226e0409573086983d6e2` | Exact harness executable and source hashes are in the receipts |

D0 was independently rebuilt from its exact commit; its native binary is naturally byte-identical to frozen `d316c281...` because the complete native input closure is unchanged. It is not an old executable relabelled with a new build receipt. C1's only native change is the conditional-store patch. The test harness is a separate executable compiled from the identified test source and dynamically linked to each named native module; retained `ldd` output proves the selected module path. The harness does not call Godot APIs. Both native builds use the same pinned godot-cpp input closure and explicitly declared local GCC 14.2 toolchain drift. Final hosted pinned-toolchain qualification is a separate gate.

The test-only commit can be cherry-picked independently. Its ancestry also contains an unqualified paired-column scheduling experiment, but that experiment is **not** present in either tested native module in this evidence bundle.

## What actually passed

Each runtime executed one new native regression, `wide current gameplay keeps exact parallel state`, from a suite containing 48 registered tests. This bundle does not claim all 48 tests passed.

The fixture uses a 1024×256 closed domain at negative global origin, current gameplay's two Wave rounds, full-face sheet/crest spill, ballistic parcels and a partial viewport pause/resume. It runs 96 actual native ticks with each of 1, 2, 4 and 8 workers. At ticks 16, 32, 48, 64, 80 and 96 it independently scans stored Water, checks the Water-cell population, adds in-flight parcel quantity and closes both native and ballistic transfer ledgers. The full live `physical_state_hash()` is recorded at each checkpoint. This is not the prepared construction hash.

All 24 checkpoints are exactly equal across D0 and C1, including physical hashes, conserved inventory and live parcel counts. Each runtime also compares the full checkpoint sequence between its serial and parallel executions. Real multi-worker participation is required. The original per-runtime process records, complete outputs and the cross-comparison receipt are retained.

## Reproduction

Build the native artifacts with the existing `tools/pubpres_playability_build/build_runtime.py` from the two exact commits and the same qualified dependency/toolchain inputs. The archived `PUBPRES-RUNTIME.json` files preserve all original commands and 105 native source-input digests. Obtain the test-only source identified above, then use explicit task-specific paths:

```sh
g++ -std=c++20 -O2 -pthread \
  -I"$PUBPRES_SOURCE_ROOT/native/include" \
  "$PUBPRES_SOURCE_ROOT/native/tests/test_wave_spill.cpp" \
  -L"$PUBPRES_RUNTIME_D0" -l:libcybersand_native.linux.x86_64.so \
  -Wl,-rpath,"$PUBPRES_RUNTIME_D0" -o test_wave_spill_runtime
LD_LIBRARY_PATH="$PUBPRES_RUNTIME_D0" ./test_wave_spill_runtime \
  --filter 'wide current gameplay keeps exact parallel state'
LD_LIBRARY_PATH="$PUBPRES_RUNTIME_C1" ./test_wave_spill_runtime \
  --filter 'wide current gameplay keeps exact parallel state'
```

Verify runtime and harness hashes, module resolution and all 24 checkpoint rows before comparing. The archived original driver retains the exact local commands used. Correctness runs overlapped compilation deliberately; their durations are not performance observations.

## Retained records

`archive.json` binds every byte of `native-live-state-raw.zip` and each member with SHA-256. The archive retains the original build/dependency receipts, complete native test/compile logs, process records, loader output, disassembly demonstrating real conditional machine-code stores, and original driver. The compact JSON files beside it expose the same exact native results without requiring archive extraction. Original evidence was copied, not rewritten. The broader native-phase campaign's raw gameplay captures and exact binaries are retained through its separate artifact custody record.
