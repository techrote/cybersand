---
title: LCB controlled session handover
status: Current
document-kind: audit
scope: Controlled landing of the 2026-10-25 multisolver session; exact accepted and pending checkpoints, evidence identities and continuation order
canonical-for: []
last-reviewed: 2026-10-26
related-documents: [../operations/cybersand-codex-development-handover.md, ../operations/source-checkpoint-and-recovery.md, ../operations/github-development-and-release.md, ../operations/lcb-water-comparison-and-fixtures.md, ../reference/status-and-roadmap.md]
---

# LCB controlled session handover

## Owner boundary and timing

The owner requested a controlled landing at **2026-10-25 22:47:24 UTC**, aiming
for a natural stopping point around **2026-10-26 00:17:24 UTC**. Stop initiating
development by **00:47:24 UTC**, even if some CI/review is incomplete. Complete
already active bounded checkpoints, preserve failures and exact provenance, then
handover. This instruction replaces the earlier open-ended continuation; it does
not expand the epic. Further Web/browser/shader testing stays owner-deferred
until after the epic, preserving prior failures without a visual pass/fallback.

The final source/PR snapshot below distinguishes accepted, externally active
and unexecuted work. Its timestamp is the observation boundary; any subsequent
CI completion still needs fresh independent readback. This handover does not
authorize automatic merges or start another implementation stream.

## Verified starting state

At receipt of the landing instruction, GitHub independently confirms:

| Checkpoint | State and exact identity |
|---|---|
| App #256 | Merged22:27:44 UTC; head `dc2eee9408b959956153608a7ee6d212a5d21672` |
| Main after #256 | `56422c050bd5ed2ceb5f816b1269748764e2dcb7`, tree `f79b861fbb84fe40c3e99f170c937aac7b521021` |
| Trial #257 | Ready/open; head `9009717889501992063a7576dccc42dd712fc5aa`, tree `af6778f4329a000a7b4ab04904a2811cb0df735a` |
| Observer #258 | Ready/open; head `fb60b66a20d907ba51936cfd73eb9b56c6f11850`, tree `1586d7aa3291c9b1cb9500028ea8c7b9a29f7d73` |
| Science #259 | Draft/open; head `e98d2b15801c67ec6bfa6db32d79242fea53842b`, tree `94fba38788b29cc1954451480c531001578d73f2` |

These are starting observations, not a promise that later heads pass. Before
resuming, read the final snapshot below and fetch live GitHub/main state.

Superseded application drafts [#252](https://github.com/techrote/cybersand/pull/252)
and [#255](https://github.com/techrote/cybersand/pull/255) were closed without
merging during this landing (23:25 UTC), after fresh head/base and Git ancestry
checks. Their exact heads
`f23f3d35214866070850d5eb4344e65b2fefed86` and
`5f3f0c21e3704232d0a2251dadc2d45bb4e4bd34` are ancestors of accepted #256 main.
Their original PR text, comments, commits, branches and worktrees remain intact;
an additive status prefix points to #256 and the actual active successors. Do
not count these closures as separate accepted merges.

## Accepted implementation and runtime evidence

During this landing, [PR #257](https://github.com/techrote/cybersand/pull/257)
merged as **`9e53a5b1b501e0667037b8502d3c1d15089211f5`**, with exact accepted
head `9009717889501992063a7576dccc42dd712fc5aa`. Its merged tree
`af6778f4329a000a7b4ab04904a2811cb0df735a` equals the actual tested synthetic
`4ab09983835836305162b3bf6b29d7321dbc0b1e` tree. All three applicable final
gates and bounded source review are independently accepted: Docs92848465,
Godot3d5a5a08 and Native
`98aebef158ded4e2320a76591e94193dffc8494fb47fe190fd21b2d069292d7e`.
Native has21 successful steps,164 exact ordered groups per ordinary/TSan/
ASan+UBSan mode,154 intended CLI invocations, zero sanitizer diagnostics and
zero tracked chunk/temperature allocations in the120-tick benchmark. Godot
includes333 actual processes. Independent final join
`80d5af8c09bfe087cfc5b6b9ad8530d10c993978f3214cf20eb23d6544c65cd8`
binds all original ten source blobs, the corrected unsupported selector and
publication/source scopes. Root final merge assessment
`1024728e000c6cd03c91d8a78bacec222b331c950fac2022524984cf33896a88`
is at `tmp/lcb-session-landing-20261025/trial257-final-acceptance/ACCEPTANCE.json`.
Fresh premerge head/base/review-thread checks and postmerge Git tree/parent/main
readback agree. This accepts the bounded transactional barrel/Ripper owners,
including actual FM/CY/PF0/PF1/PF2 body-play and legacy-owner rollback; it does
not accept positive IN Trial-body, every constructor or complete #202/#203.

App #256 passes exact-dc2 [Documentation 40234912993](https://github.com/techrote/cybersand/actions/runs/40234912993),
[Native 40234912984](https://github.com/techrote/cybersand/actions/runs/40234912984),
[GDExtension/Godot 40234913054](https://github.com/techrote/cybersand/actions/runs/40234913054)
and [#49 apparatus 40234913023](https://github.com/techrote/cybersand/actions/runs/40234913023).
The actual tested synthetic
tree equals the merged main tree. Ordinary/TSan/ASan+UBSan each pass the same
ordered164-group registry; Godot has331 actual processes and #49 has120 cases,
60 pairs and5,880 samples. Independent reviews and Root acceptance
`3bbc3a9908ec5e2e72a9ed1edc752142f3dddd500c98804aa87906833c86ce67`
preserve the old failed identity-test expectations and their correction.

Actual App003 publication remains source5f02/run40226343524/bot0c9, Windows
`e3f17363d21260690682dfaa9e5e118253544c1b9b19e69e50c03af567712343`
and Linux `02ea0661d3a62e2ab346c3fe46f9f85b808c6a0099c639144f053dc70a5c3d46`.
Its original72 processes and80-native/535-build ledgers retain their original
source identity. Later GDScript/test differences are explicit, not rewritten.

Observer004 actual publication is independently accepted at source2e1/run
40237132659/bot871ff:76 actual processes,80-native/542-build ledgers, all18 LFS
payloads and unchanged Linux floor. Windows
`ba357334a2c3b73c5d631442a164593ec9826acc6767e7283f8ffb55753ac4ff`;
Linux `30bcfaf7902d286c077b0c457bce57144952ed6cefbd94704d310ea0d312df25`.
Publication review `c5356cfddf7dbc169f878b0057b6edc0a33bc6965fb5491158b89cd5e0e54f41`
is separate from #258 final-head acceptance. Approval-held bot follow-ups are
not greens. The publisher lease is released; do not arm an accidental new run.

The bounded native residual #200 contract was already accepted through #246
and reconciled through #251; no new native #200 defect is identified by that
accepted clause map. Pressure optimization #253 merged as
`6605112986dd905c1b2ec626030be7067ca07ef0`, Brine IN #250 as
`dc915f2b2cc1261501058d0e967a98f32ecdee9d`, and Water IN #254 as
`06451f8ac9e8ac9b23a105d2fe22393375dc2d6b`. These precede this landing window;
their source-bound publication/failures remain in their original records.
Old issue mirrors describing #250/#253 as blocked drafts or Water IN as
unavailable are historical intermediate observations. Consume the later accepted
source and [Water publication record](2026-10-25-water-inertial-publication.md)
rather than reopening a solved defect solely from an old status paragraph.

## In-flight gates at the starting boundary

| PR/head | Documentation | Native | GDExtension/Godot |
|---|---|---|---|
| #257 /90097178 | [40241199943](https://github.com/techrote/cybersand/actions/runs/40241199943), independently accepted | [40241200007](https://github.com/techrote/cybersand/actions/runs/40241200007) | [40241200038](https://github.com/techrote/cybersand/actions/runs/40241200038), independently accepted |
| #258 /fb60b66a | [40241133697](https://github.com/techrote/cybersand/actions/runs/40241133697), independently accepted | [40241133702](https://github.com/techrote/cybersand/actions/runs/40241133702) | [40241133760](https://github.com/techrote/cybersand/actions/runs/40241133760), independently accepted |

The final snapshot records conclusions and any later replacement runs. Do not
call queued/running/action_required/cancelled checks green. After #257 merged,
#258's new integrated tree requires fresh applicable acceptance; its former
same-head checks do not silently validate the changed base.

Both final Godot runs completed successfully and have independent artifact
acceptance. Trial: 170 Linux and158 Windows cases,333 actual processes including
imports; review SHA
`3d5a5a08885698f33c7d0118ad6468946c3615d23f40605102bde11e64ac66dd`.
Observer:171 Linux and159 Windows cases,335 processes; review SHA
`782cd1c1dae94c514a2b5f0b34bfa1b217f2c4b7ab03f48dcdc9846a4d1c2ec6`.
Each includes twelve native rendered cases and independent raw timing/runtime/
floor checks. Seven Godot archives per run are distinct from the separate Native
archive; excluded optional stress/serial jobs and obsolete draft skips are not
counted as successes. At23:20 UTC both Native runs were still executing ASan+
UBSan; that partial progress was not final acceptance.

The applicable ready-PR matrix for these two successors is Documentation,
Native and GDExtension/Godot. Their deltas do not touch the native core/header
or apparatus paths selected by `.github/workflows/issue49-water-apparatus.yml`,
so #49 is not triggered for either. This is an explicit scope decision, not an
unexecuted Water gate reported as passed. Scope must be reconsidered if an
integration or correction changes those native paths.

The superseded ff2 Native40235988130 persisted through Draft/replacement and was
explicitly force-cancelled after current ready head90097178 was verified. Its
completed/partial steps remain historical, not final-head acceptance. Receipt
`c63aa05e07926a9521f62d61b8d9e0aeb532a1bacfe2a2d7272b5e4a62c7b674`
records that only this obsolete run was cancelled; no main/current/publication
run was cancelled by that operation.

## Active successor work and preserved failures

Trial #257 changes one inherited negative to the actually unsupported
`rapier/lcb-unsupported-rig` selector, retaining no-queue/generation/old-gyrocrate
fences. The prior
full ff2 Godot run40235988125 fails that same stale barrel-refusal expectation
on both OSes; dedicated Trial117 passes in the same Windows job. Corrected local
E3 import/sample71/Trial117/default86 proofs pass; source/artifact review8a6b44c2
and final-docs review92848465 are separate from full corrected-head CI.

Observer #258 exposes copied nineteen-field decimal ledgers and configured versus
actual Phased participation; Serial/unmeasured and idle-zero availability remain
explicit. It does not measure utilization or global scientific closure. Final
docs/source revieweafd3bf1 accepts its qualified publication status, historical
single-audit build drift and exact current80 inputs, not pending full gates.

The native-default actor-host successor is bounded to single registered owners,
retained controller/equipment/input, exact terrain/pose/masks and transactional
refusal. Its real painting callback changed an input rearm flag while preparation
was pending; deterministic input-hold regression addresses that cause. Preserve
the earlier intermittent refusals, timing-sensitive injected-charge test premise
and post-footer0xC0000005 process failure. Three final source-identical teardown
cohorts pass locally after explicit callback cleanup/worker join/tree-exit, without
claiming the earlier crash's native cause proved or a platform-wide exoneration.
The parked checkpoint is [draft PR #260](https://github.com/techrote/cybersand/pull/260),
branch `codex/lcb003-actor-host`, exact head
`86f95617d2966f9071e9fe8bdd334ea3888fa5cd`, tree
`1c001e1e4a36cf0e0cf86ceb2cb9cf82c02354fb`, stacked on Trial90097178.
Source commit `2e040037d255e387b3283f7e7d72aa6a49506abf`, normal merge
`01e756a9a9fee977f2169d292aecc64207843a1b` and the separate fifteen-document
commit preserve recovery boundaries. Only paint/usable-event callbacks are held;
actual keyboard edges deliberately invalidate/cancel a pending preparation.
The borrower retains the live controller/equipment/session, never destroys the
installed body on close, and checks exact terrain/pose/body masks/receipt.
Final local Windows cohorts include122 assertions on three fresh processes,
default86/Trial117/physical105 controls and an advanced38-assertion real IN Water/
skimmer Apply after24 native ticks, with four more resumed ticks. That advanced
proof covers that IN/skimmer arm, not every sampled/physical actor or policy.
Ten source/139 compiled Native inputs and80 runtime-ledger inputs remain fixed;
the historical535 build list is528 equal/7 script-test differences/11 additions
for546 current paths, without rewriting old publication identity.

Independent source review
`71ff55d2e859aa1463988ec1d6eaf65d53185253258167fd3f74dcdacdd9aa4b`,
advanced addendum
`c90b7da4b6032a6c419f2a65b2dd3506f570a5214c647ef2c3bac011ec41a739`
and corrected documentation closure
`2cd86164abe5f56fef9a1a576342a6e0469ac265b7ad813b06f1b03ccdbb46c1`
are clean within those scopes. The final proper-seven receipt
`32aea4833481ecf107236c47f2bf73b27d180143821c1b27772b70e102b21b25`
has repository errors0. Earlier metadata-default decoding damaged unrelated
UTF-8 Markdown text; the corrected freeze reconstructs all fourteen inherited
bodies exactly when only intended additions/row changes are reversed, retaining
all152 previous question objects and adding question153. The bad freeze and
review finding remain historical. This does not replace full ready-head platform
gates. Automatic [Docs40244499431](https://github.com/techrote/cybersand/actions/runs/40244499431)
was in progress at23:23; draft Native40244499447 and Godot40244499502 skips are
unexecuted. Agent handover
`C:/Users/_/.codex/tmp/lcb202-default-actor-host/PARKED-HANDOVER.json`, SHA256
`6f9d2233db90f8a853706ea4651a186ec93d4e3a792e242f57598071225ee070`,
records clean local/remote source, no owned active process and no further tasks.

Science #259 is an apparatus checkpoint, not a long scientific campaign. It uses
real Godot preparation and byte-identical CYPS restoration, complete resident
census and independent quantity/nineteen-field IN closure. Short actual Windows
O1 qualification prepares three registered fixtures and executes six1/4-worker
children for30 ticks; corrected readers re-reduce those outputs with25 adverse
mutations. Independent reader/harnessc18a9433 and CLI/Makefileb93499ef reviews
close their bounded findings. The original legacy-hash-zero mismatch, protocol
amendment, source identity/numeric/coverage findings, missing LFS/PATH and helper
failures remain recorded. The already active bounded Linux/Windows Release
qualification infrastructure must either be reviewed/executed or left as a clean
explicit gap; no new fixture stream, residual threshold or full campaign starts.

The first actual Release qualification at exact
`baab6d75143bbdfd4bd409238f5525f6aeda6c6c`,
[run40243375312 attempt1](https://github.com/techrote/cybersand/actions/runs/40243375312),
**fails before any actual qualification physics**. The Windows cross-build
genuinely succeeds (five translation units/38 compiled inputs/PE/import/archive
checks), but Linux GCC13 rejects a most-vexing-parse/CTAD `std::span` declaration.
The Windows execution job refuses raw `world_inertial.inc` checkout bytes before
Godot: native-eol/stat-cache CRLF differences remain despite `autocrlf=false`.
The bounded repair uses an explicit const-byte span with brace initialization
and Git-extracted LF bytes for only the authenticated compiled Native text paths;
the raw source-map verifier remains strict. Failed setup fixtures, all three job
logs and three API-digest archives remain preserved. Corrected pure tests and a
Windows syntax-only check do not establish corrected GCC/link/physics success.
The final snapshot records the repair's actual commit and any later real run.

The repair is committed as
`d0aefea77d5b7a3d5c6b18833628a735aa831e4b`, followed by the three-document seal
`7ebadf1e9d6c009e77604104ab2e177ee4bc65a6` (tree
`b24a7c8a7b731c07be9e5eef1dcb75f41afb8544`). Ready #259 is pushed/clean on
`codex/lcb004-science`; its author is parked with no owned active process.
The strict seven-file freeze
`7525ad23b31e51fac9b948b870e5f0ffa5738ce58c92412c821b1822f8f00dfa`
binds36 local guards, real Git CRLF/hostile fixtures, pinned Clang syntax-only
validation and proper-seven receipt
`4737a73aeb65a4a78925d9bfff85a0bdbb0e89211578694060dab21863347b9c`
(repository errors0). Independent repair review
`8bc1bc2d49f7427a8305133d927c9004f5b78545d78aebbb9a64bcfb200b7052`
has no open finding; both Native80 manifests, six other apparatus paths and
27 scenarios/117 historical arms remain exact. Clean pushed checkpoint
`809ec67d44f7bb91834198f30f075c1e6a4c8d350ec2b29833681fa7cd6f0bf5`
is at `tmp/lcb004-science-release-infra-failure-40243375312/final-checkpoint-v1/CHECKPOINT-RECEIPT.json`.
At23:27 UTC its naturally triggered
[Release40244829655](https://github.com/techrote/cybersand/actions/runs/40244829655),
[Docs40244829566](https://github.com/techrote/cybersand/actions/runs/40244829566),
[Native40244829682](https://github.com/techrote/cybersand/actions/runs/40244829682)
and [Godot40244829641](https://github.com/techrote/cybersand/actions/runs/40244829641)
were pending/in progress. No manual rerun or full campaign was dispatched.

Second actual run40244829655 subsequently reports Linux and Windows cross-build
success, but Windows execution again refuses before Godot/physics. This time all
38 raw compiled inputs authenticate correctly; two pure Python fixtures fail
because their mocked temporary ROOT is unresolved while production ROOT/output
are canonical. An independent real Windows8.3 path counterexample reproduces
the missed containment/refusal with an unresolved short alias and closes it with
canonical ROOT (receipt
`9c4ea3d28a802a4e915358555796cdda044e07b14553abdd67a9f99fdf5d4350`).
The exact hosted TEMP spelling is absent from the log, so that attribution is a
source/local-counterexample inference. The final test-only correction resolves
the two mock roots, retaining every refusal assertion and all production bytes.
Linux's job success still requires independent scientific artifact reduction;
it is not a Windows or complete Release pass. The final snapshot records this
correction's exact pushed head and any third actual qualification outcome.

That final fixture-only commit is
`513bf479e0c069ce492c9e1b6806a7978ae60461`, tree
`3e9fd2aa133eeae5d10ff1770cbaee30979d460e`, on the same ready #259 branch.
Two test initializers and one dated audit are its only three paths. Independent
review `86868041bc15ee38ff91fa4e218f64fcf976b0827da64f3732cffc635d9fcd1f`
passes both corrected refusal cases under an actual short-path TEMP namespace;
all assertions and production bytes remain unchanged. Thirty-six local tests
and proper-seven receipt
`61dc77e6396cd5cb2b009d8aec5cb9f7f1eca091b45649d36b25fc97579fda2c`
pass with repository errors0. Clean pushed/parked packet
`1b77dfc08c93f5781e0d7b3c3b09cca60c98b8d67eecab48c8871188e410ce92`
is at `tmp/lcb004-science-fixture-alias-failure-40244829655/final-checkpoint-v1/CHECKPOINT-RECEIPT.json`.
At23:36 the naturally triggered final-head runs are
[Release40245503135](https://github.com/techrote/cybersand/actions/runs/40245503135),
[Docs40245503126](https://github.com/techrote/cybersand/actions/runs/40245503126),
[Native40245503184](https://github.com/techrote/cybersand/actions/runs/40245503184)
and [Godot40245503129](https://github.com/techrote/cybersand/actions/runs/40245503129).
Their final observed outcomes belong in the stopping snapshot. Earlier exact-head
runs superseded by these normal pushes retain their real automatic concurrency
cancellation/status; no incomplete old run becomes a final-head green.

**Final bounded Release qualification is independently accepted** at513bf479,
run40245503135 attempt1, actual synthetic checkout
`8ec7c15991f92a832697af0d64ba81116c34af16` (parents564+513b, exact3e9 tree).
Independent receipt
`ebe7a426da97d9a5c09826b98a32a4b23bf872f80480b204c28b0dd4523e172c`
at `tmp/lcb004-science-release-final-independent-v1-20261025/REVIEW-RECEIPT.json`
authenticates three job logs/three API-digest ZIPs/5,926 extracted files.
Linux consumer SHA256
`57338fbe4d6165b09e9a828cfe88f661729e0360fc1162e6537c5a58584b152f`
(745,888 bytes) and Windows
`af5fcb28b00bbbdba1dcc82e1cf1ca8b50f326d91d782d83402123175764a2c4`
(939,008 bytes) are actual five-TU/38-input `-O3 -DNDEBUG -flto` builds.
The driver/object/depfile/bundle maps and Windows transfer authenticate; actual
Windows restoration covers38 paths including seven original CRLF `.inc` files.
Existing core compiler warnings remain in the build logs; no warning suppression
or World edit is part of this checkpoint.

Each platform performs three real Godot preparations/imports and six bounded
one/four-worker thirty-tick native children (120s per child). Independent replay
accepts six original positive reports and refuses25 registered hostile mutations
for their intended reasons per platform,
all190 phase closures per platform, complete1,638,400-slot census, quantity,
nineteen-field IN closure and worker/cross-OS parity projections. Preparation
definitions, serialized snapshot and run-receipt identities agree across OSes.
This qualifies the short actor-free apparatus only. It does not register/execute
the full scientific campaign, qualify total cost/full hosts, or accept the whole
PR while its other exact-head gates remain outstanding.

**Retention limit:** artifact upload omits the three hidden portable Godot
bootstrap files from each of six staged projects. Their646-entry source maps and
Git-declared hashes are checked, but only643 staged tracked-file bytes per arm
are available for independent rehash. `ARTIFACT-OMISSION.json` records this;
do not claim complete staged byte retention. The next session must retain and
independently authenticate those three omitted files' actual bytes before
claiming full staged-source or full scientific campaign closure. This preserves
the present narrow thirty-tick acceptance. Actual mapped modules, executed
scripts, every transitive compiler dependency, portable CLI loader pins and
full-host execution identity also remain unproved; no such waiver is implied.

## Workspace and recovery rules

**Do not switch, reset or edit the user's dirty primary checkout `C:/khybersand`.**
It remains the separate material-fidelity user work. All session work uses managed
trees under `C:/Users/_/.codex/worktrees`, sharing `C:/khybersand/.git`.

| Responsibility | Managed working directory |
|---|---|
| Trial | `C:/Users/_/.codex/worktrees/lcb003-trial-body/khybersand` |
| Observer | `C:/Users/_/.codex/worktrees/lcb004-observer/khybersand` |
| Actor successor | `C:/Users/_/.codex/worktrees/lcb003-actor-host/khybersand` |
| Scientific apparatus | `C:/Users/_/.codex/worktrees/lcb004-science/khybersand` |
| This documentation handover | `C:/Users/_/.codex/worktrees/lcb003-final-integration/khybersand`, branch `codex/lcb-session-handover` |

Local raw reports, source freezes and failures remain outside Git under
`C:/Users/_/.codex/tmp`. They must not be committed as logs/build archives.
The final evidence inventory supplies exact packet paths/hashes; GitHub run IDs
allow independent API/log/artifact recapture. Recover source from the pushed
branches, not undocumented working-tree copies. Preserve the eighteen actual LFS
objects, dependency pins, all historical receipts and the separate companion
workspace at pin6a583119. Proper validation runs in the companion-parent mirror;
direct source-tree checks can otherwise report six missing companion fact paths.

The read-only23:20 inventory contains46 Git worktrees. Dirty historical user,
Claude, diagnostics, validation, quickplay, material and deferred-palette trees
were preserved rather than cleaned. In particular, primary
`mat/material-fidelity-pass-2` stays at
`620826f59fbe248f93a45c45e786a7297f2e5288` with its existing122 dirty paths.
The old Claude host tree at
`264f3951727d21df4e8aa3d2ca665f84e5b00ff6` has three uncommitted adapter/header
paths; it is not the clean accepted App or #260 source. The deferred palette
tree at `c8bd9623f300b738333cd3847c1dd5eced763de8` retains one shader delta,
without any new shader/Web testing. Read-only binary patches/raw file hashes
are preserved at `tmp/lcb-session-landing-20261025/legacy-deltas/PRESERVED.json`,
SHA256 `7c9d813d5cfb3d97f2a7a63c3735428cee5553a35d5da48b8c1b40e8f5e89cbf`.
Do not transplant or discard those old deltas without first reconciling their
ownership and accepted replacements. The final snapshot provides the later
active-LCB cleanliness and process state; this is not a globally clean-workspace
claim.

## Continuation order and genuine remaining work

Continue **finish residual #200 → fan out #201/#202/#212 → #203**, consuming the
already accepted bounded checkpoints rather than rebuilding them. Finish pending
source/head integration and exact gates first. Then complete actual full-app
constructor/lifecycle/identity coverage, separately preregister the long scientific
matrix with N/source-stop/window/repeats/budgets before output, and qualify the
complete packaged product. Current defaults stay unchanged; optional owner feel
preferences remain separate from technical qualification.

This is the dependency order, not an instruction to repeat accepted native
#200/#201/#212 work. The remaining #200 join is normal-application ownership and
qualification under #202/#203. All five issues remain open while their complete
requirement joins remain unaccepted; merged prerequisites alone do not close them.

The #201 rest certificate must decline **any body mask anywhere in the complete
5×5 contact stencil**. Unchanged pixels or subpixel/rounded body motion do not
prove rest. Failed motion contacts, chemistry, Water updates, cadence/future
events and unrelated liquids still require work; head/gas/body changes revoke the
certificate. Preserve the regression/evidence; do not weaken this to win timing.

Genuine remaining host gaps include per-plane/depth/semantic/Deepworks selection
receipts, diagnostic/player modes, normal desktop save/load UX, first-accepted-input
Exploratory history, complete exhibition/copied inspection and same-policy recovery
from a quarantined prepared World. Healthy-only Restart's typed refusal is not a
complete failed-session recovery implementation. Retain all117 registry records;
headless/native prerequisites are not full-host, visual or total-cost acceptance.

Do not silently select #45, alter #12 Stage4/GEN006 ownership, migrate Cell ABI,
invent a universal pressure speedup, fall back to another law or accept incomplete
platform checks. The owner-deferred Web investigation resumes after this epic.

## Final stopping snapshot

**Observation boundary: 2026-10-26 00:03:49 UTC**, with the subsequent focused
handover documentation seal recorded by its PR. Accepted main remains
`9e53a5b1b501e0667037b8502d3c1d15089211f5`; #257 is the only implementation
merged during this landing. #256 was already accepted at entry. No automatic
merge or background implementation continuation is enabled.

| Active checkpoint | Exact head/tree | Base and disposition |
|---|---|---|
| Ready [#258](https://github.com/techrote/cybersand/pull/258), `codex/lcb004-observer` | `fec2c73a33e146c63398849a1d128cf45c0ba59b` / `211cf99590737dfd76c3ab104ac7791621edac7c` | Main9e53; clean/pushed normal merge of fb60+9e53; fresh gates running, unmerged |
| Ready [#259](https://github.com/techrote/cybersand/pull/259), `codex/lcb004-science` | `513bf479e0c069ce492c9e1b6806a7978ae60461` / `3e9fd2aa133eeae5d10ff1770cbaee30979d460e` | Original parent56422c05; API still reports that old base while main has advanced. Clean/pushed; short Release accepted, final-base integration and full PR acceptance outstanding |
| Draft [#260](https://github.com/techrote/cybersand/pull/260), `codex/lcb003-actor-host` | `86f95617d2966f9071e9fe8bdd334ea3888fa5cd` / `1c001e1e4a36cf0e0cf86ceb2cb9cf82c02354fb` | Retargeted to main9e53 after #257; source head unchanged from its Trial900 stack. Clean/pushed/local proof reviewed; full ready matrix unexecuted |
| `codex/lcb-session-handover` | This focused five-document checkpoint; exact commit is in the accompanying PR/body and final report | Based on accepted main9e53; documentation only, no implementation acceptance implied |

Observer's normal integration preserves every non-document blob from its
respective parent. Nine documentation conflicts were distinct additions; the
corpus note preserves the complete Observer value plus the exact incoming
addition. Both parents'152 question objects remain intact in the153-object
union, with frozen32 unchanged. Actual private004 selector gives548 current
build paths: old542 has536 equal/six changed, plus six new Trial paths. Native80,
compiled139, runtime/manifests/profiles/requests remain unchanged from accepted
Observer publication. New-head independent integration review
`b1d6e057730e8d145d532819a4ed8a597e6db9ee04354f7e82cc42ee9e18449c`
and proper-seven
`5a863ed66531afbeb65516ea3c899f13ac460aa8aeb0663f8b2c857c7731e3df`
are clean (repository errors0). Initial v1 failed whitespace only on one extra
audit EOF blank line; that exact correction and the failed result remain
preserved. Pushed normal-merge packet
`553fb26fd0bfcdd00e1ff8d5c4e78de00cbea0c1b59a37b615740b8a3906ce4e`
is at `tmp/lcb-session-landing-20261025/observer-integration/MERGED-PUSHED-CHECKPOINT.json`.
No new engine execution or republication was needed for this unchanged Native
source; fresh integrated application gates remain required.

Original Observer fb60/base564 matrix is independently accepted as
`d8b7007727ec9e263b8d6151b928271e638d119e50a81bb55e2452fb9dac6fd6`:
Docs eafd3bf1, Godot782cd1c1/335 processes and Native
`5ffcb861fd45e1664d5b32bd35a702139e2876d795e3084bd0428e8d689b465b`
(164 groups per mode/all21 steps/310 artifacts/154 CLI invocations/zero tracked
benchmark allocations). That old green tree does not accept fec2's changed host
integration. Do not merge #258 until its fresh matrix and independent readback
are complete.

All runs below are **attempt1**. "Success observed" is a GitHub conclusion;
independent acceptance is named separately above. Later results are not accepted
merely because they eventually turn green.

| Source/scope | Run URL | Last observed status and acceptance |
|---|---|---|
| #258 fec2 Docs | [40247494788](https://github.com/techrote/cybersand/actions/runs/40247494788) | In progress at snapshot; fresh terminal readback required |
| #258 fec2 Native | [40247494793](https://github.com/techrote/cybersand/actions/runs/40247494793) | In progress; unaccepted |
| #258 fec2 Godot | [40247494969](https://github.com/techrote/cybersand/actions/runs/40247494969) | In progress; unaccepted |
| #258 staged publisher guard | [40247494872](https://github.com/techrote/cybersand/actions/runs/40247494872) | Success; guard/validation only, no new runtime publication |
| #259 final513b Release | [40245503135](https://github.com/techrote/cybersand/actions/runs/40245503135) | Success, bounded independent acceptance ebe7a426 with retention limit |
| #259 final513b Docs | [40245503126](https://github.com/techrote/cybersand/actions/runs/40245503126) | Success observed; full PR/final-base join remains open |
| #259 final513b Godot | [40245503129](https://github.com/techrote/cybersand/actions/runs/40245503129) | Success observed; independent full-gate readback remains outstanding |
| #259 final513b Native | [40245503184](https://github.com/techrote/cybersand/actions/runs/40245503184) | Pending behind earlier run; unexecuted/unaccepted at snapshot |
| Superseded Science baab Native | [40243375271](https://github.com/techrote/cybersand/actions/runs/40243375271) | Still externally running at snapshot; wrong final source, never final-head acceptance |
| Main9e53 Docs | [40246630498](https://github.com/techrote/cybersand/actions/runs/40246630498) | Success observed |
| Main9e53 Native | [40246631211](https://github.com/techrote/cybersand/actions/runs/40246631211) | In progress; corroborative postmerge check, merged tree already equals accepted #257 tree |
| Main9e53 Godot | [40246630501](https://github.com/techrote/cybersand/actions/runs/40246630501) | In progress; same qualification distinction |
| #260 draft Docs | [40244499431](https://github.com/techrote/cybersand/actions/runs/40244499431) | Success observed on original stack; separate local proper/source reviews are accepted |
| #260 draft Native/Godot | [40244499447](https://github.com/techrote/cybersand/actions/runs/40244499447), [40244499502](https://github.com/techrote/cybersand/actions/runs/40244499502) | Skipped for Draft, not execution/acceptance |

Earlier main564 push Native40240304166 and Godot40240304172 completed success;
the accepted #256 PR/tree evidence remains their acceptance basis. Failed
Science Release40243375312 and40244829655, cancelled superseded7eba Native/
Godot40244829682/40244829641 and baab Godot40243375331 retain their actual
statuses. No mass cancellation or failure erasure occurred. The separately
recorded obsolete ff2 cancellation is the only explicit force-cancel operation
in this landing.

| Agent | Final handover disposition |
|---|---|
| `/root/application_host` | Parked; clean pushed #260/86f956; no owned active process; packet6f9d2233 above |
| `/root/water_inertial` | Parked after bounded existing-apparatus fixes; clean pushed #259/513bf479; no owned active process; packet1b77dfc0 above |
| `/root/level_import_review` | Independent source/gate/scientific reviews complete; final documentation-only review then parked, no engine/build/browser execution |
| Earlier boundary/local-validation/moving-mask/pressure/release reviewers | Not present among live agents in the fresh inventory; retained original evidence is historical. No new task was dispatched to them |

Fresh46-worktree/API inventory is at
`tmp/lcb-session-landing-20261025/snapshot-20261026T000349Z/SNAPSHOT.json`, SHA256
`a278cf21ec8ba8276794431cfa03bf612937f11e7daf08cafe3fe48e7f197507`.
It includes all PR head/base payloads, exact current-head workflow lists and
worktree status/upstream/ahead-behind records. The four current LCB working
trees are recoverable; Trial/Observer/Actor/Science are clean and pushed. This
documentation tree becomes clean on its own focused commit. Fifteen pre-existing
dirty trees (including primary and the two backed-up legacy deltas) remain
preserved. A recoverable Root-only handover-draft stash
`13a34f596472f3f05692d49ae6a654c2c19b278c` was applied after the clean fast-forward
to9e53 and intentionally retained; it is historical recovery data, not a pending
operation. No agent-owned local engine/build/server process is deliberately
left running. External Actions above may continue.

### Next session: first three tasks

1. Fetch live main and read this snapshot plus the PR bodies. Read back the exact
   fec2 #258 Documentation/Native/Godot results and their actual tested base/tree;
   resolve any genuine finding, then merge only if that source is still current
   and clean. Preserve the original fb60 acceptance and publication history.
2. Consume accepted Observer/Trial interfaces in draft #260 and finish genuine
   #202 constructor/lifecycle/identity gaps, with fresh source-matched runtime
   publication only if Native inputs change. Requalify any changed integrated
   host tree. Keep advanced IN/skimmer local proof and positive unsupported
   actor/host gaps distinct. Native residual #200 is already accepted; reconcile
   its full-app ownership join without repeating solved native work.
3. Integrate #259 on that accepted host/observer source, retain/authenticate the
   three omitted bootstrap bytes, complete exact-head PR gates/readback, then
   preregister the remaining long scientific matrix before execution. #203 joins
   full four-family host, scientific, total-cost, packaging and independent
   publication qualification. Do not substitute this short apparatus pass for
   the complete campaign or close #202/#203 on prerequisites alone.

This implements **finish residual #200 → fan out #201/#202/#212 → #203** by
consuming the already accepted native/optimization/inertial checkpoints. No new
large #201/#212 architecture stream or full #203 campaign started during landing.
Web/browser/shader qualification stays owner-deferred until after the epic;
MAT #230/#231, material fidelity and nanotech remain deprioritized/out of scope.

## Practical native desktop feel testing

### Prepared accepted-main copy and evidence

**Recommended latest accepted copy:**
`C:/Users/_/CyberSand LCB Manual/accepted-9e53a5b1b501`.
It contains exact accepted main9e53/treeaf6778, pinned Godot and all18 materialized
LFS libraries. `BUILD-IDENTITY.json` SHA256
`21012f082d2c30beecd3ad9e473df045c533203f85ba54acbc620f7d6b707fe1`
binds source/native/engine/archive identities. Actual strict Windows import
5.996s, default-host86/0 in18.348s and Trial117/0 in29.917s all exit0 within
their240/180s bounds, with no warnings/errors/skips/timeouts and held source/
native fences. Smoke receipt
`23afe03ca4d4646610b93fa14dadc13b54f2a7a3858e2a04946baa45fe5ecb29`
is at `tmp/lcb-session-landing-20261025/manual-smoke-accepted-9e53a5b1b501/RECEIPT.json`.
No compilation, export or visual/Web qualification is claimed. The local
`Manual testing guide.md` and launcher accompany that copy.

The initial accepted564 backup is
`C:/Users/_/CyberSand LCB Manual/accepted-56422c050bd5-v2`.
Its `BUILD-IDENTITY.json` SHA256 is
`a559c2ceb9aab70092c8572b6d327cde87fcffabc1c97dfbbb189a808b02c667`;
it binds main/tree, all18 actual LFS payloads and the E3/02ea native libraries
listed above. Bundled Godot is `4.7.stable.official.5b4e0cb0f`; GUI executable
SHA256 `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`,
console `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`.
It uses the repository-pinned Rapier0.35.2; Windows payload
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`
and Linux `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`
remain independently authenticated. C64/E8 remains the carrier. Full dependency
and floor contracts stay at their canonical build/provenance homes.

Actual Windows smoke receipt
`23bd053e6cb689d475e2423bd43d721fd5a397c8709488b0983db46ece9a829a`
at `tmp/lcb-session-landing-20261025/manual-smoke-accepted-56422c050bd5-v2-v2/RECEIPT.json`
records strict headless import3.568s (240s bound) and default-host86/0 in17.806s
(180s bound), both exit0, source/native fences held. This is a startup/functional
smoke, not a GUI/rendered acceptance. The final stopping snapshot identifies a
newer accepted-main copy if another implementation merged during landing.

Two local packaging-apparatus failures remain separate from engine results:
Git archive actually materialized LFS payloads rather than leaving the presumed
pointers; corrected verification authenticates every payload against the committed
pointer's hash/size. The first `accepted-56422c050bd5` folder is incomplete and
must not be launched. A first smoke fence rejected known Godot import-descriptor
CRLF normalization even though import exited0; the corrected fence permits only
the four named Rapier import descriptors' canonical LF normalization and then
passes both strict processes. No unknown source drift or engine failure was
accepted by that correction. Raw receipts/scripts remain in the landing packet.

### Launch and compare

Use the clean **accepted-main project launcher with prebuilt native libraries**
identified in the final snapshot. It includes the pinned Godot4.7 executable;
double-click `Launch CyberSand.cmd` in that testing folder. No C++ build or
experimental source checkout is needed. Keep its `BUILD-IDENTITY.json` with any
report. This is a local native project launcher, not a newly qualified exported
#203 release. The repository's export templates remain absent/unpinned. Leave
the dirty material-fidelity checkout at `C:/khybersand` alone.

1. In the feature launcher choose **Liquid comparison — solver policies and
   protected Dam Break**. The Liquid comparison dialog opens automatically on
   the paused protected Dam Break; reopen it with **Liquids…** if closed.
   Start with **Controlled • fixed
   actor-free** for clear comparisons; use **Original Current control** to
   restore the protected unchanged Water reference.
2. Choose a preset/material assignment. The available presets include Current
   defaults, whole-cell Water, pressure reference/cached/dormant, Water inertial,
   Current Water with inertial Brine and pressure Water with inertial Brine.
   Availability comes from the actual native runtime. A pending selection does
   not change the World; use **Load selected comparison** or a supported
   **Apply & rebuild active**, then check the **applied** native family/variant.
3. For IN choose **Matched IN geometry (radius 3)** explicitly. Use the same
   radius3 for its Current comparator. The protected **Original Current
   control** restores radius2. For a fractional initial Water setup under CY/IN,
   explicitly choose **Normalize Water to whole cells on rebuild** and record
   added/removed/net counts. Future fractional scheduled sources still refuse.
4. Reset between models. Keep scene, seed, geometry, transport, adhesion,
   coherence, damping and camera the same; record any intentional difference.
   Try pause/step at30,60 and240 completed ticks, then ordinary free play. Human
   feel observations are useful without being scientific campaign acceptance.

| Comparison | What to look for |
|---|---|
| Protected Dam Break, Water FM/CY/PF/IN | Deep surge, front speed, retained reservoir, sheets and splashes; compare full-cell or explicitly normalized starts |
| Water/Oil/Brine lock exchange | Density boundaries, mixing and actual same-World family readback; try both Current and pressure Water with IN Brine |
| Water Feel and ordinary Waterworks | Streams, ledges, outlets and body response where the current host admits the selected policy; choose Exploratory for its staged player |
| Experiment Tower | Releases, remote changes and ordinary tools; keep transport tuning separate from family |
| Pressure reference/cached/dormant | These are three implementations of one pressure family; similar physical behavior is expected, and casual side-by-side frame rate is not isolated cost evidence |

Material Lab, Waterworks, Foundry and Neon Works retain ordinary free play.
The selected family can be rebuilt only on the documented supported host routes;
an import sharing a scene label is not that authored recipe. Some curated or
diagnostic/Deepworks/player routes and full desktop load UX remain incomplete.
In the native default scene, all three pressure variants intentionally refuse
the initial gas-compartment capacity preflight; use the small actor-free Dam
Break for pressure comparison. Do not treat that refusal as a silent fallback.
Use barrel/Ripper experimental preparation only if #257 is in the accepted build;
the later registered actor-host successor stays branch-only until accepted.
Water IN/Brine IN support does not imply every material/family combination.
Sealed rooms are not universally supposed to equalize levels; retain venting and
gas assumptions. No Web, total-cost or complete-host qualification is implied.

For a reproducible issue, copy the build/source SHA and native library SHA from
`BUILD-IDENTITY.json`; record material, applied family/variant, scene, seed,
radius, normalization, damping and other tuning, worker setting, exact actions
and approximate completed tick/time. State the expected versus observed result,
paste any typed refusal/error and attach an optional short video or screenshot.
Say whether it repeats after Reset. Keep preference (for example, better splash
feel) separate from quantity loss, failure, freeze or an incorrect applied solver.
