"""Reduce completed issue15 runs without treating retained data as new execution."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import statistics as stats


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def distribution(values):
    return dict(min=min(values), median=stats.median(values), max=max(values))


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    screen = read(args.raw / "screen/results.json")
    pairs = read(args.raw / "timing/pairs.json")
    if len(screen) != 352 or len(pairs) != 112:
        raise ValueError(f"Incomplete campaign: {len(screen)} behavior, {len(pairs)} timing pairs")
    pattern = re.compile(r"(?P<fixture>\w+)-(?P<material>\d+)-s(?P<shift>-?\d+)-m(?P<mirror>\d+)-w(?P<workers>\d+)-q(?P<quiet>\d+)-o(?P<observer>\d+)-observed(?P<repeat>-repeat)?$")
    groups, records, fingerprints, traces = {}, {}, [], []
    for row in screen:
        match = pattern.fullmatch(row["key"])
        if not match:
            raise ValueError(row["key"])
        fields = match.groupdict()
        for key in ("material", "shift", "mirror", "workers", "quiet", "observer"):
            fields[key] = int(fields[key])
        path = args.raw / "screen" / row["file"]
        if sha(path) != row["sha256"]:
            raise ValueError(f"Changed raw file {path}")
        fingerprints.append(dict(file=str(path), sha256=row["sha256"]))
        key = (fields["fixture"], fields["material"], fields["shift"], fields["quiet"])
        records.setdefault(key, []).append(row)
        if fields["workers"] != 1 or fields["observer"] != 1 or fields["repeat"]:
            continue
        raw = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
        ticks = raw[1:-1]
        assert len(ticks) == 1800
        assert len({r["quantity"] for r in ticks}) == 1
        selected = dict(**fields, result=row["result"], first_sleep=row["first_sleep"],
                        final_quantity=ticks[-1]["quantity"], occupied=ticks[-1]["occupied"],
                        final_content=ticks[-1]["content"], column_spread=ticks[-1]["spread"],
                        content_sequence_sha256=hashlib.sha256(json.dumps([r["content"] for r in ticks]).encode()).hexdigest(),
                        visited=sum(r["visited"] for r in ticks), active_block_sum=sum(r["active"] for r in ticks),
                        scheduled_core_sum=sum(r["cores"] for r in ticks), cell_bytes=raw[0]["cell_bytes"], chunks=raw[0]["chunks"],
                        late_changed_ticks=sum(r["changed"] for r in ticks[1200:]),
                        late_moved=sum(r["moved"] for r in ticks[1200:]),
                        events=ticks[-1]["events"],
                        late_events=[a-b for a,b in zip(ticks[-1]["events"],ticks[1199]["events"])])
        groups.setdefault((fields["fixture"], fields["material"], fields["quiet"]), []).append(selected)
        if fields["shift"] == 0:
            samples = {1,3,12,120,600,601,602,624,900,901,960,961,962,1200,1800}
            traces.append(dict(configuration=fields, raw_file=str(path), sha256=row["sha256"],
                               ticks=[r for r in ticks if r["tick"] in samples]))
    for key, values in records.items():
        if len({r["semantics"] for r in values}) != 1:
            raise ValueError(f"Worker/observer/repeat mismatch {key}")
        if len(values) != (6 if key[2] == 0 else 4):
            raise ValueError(f"Missing registered controls {key}")
    behavior = []
    for (fixture, material, quiet), rows in groups.items():
        assert len(rows) == 5
        metrics = {name: distribution([r[name] for r in rows]) for name in (
            "visited", "active_block_sum", "scheduled_core_sum", "column_spread", "occupied", "late_changed_ticks", "late_moved", "cell_bytes", "chunks")}
        metrics["last_change"] = distribution([r["result"]["last_change"] for r in rows])
        metrics["slept_cases"] = sum(r["first_sleep"] is not None for r in rows)
        metrics["first_sleep"] = [r["first_sleep"] for r in rows]
        metrics["level_ticks"] = [r["result"]["level"] for r in rows]
        metrics["arrival_ticks"] = [r["result"]["arrival"] for r in rows]
        metrics["events"] = [distribution([r["events"][i] for r in rows]) for i in range(14)]
        metrics["late_events"] = [distribution([r["late_events"][i] for r in rows]) for i in range(14)]
        if quiet == 3:
            other = {r["shift"]: r for r in groups[(fixture,material,4096)]}
            metrics["different_final_content_vs_4096"] = sum(r["final_content"] != other[r["shift"]]["final_content"] for r in rows)
            metrics["different_content_trajectory_vs_4096"] = sum(r["content_sequence_sha256"] != other[r["shift"]]["content_sequence_sha256"] for r in rows)
        behavior.append(dict(fixture=fixture,material=material,quiet=quiet,metrics=metrics,translations=rows))
    timing_groups = {}
    for pair in pairs:
        key = (pair["kind"], pair["fixture"], pair["material"], pair["workers"])
        timing_groups.setdefault(key, []).append(pair)
        for label, row in pair["runs"].items():
            path = args.raw / "timing" / row["file"]
            if sha(path) != row["sha256"]:
                raise ValueError(f"Changed timing output {path}")
            fingerprints.append(dict(file=str(path),sha256=row["sha256"]))
        if pair["kind"] != "quiet":
            assert pair["runs"]["A"]["semantics"] == pair["runs"]["B"]["semantics"]
    timing = []
    for (kind,fixture,material,workers), rows in timing_groups.items():
        assert sorted(r["pair"] for r in rows) == list(range(7))
        for label in ("A", "B"):
            if len({r["runs"][label]["semantics"] for r in rows}) != 1:
                raise ValueError("Timing repeat semantic mismatch")
        windows = {}
        for window in ("all", "initial", "post_warmup", "after_reentry"):
            windows[window] = {label: {metric: distribution([r["runs"][label]["timing_us"][window][metric] for r in rows])
                                     for metric in ("p50", "p95", "p99", "maximum", "total")}
                               for label in ("A", "B")}
            ratios = [r["p95_ratios"][window] for r in rows]
            windows[window].update(p95_ratios=ratios, ratio_distribution=distribution(ratios),
                                   flagged_pairs=sum(r > 1.15 for r in ratios))
        timing.append(dict(kind=kind,fixture=fixture,material=material,workers=workers,windows=windows,
                           startup_us={label:distribution([r["runs"][label]["startup_us"] for r in rows]) for label in ("A","B")},
                           epoch_excess_us={label:[r["runs"][label]["epoch_excess_us"] for r in rows] for label in ("A","B")},
                           added_max_epoch_excess_us=[r["added_max_epoch_excess_us"] for r in rows],
                           flagged_pairs=sum(r["review"] for r in rows)))
    save(args.output / "behavior.json", behavior)
    save(args.output / "timing.json", timing)
    save(args.output / "traces.json", traces)
    save(args.output / "integrity.json", dict(behavior_processes=len(screen),timing_pairs=len(pairs),timing_processes=2*len(pairs),
         behavior_ticks=352*1800,timing_ticks=224*2048,worker_observer_repeat_groups=len(records),
         raw_files=fingerprints,screen_summary_sha256=sha(args.raw/'screen/results.json'),timing_summary_sha256=sha(args.raw/'timing/pairs.json')))
    print(f"Verified {len(screen)} behavior processes and {len(pairs)} timing pairs")


if __name__ == "__main__":
    main()
