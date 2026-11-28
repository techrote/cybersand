# Third source: native authority and hosted Windows evaluator

**Draft/HOLD.** Candidate `c2f8a73d34448bc1496ecd84bca02f0812c80d27`, tree
`351b947a50ce054361660eba9379006122527547`, is an executed qualification source,
not the selected final architecture. [Run 45452580606](https://github.com/techrote/cybersand/actions/runs/45452580606)
retains the distinct results below. Its renderer job failed before any font or
startup process, and that failure is not rewritten by the corrected reader.

## Native material and sanitizer authority

The source-exact [native authority receipt](final03-native-authority.json) binds
artifact 14950189219, both exact commands and retained raw
[normal](final03-native-normal.txt) and [sanitizer](final03-native-sanitizers.txt)
logs. Normal and scoped ASan/UBSan execution each passed 192 general native and 34
Wave tests, plus 50 body-boundary runs totaling 6000 ticks. Normal execution also
passed 47 spill tests and the material baseline. The actual Empty-storage
diagnostic was compiled in; all 153 lifecycle checkpoints match at one and four
workers in both normal and sanitized builds.

Leak detection was explicitly disabled; no LeakSanitizer or ThreadSanitizer
result is claimed. These tests establish native authority/correctness within
their declared cases, not ordinary Workbench timing. The separately verified
[four-runtime inventory](final03-native-runtime-inventory.json) covers all 105
committed native inputs per runtime, build drivers/logs, compiler and dependency
identity. Production runtime provenance and LFS binaries remain unpromoted.

## Extracted stock-engine Windows evaluator

The [delivery artifact](https://github.com/techrote/cybersand/actions/runs/45452580606/artifacts/14952245528)
contains `CyberSand-PUBPRES-PLAYABILITY-FINAL-001-c2f8a73d3444-Windows.zip`.
It is a source/runtime-verified interactive evaluator whose hosted packaging,
launcher, authoring, persistence and collection gates passed. It is not a
physical playability acceptance result.

| Exact delivery identity | Value |
| --- | --- |
| Outer GitHub artifact ZIP SHA-256 | `26c4ca809ad2f95c6ed30f92cb9f70920941b5733b1e7062bf42ad5cb0088f7e` |
| Inner evaluator ZIP SHA-256 | `56a9218fe7e041abea7941b9866114b0d96514abda6e5c40b308ac00b76c3b01` |
| Inner ZIP bytes | 102,830,043 |
| Exact original manifest SHA-256 | `0288861763665cd40f2b3c950536d5aa3ccb6ffa2ad60420b6e2b7b230b56abe` |
| Manifest-declared files | 2533, plus manifest and checksum |
| Candidate native DLL SHA-256 | `1cdcbf4f72204d79b22d1a9551e46f9ccf02f6785d3141503e90e27feda28f1b` |
| Frozen-control native DLL SHA-256 | `505c766c6003b9d7c1e3acdee9331527210ba09a149a1588de32bf877ee3bb40` |
| Official Godot 4.7 GUI SHA-256 | `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` |
| Rapier Windows DLL SHA-256 | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |

The [complete custody record](final03-evaluator-custody.json), original
[manifest](final03-evaluator-manifest.json) and independent
[source projection](final03-evaluator-source-projection.json) verify every ZIP
member/CRC/hash and all application/tool source bytes. The exact original CRLF
manifest is retained without Git text normalization. Source C has 1232 committed
project files and D has 1224, with explicit independently built runtime and
canonical recipe additions. No unexplained source replacement or unqualified
LFS pointer is admitted.

The separately recovered [hosted evidence artifact](https://github.com/techrote/cybersand/actions/runs/45452580606/artifacts/14952210595)
contains nine actual shipped-command launches: candidate ordinary and reopen,
Wave 512/1024/2048, Mixed 2048, frozen-control ordinary and reopen and the explicit
three-slot diagnostic. All exited successfully under actual Windows Job process
ownership. Source/runtime refusal, unknown-scene, changed-profile and unqualified
Separate requests were rejected. All seven profile identities and fresh reopen
PIDs are joined to the exact package.

The actual shipped collector produced a verified 125-member archive;116 members
join retained evidence byte for byte and nine collector-only profile logs match
the corresponding startup terminals. Native authoring passed 208 checks, and a
fresh graphical reopen passed 65, preserving the full prepared-material digest
`3f36a472fc70c61c9df71f965f6d5ba061ede71633fb79af31ea6fc9c203be2e`.
The [independent execution review](final03-evaluator-independent-peer-review.json)
and [portable read-only audit](final03-evaluator-independent-reader.py) retain
all process, command, artifact, collector and persistence joins.

Hosted launches deliberately used ANGLE with Microsoft Basic Render Driver.
They do not exercise the launcher's normal native OpenGL/WGL path on a physical
NVIDIA system. Startup at native tick 0 and static screenshots provide no
sustained-progression or temporal-trail evidence. The original second evaluator
with its failed optional Separate engine remains a distinct unqualified artifact.

## Owner procedure and remaining physical acceptance

1. Extract the entire inner evaluator ZIP into a fresh writable folder. Keep its
   manifest and checksum; the launcher verifies source/runtime files automatically.
2. Open **Open Wave 512.cmd** or **Open Workbench.cmd**. Representative starts are
   paused. Use **Play / Pause [P]**, select the flyer, then fly and change direction
   while Follow is active. Keep the console available.
3. Repeat on the 1024 and 2048 starts, then Mixed 2048. Paint and erase obstacles
   during motion, switch actors, and check collisions, material freshness, camera
   behavior and any perceptible freezes. Record duration and observations even
   if render FPS appears high.
4. Use **Save start [Ctrl+S]**, close the process, reopen the same command and use
   **Load start**. This restores authored material/actors; it is not a checkpoint
   of evolved Water, live velocities or simulation time.
5. For an instrumented pass, use **Engine Lab → Measure while I fly** and
   **Trace poses: manual**. Repeat a comparable ordinary pass without these
   observers so their cost is not silently ignored.
6. Write notes in `Runs/OWNER-ACCEPTANCE.md`, close Workbench and run
   **Collect Results.cmd**. Retain the resulting ZIP and SHA-256 sidecar from
   `Runs/Reports` with Windows version, actual GPU/driver and display settings.

Physical Windows 11/NVIDIA acceptance still requires native OpenGL initialization,
actual owner/executable verification, sustained small/medium/large mixed gameplay,
independent completed-step tails, visible pose/material freshness, input response,
Follow, painting, multiple actors, collision and save/reopen observations. Any
future custom engine requires its own equivalent extracted evaluator gates.
Hosted software rendering cannot discharge those requirements, and nothing here
authorizes Ready promotion, merging, production activation or release.
