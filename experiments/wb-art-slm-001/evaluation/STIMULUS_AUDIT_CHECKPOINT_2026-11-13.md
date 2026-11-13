# WB-ART-SLM-001 — Independent native-image stimulus redundancy audit

**Date:** 2026-11-13. **Owned branch:** codex/wb-art-slm-evaluation.
**Result:** One repeated two-seed artwork stimulus in the existing 34-card
blinded model-output gallery. First-pass and native-request denominators remain
unchanged. This is measured qualification, not a new model result.

## Executed milestone

Implemented [audit_blind_stimulus.py](audit_blind_stimulus.py) and
[test_audit_blind_stimulus.py](test_audit_blind_stimulus.py).
The standard-library auditor decodes the actual embedded PNG bytes, verifies
96×96 PNG IHDR, host-seed order, unique card IDs, the review token and optionally
the exact source SHA-256. It groups two-image pairs using both actual PNG hashes.
An optional answer-key mode, intended only AFTER blinded responses are frozen,
checks displayed PNG hashes, request-denominator closure, alias IDs and
same-versus-cross-structural-group duplication. The original gallery and
compiler/native/model outputs are unchanged.

Executed locally on Linux with Python 3: six unittest methods passed, Python
source compilation passed, and the frozen real HTML completed a source-hash
checked audit. Controls cover tampered HTML, external/non-PNG images, bad base64,
changed host seed, duplicate IDs, wrong key hashes/tokens, request-denominator
tampering and duplicates across structural groups. Exact Git blob identities of
both published source files matched locally tested files. No hosted CI,
Windows graphical execution, native rerun or human review is claimed.

## Frozen native stimulus results

The audited standalone HTML SHA-256 was
5f554c67c928d6f940126d07c529df89694a42d6cdeb7a65c7b9c4413f354877,
identical to the previously published historical Linux headless native-material
[blind review checkpoint](BLIND_REVIEW_CHECKPOINT_2026-11-13.md).

| Measurement | Result |
| --- | ---: |
| Original model requests (unchanged) | 36 |
| Invalid original completions (unchanged) | 2 |
| Native-admitted requests (unchanged) | 34 |
| Displayed seed-pair cards | 34 |
| Displayed PNGs | 68 |
| Distinct PNG byte hashes | **66** |
| Distinct exact two-seed image pairs | **33** |
| Duplicated card pair | **q004 and q007** |
| Extra exposure of the same two-seed pattern | **1** |

Separate sealed answer-key metadata confirms that q004 and q007
are two different original development prediction IDs belonging to the
**same structural group**. Theme names, original prediction IDs and group IDs
are deliberately withheld from this human-facing note until the rater freezes
a blind response; opening the original answer key would reveal them. Their
paired native PNG hashes match exactly at seeds 17 and 73. Other two-seed
pairs differ in exact PNG bytes. This is a concrete visual-diversity limitation;
it is neither a material-write failure nor a measured aesthetic score. The committed [audit JSON](stimulus_redundancy_audit.json) deliberately
states key_checked=false: it is the independently executed HTML-only check.
The optional full answer-key-to-PNG binding was tested synthetically but
was **not run against the original full key**; separate key metadata inspection
must not be represented as that execution.

The baseline retains 36 original requests, 34 accepted programs and 68/68
native seed replays; the unique-stimulus count of 33 is **not** a replacement
for request-level first-pass accounting. When scoring a review, retain both
request-weighted and structural-group-weighted measures; do not count duplicate
cards or seeds as independent structural templates. The existing 34-card
blind packet was not changed. A separately versioned collapsed-stimulus review
could avoid a second identical visual exposure while preserving original
request-ID mappings.

## Upstream status and scope

At refresh, main remained 63f8b1ba6559906fe85f3ad0269aa296e4141d67,
#564 Draft 6319ab1d94d85d01c9cdb44d973a92d224bfa9aa,
#565 Draft d66499ec3409fb657875fca7dbd0f234cf28ca49.
The last #565 Windows MATERIAL_LAB_UI campaign failed; no source-compatible
Windows acceptance runtime was consumed. This role did not alter combined
Draft #567, model weights, training, corpus, compiler, native harness, production
source, physics/material law or unrelated schedules.

The frozen step-400 result remains development 22/24 strict, one-word 12/12
syntax, 11/12 primary motifs and 11/12 theme labels; separate ribs/veins
errors persist. First-pass schema and native request yield remain 34/36
(94.4%), below 95%/98% targets. Constrained 99%, visual-recognition 80%
and zero host-invariant-violation targets are unchanged; no new visual
recognition score or current-main/Windows qualification is claimed.

**GO:** source-bound, offline PNG-stimulus redundancy audit only.
**HOLD:** model release and native/Windows/visual acceptance.
**Next:** Integrator may import the evaluation-owned changes; independently
qualify a compatible #565 successor when available and score a frozen blind
review without using final assessment for repair.
