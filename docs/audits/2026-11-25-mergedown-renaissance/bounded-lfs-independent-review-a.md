# Independent review: bounded LFS acquisition

## Disposition

Specialist A independently approves source `886a149b7f38f9d04bc74da8b2fedb566ce89c62` (tree `c905324fd96214e88a1a7d3327b4cd7cdff693db`, parent `0c1152c21427125066df931cf06a53b7dda0075d`) **for resulting-source qualification**. This receipt does not claim hosted campaign completion, live Git LFS recovery, or actual Windows execution.

## Source review

The helper retries only exit status 2 with the observed Git LFS batch service-timeout message. Authentication, authorization, quota, integrity, unknown, and permanent failures remain fail-fast. Mixed error output containing a permanent failure is refused. Three attempts and 2/4-second backoff share one original monotonic allowance, including pointer discovery, Git preparation, materialization, verification, and cleanup reserve. Existing Windows 600-second and dependency 1200-second allowances remain unchanged.

The exact expected source must match HEAD before and after acquisition. Expected object SHA-256 and size come from the committed canonical LFS pointers, paths are literal and bounded, and materialized file bytes must match before success. Each actual process attempt retains stdout/stderr, exit status, duration, and timeout/retirement evidence. Process cleanup uses the established owned-process helper. The new helper is included in Windows input custody and the Palette apparatus scope. No native input, runtime pointer, application code, mandatory test, or test watchdog changes.

## Independent execution

All 145 Python tests passed on Linux: 14 acquisition controls, 35 Palette contracts, 14 Palette custody tests, 22 Windows-runner unit controls, 47 Windows reducer tests, and 13 Linux reducer tests. These are host-executed Python tests; their names do not imply an actual Windows runner qualification. The acquisition controls executed an actual fake Git process that failed once then produced checksum-matched bytes, and a hung parent plus owned descendant that was retired. They also cover permanent failures, attempt exhaustion, deadlines, changed source, wrong bytes, and evidence overwrite refusal. All seven reviewed tracked files matched the exact pinned commit before execution and were unchanged afterward.

The machine receipt links the original commands, per-case durations, exact log hashes, and before/after source hashes. The evidence ZIP preserves the complete six outputs and custody receipts.

## Original failure and remaining gate

Palette run `45715343561`, attempt 1, job `139560080793` failed before Godot because the Git LFS service returned its explicit batch timeout; the original decoded job log hash is `657ecfe77d26be828c35180d124f2c25655c239b3bfdfb2129ac7091b493bd31`. The command returned status 2. Retry classification was checked against that command's output, rather than unrelated checkout/setup text elsewhere in the entire job log. The original failed attempt remains failed.

A full resulting-source campaign remains required. Success of bounded retry controls cannot establish availability of an external service or qualify an incomplete campaign. The change makes a small number of transient retries possible within the unchanged budget; repeated service exhaustion remains a real qualification blocker.
