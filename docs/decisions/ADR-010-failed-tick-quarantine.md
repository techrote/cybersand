---
title: ADR-010 — Quarantine failed ticks until reset or replacement
status: Current
document-kind: decision
scope: Issue 1 failure/recovery choice for the in-place native solver and its desktop/Web owners
canonical-for: [decision-failed-tick-recovery]
last-reviewed: 2026-11-24
related-documents: [../architecture/simulation-tick-and-threading.md, ../reference/interfaces-and-message-contracts.md, ADR-004-interest-region-and-reconfiguration.md]
---

# ADR-010: Quarantine failed ticks until reset or replacement

## Decision and authority

**Approved choice, Current implementation:** after a tick throws, stop that World
until explicit clear/reset or validated replacement. The owner delegated this
choice to engineering judgement on 2026-09-08 after reviewing the recommendation.
No automatic retry, transactional rollback, or continuation of partial state.
The [tick contract](../architecture/simulation-tick-and-threading.md) owns exact
native, desktop and Web stage/status semantics.

## Evidence and tradeoff

The preserved diagnostic, reproduced against source `bfac0bc`, shows events and
attempted tick identity changing before planning failure. A new late-phase fixture
also retains earlier cell movement before a later storage-capacity error. Merely
checking the final return cannot make this in-place algorithm transactional.
Quarantine adds bounded state and explicit outcomes without a full-world copy,
mutation journal, hidden retry loop or changed material ordering. The cost is loss
of continuation after a fault: reset/replacement abandons the failed world's state
and pending events. Diagnosis remains possible through serialized raw reads.

## Alternatives and scope

**Rejected for this fix:** retrying the same world after changing capacity/region,
silently replaying an accepted explosion, presenting partial output as a completed
tick, or claiming rollback of preceding character/Rapier work. Complete rollback
would require a separately specified journal/transaction covering cells, epochs,
activity, events, allocation, coupling and publication, with memory/work budgets.

**Separate from this quarantine decision:** live capacity growth, complete
application replay and broader allocation/error typing need their own accepted
contracts. Current native `save_physical_state`/`restore_physical_state` supports
selected non-Wave tick-boundary configurations (CYPS2–5); Wave reports physical
save format 0 and refuses exact continuation. Those capabilities do not make a
failed World resumable or restore host/Rapier state. The
[save coverage table](../reference/level-saves-and-replay.md#current-native-physical-state-versions)
owns the exact boundary.

A settled flattened Workbench document can follow its separately implemented
[authored-data recovery route](../operations/gen008-flatten-qualification.md#recovering-after-a-native-owner-fault):
Save the acknowledged baseline/edits, close the process and Load a fresh owner.
It does not read or repair the failed physical state. Pending or unacknowledged
work can refuse. Region requests during failure may be retained, but only
reset/replacement makes fresh activity eligible again.

## Acceptance boundary

Source regressions cover event/no-event faults, prior success, earlier executed
phases, repeated rejection, C ABI status, conservation, one/four-worker repeat,
lease retention and clear. Rebuilt adapter tests cover real capacity failures,
desktop owner status/reset, Web controller gating and validated replacement.
Actual platform evidence and browser gaps belong to the
[issue #1 audit](../audits/2026-09-08-issue-1-failed-ticks.md).
