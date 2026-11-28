# Portable re-reading of the frozen predecessor comparison

**Specialist B · 26 November 2026 · external evidence reader only.** The frozen application and its packaged qualification tools remain unchanged. This annex records a host-path parsing defect in the retained predecessor reader and a narrowly bounded adapter. It does not rerun the application or replace any original observation.

## Original result and cross-host limitation

The final Windows job in [run 45721790366](https://github.com/techrote/cybersand/actions/runs/45721790366) completed all six predecessor/candidate observations and verified them on Windows. The exact retained comparison is SHA-256 `9b4288609b7dfb0e9cdade7d0410e29ab782b75cc0f595f27080bbb7afb96b65`. Re-reading those same bytes with the frozen reader on Linux rejected them with `Observation did not execute the external graphical driver`.

The retained command contains a Windows path. The frozen condition uses the reader host's `Path(command[-1]).name`; on Linux, backslashes remain ordinary filename characters. This is a cross-host reader limitation, not an observed failure to execute the driver on Windows. The original Linux rejection is preserved in the new receipt.

| Input | Exact identity |
| --- | --- |
| Frozen application | `fd0830abcfadd9ae19162e5677943bb131223e59` |
| Frozen tree | `fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499` |
| Frozen reader SHA-256 | `f01dbdd2f616f5bfb45e4295dd5a4f2a0001a2bc29c5035c2d1bf6c5f2e99568` |
| Windows controls artifact | `15078378766`, ZIP SHA-256 `5cf98513696d691071ad388fb698e015ad8fba78bf985ea5341c2da969155928` |
| Linux controls artifact | `15074613066`, ZIP SHA-256 `c9d511b193783e13b99d875387e5b5cfd0158a26c33316f4566aa163ea66c0ce` |

## Exact correction and preserved gates

`tools/ci/strata3_predecessor_portable_verify.py` requires a clean checkout of the exact frozen application and tree, verifies the frozen reader bytes against its Git blob, and imports its existing dependencies from that checkout. It extracts the frozen `verify` function and reversibly replaces exactly one expression: `Path(command[-1]).name` becomes a basename interpreted using the retained platform. Windows uses `PureWindowsPath`; Linux uses `PurePosixPath`. The comparison remains exact and case-sensitive. Unknown platforms, empty paths and NUL characters are refused.

The adapter neither broadens the comparison to a suffix search nor edits the frozen file. All other source, archive, runtime, observer, file-ledger, command, native state, image, resource, ordering and summary checks execute unchanged. The retained candidate identity must additionally equal the exact frozen checkout's source identity. The original reader outcome is included separately. When the original reader already passes, the two summaries must be identical. The comparison bytes are checked again after verification.

Specialist A independently inspected the one-expression substitution and confirmed that the predecessor, metrics, custody and Windows runtime helper modules load from the clean frozen checkout and match its Git blobs. A also repeated the actual Windows positive invocation and all eight focused controls successfully. No production shader, profile, scene, native library or evaluator byte is changed by this annex.

## Qualification and limits

All eight focused controls passed: exact Windows drive/forward-slash/UNC basenames; refusal of wrong suffix, prefix, case and filename; Linux path semantics; invalid/unknown dialect refusal; exactly one reversible substitution; the actual Windows positive corpus; a rehashed wrong-driver command refusal; and a wrong candidate-source refusal. The wrong-driver control updates the duplicate command witness and file hash in an isolated evidence copy, then still fails at the original frozen driver gate. Its expected exception is the original `RuntimeError`; the adapter's own source gate raises `ValueError`.

The adapter also admitted the retained Linux corpus. Its original reader already passed, and the original and portable summaries were exactly equal. These are retained-evidence checks, not new runtime executions.

The Windows paired comparison preserves the registered Classic result: median native progression is approximately 2.9055 ticks/s for Strata 002 and 2.9379 ticks/s for the frozen Strata 003 Classic path; median physical p95 is 335,406 and 329,010 microseconds respectively. The registered native, Rapier and p95 criteria pass on this hosted software-rendered fixture. All six scene admissions remain above the unchanged 45-second target: predecessor 50,911 / 57,214 / 49,280 ms; candidate 48,930 / 53,168 / 51,531 ms. This result does not qualify enabled optical profiles, other scene costs or physical Windows 11/NVIDIA performance.

The complete adapter receipts are retained as `b-portable-predecessor-windows.json` and `b-portable-predecessor-linux.json`; the focused test record is `b-portable-predecessor-tests.json`. Their reader identities include both function hashes and the exact reversible expression. The original application remains on its existing performance HOLD and owner acceptance gates.

## Reproduction

Run the external adapter against an unmodified checkout at the frozen commit and the original extracted controls directory:

```sh
python3 tools/ci/strata3_predecessor_portable_verify.py \
  --source-repo /path/to/clean-frozen-fd-checkout \
  --verify /path/to/strata3-predecessor-windows \
  --output /path/to/new-verification-receipt.json

python3 tools/ci/test_strata3_predecessor_portable_verify.py \
  --source-repo /path/to/clean-frozen-fd-checkout \
  --campaign /path/to/strata3-predecessor-windows -v
```

The output path must be new. Run this adapter from its external archive checkout; copying it into the frozen application's `tools` directory would deliberately violate its unchanged-dependency requirement.
