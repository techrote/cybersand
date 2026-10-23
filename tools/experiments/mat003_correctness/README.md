# Isolated eight-map correctness apparatus — implementation in progress

Source contract: docs/research/mat003-correctness-only-plan.md at reviewed commit
1bbbec9580f9a3e9e6a6f9136503f873ede0f254. Production has no includes or build
routes into this directory. R16 is opaque; R16-T1 is not implemented.

This directory is NOT admitted or qualification-complete. No build/run workflow
is installed. No qualification was executed. The readback completion function
fails closed while independent World decoding and source-bound transition proofs
remain incomplete; do not remove that hold based on collector summary booleans.

Implemented source pieces:
- maps.hpp: all eight numeric/compact/lane maps, safe memcpy head, canonical bytes,
  checked raw field domains/capabilities, epoch-only clear.
- oracle.py: independent explicit positions, logical encoding/decoding and partial
  operation/refusal expectations, without candidate imports.
- world_adapter.hpp / overlay.py: generated World-only selection, frozen S1 input
  checks, typed counters, observers; accepted inputs remain unmodified.
- probe.inc / world.cpp: complete carrier/temperature record stream, unchanged S1
  common semantic record and explicit World scalar state, natural/prepared real
  tick entry, sequential event/reference roles and endpoint identities.
- matrix.py: proposed152-case platform matrix and safety bounds.
- storage.cpp / readback.py: deterministic storage trace and independent chained
  operation readback. This initial schedule does not yet satisfy every coverage
  obligation of the reviewed plan.

Remaining implementation gates include full source-symbol owner inventory and
World metadata export/readback, configuration identity, independent R transport
model, neutral mutation coverage, refusal/lifecycle fixtures, negative verifier
fixtures, complete named storage boundary/copy/swap/U coverage, a resource-enforcing
sealed collector and exact source/platform/binary admission. Existing S1 common
records intentionally normalize epochs and omit R/U: they are a control projection,
not a complete endpoint proof. Exported additional files must be independently
parsed and cross-checked before any apparatus completion claim.

All program execution, including compiling/running these candidates, remains
held pending separate authority and completed independent source review.
