"""Replay-verified DEVELOPMENT-only target-sweep diagnostics.

A unit/macro action can sweep through the A-to-B endpoint but finish beyond it.
The frozen v1 episode score intentionally defines ARRIVED by the terminal cursor.
This independent diagnostic records intermediate target contact without silently
changing that scoring rule or making any native/paint/model performance claim.
"""
from __future__ import annotations

from typing import Any

from . import offline as d
from . import paired

VERSION = "d1a-target-sweep-diagnostic/1"


def _summarize_sweeps(target: d.Point, swept_events: list[tuple[int, tuple[d.Point, ...]]],
                      terminal_cursor: d.Point) -> dict[str, Any]:
    """Pure geometric accounting; production entry point replay-verifies first."""
    moved = 0
    contacts = 0
    first = None
    for decision, swept in swept_events:
        for index, cell in enumerate(swept, start=1):
            moved += 1
            if cell == target:
                contacts += 1
                if first is None:
                    first = {
                        "decision_index": decision,
                        "one_based_global_cell_step": moved,
                        "one_based_macro_cell_step": index,
                        "macro_cell_length": len(swept),
                        "contact_at_action_endpoint": index == len(swept),
                    }
    return {
        "target_swept_at_least_once": contacts > 0,
        "total_target_cell_contacts": contacts,
        "first_target_contact": first,
        "terminal_cursor_at_target": terminal_cursor == target,
        "first_contact_overshot_within_macro":
            first is not None and not first["contact_at_action_endpoint"],
        "post_first_contact_cell_steps":
            None if first is None else moved - first["one_based_global_cell_step"],
        "total_swept_cell_steps": moved,
    }


def audit_development_target_contact(fixture: d.Fixture,
                                     episode: dict[str, Any]) -> dict[str, Any]:
    """Distinguish target swept contact from endpoint arrival, source-bound.

    No new policy rollout, held-out exploration, native operations, or inferred
    evidence is performed. All swept segments are taken from the recomputed
    legal candidates of the replay-verified original episode.
    """
    custody = paired.verify_episode(fixture, episode)  # Fails closed on held-out.
    lengths = tuple(episode["macro_lengths"])
    sweeps = []
    for event in episode["events"]:
        before = tuple(event["observation"]["position"])
        options = {c.candidate_id: c for c in d.candidates(fixture, before, lengths)}
        selected = options[event["choice_id"]]
        sweeps.append((event["seq"], selected.path))
    summary = _summarize_sweeps(fixture.target, sweeps,
                                tuple(episode["path"][-1]))
    if summary["terminal_cursor_at_target"] != episode["metrics"]["arrived"]:
        raise ValueError("Verified terminal arrival does not match source metrics")
    if summary["total_swept_cell_steps"] != episode["metrics"]["cursor_cell_steps"]:
        raise ValueError("Verified swept length does not match source metrics")
    return {
        "version": VERSION,
        "source_kind": "replay_verified_offline_geometry_only",
        "native_qualified": False,
        "model_evaluated": False,
        "heldout_behavior_evaluated": False,
        "fixture_sha256": fixture.sha256,
        "verified_original_trajectory_sha256": custody["path_sha256"],
        "decision_count": len(episode["events"]),
        "arrival_semantics": "cursor_equals_target_at_action_endpoint",
        "target_contact_summary": summary,
        "interpretation": (
            "Swept contact or overshoot is not native painting, and is not "
            "terminal arrival unless the action endpoint is the target"
        ),
    }
