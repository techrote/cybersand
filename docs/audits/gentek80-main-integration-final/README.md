# GENTEK-80-MAIN-INTEGRATION-001 — final merge handoff

**MERGE CANDIDATE ACCEPTED** — implementation and integration gates passed; awaiting explicit owner merge approval. [PR #684](https://github.com/techrote/cybersand/pull/684) remains **Draft/HOLD**, unmerged, with auto-merge disabled.

## Exact source

| Identity | Revision |
| --- | --- |
| Starting qualified PR head | `bf1bd8c8e6f189b36a3cb0f582185e5d529297d0` |
| Starting and final accepted `main` | `7b03aa437561ec63e31fd09531171360ab60eeb4` |
| Final candidate on the existing PR branch | `87148d66e816f3fd4033e8227a7d310652e2812a` |
| Final candidate tree | `a24d0ed7a1f18d02716dec3a8cee378d18b38c63` |
| Retained native source/build | `82da41a945b1d98e0267a2a20b56ec66d83f71f6` |

Accepted main contains #681's lazy Art/conversation continuation and #680's large-landscape host-claim admission. The final candidate includes that exact main as an ancestor. The [live readback](final-live-readback.json) records the source, Draft state, clean mergeability and successful exact-candidate Documentation check. No mandatory status-check contexts or repository rulesets were configured in that readback.

## Reconciliation and preservation

The accepted branches merged cleanly. **No new production or native modifications were required.** All 33 non-overlapping accepted-main files are preserved exactly. The three shared documentation paths—`docs/README.md`, `docs/reference/retrieval-index.md`, and `docs/reference/status-and-roadmap.md`—retain the accepted-main content through the ordinary merge.

Only three supplemental paths differ from that mechanical union:

| Path | Attribution |
| --- | --- |
| `godot/tools/qualify_gentek80_main_integration.gd` | Bounded actual-Workbench qualification apparatus; kept outside ordinary test discovery. |
| `tools/architecture/gentek80_main_integration.py` | Source/runtime custody, isolated author/reopen processes, archive and screenshot receipts. |
| `docs/operations/gentek80-evaluation.md` | 26 lines describing the combined qualification and its command. |

The catalogue remains **80 Genteks: 72 CLASSIC + eight showcases; 93 unique UI presets including all 13 existing presets; 91 unique native module/version identities**. All six reviewed repairs—Ring Pier, Tripod Frame, Cascade Terrace, Scalloped Vault, Suspended Deck and Buttress Wall—match the qualified candidate. The other 66 CLASSIC implementations retain their authoritative bodies; all eight showcases and catalogue registrations are preserved. See the [independent source comparison](independent-merge-source-review.json).

## Actual qualification

All application runs use **Godot `4.7.stable.official.5b4e0cb0f`** and the retained native engine. Graphical execution used Linux X11/Mesa and actual Windows ANGLE. Current execution receipts bind **1,029 committed source inputs**; the pristine Windows replay additionally verifies **781 packaged project files**.

| Gate | Result and original evidence |
| --- | --- |
| Documentation, dependency/runtime provenance, historical-record integrity and retrieval | **PASS** — [exact candidate run 44770757479](https://github.com/techrote/cybersand/actions/runs/44770757479). |
| Existing catalogue/native/UI/install/save/paint/Art/Water controls | **PASS after the bounded Linux invocation correction below**. Includes 3,111 project-contract and 2,730 native-generator assertions per platform, UI/filter controls, generated installation, authored Save/Load, Art lifetime/integrity and 618 Water Lab assertions. [Original execution](https://github.com/techrote/cybersand/actions/runs/44770730491), [Linux continuation](https://github.com/techrote/cybersand/actions/runs/44773594434). |
| Combined ordinary Workbench on Linux and Windows | **PASS** — all six repaired CLASSIC styles plus Cathedral Megaframe selected, generated, previewed, installed, painted, saved and reopened in independent processes. Each graphical pair completed 290 author and 194 reopen terminal assertions, zero failures, with 35 original PNGs. |
| Native material and actor coexistence | **PASS** — real keyboard-input Midge movement while native and Rapier ticks advance; 64 Sand cells conserved with 128 changed occupancy cells. Exact authored material/recipe/setup/actor/edit identities survive reopening. Evolved post-play hashes are observations, not a coupled-determinism claim. |
| Lazy Art and archive lifetime | **PASS** — unopened Art remains deferred; the seeded 4,194,611-byte archive retains its files, bytes, sizes and modification times throughout generator/start operations and reopening. |
| Real original landscape and authored starts | **PASS** — Graftloom Slipway R6, **2048×1024**, **13,839 source rectangles**, all **2,097,152 material cells** independently compared; native rectangle capacity **32,768**. Two authored edits compile to **13,844** rectangles. Admission and fresh-process reopening remain valid after the Gentek sequence. |
| Updated Windows ZIP | **PASS** — [delivery run 44775033610](https://github.com/techrote/cybersand/actions/runs/44775033610) assembled the source-matched package, replayed its pristine extracted project graphically in independent author/reopen processes, rechecked every original payload file, then published it. |

### Preserved failed attempts and their disposition

The original matrix run `44770730491` remains recorded as failed. Its Linux auxiliary runner invoked the native-paint cancellation fixture graphically with default worker settings; that invocation failed one of 109 assertions. The registered headless one-worker and four-worker invocations each passed all 109 unchanged assertions. Continuation `44773594434` verified and reused the ten completed original cases and retained all 193 original evidence files unchanged. The precise timing of the original cancellation race was not measured.

The original Windows runtime tests all passed, followed by an auxiliary packaging comparison failure. The frozen runner had read UTF-8 phase JSON through Windows' default CP1252 decoding. The delivery helper requires complete-object equality through the original decoder, records the raw file hash and matched decoder, and preserves the original files. The new pristine replay uses UTF-8 and its phase/aggregate objects match exactly. These corrections changed auxiliary orchestration only; candidate `87148d66` stayed fixed.

## Runtime identities

Both native manifests remain unchanged records of the actual `82da41a9` build. All **103 current native inputs** match them completely; native code and dependency/build pins require no rebuild. New application execution and package identities are recorded separately from the broader historical build ledger, whose eight changed script/test/documentation entries are explicitly identified in the source review.

| Runtime | SHA-256 |
| --- | --- |
| CyberSand Linux, 5,183,960 bytes | `5195149bb4ee0b826d258f46627397d4a3e79d0d22cd3072ca0518aa75ebd878` |
| CyberSand Windows, 5,747,200 bytes | `2b7a1fbb8410270498e5c0ce8f9384a598c4467397e4ca1bda0111d6c5985447` |
| Rapier Linux | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Rapier Windows | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |

Rapier remains the pinned v0.35.2 addon at `172c66f5a88bf1164c2b8cf2d775ed889edefd75`, with its existing locked cooperative-BVH patch and native authority. Windows console Godot is SHA-256 `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`.

## Windows owner evaluation

[Download the published Windows owner artifact](https://github.com/techrote/cybersand/actions/runs/44775033610/artifacts/14649053225). It contains **CyberSand-Gentek80-Main-Windows-87148d66e816.zip** and its checksum file.

- ZIP size: **107,525,777 bytes**.
- Actual ZIP SHA-256: `ab3f8887933380ecc45f95fddd6dac9c8a42fd690bc83a77a8707805de9c8c9a`.
- All **1,114 payload inventory hashes** were independently verified; the archive has 1,115 files including the inventory itself.
- Includes the ordinary **Open Workbench.cmd** launcher, the current selection/test guide, seven generated starts, original Graftloom, retained manifests, qualification receipts and 35 original Windows screenshots.

Extract the complete ZIP, then run **Open Workbench.cmd**. Use **New from generator → Architectural Generator → Find style**, enable one style at 100%, generate its preview and install it. For the supplied Cathedral with Midge, enter `gentek-main-cathedral-megaframe` and choose **Load start**, then confirm installation. Use `my-canvas` or `graftloom-slipway` for the original large landscape. Save a named authored start and reopen it in a fresh application process using the included Windows procedure.

The seven supplied save files are exactly the original Windows-author/fresh-reopen bytes. The pristine ZIP replay executes a new isolated author/reopen pair against the packaged project/runtime. Hosted graphical qualification establishes those automated paths; physical-owner GPU behaviour and subjective gameplay feel remain outside this evidence.

## Independent verdict and owner action

The [independent final review](gentek80-main-independent-final-review.md) is **ACCEPT, zero outstanding P1/P2 findings**, based on the exact combined source, preserved catalogue, actual platform receipts, original screenshots and downloaded ZIP. Supporting independent receipts are retained beside this report.

There are **no remaining implementation or integration blockers**. The remaining owner action is explicit approval to leave Draft/HOLD and merge PR #684. No merge, Ready promotion or auto-merge action was performed.

[Seven inspected current Workbench screenshots](SCREENSHOTS.md) show the requested integration views. The [existing complete 80-Gentek gallery](https://github.com/techrote/cybersand/blob/fea465b014757fce9000be6b30e368d5ab187c43/docs/images/gentek80-integration/README.md) is reused under its original source identity; it was not regenerated or relabelled as new execution.
