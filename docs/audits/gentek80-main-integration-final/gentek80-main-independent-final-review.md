# Independent final review — GENTEK-80-MAIN-INTEGRATION-001

**MERGE CANDIDATE ACCEPTED. Zero outstanding P1/P2 findings.** Implementation and integration gates passed for the exact candidate below. PR #684 remains **Draft/HOLD, open and unmerged**, awaiting explicit owner merge approval. This review authorizes no merge, Ready promotion or auto-merge action.

## Exact reviewed source

| Identity | SHA |
| --- | --- |
| Starting and accepted `main`, containing #681 and #680 | `7b03aa437561ec63e31fd09531171360ab60eeb4` |
| Previously qualified Gentek candidate | `bf1bd8c8e6f189b36a3cb0f582185e5d529297d0` |
| Final PR #684 candidate | `87148d66e816f3fd4033e8227a7d310652e2812a` |
| Final candidate tree | `a24d0ed7a1f18d02716dec3a8cee378d18b38c63` |
| Retained native source/build | `82da41a945b1d98e0267a2a20b56ec66d83f71f6` |

I independently inspected the combined Git tree, qualification code, original hosted process receipts and logs, rendered screenshots, and the actual delivered ZIP. The tested source has no tracked or relevant input delta. Direct GitHub readback also confirmed PR #684 HEAD and `main` still equal the identities above, with Draft true, mergeable/clean and auto-merge null. The repository showed no enforced required-check context. The exact-candidate Documentation check passed.

## Preservation and reconciliation

The common-base comparison covered 860 Gentek-changed paths and 36 accepted-main-changed paths. The only overlapping files were `docs/README.md`, `docs/reference/retrieval-index.md` and `docs/reference/status-and-roadmap.md`; their combined content retains accepted-main material and the Gentek additions. All nonoverlapping main changes are preserved exactly. The only deliberate difference from the Gentek side is the 26-line integration guide addition. There is no integration-specific production repair or native change.

Beyond the mechanical merge, the final tree adds only `godot/tools/qualify_gentek80_main_integration.gd`, `tools/architecture/gentek80_main_integration.py`, and that guide section. The dedicated seeded apparatus is outside ordinary test discovery; the unchanged default scanner discovers 328 routine cases.

The source inventory contains **93 unique UI presets: 13 existing presets plus 72 CLASSIC and eight advanced Genteks**, and **91 unique native module/version identities**. All CLASSIC implementations match the qualified Gentek candidate. Against the accepted CLASSIC authority, 66 class bodies remain unchanged and exactly the six reviewed repairs remain: Suspended Deck, Scalloped Vault, Buttress Wall, Tripod Frame, Ring Pier and Cascade Terrace. Rib Vault retains its accepted repaired implementation. All eight showcases and the existing generator contract are preserved. The complete 80-Gentek gallery retains its original source identity. See the [independent source comparison](independent-merge-source-review.json).

## Native and application custody

All **103 native inputs**, dependency pins, native binaries and provenance manifests remain identical to the qualified Gentek source. No rebuild was needed. The historical 951-entry build-input inventory has eight changed nonnative application/test/documentation paths: four accepted-main Workbench/Art scripts, three accepted-main tests and the integration guide. Those historical manifests are preserved as build custody. Fresh execution receipts bind the combined application to **1,029 committed source inputs**, its actual loaded project, engine and runtime bytes.

| Runtime | SHA-256 |
| --- | --- |
| Linux CyberSand | `5195149bb4ee0b826d258f46627397d4a3e79d0d22cd3072ca0518aa75ebd878` |
| Windows CyberSand | `2b7a1fbb8410270498e5c0ce8f9384a598c4467397e4ca1bda0111d6c5985447` |
| Linux Rapier | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Windows Rapier | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |

Actual execution used pinned **Godot `4.7.stable.official.5b4e0cb0f`**. Linux ran native ELF binaries; hosted Windows ran its retained PE/DLL binaries and actual graphical ANGLE renderer. Linux graphical evidence used X11 with software rendering. Local headless evidence is supplemental and is not presented as local graphical execution.

## Execution evidence inspected

| Gate | Observed result |
| --- | --- |
| Architectural project/native/UI suites | 3,111 / 2,730 / 61 checks, zero failures on Linux and Windows; ordinary author/reopen and multistyle phases pass |
| Installed preview and generated-start paint | Installed author/reopen 17/18; generated paint author/reopen 39/19; pass |
| Accepted Art behavior and edit ownership | Lazy 21, traffic integrity 148, panel safety 38, native batch 147, edit ordering 144; pass |
| Registered Linux native paint | Headless workers 1 and 4 each execute all 109 assertions, zero failures, identical material witnesses |
| Existing materials and Water Lab | Material baseline 102 and Water Lab 618 checks; pass |
| Host claims | Capacity 95 and actual native admission 110 assertions; pass, including the real Graftloom fixture |
| New graphical combined Workbench | Linux and Windows each pass seven-style author/fresh-reopen phases: terminal totals 290/194, zero failures |
| Pristine Windows package project | A separate graphical author/fresh-reopen pair passes 290/194, zero failures; original payload hashes remain valid |

The supplemental apparatus exercises all six repairs and Cathedral Megaframe through the ordinary form, native preview, installation, paint, save and independent-process reopening. The existing UI suite checks searchable selection, stable identities, no-match selection retention and restoration of all 93 choices.

The original **2048×1024 Graftloom Slipway R6 has 13,839 source rectangles**. The actual native world is compared over every material cell with independent authored-stamp reconstruction, and the complete canonical definition and positive native receipt remain authoritative. Two saved paint edits preserve all original rectangles; recompilation produces 13,844 native runs, within the unchanged 32,768 capacity. It loads before and after Gentek use and again in a fresh process.

Every generated authored start restores complete setup, ordered edits, actors and actual native stored-material hashes. Cathedral has a real Midge driven by ordinary `InputEventKey` W+D publication, with nonzero thrust/displacement and at least 30 native and Rapier ticks. All graphical pairs preserve 64 Sand cells while changing 128 Sand-occupancy cells. Hidden Art remains deferred and the isolated 4,194,611-byte existing traffic fixture retains identical file inventory, bytes, size and mtime.

I verified 35 PNG hashes for each original Linux, original Windows and pristine-package run. I visually inspected 12 original Windows images, four Linux images and four pristine-package images, including the real expanded catalogue, all six repaired CLASSIC structures, intact Cathedral preview, installed architecture, Midge and the large landscape. These are actual Workbench framebuffer captures. The actor fixture deliberately includes an authored clear area and Sand patch; that edited view is distinct from the intact generated preview.

## Preserved failures and bounded corrections

The [original combined run 44770730491](https://github.com/techrote/cybersand/actions/runs/44770730491), orchestration `561a0ac544027b8fa85b3e24ed7b903ab9732719`, remains a failed run. Two auxiliary qualification issues were resolved without candidate production changes:

- The Linux runner forced the native paint test into graphical/default-worker mode instead of its registered headless workers-1/4 invocation. One of 109 assertions failed: **“Stop reports truthful partial prefix.”** A secondary unanchored parser matched both its error line and terminal JSON. The original failure, raw process receipt and log remain intact. Source inspection shows the poll can observe completion before Stop; the actual timing cause was not recorded and remains an inference. The continuation retains all 109 assertions, restores the registered invocations and anchors JSON parsing. Both arms pass. All 193 original artifact files are byte-identical in the continuation; ten successful prior cases were reused.
- Windows execution suites, graphical integration and real-map qualification passed, but the first packaging attempt rejected a phase-object comparison. The frozen Python runner had decoded UTF-8 phase JSON with Windows' default CP1252, changing 14 human-readable status strings in its aggregate. The delivery helper proves equality of the **entire original phase object** through the exact original decoder, records raw file hashes and leaves originals untouched. All numeric, identity, hash and runtime fields agree. The new package replay uses Python UTF-8 mode and its phase/aggregate objects match directly.

Other review findings were resolved in qualification apparatus: strict edit-order leak-guard naming; actual Sand movement/conservation evidence; execution-helper custody; an actual expanded-dropdown capture; and moving the seeded harness out of routine test discovery. No production assertions were weakened.

Successful completion is recorded separately in [Linux continuation 44773594434](https://github.com/techrote/cybersand/actions/runs/44773594434), orchestration `4e55839d21677c8f3a2182c6293437c590913c71`, and [Windows delivery 44775033610](https://github.com/techrote/cybersand/actions/runs/44775033610), orchestration `cdc78e52b2007906737b19c169cb41ad77145e28`. [Documentation 44770757479](https://github.com/techrote/cybersand/actions/runs/44770757479) passed directly at candidate `87148d66`.

## Actual Windows delivery

[Owner ZIP artifact](https://github.com/techrote/cybersand/actions/runs/44775033610/artifacts/14649053225): **`CyberSand-Gentek80-Main-Windows-87148d66e816.zip`** — **107,525,777 bytes**, SHA-256:

`ab3f8887933380ecc45f95fddd6dac9c8a42fd690bc83a77a8707805de9c8c9a`

I checked the actual inner ZIP and extraction: **1,115 files, all 1,114 inventoried payload hashes verified**, plus the inventory manifest itself. The ordinary `Open Workbench.cmd` launches `--workbench`; it is not a Gentek laboratory launcher. The package includes the selection/installation guide and Windows procedure, original Graftloom, seven Windows-generated sample starts, original graphical evidence, unchanged native manifests and the historical gallery link.

The supplied seven save files exactly match the bytes qualified by the original Windows fresh-process reopen. Separately, the pristine-extracted project and packaged engine execute a new isolated graphical author/reopen pair. The latter verifies packaged project/runtime operation; it is not described as a human launcher click or direct loading of all preseeded sample files. See the [delivery/ZIP review](independent-windows-delivery-review.json), [original Windows review](independent-windows-original-review.json) and [Linux continuation review](independent-linux-continuation-review.json).

## Limits and owner action

Automated input exercises the ordinary keyboard publisher with only the window-focus predicate supplied by the apparatus. Hosted software rendering does not establish human gameplay feel or behavior on an owner's physical GPU. Saved starts preserve authored state; no deterministic replay of evolved coupled simulation is claimed. The original failed paint invocation and historical Windows diagnostic encoding remain disclosed above. They are not relabelled as successful runs or evidence of a measured timing cause.

**No outstanding P1/P2 production or integration defect remains.** No further source change is requested. The current owner action is explicit approval of the concrete candidate and evaluation package. Preserve Draft/HOLD until that approval; this review performs no merge, Ready promotion or auto-merge enablement.
