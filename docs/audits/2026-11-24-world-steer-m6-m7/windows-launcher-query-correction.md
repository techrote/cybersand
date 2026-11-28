# Windows pristine-launch query correction — 25 November 2026

This is a source-specific qualification-tool correction. It changes no
Workbench application, launcher CMD, geometry, native input, physics or material
behavior. Original outcomes remain immutable.

## Retained second campaign

[Run 45512988153](https://github.com/techrote/cybersand/actions/runs/45512988153)
executed application `d948deab5d280adfe1e890bddf85725b2efd59bc`, tree
`1d8fec406a53a21e3321d1619e56da01520e5501`.
Linux passed 89/89 process groups and source Windows passed 89/89. The Windows
job then failed the new pristine delivered-CMD launch witness before any
successful extracted-application process groups. The owner ZIP publication step
was skipped. These source application passes do not qualify that failed package.

The retained fresh-profile Godot log contains `SHARED_WORKBENCH_LAUNCH_READY`
and no script/parse failure. This establishes route startup, without proving
the required correlated visible window and completed launcher exit. GitHub job
cleanup later found a running GUI process. The original verifier retained no
per-poll predicate samples; its empty observed inventory does not establish that
no GUI process existed or that cleanup found every launched child.

## Concrete defect and bounded correction

The verifier calls Windows `powershell.exe`. In Windows PowerShell 5.1,
`ConvertFrom-Json` emits a JSON array as one pipeline object. Wrapping that
pipeline in `@(...)` nests the two executable paths, so string membership cannot
match either executable. The PowerShell project's
[original issue 3424](https://github.com/PowerShell/PowerShell/issues/3424)
documents this behavior. This is a concrete defect consistent with the empty
inventory and observed startup marker; the historical report cannot reconstruct
every missing predicate after the fact.

The correction explicitly enumerates validated scalar executable strings. A
real Windows self-query must locate the exact current Python process using a
two-path filter through the same PowerShell/CIM query. The existing Windows
custody step runs this preflight before the expensive source application groups.
The delivered-CMD check also retains bounded poll predicates and process/window
samples for diagnosis.

Exact direct-parent and executable checks, creation-identity cleanup, visible
window, Workbench route marker, successful CMD exit, the 150-second deadline and
strict pristine/post-import payload verification remain required. A marker,
unrelated engine process or timeout alone never becomes a pass. No timeout was
increased and no renderer or application change was made to accommodate the
measurement failure.

## Why the existing campaign is used again

The established Batch workflow requires a same-run source-matched native
producer/consumer. It has no extracted-only dispatch or qualified generic reuse
path, and the failed inner ZIP was not published. A new reuse system would add
unnecessary release risk at this checkpoint. The narrow successor therefore
uses the existing four jobs and all existing application/package gates, with a
new request identity and explicit correction. Native inputs are unchanged.

Until actual successor Windows execution is observed, the correction is a
reviewed candidate, not a Windows pass. Final source, runtime, artifact and
result identities belong in the canonical decision packet. Physical owner
acceptance remains separate from hosted graphical qualification.
