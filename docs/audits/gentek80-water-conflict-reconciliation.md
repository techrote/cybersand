# GENTEK-80 / Water main conflict reconciliation — WORK IN PROGRESS

This source-only two-parent integration candidate combines frozen GENTEK-80 PR #684
(87148d66e816f3fd4033e8227a7d310652e2812a) with the accepted main Water-era
source (de58bf1997ca75825cf3b29e046dc1c1022c45bf), rather than using
an unsafe ours/theirs conflict resolution on its four native artifacts.

## Hold gate — runtime publication is not yet qualified

- Native architectural implementation and accepted Water changes are preserved
  in source. The four overlapping native binary/provenance files retain their
  **main** versions as interim historical bytes, NOT a source-matched executable
  for this merged candidate.
- The binary must be rebuilt from this *exact combined source*, with matched
  provenance. Linux and Windows GDExtensions and any packaged Windows ZIP must
  be published only after source-matched qualification.
- Never deploy, merge, promote Ready, or claim Gentek UI runtime acceptance from
  these provisional native artifacts.
- The accepted main docs and Gentek docs were merged additively using their
  common ancestor. The four resulting docs preserve both sets of information.
- Exact current-main identity must be checked again before the final merge,
  because other Wave work is progressing.

The implementation donor #684 is preserved unchanged. This reconciliation
branch is an isolated Draft/HOLD candidate to verify safe conflict resolution.
Old #671 is superseded; do not separately merge its original CLASSIC/showcase
ancestry into main and lose the reviewed repairs.
