---
title: Current validation and retained M11 integrity
status: Current
document-kind: guide
scope: Separate current source and runtime acceptance from immutable historical M11 evidence
canonical-for: [current-validation-gates, m11-retention-policy]
last-reviewed: 2026-09-08
related-documents: [local-build-and-validation.md, github-development-and-release.md, ../reference/validation-evidence.md]
---

# Current validation and retained M11 integrity

## Why did the old consistency check report hash mismatches?

The old checker compared today's source and binaries with the M11 hash table.
Later implementation changes necessarily differ. An unresolved LFS pointer also
differs from a materialized library. Neither comparison establishes corruption of
the historical record. **Rejected:** editing M11 hashes or suppressing integrity
errors to declare current success.

**Current:** [check_m11_consistency.py](../../tools/ci/check_m11_consistency.py)
verifies all 28 original [BUILD_ID](../BUILD_ID.md) source hashes against Git blobs
at audited commit `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`. It additionally
verifies 18 retained records, including the original checker, against the
[retention manifest](../audits/m11-retention.json). Text uses canonical Git LF
bytes across Windows/Linux checkouts. Missing historical Git objects fail the
check; fetch complete history. The historical tag and original hashes stay intact.

`--compare-working-tree` explicitly requests the strict legacy comparison. It
still exits nonzero when current files differ; its output is diagnostic drift,
not the current release gate. The [dated reconciliation](../audits/2026-09-08-validation-reconciliation.md)
preserves the previous failures and explains their resolution.

## What validates current source and runtime identity?

**Current:** [check_repository.py](../../tools/ci/check_repository.py) validates
canonical documentation, approved dependency versions, required notices/bootstrap
files, committed LFS identities and the published Windows/Linux runtime source inputs.
[runtime-provenance.json](../../godot/addons/cybersand_native/runtime-provenance.json)
and [Linux provenance](../../godot/addons/cybersand_native/runtime-provenance.linux.json)
bind each library's SHA-256/size to canonical source input hashes and dated execution
evidence. Changing an input requires a rebuilt, tested and explicitly recorded
artifact. Identity alone never substitutes for execution.

A local source checkout may validate LFS pointer identity while reporting missing
payloads. CI and release hashing require `--require-materialized`; every required
runtime object must match its committed SHA-256 and size. Vendor runtime libraries retain their dependency provenance. Other platforms
are not certified by the Windows/Linux manifests or a successful LFS check.

```text
python tools/ci/check_docs.py
python tools/ci/check_repository.py
python tools/ci/check_m11_consistency.py
python -m unittest discover -s tools/ci -p test_validation_contracts.py
python tools/docs/retrieval_eval.py --output <local-frozen.json>
python tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output <local-challenges.json>
git diff --check
```

The eight checker regressions deliberately corrupt records, historical inputs,
current source and binaries, and distinguish pointer identity from materialization.
They also verify that legitimate current evolution does not invalidate history.

## Which build and CI gates use each policy?

**Current:** native builders retain compiler, SCons and exact godot-cpp source
checks. M11 archive/output byte equality requires the explicit
`CYBERSAND_VERIFY_M11_OUTPUT=1` flag; an explicit historical check is never bypassed
by the existing toolchain-drift override. Normal current outputs are identified
and tested independently. M11 output constants and dependency locks are retained.
The existing local override can still bypass compiler/dirty-source checks; inspect
and record those inputs. It is not a reproducible-release attestation.

Documentation CI checks current identity, retained M11 integrity, checker failure
contracts and both retrieval sets. It checks out the pinned companion workspace
because canonical links cross the two repositories. Release hashing separates
current runtime/provenance manifests from historical records.

GDExtension CI builds Linux and Windows from current source. Its Linux job installs
the freshly built extension, checks the ABI floor, then runs every `test_*.gd`,
two profiles, project import and scene smoke using exact Godot 4.7. It retains
source/binary identity and logs. The earlier separate Godot workflow, which loaded
the retained M11 Linux binary and a fixed fixture list, is superseded; Git history
preserves it. Windows cross-compilation is not Windows execution.

**Planned, still tracked by issue #3:** Web producer/consumer toolchain alignment,
real CI runtime coverage and current export/template provenance. Local browser
acceptance for issues #1/#2 has its own recorded artifact identity. No historical
hash reconciliation settles these separate Web obligations.
