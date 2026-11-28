# PUBPRES delivery recovery: review before hosted execution

This is a partial engineering review dated 28 November 2026, not application or
package acceptance. PR #767 remains Draft/HOLD. The inspected application is
`65f71aaf4be3a67896bafac7f5220a0cb25a8fb7`, tree
`f6b7b8d3d613b70cdcdf3643fb906934b3887173`; live accepted main remains
`50e3bcb839211eac2abe1e065750cbcba4d36f8c`. Recovery edits are uncommitted in
`C:\pubpres-delivery-recovery-65f`, branch
`codex/pubpres-delivery-recovery-001`. Original dirty workspace is untouched.

## Findings and disposition

- The compiler process observer records every matching executable on the host.
  It does not establish ancestry from the invocation it measures. Its presence
  checks therefore cannot yet prove which compiler/linker processes performed
  the probe. Invocation correlation is required before granting that credit.
- The per-executable firewall blocks cover packaged Python, Git and compiler
  tools, plus the minimal linked executable. They do not cover the generated
  reference/candidate World executables. Full offline compile-and-execute
  qualification remains unestablished; the current response field claims only
  the narrower packaged-Python block.
- Corrected during review: minimal probe directories now use ASCII, so nominal
  ASCII installation controls no longer introduce Unicode themselves. The Lab
  timeout metadata now matches the actual 420-second process bound.
- Earlier review corrections retained: actual shipped Python and staged source
  CLI execution, real World receipt validation, production TEMP/TMP inheritance,
  firewall creation error handling/readback, and final summary state lookup.
- The historical four-path spawn rerun projection is excluded from the
  principal driver: new recovery changes make that isolated admission unusable,
  and widening it would invalidate its scope guarantee. Durable reader custody,
  explicit comparison driver identity and LF pointer fixes are retained.
  A direct comparison regression checks distinct application and driver
  identities; the ordinary CLI still requires candidate and driver to match.

## Local checks

Windows local Python 3.13; commands below ran from the isolated worktree. No GCC
toolchain is installed here, so no compile/link or Materials Lab execution is
claimed. No hosted workflow was started during this review.

| Command | Outcome |
| --- | --- |
| `python -B -m unittest discover -s tools/pubpres_mainline -p 'test_*.py'` | 42 tests passed after narrowed integration, 3.469 seconds |
| Python AST parse and witness `--help` | Passed; syntax/CLI only |
| `python -B tools/ci/check_ci_provider_policy.py` | Passed |
| `python -B tools/ci/check_m11_consistency.py` | Passed historical integrity: 18 records, 28 hashes; no current runtime acceptance |
| `python -B tools/ci/check_repository.py` | Failed: six missing retrieval expected-fact references (Q01, Q04, Q28 twice, Q29, Q30) |
| `python -B tools/docs/retrieval_eval.py --output <external temporary JSON>` | Completed: 19/33 canonical rank-1 hits, 31/33 top-k, MRR 0.7222; not answer sufficiency |
| `git diff --check` | Passed before adding this report |

The earlier package-helper check completed 17 tests with two skipped. These
checks neither reproduce the original linker failure nor qualify a corrected
evaluator. Original failed archive and campaign evidence remain intact. Runtime
ownership, presentation defects, matched performance cohorts and complete new
extracted execution are still outstanding mission work.
