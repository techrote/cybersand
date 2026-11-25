# Isolated Conversation Apply phase instrumentation

This measurement-only fork adds monotonic timestamps around the existing successful `ArtBatchPanel._apply_conversation_edits` phases and prints one bounded numeric receipt. The production operations, order, refusal branches, complete audit, checkpoint, assignment and native-history separation are unchanged. It is not proposed for the principal application.

The unchanged inherited `run_art_workbench_final.py --group conversation-apply` executes the ordinary editor, real TextEdit replacement and actual Apply button. It uses the same 16,769,024-byte synthetic message and expected complete changed-message SHA-256 `ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a`. Its post-exit verifier checks the complete redacted audit. No provider request is sent.

The source parent also contains the separate read-only startup phase apparatus; those three files do not execute in this inherited Apply group. The panel's functional parent is Art 2743. Record this fork's exact commit/tree/panel hash, the actual process log, source/runtime receipt, complete audit verifier and the `ART_APPLY_COMPONENT_PROFILE` marker. A Linux headless observation cannot attribute the separate hosted Windows 619ms sample or establish a displayed improvement.
