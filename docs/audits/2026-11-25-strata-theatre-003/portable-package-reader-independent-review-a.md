---
status: Current
date: 2026-11-26
scope: Independent source review of an external static package reader; actual package pending
---

# Independent source review — complete portable package reader

Specialist A reviewed external reader commit
`33eff6952282177be479dfa55f4b509648c66981`, tree
`299f290ffb6520724cbe56e9d5eb9f80301f31cc`, and independently ran all **10 focused
controls successfully** with exact `fd0830ab` source loading. This is a source
and control result; no actual evaluator ZIP was admitted by this review.

| Input | SHA-256 |
|---|---|
| `tools/ci/strata3_package_portable_verify.py` | `65f0b6e13a89afd9ed5500ce96d1925947e08dcb83ecb65937c1281c7945eec8` |
| `tools/ci/test_strata3_package_portable_verify.py` | `ffde8341374ad76973d59aed98d52e809f456397afba08819df0c4331d5dcfa0` |

The wrapper loads the exact frozen package verifier and its transitive modules
from the explicit immutable application checkout. It executes that verifier
unchanged. Only the separately reviewed predecessor `verify` function is
temporarily supplied in memory, carrying its one Windows/POSIX basename
correction. The original function is restored even if a later frozen gate fails.
An original failure outside the specific recorded path limitation is rejected;
the adapter does not generally waive failed checks. An original success must
produce the same manifest as the adapted invocation.

ZIP/manifest digests come from separate download custody. The wrapper validates
raw decoded archive names, bounded inventory, case collisions, links and exact
extracted bytes. It runs pristine package verification and rechecks original
archive, complete extracted inventory and frozen imported-source bytes after
the read. It makes no Godot invocation or new execution/performance claim.

I found a concrete initial CLI output-path hole: checking receipt nonexistence
before extraction permitted a destination such as
`<fresh extraction>/evaluation-manifest.json`, which could overwrite an original
file after the final snapshot. B independently identified the same issue and
closed it before this commit. The current CLI resolves the receipt path and
refuses destinations inside either the extraction or frozen source before
verification begins. The added adverse control exercises both destinations,
proves verification was not invoked, and proves no file was created.

No remaining concrete source blocker was found. Actual static package admission
still requires the original delivered ZIP, its authenticated custody identities
and the retained result of this exact reader. Such a future static pass must
remain distinct from pristine Windows application execution and the separate
cold first-command annex.
