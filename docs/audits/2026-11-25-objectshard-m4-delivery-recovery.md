---
title: ObjectShard M4 package replay and acquisition recovery
status: Historical
document-kind: audit
scope: Original failed campaign evidence, exact provenance mismatch, focused repair and qualification still required at this checkpoint
last-reviewed: 2026-11-25
related-documents: [2026-11-24-objectshard-m4-source-recovery.md, ../research/objectshard-m4-workbench.md, ../operations/objectshard-workbench-playtest.md]
---

# ObjectShard M4 package replay and acquisition recovery

This checkpoint repairs two concrete failures in the ordinary Workbench
completion campaign. It does **not** relabel the previous campaign, establish
new Windows/Linux application passes, or close physical owner acceptance.
The [machine-readable recovery ledger](objectshard-m4-recovery-20261125/delivery-recovery.json)
contains original archive/report/log digests, all case identities, runtime
identities, changed execution-input hashes and the required next qualification.

## Independently recovered predecessor evidence

The original [run 45473059187](https://github.com/techrote/cybersand/actions/runs/45473059187)
executed source `f5b7ac7e651356c9f6d5657dfb0cb9d60111be81`, tree
`fcbb55a7c80a9d1a887e4e0336491e07c3ae01db`. The
[Windows evidence artifact 14961723648](https://github.com/techrote/cybersand/actions/runs/45473059187/artifacts/14961723648)
was downloaded independently: **33,235,453 bytes**, SHA-256
`3f35d18a7e54ce8327d0b6f63dc57cf3e035380e7b87714c612dd0370f3650d7`.
Every one of the 65 individual process-log hashes in its two qualification
reports matches the corresponding original ZIP member.

| Original Windows evidence | Independently observed result |
| --- | --- |
| Ordinary headless Workbench | 38/38 cases passed, including the ordinary Water/actor/equipment regressions and retained Lab budget |
| Report requested with graphical profiles | 27/27 cases passed; 14 actually require a display, while 13 focused/import cases remain headless |
| Shipped CMD in four extracted roots | Four passed: spaces, parentheses, Unicode and nested directories; 73 launcher checks each |
| Tower display identity | Zero incoherent observations in each shipped-launcher witness |
| Pristine-package application replay | **FAIL**, zero cases; required original-name retained provenance path was absent |
| Aggregate Windows Workbench job | **FAIL**, unchanged historical disposition |

The hosted graphical adapter was **Microsoft Basic Render Driver through ANGLE
D3D11**. These are renderer-submission and source-identity observations, not
physical NVIDIA presentation or playfeel acceptance.

The separate [native DLL artifact 14959065759](https://github.com/techrote/cybersand/actions/runs/45473059187/artifacts/14959065759)
was also independently downloaded: 2,265,509 bytes, archive SHA-256
`467f34bcb7b2c3cfcfbf90d8e4e274c44a5b9817357fc3079e5503f65a104a70`.
Its actual 6,196,224-byte DLL has SHA-256
`9c939287f21b8d5b580b50464271a16b6aa235b6e71183eb434d607cfd966b4a`.
The existing `native_candidate_identity.py` independently accepted its complete
candidate ledger, 117 native inputs, exact source/tree and actual DLL bytes
against the recovery checkout. Both Windows Workbench reports name that DLL.

The original evaluator ZIP was created and exercised, but its upload step
followed the failing package replay and never ran. Its recorded digest
`d27d13ab58bd96680d9f84908e0e1cd2994663d1f39906c63fdd550c08f736b3`
is a **reported identity only**: the playable ZIP is absent from the evidence
artifact and cannot be independently recovered from that artifact. Do not offer
the evidence ZIP as the owner evaluator.

The [earlier platform recovery ledger](objectshard-m4-recovery-20261125/earlier-platform-recovery.json)
also preserves independently downloaded original reports from runs
[45435990124](https://github.com/techrote/cybersand/actions/runs/45435990124) and
[45457037610](https://github.com/techrote/cybersand/actions/runs/45457037610).
Four original platform archives match their recorded size and SHA-256, and all
127 report process-log hashes match the original ZIP members:

| Earlier source and platform | Original result and retained scope |
| --- | --- |
| `f4a2176f` Linux | **FAIL**, 23/32 cases passed. Failed explicit coordinator retirement; profile camera/publication refresh; Viaduct/Mixed `DestinationUnavailable` holds and Water raster-census assertions; Tower light awake-body observation. |
| `f4a2176f` Windows | **FAIL**, zero cases. `WinError 206` stopped qualification before application execution because the source check constructed an oversized Windows command line. |
| `0f013ba4` Linux headless | **PASS**, 35/35 cases. |
| `0f013ba4` Linux report requested with graphical profiles | **FAIL**, 24/25 cases. The failing `workbench_completion` case itself ran headless and remained in `AwaitingCompletedNativeTick` before facade detachment; do not attribute it to a renderer. |
| `0f013ba4` Windows | **FAIL**, 34/35 cases. The lifecycle-adversity test failed its exact stale-publication refusal assertion. |

The `0f013ba4` native-input map matches `f5b7ac7e`, but thirteen script/tool
inputs differ. The older `f4a2176f` map differs in four native paths and twenty-nine
script/tool paths. Matching named cases later passed on `f5b7ac7e` Windows;
that successor evidence does not turn the earlier failures into passes and
does not qualify `f5b7ac7e` Linux, whose acquisition failure prevented execution.
Native sanitizer and allocation-budget history is owned by the separate
independent native review.

## Exact package failure and corrective contract

`package_windows_workbench.py` deliberately preserves the committed production
`godot/addons/cybersand_native/runtime-provenance.json` as
`retained-runtime-provenance.reference.json`. The executable candidate has its
separate `source-built-candidate-provenance.json`. This prevents historical
production provenance from appearing to attest a newly built candidate DLL.

`qualify_workbench.py` nevertheless demanded every committed Godot JSON at its
original filename. Its blanket source-byte loop therefore failed before engine
execution, including under the correctly resolved `Workbench (1)` extraction.
This was a verifier assumption mismatch, not an absent source-built candidate
ledger and not a parentheses/path-resolution failure.

The repair maps precisely this one committed path to its preserved reference
name and compares its **exact original digest**. Missing, changed, stale or
unrelated reference bytes remain failures. All other committed Godot inputs
retain their original path and exact-byte requirement. The package inventory
now explicitly requires the retained reference; an active production provenance
filename inside the evaluator is refused. No dummy or substitute ledger is
created.

Python and the shipped PowerShell verifier require the full candidate ledger
schema, kind, native path, source/tree/build identity, native-input map, size and
digest. A small MZ header sanity check supplements these identities; it is not
a complete PE parser or a new binary qualification claim. Package replay also
requires the manifest-bound console engine physically inside the selected
extraction, refusing an external engine even when its bytes happen to match.

## Linux acquisition repair

The original [Linux job 138725897840](https://github.com/techrote/cybersand/actions/runs/45473059187/job/138725897840)
built and sealed its native runtime, then received HTTP 403/curl exit 22 from
the official downloads frontend before Workbench execution. It demonstrates
an acquisition failure, not an ObjectShard application failure.

The scoped completion workflow now requests the same official Godot 4.7 Linux
release archive directly from the existing `godotengine/godot-builds` release
route, already used elsewhere in this repository. The locked 75,664,355-byte
size, SHA-256
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`
and exact version `4.7.stable.official.5b4e0cb0f` remain mandatory. The shared
dependency-preparation allowance bounds acquisition; retries are finite,
ZIP integrity is checked before extraction, and version readback precedes use.
No provider, runner, version pin or material policy changes; no unqualified
generic helper from PR #771 is imported.

## Focused verification and impact

Local command `python3 -m unittest discover -s tools/objectshard -p 'test_*.py' -v`
passed **76 tests**, including 12 new delivery/provenance cases. These reproduce
the old missing-path assumption and exercise exact relocated bytes, missing
and stale provenance, alternative roots, Unicode, symlink refusal, source drift,
wrong candidate identities and an external engine. A scoped qualifier fixture
reaches case execution after the corrected preflight, then intentionally stops
before executing its synthetic engine. Synthetic fixtures are never reported as
application qualification. CI provider policy and `git diff --check` passed.

The Windows ZIP campaign adds eight actual shipped-verifier negative cases:
missing candidate, tampered candidate, wrong candidate kind, stale source,
stale build, wrong native digest, missing retained reference and an active
production ledger. Candidate-field mutations also update the outer payload
digest, forcing the inner provenance checks to reject them. Disposable
extraction bytes are restored even after a failure; the archive is immutable.

No native C++, Godot gameplay law, worker barrier, registered workload or
production runtime changes in this repair. Historical native input equivalence
can support an explicitly documented reuse relationship, but changed qualifier,
verifier and workflow inputs require new delivery and application execution.
The original failure remains recorded.

## Replacement Linux evidence checkpoints

The [replacement Linux campaign ledger](objectshard-m4-recovery-20261125/replacement-linux-campaigns.json)
preserves the two terminal replacement failures. Their original archives were
independently downloaded again after the local executor restarted; original
GitHub archive digests, exact Git inputs, registered inventories and original
process-log hashes were reverified. Acquisition of the pinned Linux engine
succeeded in both hosted jobs.

| Source and campaign | Exact retained outcome |
| --- | --- |
| `51903088118d2a04f2dc79dd6fff7c25b226970c`, run [45517975210](https://github.com/techrote/cybersand/actions/runs/45517975210) | Headless 42/42 passed. Graphical 30/31 passed; the disabled paused control observed two delayed ordinary native ticks and zero Rapier steps after measuring from a generic paused snapshot. The exact worker Pause acknowledgement already exists but was not awaited by this fixture. Aggregate Linux job remains **FAIL**. |
| `422d131048db573c0abd08bcca25f6b3999e8703`, run [45522534938](https://github.com/techrote/cybersand/actions/runs/45522534938) | Headless 41/42 passed. The fragment/reabsorption process naturally exited 1 after 107 checks, failing the second held Cut receipt and post-release result-count assertions. Later fragmentation, native material conservation, physical mass and settlement checks passed. Graphical qualification was not reached. Aggregate Linux job remains **FAIL**. |

The second campaign includes the independently reviewed long-burn clock repair;
its original long-burn case passed. These outcomes neither waive the remaining
failures nor establish qualification for a subsequent fixture or product repair.
The exact pointer-ordering cause is still under independent investigation at
this checkpoint.

The independent ZIP auditor now streams payload hashes and bounded PE header
reads, preserving every previous source, digest, provenance and image check.
This avoids allocating the complete 178 MB engine image in the local reviewer.
The [audit-only verification receipt](objectshard-m4-recovery-20261125/zip-stream-audit-checks.json)
records both actual pinned Windows engine images passing and six malformed
header fixtures being refused. Independent review also supplied a ZIP whose
valid CRC covered only 90 actual image bytes while its central directory
declared 200 bytes. The first streaming draft incorrectly trusted that length.
The corrected member hash counts actual decompressed bytes, and both the hash
and PE paths refuse this fixture. No evaluator was inspected using the defective
draft. The [repeatable audit challenge](objectshard-m4-recovery-20261125/challenge_windows_zip_audit.py)
requires the independently acquired official archive and records all ten checks.
The ordinary package producer, shipped verifier,
application, workflow and registered execution inventory are unchanged by this
audit-only adjustment. A locally terminated bulk inspection is not represented
as a pass or attributed to a diagnosed memory failure.

## Required next execution and disposition

The existing completion workflow supports a principal-branch push whose commit
message includes `[objectshard-m4-completion]`; a workflow dispatch is also
defined. Root integration owns admission and must freeze the integrated source
before triggering the established campaign. Do not launch duplicate campaigns
or cancel another programme's work.

The new campaign must establish actual Linux acquisition and ordinary
headless/graphical Workbench execution, actual Windows candidate execution,
source-matched package production, four pristine shipped-CMD paths, all eight
provenance refusals and the complete extracted-package replay. The current
checkpoint is **repair implemented / local contracts PASS / replacement
platform and delivery qualification required**. PR #754 remains Draft/HOLD,
and physical Windows 11/NVIDIA acceptance remains HOLD.

## Independent performance-control and publication-scope review

Delivery lane C independently reviewed performance commit
`61213289ccaf2ec9771274f73576752ac1d648ff`: **APPROVE source/test scope**, with
actual replacement platform execution still required. All ten focused Python
qualification-validator tests passed. A synthetic enumeration of the actual
qualifier (without executing any engine) established 42 headless, 31 graphical
and 16 extracted-package cases. Eighteen cases in the graphical lane require a
display. Comparing names with the recovered original 38/27 reports found no
removed cases and exactly four additions in each full lane.

The disabled/enabled controls share the native tower recipe, ordinary actor,
canvas, view and exact authored-rectangle digest. The qualifier compares these
identities. Light tower recording-on/off trials retain the same 180 semantic
ticks, Rapier motion and acknowledgements. Both diagnostics variants exercise
the actual graphical checkbox path when a renderer is requested. No physics,
material, worker-barrier or actor-coverage reduction was found. The
[machine-readable review](objectshard-m4-recovery-20261125/delivery-independent-review.json)
retains inspected input hashes and complete expected case names.

The repository's retained-runtime status is a separate, unresolved gate.
[Repository release policy](../operations/github-development-and-release.md)
requires exact-head Documentation/provenance and broad implementation gates
before Ready/merge. [Current validation policy](../operations/current-and-historical-validation.md)
and `check_repository.py` explicitly check the two **published retained** native
manifests. Their stale source inputs remain real failures; candidate execution
does not make those failures pass. The M4 integration contract explicitly
excludes qualifying retained production binaries. A source-matched portable
candidate can therefore be qualified for owner evaluation while the retained
repository runtime/publication and merge gates remain open. This scoped result
must never be described as complete repository production readiness, and the
accepted production manifests remain untouched.

## Independent pinned-engine acquisition

The recovery reviewer separately downloaded both official Godot 4.7 archives
through the repository's approved direct `godotengine/godot-builds` release
route. The Linux ZIP matched the locked 75,664,355-byte size and SHA-256 above,
passed ZIP CRC inspection, and its extracted executable returned exactly
`4.7.stable.official.5b4e0cb0f`. This independently exercises the repaired
acquisition route; the new hosted Linux Workbench job still owns application
qualification. The [original local acquisition receipt](objectshard-m4-recovery-20261125/independent-linux-engine.json)
records executable size and hash.

The Windows archive was 83,764,371 bytes and matched the existing locked
SHA-512. Both executables have valid AMD64 PE32+ headers. Their independently
measured SHA-256 values are
`b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`
(graphical engine, 178,485,256 bytes) and
`d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`
(console wrapper, 198,152 bytes). The
[archive receipt](objectshard-m4-recovery-20261125/independent-windows-engine.json)
retains both identities. This is independent byte/format inspection on Linux,
not a Windows execution claim.

The [independent final-ZIP reviewer](objectshard-m4-recovery-20261125/inspect_windows_evaluator.py)
imports no package producer or shipped verifier code. It checks ZIP paths and
CRC, the complete immutable payload, candidate/native input identities, the
frozen canonical Git source, preserved reference provenance, actual AMD64
images and direct equality with the separately acquired approved engine. Its
final execution must target the newly delivered archive and be combined with
original Windows launcher and pristine-replay receipts.
