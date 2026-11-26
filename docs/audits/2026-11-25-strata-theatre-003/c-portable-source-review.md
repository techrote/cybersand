---
title: Strata 003 Specialist C portable workflow and cross-platform custody review
status: Current
document-kind: evidence
scope: Independent executable integration review through the sequence5 frozen application
canonical-for: []
last-reviewed: 2026-11-25
related-documents: [qualification-registration.md, c-smoke-visual-review.md]
---

# Specialist C portable source review

The portable workflow requires actual full Linux and Windows optical campaigns,
inherited authoring compatibility campaigns, paired predecessor observations,
pristine extracted Windows execution and the exact shipped launcher. Source
inspection found two cross-platform evidence-path/archive hazards. Both received
targeted corrections; neither changes native production sources or rendering.
The final graphics and package gates remain separate from this source review.

## Cross-platform path correction

On Windows, a path beginning `/` can be rooted without a drive and is not
necessarily reported as absolute by `Path.is_absolute()`. Sequence3's Windows
adverse test exposed this in the optical coordinator before graphical execution.
The predecessor reader had the same predicate, so its evidence path admission
was tightened to reject leading `/`, any colon, backslashes and parent traversal
lexically on every host. This also rejects drive-relative names such as
`C:outside.png`. Correction: `bf049baf`. The portable path regression includes
rooted, drive-absolute, drive-relative, UNC and traversal cases.

## Original archive byte identity

The original paired observer reconstructed its project using Git archive and
explicitly skipped unrelated LFS smudging. Git archive also applies working-tree
line-ending conversion. With `core.autocrlf=false`, the remaining `core.eol`
setting changed114original files, including UID metadata, SVG files, notices and
import descriptors. Reproduction against the exact original application commit
`934cc0c0eef70dad528155e9a92eebe25e2757eb` yielded:

| Child Git setting | Original Godot archive SHA256 |
| --- | --- |
| `core.eol=lf` | `6c93cff07bb83402d3246bdcb269aac4a067663f14d384aac0d5c7a9655f5931` |
| `core.eol=crlf` | `4cc99598faa2b86dd40cf97e0b8faa007a06eb0b3443600f7ef1346531fe6807` |

This matters because the Windows packager independently verifies the retained
Linux comparison. A host-dependent archive hash would reject identical logical
source. Correction `2f748c93` appends child-only `core.autocrlf=false` and
`core.eol=lf` overrides while preserving inherited Git configuration and explicit
repository file attributes. It follows the established portable packager's
archive policy. A real archive invocation under an inherited CRLF setting now
reproduces the LF SHA above exactly. Nineteen adversarial predecessor-reader tests
pass. Original application code, material recipes and native/Rapier identities
remain unchanged; the separately hashed observer remains external to that
project.

## Immutable native download fallback

The sequence5 workflow at source
`146cead1ac41147efa993b0bf8b634da08695182` was independently inspected after repeated
Linux LFS batch-service timeouts. Its fallback reads only two fixed Linux runtime
paths and their canonical committed LFS pointer OIDs/sizes. It constructs an
immutable URL from the exact40-character HEAD commit, streams bounded1MiB chunks,
refuses an oversized response, checks final byte count and SHA256, and replaces
the checked-out target only after verification. Temporary partial files are
removed in `finally`. Existing runtime provenance is preserved, and independent
source/runtime custody verification still executes before graphics.

The fallback does not publish or rebuild a runtime. It changes the transport
used to recover the same already-qualified bytes. Three LFS command attempts,
socket timeouts and the overall job watchdog bound the campaign; these are
operational limits, not scene-admission or physical-performance targets.

## Evaluator and command review

The archive binds source files directly to Git blob identities, separately
materializes only the qualified native/Rapier binaries, and checks pinned Godot,
ANGLE and licensed Visual C runtime dependencies. Source/platform/native
receipts are checked for all six prerequisite campaigns. The offline gallery
is reproduced from its original captured bytes and metadata.

The pristine package path deliberately contains spaces. The ordinary
`Open Workbench.cmd` quotes its directory/executable/project paths, sets portable
user-data locations and invokes the included Godot importer before the ordinary
Workbench. It does not require Python, Git, compilation or an external Godot
installation. Qualification runs the actual batch file through `cmd`, captures
both original streams, rejects errors/nonzero exit, and requires an actual
source-bound Workbench admission marker with the expected live native owner.
The test retains the established180-callback launcher bound and180-second
process watchdog. These do not replace the unchanged45-second scene target.

The workflow verifies the package both before and after the extracted full
graphical campaign and actual launcher execution. The final evaluator upload is
gated on these commands succeeding. Failed and incomplete campaign evidence is
retained separately. The source review found no additional blocking path-join,
command-quoting, dependency-staging or watchdog integration issue.

## Pending graphical evidence

Sequence5 Linux successfully reached the actual renderer after the immutable
fallback. Its108-check renderer case retained one exact-Classic wipe failure
under haze and partial parent opacity. Specialist A and the lead own that
rendering correction. The exact oracle remains intact. Earlier sources/runs and
the failed framebuffer evidence must remain distinguishable from the subsequent
qualified candidate. This source review does not turn those failures or still-
running Windows campaigns into passed engineering gates.
