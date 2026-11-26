# Independent recovery admission: accepted-main Windows adapter

Specialist C, 26 November 2026. **APPROVE a fresh source-pinned Windows campaign.**
This is source/harness admission, not a Windows execution or delivered-package pass.

Reviewed recovery commit `ac9eae778aa4a129b56e36f5039cf8f426a89c59`, tree
`d3dc51c39971458eaf20c16af561e424b6f7ba5b`, first parent
`a3cddc4703ecea7abdfe2db55d1de5ef79874447`. The exact product stays accepted
`67c1413a2a84077b47fa542cf91d2bd6ba5520ee`, tree
`984c94a6e312261120dffb4ad3625a6030d2f359`. The earlier registered local
`2709e8cb6f83cd4d9bf7af5feb91ae0965c2c133` was not recovered; this is an explicitly
new correction of the persisted adapter, with no claim of tree equivalence.

## Independent checks

- `python3 tools/ci/test_mainline_evaluator.py`: all 25 controls pass. This retains
  all original 23 custody/refusal cases and adds the real assembly helper join
  and actual delivered PowerShell options contract.
- `python3 tools/ci/check_ci_provider_policy.py`: pass.
- Five additional independently executed refusal cases pass: leading argument
  whitespace; a Vulkan-only renderer line; absent completion; an indented fake
  completion marker; and a cached module whose file belongs to another checkout.
- `git diff --check a3cddc47 ac9eae778`: pass. The worktree remained clean.

The first reviewer command used module-mode unittest discovery without the
required `tools/ci` import path and failed before importing the test module.
The normal documented direct-file command above then executed all 25 cases.
That reviewer invocation error is not a product or CI failure.

## Source findings

The actual accepted product's `run_windows_godot_regressions.verify_retained_runtime`
exists and returns every field consumed by assembly: native source inputs,
native/runtime source identities, binary size/hash records and Rapier identity.
It checks the complete current native input set, source hashes, committed LFS
pointer identities and materialized PE bytes. Loading it directly fixes the
observed nonexistent `qualify_ambient.windows` lookup. The existing source-owned
module guard rejects a cached helper imported from another checkout. The staging
and AMBIENT helper imports now use that same guard.

The unchanged PowerShell proof actually invokes `Open Workbench.cmd` with
`--audio-driver Dummy --quit-after 180`. The finalizer now requires that exact
string. It continues to require actual ANGLE initialization and exactly one
native-ready marker. The PowerShell producer additionally retains its strict
engine/script-error, clean exit, process watchdog, output-drain and scoped
cleanup checks. The finalizer still checks original stdout/stderr hashes and
source/package identities; the added helper does not replace these controls.

Both extraction and final ZIP readback retain original-member-name checking,
including normalized backslash and NUL aliases. No package payload, source,
native dependency, workflow, timeout, ordinary default or acceptance condition
was weakened. The complete registered budget remains 20,420 seconds under the
360-minute parent allowance.

## Remaining actual gate

Run the exact published recovery harness against the frozen product, inspect
all actual Windows admission, default-OFF, five-example graphical, delivered
CMD, Goblin/native-authoring/persistence/reopen, cleanup and immutable payload
receipts, then independently download and hash the final archive. Original
failed runs remain failures. No final evaluator is qualified by this review.
