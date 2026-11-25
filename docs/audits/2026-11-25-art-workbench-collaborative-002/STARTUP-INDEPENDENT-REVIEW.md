---
title: Independent Windows startup evidence review
status: Planned
document-kind: audit
scope: Read-only original-byte, source-boundary and timing review of the separate seven-arm startup diagnostic
last-reviewed: 2026-11-25
---

# Independent Windows startup evidence review

**The original measurements support the lead's narrow render-interval
localization and its decision to retain the startup limitation. They do not
establish a production startup repair or a shader-function cause.** Specialist B
independently reviewed the lead-authored apparatus, original records and corrected
compact archives. No application, native World, provider or model was run during
this review.

The reviewed report and compact custody correction are pinned to
[30c4d2bdead3bae8491b1f6a7c766c97df36970b](https://github.com/techrote/cybersand/blob/30c4d2bdead3bae8491b1f6a7c766c97df36970b/docs/audits/2026-11-25-art-workbench-collaborative-002/windows-startup-evidence/WINDOWS-STARTUP-OBSERVATIONS.md).
The application remains bcc92927ce3894a16d5544923cfbf7b1d0339fda,
tree 517164084860a19f18b36cb94f77597eb3220578. This independent review is evidence
only and does not alter that evaluator or the separate delivery-guide successor.

## Independently checked original custody

The independently authored [Python reduction](startup-independent/verify_startup_originals.py)
executed directly in the reviewer environment and passed **876 checks with zero
failures**. Its [complete stdout](startup-independent/startup-original-review.json)
is 8,461 bytes, SHA-256
f267af80c0e63ca3c632769199717051286198c67f28a79a7c0944ffc5bbc399.
These are evidence verification checks, not another 876 application tests.
The script does not import the diagnostic runner or fixture.

| Complete original | Source | Verified bytes | SHA-256 |
| --- | --- | ---: | --- |
| [Four arms, artifact 14993266843](https://github.com/techrote/cybersand/actions/runs/45549435385/artifacts/14993266843) | 8ce9bbd780df7ac1a82caf1ae1598fed27371138 | 4,981,131 | c79ffd7960cb02c66d66e1e09d3c6fc167aa288d101b748771b5af2def7ffe1f |
| [Render/profile arms, artifact 14993970171](https://github.com/techrote/cybersand/actions/runs/45550363681/artifacts/14993970171) | 60a0db0206a6e7ef24b97d44e7cc1db60918dbca | 619,916 | 8515813ed298f3d1aa5eba9c4eea7456e36af6b96eeb86307495d63b9ebfaf4d |

The reduction recomputes both outer identities, all ZIP member CRCs and every
manifested original file size/SHA: **130 + 53 original members**. It verifies the
complete partition into retained and omitted files, and the exact original bytes
of all **26 + 18 compact measurement/log/audit members**. The compact archive's
embedded manifest must equal the external source-pinned manifest. Original
process-log JSON must equal the standalone phase file and result fixture; all
seven logs contain their 27 successful actual fixture assertions. Reported
process outcomes, source identities, derived summaries and log hashes agree.

Source review found an unnecessary generated CI debug signing keystore in the
first compact archive. The lead corrected only that derivative: its current
55,211 bytes have SHA-256
fcd42328682e977c4d6422a7ae6f5bd5da8d0e87ced0ef7cb460f3303c43717b.
The reduction confirms that it excludes the key, preserves the original omitted
identity/reason, and retains every measurement, process log and audit byte. The
immutable full original artifact is unchanged. The second compact archive is
58,530 bytes, SHA-256
064378dc64c6a41dd390bf17caf8c7bc5ced82b5314527af265edc443bcfcec2.
No key content is reproduced in this review.

## Application and observation boundary

Canonical GitHub commit metadata was independently read. The first diagnostic
is a direct child of bcc, tree e7a3557e2983bb596fabe3f226e3939baf353a47. The
follow-up is its child, tree f52fd14241738ec20bba1ea5590e9a888c5ee785. Read-only
Git object comparisons establish exactly four apparatus paths over bcc in both
trees: the dedicated workflow, probe audit, Python runner and GDScript fixture.
Every application script and native/runtime input is consequently unchanged.

Each original arm's recorded source is clean and identical before and after
execution. Apparatus hashes match the actual Git blobs. The recorded native and
Rapier identities match bcc's LFS pointers, and the recorded official Godot GUI
and console identities match the pinned engine. This measurement review does
not independently rehash runtime binaries absent from the measurement archives;
the principal package has its separate original-byte runtime custody review.

The fixture loads ordinary main.tscn and waits for actual native Workbench
installation. It opens ordinary Art without requesting a provider, captures
three regions through the existing native owner, and builds copied bounded
contexts. The World remains 2048 by 2048, configured worker-thread value and
maximum FPS remain zero, and no production scheduling policy is changed.
Recorded native source identity is unchanged around every capture.

The clock starts at SceneTree initialization after engine bootstrap. The
readiness clock, OS process wall, render intervals and native absolute
publication timestamps have different scopes. In particular, the remaining
installation wait includes main-loop/render wall time; it cannot be read as
native-worker CPU time. Callback-to-observation also includes three context
builds, rather than being a pure callback scheduling metric.

## Exact timing and cache findings

For the original four fresh-profile arms, independently recomputed readiness is
42.630759, 38.979483, 40.161100 and 3.510985 seconds for graphical-first,
graphical-repeat, graphical-after-import and headless. Main loading,
instantiation, synchronous ready and remaining-installation phases sum to each
readiness time with 1.331–6.616 ms of unallocated fixture overhead. Repeated
project-cache use and explicit import did not remove the displayed stall in
those observations. All four used an AMD EPYC 9V74 allocation.

The follow-up used a different Intel Xeon Platinum 8573C allocation. Both hosts
reported two exposed cores/four logical processors, Windows Server 2022 image
20261116.370.1, 16,771,836 KiB visible memory and Microsoft software rendering
through ANGLE. That host difference prevents a cross-campaign source-causal
comparison.

| Follow-up arm | Readiness | First render interval | Largest render interval | Maximum main-loop gap |
| --- | ---: | ---: | ---: | ---: |
| Fresh graphical profile | 52.113567 s | 47.889111 s | 47.889111 s | 47.892064 s |
| Reused generated profile | 4.728312 s | 0.206923 s | 0.882206 s | 3.196733 s |
| Fresh headless profile | 4.027805 s | No render interval | No render interval | 3.133733 s |

All 38 fresh and 41 reused graphical render intervals are retained, below the
128-interval cap. Their recorded end-minus-start values reproduce every duration
and the reported maximum. The first fresh draw starts at 3.240105 s and ends at
51.129216 s. The enclosing process frames occur at 3.237711 s and 51.129775 s:

**2,394 microseconds before + 47,889,111 microseconds inside + 559 microseconds
after = 47,892,064 microseconds of observed frame gap.**

Only 2,953 microseconds of that specific gap lie outside the render-signal
interval. This is a direct temporal localization of wall time. The signals do
not identify GPU-only work or a particular compiler function.

The first arm's **34 complete shader-cache path/size/SHA records exactly equal
the second arm's recorded inputs**. The reused arm records the designated passed
same-source sibling profile; source review confirms arbitrary or failed reuse
is refused. The second arm ends with 35 files. The reduction also checks those
35 final original archive files and confirms the first 34 are unchanged. This
is a whole-profile, baseline-first, one-pair observation. OS page caches, other
profile state and host contention were not isolated.

All seven arms retain equal disclosed context hashes for their 64 by 64,
256 by 256 and 512 by 512 captures, with 7,438, 8,003 and 8,528 wire bytes
respectively. Every capture repeats the same source identity before and after.
This comparison covers those three bounded model contexts; it is not proof that
every hidden native World byte or simulated body state is identical.

## Reviewer disposition

No evidence blocker remains in the corrected report. Preserve the substantial
fresh-profile startup cost and hand this exact apparatus/data to the rendering
owner. The reused arm still has an 882 ms render interval and seconds of initial
setup. Neither a universally reusable driver cache nor a production startup
change follows from this experiment alone.

The report correctly preserves the distinct physical Windows/NVIDIA acceptance
item: an absent LM Studio listener, Send, and ordinary Art X/Hide. These startup
measurements do not reproduce or close that case. Earlier bcc/e536 pristine
launcher gaps also remain separate hosted observations, not a controlled
improvement estimate. Draft/HOLD and the independent evaluator identities remain
unchanged.
