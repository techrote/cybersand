

## Windows cleanup repair candidate and separate startup assessment — 2026-11-03

**Candidate, not hosted qualification.** This continuation starts from frozen
#304 head `4f21f97c97c7dc344e026c85900d820006cdb308` and its tree
`10786b2fa4de0f8cc671d79cfc85e666bb8e5aeb`. The preceding original run
`41601226467` retains its exact-source disposition: Linux authoritative 001C
32/0, Windows 001C failure, combined workflow failure. Those results do not
qualify the repaired source. Keep #304 draft, optional and unmerged; do not
modify #334 or create a PLAY dependency. No new host run is claimed here.

### Minimal source correction

The Windows helper captures the TerminateProcess error immediately, before
GetProcessTimes, WaitForSingleObject or CloseHandle can overwrite it. A refused
request, including error 5, is retained with the creation identity. Cleanup
requests termination once per recorded identity and polls the retained handle
within the existing three-second allowance. Only a signaled process object
establishes retirement. A still-nonsignaling object at the deadline, failed wait,
unexpected wait result or observation error remains failure. No process-name
kill, PID reopen, unowned process claim or extended case deadline is added.

The runner retains cleanup termination errors in its process receipt and does
not start a second three-second cleanup attempt after the first attempt fails.
Its existing timed_out/timeout_kind/forced_cleanup fields and pass predicate
remain authoritative: successful failure cleanup cannot turn a timed-out or
forcibly cleaned run into a positive result.

Microsoft's primary API contracts distinguish asynchronous termination, the
already-exited error-5 case and actual signaled-handle observation:
[TerminateProcess](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-terminateprocess),
[WaitForSingleObject](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitforsingleobject),
[GetLastError](https://learn.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-getlasterror).
This repair does not retrospectively certify the old Windows cleanup receipt.

### Passive selected-palette provenance

The fixture copies provenance from the shader already selected by Main._ready,
before its existing process_frame yield, and carries it in the existing
worker_started row. It records actual driver, source resource path, source/file
hashes and binding, selected variant hash/name/binding, bounded-define count
and comparison with the accepted ANGLE hash
`7e5650cb807825e8febebd402dcba262d0df10baf02d478ee3c30f99ca3d460d`.
Missing shader state is recorded as unavailable, never invented. Native OpenGL
has no ANGLE-match verdict. No shader is selected, replaced, compiled or
prewarmed by the observer; no extra progress event or heartbeat is emitted.

The observation is before the fixture's first explicit yield after Main ready;
this alone is not a measured claim about the engine's first actual draw or GPU
presentation. Emission remains at the original worker_started stage. Shader
identity is diagnostic and does not replace the original held-native/pixel oracles.

### Controls and CI boundary

The candidate adds portable Win32-kernel controls plus native Windows retained-
handle controls and runner-finally receipt tests. The previous 14 custody cases
remain unchanged. Local Python and Python -O outcomes belong to the handover's
source-bound validation report, not to a hosted Windows or Godot qualification.
Actual Windows handle tests, full-checkout documentation/provider/actionlint
checks and GDScript execution must be reported separately; none is assumed.

The existing host workflow gains a controls-only Windows job. Pushes to the
#304 branch cannot start Linux/Windows build-and-render jobs; those jobs on
that branch require an explicit workflow_dispatch with full_host=true. Manual
dispatches on other refs also default to controls only; the legacy 001B pool
branch push behavior is retained. No
native/Godot runtime is downloaded by the controls job. It uses the pinned
checkout/setup/upload actions and preserves original control logs for 90 days.
This source change does not dispatch a workflow. Even a green controls job is
not graphical 001C acceptance or merge readiness.

### Separate cold/warm startup assessment — registered proposal, not executed

The prior #331 ledger records one whole-Main cohort at source
`c24e69ad6310a8c3153c1ab9b680f7c84eb84b20`, run `41324343126`: first cold-process
Main acknowledgement 89.320689 seconds, recreated Main 4.641143 seconds,
then first/second Main in a warm process 4.600219/4.663236 seconds. These are
whole-Main timings under that apparatus's existing 600-second allowance, not
compiler-only timings, a distribution, current-source 001C passes or proof of a
specific shader defect. The #304 process still failed after 45.027 seconds idle.

After targeted Windows cleanup controls pass, a separately reviewed measurement
may use three independent fresh Windows jobs, each with one first-process and
one subsequent-process pair; each process creates two ordinary Main lifetimes.
This gives 12 planned acknowledgements, not 12 claimed results. Freeze exact
source, engine/native/Rapier bytes, renderer and actual selected-shader hashes.
Use the already registered Main-startup apparatus and its existing allowance;
do not modify 001C's 30/45/120-second protocol. No attempt is retried to obtain
a pass. Retain failures, timeouts and incomplete lifetimes in the denominator.

Record runner image, CPU allocation, argv, process lineage, environment, project
cache inventory before/after and cache isolation method. A fresh runner or
process is not proof that every driver/OS cache is cold; unknown caches remain
unknown. Never mix deliberate cache deletion with the observational cohort.
Report individual timings and the observed range first; do not estimate p95
from three independent startup cohorts or choose a new deadline from them.

Only the separate measurement can support a later reviewed startup-policy
proposal. Until then, no deadline increase, shader-causality conclusion, cold
startup success, physical-display cadence or human-feel claim is made.
