# Preparation registration addendum — 2026-09-12

Author: OpenAI assistant. This remains offline research, not issue acceptance.

The root scratchpad registered the initial studies before execution. The initial local run completed 22 tests after correcting one test expectation: 1/255 quantizes to zero at mass7 because 127/255 is below one half. The quantization formula was unchanged. The first failed log is retained outside committed source; the final report must retain this correction.

## Additional bounded checks, registered before execution

1. Source inspection of `native/include/cybersand/material_appearance.hpp` at `d39e31f03f2e39b0022d507b79fbee5c2439436d` confirms that Water currently projects raw state_a into its condition byte. Independently check a proposed normalized-byte projection for mass3..8, every legal mass, with exact integer arithmetic. Check endpoints, decode round-trip, and direct versus two-stage four-level presentation. Add a separately compiled C++20 arithmetic oracle and compare its rows with Python. This is not an engine change or ABI test.
2. The first abstract ownership exploration reached its depth-ten cutoff without violations. Retain those results and extend the same two-unit/two-slot model to depth64, with the same 60,000-state ceiling. Report whether the finite graph closes; do not interpret bounded graph closure as a proof about implementation, unbounded revisions, concurrency, topology, collision or liveness.

No timing speedup, production approval, motion-target admission or human preference is inferred from either check.
