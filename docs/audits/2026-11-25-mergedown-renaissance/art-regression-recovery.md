# Art resulting-source regression recovery

Implementer and investigator: Specialist C. **Specialist A independently
approved both fixture/runner commits; physical owner acceptance remains pending.**
The source repair is seven runner/test files, with no production script, native
input, runtime binary or watchdog change.

## Sources and original failures

Current Ready predecessor #773 is
`1c2d084cba2e44e455f6ffe7d269007519829102`. Its two failed workflows are the
[Art campaign 45522038721](https://github.com/techrote/cybersand/actions/runs/45522038721)
and [GDExtension campaign 45522038886](https://github.com/techrote/cybersand/actions/runs/45522038886),
attempt 1. Job-level error excerpts and exact links remain in
`art-original-failures.json`.

The consolidated successor #780 at
`d503d824aac4128968f7dfba5dccd540c3c07b59` does not by itself repair these broad
regression defects. Untouched successor source and actual source-matched Linux
native bytes independently reproduced the relevant failures before any edits.

| Failure | Original evidence | Finding and repair ownership |
| --- | --- | --- |
| Request preparation and admission report invalid URL engine errors despite exit 0 | Windows shards 14/15 and Linux shards 12/13; reproduced at d503 | Real strict-runner diagnostics from intentional negative fixtures. A owns production asynchronous URL admission; C adds no stderr exception. |
| Local-close test gets `/chat/completions` without a host and loses expected requests | Windows shard 22 and Linux shard 16; reproduced at d503 | Generic discovery invoked a fixture that needed the dedicated Python loopback server. C supplies the same authoritative server through the shared runner. |
| Three native material assertions fail in combined authoring | Windows shard 3 and Linux shard 14; reproduced at d503 with complete repository examples | Deterministic fixture emits request 1 while current provider serial is 0. Correct production freshness guard rejects it. C binds the fixture serial and preserves stale-response rejection. |
| Idle Art allegedly creates another file | Windows shard 18; reproduced at d503 with one pre-existing unrelated archive | Test hardcodes one total directory entry. Fresh isolated d503 passes. C compares complete sorted before/after directory membership while retaining archive-content safeguards. |
| Fresh-process combined reopen demands previous conversation text | Independently discovered after the first three repairs | Accepted session-only Art intentionally starts empty. C verifies authored persistence, empty new conversation, unbound old audit, and byte-identical retained old audit. |

The first local standalone staged-project run lacked repository-relative
`examples/worldgen`; it failed generator discovery. That was corrected before
attributing any product failure. The complete-resource run reproduced the exact
three hosted native-cell assertions. This staging failure is not presented as
an application regression.

## Implemented repair

Commit `23fd85d9d9d8af14b81822ca942b3274079e8595` extracts a bounded
`loopback_fixture` context from the existing local-close tool. Both the focused
qualification tool and generic Linux/Windows runner use its existing Handler.
The child still executes the original Godot script, process watchdog and strict
diagnostic handling. The fixture binds only loopback, overrides any inherited
external endpoint for this one test, and closes after success or failure.
Both platforms now record the helper among their source inputs.

The combined-authoring fixture establishes the current deterministic provider
generation before emitting its completion. It also asserts that Stop retires
that generation and then emits the actual stale identity. The production
provider serial check stays unchanged. Its native line, erasure, shared
transaction, Undo/Redo and late-response assertions are retained.

The session-log check records directory membership before constructing the idle
panel and requires exact equality afterward. It no longer mistakes evidence
from an earlier shard case for a new product write. Existing archive hashes and
the session-only contract continue to be checked.

Commit `83fbf6de58db8a3a09f15029625a0502b8be7017`, tree
`2f9fe125363d09c436c29e52de7bf2c46d360160`, then reconciles the fresh-process
combined fixture with the already accepted session-only Art behavior. Authored
geometry, actor configuration, equipment, solver settings and provider
preferences still persist. Conversation and execution authority do not resume.
The fixture records and independently checks the prior audit's exact hash.

## Actual validation

All application proofs used clean committed source, pinned official Godot 4.7,
the unchanged source-matched native library
`a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`, and the
unchanged Rapier library
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
Native/Rapier input checks cover 105/four files. Each project was staged with
complete repository examples and a fresh disposable profile; the contaminated
archive case deliberately adds one known independent prior file.

| Exact repaired source | Actual case | Result |
| --- | --- | --- |
| 23fd85d9 | Generic runner local-close, real HTTP fixture | 81 checks, zero failures, 6.313 seconds |
| 23fd85d9 | Session log with a prior unrelated archive | 35 checks, zero failures, 4.738 seconds |
| 23fd85d9 | Combined authoring | 193 checks, zero failures, 15.348 seconds |
| 23fd85d9 | Combined fresh-process reopen | Original stale conversation-restore assertion fails; retained as intermediate evidence |
| 83fbf6de | Combined authoring | 193 checks, zero failures, 17.114 seconds |
| 83fbf6de | Combined fresh-process reopen | 51 checks, zero failures, 10.971 seconds |

Python execution tests: **93 pass, one explicit Windows-only observation skip**
in the 94-method sharding suite; **22 pass** in the retained Windows harness
suite. New controls make actual loopback POSTs for 200 and 404 responses, retain
nonzero child exits as failure, and verify that no listener survives either
outcome. The helper's source bytes participate in existing mutation controls.
No mandatory test is removed, timeout extended, or diagnostic suppressed.

## Unresolved gates and preserved negative evidence

The original #773 Windows displayed request-preparation artifact
[14981748735](https://github.com/techrote/cybersand/actions/runs/45522038721/artifacts/14981748735)
was independently downloaded and its complete ZIP digest verified:
`a424e3a5c354291576f81bf77f07e0074253492a2964b64de7896e1acc4d8fde`.
Its near-limit full-context case records a **3,860,552 microsecond maximum frame
gap**, failing the unchanged two-second requirement. This is a performance
failure, not one of the fixture defects repaired here. The original report and
its digest are preserved in the machine-readable recovery record. A later
passing successor campaign does not erase this measurement or prove this patch
fixed it.

The original asynchronous invalid-scheme request-preparation and admission
cases now pass independently on the reconciled source. The
[subsequent integration review](art-architecture-independent-review.md) records
those results, actual production mount/native execution and the separate PNG
repair. Malformed authority/port URL controls and broader resulting-source
qualification remain required. Existing genuine
model creative acceptance and physical Windows/NVIDIA acceptance remain
outstanding. Nothing in this repair authorizes a mainline merge of Art.
