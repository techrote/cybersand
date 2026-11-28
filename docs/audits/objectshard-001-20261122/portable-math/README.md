# Portable-math native performance delta

Source commit: `8f55a4e61b7cbb34a594f5e07e7d81d49aa58945`.

Read the [delta report](../../2026-11-22-objectshard-portable-math-performance-delta.md)
before interpreting these files. The full matrix's functional assertion count
is successful, but its performance status is **`budget_failed`** with ten
registered-limit failures. The subsequent bounded matched control is additional
evidence and does not change that status.

- `native-result.json`, `native-summary.json`, `native-inputs.json`: exact
  repaired-source matrix observations and failed budget evaluation.
- `commit-binding.json`: all 92 source bytes matched to the repaired Git commit.
- `matched-control.json`: one old/new control cohort with commands, exact binary
  identities, CPU/wall durations and available pressure observations.
- `control-*.json`: every raw result from that cohort, without removed outliers.
- `manifest.json`: source identity, classification and hashes of these files.

No native implementation, harness, workload, threshold or qualifier was changed
while collecting the control. The previous source report and architectural
full-tree experiment remain byte-for-byte unchanged in the parent directory.
