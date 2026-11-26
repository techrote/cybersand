# Independent review: same-attempt LFS runtime transport

## Disposition

Specialist A approves source `d64b3886f27a3a3ffa0415bc516db993a112e5f1`, tree `984c94a6e312261120dffb4ad3625a6030d2f359`, **for full resulting-source qualification**. Its implementation parent is `4bb903109321bdc343eaebcb3da86bfec19bd4dc`, built on `120f0d0825e1fcdf9ea1ea9d8d50a0d5b32735d6`. This independent review covers source semantics, workflow integration, and Python/synthetic adversarial controls. It does not claim a hosted campaign, Windows native execution, service availability, or owner acceptance.

## Engineering findings resolved

Independent synthetic controls found that the pre-finalization helper could return a transport PASS after a final manifest write exceeded the shared allowance. A 601-second induced seal completed under a 600-second budget and left a usable manifest. An analogous 301-second final consumer receipt under a 300-second allowance also returned passed. Original helper bytes are retained and hash-verified as `d05443156b7fc41867e1b75bc5652a156b582ed3d2f8584e99bf712837bd0dae`; because that implementation was still uncommitted, its exact reconstructed byte identity is preserved alongside the original observation receipt.

The lead added final-write deadline enforcement. Independent reruns at the final source now reject both cases. The producer retains `failed-manifest.json` and leaves no usable manifest. The consumer retains the late original seal, records canonical status `failed`, and raises before the next step can execute. Payload/acquisition originals remain available. No allowance was extended to make the controls pass. An intentionally resealed unknown acquisition schema also refuses.

The final prose correction removes a stale statement that Rapier is fetched in every shard. The documented operation now agrees with the workflow: acquire once in the producer, distribute a same-attempt artifact, and verify committed pointers plus actual bytes in each shard. The small Windows fixture follow-up canonicalizes TEMP paths before comparing identities; all rejection assertions remain intact.

## Source and workflow review

The manifest binds the exact source commit, run ID, and attempt. Each consumer derives its expected complete inventory from its own committed LFS pointers, rejects omitted or additional sealed files, checks acquisition command identities and original logs, verifies every object, and only then stages selected runtime files. Palette verifies all four retained platform/native/Rapier objects before choosing its own two. Invalid artifacts cannot fall back to a service download, another attempt, or another runtime.

GDE Windows retains its separate source-built native candidate and original native/Rapier checks. This change transports only its committed Windows Rapier dependency. Palette retains the existing runtime provenance, GL/ANGLE, capture, cache-lineage, and complete reducer gates. Producer and consumer helper sources are included in the existing custody scopes.

The Windows dependency slot remains ten minutes, split into five for artifact download and five for verified installation. Palette retains its independent dependency clocks and budgets the additional artifact step. Producer parent envelopes include moved acquisition and upload work. Godot/native case watchdogs, concurrency, and source/runtime inputs are unchanged. Retrying only failed consumers would lack a same-attempt producer artifact and must fail; the documented retry entry points include the producer and complete dependent chain.

## Independent execution and exact binding

All 140 relevant controls pass: 20 transport controls, 38 Palette controls, 22 Windows-runner unit controls, 47 Windows reducer controls, and 13 Linux reducer controls. These ran as Python tests on Linux; Windows-named test modules do not imply actual Windows execution. The initial complete run used byte-pinned inputs from `4bb9031`. The final follow-up changes only canonical prose and the temporary fixture path: all seven other measured inputs match the final commit exactly, and all 20 transport controls plus the separate adversarial probes were rerun on the final fixture. Before/after maps are unchanged.

The evidence ZIP includes every command output, source binding, independent probe script, original gap observations, exact original failed helper, and corrected outcomes. The machine register hashes every member and lists all ten committed source/documentation files. The final helper is SHA-256 `ebec1b0fc7634641695956f8a4c9b2748e45ddc7553d69755b476595e08231b3`.

## Remaining qualification

Actual hosted producer artifacts and consumers must complete at the same resulting source and attempt. Full ordinary application, native, platform, and graphical checks remain required before a merge. The original LFS service failures remain failed; reducing redundant service calls improves the acquisition topology but cannot guarantee service recovery. No gameplay or physical owner gate is waived.
