# Independent SOL281 native and readback-guard reviews

This packet preserves two read-only reviews by `/root/implementation_review/native_review`.
No source changes, remote mutations, or new test execution occurred while preserving this packet.

## Evidence origin

- `native-review.json` binds the original observer/geometry review to publication `3ac7701f013452c94a8c08b0746e1b13523e7234`, source-identical reviewed paths at executed `5944c13079356fedf96da78c78e83b3898379fee`, and six file hashes.
- `readback-guard-review.json` binds the final seven-file readback-failure patch to its stable reviewed bytes on that base. The final commit did not yet exist when those bytes were reviewed.
- Files under `transcripts/` are faithfully transcribed excerpts from the reviewer's tool history. They are **not original-byte process logs**. No failed command was rerun to recreate an original log.
- `inspected-evidence/sol281-readback-fences.log` is the available local log copied without modification from the implementing agent's `/tmp/sol281-readback-fences.log`. This reviewer inspected that actual 135-check log; this reviewer did not execute that Godot run.
- `manifest.json` hashes every payload file in this packet. It does not hash itself.

## Results and limits

The native geometry reviewer independently executed the normal 6,817-check test and a sanitizer build. The initial sanitizer run failed because LeakSanitizer could not read `/proc/2/task` and cannot operate under ptrace. That result remains failed. A separate execution of the same unchanged binary with `ASAN_OPTIONS=detect_leaks=0` passed 6,817 checks with address/undefined checks active. **No local LeakSanitizer pass is claimed.** Diagnostic binaries are identified by hash in the JSON receipt but are not included as repository evidence.

The final guard review independently executed the 11 Python qualification-reader tests, inspected the production latch/consumed-sample code, and found two test defects that were corrected: misplaced indentation/scope, and a retry assertion that could pass after another post-application failure. The corrected retry requires `DuplicateOrOldContact`, `failed=false`, unchanged RID state and no additional readback call.

No remaining bounded implementation blocker was found in either reviewed scope. This does not qualify persistent embedding, restoration, human gameplay, default promotion or merge. Fresh exact-source host qualification remains separately owned by the implementation task.
