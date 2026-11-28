# Provider recovery and retained observations — 25 November 2026

Status: **Draft/HOLD**. This record is a recovery transcription, not a replacement for original raw evidence or fresh application qualification.

## Source custody and recovery boundary

The execution environment reset while the lead was preparing the successor qualification campaign. The committed local integration, specialist worktrees and evidence under `/tmp` became unavailable. The previously published integration checkpoint remains `7db8d1592642c7bd7298ba8f8fb008345de35e07` (tree `c9ba0ddc7e7ec5de1e62eed3f27123a20c52cd61`). No predecessor branch, qualified evaluator or Architecture source was changed by the recovery.

The Art provider recovery commit is `419063f6bff2e0842d8be1d69a1a69eeb613e388`, tree `413f55cbee7248130ad64fdd23ad6684cff9d36f`, parent the exact published integration checkpoint. It changes only two functional lines: production HTTPRequest download chunks from 64 to 256 KiB, and the inherited application matrix's declared chunk size to match. Nonthreaded polling, scoped cancellation, the 16 MiB response limit, finite timeouts, complete redacted audit and original frame/cancellation gates remain unchanged.

The recovered provider file SHA-256 is `9d32d4ad89f5dd9bc330bfa3dc91a689ffc1720bf4fc31d933d4614d49638438`. This is the byte identity of the earlier experimental 256 KiB arm, without the two explanatory comments added to the later local production file. That later locally tested provider SHA was `465e108288743b4a629f416f640634d0ddca19ddd95e3d6044079db351875cd6`.

The local commits `9e8abd74`, `0401aa10`, `34b4e980` and `8ea57ea4ea4e8107e2fc02f868042753c5414e18` were committed but not remotely published before reset. Their original comparison runner, fixture and raw new observation logs are not claimed present in this recovery. The values below were read and reported before the reset; their listed hashes describe those original files and do not make absent bytes available. A fresh reconstruction and rerun must use its own source and evidence identity.

## Controlled 4 MiB mechanism observations before reset

These were headless production-provider exchanges against a deterministic local HTTP server, without a native World or real inference. Each arm completed 18 checks with zero failures, preserving full assistant-text and redacted-audit checks, actual Stop and oversized-response refusal. Each arm is one observation under a shared host; no statistical or displayed-application improvement is inferred.

| Frame cap | Read chunk | Transport ms | Complete callback ms | Observed nonterminal reads | Maximum frame ms | P95 frame ms | Stop ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 60 fps | 64 KiB | 1115.404 | 1972.524 | 63 | 245.015 | 17.335 | 1.156 |
| 60 fps | 256 KiB | 315.331 | 866.070 | 15 | 149.793 | 16.894 | 0.981 |
| 5 fps | 64 KiB | 13399.345 | 14658.062 | 63 | 257.069 | 204.244 | 1.837 |
| 5 fps | 256 KiB | 3798.131 | 4867.190 | 15 | 267.045 | 205.700 | 1.714 |

The response was 4,190,323 bytes, SHA-256 `0577042e411548f0035b75c4accd928544fcc451b82acd21878057d53d3b75fa`. The decoded assistant SHA-256 was `8034f34bb459ba5c850d09839c39b0595d902421b5bed1c8d63c1e460233ab08`. The original comparison JSON SHA-256 was `0517c43bdd4b90635113fb3bec73ccc0d7103abbeaf2a9415d0a8e0535d8c182`.

Reads were sampled during process frames and can exclude the terminal read. The largest observed increments were 65,536 and 262,144 bytes. These observations support a frame-paced transport mechanism; they do not explain all audit, decoding, layout or World startup costs.

The recorded host was Linux 6.18.57 x86-64, glibc 2.41, Intel Xeon Platinum 8573C, Python logical CPU count 9, MemTotal 10,206,468 KiB and available memory approximately 1.86–2.23 GiB during the cohort. Cgroup counters were not available. Godot was `4.7.stable.official.5b4e0cb0f`, SHA-256 `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`. The real native audit library SHA-256 was `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`.

## Retained 16 MiB unsuccessful comparison

The first 16 MiB cohort is an adverse observation, not evidence of a successful throughput improvement. The 64 KiB / 60 fps arm completed 18 checks with a 16,773,235-byte response, 4,314.579 ms transport, 11,171.635 ms complete callback, 1.046 ms Stop and a **4,319.049 ms maximum frame**. The experimental 256 KiB arm exited with signal 9 after the server wrote the response and before a final receipt. It was not reported as a timeout. The available evidence did not establish whether memory pressure, the chunk change, or another condition caused termination. No passing 16 MiB comparison or reduction of the predecessor's maximum frame is claimed.

The environment also killed one initial full native World startup and an editor import before useful assertions. A subsequent separate-worktree checkout initially exited 137 before succeeding with LFS smudge disabled. None is silently converted into a product diagnosis.

## Post-change focused provider regressions observed before reset

On the locally committed provider SHA `465e1082…`, actual local processes passed the following existing tests: owned transport 155 checks; provider 54; failure lifecycle 106; outgoing preparation 34; incoming preparation 38. The logs were checked for parser/script errors. These are earlier development observations, not fresh source-exact qualification of the recovered remote commit.

The four original legacy-log SHA-256 identities were respectively `a94c05d761d2f8a2eea617ddc591c0dd86331254fdebece261d5c0ca633436a5`, `1c756ae578597a2fdd72371b7a6aec694938fa9b8df11f3294da2bf8cf2e2254`, `b1ea615b83e7140b3a2d0b716d75fdb6c0512068e1b8ac1485ae0cc961f3270c`, and `53b7245e5dfa0691a3b9282e0adf563baf8f5c3561b2b84c6d37553ea6fec400`. Observed accepted-socket/no-headers Stop was 0.778 ms and body-transfer Stop 0.771 ms in that focused fixture run. The absent local listener remains a distinct case from a live HTTP error.

## Exact predecessor scope recovered before reset

These values were independently read from the original retained predecessor workflow ZIPs and compared byte-for-byte with their extracted copies. Those predecessor archives were under the persistent workspace, not the lost temporary worktrees. This transcription retains their identities and scope until the extracted recovery JSON can be regenerated.

- Qualified application source: `981a740828decbeac04d5a14511d0222095de0a9`, campaign [45482969231](https://github.com/techrote/cybersand/actions/runs/45482969231).
- Qualified package source: `fa22d386b802b686c371bb6e12996c7a93c18588`, campaign [45497650568](https://github.com/techrote/cybersand/actions/runs/45497650568).
- The extracted delivered launcher took 54.184566 seconds to readiness and reported a 49.252555-second maximum startup frame gap. This is a startup gap; the measurement does not isolate import, initialization or one causal component. Visible idle maximum was 161.351 ms and teardown 391.459 ms; the observed window was 1028×720 at 96 DPI.
- Windows displayed `near-limit-successful-assistant`: 16,773,283 response bytes, HTTP 200/result 0, transport 48.128887 seconds, whole case 53.283976 seconds, maximum frame 823.830 ms, P95 192.256 ms, 64 KiB reads. Hide while the provider was active took 847 microseconds; manual paint/native ticks progressed from 3610 to 6448 during the inflight case.
- Linux's corresponding case recorded 14.026525-second transport, 17.233007-second whole case and a 257.110 ms maximum frame.
- `loaded-near-cap-edited-apply` covered 16,769,024 bytes with a 4096-character displayed part: Linux Apply 354.215 ms; Windows Apply 413.840 ms. The complete edited value SHA-256 was `ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a`.

Both Windows campaigns used Windows Server 2022 Datacenter 10.0.20348, runner image windows-2022 version 20261116.370.1 and ANGLE 2.1.1 (git aaebda1c5a40), Microsoft Basic Render Driver 0x8C / D3D11-10.0.20348.5756. The application runner location was Azure westus2; the package runner Azure centralus. CPU model/count and RAM were **not recorded**; GitHub defaults must not be substituted. This was software graphics and does not qualify physical Windows/NVIDIA acceptance.

The Linux application runner used Ubuntu 24.04.5 image 20261116.133.1, AWS us-west-2, Mesa 25.2.8-0ubuntu0.24.04.4 / llvmpipe LLVM 20.1.2, 256 bits, MemTotal 16,078,416 KiB. CPU model/count were not recorded.

Original retained ZIP SHA-256 identities: Windows application evidence `9c9664683bd492522521a1e05ad0cfab1d6ad400e0ddc2010453073494b0f63d`; Linux application evidence `4b0d1a3f318580f5a3224e4687c4362e2b49a11b893e862c90b7741dff490940`; Windows package evidence `832d48b2a64c38d92d9379f33fe7da36dbb4719fb41954f1211091929daa21ae`; principal Windows evaluator ZIP `c1666f1b6cee269bea8e95c4d018f2f36dd3b246491a3754c83cc37d167f9f9f`.

## Architecture and independent review boundary

The source-pinned proposal-only bridge implementation and 32-check fixture probe are already preserved in published 7db. They use unchanged qualified Architecture application source `17c6b5b35049b7b2541c2deeea23c02fd1e2fc5d`; their copied inspection fixture demonstrates transport/typing/ownership, not native construction. The owner authorized a separately identified combined native Workbench/StageSession probe. It had not started native execution when the environment reset and remains pending.

Independent source review found and helped close policy/loopback/image admission issues, direct-run ownership conflicts, reentrant proposal identity and native-verification receipt custody. The lead's later local coordinator source and tests must be recovered and freshly qualified; this record does not certify reconstructed bytes that have not been inspected. Package review likewise does not substitute for a downloaded ZIP, pristine launcher execution, native runtime custody or physical owner acceptance.

No paid or genuine model inference was used in these observations. The predecessor evaluator, original negative findings, session-only conversation semantics and Draft/HOLD remain in force.

## Reconstructed mechanism apparatus

The separately named `tools/ci/compare_art_transport_pump_recovered.py` and `tools/fixtures/art_transport_pump_recovered.gd` were reimplemented from the required mechanism contract after recovery; they are not represented as byte-identical copies of the lost runner. Each records its own source hashes and full original process log. The first development arm reported 25 checks but emitted native hashing errors for empty cancellation/refusal text. Independent log inspection rejected that attempt despite its initial wrapper result. The fixture now avoids hashing an empty update, records callback-entry time before validation work, and the wrapper rejects any engine `ERROR:` line. The original failed development log and receipt remain separate from subsequent observations. Fresh comparison results will be added only after the committed apparatus runs.

## Fresh committed four-arm comparison

The reconstructed apparatus committed at `6ecfb83e6146758ce4d9e0cd20102c844ccf3186` completed four fresh processes, **25 checks / zero failures each**. The complete original comparison, four process logs, four complete redacted audit streams (losslessly compressed), failed development attempt and file manifest are now retained in [provider-recovered-evidence](provider-recovered-evidence/files-sha256.json). The complete comparison SHA-256 is `45b9e3a349640a0a4ae621b762eae7a923c031ee777597395420571dc210b626`.

| Frame cap | Read chunk | Transport ms | Callback entry ms | Maximum frame ms | P95 frame ms | Actual no-headers Stop ms |
| --- | --- | --- | --- | --- | --- | --- |
| 60 fps | 64 KiB | 1084.025 | 2186.214 | 119.285 | 16.942 | 0.940 |
| 60 fps | 256 KiB | 284.345 | 1360.333 | 143.202 | 17.085 | 0.991 |
| 5 fps | 64 KiB | 13131.776 | 14150.801 | 223.728 | 203.247 | 1.325 |
| 5 fps | 256 KiB | 3502.261 | 4534.303 | 235.310 | 204.688 | 1.318 |

All arms used the same 4,190,448-byte response, SHA-256 `1fdf50cf46644389b7f0858f215407b23214bcd7467446d6b93a4931c0434673`, with full assistant SHA-256 `63b673968544a3f3bb234b8815455eb665dc945df22b63a4a771cd6a0359047d`. This payload is explicitly different from the lost cohort's fixture. The production provider source is `9d32d4ad…`; the baseline arm changes only the pump constant back to 64 KiB, giving `210245a0dac634a5b812231dca3b7e4cca265b631726805a4da69412b908ff41`. Every copied closure file, runner, fixture, engine and native library has its own recorded hash.

Each real server saw exactly three authorized synthetic requests: complete success, accepted socket without headers and an oversized response header. Each owned request had one terminal consumer; ordinary completion count stayed zero. The actual HTTPRequest stayed nonthreaded, its cap remained 16 MiB, both full response-envelope and assistant audit values matched the expected complete text, and no audit contained the synthetic credential. Decompressing each `.jsonl.gz` restores the exact original stream whose SHA-256 is recorded in the fixture receipt.

This second cohort reproduces the bounded transport mechanism and fast scoped Stop. It does not establish a reduction in maximum frame time: both 256 KiB arms had a slightly higher maximum frame than their paired 64 KiB arms. It contains no native World, displayed UI, Windows run or genuine inference, and no 16 MiB successful paired improvement claim. All full application and physical owner acceptance boundaries remain separate.
