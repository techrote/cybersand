# Superseded Art traffic regression fixtures

These scripts are historical source witnesses for the **linked, cross-session Art
conversation** contract accepted in PR #681 and the later durable-history
receipt programme. On 22 November 2026 the owner explicitly retired that
product behaviour and replaced it with **one independent JSONL audit per
Workbench game session, no conversation reopening or persistent model context**.

The three fixtures previously required unavailable saved conversations to block
Send and required historical conversations and pending native-history journals
to rehydrate on every Art reopening. Such assertions are incompatible with the
new owner contract and must not be run as production qualification.

They are copied unchanged here, retaining their Git blob identities. Their
original native/parser evidence and audit remain in Git history. The active
`godot/tests/test_art_session_log.gd` tests the replacement contract. Existing
`test_art_traffic_integrity.gd`, `test_art_history_receipt_identity.gd`,
`test_art_undo.gd` and native PAINT tests retain separate legacy-parser,
receipt-integrity and native edit coverage. No historical JSONL or owner data
was migrated or removed by the implementation.

Do not revive legacy cross-session replay to satisfy these retired assertions.
A future archive-inspection utility may consume the read-only parser without
connecting archived content to a live game session.
