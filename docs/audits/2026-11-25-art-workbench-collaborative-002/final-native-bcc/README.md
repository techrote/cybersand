---
title: Final native reviewer outputs
status: Planned
document-kind: audit
scope: Immutable Linux and Windows native evidence replay and cross-source comparison
last-reviewed: 2026-11-25
---

# Final native review data

These files preserve the complete independent original-byte reviewer stdout for
the frozen bcc Linux and Windows headless/displayed campaigns, the independent
cross-source comparisons, exact commands and artifact identities. No file here
is a new native execution or a real-model output.

The original-byte method is tools/ci/verify_art_creative_native_evidence.py at
06a3ab765255c72d80e8e0866beae1ba725f9880, SHA-256
64292c1a48babae89b51e0dfa2c99792c29e9f2f813962294da8fc6d8c4536a9.
Run it on each extracted art-collaborative-headless or
art-collaborative-displayed campaign directory with the explicit expected source
bcc92927ce3894a16d5544923cfbf7b1d0339fda. It checks the recorded per-case hashes
before replaying the exact cell arrays and native diagnostic planes.

The comparison script uses a reviewer input directory containing:

- creative-native-summary-2743.json, copied without changes from
  docs/audits/2026-11-25-art-workbench-collaborative-002/full-displayed-2743/creative-native-summary.json
  at evidence 39a7a1fb72b9c694f442963ca6852499e2f56eee.
- native-test-2743.gd and native-test-bcc.gd, from
  godot/tests/test_art_collaborative_native.gd at their respective immutable
  application sources. The files are byte-identical.
- verify_art_creative_native_evidence.py, unchanged as identified above.
- The four original-byte output files preserved here.

Pass that reviewer directory and the extracted platform artifact directory to
reconcile_final_native.py with --platform linux or --platform windows.
The outer artifact ZIP must remain beside its extraction directory under the
filename in execution.json's actual execution environment: the script also
checks its complete immutable archive SHA. The original source summary and all
script/record SHA-256 values are recorded in the comparison and execution files.

The source fixture's dynamic per-chunk assertion count explains the differing
757/764/739 terminal counts; every source check line is still verified. This
comparison deliberately does not compare performance across different hosts.
See ../FINAL-NATIVE-INDEPENDENT-REVIEW.md for interpretation and scope.
