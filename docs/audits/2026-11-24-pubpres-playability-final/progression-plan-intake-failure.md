# First progression launch: missing shallow-checkout control

The first progression request used source
`fb08fe8fe260523fa37efc7c3faffb09e1f8254a`, tree
`69271d01bf0f6288ba8875235ff3865525978677`, in
[run45476755989](https://github.com/techrote/cybersand/actions/runs/45476755989).
Its request fingerprint and CI provider gate passed. The plan job138738885520
then failed before any native build, sanitizer, correctness or timing execution.
All downstream jobs were skipped; none receives qualification credit.

The count capability adversary deliberately inspects the actual committed c2
Main and confirms the old source lacks the new policy helper/API. The default
one-commit Actions checkout did not contain that c2 Git object, so `git ls-tree`
refused it. The full local repository contained c2, which explains why the
77-method local driver run passed. This is a missing test input, not an observed
runtime, material or physical-progression failure.

The corrected plan explicitly fetches
`c2f8a73d34448bc1496ecd84bca02f0812c80d27` with a bounded depth-one Git operation
before running the unchanged source-bound adversary. It retains the same
native/runtime/correctness/physical gates. A new complete source-tree request
will execute the correction; the original failed run remains failed.

The complete decoded original job log is retained separately, SHA-256
`942572b474ba54595d560fc6423b5206f7186967eb638e6162308e82c3e1dd91`.
The original request fingerprint was
`a5fe4df8db8054498af319644d8f75c9f18300a25d8dea9e49ba52b785e302be`.
No experiment is repeated by this correction because no experiment started.
The independently qualified retained-font packet remains a separate run and
does not change this outcome. All work remains Draft/HOLD.
