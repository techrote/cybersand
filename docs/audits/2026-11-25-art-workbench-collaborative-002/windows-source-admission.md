# Windows source-admission failure and explicit import EOL correction

## Retained intermediate campaign

Candidate `2743f89a0df6f6afcf7484e859c10790d521e74b`, tree
`56687bcaa8eb58fbdf1bbeb673d74a40dcc9b634`, ran a fresh, non-reused
application campaign [45534980763](https://github.com/techrote/cybersand/actions/runs/45534980763).
Linux passed the 23 retained core cases and all seven new cases in both headless
and displayed modes. Windows passed the retained core and displayed lifecycle
groups, then refused both new suites **before test admission** because the
working tree was reported dirty. No new Windows suite or owner package passed.

The complete original Windows job log is job `138939433113`. Negative evidence
is [artifact 14988050882](https://github.com/techrote/cybersand/actions/runs/45534980763/artifacts/14988050882):
530 members, 4,260,713 ZIP bytes, SHA-256
`038fed40c87a04ec3d26669b47612af8cc9bfe5ffd166729256fa8fe285fb42c`.
Specialist A independently verified the downloaded ZIP hash and CRC.

## Observed discrepancy and its limit

The rejected guard uses `git status --porcelain=v1 --untracked-files=no`.
The preceding 12 retained provenance records use `git diff --name-only` and all
recorded an empty changed-path list and empty scoped-diff hash. The failure
message did not retain its porcelain rows, so the exact rejected paths cannot
be recovered from that campaign.

Repeated original Windows warnings name four tracked Rapier import descriptors:
`Radial2D.svg.import`, `icons/Fluid2D.svg.import`,
`icons/StateManager2D.svg.import` and `logo_square_2d.png.import`.
Warnings alone do not establish modified source content.

Specialist A independently reproduced the discrepancy in a disposable Git
repository using the exact committed Radial2D descriptor: with
`core.autocrlf=true`, a fresh checkout contains 44 CRLF newlines. Rewriting those
as Godot's 44 LF newlines makes porcelain report a modification while
`git diff --name-only` remains empty. An explicit
`*.import text eol=lf` attribute keeps both checkout and the same rewrite clean.
This is a supported explanation of the hosted refusal, not a claim that the
missing original porcelain was observed.

## Correction and fresh gate

The source now declares LF for tracked `.import` descriptors. No dirty-source
exception, automatic file restoration, ignored application input, or reused
qualification was added. The gate still requires a clean committed source.

Future refusals retain exact porcelain rows, staged and unstaged path lists,
hashes of both diffs, and committed/worktree SHA-256, byte and newline counts
for the bounded tracked import-descriptor inventory. Changed source bodies are
not copied into diagnostics. An isolated Git test checks failure diagnostics;
a second uses the real tracked descriptor and source attributes to check the
Windows EOL checkout/rewrite sequence.

The independent reproduction script, complete result and original artifact review
are source-pinned at [provider evidence 4cf4fdfa](https://github.com/techrote/cybersand/blob/4cf4fdfa130e45a88bc4cafc57543316fb0ebfe6/docs/audits/2026-11-25-art-workbench-collaborative-002/provider-independent-evidence/windows-source-admission-review.md).

The next complete campaign must qualify its own source, including this
correction, the finite direct-run admission guard and integrated Context layout.
The intermediate failure remains part of the mission record.
