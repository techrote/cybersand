# Specialist C — first cold-command annex rejection

**REJECTED BEFORE GODOT EXECUTION.** This is a failure of the external observer's
source inventory, not a newly observed failure of the frozen application or its
shipped command. It does not qualify cold startup.

## Immutable original

- Observer: `3f37d27bb7637e6ef7107e968d6e27fb4128ce2e`.
- Application: `fd0830abcfadd9ae19162e5677943bb131223e59`.
- [Run 45741693665](https://github.com/techrote/cybersand/actions/runs/45741693665), job `139647997400`.
- Original failed artifact: `15081990856`, `242423` bytes.
- Artifact SHA-256: `00595d7c3830b17ba2d5eceb0a9539d960fbc9553f19d7a2095def295c8b5cfc`.
- Name: `strata3-cold-windows-fd0830ab-3f37d27bb7637e6ef7107e968d6e27fb4128ce2e-1`.

C independently retrieved the completed job metadata and decoded job log through
GitHub after the local environment became unavailable. The job actually passed
all **21 controls**, the provider policy, exact artifact authentication and the
original evaluator download. The download action reported the expected outer
artifact SHA-256 `cc6d27dbf377cb62ac397c2db0b3ba6f9b2f3b3b294a3bc89b7fbbc18767b1ee`.

At 02:21:35 UTC the ordinary-command step rejected with:

> Missing frozen verifier/process observer custody

The bound source raises this from `verifier_inputs` before its pristine static
verification and before `execute_launcher`. Thus this run never attempted the
cold Godot launch. No import duration, native admission, graphical presentation
or shutdown result can be extracted from it. The original artifact and this
negative result remain separate from any corrected observer.

## Concrete source diagnosis

`application_tools` constructs the frozen package module with
`module_from_spec` and `exec_module`, but does not register that module in
`sys.modules`. The inventory scans `sys.modules` and correctly requires the
exact `tools/package_strata3_workbench.py` input. That module is absent from the
inventory despite its successful dynamic loading. Specialist A independently
identified the same defect.

The narrow correction is standard module registration before executing the
module, with cleanup on an import exception, or explicit inclusion of that
actual verifier object in the inventory. The required source file must remain
mandatory. A meaningful regression must exercise the actual dynamic loading
and inventory together; passing the earlier controls did not exercise this seam.

## Artifact completeness issue also found

The retained-source copier places the original workflow under
`observer/.github/workflows/` in the output, and the strict evidence ledger
requires that file. The actual upload log states `include-hidden-files:false`.
That default excludes a hidden directory, so it can omit a required retained
workflow from the uploaded artifact even when the local reader passes.

C alerted the lead to enable hidden-file inclusion for this bounded evidence
output, or consistently relocate that one retained path. This is an artifact
custody correction, not a relaxation of source hashes. The failed upload's nine
files are consistent with this omission, but C has not independently extracted
that ZIP after the workspace outage and does not claim a byte-level inventory
of its contents.

## Remaining gate

The lead owns a source-pinned correction and a fresh hosted run using the same
original ZIP, immutable application, first-CMD boundary and 180-second limit.
The previous failure must not be overwritten or called a successful cold
command. A later result needs its own exact observer/run/artifact identities.
The principal evaluator retains its separate functional qualification and
enabled-optics PERFORMANCE HOLD.
