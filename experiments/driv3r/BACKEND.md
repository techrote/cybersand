# Stage A resident decision backend

`backend.py` serves the ordinary single-choice subset of the official System One
API. It is a decision provider with no native painting authority. The episode
controller owns candidate registration, native freshness, permissions and budgets.
The final Stage A report owns actual source-qualified execution outcomes; the
backend's presence alone does not establish inference or native execution.

## Official identities and licence

The committed [pins](pins.json) select **LiquidAI/d1-2B-GGUF Q8_0**, revision
`4a181094d1b6addfaa3a0956f78e7ab2aa406a0c`, file
`d1-2B-Q8_0.gguf` (1,846,240,576 bytes), SHA-256
`073313d92b53b0ac8193db6e906cb3c78a98183d244b15b7b8f5426115c6738c`.
The quantized repository identifies `LiquidAI/d1-2B` as its base model. The
inspected reference revision is `652f920e544ea37f81e4b0ce89b81d4ed0da90b1`.

Both official repositories provide **LFM Open License v1.0**, not an Apache or MIT
model licence. Its commercial-use section specifies a US$10 million annual-revenue
threshold. Redistribution conditions include supplying the licence and preserving
the relevant notices. Acquisition retains the exact pinned licence as
`MODEL-LICENSE.txt`; the model is not committed to the CyberSand repository or
included in the evidence package. Stage A is the owner's bounded research
investigation, with no model redistribution or new commercial deployment claimed.
The licence hash is independently pinned alongside the model identity.

The runtime is the official Linux x64 CPU archive for **llama.cpp b11960 / v0.8.0**,
commit `8642541b255bfb5dc39cd351a178be09013a55d6`. Its actual version output is
`0.8.0-dev (build 11960, commit 8642541b2)`, built with GNU 11.4.0. The archive has
22,686,210 bytes and SHA-256
`31cc3a6bc638ac6c48dc4b1b74888f1eaadf3d14227c1e5f67daf9a49541d97a`.
The MIT runtime licence is retained in the extracted bundle. Executable and every
bundled library are individually pinned from this hash-verified official archive.

Sources are the [official quantized model card](https://huggingface.co/LiquidAI/d1-2B-GGUF/tree/4a181094d1b6addfaa3a0956f78e7ab2aa406a0c),
[reference model repository](https://huggingface.co/LiquidAI/d1-2B/tree/652f920e544ea37f81e4b0ce89b81d4ed0da90b1),
[pinned runtime release](https://github.com/ggml-org/llama.cpp/releases/tag/b11960),
and [pinned server decision implementation](https://github.com/ggml-org/llama.cpp/blob/8642541b255bfb5dc39cd351a178be09013a55d6/tools/server/server-decision.cpp).

## Typed semantics

The endpoint is `POST /v1/systemone`. The host supplies a text state and a mapping
of named questions. A single-choice question has `type`, `instructions` and a
`criteria` mapping from stable candidate identifiers to descriptions. Its answer
contains `type: "choice"`, `choice`, `confidence`, and the probability of **every**
candidate. Usage records input tokens and **zero generated output tokens**.

For this d1 model, the chosen candidate is the maximum-probability candidate and
confidence is that candidate's probability. The adapter verifies finite values,
normalization, the exact original candidate set, argmax/confidence consistency,
question names and token usage. Option order is preserved in the request but is
never interpreted as an action identifier. Raw response text is retained as well
as parsed JSON; duplicate response keys and nonfinite numbers are refused.

Named questions in a request concern the **same input state**. They do not receive
the result of a previous question, and they do not constitute a sequence of
native actions. `inference_smoke.py` explicitly exercises two named questions over
one state without turning their answers into a dependent plan.

The official runtime also implements `noul` and `score`; Stage A's adapter exposes
only single choice. For lfm3-d1, `noul` is P(true); `score` returns the median level,
and its confidence is the maximum category probability. This differs from the
expected-value score rule used by some other models in the same runtime. Do not
generalize response semantics from the generic TypeSafe examples.

The inspected reference `api.py` and `modeling_d1.py` provide broader functionality,
including multi-select and other typed heads. The official GGUF documentation
excludes multi-select, extraction, estimates and boxes. In pinned b11960,
`parse_questions` does not inspect the `multiple` flag; sending it can silently
behave as a single-choice request. The host therefore rejects **all** unsupported
question fields before transport, including `multiple`, even when false.

The reference applies the revision's calibration and its own question/set
attention machinery. The quantized backend has its own numerical path. Q8 and
the reference are recorded as distinct backends; no exact probability parity is
claimed. The reference code and model identity were inspected, but a reference
CPU execution is deferred: the official CPU example uses float32, adding a full
reference load and separate dependency environment to a stage whose primary gate
is a resident Q8/native vertical slice. No accelerator benchmark is substituted
for measured CPU performance. The separately identified Q4 pin is informational;
the acquisition command cannot silently choose it.

## Lifecycle, capacity and custody

Acquire with:

```sh
python3 -m experiments.driv3r.backend acquire \
  --runtime-dir /absolute/runtime-directory \
  --evidence /absolute/evidence-directory \
  --timeout-seconds 1200
```

The command writes `runtime-manifest.json`. Model and archive bytes are checked
against the committed hashes and sizes, including cache hits. Failed partial
downloads and acquisition receipts remain distinguishable. Supplied identity
metadata cannot replace the committed model, executable or library hashes.
An existing valid runtime bundle is verified and reused without changing its
files. A dirty or incomplete existing bundle is refused. A fresh bundle is
extracted into a staging directory, verified, then atomically published. This
avoids rewriting libraries already mapped by a resident process.

`ResidentDecisionBackend(binary, model, evidence_dir, ...)` owns one process group
and one outstanding request. `start` verifies every bundled runtime file before
spawn, rejects unexpected files and paths escaping the bundle, restricts the
loader search to the pinned bundle, and removes inherited loader and llama/GGML
configuration. Startup records actual loaded system-library hashes from Linux
process mappings. System libraries are measured host dependencies, not bundled
llama libraries. The process has an authenticated loopback-only endpoint and a
unique model alias; startup verifies the alias before accepting the instance.

The default uses two compute threads, one slot, a 4,096-token context and a
2,048-token logical/physical batch. Both startup and each request have bounded
deadlines. Startup's deadline includes identity checks. Text-only input is
bounded to 32 KiB, eight named questions and 32 options per question. A request
whose rendered prompt does not fit the runtime's batch/context is a failure; the
adapter never truncates it or reissues a different state to manufacture an answer.
Pinned b11960 reports a prompt exceeding its physical batch as HTTP 500
`server_error`, with an explicit token-count/capacity message. This is an upstream
error-classification limitation, not a clean HTTP 400 client refusal. The smoke
verifier recognizes only that exact capacity-message shape, requires no decision
answer, preserves the original response and then checks a valid request on the
same resident process. Other HTTP 500 errors remain failures. The initial smoke
expectation of HTTP 400 failed and remains retained as development evidence.
Media, tool servers, arbitrary completion sampling and network model loading are
not enabled by this adapter.

Each call retains the exact state/questions, original typed response, request
sequence, process/session identity, model/runtime identity, latency, errors and
Linux RSS/peak-memory/CPU counters. Backend errors retain their original response.
Timeout or cancellation retires and terminates the owned process group. Any
arriving transport result is recorded as discarded evidence; a retired backend
cannot restart or supply another valid decision. Context-manager exit reaps the
process, removes its temporary credential and records shutdown.

Offline tests use a conspicuously synthetic local HTTP fixture and patch the
committed pins **inside the test process only**. There is no production fixture
bypass switch. They qualify parsing, transport and ownership regressions and do
not count as model inference. The frozen real inference smoke leaves the caller's
resident process alive so subsequent native episodes use the same loaded model.

## Retained development defect

A development acquisition recheck originally re-extracted an already verified
runtime into its existing directory. An overlapping diagnostic model process made
the executable write fail with `ETXTBSY`; earlier identical library files could
already have been rewritten. That failure and the diagnostic scope are retained
in the evidence package. The corrected installer performs read-only reuse and
refuses dirty bundles, with dedicated no-write and atomic-publication regressions.
The affected diagnostic run is not promoted as final runtime qualification.
