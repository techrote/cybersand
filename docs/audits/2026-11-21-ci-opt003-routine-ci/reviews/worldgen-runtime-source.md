# Independent worldgen runtime review

**HOLD pending one P2 diagnostic-preservation repair.** The scientific inventory, dependency graph, two-job scheduling and failure admission checks pass independent review. No native/Godot/fixture source, published runtime or required workflow was changed by this increment. Hosted scientific and performance qualification remain pending.

## P2 — lost diagnostics from an interrupted peer

`tools/ci/run_native_family.sh:57–58` adds GNU Make `--output-sync=target`. The new per-showcase recipes in `Makefile:463–468` therefore send output into Make’s transient per-target buffer. When the production watchdog terminates Make and a hung showcase, that showcase’s already flushed stdout and stderr can disappear from the retained command log.

The independent reproduction runs the actual candidate Make graph with executable doubles and the actual `run_timed_command` owner. Megatruss exits29 after the seeded peer starts. The seeded peer flushes `CONTROL-BEGIN` to stdout and `CONTROL-ERR` to stderr, then hangs. After a one-second watchdog, the receipt correctly records timeout and both processes are reaped. The retained log contains the first failure but neither hung-peer marker. Removing only the output-sync option from the same graph preserves both markers. See `worldgen-runtime-timeout-output.json` and `worldgen-runtime-ungrouped-control.json`.

This does not create a false pass, but it violates the requested preservation of partial failure diagnostics. Retain per-case raw output independently of Make’s transient buffer, ensure those files survive timeout/cancellation and enter uploaded source-bound evidence, or adopt another diagnostic scheme with equivalent demonstrated retention. A fresh delta review is required before admission.

## Verified source and coverage

Independent actual baseline/candidate Make dry-runs preserve all28 compiler/link argv in both modes, all12 objects,16 binaries and all16 executions. Seven required independent showcase targets gate the same nine principal recipes in source order. Default showcase paths have no shared-file writes; exporters and benchmark paths require explicit arguments absent from CI. Generation source has no filesystem/output side effects in the inspected primitives.

Executed20 graph/inventory/watchdog controls (18.451s),22 Native watchdog controls (13.181s),45 Native reducer controls (3.078s). Independent additional controls passed reversed prerequisite scheduling in both modes, duplicate aggregate/shared-showcase targets (16 warm tests,0 compilations), and keep-going after failed prerequisite (nonzero exit, zero principal-tail executions). Executable doubles verify infrastructure only; they are not scientific or performance evidence.

The real SIGINT cancellation control qualifies that path only. Abrupt SIGTERM behavior is not claimed. Original acceptance receipts still refuse timeout, cancellation, missing/partial binaries and failed children.

## Documentation correction

A minor P3 wording issue at `docs/operations/ci-execution-and-performance.md:74` claimed exact original commands despite two added output-grouping options. Root corrected it during review. No open P3 remains.

Exact reviewed source hashes and structured dispositions are in `worldgen-runtime-source.json`. The reviewer made no candidate-source or remote changes.
