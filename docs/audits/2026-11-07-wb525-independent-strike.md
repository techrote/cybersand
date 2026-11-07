---
title: WB525 independent integration, capacity repair and physical cause
status: Current
document-kind: audit
scope: One-off source composition, source-built desktop qualification and unresolved owner acceptance
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../systems/shared-workbench-agent-authoring.md, ../operations/local-build-and-validation.md, ../operations/current-and-historical-validation.md]
---

# WB525 independent integration, capacity repair and physical cause

## Final independent qualification and usable delivery

Final code checkpoint`bd1325bbd53b8ffe1fb1368f3eed8abbcc1a6112`, tree
`be57653657ac8595be28cd1ddf8f796d2690d1f2`, is published on
`codex/wb525-strike-evidence-20261107`. All native inputs match accepted
main`1f82dac1`; current owner implementation blobs match the heads below.
The final cold-start test correction is independently reviewed and runs on
both rebuilt platforms. Windows completes all nine processes and414 scoped
assertions, including86 fake-provider checks, native Step33, mounted68,
capacity28, mounted hopper166, manual input24 and authored save6/reopen3.
Linux repeats native Step33, latest owner hopper134, mounted68 and capacity28
on the same code checkpoint. Both qualification reports state unchanged
source/runtime fingerprints and all processes passed. Original logs, PNGs and
native receipts are in`build/wb525-strike/windows-final-bd1325` and
`linux-final-bd1325`.

The final GitHub readback also finds a newer #530 **test-only** head
`e249775c7765adfd56098dad8e10466bd0af6874`, tree
`6b28a0826f92aec7078e358ecbb28ee10c495215`. Its sole41-line addition leaves
a valid proposal unapplied across Stop/reload and checks late-apply refusal
and Empty readback. Production source, fixture, bridge and Step blobs are
unchanged. The root retains its qualified134-assertion test snapshot;
the owner's[new146-assertion exact-head run](https://github.com/techrote/cybersand/actions/runs/42413942007)
passes, with[original artifact13590244697](https://github.com/techrote/cybersand/actions/runs/42413942007/artifacts/13590244697).
That owner evidence uses retained extensions and is not relabeled as the
root's rebuilt Windows run. The integrator should consume the released
new test blob`8559f072d59eee26d8b161ed9653c43de20ee573` from its owner.

The actual Windows delivery is
`C:/CyberSand-evidence/WB525-review-20261107-main1f82`. All839 tracked Godot
files are verified byte-identical to the final code source; the manifest
explicitly records the separately rebuilt Windows DLL override. Its own
offline launcher again completes166/166, both variants32/32 Sand,17 walls and
480 native ticks each, preserving original evidence under
`evidence/offline-20261107-211025-750`. The adjacent ordinary launch keeps
agent features opt-in. A separate local`Run Live Workbench.cmd` helper prompts
for a key in a native masked-password dialog, passes`OPENAI_API_KEY` only through the
process environment and restores that environment on exit. Its syntax is
checked; no key was entered or live call made. The user still chooses the
model/task/scope and presses Start. No key is stored in source, bundle files
or this record. Existing12-request/32-tool/2048-output-token defaults remain.

Exact-head[Documentation/provenance42414324170](https://github.com/techrote/cybersand/actions/runs/42414324170)
passes onbd1325. The replacement full
[GDExtension42414321750](https://github.com/techrote/cybersand/actions/runs/42414321750)
is now **PASS**: all273 applicable Windows and287 Linux cases plus independent
coverage reduction and both source-build jobs complete successfully. Windows
coverage verifies294 original logs across21 shards; its
[artifact13591725152](https://github.com/techrote/cybersand/actions/runs/42414321750/artifacts/13591725152)
retains the original receipt. Broad Windows shards consume the provenance-
checked retained DLL; the production Windows build and local rebuilt-DLL414
checks are separate evidence. Linux shards consume the fresh build. The two
conditionally skipped scope/stress jobs are not counted as executed gates.
Prior full Native42409680857 passes the identical native input set.
Resulting implementation-owner source admission remains separate from this
isolated branch. All PRs remain Draft; no merge, Ready or closure occurred.

## Additional owner-authorized whole-canvas scope

The owner then requested a usable larger authoring region and explicitly
authorized isolated ownership of panel/adapter/host changes: whole installed
canvas authorization with observations/edits still bounded to4096 cells.
The native authority already accepts an in-canvas rectangle without scanning
it; the two UI area restrictions are removed in favor of actual installed
bounds. A **Use whole canvas** control selects that rectangle without starting
a task. The default selection is not silently enlarged.

Null observations for larger tasks inspect at most64x64 cells centered on the
native camera and clamped inside the acknowledged scope; small task behavior
is unchanged. Step's fresh counts/PNG observation uses the same bounded path.
Explicit oversized reads/edits still refuse in native authority. Receipts
identify inspected area, full authorization and captured native/logical/pixel
viewport mapping. Generation comes from actual native admission. Projection
changes retry inside the existing bound; original PNGs are not cropped or
replaced. An independent safety reviewer found no blocking implementation
defect and required the model-tool description/null semantics to be updated.

The actual Windows test passes71/71:4,194,304-cell authorization, distant four-
cell native apply/readback at1800,1800, duplicate receipt, oversized-read/edit
and protected-edit refusals, ordinary/signed Step/Stop, camera inspection and
both scope-edge clamps. Existing mounted68 and capacity28 also pass. The first
test run's four failed expected origins are retained: ordinary workbench
camera clamping places the viewport at0..1792, so expected inspection origins
are96/1888 (signed1376), not0/1984. A separate partial128x128 authorization
then proves real inspection-window clamps at1000/1064. Product code did not
need changing for that test correction.

This additional source is distinct from the fully greenbd1325 baseline.
New CI inventory is288 Linux/274 Windows with the additional real graphical
case; prior cases are retained. Native laws, workers, per-call capacities,
image/receipt budgets and paid limits remain unchanged. Final qualification
and delivery identities for this additional patch are recorded separately.

The rebuilt Linux run also passes whole-canvas71, mounted68, capacity28 and
the full unchanged mounted hopper166 with stable source/runtime fingerprints.
Windows whole-canvas71/mounted68/capacity28 is likewise stable. The remaining
client change is model-facing description text explaining bounded/null reads;
no paid transport or limits are changed. All194 focused CI Python tests pass.

The owner reported unreliable console key entry. Independent Windows5.1
probes prove the console wrapper inherits a dummy-only environment, waits for
the actual child (1206ms for a1s timer), and forwards exit37. No real key or
service is involved. The replacement local launcher uses a masked WinForms
dialog with Paste/Launch/Cancel, rejects empty/whitespace input before launch,
clears/disposes the field, restores its process environment on exit and pauses
the command window on errors. Its noninteractive control/validation self-test
passes Windows PowerShell5.1 and PowerShell7. Actual secret paste and real API
remain human/live gates. Graphical tests are no longer opened on the owner's
desktop during their interactive testing; Linux uses isolated Xvfb.

## Final owner handoff readback

The existing #528 owner has consumed the two production repairs and three
graphical regressions in its own Draft #531, head
`4136fa68c89ebf867a2ecbb82800bf095e3546eb`, tree
`fb32fd192ecff39b15655d494223c6d12daa7cf6`. Its
[exact-head hosted native68/capacity28/mounted-hopper166 gate passed](https://github.com/techrote/cybersand/actions/runs/42411658093),
with [original artifact13589892339](https://github.com/techrote/cybersand/actions/runs/42411658093/artifacts/13589892339).
These source-identical fixes need no repeat implementation. They are still
separate from complete current-main rebuild/merge admission.

Refreshed source readback also inspected #529
`eee30c00dec3a7885255a43b892bf0a3f540848d`, tree
`41402ccfe2d3644939a2222a424ce39615bfe38e`, and #530
`7f1740074a2656e53f47d208f8241c26c9f77bf0`, tree
`3255c06bb0c227f62efc5bd9e33026687b86ba7f`. Current #529 authority and all
native inputs match the isolated composition. Current #530 Step/Stop/control
and #531 client/mount/panel blobs also match after the final byte-exact owner
consumption checkpoint `1390c3e30ab7ffd2a3d6f4d2d621704eb0387022`, tree
`d082e69e6324443dea4df267757cf2c28f2daa2b`. All three PRs remain open Drafts.

The final owner-provided78-line authored-start extension is independently
executed through the common runner on source-built Windows: **134/134**. After
each unchanged480-tick trial, the complete agent-authored apparatus saves and
reopens into a new native generation at tick0 with32 source Sand/17 protected
Walls, matched PNG and old-task Step refusal. This is authored construction
recovery, not evolved-state persistence. The package's two changed Godot files
are refreshed to1390c3e3 and the manifest records that source; the native DLL
remains the independently qualified accepted-main1f82 build. The generic
CI correction is released as6718d544,4174dcc3 andf659e040 for the existing
integrator to consume. Documentation/provenance42413856735 passed on final
documentation checkpoint`fe8a8ed182e316743a4501936a9942f03d06e0b9`, tree
`94019a09c3ddaf9867d39c4a0781b5936d4e1fd5`.

### Cold Windows startup diagnostic

Full GDExtension42412686929 is not a pass. The Windows capacity/camera case in
[shard20](https://github.com/techrote/cybersand/actions/runs/42412686929/job/128524227239)
failed its inherited45-second native-start wait after64.639 seconds, with the
hosted display initializing ANGLE/Microsoft Basic Render Driver. All other
Windows shards passed; the independent coverage reducer correctly rejected
this nonpassing case rather than certifying partial execution. Original
[shard artifact13590087604](https://github.com/techrote/cybersand/actions/runs/42412686929/artifacts/13590087604)
and [coverage artifact13590218649](https://github.com/techrote/cybersand/actions/runs/42412686929/artifacts/13590218649)
retain the failure. The two decoded job logs are also in the local evidence.

The isolated capacity regression now overrides only its inherited wait helper
to consume the existing canonical`operation_seconds` allowance300 seconds.
It preserves the actual native readiness/receipt predicates, failure behavior,
4096-cell readback, graphical evidence and independent outer watchdog. An
independent review also requires a strict deadline: a synchronous frame or
predicate crossing the bound fails when control returns, rather than accepting
a post-deadline poll. No production code, worker-owned parent test, timing
policy or simulation inputs change. The initial policy-only local Windows
run passes28/28, with201010-character proposal,258648-character applied receipt,
4096 confirmed native writes and native tick0
(`build/wb525-strike/windows-cold-start-policy`). The final strict-deadline
revision also passes28/28 on the rebuilt Windows DLL in5.398 seconds, with
unchanged source/runtime identity (`windows-cold-start-strict`). The completed
42412686929 has a passing Linux aggregate and failing Windows aggregate. Its
hosted replacement requires its own completed result; local passes do not
relabel42412686929.

## Production CI integration repair

Full production GDExtension run42409683405 exposed a genuine additional blocker:
[Windows shard17](https://github.com/techrote/cybersand/actions/runs/42409683405/job/128515124797)
ran the existing hopper headlessly without the runtime TSV that its focused
workflow normally stages. It failed **immutable fixture file missing**, retained
in [original artifact13589167125](https://github.com/techrote/cybersand/actions/runs/42409683405/artifacts/13589167125).
The human explicitly authorized an additional isolated common-CI repair.

Code checkpoint `6718d54499728bec0da101034bc26a027708382c` fixes discovery,
input staging and platform custody without editing any worker's implementation
or test script. The five older WB framebuffer cases receive real graphical
commands; the three new `_render` cases retain that convention. All eight stay
in Windows execution as a narrow supported graphical set, as well as Linux.
The planned inventory is287 Linux and273 Windows cases; no existing Windows
case is dropped. Fourteen other graphical cases retain their previous
Linux-only scope. Watchdogs, hosted budgets, provider and runner labels are
unchanged; the job planner, collector and independent reducer derive the same
source inventory.

For each of the two hopper cases, the common runner verifies the frozen native
TSV hash, creates the expected runtime copy exclusively, refuses different
existing bytes/symlinks, retains the original input with its images/receipts,
checks source/runtime/artifact integrity after execution and removes only its
invocation-created copy. The exact source TSV joins Windows tracked-input
custody. Source/runtime/artifact paths, size/hash and completion/cleanup flags
are recorded. Both independent platform reducers require this custody and
reject contradictory, absent or replaced evidence.

Independent review found that initial6718 Linux reduction did not yet inspect
the new fixture fields. A forged passed record with explicit custody failure
could reduce green. The follow-up adds the same mandatory contract to Linux;
its negative controls preserve that reproduced weakness. Python tests pass:
103 common runner,21 Windows collector,46 Windows reducer,11 hosted planner and
13 Linux reducer (**194 total**). Initial test-harness mistakes and failed runs
remain in the local record; none count as a passing production gate.

The **actual common runner**, starting with the generated fixture absent,
passes the original106-assertion and full mounted166-assertion hopper cases on
the rebuilt Windows DLL. Both use genuine GL/native simulation, verify and
retain the frozen bytes, and finish with the generated copy absent. This tests
the same path that failed in production rather than only a Python stand-in.
New full GDExtension [42411753603](https://github.com/techrote/cybersand/actions/runs/42411753603)
was dispatched on6718; its aggregate is not assumed green. Full Native
[42409680857](https://github.com/techrote/cybersand/actions/runs/42409680857)
has **passed** on the unchanged accepted-main1f82 native source in28f5bd3b.
The standalone review app's Godot/native payload is unchanged by this CI-only
follow-up. #531's owner must consume the narrow repairs and require fresh
resulting-head production gates before Ready/merge.

Hosted Windows then exposed a portability failure in6718: its automatic CRLF
checkout changed the TSV's worktree byte hash, correctly refused by staging.
The original source Git blob was unchanged. A temporary Git repository with
`core.autocrlf=true` reproduces that exact failure mechanism and verifies its
correction. An exact-path `.gitattributes` LF rule pins only v2's checkout bytes;
the frozen TSV itself remains byte-identical in Git and retains SHA256549a1db2….
No hash relaxation or geometry change is used. Failed jobs128521421991,
128521422013 and128521422073 in42411753603 remain recorded. The194 Python
controls include this real Git checkout regression, not a string-only surrogate.

## Final accepted-main refresh and delivery

Accepted main advanced during execution to
`1f82dac1cebc9b38a319153354e4bcc774289417`, tree
`ea78c459535b7806de8e200656aa78f97de539e4` (#292 material/RGBA copy endpoint
safety and its approved MAT-AUTH source transition). The isolated branch
consumes it through merge3686dd43, preserving that accepted change rather than
continuing against the older native source. It also consumes the #527 owner's
canonical paused-publication test correction1593b635 in source checkpoint
`28f5bd3bf7731e2ad7114625896caa6763583d67`, tree
`1a931e07612b09b94d51776a5308d69926f034cd`. #529 advanced to953f0c79 with
source-rebuild CI only; its authority blobs remain the consumed versions.
#531's examined head remains8425758f. Earlier source identities and failures
below are retained as earlier checkpoints, not current-main equivalence claims.

Both extension builds were repeated after this source change. Current local
Windows DLL SHA256 is
`a733ee35ce68fd6bf3b5cb50a3e5b11bd61e198238c1ead36e307605b8146647`;
Linux SO is
`c848253ea7a249fb745ee6b439337940a4067d5cb08d9cf0cf460d837cf207b2`.
The Linux rebuilt bytes again match the new committed runtime. Local cached
godot-cpp libraries use the locked source revision but differ from historical
M11 library byte identities: Windows SHA256
`2629ba35adc7b1263deeb1155d674252e1e4188c2c89d1d7158e816d18f957df`,
Linux `bc5f860471475c745ebad2b45988607a15c9a35c6996b0f08fea37570e6ef666`.
Source ledger and compiler/version checks passed; this is current local build
qualification, not historical M11 byte reproduction or runtime publication.

The first complete Linux run passed all individual cases, but accepted-main
refresh occurred before its final source-identity readback. Its aggregate
correctly refused source/runtime drift. A fresh bounded Windows/Linux run on
28f5bd3b is retained under `build/wb525-strike/*-main1f82`; only a report with
`source_and_runtimes_unchanged=true` and `all_processes_passed=true` is an
aggregate pass. The new canonical Step predicate is exercised directly.

**Final local result:** both `windows-main1f82/qualification.json` and
`linux-main1f82/qualification.json` report both booleans true. All nine processes
pass on each platform: import, client86, canonical Step33, mounted client68,
capacity/camera28, mounted hopper166, manual input24, manual save6 and separate
reopen3. The414 assertions include86 fake-provider protocol checks; they are
not414 live-service or all-native assertions. Both native hopper variants
complete480 ticks with32 catchment Sand/17 protected Walls and Stop; original
PNG files and all serialized panel native receipts are retained. No API key
is present and genuine attempts remain0/3.

Fresh hosted source28f5bd3b dispatches are
[Native42409680857](https://github.com/techrote/cybersand/actions/runs/42409680857)
and [GDExtension42409683405](https://github.com/techrote/cybersand/actions/runs/42409683405).
[Current28f5bd3b hosted mounted gate42409685781](https://github.com/techrote/cybersand/actions/runs/42409685781)
passed. The older5d5d8bc6 full Native aggregate42408005905 also passed, but
predates the accepted #292 copy change and does not replace the current run.
Previous exact29932 mounted Linux gate
[42408865575 passed](https://github.com/techrote/cybersand/actions/runs/42408865575),
with [original native/frame artifact13588940986](https://github.com/techrote/cybersand/actions/runs/42408865575/artifacts/13588940986),
and [Documentation/provenance42408863667 passed](https://github.com/techrote/cybersand/actions/runs/42408863667).
Production aggregate conclusions must still be read; partial green shards are
not a complete Native/GDExtension pass.

Local docs and materialized-retained-runtime repository checks pass after
staging the same pinned companion documentation as hosted CI
(6a58311982941b75f46e22109a0829e5acb83c7e). Initial missing-companion failures
and rebuilt-Windows-DLL identity mismatch remain in their original logs. The
rebuilt DLL is restored after source validation and remains uncommitted.
M11 retained-history integrity passes. Frozen lexical retrieval is18/32 at1,
32/32 at5,MRR0.738; supplementary160-question results are126 at1,158 at5,
MRR0.8714. The additive WB525 question retrieves the canonical answer at1;
this is lexical routing, not answer-correctness or a live retrieval claim.

A standalone Windows review project is assembled outside source, with an
explicit local rebuilt-runtime override in its manifest. Its ordinary
`Open Workbench.cmd` and `Run Offline Native Demo.cmd` require no project/editor
setup; the latter preserves a fresh output directory per execution and never
calls an AI service. The first package passed its actual4096-cell test28/28
and complete mounted hopper166/166 through its launcher. The current-main
delivery must use the refreshed package and current runtime identities above.
The refreshed folder is `C:/CyberSand-evidence/WB525-review-20261107-main1f82`;
it independently passes its actual native capacity/camera smoke28/28. Its
manifest records source28f5bd3b, Godot4.7, local DLL override and console wrapper
hash. Double-click `Open Workbench.cmd` for ordinary use or
`Run Offline Native Demo.cmd` for the scripted no-service hopper demonstration.

## Source and ownership

Inspected on 7 November 2026: accepted main
`662ed4d88c08070dbb6f313931146a23e3631471`, tree
`49a00e4b0e8e0da123b0fec2b5739a31fbbba886`; Draft #529
`6a9967fbd47c992c8f1bcd109163563d0f3ab18f`; Draft #530
`ffde819818556c61a335674fc366ab3b4a865af2`; Draft #531 initially
`a8c06fa058ae8d8e031f4887a1e5c5b4c3f48761`, then refreshed to
`8425758fcfc1d4fa589c5ee3a5258760741ef191`, tree
`6d1b994338640bdf6565aeeb4203eb2444e3c216`. Closed/no-merge physical
experiment #537 is `c930fb20074f993fdab7cd00e0a66bd18d85d570`, tree
`dc3650e67b8d32df7f5db047a865c5e669eb5baa`.

An isolated composition first consumed the #526/#527 handoffs. The #528 owner
then independently delivered that composition at `8425758f`; final repair work
uses that exact owner source. It preserves accepted-main Atlas routes, native
physics, material authority, World ownership and all frozen fixture bytes.
The dirty `C:/khybersand` MAT checkout at `620826f5` was not modified.

The human explicitly authorized **only two isolated production repairs** after
the [ownership request](https://github.com/techrote/cybersand/pull/531#issuecomment-6712055184).
The [handoff notice](https://github.com/techrote/cybersand/pull/531#issuecomment-6712114667)
reserves those slices; no original worker branch was written. Recoverable code
checkpoint `5d5d8bc6a98ddb115efe789f113fd8c656b6ae36`, tree
`171107ef0ad22cf9bc269817ae4abc80f88f2daa`, is published on
`codex/wb525-strike-evidence-20261107` for the existing #531 owner to consume.
There is no new integration PR, Ready transition, merge or production admission.

## Reproduced defects and repairs

**Current in this isolated patch:** `workbench_agent_client.gd` permits a finite
524288-character native JSON receipt. The previous65536 limit discarded a
valid4096-cell proposal. A separately reproduced1400-cell apply had already
performed and confirmed every native write and recorded authored construction,
but lost its known `applied` result at the client boundary. The new allowance is
4096 rows times112 characters plus65536 metadata characters; original image,
edit, request, tool and token limits remain separate. No mutation is retried.

**Current in this isolated patch:** `workbench_agent_mount.gd` redraws scope and
proposal overlays when camera origin, view size, content rectangle or signed
presentation origin changes. Previously cached draw commands stayed in old
screen positions after same-size camera pan. It disconnects its global frame
callback when the host exits; camera-only motion does not retire native proposal
authority. World/snapshot/interface ownership and native work capacity are unchanged.

The real mounted Windows regression prepares4096 cells without mutation, pans
and zooms with that proposal still valid, applies and verifies4096 actual native
material IDs, replays the same retained duplicate receipt, observes4096 Walls
and receives native Stop. It also verifies callback retirement on scene exit.
Observed JSON sizes:201010 proposed and258648 applied characters; native tick0.
Initial/final original PNGs and receipts remain under the execution directory.

An independent review accepted both narrow production changes and reran the
existing client86/86. It found an initial qualification-runner false-positive
path: zero exit without a positive test summary. The runner now requires the
case-specific positive-count/zero-failure summary, rejects Godot script/runtime
errors and preserves failed/timeout logs. Explicit zero-assertion and missing
summary controls refuse. Historical failed attempts are not relabelled.

## Why do 26 translated NORMAL states differ?

**Measured:** native `World::deterministic_direction` hashes absolute x/y and tick.
At the first branching update, original(-1,8) chooses-1; translated(511,520)
chooses+1 with the same local occupancy. Unchanged physics therefore chooses
opposite legal diagonal moves. The +512 shift preserves chunk/core/color/scan
parity but not the direction hash. Original #537 compares two unrestricted
signed Worlds: finite boundaries cannot cause those26 differences.

Independent GCC13.3 source builds reproduce NORMAL mismatches at ticks
7,8,9,10,38,39,41,42,43,44,45,48,49,50,51,52,53,55,56,57,58,59,60,61,62,63
with configured workers1 and4. Maximum symmetric occupancy difference is4
sites. REVISED matches all481 sampled states. Corresponding finite2048-square
scheduling coverage preserves the same result. A **test-only copied** World that
subtracts512 before that hash removes all differences in all four arms. This
causal intervention is **Rejected as a production repair**: it changes the
coordinate-dependent physical law. The original source and fixture stay intact.

Every arm conserves32 Sand and17 protected Walls, completes480 native ticks,
matches catchment counts at all481 states, first completes at NORMAL57 and
REVISED40, and has identical terminal occupancy. This proves terminal/count
equivalence, not trajectory equivalence. Actual participating worker maximum
in the frozen native control remains1; configured4 is not a concurrency claim.

**Approved owner disposition, later in this execution:** after the difference
was explained in plain language, the human explicitly answered **“Yes—use the
moved hopper and record the difference.”** The +512 hopper is admitted as the
workbench acceptance control, preserving original logical geometry, counts,
protection, materials and total480 ticks. The
[owner decision record](https://github.com/techrote/cybersand/issues/525#issuecomment-6712294815)
supersedes the earlier fixture-admission HOLD. It does not claim identical grain
trajectories, approve a hash/physics change, merge, paid spending or human verdict.
Literal signed trajectory reproduction remains separately unqualified; it would
need bounded adapter/canvas/render/camera work, not a new physics engine.

## Executed platform evidence and retained failures

Official Godot4.7 `4.7.stable.official.5b4e0cb0f`, Windows NVIDIA OpenGL
compatibility and WSL Ubuntu24.04 GCC13.3/ld2.42 were used. The pinned
godot-cpp revision remains `101ae38034304346a46ea9ea84ae156d3e860496`.
Both extensions were freshly compiled from unchanged current native source
using `tools/build_native_extension.sh` and
`tools/build_native_extension_windows.sh`; the Windows build's first attempt
failed on the machine's python3 Store alias, then passed using the existing
local Python shim. That failure is retained.

| Runtime | SHA256 |
|---|---|
| Rebuilt Windows CyberSand DLL | `33484119fa2026e42c997d990088fb8fcd3666186502bfac0c6c26cd94e6cac8` |
| Rebuilt Linux CyberSand SO | `23cb57d97b31aeb6720c4363dc90dfb437e6dd25566ae8a5865c2b6a4fafa605` |
| Retained Windows Rapier DLL | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |
| Retained Linux Rapier SO | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Frozen v2 TSV | `549a1db2520bcfb35f068f46b62320d7325d6297037ca2faf23c3b488d80347c` |

The Linux rebuild is byte-identical to the retained SO and passes the GLIBC2.34
bundle floor. The local Windows DLL differs from committed LFS identity and is
**not published**. `check_repository.py` consequently reports that local
runtime mismatch; it must not be suppressed or treated as source publication.
The clean retained-runtime source validation is a separate gate.

Windows source-built execution passed native owner141, four-tool join46,
signed join16, direct experimental frozen hopper106, mounted client68,
manual input24, native render bridge, manual save6 and separate-process reopen3.
The new mounted **panel -> asynchronous fake Responses -> native dispatcher**
hopper passed both destinations: four applied native batches, exactly480 ticks,
32 catchment Sand,17 protected cells, original PNGs and acknowledged Stop.
This extends the prior direct-bridge hopper through the actual panel/client.
The full fake transcript uses20 HTTP turns from an explicit **test-only24**
budget; the paid default12 has not changed. Real live trials need a predeclared
adequate request allowance and aggregate480-tick accounting.

The unchanged canonical Step test exposed a test synchronization failure on
Windows: its manual-step predicate observes the serial before the paused native
publication, and the next agent call correctly refuses. Its four failed
assertions/final127 ticks are preserved. A separately owned wrapper waits for
the actual paused publication and passes33/33 with130 total ticks and Stop
after3 completed ticks. The [#527 handoff](https://github.com/techrote/cybersand/pull/530#issuecomment-6712145130)
requests that predicate correction. An initial headless invocation incorrectly
waited for graphical post-draw; it was terminated and is not a qualification pass.

Full production workflows were explicitly dispatched on code checkpoint5d5d8bc6:
[Native42408005905](https://github.com/techrote/cybersand/actions/runs/42408005905),
[GDExtension42408008040](https://github.com/techrote/cybersand/actions/runs/42408008040),
[Documentation42408010135](https://github.com/techrote/cybersand/actions/runs/42408010135).
Read actual final conclusions; dispatch and Draft-skipped jobs are not passes.
Documentation passed on5d5d8bc6. The initial full GDExtension run was cancelled
after detecting that the three new graphical tests needed the repository's
`_render` naming convention. Follow-up code commit
`ecdbc6ab603af0302a0675b7bfea36fe62263e7a` classifies them correctly and selects
Dummy audio in the offline runner. Linux's first graphical diagnostic passed
its native assertions but emitted an unavailable-ALSA-device error; the strict
runner correctly refused it. Windows-worktree Git under WSL uses an explicit
Windows-Git shim; initial native-WSL-Git path failure is also retained.
Local platform JSON reports/logs include exact commands, timeouts, source file
hashes, runtime hashes, process exits, failures and original image hashes.

## Reproduce and launch on Windows

The isolated working checkout is
`C:/Users/_/.codex/worktrees/wb525-strike-20261107/khybersand`.
Run the graphical application from PowerShell:

```powershell
& C:/Godot47/Godot_v4.7-stable_win64.exe --path C:/Users/_/.codex/worktrees/wb525-strike-20261107/khybersand/godot --rendering-method gl_compatibility -- --workbench
```

Ordinary brush, Step and named authored starts work with agent features disabled.
Enable **Agent authoring (opt-in)** for the panel. Choose task, model, bounded
region, protection and Hard Wall/Empty permissions. The owner-admitted +512
checkbox is off by default; selecting it does not establish signed trajectory parity. Start
needs a process-local `OPENAI_API_KEY`; do not store a key in project/saves/logs.
Stop retires native authority before another task can begin. No credentials or
genuine service attempts were used by this execution.

From that source root, run the offline automated native/UI gate (output must be
a new directory):

```powershell
python tools/wb_agent/qualify_integrated.py --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe --output build/wb525-new-run --cases client capacity-camera step mounted mounted-hopper manual-input manual-save manual-reopen
```

The current canonical Step test includes its owner's paused-publication fix
and passes33/33 on both rebuilt platforms. The separately named diagnostic
wrapper and earlier failed test logs remain retained evidence.
Graphical cases have420-second process bounds; headless/import cases240.
The runner removes `OPENAI_API_KEY` from child environments and makes no paid
calls. For Linux use the same Python entry point with the locked Linux Godot
path and `--xvfb`, after source-building its extension.

Physical causal evidence remains in the independent worktree's ignored
`build/wb525-physical` directory. From PowerShell:

```powershell
wsl -d Ubuntu-24.04 -- bash -lc 'cd /mnt/c/Users/_/.codex/worktrees/wb525-physical-20261107/khybersand && bash build/wb525-physical/reproduce.sh'
```

It compiles original, copied-hash-counterfactual and finite-coverage controls
with90-second execution bounds. Generated diagnostic World copies, binaries,
PNGs, logs and machine-local toolchains are excluded from the commit.

## Completion and shortest remaining route

Engineering has substantial source-built desktop evidence; the canonical
Step-test correction and initial #531 receipt/camera consumption are complete.
The latest common-CI handoff and #527 authored-start test still require
consumption into the actual integration head, its full hosted production
results and independent source admission. MAT-AUTH and GEN-006 files,
native laws/defaults, failure quarantine and immutable render authority were
not modified. Save/reopen qualification concerns authored starts, never evolved
runtime persistence. No new ADR is needed for these bounded UI/transport repairs.

Live remains **0/3 genuine attempts, HOLD**. The moved fixture is now owner
admitted; the owner must still approve registered spending/model/turn limits and use a
trial driver that counts actual cumulative ticks. All three actual attempts,
at most one repair each, must be preserved. This offline fake transport cannot
supply that gate. Human Windows graphical preview/intervention/recovery verdict
is **PENDING** and cannot be supplied by automated input or CI.

The shortest route is for the existing integrator/#528 owner to consume
released6718d544/4174dcc3/f659e040/bd1325bb CI corrections and #527's exact
e249775c authored-start/pending-proposal test, reconcile latest owner heads onto accepted main,
make the source-build workflow eligible for that branch and read exact
resulting-head production gates plus independent admission, then perform the three registered
bounded live trials plus human review using the owner-admitted moved fixture. No
parent/child closure or merge is authorized by this record.
