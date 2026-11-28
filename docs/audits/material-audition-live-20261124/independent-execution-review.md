# Independent execution and evaluator review — MAT-AUDITION-LIVE-001

**Disposition: Draft/HOLD.** This record separates source review, native execution,
graphical execution and delivery. Physical owner acceptance and integration into
accepted main are separate gates. No automatic Ready promotion or merge is
recommended by this record.

## Source and evidence authority

The accepted baseline is `00cdb02f103265b6dc5224c68283e9a0c8cb449f`. The Linux-qualified
source2 checkpoint is `3e91942d7d12b87ddae09ec0f0f087f1ba6748e9`, tree
`623c1cf0d33d1add850ea7232811f2d48075b29f`, from
[run 45458665170](https://github.com/techrote/cybersand/actions/runs/45458665170).
The final source3 candidate is `5f73b0ae6980ad1eec993ef2ee9b623f874f33a5`, tree
`043fdb9ff61c0c4fb9d849b39756cdbedf2e7aaa`, from
[run 45465121123](https://github.com/techrote/cybersand/actions/runs/45465121123).
Its native inputs are unchanged from source2; the changes address the Windows
synthetic Git fixture, receipt freshness in the UI, evaluator instructions and
retention of original guard output.

The independent review uses original process receipts, unique completion
markers, source and runtime digests, and actual framebuffer files. A successful
build, cross-compiled Windows executable, headless layout test, or positive
summary line alone is insufficient. The delivery validator checks every
original receipt against its summary and log, rejects script errors even after
a zero process exit, and binds the PNG bytes and native readback to the same
execution.

## Retained material and solver regression execution

Six existing tests ran in a detached source2 worktree using the pinned hosted
Linux candidate and Godot `4.7.stable.official.5b4e0cb0f`. They required no source
changes or engine scheduling changes. Each actual process exited zero and
reported zero failures.

| Existing test | Assertions | Relevant retained behavior |
| --- | ---: | --- |
| `test_workbench_material_baseline` | 102 | Ordinary Workbench material defaults |
| `test_liquid_solver_policy` | 642 | Default readback, validation, refusals and whole-cell admission parity |
| `test_liquid_policy_worker` | 29 | Explicit and omitted worker policy, normalization and instance isolation |
| `test_lcb_inertial_adapter` | 10,192 | Default preservation, mixed workers, radius transactions and CYPS continuation |
| `test_wave_flow` | 4,986 | Native configuration, mass and state identity, contacts, region pause and save refusal |
| `test_workbench_physics_play` | 72 | Actual ordinary Workbench granular/body delivery and four retained physical fixtures |
| **Total** | **16,023** | **Six original successful processes** |

The executed native ELF has SHA-256
`b7afb86202d3a99c4a2c20751819899b362931b78454d1b29c3d7c32888b8f78` and size
5,315,056 bytes. The engine SHA-256 is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`; Rapier is
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
The original candidate manifest SHA-256 is
`3b794749b3758e9d2dda3a0368a78d46a4c8ca05ed3130a6d74b81e9a6661150`.
Source, native library and fixture bytes were checked before and after the
processes. The temporary worktree was subsequently removed to reclaim space;
all original evidence was retained.

The first external reduction incorrectly assumed every `completed` field was
Boolean. The retained policy tests intentionally report numeric refusal and
parity counts, so this reducer refused two otherwise successful processes.
That first summary remains unchanged. A separate typed-schema review checks
the exact expected maps, original log and receipt hashes, zero exits, unique
completion markers and the Workbench readback. It passes all six processes
without rerunning them or changing any original result. Its SHA-256 is
`c4055f5f05f5b4e575d2b3a1fd4d45dd34a0b476f1ff0189f6a28245a605755a`.

The [original evidence directory](independent-execution-evidence/existing-solvers-source2/)
contains the original import and test logs, process receipts, first summary,
separate independent review, original orchestration/review scripts and source2
candidate manifest. `original-file-sha256.json` inventories those exact files.
Only redundant isolated user-data logs were omitted. The scripts retain their
original absolute workspace paths as execution provenance; replay requires
checking out the recorded source and supplying the recorded dependencies.

## Final Linux native and graphical evidence

The final source3 hosted Linux run passed the expanded native suite and
ASan/UBSan at 34,081,851 assertions each. It then passed all nine headless
Lab/current-scene cases with 6,000 assertions, and the separate graphical
current-scene case with 4,002 assertions, an X11 display and seven actual PNGs.
The native candidate retains the required GLIBCXX 3.4.30 / CXXABI 1.3.9 floor.
The independent native specialist checked every original receipt and compared
all 108 native and 1,508 execution inputs with the explicit source3 Git blobs;
that [original review](independent-execution-evidence/linux-source3-independent-review.json)
is retained here. C separately revalidated both original execution manifests,
all process receipts/logs and graphical PNG/native readback through the strict
[evidence validator](independent-execution-evidence/linux-source3-process-review.json),
without repeating the engine runs. The final ELF is byte-identical to source2, establishing
exact native continuity for the six retained solver processes above.

The source3 benchmark compares identical probes against accepted main, with
12 accepted rows and 36 candidate rows. All 24 default/equivalent matched pairs
have exact content and physical hashes, material counts, movement/visit
counts, ticks and observed worker counts. Default median timing differences
range from −0.97% to +1.52% across the four 256²/1024² and requested 1/4-worker
groups. The small 256² fixture actually uses one worker even when four are
requested. Equivalent profiles scan no cells; a modified profile scans 65,536
or 1,048,576 cells once, with median transition times around 0.37ms and 5.8ms.
Three repeats on hosted hardware are advisory timing evidence, not a broad
performance guarantee. The modified arm changes physical work and is not a
measurement of lookup overhead alone.

The independent UI specialist inspected all seven final source3 Linux PNGs:
the current-scene density view, both compact 1000×650 and 1280×720 layouts, and
all four demonstration scenes. The qualified header, truthful activation and
matched Active/Draft values are visible. Fields, ranges and the
configuration-only Revert explanation remain legible. The Brine scene Overview
shows all three reservoirs and covered lateral throats. The header clarifies
that Inspect/isolated movement settings are copied while current-scene
controls read the active Workbench owner. The [original visual-review notes](independent-execution-evidence/ui-artifact-review.md)
are retained with this review.

The original native behavior evidence separately establishes directional
density exchange, viscosity-controlled lateral movement and stored reaction
products/contact-ledger execution. These are native simulation claims. The
layout and framebuffer checks establish presentation and actual rendering;
they do not substitute for consumer readback.

## Adversarial review and corrections

Independent review found and required corrections for several concrete false
positive or delivery risks: summary-only evidence validation; omitted scene,
loader and helper inputs; copied Git index mutation during verification;
untracked duplicate recipe staging; legitimate generated UID sidecars; the
wrong old Lab marker; a stale five-tab diagnostics fixture; and extracting and
running the exact delivered archive and shipped launcher. Original failures
were retained. Production source guards were not weakened to pass them.

Source1's Linux ABI-floor failure was traced to the new adapter's string
assignment importing `GLIBCXX_3.4.31`. Fresh string construction followed by swap
preserves the exact byte copy and validation boundary while retaining the
accepted runtime floor. Native wire tests now cover the 64-byte permitted ASCII
boundary and refusal of empty, overlong, non-ASCII and embedded-NUL identities.

Source2's Windows target job failed before native execution because synthetic
fixtures combined Windows text newlines and global Git conversion with the
production verifier's isolated Git authority. The fixture-only correction
uses the same isolated Git wrapper, explicit LF bytes and repository-local
`core.autocrlf=false`. All 32 adversarial evidence tests pass on Linux even
with hostile global `core.autocrlf=true`; A and B independently reviewed that
production source checks and CRLF materialization coverage remain intact.
This local result does not itself qualify Windows.

The final UI review checks a later-receipt ordering: a transaction can commit,
then the owner can advance revision or replace/retire the World before the
panel receives its copied receipt. Source3 retains that receipt as historical
activation evidence, refreshes current owner authority and adopts its state
only when the session, World, exact successor revision and profile still
match. Otherwise it preserves the newer state and draft, retires old Revert
history and requires deliberate reconciliation. Fake-owner tests cover both
explicit-refresh and no-refresh orderings, failed readback correlation and
restored numeric fields. This is a UI truthfulness correction; the native
transaction lease already prevented wrong-World application.

## Windows extracted evaluator qualification

**Actual target-OS execution passed.** Original Windows evidence from source3
run 45465121123 was downloaded and independently authenticated as artifact
`14955958252`, 7,212,984 bytes, SHA-256
`2a2ac1186bb47720aa711d1960873d35057a26557903fde667242daed8a9f05b`.
The [independent review](independent-execution-evidence/windows-source3/independent-review.json)
checks each original process receipt, log, completion, PNG and native readback.

| Actual Windows execution | Result |
| --- | --- |
| Expanded standalone native consumer EXE | 34,081,851 assertions; zero exit |
| Nine source-checkout Godot cases | 6,014 assertions; all passed |
| The same nine cases after extracting the exact ZIP to a spaced, relocated path | 6,014 assertions; all passed |
| Existing full isolated Materials Lab UI using bundled tools | 226 assertions; all passed |
| Existing compiled candidate/reference World UI using bundled tools | 204 assertions; all passed |
| Actual shipped `Open Workbench.cmd` | Zero exit, nonce-bound native readiness and non-headless framebuffer |

Each nine-case run includes one actual graphical current-scene test with 4,002
assertions and seven PNGs; the other retained fixtures may be headless. The
independent UI specialist inspected all 15 original Windows frames: seven from
the source checkout, seven from the extracted package and the actual launcher
frame. No visual blocker was found. The two compact sizes retain legible
actions/readbacks and scrolling, and all four demonstrations are fully visible.

The separate shipped-launcher proof observes ordinary blank Workbench startup,
`res://main.tscn`, native World `3`, generation `2`, revision `0` and the default
profile. Its native canvas extent is 2048×2048; the actual Windows framebuffer
is 1028×578. It does not claim a played simulation or manual profile edit during
that startup witness. Those interactions belong to the current-scene test and
the separately scoped manual exercise.

The executed Windows native DLL has SHA-256
`55db1fb076d5aa5fbb51ab3c5e0cee0eabdf720fdbd81e30224675942068a6c4` and size
5,870,592 bytes. The expanded AMD64 PE probe has SHA-256
`230354e476779216f7d3e790b86dee3f7aec1e11e2e354e98f304fa2410e4f1b`.
Pinned Godot reports `4.7.stable.official.5b4e0cb0f`; the executed console engine
has SHA-256 `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`.
All 108 native and 1,508 execution inputs were independently compared with
explicit source3 Git blobs before the target execution review.

The exact ZIP extracted and executed is:

- **File:** `CyberSand-Material-Audition-Windows.zip`.
- **Bytes:** `754138787`.
- **SHA-256:** `cb4c67025fb1de64b3f647d70873421cf9be601372fccd2a915791222d94bb96`.
- **Evaluator manifest SHA-256:** `93a3cd71302d7c7202ca8f93d13bb7fae609b461794773c641b6d5b958f09e7c`.
- **Original delivery artifact:** `14956377609` in run `45465121123`; its outer
  artifact ZIP is 747,942,823 bytes with SHA-256
  `a620d6f2762d0e52876eb372d107db2ad96296cfef2e87088375b0fc65ba3b29`.

The Windows smoke and subsequent publication job both verified that exact
archive against its original execution evidence. The four-path runtime
publication [206f14dade78f42b5d8502627bcc19c7093c808e](https://github.com/techrote/cybersand/commit/206f14dade78f42b5d8502627bcc19c7093c808e)
contains only the Linux/Windows native libraries and their provenance records;
the qualified source remains source3. This does not promote or merge the Draft.

The initial execution-review checkpoint recorded a local transfer limitation:
the artifact connector refused the 747,942,823-byte outer ZIP because its limit
is 536,870,912 bytes. That was a transfer-size limitation, not an evaluator test
failure. Its original JSON remains unchanged as an honest earlier checkpoint.
The exact-byte transport and final independent verification below now close
that handoff gate; the tested archive was neither rebuilt nor repacked.

Selected unchanged original Windows logs, receipts, candidate metadata and the
launcher PNG are retained in the
[Windows evidence directory](independent-execution-evidence/windows-source3/).
Its inventory explicitly identifies the fourteen larger PNGs retained in the
authenticated original artifact; their source-run copies also ship inside the
evaluator itself. The selected directory is not described as a complete copy
of that artifact.

## Final complete-archive verification

**The reconstructed complete ZIP passed independent local verification.**
Transport-only run
[45473429772](https://github.com/techrote/cybersand/actions/runs/45473429772)
authenticated the already-tested inner ZIP and split it into contiguous
419,430,400-byte and 334,708,387-byte parts. The workflow has read-only
permissions, no checkout or build, an exact original run/artifact binding,
per-part hashes and a full reconstructed-stream hash/EOF check before upload.
Root verified both outer artifacts, both part hashes/offsets and the complete
archive after reassembly.

C then independently hashed the same complete 754,138,787-byte ZIP to the
recorded `cb4c6702…bb96` identity and streamed every payload entry without a
full extraction. All 22,384 manifested payload file hashes match; the archive
has 23,358 total entries and 1,616,146,588 uncompressed bytes. All 1,508
execution inputs, including the 108 native inputs, match the exact qualified
source. Both shipped launchers, the installed/candidate DLLs, engine, candidate
manifest, dependency inventory and instructions are bound by those checks.

The strict `verify_extracted_execution` validator also passed against the
original Windows receipts and this actual complete ZIP. The
[final machine-readable review](independent-execution-evidence/complete-archive-review.json)
and its [review script](independent-execution-evidence/review_complete_archive.py)
are retained separately from the earlier transfer-pending checkpoint.
No native execution was repeated during archive inspection. A first additional
README phrase assertion was corrected for the file's CRLF line wrapping; its
original bytes and all hash checks were unchanged, and the reviewer-only
correction remains recorded in the new receipt.

The actual archived README is 1,811 bytes with SHA-256
`c9ca0ab02c121a6b3b9b0fd218a867e21135ec4a8dccb6531bddf6d096f37216`.
Independent UI review directly read those archive bytes and found no blocking
instruction, restoration or provenance issue. Its
[final notes](independent-execution-evidence/ui-artifact-review-final.md)
cover all seven final Linux frames, all fifteen original Windows frames and
the exact archived README. Physical owner acceptance remains separate.

## Physical owner and integration limits

The shared-desktop exercise used pinned Godot 4.7 and the earlier local
`b333eab0…` native build with declared GCC14 toolchain drift. It observed ordinary
Workbench Brine Apply from 240 to 0 while playing, with the same native World and revisions 1→2, plus visible
lateral flow changes. Manual Revert and named profile save/load were not
completed. One attempt ended with `Killed`; shared-host resource pressure was
suspected, but causation was not established. A later unrelated mission
repeatedly acquired foreground focus. No further
desktop input was sent after that conflict. Programmatic native/Workbench
tests qualify those operations separately; physical owner acceptance remains
open.

Changing configuration does not reverse consumed cells, moved grains or other
simulation consequences. Named profiles persist the bounded configuration and
runtime identity; scene saves do not silently retain an experimental profile.
Current-scene unsupported fields remain refused. Cross-version complete
simulation reproducibility, PUBPRES/ObjectShard integration and production
default changes are outside this candidate's claim.
