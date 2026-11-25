# PUBPRES playability source qualification

These programme-scoped helpers build and qualify the Draft/HOLD candidate.
They do not replace production runtime provenance or the ordinary CI pipelines.

The separate [isolated render diagnostics](../pubpres_render_probes/README.md)
reuse the process owner and reviewed private-display helper without native or
godot-cpp inputs. They may run immediately after the exact engine download.
Their failed first-read pixels/startup crashes remain failed diagnostic arms;
their results never qualify the native build, package or gameplay campaign.

`build_runtime.py` uses each M/I/C source's own native build script and exact
native input closure. It requires the actual `LINUX_CXX` or `WINDOWS_CXX`, the
pinned `GODOT_CPP_ROOT`, and `PUBPRES_GODOT_CPP_BUILD_LOG` from the completed
dependency build. Its receipt binds generated headers and source, static library,
dependency command/log/builder/compiler wrapper, and every local driver module.
Local toolchain drift is disclosed and refused by comparison/package readers.

`process_owner.py` owns descendants at creation. Linux uses a scoped child
subreaper and `/proc` parent identities, including separately grouped orphans.
Windows assigns the suspended process to a kill-on-close Job before resuming
its initial thread. Ordinary exit with live descendants is a failed invocation.
Cancellation and uncertain cleanup are terminal; original logs and incomplete
process/index receipts remain available. These operations add no sampling to a
timed capture. Windows behavior requires execution of `test_helpers.py` on the
actual Windows host, in addition to Linux controls.

`run_comparisons.py` executes one registered paired stage on one host. All arm
and measurement bounds are unchanged; the parent allowance includes imports,
mailbox identity preflights, each admitted child allowance, and cleanup. Jobs
for different stages are separate and must not be treated as paired timing.

`run_regressions.py` archives exact committed project and recipe bytes, stages
the source-matched native/Rapier runtimes, rejects strict Godot errors and absent
completion evidence, and retains original logs, material receipts and profiles.
Its ordinary graphical run executes the existing combined-authoring fixture
through Save and a second process on the same profile, independently for
continuation OFF and ON with separate profiles. It also runs the one-shot permit,
real native/Rapier continuation and unchanged publication OFF/ON controls.
Actual before/after policy readback binds each authoring exercise; it proves
configuration rather than causality. `--headless-only` labels
the limited local variant. The packaged strict diagnostic contract is an exact
copy of the unchanged accepted checker, verified by a focused source comparison.

`run_installed_authoring.py` verifies a pristine Windows package, tests a mutable
copy with the packaged engine, and re-verifies the original payload afterward.
Both authoring processes use a 512-square native World and one native worker.
It requires actual framebuffer PNGs, all transaction phases and equality of the
complete saved/reconstructed native material digest. Hosted software rendering
does not establish physical NVIDIA acceptance.
`--same-frame off|on` selects this exercise explicitly and defaults to OFF.
Both settings retain blit/early/coherent/measured/repaired, Eager pools, Safe
rendering and zero rendezvous. The workflow runs OFF and ON independently, so
one failed gate cannot erase its sibling's original evidence.

The full source runner now schedules 27 outcomes: twenty-three 300-second
and four 600-second child bounds (155 minutes if every child reaches its bound).
Its Linux parent reserves 210 minutes for those bounds, owned display/process
cleanup, preparation and upload. The Windows package parent reserves 360 minutes:
155 for source correctness, 50 for installed OFF/ON imports and author/reopen,
77 for seven 300-second import plus 360-second startup pairs, and the remaining
allowance for package/ownership controls, setup, cleanup and upload. These are
enclosing failure-retention budgets; no native, physics, gameplay or individual
child work/capture allowance is increased.

The isolated workflow runs only for an explicit committed
`.github/pubpres-playability-run.json` request or manual dispatch. Development
requests select a small registered comparison set. A final request is reserved
for the frozen source and measurement policy. No Ready, merge, auto-merge or
production-default action is performed by these helpers.
The prospective v3 development subset schedules source comparisons, the new
same-frame OFF/ON/ON/OFF control and fresh observer calibration. The full frozen
request additionally covers the registered Water families and existing input
and native-probe diagnostics. V3 primary timing is Safe-only; the original
Separate engine/history negatives remain in strict correctness and isolated
diagnostic evidence, rather than being reused as valid timing arms.

After development-01, independent Windows package gates continue after another
gate fails, provided the exact package was built successfully. This retains
startup, source correctness and installed author/reopen evidence without turning
any failed step into success. Installed startup/reopening uses Safe rendering;
Separate/ANGLE crashed before application startup in development-01 and remains
an unqualified diagnostic, investigated separately with retained crash controls.
Safe startup does not qualify Separate or establish material-history parity.

A `probes` request is a deliberately smaller source-frozen diagnostic phase:
process ownership prerequisites and isolated engine/font/material probes only.
It skips native builds, source comparisons, packaging and native correctness.
Its artifacts cannot qualify the complete application or an owner evaluator.
The Linux probe parent reserves 45 minutes for all eight 180-second outer
allowances, their bounded cleanup, pinned engine preparation and artifact upload.
Each actual Godot diagnostic still has the same 60-second limit. This parent
allowance changes no gameplay capture, native work or performance comparison.
