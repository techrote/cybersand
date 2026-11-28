# Independent review of guarded Goblin audit storage

Specialist C, 26 November 2026. **APPROVE prepared application
`7f7095a0664afc1225346d782deb42ab04f81aeb`, tree
`a78ea1ac28af809d41ac14f0c172c8e523abd207`.** Current-source Windows qualification,
eventual mainline reconciliation and owner acceptance remain outstanding. This
does not resolve the original 512/1024-action timeout findings.

## Narrow source adaptation

The change preserves prepared Goblin002 source `21c9a667` and its qualified
predecessor ancestry. It replaces the single fixed-output writer's unverified
buffered write and Godot rename with the same closed-file verification/native
replacement utility independently reviewed in the Art integration. C verified
the utility's exact SHA-256
`13ef034bc836763546957c60a3f0731f6934f99a7d9ef384969b15bb2a1852f2`.
No whole ULTIMA programme, native input or runtime payload is imported.

All ten existing output paths and the actual disposable-profile guard remain
authoritative. Compact JSON and the separate 2 MiB corpus, 32 MiB transcript
and 512 MiB cumulative archive bounds remain intact, with budget refusal before
staging. Unrelated stale `.partial` files are preserved. Individual output files
remain individual transactions; no fsync, power-loss or multi-file guarantee
is claimed.

The canonical runner adds one explicitly named storage fixture and requires its
unique terminal receipt. Only that fixture bypasses campaign-transcript parsing,
because it deliberately writes small non-campaign JSON to exercise the fixed
paths. Actual controller, gameplay, campaign, replay and lineage cases retain
the existing independent transcript validation.

## Independent execution and exact source custody

The lead had appended evidence-only records when C executed. The actual checkout
was `eb17ca92c7f6de05ff2558350a33d0a418cfa05f`; C proved its entire difference
from `7f7095a0` consists of three audit files. All application, test, native and
runtime inputs were unchanged. C's complete before/after custody snapshots were
identical.

The canonical runner's fresh executed-game source ZIP is also byte-identical to
the exact source retained by the lead's `7f7095a0` campaign: 2,951,967 bytes,
SHA-256 `79707507151897b3604aa13af256bed38f52b531f0b3f0a7f6920ac8e1a67e39`.
The record preserves the actual checkout identity rather than relabelling it
as the earlier commit.

| Independent execution | Result |
| --- | --- |
| Guarded normal replacement | PASS, including preservation of unrelated stale staging. |
| Actual 128-byte file-size limit | PASS refusal; previous complete 1,689-byte output remains identical, then retry succeeds after fault removal. |
| Actual directory permission failure | PASS refusal; previous complete 1,689-byte output remains identical, then retry succeeds after permission restoration. |
| Canonical storage contract | 67 checks, zero failures, fresh import, unique natural terminal receipt. |

The three actual storage scenarios used eight real Godot processes. Both
refusals retained SHA-256
`2eb30c3a147f1beaf5f4873bdc2018384b2f59216d4f2a01b211f943d0c2fe67`
and the previous value 7; both retries produced complete requested value 8.
Actual fixed-path/profile negative controls passed in every process.

The canonical test retained its 300-second process allowance, 240-second fresh
import allowance and 3,072 MiB owned-process bound. The storage case completed
in 2.746 seconds, sampled peak process-tree RSS 714,133,504 bytes across 27
samples, with no surviving owned process. Its fresh import passed in 7.061
seconds. These are bounded short-run observations, not a long-horizon resource
stability claim.

## Original failure and wider evidence retained

C separately inspected and hash-verified the lead's original baseline
`9f3c479efbf356832a691aa2f9c1dbe947c34d32`: it returned success after replacing
a valid 1,689-byte output with malformed 128-byte output under the actual file
limit. That result remains failed evidence. C did not rerun or relabel that
baseline as a successful test.

C also checked the six source-pinned canonical qualification reports and their
original raw log hashes: storage, controller, laboratory, discovery, authored
lineage and the AMBIENT handoff test all pass at `7f7095a0`. The laboratory's
14-check preflight is included in its final cumulative 70 checks; it must not
be added again. The 447-check AMBIENT case retains its distinction between
test assertions and applicable gameplay oracles.

The companion JSON preserves exact source, process, limit, refusal and retained
byte identities. `raw/goblin-storage-independent-7f7095.json.gz` retains C's
registration, wrapper, complete custody, original process logs and actual output
bytes. It records the byte-identical source archive as an alias to the lead's
committed packet and excludes only identified derived engine documentation
cache. No product source was modified by C.
