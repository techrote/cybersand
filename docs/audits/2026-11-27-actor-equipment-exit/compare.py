"""Replay a fixed-binary Windows equipment-lifetime experiment using only an isolated copy."""

from pathlib import Path
import argparse, hashlib, os, json, subprocess, shutil, time

parser = argparse.ArgumentParser(
    description="Measure terminal-marker engine exits in an isolated Godot project copy."
)
parser.add_argument(
    "--checkout",
    required=True,
    type=Path,
    help="Imported b1d33a18 checkout with original runtime bytes",
)
parser.add_argument(
    "--engine", required=True, type=Path, help="Pinned Godot 4.7 Windows executable"
)
parser.add_argument(
    "--output", required=True, type=Path, help="Fresh directory for this one cohort"
)
parser.add_argument(
    "--cohort", required=True, choices=("deps", "donor", "leaf", "all_scripts")
)
parser.add_argument("--fixture", choices=("owned.gd", "script.gd"), default="owned.gd")
parser.add_argument("--repetitions", type=int, default=24)
args = parser.parse_args()
if args.repetitions < 1:
    parser.error("repetitions must be positive")
checkout = args.checkout.resolve()
evidence = args.output.resolve()
evidence.mkdir(parents=True, exist_ok=False)
engine = args.engine.resolve()
src = "b1d33a18549adf03db7ae3b49a0c4180aa4e5382"


def git(*a):
    return subprocess.check_output(["git", "-C", str(checkout), *a])


assert git("rev-parse", "HEAD").decode().strip() == src
d = evidence / "staged"
destination = d / "godot"
if not destination.exists():

    def cp(s, t):
        if os.path.getsize(s) >= 2**20:
            return os.link(s, t)
        return shutil.copy2(s, t)

    shutil.copytree(
        checkout / "godot",
        destination,
        copy_function=cp,
        ignore=shutil.ignore_patterns("*.log", "*.tmp"),
    )
engine_hash = hashlib.file_digest(engine.open("rb"), "sha256").hexdigest()
native = destination / "addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
native_hash = hashlib.file_digest(native.open("rb"), "sha256").hexdigest()
assert (
    native_hash == "55c2a2ac2af4acbb4314eb89f7dcba35ff4cc69c8ec87552b0daf1b7d9658bcd"
    and engine_hash
    == "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8"
)
assert (
    json.loads(
        (destination / "addons/cybersand_native/runtime-provenance.json").read_bytes()
    )["sha256"]
    == native_hash
)
fixture = Path(__file__).parent / args.fixture
phase, N = args.cohort, args.repetitions
run = evidence
env = {
    k: v
    for k, v in os.environ.items()
    if not k.startswith(("CYBERSAND_", "SWARM004_", "WB_ACTOR_"))
}
env["CYBERSAND_SOURCE_REVISION"] = src
for key, subdir in (
    ("APPDATA", "roaming"),
    ("LOCALAPPDATA", "local"),
    ("XDG_DATA_HOME", "data"),
    ("XDG_CONFIG_HOME", "config"),
    ("XDG_CACHE_HOME", "cache"),
):
    folder = run / "profile" / subdir
    folder.mkdir(parents=True)
    env[key] = str(folder)
paths = [
    "scripts/physical_usable_runtime.gd",
    "scripts/usable_runtime.gd",
    "scripts/workbench_sandbox_capacity.gd",
]
old = "80caeece153ac6f4be137c80164f78de364cc4cc"
if phase == "all_scripts":
    paths = sorted(
        {
            p.removeprefix("godot/")
            for p in git(
                "diff",
                "--name-only",
                "--diff-filter=M",
                old,
                src,
                "--",
                "godot/scripts/",
            )
            .decode()
            .splitlines()
            if p.endswith(".gd")
        }
    )
versions = {p: git("show", src + ":godot/" + p).decode() for p in paths}
numberonly = "extends RefCounted\nconst DEFAULT_ACTORS := 8\nconst DEFAULT_BODIES := 64\nconst MAX_ACTORS := 4096\nconst MAX_BODIES := 4096\n"
(d / "godot/scripts/equipment_numeric_contract_probe.gd").write_bytes(
    numberonly.encode()
)
variants = {"source": versions.copy()}
if phase == "deps":
    c = versions.copy()
    c[paths[0]] = c[paths[0]].replace(
        "res://scripts/workbench_sandbox_capacity.gd",
        "res://scripts/equipment_numeric_contract_probe.gd",
    )
    variants["equipment_preload_numeric_contract"] = c
    c = versions.copy()
    for p in paths[:2]:
        c[p] = c[p].replace("CyberRigidBodyCoupling.MAX_BODIES", "4096")
    variants["equipment_coupling_constant_numeric"] = c
elif phase == "all_scripts":
    variants["all_prior_changed_scripts"] = {
        p: git("show", old + ":godot/" + p).decode() for p in paths
    }
elif phase == "leaf":
    c = versions.copy()
    c[paths[0]] = c[paths[0]].replace(
        "res://scripts/workbench_sandbox_capacity.gd",
        "res://scripts/equipment_numeric_contract_probe.gd",
    )
    c[paths[2]] = (
        c[paths[2]]
        .replace(
            "extends RefCounted",
            'extends "res://scripts/equipment_numeric_contract_probe.gd"',
        )
        .replace("const DEFAULT_ACTORS := 8\n", "")
        .replace("const DEFAULT_BODIES := 64\n", "")
        .replace("const MAX_ACTORS := 4096\n", "")
        .replace("const MAX_BODIES := 4096\n", "")
    )
    variants["shared_numeric_leaf"] = c
elif phase == "donor":
    c = versions.copy()
    old = "80caeece153ac6f4be137c80164f78de364cc4cc"
    c[paths[0]] = git("show", old + ":godot/" + paths[0]).decode()
    variants["historical_physical_only"] = c.copy()
    c[paths[1]] = git("show", old + ":godot/" + paths[1]).decode()
    variants["historical_physical_and_sampled"] = c
else:
    raise ValueError(phase)
labels = list(variants)
marker = (
    b"SCRIPT_EQUIPMENT_RETIRED"
    if fixture.name == "script.gd"
    else b"33 checks, 0 failures"
)
rows = []


def flush():
    j = dict(
        source=src,
        phase=phase,
        script=fixture.name,
        fixture_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),
        godot=engine_hash,
        native=native_hash,
        variants={
            k: {
                p: hashlib.sha256(txt.encode()).hexdigest()
                for p, txt in v.items()
                if txt != versions[p]
            }
            for k, v in variants.items()
        },
        rows=rows,
    )
    (run / "result.json").write_text(json.dumps(j, indent=2) + "\n")


for i in range(N):
    rotated = labels[i % len(labels) :] + labels[: i % len(labels)]
    if i // len(labels) % 2:
        rotated.reverse()
    for label in rotated:
        for p, content in variants[label].items():
            (destination / p).write_bytes(content.encode())
        log = run / f"{i}-{label}.log"
        with log.open("wb") as f:
            process = subprocess.run(
                [
                    str(engine),
                    "--headless",
                    "--path",
                    str(destination),
                    "--script",
                    str(fixture),
                ],
                cwd=checkout,
                stdout=f,
                stderr=subprocess.STDOUT,
                env=env,
                timeout=90,
            )
        data = log.read_bytes()
        row = dict(
            iteration=i,
            variant=label,
            code=process.returncode,
            marker=marker in data,
            script_error=b"SCRIPT ERROR:" in data,
            log_sha256=hashlib.sha256(data).hexdigest(),
        )
        rows.append(row)
        flush()
        assert row["marker"] and not row["script_error"], (row, data[-750:])
    if i % 6 == 5:
        print(
            i + 1,
            [
                (label, sum(x["code"] != 0 for x in rows if x["variant"] == label))
                for label in labels
            ],
            flush=True,
        )
for p, content in versions.items():
    (destination / p).write_bytes(content.encode())
print(
    run,
    [
        (label, sum(x["code"] != 0 for x in rows if x["variant"] == label))
        for label in labels
    ],
    flush=True,
)
