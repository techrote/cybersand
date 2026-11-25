# Independent performance observations — retained boundaries

This packet combines independent inspection of immutable predecessor/current hosted artifacts with independently executed Linux phase measurements. It preserves adverse results. The controlled 4MiB transport experiment remains separately documented in [provider recovery](../provider-recovery.md); these hosted runs are different campaigns and must not be treated as a matched causal comparison.

## Hosted large-response and Apply observations

Predecessor application source is `981a740828decbeac04d5a14511d0222095de0a9`, campaign `45482969231`. The successor observation is intermediate application `2743f89a0df6f6afcf7484e859c10790d521e74b`, campaign `45534980763`. Its Linux campaign passed. Its retained Windows groups passed, then both new collaborative suites refused before execution on strict source admission; the whole Windows campaign and its owner package did not qualify.

Both near-cap fixtures transferred 16,773,283 response bytes. Both Apply fixtures edited 16,769,024 bytes, displayed at most 4096 characters and preserved complete edited-message SHA-256 `ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a`.

| Actual displayed observation | Predecessor Linux | Intermediate Linux 2743 | Predecessor Windows | Intermediate Windows 2743 |
| --- | ---: | ---: | ---: | ---: |
| Near-cap transport seconds | 14.026525 | 3.856402 | 48.128887 | 13.530290 |
| Whole near-cap case seconds | 17.233007 | 7.120711 | 53.283976 | 19.285563 |
| Near-cap maximum frame ms | 257.110 | 277.563 | 823.830 | 796.202 |
| Near-cap P95 frame ms | — | 72.420 | 192.256 | 214.886 |
| Large Conversation Apply ms | 354.215 | 369.504 | 413.840 | 619.017 |
| Large Apply maximum frame ms | — | 372.936 | — | 624.742 |

The bounded read chunk changed 64→256KiB while retaining the 16MiB cap and cancellation. Transfer completed substantially sooner in these observations; the separate matched 4MiB experiment supports the frame-paced transfer mechanism. The approximately 0.8-second Windows large-response frame stall remains. Linux maximum frame and both large-Apply observations worsened. No frame-latency or Apply improvement is claimed.

The fresh Windows near-cap response CPU preparation was 3.340383 seconds: response sanitization 1.447446s, assistant redaction 0.977474s, JSON parse 0.331673s, response encoding 0.219189s, assistant encoding 0.200035s, plus other recorded costs. Response audit append was 39.913ms and completion callback 559.273ms. On Linux preparation was 2.318620s and callback 208.892ms. These are observed components, not permission to weaken complete redacted custody.

Fresh Windows Apply audit consumed 211.862ms, including 119.438ms formatting, 55.106ms writing and 7.493ms sanitization. The remaining 407ms belongs to other Apply work. Linux Apply audit was 162.270ms. Further phase attribution needs separate instrumentation; it cannot be inferred from the total alone.

Post-exit complete audit verifiers record the full near-cap redacted response body SHA-256 `9360fc172d8f811ddf11b16b8ab7d3bce18d1bfa9fbbbcfebfd90419bb8458e1` and credential redaction. The original report/provenance/verifier bytes are retained in the archive below.

## Hardware and original cold-start scope

Both Windows campaigns used Server 2022 Datacenter, image `20261116.370.1`, and ANGLE 2.1.1 `aaebda1c5a40` with Microsoft Basic Render Driver `0x8C`, Direct3D11 `10.0.20348.5756`. CPU model/count and RAM were not recorded in those artifacts. These are hosted software-rendered observations, not physical Windows/NVIDIA acceptance.

Both Linux hosted campaigns used Ubuntu 24.04 image `20261116.133.1`; the predecessor reports 24.04.5 and Mesa 25.2.8/LLVM20.1.2 llvmpipe 256-bit software rendering. Fresh Linux resources record MemTotal 16,078,424KiB. CPU identity was not retained, so matched physical hardware is not assumed.

The original pristine Windows package campaign `45497650568`, source `fa22d386b802b686c371bb6e12996c7a93c18588`, recorded a 54.184566-second Workbench-ready event and 49.252555-second maximum startup main-loop gap. That gap includes the evaluator's resource load, instantiation, synchronous main._ready and native setup interval. It does **not** isolate 49seconds of import. Its visible-idle maximum was 161.351ms and teardown 391.459ms. The original report is retained unchanged.

## Separately pinned startup and native-context measurements

External apparatus `a895e622072b88ab59dbef1db5a473dfc950bd85`, tree `72157b68e413615fc6eb1866f6186165ef6c84c0`, contains exactly application 2743 plus three apparatus files. Each independently executed process had a fresh profile; production source and scheduling remained unchanged. All three arms passed 27 checks, with no provider request or native write.

The first two arms had only the three committed Godot bootstrap files before and after execution. The third explicitly ran editor import (9.048662s) and had 19 cache files at runtime. File identities are recorded. OS page cache was neither cleared nor controlled; none of these runs is called OS-cold.

| Linux headless phase | Bootstrap first process | Bootstrap second process | After explicit editor import |
| --- | ---: | ---: | ---: |
| Main resource load ms | 1962.776 | 1822.897 | 1786.604 |
| Scene instantiation ms | 69.413 | 124.093 | 42.232 |
| Add-child and synchronous ready ms | 1597.260 | 1406.306 | 1332.522 |
| Remaining native installation ms | 1809.562 | 1378.940 | 1770.188 |
| Workbench ready since fixture initialization ms | 5440.341 | 4733.770 | 4932.669 |
| Ordinary Art opening ms | 181.276 | 179.685 | 225.298 |

The phase sums expose multiple startup costs; the 49-second Windows boundary was not reproduced and no single component is identified as its cause. Art's Context resource load after panel creation was 15–17µs because it was already cached in that process; it is not a cold context-script measurement.

Actual read-only PAINT captures took 20.468–28.741ms for 64×64, 263.355–268.836ms for 256×256 and 1064.537–1078.418ms for 512×512 cells. The larger readback completes across existing bounded native slices. Context construction over those copied native values took 2.127–3.115ms, 25.407–49.209ms and 108.701–124.728ms respectively, across three builds per arm. The 512² context fits 8281 UTF-8 bytes, but its complete native histogram/occupancy processing is still synchronous CPU work. These figures identify a bounded performance limit; they do not establish a creative or retrieval-quality advantage.

Local host: Linux 6.18.57/glibc2.41; Intel Xeon Platinum 8573C; nine reported logical processors; MemTotal 10,206,468KiB; MemAvailable 4,965,488–5,044,460KiB at admission; no swap. Godot 4.7 headless compatibility renderer had no reported video adapter. Default application worker configuration was retained. The pinned engine/native/Rapier hashes and complete host/cache snapshots are in each inputs/result record.

## Immutable custody and limits

[Complete selected-report and phase archive](performance-observations.zip): SHA-256 `78c71ff709b3f557e5c2e71104a985f92e79f27e2a4e2bc3d0c7e54641f37aa2`, 67,509 bytes, 50 members, 261,450 uncompressed payload bytes plus manifest. The [manifest](performance-manifest.json) identifies every original included file and all five source artifact ZIPs. Each source artifact and the new archive was hash-checked and CRC-checked; every archive member was independently hashed before publication.

The evidence establishes retained responsiveness boundaries, a useful bounded transfer improvement and phase-level follow-up targets. It does not erase the previous killed 16MiB experiment, physical no-listener owner acceptance, the failed intermediate Windows source gate, complete audit requirements or either programme's independent evaluator.
