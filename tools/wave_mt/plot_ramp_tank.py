"""Render the ramp tank and front measurements. Requires Matplotlib."""
import argparse
import csv
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def read_csv(path):
    with path.open(newline="") as stream:
        return list(csv.DictReader(stream))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results_directory", type=Path)
    folder = parser.parse_args().results_directory
    data = json.loads((folder / "tank-results.json").read_text())["profiles"]
    traces = read_csv(folder / "tank-traces.csv")
    shapes = read_csv(folder / "tank-profiles.csv")
    fig, axes = plt.subplots(1, 3, figsize=(14, 4.6))
    profiles = [("sloshy", "Sloshy + Max · 1 round", "#737a85", "--"),
                ("sloshy_two_rounds", "Sloshy + Max · 2 rounds", "#3979a1", "-."),
                ("floor_255", "Level-floor gain · 2 rounds", "#b34215", "-")]
    for key, label, color, style in profiles:
        line = dict(color=color, linestyle=style, linewidth=2.2, label=label)
        series = [r for r in traces if r["settings"] == key and r["fixture"] == "deep" and int(r["tick"]) <= 460]
        axes[0].plot([int(r["tick"]) for r in series], [float(r["long_mode_cells"]) for r in series], **line)
        peak = data[key]["deep"]
        axes[0].scatter(peak["first_return_tick"], peak["first_return"]["long_mode_cells"],
                        s=36, color=color, edgecolor="white", zorder=3)
        shape = next(r for r in shapes if r["settings"] == key and r["fixture"] == "deep" and r["phase"] == "first_return")
        axes[1].plot(range(17, 81), [float(shape[f"x{x}"]) for x in range(17, 81)], **line)
        front = data[key]["blob"]["front_x"]
        axes[2].plot([int(t) for t in front], list(front.values()), **line)
        arrival = data[key]["blob"]["first_x100_tick"]
        axes[2].scatter(arrival, front[str(arrival)], s=36, color=color, edgecolor="white", zorder=3)

    axes[0].axhline(0, color="#778088", linewidth=.6)
    axes[2].axhline(100, color="#778088", linewidth=.6)
    axes[0].set(title="Time to first return", xlabel="Simulation ticks", ylabel="Signed long-wave amplitude (cells)", xlim=(0, 460))
    axes[1].set(title="Depth at each wave’s first return", xlabel="Tank column, x", ylabel="Water depth (cells)", xlim=(17, 80))
    axes[2].set(title="Flat-floor blob front", xlabel="Simulation ticks", ylabel="Rightmost wet column, x", xlim=(0, 200), ylim=(65, 130))
    for ax in axes:
        ax.set_axisbelow(True)
        ax.grid(axis="y", alpha=.23)
        ax.spines[["top", "right"]].set_visible(False)
    fig.suptitle("Deep-tank waves return sooner. The floor front reaches x100 in 32 ticks.",
                 x=.063, y=.97, ha="left", fontsize=16, weight="semibold")
    fig.legend(*axes[0].get_legend_handles_labels(), loc="upper left", bbox_to_anchor=(.057, .915),
               ncol=3, frameon=False)
    fig.subplots_adjust(left=.063, right=.985, bottom=.14, top=.74, wspace=.32)
    fig.savefig(folder / "tank-and-front.png", dpi=130)


if __name__ == "__main__":
    main()
