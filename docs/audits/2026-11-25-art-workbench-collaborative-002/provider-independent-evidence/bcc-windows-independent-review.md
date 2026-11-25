# Independent final Windows evaluator custody review

**Passed for the documented package and original-evidence scope.** Specialist A independently downloaded and inspected the principal Windows evaluator for application `bcc92927ce3894a16d5544923cfbf7b1d0339fda`, tree `517164084860a19f18b36cb94f77597eb3220578`, from full campaign [45546845554](https://github.com/techrote/cybersand/actions/runs/45546845554). All three campaign jobs completed successfully, including the actual pristine extracted launcher and runtime-module check. The review ran on Linux against original Windows artifact bytes and receipts; it does not claim a local Windows execution or physical Windows/NVIDIA acceptance.

## Principal archive and immutable payload

| Identity | Verified value |
| --- | --- |
| Evaluator artifact | [14992534811](https://github.com/techrote/cybersand/actions/runs/45546845554/artifacts/14992534811) |
| Artifact ZIP bytes | 94,402,359 |
| Artifact ZIP SHA-256 | `5bf19d36afab227bbe489f9404530f24694e5f1e03d464e1613b0529f23d3699` |
| Inner portable ZIP bytes | 95,598,830 |
| Inner portable ZIP SHA-256 | `de46eaa1fa6ce3f75cea4a29286bbefa43cc257028e912b54b2265060731d95a` |
| Candidate manifest SHA-256 | `55de7a0e79af94be513e31a22c8d0ba5ec1322be1aa2e9af5bacf455940fb95b` |
| Windows original-evidence artifact | [14993247449](https://github.com/techrote/cybersand/actions/runs/45546845554/artifacts/14993247449) |
| Original-evidence ZIP bytes | 12,820,321 |
| Original-evidence ZIP SHA-256 | `45df2fecb95f21fe769f15202d15411156b658d7670e249f76e4b6877f9b3f47` |

Both downloaded outer archives, the inner package and every ZIP CRC were checked. The principal ZIP contains exactly **1,200 immutable payload files plus its manifest**, 1,201 members and 224,670,932 uncompressed bytes. Every declared SHA-256 was recomputed; there are no undeclared package members or duplicate paths.

The review separately compared all 1,092 packaged tracked source files with their canonical final Git blobs. All match byte for byte. The two materialized native DLLs match their source LFS object identities. The manifest explicitly records Draft/HOLD, package-local profiles, zero automatic model requests, deterministic fixture evidence and physical owner acceptance pending. No populated profile, diagnostics, session-journal, private-key or provider-configuration payload was found.

The generated `APPLICATION-QUALIFICATION.json` has Windows CRLF line endings, while its original qualification artifact uses LF. The initial raw-copy equality check exposed this distinction; the review then required the exact LF-to-CRLF conversion and identical parsed values, without relaxing source or payload checks. Original SHA-256 is `c4d23ad364f14585d16afa69ef011cf7433ce256e100b9181f7a566fb2bb1056`; packaged SHA-256 is `658450e67fb02b03098d260d587667fa55f5db7f164742b7751acaf688fa3319`. Both originals are retained. The decision remains `full_required`; no application evidence reuse was inferred.

## Source-matched runtime and actual extracted launch

| Runtime payload | Verified SHA-256 |
| --- | --- |
| Godot 4.7 Windows GUI | `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` |
| Godot 4.7 Windows console | `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c` |
| CyberSand native Windows | `668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e` |
| Rapier Windows | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |
| VC runtime | `d5e4d9a3e835fa679450145d6a7d94e36573a509317111904d9b3712c30d9066` |

The engine version is `4.7.stable.official.5b4e0cb0f`. All 105 compiled native input hashes and all four Rapier provenance input hashes match final bcc Git objects. The retained native build commit is `c53fd6f9d3d0f2b3f39396c7e605654f65c17299`; this mission does not claim a new native build.

The actual installed evaluator receipt identifies the final source, `actual_launcher=true`, Windows display, no automatic model requests, exit code zero and no timeout under a 240-second watchdog. The separate module-enumeration receipt observed the GUI engine, native DLL, Rapier DLL and VC runtime at their expected paths inside the extracted installation, with all observed hashes matching the delivered manifest. Its deliberate owned-process cleanup returned -1 after successful enumeration; that cleanup is separate from the principal launcher, which exited zero.

The ordinary `Open Workbench.cmd` uses package-local profile directories and its source identity is final bcc. The separate evaluated-start installer was actually executed in Windows. All nine installed Setup labels and hashes exactly match their delivered source files, with no replacements of existing saved starts claimed.

## Original application receipts and editable examples

Both packaged collaborative qualification JSON files match the original Windows evidence bytes exactly. Their source/tree, clean-source observations, engine, native/Rapier hashes, required case sets and deterministic model-call scope were checked. **All 18 original process logs** were independently hash-checked and reparsed; each has one matching result marker, zero failures, exit zero and no script/parse/resource error. Every declared case artifact hash also matched its original file.

| Required case | Headless checks | Displayed checks |
| --- | ---: | ---: |
| Exclusive owned transport | 155 | 155 |
| Provider conversation preparation | 66 | 66 |
| Ordinary Workbench prepared Apply lifecycle | 154 | 154 |
| Typed proposal/context compiler | 107 | 107 |
| Creative fixture cohort | 251 | 251 |
| Actual native creative scenarios | 739 | 764 |
| Native collaboration authority | 39 | 39 |
| Ordinary collaboration session | 182 | 202 |
| Collaborative workspace | 93 | 94 |

The differing native check counts include scheduling-dependent chunk observations; they are not different scenario counts. All nine scenarios are present. All **73 delivered native example files**, totalling 18,939,337 bytes, are byte-identical to the original displayed-run artifacts and carry the same original and immutable-manifest digests. All nine editable starts map exactly to the actual installed Setup receipt. This review verifies custody and original result integrity; the separate native specialist's raw material-row replay supplies independent geometric reduction.

The actual final Windows completed-work screenshot was inspected and shows the ordinary Workbench Art panel, bounded conversation list, complete selected message, host native result and completed-state controls. This visual check is not physical interaction acceptance. The fixture cohort demonstrates native/compiler/context/lifecycle behavior, not genuine model creativity or a causal retrieval improvement.

## Retained performance boundaries and limits

The original final Windows displayed near-cap Apply case passed 24 checks with the complete 16,769,024-byte edited conversation and SHA-256 `ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a`. Action return was 13.972 ms, driver-observed completion 622.689 ms and maximum adjacent frame gap 214.778 ms. Its audit owner work measured 25.446 ms. The headless counterpart passed 23 checks with 13.359 ms action return, 345.936 ms completion and 41.238 ms maximum frame gap. Original complete journals are retained in this review archive. These are separate hosted observations, not a matched Windows causal comparison.

The pristine installed launcher still recorded **38.497889 seconds to Workbench-ready** and a **34.966643-second maximum startup frame gap**. Visible-idle maximum was 162.762 ms, and teardown completed in 327.601 ms. The original workbench log includes the hosted audio-device failure and Dummy fallback; this is not an error-free or fixed-cold-start claim. The final displayed near-limit response case transferred 16,773,391 bytes in 11.332308 seconds and completed in 15.331624 seconds, with a 465.486 ms maximum frame gap and manual painting/native tick activity observed during transport.

The host is Windows Server 2022, AMD64 Family 25 Model 17, four logical processors, with Microsoft ANGLE software rendering in the displayed qualification. These records do not supersede the distinct original predecessor boundaries or the separately identified startup diagnostic programme. Physical owner Windows/NVIDIA acceptance, genuine local-model evaluation and a production Architecture host mount remain separate tasks. The independently refreshed Architecture native handoff is recorded at source 04ca over the final bcc provider closure; it does not turn this Art evaluator into a combined Architecture Windows qualification.

## Reproducible review record

The companion `bcc-windows-independent-review.zip` retains the independent verifier and reports; candidate manifest and launcher/installer originals; runtime provenance; both full collaborative summaries and all 18 original logs; actual installed-launch, runtime-module and Setup records; original near-cap reports and complete redacted journals; and the final displayed near-limit transport report. Its separate manifest records every member's original byte count and SHA-256. The archive is 297,301 bytes, SHA-256 `2f3fa34214654fe40d49a8a4bea4a5b5bc3f1bfc02b0742009dcfb9706a8159d`, with 53 members containing 68,061,362 original/review payload bytes plus the manifest. The manifest SHA-256 is `f91bfa5a24120ef0fc2a11f723bec25b39220d41bf266c4bda1b1b119c05b3dc`. The archive was reopened, CRC checked and every member compared with its source bytes before publication.

The verifier is read-only and performs no inference or native World execution. Its declared scope is independent artifact and receipt review. Specialist A authored the Provider implementation and performed this independent package/source-custody review; separate B/C reviews cover Provider source boundaries, host lifecycle and full campaign evidence. No merge, readiness promotion or production-default activation is implied.
