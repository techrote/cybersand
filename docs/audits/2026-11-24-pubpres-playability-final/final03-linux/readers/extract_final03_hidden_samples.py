#!/usr/bin/env python3
"""Retain exact observed mixed-scene omissions without inventing endpoint state."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace-root", type=Path,
                        default=Path("/workspace/scratch/0b2a9bdf7883"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    archive = args.workspace_root / "evidence-root/final-03/graphical-linux/original.zip"
    output = args.output or args.workspace_root / "evidence-c/final03-linux-hidden-frame-samples.json"
    result = {
        "schema": "pubpres-final03-hidden-frame-samples-v1",
        "program_sha256": digest(Path(__file__).read_bytes()),
        "archive_sha256": digest(archive.read_bytes()),
        "application_source": "c2f8a73d34448bc1496ecd84bca02f0812c80d27",
        "cases": [],
        "scope": [
            "Raw observed submission and current independently completed Rapier pose, not a replay of renderer selection.",
            "A hidden selection records no selected pose. No native-bound or rejected endpoint pose is fabricated.",
            "The recorded reason is the initial refusal; later endpoint re-entry refusals may not overwrite it.",
            "Camera classification is the physical center in the submitted view rectangle, not pixel visibility or collider extent.",
            "Worker publication is joined by actual uploaded render serial, World, and generated clock; capture association is an enclosing producer interval, not serial equality.",
        ],
        "physical_acceptance": False,
    }
    with zipfile.ZipFile(archive) as z:
        for size, slots in ((512, (4, 5, 6)), (1024, (1, 4, 5, 6))):
            case = f"mixed_wave_{size}_follow"
            prefix = f"mixed-eight-actor/{case}/"
            trace_bytes = z.read(prefix + "receipt-events.jsonl")
            presentation_bytes = z.read(prefix + "receipt-presentation.json")
            trace = [json.loads(line) for line in trace_bytes.splitlines()]
            presentation = json.loads(presentation_bytes)
            rows = presentation["submissions"]
            steps = {e["step"]: e for e in trace if e["event"] == "rapier_step"}
            uploads = [e for e in trace if e["event"] == "texture_upload"]
            workers = [e for e in trace if e["event"] == "worker_snapshot"]
            captures = [e for e in trace if e["event"] == "native_render_capture"]
            observations = [e for e in trace if e["event"] == "native_completion_observed"]
            identity = next(e for e in trace if e["event"] == "identity")
            record = {"case": case, "trace_member": prefix + "receipt-events.jsonl",
                      "trace_sha256": digest(trace_bytes),
                      "presentation_member": prefix + "receipt-presentation.json",
                      "presentation_sha256": digest(presentation_bytes),
                      "identity": identity, "slots": []}
            for slot in slots:
                episodes, start = [], None
                for i, row in enumerate(rows):
                    body = next(b for b in row["bodies"] if b["slot"] == slot)
                    hidden = not body["selected_visible"]
                    if hidden and start is None:
                        start = i
                    if not hidden and start is not None:
                        episodes.append((start, i - 1, False))
                        start = None
                if start is not None:
                    episodes.append((start, len(rows) - 1, True))
                start, end, censored = max(episodes, key=lambda e: rows[e[1]]["time_usec"] - rows[e[0]]["time_usec"])
                first_bounded = next((i for i in range(start, end + 1)
                                      if next(b for b in rows[i]["bodies"] if b["slot"] == slot)["reason"] == "bounded_pose_delta"), None)
                indices = {start, (start + end) // 2, end}
                if start:
                    indices.add(start - 1)
                if first_bounded is not None:
                    indices.add(first_bounded)
                entry = {"slot": slot, "longest_episode_first_index": start,
                         "longest_episode_last_index": end, "right_censored": censored,
                         "observed_first_to_last_ms": (rows[end]["time_usec"] - rows[start]["time_usec"]) / 1000,
                         "reason_counts": dict(collections.Counter(
                             next(b for b in rows[i]["bodies"] if b["slot"] == slot)["reason"]
                             for i in range(start, end + 1))),
                         "samples": []}
                for i in sorted(indices):
                    row = rows[i]
                    body = next(b for b in row["bodies"] if b["slot"] == slot)
                    step = steps[row["physical_tick"]]
                    physical_body = next(b for b in step["bodies"] if b["slot"] == slot)
                    assert step["time_usec"] <= row["time_usec"]
                    assert physical_body["instance_id"] == body["instance_id"]
                    owned = next(b for b in step["body_ownership"] if b["slot"] == slot)
                    assert str(owned["body_rid"]) == body["body_rid"]
                    preceding = [u for u in uploads if u["time_usec"] <= row["time_usec"]]
                    upload = max(preceding, key=lambda u: u["time_usec"])
                    assert upload["render_serial"] == row["render_serial"]
                    assert upload["generated_usec"] == row["material_generated_usec"]
                    assert upload["world_generation"] == row["world_generation"]
                    matching_workers = [w for w in workers
                                        if w["render_serial"] == upload["render_serial"]
                                        and w["render_generated_usec"] == upload["generated_usec"]
                                        and w["render_world_generation"] == upload["world_generation"]
                                        and not w["failed"] and w["time_usec"] <= upload["time_usec"]]
                    assert matching_workers
                    worker = min(matching_workers, key=lambda w: w["time_usec"])
                    enclosing_captures = [c for c in captures
                                          if worker["start_usec"] <= c["start_usec"] <= c["time_usec"] <= worker["time_usec"]]
                    native_observations = [o for o in observations
                                           if o["tick_index"] == worker["tick_index"]
                                           and o["body_sample"] == worker["completed_body_sample"]
                                           and o["world_generation"] == worker["world_generation"]]
                    assert native_observations
                    xy, camera, view = physical_body["xy"], row["camera_submitted"], row["view_size"]
                    entry["samples"].append({
                        "submission_array_index": i,
                        "relative_to_episode": "preceding_visible" if i < start else "hidden",
                        "submission": {k: v for k, v in row.items() if k != "bodies"},
                        "selected_body_observation": body,
                        "actual_completed_step": {k: v for k, v in step.items() if k not in ("bodies", "mixed_actor_controls")},
                        "actual_completed_body": physical_body,
                        "actual_center_in_submitted_view": all(camera[a] <= xy[a] < camera[a] + view[a] for a in (0, 1)),
                        "actual_center_in_native_extent": all(0 <= xy[a] < size for a in (0, 1)),
                        "latest_preceding_actual_upload": upload,
                        "earliest_matching_healthy_worker_publication": worker,
                        "matching_native_completion_observations": native_observations,
                        "captures_enclosed_by_worker_publication_interval": enclosing_captures,
                        "native_bound_pose": None,
                        "native_bound_pose_scope": "Not present in this retained observer; worker sample/serial identity does not reconstruct the rejected bound endpoint.",
                        "rejected_endpoint_details": None,
                    })
                record["slots"].append(entry)
            result["cases"].append(record)
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"output": str(output), "sha256": digest(output.read_bytes()),
                      "cases": len(result["cases"]),
                      "samples": sum(len(s["samples"]) for c in result["cases"] for s in c["slots"])}))


if __name__ == "__main__":
    main()
