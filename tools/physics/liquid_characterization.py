"""Issue 15: isolated builds, clock-free controls, and separately gated timing."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASE = "b16408c"
CASES = [("support", m) for m in (3, 24, 20, 21, 33)] + [
    ("basin48", 3), ("basin96", 3), ("film", 3)]
SHIFTS = [-129, -65, 0, 63, 127]
SOURCES = [f"native/src/{s}.cpp" for s in ("world", "material_rules", "scheduler_geometry", "render_snapshot")]
HARNESS = "native/bench/liquid_characterization.cpp"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def command(args, directory, name, cwd=ROOT, timeout=300):
    directory.mkdir(parents=True, exist_ok=True)
    args = list(map(str, args))
    with (directory / f"{name}.log").open("w", encoding="utf-8") as log:
        log.write(json.dumps(args) + "\n"); log.flush()
        try:
            result = subprocess.run(args, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 124
    save(directory / f"{name}.execution.json", dict(command=args, cwd=str(cwd), timeout=timeout, exit=code))
    if code:
        raise RuntimeError(f"{name} failed ({code}); see {directory}")


def no_builds():
    # Read-only guard; never stop another task's process. Timing additionally
    # requires the explicit owner-released --uncontended invocation.
    result = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True, check=True)
    names = {row[0].lower() for row in csv.reader(result.stdout.splitlines()) if row}
    busy = names & {"clang++.exe", "clang.exe", "cc1.exe", "cl.exe", "rustc.exe", "msbuild.exe", "scons.exe", "mingw32-make.exe"}
    if busy:
        raise RuntimeError(f"Another build is running: {sorted(busy)}; retry after it finishes")


def prepare(build, output, workspace):
    if any((build / f"{variant}.exe").exists() for variant in ("baseline", "observed")):
        raise RuntimeError("Retain existing binaries; select a fresh --build directory")
    cxx = workspace / ".local/llvm-mingw-20260826-ucrt-x86_64/bin/clang++.exe"
    version = subprocess.check_output([str(cxx), "--version"], text=True)
    if "23.1.0" not in version:
        raise RuntimeError("Compiler pin mismatch")
    tracked = subprocess.check_output(["git", "ls-files", "native/include", "native/src"], cwd=ROOT, text=True).splitlines()
    reference = build / "baseline-source"
    for name in tracked:
        path = reference / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(subprocess.check_output(["git", "show", f"{BASE}:{name}"], cwd=ROOT))
    for variant, source in [("baseline", reference), ("observed", ROOT)]:
        no_builds()
        exe = build / f"{variant}.exe"
        command([cxx, "-std=c++20", "-O3", "-DNDEBUG", "-pthread", "-static", "-Wall", "-Wextra",
                 "-I" + str(source / "native/include"), *[source / s for s in SOURCES], ROOT / HARNESS,
                 "-o", exe], output, f"build-{variant}")
        inputs = {name: sha(source / name) for name in tracked}
        inputs[HARNESS] = sha(ROOT / HARNESS)
        save(build / f"{variant}.manifest.json", dict(
            base=BASE, head=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
            variant=variant, source_inputs=inputs, executable=str(exe), sha256=sha(exe),
            compiler=str(cxx), compiler_sha256=sha(cxx), compiler_version=version,
            python=sys.version, platform=platform.platform(), processor=platform.processor()))
    print("Prepared baseline and observed executables; no timing run.", flush=True)


def verify_build(build):
    for variant in ("baseline", "observed"):
        manifest = json.loads((build / f"{variant}.manifest.json").read_text())
        if sha(build / f"{variant}.exe") != manifest["sha256"]:
            raise RuntimeError("Executable changed; prepare again")
        source = ROOT if variant == "observed" else build / "baseline-source"
        for name, expected in manifest["source_inputs"].items():
            actual = ROOT / name if name == HARNESS else source / name
            if sha(actual) != expected:
                raise RuntimeError(f"Stale {variant} build: {name}; prepare again")


def execute(build, output, fixture, material, shift, mirror, workers, quiet, observer,
            variant="observed", timing=False, suffix=""):
    key = f"{fixture}-{material}-s{shift}-m{mirror}-w{workers}-q{quiet}-o{observer}-{variant}{suffix}"
    path = output / f"{key}.jsonl"
    if path.exists():
        raise RuntimeError(f"Refusing to overwrite retained run {path}; use a new output directory")
    args = [str(build / f"{variant}.exe"), fixture, str(material), str(shift), str(mirror),
            str(workers), str(quiet), str(observer), "timing" if timing else "behavior"]
    if timing:
        no_builds()
    output.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as log, path.with_suffix(".stderr.log").open("w", encoding="utf-8") as err:
        try:
            result = subprocess.run(args, cwd=ROOT, stdout=log, stderr=err, timeout=180)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 124
    save(path.with_suffix(".execution.json"), dict(command=args, timeout=180, exit=code, executable_sha256=sha(args[0])))
    if code:
        raise RuntimeError(f"Fixture rejected ({code}): {key}")
    rows = [json.loads(line) for line in path.read_text().splitlines()]
    if not rows[-1].get("result") or len(rows) != (2050 if timing else 1802):
        raise RuntimeError("Incomplete fixture output")
    ticks = rows[1:-1]
    semantics = [{k: v for k, v in r.items() if k not in ("events", "tick_us")} for r in ticks]
    digest = hashlib.sha256(json.dumps(semantics, sort_keys=True).encode()).hexdigest()
    record = dict(key=key, file=path.name, sha256=sha(path), semantics=digest, result=rows[-1],
                  first_sleep=next((r["tick"] for r in ticks if r["active"] == 0), None),
                  visited=sum(r["visited"] for r in ticks), events=ticks[-1]["events"],
                  content_final=ticks[-1]["content"])
    if timing:
        def summarize(values):
            values = sorted(values)
            if not values:
                return None
            return dict(n=len(values), total=sum(values), maximum=values[-1],
                        **{f"p{p}": values[min(len(values)-1, (len(values)*p + 99)//100 - 1)] for p in (50, 95, 99)})
        windows = {"all": ticks, "initial": ticks[:120], "post_warmup": ticks[120:600], "after_reentry": ticks[960:]}
        record["timing_us"] = {name: summarize([r["tick_us"] for r in values]) for name, values in windows.items()}
        record["active_us"] = summarize([r["tick_us"] for r in ticks if r["visited"]])
        record["sleeping_us"] = summarize([r["tick_us"] for r in ticks if not r["visited"]])
        record["epoch_excess_us"] = [ticks[t-1]["tick_us"] - statistics.median(
            [ticks[t-2]["tick_us"], ticks[t]["tick_us"]]) for t in range(256, 2048, 255)]
        record["startup_us"] = rows[0]["startup_us"]
    return record


def behavior(build, output, smoke):
    results, expected = [], {}
    cases = CASES
    shifts = [0] if smoke else SHIFTS
    for fixture, material in cases:
        for shift in shifts:
            mirror = SHIFTS.index(shift) % 2
            for quiet in ((3,) if smoke and fixture.startswith("basin") else (3, 4096)):
                for workers in (1, 4):
                    for observer in (0, 1):
                        row = execute(build, output, fixture, material, shift, mirror, workers, quiet, observer)
                        if observer and fixture == "support" and material != 3 and quiet == 4096:
                            if not row["events"][11] or not row["events"][12]:
                                raise RuntimeError("Missing generic mobility observations")
                        if observer and fixture == "film" and quiet == 3 and not row["events"][13]:
                            raise RuntimeError("Missing film sleep observations")
                        key = (fixture, material, shift, quiet)
                        if key in expected and row["semantics"] != expected[key]:
                            raise RuntimeError(f"Worker/observer mismatch: {row['key']}")
                        expected[key] = row["semantics"]
                        results.append(row)
                    # Actual unmodified source control, same fixture/ABI/config.
                    # Full screen uses repeat controls at shift0; preparation
                    # compares baseline-source too, without tick clocks.
                    if shift == 0:
                        variant = "baseline" if smoke else "observed"
                        row = execute(build, output, fixture, material, shift, mirror, workers, quiet,
                                      0 if smoke else 1, variant, suffix="-repeat")
                        if row["semantics"] != expected[key]:
                            raise RuntimeError(f"Baseline/repeat mismatch: {row['key']}")
                        results.append(row)
            save(output / "results.json", results)
            print(f"Passed {fixture}/{material}/shift{shift}; {len(results)} clock-free runs", flush=True)


def timing(build, output):
    results = []
    cases = [case for case in CASES if case[0] in ("support", "basin96")]
    experiments = [("quiet", f, m, ("observed", 3, 0), ("observed", 4096, 0)) for f, m in cases]
    experiments += [("observer", "basin96", 3, ("observed", 3, 0), ("observed", 3, 1)),
                    ("source", "basin96", 3, ("baseline", 3, 0), ("observed", 3, 0))]
    for kind, fixture, material, a, b in experiments:
        for workers in (1, 4):
            for pair in range(7):
                rows = {}
                for label, (variant, quiet, observer) in ([('A', a), ('B', b)] if pair % 2 == 0 else [('B', b), ('A', a)]):
                    rows[label] = execute(build, output, fixture, material, 0, 0, workers, quiet, observer,
                                          variant, True, f"-{kind}-pair{pair}-{label}")
                if kind != "quiet" and rows['A']['semantics'] != rows['B']['semantics']:
                    raise RuntimeError("Timing semantic control failed")
                ratios = {window: rows['B']['timing_us'][window]['p95'] / rows['A']['timing_us'][window]['p95']
                          for window in rows['A']['timing_us']}
                excess = max(rows['B']['epoch_excess_us']) - max(rows['A']['epoch_excess_us'])
                results.append(dict(kind=kind, fixture=fixture, material=material, workers=workers, pair=pair,
                                    runs=rows, p95_ratios=ratios, review=any(v > 1.15 for v in ratios.values()) or excess > 1000,
                                    added_max_epoch_excess_us=excess))
                save(output / "pairs.json", results)
                print(f"Completed {kind}/{fixture}/{material}/w{workers}/pair{pair}", flush=True)


def gates(build, output, workspace):
    # Frozen questions reference the companion workspace through ../ paths.
    # A worktree lives one level deeper. Validate an exact copied source snapshot
    # with copied companion evidence, all inside this worktree; never rewrite
    # frozen questions or create shared paths beside other issue worktrees.
    context = output / "validation-context"
    source = context / "source"
    names = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=ROOT, text=True).splitlines()
    hashes = {}
    for name in names + [".git"]:
        target = source / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
        hashes[name] = sha(ROOT / name)
        if sha(target) != hashes[name]:
            raise RuntimeError("Validation snapshot copy mismatch")
    companions = ["SOURCE-PROVENANCE.json", "docs/WEB_THREADING.md", "tools/dev.py",
                  "docs/LOCAL_DEVELOPMENT.md", "validation/browser-results.json"]
    for name in companions:
        target = context / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(workspace / name, target)
    save(output / "snapshot.json", dict(source=str(ROOT), checked_root=str(source), source_hashes=hashes,
                                       companion_hashes={name: sha(workspace / name) for name in companions}))
    checks = {
        "docs": ["tools/ci/check_docs.py", "--root", source],
        "repository": ["tools/ci/check_repository.py", "--root", source],
        "m11": ["tools/ci/check_m11_consistency.py"],
        "retrieval": ["tools/docs/retrieval_eval.py", "--output", output / "retrieval.json"],
        "challenges": ["tools/docs/retrieval_eval.py", "--queries", "docs/reference/retrieval-challenges.json", "--output", output / "challenges.json"],
        "programme": ["tools/docs/retrieval_eval.py", "--queries", "docs/reference/architecture-programme-questions.json", "--output", output / "programme.json"],
    }
    exits = {}
    for name, args in checks.items():
        try:
            command([sys.executable, *args], output, name, timeout=180)
        except RuntimeError:
            pass  # Retain/report failures; never turn a publication mismatch green.
        exits[name] = json.loads((output / f"{name}.execution.json").read_text())["exit"]
    save(output / "exits.json", exits)
    print(json.dumps(exits), flush=True)
    if any(code for name, code in exits.items() if name != "repository"):
        raise RuntimeError("A preparation gate failed; inspect logs")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["prepare", "smoke", "screen", "timing", "gates"])
    parser.add_argument("--workspace", type=Path, default=Path("C:/kybersand"))
    parser.add_argument("--build", type=Path, default=ROOT / "build/issue-15")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--uncontended", action="store_true", help="Owner has released the performance hold")
    args = parser.parse_args()
    build, output = args.build.resolve(), args.output.resolve()
    if not build.is_relative_to(ROOT) or not output.is_relative_to(ROOT):
        parser.error("Builds and raw outputs must remain in this worktree")
    if args.action == "timing" and not args.uncontended:
        parser.error("Performance hold: arrange an uncontended run before passing --uncontended")
    build.mkdir(parents=True, exist_ok=True)
    if args.action == "prepare":
        prepare(build, output, args.workspace)
    elif args.action == "gates":
        gates(build, output, args.workspace)
    else:
        verify_build(build)
        if args.action == "timing":
            timing(build, output)
        else:
            behavior(build, output, args.action == "smoke")


if __name__ == "__main__":
    main()
