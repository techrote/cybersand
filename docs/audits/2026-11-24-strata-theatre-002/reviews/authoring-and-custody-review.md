# STRATA-THEATRE-002 — authoring contract and independent review A

**Disposition: Draft/HOLD.** This dated review records a specific implementation
checkpoint and concrete cross-review findings. It does not approve a merge,
promote the candidate, certify later source, or establish physical Windows/NVIDIA
appearance or performance. The companion
[machine-readable receipt](authoring-and-custody-review.json) pins the reviewed
commits and file hashes.

Specialist A implemented the import, module, finite-plan, session and provenance
components. Those components are described below as an **implementation handoff**,
not independently approved by their author. A independently reviewed the lead's
ordinary Workbench mediator, native owner settings/admission seam, and specialist
C's user-interface and qualification/package custody changes. Actual native
mutation and display qualification remain distinct from value-owner codec tests.

## Source and evidence scope

| Scope | Exact checkpoint | Review or execution |
| --- | --- | --- |
| Frozen predecessor | `80623d039aa49bc0c1d84a9206d89812ffa99ea6` | Read-only architectural and evidence intake; original #769 application/evaluator remain unchanged |
| Native architectural interchange donor | `fe2395c7060dae736dc2e5dc8d1e4e050b2d2e52` | Narrow read-only #770 module schema adapter; no moving architecture branch or planner absorbed |
| A codecs/session | `46cd8e74d36afcd7d08ccbf7d603bb2f4228b2f8` | Godot 4.7 codec suite: 232 checks; finite-session suite: 74 checks; copied value-owner fixture, not native World application |
| Lead mediator, settings, Stop helpers | `b02e352508013ceb985e11d745f0d300389321bb` | Independent source review; actual Main/native helper execution is separately recorded by the lead |
| C verifier and package custody | `4161eb245907bacecfeca0c0defa15f465e01e6a` | Independent source review and 11 Python verifier/adverse-control tests; synthetic receipts are never hosted execution evidence |

The codec/session tests used official Godot
`4.7.stable.official.5b4e0cb0f`, Linux SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
They instantiate the retained material-admission catalogue, but their session
host is an explicitly copied in-memory fixture. They cannot prove native mutation,
actor ownership, framebuffer behavior, Windows packaging or owner playfeel.

The independent Python command was
`python3 -m unittest test_strata2_qualification test_strata2_campaign_custody -v`
from `tools/ci`. All 11 tests passed. The four reviewed verifier/test files were
confirmed identical to checkpoint `4161eb245` after execution. The tests exercise
receipt validation and rehashed adverse copies; they launch no Godot process.

## Implementation handoff: import and native authority

The PNG codec emits a proposed masked native module. It never stores a World or
mutates material state. Original bytes, decoded pixels, optional mask, exact crop,
integer sampling transform, palette policy and output geometry have distinct
retained identities. A raster's pixels do not infer authoritative depth: the
owner explicitly selects a target plane. Source and output previews use declared
material-ID colours; production rendering is inspected in the actual Workbench.

| Contract | Current bounded behavior |
| --- | --- |
| PNG source | At most 16 MiB; each source side at most 2048; validated PNG structure and IHDR before decode; animated PNG and trailing/truncated payloads refused |
| Raster crop/output | Crop at most 512×512; scale 1–4 by exact integer nearest-neighbour replication after the selected orthogonal transform; result at most 2048 per side and 262,144 cells |
| Alpha | Below the explicit 1–255 threshold means no write in overlay mode, including fully transparent pixels with hidden RGB; replacement mode explicitly proposes Empty writes |
| External mask | Same dimensions as source; nonzero alpha and mean RGB at least 128 select pixels; excluded mask pixels remain no-write even in replacement mode |
| Palette | 1–32 explicit RGB/material/role rows; current native material permissions; Euclidean RGB-byte distance at the selected limit; deterministic earlier-row tie break; unknown pixels explicitly refuse or skip |
| Native interchange | `cybersand-strata-module-v1`; exact uint16 little-endian cells plus separate byte-per-cell write mask; maximum 2 MiB JSON and 262,144 cells; no native-ID resampling |
| Native transforms | Identity, horizontal/vertical reflection and 90/180/270-degree rotation; transparent cells remain no-write; explicit Empty remains distinct |
| #770 donor | Pinned `cybersand-native-module-v1` reader retains the donor's 512-side limit; required unresolved attachment constraints refuse; no attachment or load-bearing solver claim |

`strata_construction_plan.gd` validates a finite plan with at most 16 stages,
32 module dependencies, 262,144 proposed writes and 1,048,576 inspected region
cells. Each stage has an explicit plane, authorized region, expected revision,
earlier dependencies, material scope, protection and exact module identities.
Within-stage overlapping placements refuse; ordered stages may intentionally
depend on an earlier stage's projected material result. Hidden stages never
become completed merely because their output is invisible.

`strata_construction_session.gd` captures real target observations through the
host in at most 64×64 tiles, prepares a zero-write projection, and requires a
fresh opaque approval token. It compares scene, owner, generation, native
revision, authored serial and permission digest. `authored_serial` is explicitly
separate because a saved same-material stamp can change authored history while
native material revision remains unchanged.

After approval, the session calls only the existing owner's authoring path, with
at most 4096 cells and exact expected-before materials per chunk. The lead's Play
adapter uses the existing editor, worker queue, result consumer and history;
decorative calls use the existing exclusive plane owner. A completed chunk is
counted only from a matching original ACK. Stop cancels the unstarted suffix and
retains a truthful acknowledged prefix. There is no cross-plane transaction,
whole-plan rollback, new native mutation engine or decorative actor authority.

Each completed or stopped stage receives a full actual native region readback
and one publication attempt. Publication failure can produce
`committed_stale_pixels`; it cannot erase or relabel an acknowledged material
commit. A malformed or retired mutation ACK instead yields an explicit failed,
unverified outcome, preserves the original receipt, and makes no zero-write or
completed-provenance claim.

## Implementation handoff: history and persistence

Existing native history remains per chunk. Decorative and ordinary Play history
keep their existing 32-entry windows. The preview reports required chunk count
and warns when the finite operation will displace earlier entries. Large plans
are not advertised as one reversible history action.

Before the first native write, the session checks whole-stage Play authoring
through the existing `History.prepare` path, decorative append budgets, record
count and worst-case terminal metadata/diagnostic bytes. This prevents a
predictable retained-record failure after a commit. Each stage's final record
stores original/projected/actual hashes, original identity, acknowledged counts,
terminal status, publication status and bounded source metadata.

The document's versioned authoring extension keeps at most 64 historical records
and 256 KiB in total, with 8192 bytes of metadata per record. Capacity refuses
before writes; records are not silently evicted. These are historical operation
receipts, not assertions that later edits or evolved physical state still equal
the recorded geometry. The lead owns CYSSTRAT v2 integration and strict v1
compatibility; the session does not reinterpret Play Setup, Flatten or evolved
multi-World physical continuation.

The original alpha fixture deliberately retains hidden RGB inside a transparent
central opening and includes alpha 127/128 threshold neighbours. Its 64×48
overlay proposal maps 1315 pixels and leaves 1757 no-write. The independent mask
selects only the left half. The native equivalent stores exact admitted IDs and
the same no-write mask. The generator and manifest label these as original
synthetic import controls; none is presented as a native framebuffer capture.

## Independent cross-review findings and repairs

| Finding | Consequence before repair | Reviewed resolution |
| --- | --- | --- |
| Lead substituted current worker revision into an older Play receipt | An unrelated later revision could be attributed to the original ACK | `_play_finished` retains `receipt.revision`; copied Setup serial is observed synchronously after the ordinary editor's own ACK handling |
| Native revision alone did not fence no-op saved edits | A proposal could survive an authored-history change with identical native cells | Lead compares an exact private copied Setup, covering ordinary and legacy/Art recorders; session requires a separate authored serial |
| Disabling Strata stopped its authoring process driver | A busy preparation or acknowledged prefix could be stranded | Controller processes while enabled **or** authoring is busy; new actual-native helpers check disabled preparation and stopped prefixes |
| Harvest initially accepted only a successful material count | A stale or misdirected copied tile could enter a reusable part | Region, owner, generation, revision and final live fence are checked; per-tile authored-serial symmetry was requested as a small remaining hardening item |
| Focus-preserving UI buttons used uncommitted SpinBox text | A displayed crop/origin could differ from the submitted value | C commits focused numeric text before actions and executes a real-control regression |
| Async harvest and same-status stage updates were not reflected by UI refresh | A completed module could stay absent, and applying-stage counts could remain stale | C refreshes catalogue after completion and tracks stage-content changes; actual-control regressions cover both |
| Failed replacement preview could leave prior approval valid | A new failed source/settings request could accidentally approve an older proposal | Lead retires the old token before validation; C also binds approval to its reviewed settings/preview serial |
| Binary PNGs were omitted from text-source custody | Executed artwork could differ from git-archived package artwork | C adds a raw-byte source asset map, source/loaded start/end checks, package binding and an adverse mutation test with recomputed manifest hashes |
| Native report admission accepted weak/null identity and hash shapes | Incomplete synthetic reports could pass a superficial equality test | C requires real-shaped material SHA-256 values, positive generation/epoch, exact decimal instance strings and nonempty actor identities |
| V2 manifest used the default shortened float serializer | Valid authored settings could change by one float64 ULP after an actual atomic save/read | Independently reproduced and reported to the lead; v2 full-precision serialization and exact numeric canonicalization require repair and re-execution |

The lead's composition settings path separately validates one complete candidate
before changing settings. Its admitted fields are decorative opacity/depth,
parallax/haze and the strict atmosphere configuration. Native geometry, ownership,
revision and history cannot be overwritten through that interface. The reviewed
service requires the current exact settings token, completed native stages,
unchanged original visual settings, same scene, current edit permissions and
unchanged completed-stage revisions. The new native helper checks incorrect-token
and locked-target refusal, unchanged native bytes/history after settings approval,
and exact atmosphere settings. Additional direct stale-visual-setting and
stale-native-revision refusal checks were recommended before final freeze.

The composite proposal uses accepted full-world copied material images; camera
pan does not turn them into viewport-local coordinates. Its bounded native-ID
preview deliberately uses fixed plane order, visibility and opacity. The scope
label correctly excludes production depth, haze, glow and atmosphere. Those
must be judged in actual Workbench output after approval.

## Retained negatives and remaining qualification boundaries

An early real JSON module/composition exercise failed because validated integral
JSON floats remained in an allowed-material array and Godot's array membership
did not match the compiled integer IDs. The compiler now uses the canonical
validated module and normalized allowed IDs, with real JSON round-trip tests.
This was a defect repaired from actual execution, not evidence that earlier
code passed. Earlier typed-key/canonicalization and adversarial metadata/receipt
failures similarly remain represented by explicit regressions.

An independent small document exercise on `b02e35250` also reproduced a real
persistence defect through the retained native atomic file service. Assigning
`presentation.fog_strength = 0.123456789012345 * 3.0` wrote
`0.370370367037035` with the default JSON serializer. Its original float64 bytes
`a23875e925b4d73f` reopened as `a33875e925b4d73f`, and the complete document equality
check failed. Explicit full-precision JSON emitted `0.37037036703703496` and
preserved the complete canonical document. The original failing diagnostic is
retained at `/tmp/strata2-float-original-negative-expanded.log` pending collection
with the final evidence. The recommended repair enables full precision only for
v2, retains v1 serialization semantics, and independently normalizes atmosphere
numeric array types. Approximate float comparisons would weaken this gate.

This review establishes no native decorative dynamics. Decorative geometry
remains static; visual atmosphere is presentation-only and owns no mass,
collision or cross-plane transfer. No change here qualifies physical GPU FPS,
NVIDIA appearance, high-speed route readability, structural load capacity or
the subjective value of a scene. Hosted graphical campaign results, pristine
extracted Windows execution, full payload inspection and physical owner review
must be retained under their own exact source and runtime identities.

**Review conclusion:** the reviewed cross-lane ownership, settings-approval and
custody repairs have defensible contracts. The independently reproduced exact v2
float persistence defect is a blocking repair at this review checkpoint. The
small harvest fence hardening and two direct stale-settings/revision test
suggestions also remain explicit until the final decision packet records their
disposition. Later application changes require exact-source reconciliation;
this document does not certify the final union by ancestry alone.

## Exact-source follow-up: numeric persistence repaired

The lead repaired v2 serialization and specialist B canonicalized atmosphere
speed/strength/direction/colour as float64 values, while region/seed/count/version
remain integers. The v1 writer's precision setting remains unchanged. At exact
integrated application `338be3e6b90cca45c2f9fdc8afe9cbe920dcd56f`, tree
`0292028d2275dc05208dd2a647befda49877ad6c`, A re-executed the same independent
atomic file diagnostic: complete document equality now passes and original/reopen
fog bytes both equal `a23875e925b4d73f`. The original negative above is retained.

The same source freeze also passed the codec's 232 checks, session's 74 checks
and atmosphere's 55 checks using pinned Godot 4.7. The
[integrated execution receipt](integrated-fast-tests-338be3e6b.json) records each
command, original log hash, exact source/tree, selected input hashes and actual
native/Rapier bytes. Both libraries matched their committed LFS pointers and
retained manifests; 105 native and four Rapier source inputs matched their
retained input sets. Application inputs and library bytes were unchanged across
the execution. The original process logs and diagnostic source remain under
`/tmp/strata2-evidence/a-integrated-338be3e6b` for final evidence collection.

The harvest path now also compares every capture receipt's `authored_serial`
against the original expected serial. That defensive review item is closed by
source inspection at this checkpoint. The two additional direct stale-visual
setting and stale-native-revision approval probes remain recommendations until
the lead records their execution. The numeric persistence blocker identified by
this review is resolved; full native, graphical, package and physical owner
acceptance remain separate gates.

## Follow-up: complete protection and exact chunked Play preflight

A independently reviewed the lead's application
`da34aa1088c5540f1f0b491da6185ddf0111ca52`, tree
`e98204eff94a233310c51dd374fd5adee74008bf`. The
[follow-up receipt](protection-and-chunk-preflight-review.json) pins the relevant
source bytes and distinguishes source review, inspection of the lead's original
native execution log, and A's own copied-value regression.

The earlier whole-stage Play preflight could coalesce a larger rectangle across
actual history chunk boundaries. That could understate the eventual saved Setup
cost. The repaired host now uses the same sorted 4096-cell partition as Session
execution and advances a private Setup through the existing `History.prepare`
authority for every chunk and subsequent Play stage. This method duplicates the
input Setup before appending edits; preview never installs the projected Setup.
A new preview and scene retirement clear the cumulative temporary value. Actual
chunk planning still revalidates the existing authority before native writes.

The lead's original source-bound Main/native run completed 404 aggregate checks
in 22.929 seconds, with sampled process maximum RSS of 433004 KiB. A inspected
the original log and process receipt rather than independently repeating that
execution. Its new trial applies a repeated part spanning multiple ordinary Play
chunks, reconstructs the complete material result from original ACKs, compares
actual authored Setup to the exact reviewed Setup, and undoes each committed
chunk back to the original native layout. This is headless native evidence, not
physical GPU frame pacing or hosted graphical acceptance.

The protection review followed the complete request chain. Before approval, the
session captures every cell in each declared target region, including transparent
no-write cells. The ordinary editor includes its existing 4-by-24 source guard
where a source is configured. The native executor checks the canvas boundary,
source guards and actual rigid-body occupancy during both capture and mutation.
Consequently, a protected part of any preview region refuses before any stage
writes. This conservative policy may also refuse a transparent area covered by
a body; it does not bypass the owner's capture rules. The native extent check
has no additional fixed protected outer ring. No decorative actor ownership was
introduced. Later changes after approval can still stop an unstarted suffix;
there is no promise of cross-plane atomicity.

The two previously recommended stale-settings probes are now present in the
actual workflow: changing haze invalidates the original appearance token, and
an intervening native edit followed by Undo still invalidates it because the
authored revision advanced. The service also hashes the exact canonical admitted
atmosphere and visual settings before issuing the separate appearance approval.

A's own public composition constructor had a narrower defect: a dependency list
`[A, A]` could conceal supplied and used parts `[A, B]`. The shipped Library
already rejected duplicate dependency entries. Commit `b67347e71` closes the
public constructor gap by requiring every supplied identity exactly once. A real
JSON two-part positive control and the duplicate-dependency adverse control
reproduce the old failure and pass after repair: 76 copied-value checks under
pinned Godot 4.7. The [original failure](strata2-composition-dependency-original-negative.txt)
and [repaired execution](strata2-composition-dependency-fixed.txt) remain intact.
This is implementation evidence from the author; it is not independent approval
of A's code or qualification of a later combined application.
