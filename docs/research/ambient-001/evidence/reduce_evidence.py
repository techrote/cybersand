#!/usr/bin/env python3
"""Reduce AMBIENT-001 reports into small retained measurements and a trace plot.

This reads existing results, checks source custody, and never runs the game.
Requires matplotlib for the standalone publication-style plot.
"""
from __future__ import annotations

import argparse
import copy
import csv
import hashlib
import json
import math
from pathlib import Path
import subprocess


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def console_result(path: Path, prefix: str) -> dict:
    text = path.read_text()
    if "SCRIPT ERROR" in text or "ERROR:" in text:
        raise SystemExit(f"Runtime error in {path}")
    matches = [line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)]
    if len(matches) != 1:
        raise SystemExit(f"Expected exactly one completion result in {path}")
    result = json.loads(matches[0])
    if result["failures"]:
        raise SystemExit(f"Failed qualification: {path}")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--motion", type=Path, required=True)
    parser.add_argument("--perception", type=Path, required=True)
    parser.add_argument("--independent-log", type=Path, required=True)
    parser.add_argument("--ledge-log", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[4])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.source_root.resolve()
    motion = json.loads(args.motion.read_text())
    perception = json.loads(args.perception.read_text())
    if motion["failures"] or perception["failures"]:
        raise SystemExit("Refusing to summarize a failed qualification as passing")
    for relative, expected in motion["source_identity"]["sha256"].items():
        if digest(root / "godot" / relative) != expected:
            raise SystemExit(f"Source changed since the motion run: godot/{relative}")
    args.output.mkdir(parents=True, exist_ok=True)
    summary = copy.deepcopy(motion)
    for campaign in summary["campaigns"]:
        for actor in campaign["actors"]:
            actor.pop("trace")
            actor.pop("last_intent")
            actor["horizontal_range_cells"] = actor["max_x"] - actor["min_x"]
            actor["decision_usec_mean"] = actor["total_decision_usec"] / 40
    summary["interpretation"] = [
        "One four-second run per controller; this is a bounded comparison, not an optimality claim.",
        "Scripted, ambient and random legal controls share source geometry, spawn states and decision budgets.",
        "Random action streams and ambient per-module streams are distinct declared generators.",
        "The same independent native-ID observer samples all modes and never feeds their actions.",
        "Oil itself moves; fixed initial Oil coordinate distance is reported separately from current nearest sample.",
        "Zero flight move is an active hover request; neutral move is not passive or zero physical effort.",
        "Stall and sign-change counts include physical braking, collisions and deliberate route changes.",
        "Timing observations share a hosted machine; they are not Windows/NVIDIA performance acceptance.",
    ]
    write_json(args.output / "native-motion-summary.json", summary)
    write_json(args.output / "perception-summary.json", perception)
    fields = ["controller", "model", "sample", "tick", "seconds", "x", "y", "move_x", "move_y",
              "intent_x", "intent_y", "intent_pace", "override", "interval_dx", "interval_dy",
              "material_tick", "material_revision", "oil_available", "oil_present", "oil_distance",
              "oil_x", "oil_y", "water_available", "water_present", "water_distance", "water_x", "water_y"]
    with (args.output / "native-motion-trajectories.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for campaign in motion["campaigns"]:
            for actor in campaign["actors"]:
                for sample in actor["trace"]:
                    row = {"controller": campaign["controller"], "model": actor["model"],
                           "sample": "decision", "tick": sample["tick"], "seconds": sample["tick"] / 60,
                           "x": sample["position"][0], "y": sample["position"][1],
                           "move_x": sample["action_move"][0], "move_y": sample["action_move"][1],
                           "intent_x": sample["intent"][0], "intent_y": sample["intent"][1],
                           "intent_pace": sample["intent_pace"], "override": sample["override"],
                           "interval_dx": sample["actual_interval_displacement"][0],
                           "interval_dy": sample["actual_interval_displacement"][1],
                           "material_tick": sample["material_sample_tick"],
                           "material_revision": sample["material_revision"]}
                    for name in ["oil", "water"]:
                        target = sample[name]
                        row[name + "_available"] = target.get("available", False)
                        row[name + "_present"] = target.get("present", False)
                        row[name + "_distance"] = target.get("distance", "")
                        row[name + "_x"], row[name + "_y"] = target.get("nearest", ["", ""])
                    writer.writerow(row)
                writer.writerow({"controller": campaign["controller"], "model": actor["model"],
                                 "sample": "terminal_pose", "tick": campaign["rapier_ticks"],
                                 "seconds": campaign["rapier_ticks"] / 60,
                                 "x": actor["last"][0], "y": actor["last"][1]})

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False,
                         "axes.titlesize": 12, "figure.facecolor": "white", "axes.grid": True,
                         "grid.color": "#e3e8ee", "grid.linewidth": 0.7})
    colors = {"ambient": "#126e82", "scripted": "#74777e", "random": "#bd6234"}
    fig, axes = plt.subplots(2, 3, figsize=(13.5, 8.3), gridspec_kw={"hspace": 0.39, "wspace": 0.24})
    for index, model in enumerate(["runner", "monowheel", "4ly_trainer"]):
        for campaign in motion["campaigns"]:
            actor = next(row for row in campaign["actors"] if row["model"] == model)
            trace = actor["trace"]
            color = colors[campaign["controller"]]
            poses = [sample["position"] for sample in trace] + [actor["last"]]
            axes[0, index].plot([p[0] - actor["first"][0] for p in poses],
                                [p[1] - actor["first"][1] for p in poses], color=color,
                                label=campaign["controller"].capitalize(), linewidth=1.8, alpha=0.9)
            axes[0, index].scatter(poses[-1][0] - actor["first"][0], poses[-1][1] - actor["first"][1],
                                   color=color, marker="x", s=40, zorder=4)
            axes[1, index].plot([sample["tick"] / 60 for sample in trace],
                                [sample["oil"].get("distance", math.nan) if sample["oil"].get("present") else math.nan
                                 for sample in trace], color=color, linewidth=1.8)
        axes[0, index].scatter(0, 0, color="#20252a", s=25, zorder=5)
        axes[0, index].set_title({"runner": "Runner · ground", "monowheel": "Monowheel · articulated roll",
                                  "4ly_trainer": "4LY Trainer · assisted flight"}[model])
        axes[0, index].set_xlabel("Horizontal displacement (world cells)")
        axes[0, index].set_ylabel("Vertical displacement (world cells)" if index == 0 else "")
        axes[0, index].invert_yaxis()
        axes[0, index].set_aspect("equal", adjustable="datalim")
        axes[1, index].set_xlabel("Completed physical time (s)")
        axes[1, index].set_ylabel("Nearest observed Oil (world cells)" if index == 0 else "")
        axes[1, index].set_ylim(0, 52)
        axes[1, index].set_xlim(0, 4)
        axes[1, index].axvline(3, color="#b7c2cb", linestyle=":", linewidth=1)
    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper center", bbox_to_anchor=(0.5, 0.935), ncol=3, frameon=False)
    fig.suptitle("AMBIENT-001 · matched native-material and Rapier observations", x=0.5, y=0.98, fontsize=16)
    fig.text(0.5, 0.01,
             "One 4 s run per controller; 3 actors, 240 native/Rapier ticks, 40 decisions each. Dot = start; × = final pose.\n"
             "Oil can flow. Distance is nearest sampled native ID, with 4-cell spacing and inclusive radius 50.\n"
             "Water is painted at 3 s in the ground stations. No global route finding, optimality or Windows playfeel claim.",
             ha="center", va="bottom", fontsize=9, color="#404b55")
    fig.subplots_adjust(top=0.85, bottom=0.16)
    fig.savefig(args.output / "native-motion-comparison.png", dpi=170)
    plt.close(fig)
    sources = {"godot/" + key: value for key, value in motion["source_identity"]["sha256"].items()}
    for relative in ["godot/tests/test_ambient_perception.gd", "godot/tests/test_ambient_independent.gd",
                     "godot/tests/test_ambient_ledge_geometry.gd"]:
        sources[relative] = digest(root / relative)
    runtimes = {}
    windows = motion["source_identity"]["platform"] == "Windows"
    for name, relative in {"native": "godot/addons/cybersand_native/" +
                           ("runtime-provenance.json" if windows else "runtime-provenance.linux.json"),
                           "rapier": "godot/addons/godot-rapier2d/" +
                           ("runtime-provenance.windows.json" if windows else "runtime-provenance.linux.json")}.items():
        record = json.loads((root / relative).read_text())
        runtimes[name] = {key: record.get(key) for key in ["artifact", "sha256", "source_commit", "build_commit", "status"]}
        runtimes[name]["provenance_file_sha256"] = digest(root / relative)
    custody = {"schema": "ambient-qualification-custody/v1", "source_identity": motion["source_identity"],
               "repository_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
               "source_form": "accepted base plus source-hashed local implementation; final commit recorded by lead",
               "source_sha256": sources, "retained_runtimes": runtimes,
               "inputs_sha256": {path.name: digest(path) for path in
                                 [args.motion, args.perception, args.independent_log, args.ledge_log]},
               "tests": {"native_motion": {"checks": motion["checks"], "failures": motion["failures"]},
                         "perception": {"checks": perception["checks"], "failures": perception["failures"]},
                         "independent_core_composition": console_result(args.independent_log, "AMBIENT_INDEPENDENT "),
                         "actual_rapier_ledge_geometry": console_result(args.ledge_log, "AMBIENT_LEDGE_GEOMETRY ")},
               "outputs_sha256": {name: digest(args.output / name) for name in
                                  ["native-motion-summary.json", "perception-summary.json",
                                   "native-motion-trajectories.csv", "native-motion-comparison.png"]}}
    write_json(args.output / "qualification-custody.json", custody)
    print(json.dumps({"output": str(args.output), "tests": custody["tests"],
                      "retained_bytes": sum((args.output / name).stat().st_size for name in
                                            [*custody["outputs_sha256"], "qualification-custody.json"])}))


if __name__ == "__main__":
    main()
