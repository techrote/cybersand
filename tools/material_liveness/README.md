# MAT-AUTH-002 evidence tools

These tools build the test probe against the actual, unmodified native World and
retain source identity, exact compiler arguments, dependency inventories, binary
SHA-256, host identity and every process result. They do not compile the shadow
catalogue or modify any production input.

The probe includes `native/src/world.cpp` directly to use its existing
`PrecisionProbe` friendship for read-only observation. The default compilation
therefore uses the probe, `material_rules.cpp`, `scheduler_geometry.cpp` and
`settled_world_discovery.cpp`; compiling a separate `world.cpp` would duplicate
its implementation.

Run a committed case registration from a clean checkout:

```sh
python3 tools/material_liveness/run.py \
  --plan native/tests/fixtures/material_liveness_campaign_v1.json \
  --output /absolute/path/outside-checkout/mat354-normal --mode normal
python3 tools/material_liveness/reduce.py \
  /absolute/path/outside-checkout/mat354-normal/campaign.json \
  --output /absolute/path/outside-checkout/mat354-normal/reduction.json
```

Use a new output directory for each attempt. `asan-ubsan` and `tsan` build modes
are available. Sanitizer environment settings are recorded. Leak detection is
requested by default for ASan/UBSan. A separately recorded run may use
`--mode asan-ubsan --disable-leak-check` after a retained LeakSanitizer environment
failure; it explicitly sets `ASAN_OPTIONS` to `detect_leaks=0` and records leak
checking as **unexecuted**. The reducer preserves that limitation. The flag is
invalid for normal/TSan builds, and an implicit `detect_leaks=0` environment
override without the flag is refused. A process timeout, nonzero exit, source/binary identity change or
compatibility failure terminates the attempt and preserves its failure receipt.
The manifest supplies the time limits:60 seconds per case,900 seconds for the
complete build including every compiler/link step, and1800 seconds for the
whole campaign. Optional CLI bounds may shorten these limits, never extend them.
Remaining cases are unexecuted, not passing. No causal campaign should run before
its registration is committed.

Each process writes stdout/stderr to unique private temporary files. The driver
flushes, fsyncs and closes both files, then atomically publishes final names
without overwriting existing artifacts. Linux uses `RENAME_NOREPLACE`; Windows
uses its nonoverwriting rename; the portable fallback uses atomic hard-link
publication followed by temporary-name removal. Raw identity is recorded only
after publication, and all case/build raw hashes are rechecked before a campaign
can become `EXECUTED`. A later independently detected change remains an evidence
failure; no durability procedure can qualify bytes that subsequently differ.

Immediately before invoking its own generated binary, the driver verifies the
recorded bytes. If that unchanged, owned regular file has lost every executable
mode bit, it may restore only owner-execute and records an `artifact-mode-repair`.
An already executable file is never chmod-ed after an access denial, and there
is no alternate execution route or retry. Source mismatch, another owner,
symlinked output or a different artifact directory refuses repair.

`--allow-dirty-apparatus` permits explicitly unqualified diagnostic executions
for apparatus development. It never permits an uncommitted production source
change. A dirty run cannot pass the independent reader as qualified evidence.

## Manifest

```json
{
  "schema": "mat354.campaign.v1",
  "cases": [
    {
      "id": "isolated-q3-w1",
      "argv": ["--fixture", "isolated", "--quiet", "3", "--workers", "1"],
      "expected_workers": 1,
      "parity_group": "isolated-q3"
    }
  ]
}
```

The committed 552-case manifest is consumed without rewriting it. The older
`mat354.plan.v1` envelope remains accepted. `workers` is an alias for
`expected_workers`, and conflicting aliases fail. Missing parity-group names are
derived from all physical command-line flags except `--workers` and `--repeat`;
quiet thresholds, geometry, fixture and lifecycle variant remain distinct.

Case IDs are unique bounded filenames. The runner executes the exact argument
list without a shell. Additional descriptive registration fields are preserved.
Optional `compile_sources` and `compile_flags` are recorded as part of the
registration and actual compiled-input identity; default sources above are
appropriate for the supplied probe.

The probe emits one `type=metadata` JSON object, exactly `horizon` `type=tick`
objects indexed from 1, then one `type=summary` object. `case_id` must exactly
match the registered ID, including workers/repeat. Required metadata includes
`case_id`, `workers`, `horizon` and invoked fixture parameters. Every tick includes
`world_tick`, `reset_epoch`, `has_failed`, `quantity_ok`, `worker_threads_observed`, `phase_jobs`,
`visited_cells`, `scheduled_cores`, `active_blocks_after`, `physical_hash`, and
nullable `kernel_visits`. A null kernel-visit value means observation is
unavailable; it never means zero visits. The final summary repeats `case_id`,
`has_failed`, `quantity_ok` and the last `physical_hash`.

World ticks may stay fixed while the owner pauses. They may decrease only at
registered reset step17: `reset_epoch` must increase by exactly one,
`wake_cause` must be `reset`, `world_tick` must restart at1, and the registered
variant must be `reset`. Reset markers without epoch increments, skipped epochs
and unexpected resets fail.

The independent reader verifies full per-tick physical-hash sequences within
registered `parity_group` sets. A group with only one capacity is explicitly not
a one/four-worker comparison. Configured capacity and maximum actually observed
workers remain distinct. Summed kernel-visit observations are complete only when
every tick reports a nonnull value. The reader does not infer scheduler starvation
from a final state, invent a retry contract, or reimplement material movement.

`python3 tools/material_liveness/test_tools.py` runs adversarial reader/driver
checks using synthetic rows. These tests are apparatus checks, not native
physical evidence. If raw files are moved as a bundle, retain their filenames and
pass `--raw-root` to the reader. It verifies their original bytes and SHA-256.

## Focused hosted execution

`.github/workflows/material-liveness-phase-a.yml` runs two ordinary native jobs,
with literal `ubuntu-24.04` and `windows-2022` hosts and40-minute job bounds. PR
triggers cover only this probe, its manifest, its tools and this workflow. Manual
runs retain separate concurrency identities. Both check out the exact PR head
(or dispatch SHA), fetch compatibility history and run the same552-case manifest.
The workflow does not invoke production publication, Godot or the full Native
matrix, and it does not change the existing expensive-workflow draft gates.

Linux selects installed GCC13. Windows discovers installed Visual Studio with
`vswhere`, calls `VsDevCmd`, and selects an installed LLVM `clang++.exe`; missing
tools fail rather than downloading an unqualified compiler. Windows uses explicit
C++ exception flags and no POSIX thread flag. Its actual compiler/version, flags,
inputs and native executable hash are recorded by the same runner. Windows
checkout preserves LF bytes. Adding this workflow is not evidence that Windows
execution has passed; only completed, authenticated hosted outputs establish that.

Compiler dependency parsing handles Windows drive colons, path separators,
escaped spaces, hashes, dollar signs and line continuations. Missing/misparsed
files fail, relative dependencies resolve against the actual compiler working
directory, and the inventory must include `native/src/world.cpp`. Source-relative
inventory paths use forward slashes on both systems.

Both jobs run the independent reducer, preserve unsuccessful attempts, and pack
raw files using the authenticated transport codec when available. The always-run
artifact step retains raw/provenance/partial outputs and transport shards for90
days. Objects and executable bytes are excluded; the receipt retains their
executable identity. Local sanitizer attempts remain a separate evidence lane.
