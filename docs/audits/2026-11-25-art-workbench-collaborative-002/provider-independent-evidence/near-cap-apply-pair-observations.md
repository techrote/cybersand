# Controlled near-cap Apply responsiveness comparison

Status: **one completed Linux headless pair; Draft/HOLD.** This comparison follows
the incomplete low-memory attempts retained in
[conversation preparation observations](conversation-preparation-observations.md).
The environment restarted with substantially more free memory before this fresh
pair. No previous failed record was replaced.

## Exact matched task and sources

The baseline is `e536d128f85e948223b25e13931a7a801faf956d`, tree
`61d38ec119665270a9fb4eea9ae78836348d7092`. The prepared-Apply candidate is
`8a015efbeb7926a3c835303d3b163c01d353aca3`, tree
`ad991f1fe8e2c8945120526377d85392d0a3212a`.

Both ran the inherited `run_art_workbench_final.py --group conversation-apply`
against an actual ordinary native Workbench and a fresh isolated profile. They
used the same pinned engine and native/Rapier runtime, the same deterministic
16,769,024-byte edited conversation, the same 4096-character visible-part limit,
and the same complete post-exit audit verification. They ran sequentially,
baseline first. Source status was strictly clean before and after each arm.

The baseline completed **22 checks / 0 failures**; the candidate completed
**23 checks / 0 failures**. The extra candidate check waits for the explicit
asynchronous completion. Both original edited values and both archived snapshots
have SHA-256
`ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a`.
Independent post-exit verification reports complete redacted conversation
custody and zero model requests for each arm.

## Measured observations

| Metric | Baseline e536 | Prepared candidate 8a |
| --- | ---: | ---: |
| Apply action return | 620.436 ms | 43.440 ms |
| Driver-observed completion | 620.436 ms, synchronous | 644.979 ms, including preparation and durable commit |
| Maximum frame gap across Apply and completion | 639.012 ms | 73.356 ms |
| P95 frame gap in that measurement | 639.012 ms | 8.726 ms |
| Frames sampled in that measurement | 12 | 91 |
| Complete audit append, main owner | 259.717 ms | 46.978 ms |
| Audit formatting | 152.611 ms | 7.414 ms |
| Audit write phase | 54.013 ms | 28.262 ms |
| Conversation editor open action | 15.768 ms | 17.491 ms |
| Maximum frame during editor opening | 75.832 ms | 82.597 ms |

The candidate's owner commit, including adoption, took 49.149ms. Its prepared
completion became available 582.968ms after the Apply operation began. The
operation retained its immutable copied value and current owner guards while
the application continued processing frames.

The substantive gain in this pair is reduced blocking: the Apply action returns
before the full redaction/encoding work is complete, and the long CPU work no
longer occupies one application frame. **Total completion was 24.543ms slower**
in the candidate. Editor opening was also slower in this observation. Do not
describe this result as faster total work, universally smooth frames or a solved
cold-start problem. A remaining 73.356ms maximum Apply frame is material.

P95 is within-arm descriptive data: the baseline has 12 frame samples and the candidate 91, so it is not a comparison of matched distributions. The candidate's host adoption receipt is 629.538ms; the 644.979ms completion observation also includes the driver's wait for the next applicable frame.

These are one baseline and one candidate observation on a shared host, without
randomized ordering or a distribution of repeated runs. They establish a useful
mechanism-level responsiveness comparison under the matched task, not a
statistical speedup or a Windows/physical-device result. The candidate still
requires its complete displayed and Windows qualification.

## Host and unchanged runtime

The host was Linux 6.18.57-x86_64/glibc2.41, Intel Xeon Platinum 8573C, nine logical
CPUs. MemTotal was 10,206,468KiB with no swap. MemAvailable before the baseline was
6,735,332KiB and before the candidate 6,640,976KiB. The two native fixture worker
threads were selected by the existing driver. No scheduler, native engine,
PUBPRES or runtime binary changes were made.

- Godot 4.7.stable.official.5b4e0cb0f:
  `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
- Native runtime:
  `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`.
- Rapier runtime:
  `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.

The ordinary native Workbench was initialized, a 512-square World was installed,
and the unchanged driver observed simulation progress before the conversation
case. Headless execution does not establish rendered appearance or physical
mouse/Windows-driver acceptance.

## Complete evidence custody

[Original paired evidence](near-cap-apply-pair-evidence.zip) is 89,454bytes,
SHA-256
`461b2b4135e2592ac8fcd230281118398c1376afb6a9617100cd1eaf9f007b79`.
It contains 30 members including its manifest and 67,120,420 uncompressed payload
bytes. Every member was read back against its recorded digest and ZIP CRCs
passed. Both complete original synthetic audit files are included.

[Immutable manifest](near-cap-apply-pair-manifest.json) SHA-256:
`b2012bed57c43ffcecf305412218a579403810ffe804d506e2f84a78ea641ada`.
[Machine-readable comparison](near-cap-apply-pair.json) retains commands,
source identities, host/memory observations, full case results and audit proof.

The earlier e536 exit-minus-nine attempts remain informative incomplete outcomes
in evidence commit 807250. They ran under materially different shared-memory
pressure; this fresh completed pair does not prove the exact cause of their
termination.
