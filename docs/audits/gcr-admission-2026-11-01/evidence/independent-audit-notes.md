# GCR-A1 independent mechanical/source audit notes — 2026-11-01

Ignored handoff note only. No tracked source/evidence was changed by this review.
No efficacy captures were run, and no conclusion about physical adequacy follows.

## Reviewed checkpoint and decision

- Source: `3d0b1ed72e55ba6a644b28f77e5fc2eae8ad67ba`.
- Tree: `72f29fb292695685fa85ecb71d848edde6254b38`.
- Registration: `GCR-ADMISSION-001-2026-11-01`; preregistration and clarification
  precede implementation/efficacy acquisition. Frozen PR #346/R2 is not edited.
- Working protocol SHA-256: `ca5bd07fc0390e73c4a7cb1b221e85a97adbeb395cea8dcb03314e74b79e9b5a`.
- Mechanical seal: `build/mechanical-gate.json`, SHA-256
  `238e680648e94c301d2b1ab8f2bf1975e72d780f22449e3a99a6ea9d85c3d33b`.
- Decision: no blocker found for the registered acquisition after the passing
  mechanical gates. Admission validity, physical efficacy, performance and owner
  feel remain separate. Primary/async acquisition was running during review.

## Independently reopened receipt evidence

1. Seal source/tree/protocol match the frozen checkout. All three mechanical
   gate flags are true and separately supported by native/adapter components.
2. All 85 raw native-core input hashes in
   `build/admission-native-full/receipt.json` match present bytes.
   `input-manifest.json` matches the seal's manifest hash.
3. Both normal native-core logs match their recorded SHA-256 and contain
   174 passing tests, including all four named GCR-A1 groups: half-plane
   material/state interfaces; independent closed-square oracle; negative
   controls/geometric-only selection; and stability/excavation/lifecycle.
4. Windows and Linux adapter JSON components and logs match the seal's hashes.
   Each reports 290 assertions, zero failures, with actual Rapier/native startup.
5. All 520 normalized executable-project input hashes match both sealed platform
   identities. The shared project identity is
   `276564c81f6cd4410f324c0581fc7fd25a61b5c12cab8628b59790206a2b60dd`.
6. Earlier independent apparatus tests passed 7/0. The mechanical receipt gate
   rejects absent, stale and partial receipts and checks unchanged receipt bytes
   again before each physical capture.

## Explicit fresh extension provenance

Authentication uses these explicit files, not the retained R2 metadata copied
into each isolated project's addon directory:

| Platform | Manifest | Actual extension SHA-256 |
| --- | --- | --- |
| Windows | `build/admission-runtime-windows.json` | `d7c6b1d80b187c855eda8dc6369ced6baf139d54d3b6ca80f4f22acf8f6b761b` |
| Linux | `build/admission-runtime-linux.json` | `7c676c0cb2190e91f604966ef4b39b75ff0383db07438192e9e9ccfd6166530f` |

Both manifest file hashes match sealed runtime identities. Their actual artifact
bytes match those identities, and each manifest's 81 compiled source-input hashes
was independently checked against canonical current Git blobs, with no mismatch.
Their source is the frozen 3d checkpoint. The Linux module copied into the Linux
project also matches its sealed artifact hash. The running Windows primary
command explicitly passes `--native-manifest build/admission-runtime-windows.json`.
Publication of tracked runtime metadata is intentionally deferred until capture
freeze ends; unused copied R2 metadata must not be described as current A1 proof.

Working-file protocol hashes and canonical LF/Git hashes are distinct, explicitly
labelled quantities. The canonical protocol hash in the frozen-scope receipt is
`807391ce39bc92c44ec5e0f242e4d4f0c106187d63afc9d3afe4e72d048e1d06`.
Do not overwrite either identity merely to make them equal.

## Final native-diff attribution

The native production delta is the read-only admission query, literal extraction
of the existing sample-stability predicate, A1-only side/up routing, fresh-token
selection, and fixed admission counters/observation getters. The exact45-degree
classification and ordinary downward path remain unchanged. R2/B0/Y1 retain
their existing semantic branches. Locked solver, response, displacement/ejection,
bridge/controller/material functions/files remain unchanged under the scope gate.

The first mask-free stencil is selected before material/path tests. Packing is
evaluated once, without a deeper fallback. The integer traversal includes
closed-square corner touches. An independent read-only rational-clipping check
of its algorithm agreed for all 24 bounded nonzero offsets, with no duplicates
and at most seven cells. Native execution independently covers the oracle.

The new counter getter copies fixed accumulators and identity only; it does not
call `evaluate_gcr`. Counters survive telemetry-off runs. Existing expensive
diagnostics remain separate. Synchronous counter-copy cost is included once in
application timing and also disclosed as a subcomponent; async observer overhead
is reported separately. Missing measurements stay unknown.

Native lifecycle coverage includes actual Seed-to-Plant and Dust-to-Fire loss of
capability. The unsuccessful initial Sodium fixture is a retained fixture-premise
failure, not evidence that a reaction/contact law was altered to pass the gate.

## Linux environment failures and remaining limits

Native Linux Git could not interpret the Windows linked-worktree path. The
explicit-GIT_DIR attempt subsequently exceeded its unchanged 30-second Git
bound. Those failures are retained. The final ignored `build/wsl-git/git` wrapper
translates `-C` using `wslpath -w` and delegates metadata reads to Windows Git on
the same checkout. It does not waive source, module, protocol or project hashes.
The actual Linux adapter execution remains Linux runtime evidence.

The sealed normal-core records have null binary-digest fields; their retained
commands, input manifests and original passing logs are the recorded evidence.
Sanitizer completion is separate from this seal. Neither normal checks nor the
admission oracle establish trajectory adequacy, calibrated energy/momentum,
target-device feel, accepted performance, or merge/default authorization.
