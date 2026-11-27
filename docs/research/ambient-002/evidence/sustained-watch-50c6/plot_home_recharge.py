"""Render the copied-record home-rest comparison, without running the engine.

Usage: python plot_home_recharge.py BASELINE_REPORT CURRENT_REPORT OUTPUT_PREFIX
"""
from pathlib import Path
import hashlib
import json
import math
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch


OLD = "a7250e15495667b2fcf564cbed1eaa8dea217c45"
NEW = "50c6df89528dc9ecdc5316d8c67abf203e192254"
OLD_OBSERVER = "2eea3dbb921058db418fbb243b4abc493cddbdb9"
NEW_OBSERVER = "52900f9d8ead1f6d0b3c4ae6fbdc1e0ac049ce4b"


def read(path, source):
    raw = path.read_bytes()
    report = json.loads(raw)
    assert report["source_revision"] == source and report["status"] == "passed"
    assert report["scene"] == "ambient2-settlement" and report["follow_actor"] == 7
    result = []
    for sample in report["samples"]:
        t = sample["requested_simulation_second"]
        if 44 <= t <= 54:
            actor = next(a for a in sample["actors"] if a["instance_id"] == 7)
            result.append({"requested_second": t,
                           "actual_copied_second": sample["simulation_seconds_since_play"],
                           "drive": actor["drives"]["exploration"],
                           "distance": math.dist(actor["observation"]["position"], [365, 355]),
                           "position": actor["observation"]["position"],
                           "phase": actor["intent"].get("goal_phase", ""),
                           "goal": actor["intent"].get("selected_goal", ""),
                           "key": actor["intent"].get("goal_key", "")})
    assert [r["requested_second"] for r in result] == list(range(44, 55))
    return result, hashlib.sha256(raw).hexdigest()


def main():
    baseline_path, current_path, prefix = map(Path, sys.argv[1:])
    old, old_hash = read(baseline_path, OLD)
    new, new_hash = read(current_path, NEW)
    rest_samples = [r["requested_second"] for r in new
                    if r["goal"] == "seek_home_drive" and r["phase"] == "home_rest"]
    assert rest_samples == [48, 49, 50, 51]
    assert all(a["position"] == b["position"] for a, b in zip(old, new) if a["requested_second"] <= 52)
    old_delta = old[7]["drive"] - old[4]["drive"]
    new_delta = new[7]["drive"] - new[4]["drive"]

    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                         "axes.spines.top": False, "axes.spines.right": False,
                         "axes.labelcolor": "#263442", "text.color": "#263442",
                         "xtick.color": "#263442", "ytick.color": "#263442"})
    fig, axes = plt.subplots(2, 1, figsize=(11.8, 7.4), sharex=True,
                             gridspec_kw={"height_ratios": [1, 1.05]})
    fig.subplots_adjust(left=0.09, right=0.965, top=0.83, bottom=0.215, hspace=0.19)
    colors = {"old": "#c2602a", "new": "#007e87"}
    times = [r["requested_second"] for r in old]
    for axis in axes:
        axis.set_facecolor("#fcfdfd")
        axis.grid(axis="y", color="#dce3e7", linewidth=0.7)
        axis.set_xlim(43.8, 54.25)
        for t in rest_samples:
            axis.axvspan(t - 0.105, t + 0.105, color="#66758a", alpha=0.12, zorder=0)
    for axis, value in zip(axes, ("drive", "distance")):
        axis.plot(times, [r[value] for r in old], color=colors["old"], linestyle="--",
                  marker="s", markersize=6.7, markerfacecolor="white", markeredgewidth=1.5,
                  linewidth=1.7, zorder=3)
        axis.plot(times, [r[value] for r in new], color=colors["new"], linestyle="-",
                  marker="o", markersize=4, linewidth=1.9, zorder=4)
    axes[0].set_ylim(0.23, 0.75)
    axes[0].set_ylabel("Exploration drive\n(bounded preference)")
    axes[0].set_yticks([0.25, 0.35, 0.45, 0.55, 0.65, 0.75])
    axes[0].text(44.12, 0.70, "Between copied samples 48 and 51:\n"
                 f"corrected {new_delta:+.6f}  ·  old {old_delta:+.6f}",
                 fontsize=10.5, va="top", bbox={"facecolor": "white", "edgecolor": "#e1e7eb", "pad": 7})
    axes[0].annotate("Exploration goal 5 resumes\nat sample 52", xy=(52, new[8]["drive"]),
                     xytext=(52.25, 0.48), fontsize=9, ha="left",
                     arrowprops={"arrowstyle": "->", "color": "#526170", "linewidth": 0.9})
    axes[1].axhspan(16, 20, color="#348573", alpha=0.09, zorder=0)
    axes[1].axhline(20, color="#348573", linewidth=1.1, linestyle=(0, (5, 3)), zorder=2)
    axes[1].axhline(16, color="#697381", linewidth=1.1, linestyle=(0, (2, 2)), zorder=2)
    axes[1].text(44.02, 21.7, "20 cells: authored home-rest arrival radius", color="#276b5d", fontsize=9)
    axes[1].text(44.02, 10.8, "16 cells: separate geometric return metric", color="#596372", fontsize=9)
    axes[1].set_ylim(5, 73)
    axes[1].set_ylabel("Distance to home center\n(native cells, Euclidean)")
    axes[1].set_xlabel("Requested simulation-second sample (1 Hz copied observations)")
    axes[1].set_xticks(range(44, 55))
    axes[1].text(50.8, 43, "Positions agree through sample 52;\nsubsequent paths differ.", fontsize=9,
                 ha="center", va="center", bbox={"facecolor": "white", "edgecolor": "none", "alpha": 0.88})

    fig.suptitle("The accepted home-rest region now replenishes exploration drive", x=0.09, ha="left",
                 y=0.975, fontsize=15, fontweight="semibold")
    fig.text(0.09, 0.927, "Foundry Row · Cautious Flyer #7 · same authored scene and initial copied actor states", fontsize=10.5)
    handles = [Line2D([], [], color=colors["old"], linestyle="--", marker="s", markerfacecolor="white", label="Old application a725"),
               Line2D([], [], color=colors["new"], marker="o", label="Corrected application 50c6"),
               Patch(facecolor="#66758a", alpha=0.12, label="Selected home_rest at sampled seconds 48–51")]
    fig.legend(handles=handles, loc="upper left", bbox_to_anchor=(0.083, 0.902), ncol=3,
               frameon=False, fontsize=9.5, handlelength=2.6, columnspacing=1.8)
    caption = [
        f"Old application: {OLD}    Observer: {OLD_OBSERVER}",
        f"Corrected application: {NEW}    Observer: {NEW_OBSERVER}",
        "Original ordinary Workbench records. Points are 1 Hz copies; connecting lines do not establish continuous occupancy.",
        "Drive updates credit the preceding selected interval. Rest inside 20 cells is distinct from a 16-cell geometric return; neutral intent is not proof of stillness.",
    ]
    for index, line in enumerate(caption):
        fig.text(0.09, 0.132 - index * 0.025, line, fontsize=7.6, va="top", color="#526170")
    prefix.parent.mkdir(parents=True, exist_ok=True)
    for suffix in (".png", ".svg"):
        fig.savefig(prefix.with_suffix(suffix), dpi=170, facecolor="white")
    plt.close(fig)
    receipt = {"applications": {"old": OLD, "corrected": NEW},
               "original_report_sha256": {"old": old_hash, "corrected": new_hash},
               "plotter_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               "home_rest_sample_seconds": rest_samples,
               "drive_change_samples48_to51": {"old": old_delta, "corrected": new_delta},
               "plotted_records": {"old": old, "corrected": new},
               "outputs": [{"name": prefix.with_suffix(suffix).name,
                             "bytes": prefix.with_suffix(suffix).stat().st_size,
                             "sha256": hashlib.sha256(prefix.with_suffix(suffix).read_bytes()).hexdigest()}
                            for suffix in (".png", ".svg")]}
    prefix.with_suffix(".json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"outputs": receipt["outputs"], "drive_change": receipt["drive_change_samples48_to51"]}))


if __name__ == "__main__":
    main()
