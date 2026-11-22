# Independent worldgen diagnostic-repair delta review

**GO for source and diagnostic repair. No open P1/P2/P3 finding remains.** Hosted scientific qualification and performance admission remain pending. The original negative review and reproduction are preserved without alteration.

## P2 WGEN-RUNTIME-P2-01 — resolved

The repaired recipes write each showcase's raw combined stdout/stderr directly to its own file before replay into Make's grouped output. I independently reran the exact original failure-plus-hung-peer scenario using the actual Make graph and production timed-command owner. After both timeout and SIGINT cancellation, the peer's flushed stdout and stderr remain byte-for-byte in its raw file. The command remains nonpassing, the nine principal tests do not run and no peer remains alive.

The expected raw file in both reproductions had SHA-256 `76cf2a11a0d9e20958f3145b8e20e5ef30ac70a888e4fdc13cbea3af3359b782`; it includes the current source/run/attempt/binary header and both original markers. `worldgen-runtime-delta-controls.json` retains the exact bytes and observations.

The Native artifact step includes the raw log directory under its existing `always()` condition. Its common artifact root remains `build`, matching the scientific-inventory reader. The recorder hashes partial files even when recording a failed family. Successful admission requires exactly fourteen expected normal/sanitized logs, explicit source/run/attempt context, correct binary names and nonempty raw payloads. Missing, stale, extra, symlinked or subsequently altered logs cannot qualify. The shell preserves the original test failure if replay also fails; replay failure alone cannot turn green.

## Independent verification

- 21 actual Make/inventory/watchdog controls passed in20.527s.
- 51 Native evidence/reducer controls passed in3.446s.
- 22 Native watchdog controls passed.
- Five independently exercised delta controls passed: original timeout, SIGINT cancellation, explicit reader context independent of current process environment, altered-payload hash refusal and symlink refusal.

Source inspection confirms compiler/link argv, all16 scientific executables per mode, sanitizer environment, the two-job Make cap and all original watchdogs remain unchanged by this repair. The new work is raw capture, artifact retention and stricter custody validation. The original seven-showcase union and nine ordered principal-tail review remains applicable.

The minor P3 command-description wording was corrected and remains resolved. Final file hashes and any available Git commit correlation are in `worldgen-runtime-delta-review.json`. The reviewer made no candidate-source or remote changes.

## Limits and integration requirements

These executable-double and synthetic-artifact controls qualify infrastructure. They do not establish actual scientific execution or a performance improvement. Actual hosted Native/Linux/Windows qualification and the controlled family comparison must use the final source. Paired proof execution must set `GITHUB_SHA` to each tested arm's source while preserving the independent proof-controller identity; the new verifier import and explicit context arguments must be supported by its offline consumer.

The tested cancellation path is SIGINT, plus the production watchdog timeout cleanup. This is not a blanket abrupt-SIGTERM guarantee. The repair preserves data already flushed to the file; it cannot recover bytes still held in a terminated test's userspace buffers.
