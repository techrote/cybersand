# Actual ordinary Apply: isolated component timing

Instrumentation-only source `8ea23b5467702214d8f439cbea81990a02d425f1`, tree `ef9a44a8f1b443f0587604c17e64e89c915ecb8a`, retains the functional Apply method from Art 2743 and adds monotonic timestamps only. Stripping the explicitly named instrumentation lines reproduces the original function byte-for-byte; this equivalence was checked before evidence publication.

The inherited ordinary Workbench conversation-apply group ran unchanged in a fresh Linux headless process/profile: **22 checks passed, zero failures**. Real TextEdit input replaced the first character and the real Apply button committed the complete 16,769,024-byte conversation. Full SHA-256 remained `ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a`; the post-exit independent verifier confirmed its complete changed conversation in the original redacted audit, with zero provider requests and no native authoring change.

| Actual Apply phase | ms |
| --- | ---: |
| Flush edited 4096-character part into complete message | 36.601 |
| Full current/baseline guard | 7.762 |
| Typed conversation validation | 0.023 |
| Explicit provider redaction | 347.725 |
| Complete main-owner audit append | 288.351 |
| Checkpoint validation | 0.004 |
| Live assignment and hide | 0.314 |
| Instrumented total | 680.785 |
| Outer actual button interval | 681.146 |

The audit's existing receipt breaks its 288.324ms into formatting 164.287ms, writing 66.535ms, sanitization 2.608ms and other admission/observation work. The main redactor already caches an exact proven-unchanged large string under the identical credential set; the second redaction inside audit did not repeat the 347ms scan. Removing the explicit redaction would therefore move that first scan into audit rather than eliminate it, and could compromise live credential isolation.

These measurements justify investigating finite pure-value background redaction and encoding while preserving main-owner complete append, authenticated prepared values, secret/revision fences and commit-point adoption. They do not authorize dropping audit bytes, trusting arbitrary sanitized flags or modifying native scheduling. The sample is local Linux headless; it does not independently attribute the separate hosted Windows 619ms sample.

[Complete evidence archive](apply-component-evidence.zip), SHA-256 `ade1732e7c6673096cf8cd0c78b2c26536566fcb535391fc469d223e0f6203a9`, 41,164 bytes, 13 members, 33,551,565 uncompressed payload bytes plus manifest. It includes the entire original redacted audit, original process log, provenance, report, audit verifier and fixture metadata. The [manifest](apply-component-manifest.json) pins all members; ZIP CRC and every member SHA were independently checked.
