#!/usr/bin/env python3
"""Plot copied physical X positions and selected phases without adding outcomes."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch


def segments(trace):
    result = []
    start = float(trace[0]["seconds"])
    label = (trace[0]["selection"], trace[0]["phase"])
    for sample in trace[1:]:
        current = (sample["selection"], sample["phase"])
        if current != label:
            result.append((start, float(sample["seconds"])-start, label))
            start = float(sample["seconds"]); label = current
    result.append((start, 30.0-start, label))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    if not report["complete"] or report["completed_actor_episodes"] != 6:
        raise ValueError("Plot only the complete preregistered supplement")
    cases = {(c["seed"], c["arm"]): c for c in report["campaigns"]}
    colours = {
        ("routine", "approach"): "#758ca5", ("routine", "dwell"): "#b9c7d5",
        ("discovery", "approach"): "#dc8d29", ("discovery", "inspect"): "#f2d190",
    }
    fig, axes = plt.subplots(3, 2, figsize=(13, 8), sharex=True,
                             gridspec_kw={"width_ratios": [1.4, 1.0]})
    for row, seed in enumerate((605, 1701, 2909)):
        movement, goals = axes[row]
        reference = None
        for index, arm in enumerate(("low_curiosity", "high_curiosity")):
            case = cases[seed, arm]
            trace = case["episodes"][0]["trace"]
            reference = trace[0]["oil"]["nearest"][0]
            movement.plot([s["seconds"] for s in trace], [s["position"][0] for s in trace],
                color="#32638e" if index == 0 else "#b45a0f",
                linestyle="--" if index == 0 else "-", linewidth=1.6,
                label="Curiosity 0" if index == 0 else "Curiosity 1")
            for start, duration, label in segments(trace):
                goals.broken_barh([(start, duration)], (index-.3, .6),
                    facecolors=colours.get(label, "#e0e0e0"), edgecolors="none")
        movement.axhline(reference, color="#a17013", linewidth=.8, linestyle=":", label="First copied Oil X")
        movement.set_ylabel("Seed "+str(seed)+"\nActual centre X (cells)")
        movement.grid(alpha=.18)
        goals.set_yticks([0, 1], ["Curiosity 0", "Curiosity 1"])
        goals.set_ylim(-.7, 1.7)
        goals.set_title("Selected module and phase", fontsize=10)
        for ax in (movement, goals):
            ax.axvspan(0, 10, color="#76a5af", alpha=.08, zorder=-1)
            ax.axvline(10, color="#52656b", linewidth=.8, linestyle="--")
            ax.set_xlim(0, 30)
            ax.spines[["top", "right"]].set_visible(False)
    axes[0, 0].legend(loc="best", fontsize=8, frameon=False)
    axes[-1, 0].set_xlabel("Completed physical simulation time (seconds)")
    axes[-1, 1].set_xlabel("Completed physical simulation time (seconds)")
    fig.legend(handles=[Patch(color=colour, label=" / ".join(label)) for label, colour in colours.items()],
               loc="lower center", ncol=4, fontsize=9, frameon=False, bbox_to_anchor=(.5, .055))
    fig.suptitle("One trait, competing ordinary goals: six actual Runner episodes", fontsize=15, y=.99)
    fig.text(.5, .955,
        "Frozen a725 application · three matched seed pairs · only curiosity differs · shaded 0–10 s is the preregistered primary window",
        ha="center", fontsize=9)
    fig.text(.5, .015,
        "Horizontal position excludes vertical gait. The Oil reference is one initial copied sample, not a global material oracle.\n"
        "Selected inspection does not establish stillness. This supplement is separate from the primary 194 programme.",
        ha="center", fontsize=9)
    fig.tight_layout(rect=(0, .09, 1, .94), h_pad=1.5, w_pad=3)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, dpi=150)
    print(str(args.output))


if __name__ == "__main__":
    main()
