# AMBIENT-001: final CI and runtime integration review

**Specialist B approves candidate
`26317ada6a1f40637e96d732ec28f55c70cd53a2`, tree
`984c94a6e312261120dffb4ad3625a6030d2f359`, for the authorized opt-in integration.**
All seven applicable current-source workflows completed successfully. The
machine companion preserves their exact source, run and observed attempt.
Physical owner acceptance remains outstanding; ordinary defaults are unchanged.

The actual GDE PR checkout is
`a83b44dee96b6db382e8cd9def727c963a979eaf`, whose tree equals the candidate and
the independently reviewed local `d64b3886`. Linux executed at original attempt
1: 354 cases across 25 shards, with original reducer job `139609596970`.
Windows executed at recovery attempt 2: 331 applicable cases across all 24
fresh shards, followed by successful strict reducer `139617120367`.

## Actual producer and consumer custody

The fresh Windows producer `139610280135` ran from 00:39:28 to 00:43:50 UTC on
26 November. Its Rapier pull completed on the first attempt in 1.870 seconds.
Original artifact `15075334588` contains the complete sealed transport manifest,
the original acquisition commands/logs, and the actual 9,987,072-byte DLL with
SHA-256 `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
Its manifest is bound to source `a83b44de`, run `45727973062`, attempt 2;
manifest SHA-256 is
`5278f661af436c597c4266de6154978161f9a93a9c6df9954fafc17329052353`.

Source-built native artifact `15075818811` contains the actual 5,820,416-byte
Windows DLL, SHA-256
`f2ba56b678ed582489c72b4baf41f37ead84743c6a8bcb9794d6e1c9edbc81bf`.
All 105 recorded native source inputs independently match the reviewed resulting
tree. Its recorded godot-cpp revision is
`101ae38034304346a46ea9ea84ae156d3e860496`, with the pinned LLVM-MinGW archive
SHA-256 `cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65`.
No branch-retained native binaries were overwritten or published.

All 24 original Windows consumer ZIPs (4,706,982 compressed bytes) were downloaded
and independently checked against their GitHub artifact sizes/digests and ZIP
CRCs. Every installation receipt uses the same exact producer manifest,
source/run/attempt and DLL bytes. Every original executed-case log hash was read
back from the archive. All reports show natural completion, zero exit, strict
success, identical 1,137 execution inputs, and the same 105 native inputs.
The union is exactly 331 assigned cases with no duplicates or omissions.

The successful Palette producer, actual Linux and Windows consumer receipts,
and complete six-cohort/19-case strict readback are independently preserved in
`lfs-fanout-hosted-263-attempt1.json`. Native, documentation, Art, Architecture
and the source-scope advisory are separately recorded in the final packet.

## Recovery scope and truthful execution attempts

The original Windows producer failure remains failed: its service timeout and
subsequent HTTP 503 produced no usable manifest or native candidate. The lead
registered and reran that producer and all its descendants, without changing
source or replaying successful Linux execution. Every fresh Windows input and
report belongs to attempt 2.

GitHub carries completed Linux jobs into the attempt-2 API view with new job
identifiers and `run_attempt` metadata. These are not new Linux executions.
Specialist C independently compared the original and carried Linux reducer's
timestamps and byte-identical logs. Art has the same distinction: its original
Linux execution is attempt 1, while Windows job `139606815128` freshly ran and
passed at attempt 2. The original Linux Art log is 53,469 bytes, SHA-256
`f388d2c679df9b79e458f0fe4f653c6b6c68644fabd344e6559348edab1d17aa`.
No runner time or platform evidence is counted twice.

The two failed prior `120f0d08` campaigns, first `0c1152c2` campaign, inherited
accepted-main acquisition failures and all successful original observations
remain separately retained. This final decision relies on the actual complete
current-source gates and byte custody, not on relabeling any original failure.
Post-merge main checks and the requested accepted-main Windows package are the
next distinct release-engineering steps.
