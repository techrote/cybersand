# Independent Windows evaluator custody review — e536

This review concerns only the successfully completed e536 campaign and its
downloaded Windows evaluator. It preserves a qualified baseline while the later
responsiveness candidate receives its own fresh qualification. It does not
transfer Windows acceptance to the asynchronous Apply implementation.

## Exact delivered identities

[Campaign 45541065622](https://github.com/techrote/cybersand/actions/runs/45541065622)
reported success for application-source qualification, Linux native/displayed
qualification, and Windows qualification plus installed evaluator. The package is
source `e536d128f85e948223b25e13931a7a801faf956d`, tree
`61d38ec119665270a9fb4eea9ae78836348d7092`, and remains **Draft/HOLD**.

| Item | Identity |
| --- | --- |
| Evaluator artifact | 14991526130; 94,375,955 bytes; SHA-256 `afd23c48162d0af1fb560741c6a9f1d77b1e7ebcc6ea5f6f9abd5e8c55036d12` |
| Downloaded evidence artifact | 14991291608; 11,942,803 bytes; SHA-256 `1d6e44d8d39317a440a8308d931f05326b3760b0d064d29fbb44a72abb9cc080` |
| Inner portable Windows ZIP | 95,569,515 bytes; SHA-256 `7b96dbf667cde0e222957e84f75dd88638d92241fa8fe4af82e6178623303d73` |
| Candidate manifest | SHA-256 `c2a2d574ce2e899e6f0e8ebbe93dc0f425ea679e46769c0bc33b9e38471fb3fc` |
| Immutable inventory | 1,195 manifest-listed files, all independently rehashed and matched |
| Archive inventory | Exactly the listed files plus the manifest; no unmanifested payload |

Both outer ZIPs and the portable ZIP were downloaded and inspected. The sidecar
digest agrees with the independently computed inner digest. All ZIP CRCs passed.
The uncompressed portable inventory is 224,568,180 bytes.

## Runtime and source custody

| Runtime | Independently matched SHA-256 |
| --- | --- |
| Godot 4.7 Windows GUI | `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` |
| Godot 4.7 Windows console | `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c` |
| CyberSand native Windows | `668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e` |
| Rapier Windows | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |
| Visual C runtime | `d5e4d9a3e835fa679450145d6a7d94e36573a509317111904d9b3712c30d9066` |

The engine version is 4.7.stable.official.5b4e0cb0f. The native DLL is the previously
qualified source-matched runtime from
`c53fd6f9d3d0f2b3f39396c7e605654f65c17299`. All 105 recorded native build-source
input digests were independently compared with the canonical e536 Git blobs;
none differed. This verifies source continuity for that runtime without
inventing a new native build.

The package's headless and displayed qualification JSON files are byte-identical
to the originals in the downloaded evidence artifact. Their source/tree and
runtime hashes agree with the actual payload.

## Original application and installed-launch evidence

All fourteen original collaborative process logs were independently re-read,
matched to their reported SHA-256, checked for script/parse/resource failures,
and reparsed to exactly the result objects in the packaged qualification
receipts. These are the original Windows executions, not local re-executions.

| Case | Headless checks | Displayed checks |
| --- | ---: | ---: |
| Owned transport | 155 | 155 |
| Authoring proposal | 80 | 80 |
| Creative cohort | 251 | 251 |
| Native authoring scenarios | 739 | 779 |
| Collaboration authority | 39 | 39 |
| Collaboration session | 182 | 202 |
| Collaboration workspace | 93 | 94 |

Every listed case has zero failures, a successful process exit and zero genuine
model calls. These seven-case receipts predate the two new asynchronous Apply
tests and do not qualify that later feature.

All 73 packaged native example files match their original displayed-fixture
bytes, their original receipt digests and the immutable manifest. The actual
installer receipt has exactly nine Setup labels, and every installed Setup
digest matches the corresponding packaged editable native result. The complete
label-to-digest mapping is retained in the machine-readable review.

The original installed-result receipt reports `actual_launcher: true`,
Windows display, no automatic model requests and passed status. The original
installed-execution receipt records exit 0, no timeout, and the 240-second
watchdog. The distinct runtime-module probe independently observed the expected
GUI engine, native DLL, Rapier DLL and Visual C runtime inside the freshly
extracted package, with their exact hashes. Its later owned-process cleanup is
explicitly recorded; that probe's deliberate retirement is separate from the
ordinary launcher's successful exit.

The launcher scopes APPDATA and LOCALAPPDATA to the package, imports resources
when required, records source identity and opens the ordinary Workbench owner
evaluator. It does not configure a provider or send a request. The actual
nine-start installer copies only absent package-local Setup files.

No populated profile, profile-local, diagnostics, journal, provider-configuration
or private-key payload paths were found in the ZIP inventory. This is an
inventory/custody statement; source files containing synthetic credential-test
fixtures are not owner secrets. The original launch diagnostic explicitly
reports `automatic_requests: false` and `contains_provider_config: false`.

## Preserved hosted limitations

The pristine installed e536 diagnostic retains:

- Workbench ready at 56.265125 seconds.
- Maximum adjacent startup frame gap 51.259956 seconds.
- Maximum visible-idle frame gap 208.780ms.
- Completed teardown in 386.269ms.

The software-rendered Windows host used ANGLE over Microsoft Basic Render
Driver. Its original Workbench log contains WASAPI initialization errors followed
by an explicit fallback to Dummy audio. These are retained observations; this
review does not call the launcher log error-free, claim a cold-start fix, or
substitute hosted execution for the owner's physical Windows/NVIDIA acceptance.
The owner-reported absent-LM-Studio-listener hardware acceptance remains pending.

## Independent review evidence

[Review originals](e536-windows-independent-review.zip) are 313,875 bytes,
SHA-256
`17db4fdf613125a0e01c09923939cd0ee37f717ce1dd12c2389f9a2138b839b1`.
The archive contains 38 members including its manifest and 1,040,768 original
payload bytes: package manifests/provenance, original qualification receipts and
process logs, actual installed-launch/module/Setup receipts, and independent
hash/source comparison records. Every archived member was read back and hashed.

[Review manifest](e536-windows-review-manifest.json) SHA-256:
`d2442089103fe229cc76949b7de209eb2a959c1e5255ee5c9a4dd666da3cafd4`.
[Machine-readable receipt review](e536-windows-receipt-review.json) includes every
original log digest and all nine installed Setup identities.

This independent review ran on Linux against downloaded immutable Windows
artifacts and their original CI observations. It did not run a local Windows
executable or claim physical-device testing. The owner evaluator and full
evidence downloads remain the GitHub campaign artifacts identified above.
