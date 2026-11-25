---
title: Final collaborative Art native evidence review
status: Planned
document-kind: audit
scope: Independent original-byte replay and cross-source geometry comparison for frozen Linux and Windows campaigns
last-reviewed: 2026-11-25
---

# Final native evidence review

**All nine original native scenes retain identical material geometry in the
frozen successor's Linux and Windows campaigns.** Specialist B independently
replayed the four original headless/displayed native datasets and checked their
source chains, complete stage planes, translated direct controls and artifact
identities. This is a review of actual recorded native work, not another
application run or a model-creativity experiment.

The qualified application source is bcc92927ce3894a16d5544923cfbf7b1d0339fda,
tree 517164084860a19f18b36cb94f77597eb3220578, in
[campaign 45546845554](https://github.com/techrote/cybersand/actions/runs/45546845554).
The original comparison source is
2743f89a0df6f6afcf7484e859c10790d521e74b. The application was not modified
during this review.

## Immutable originals and independent method

The reviewer independently refreshed GitHub's artifact metadata and recomputed
both downloaded archive SHA-256 values before consuming the extracted originals:

| Original campaign artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| [Linux 14992946063](https://github.com/techrote/cybersand/actions/runs/45546845554/artifacts/14992946063) | 17,148,660 | 7ff9971f911a1b417582f05a929fdda021b2d536a78eb6434e002c172676d59a |
| [Windows 14993247449](https://github.com/techrote/cybersand/actions/runs/45546845554/artifacts/14993247449) | 12,820,321 | 45df2fecb95f21fe769f15202d15411156b658d7670e249f76e4b6877f9b3f47 |

The unchanged independently authored
[native original-byte verifier](../../../tools/ci/verify_art_creative_native_evidence.py)
has SHA-256
64292c1a48babae89b51e0dfa2c99792c29e9f2f813962294da8fc6d8c4536a9.
B executed it directly on the recovered reviewer executor for each final
campaign. Earlier 2743 raw verification was lead-brokered; these four final
executions were performed by B. Neither method imports the Art rasterizer or
fixture generator.

The verifier decodes native material diagnostic PNG bytes, checks their PNG
CRCs and recorded int32 plane hashes, then applies every exact native
before/after tuple in order. It checks native backend and completion status,
source/revision chains, all receipt counters, source 0/58 limits, every predicted
stage boundary, final planes and translated direct controls. Rendered
framebuffers are checksum-bound but never interpreted as material authority.
Editable Setup files are checksum-bound; their actual saved-start reopen
assertions belong to the recorded native process.

## Four complete native campaigns

| Native execution | Native terminal checks | Staged/direct chunks | Original files replay-verified | Exact readback rows |
| --- | ---: | ---: | ---: | ---: |
| Linux displayed | 757/0 | 61 / 56 | 73 | 377,234 |
| Linux headless | 739/0 | 61 / 56 | 55 | 377,234 |
| Windows displayed | 764/0 | 64 / 57 | 73 | 377,234 |
| Windows headless | 739/0 | 61 / 56 | 55 | 377,234 |

Every row contains the same nine distinct deterministic scenes, 25 finite
native stages and nine matched direct controls. Each arm acknowledges
184,396 material transitions and 188,617 checked cells. Transitions may revisit
an address across stages; they are not unique final occupied cells.

All four raw replays passed. Together they inspect 1,508,936 original cell rows
and 256 original per-case files. These are repeated platform observations of
nine recipes, not 36 different creative scenarios. The maximum observed native
receipt contains 4,096 checked cells. All material planes and actual counters
match; no receipt counter is inferred from intended geometry.

Full original reviewer outputs are retained:

- [Linux displayed](final-native-bcc/final-bcc-displayed-raw-review.json):
  a10ad008cb35a7f665d5debc424d576f23b837f0b4da069d1392cb90cb4dbe5b.
- [Linux headless](final-native-bcc/final-bcc-headless-raw-review.json):
  3ac123fe00fdc10057243195e8a4219a01d80f34fcbc0fa413ea249e57760f09.
- [Windows displayed](final-native-bcc/final-bcc-windows-displayed-raw-review.json):
  1dfec5a83f522305352826c788b2321362daa3ac03db8dd940f37f1bb20f2623.
- [Windows headless](final-native-bcc/final-bcc-windows-headless-raw-review.json):
  f97ad25af979cc9e166d0041ce1ef3c2e2bab19ca0ac26b6ac8f1b4cb10248d4.

## Original geometry and dynamic assertion denominators

A separate independently authored
[comparison method](final-native-bcc/reconcile_final_native.py) compares each
final source's proposals, regions, source endpoints, actual changed/checked
totals, protection/clearance outcomes, exact before/after hashes and all 25
per-stage predictions against the preserved 2743 summary. It also compares the
nine direct controls and checks each actual receipt's 4,096-cell bound.

Both platform comparisons passed **512 checks each**:

- [Linux comparison](final-native-bcc/final-bcc-linux-comparison.json).
- [Windows comparison](final-native-bcc/final-bcc-windows-comparison.json).

The native test source itself is byte-identical between 2743 and bcc, Git blob
33ee8dbdfead5c87f50103b2ccc4ed056132c3dd, SHA-256
88b83bc86b320b10a844a957eaa078b3bea94382b30f1104ca8ba38358a74814.
No qualification gate was removed.

The original displayed campaign's 771 assertions included two assertions for
each of 66 staged chunks and one for each of 60 direct chunks. Chunk grouping
varies with bounded execution, so the final Linux 61/56 grouping produces 14
fewer receipt assertions; Windows 64/57 produces seven fewer. Headless runs
also omit 18 screenshot assertions. Each saved scene summary is constructed
one assertion before the terminal record because writing that summary adds
the final file-open assertion. The comparison verifies these denominators
against every individual original check line.

Context source/provenance disclosures intentionally evolved after 2743.
This review compares geometry and native authority; it does not falsely require
old and new model-visible context digests to be identical. The separately
controlled packed-scan comparison owns the exact-byte Context equality claim.

## Runtime and scope

Both platform records pin Godot 4.7.stable.official.5b4e0cb0f.
The Linux/native/Rapier hashes remain the same as the preserved 2743 runtime.
Windows records identify:

- Godot:
  d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c.
- CyberSand native:
  668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e.
- Rapier:
  b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7.

Complete runtime/source identities and reviewer commands are in
[execution.json](final-native-bcc/execution.json). Binary loading and pristine
portable launcher qualification remain separately owned package checks.

B authored the Context/compiler/preview and creative test modules. This is
therefore an independent original-data replay algorithm and cross-lane source
review, not a claim that a different person independently implemented those
modules. Specialist C's separate read-only review of the packed scan is
recorded in [the Context investigation](CONTEXT-SCAN-PERFORMANCE.md).

The [native/creative synthesis](NATIVE-CREATIVE-EVIDENCE-SYNTHESIS.md) retains
the 24-brief denominator, seven refused/stale outcomes, actual single scripted
Develop exchange and the fixed-proposal ablation limitation. No genuine model
authored these nine recipes. Static Empty passages do not prove actor
traversal; material apparatus does not prove machinery function or structural
physics. Timing across these different hosts is not a controlled speed
comparison.

Draft/HOLD remains in force. The earlier incomplete native attempt, temporary
environment loss, retained Apply failures and owner-pending physical
Windows/NVIDIA absent-listener acceptance remain visible.
