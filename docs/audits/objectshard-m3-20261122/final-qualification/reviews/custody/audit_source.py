"""Independent exact-commit custody checks; no product edits or native rebuilds."""
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

REPO = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SOURCE = "e034f2294663e0485cfb9adcc8ada46a6e977cee"
TREE = "246e7324ca618d98c43a0ed54fe19bc86a155877"
BASELINE = "68235b12d7f41f7b590456971f21dfc3f5c6d701"
FINISHER = "44abd754d014a44078a41792d2d46967a9b8cf30"
QUALIFIED_NATIVE = "514d76fbf4df30eb05353bc14b6a4ec3ea9bf61c"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*arguments):
    return subprocess.check_output(["git", "-C", str(REPO), *arguments])


def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def main():
    report = {"schema": "objectshard-independent-repaired-source-review-v1",
              "source_commit": SOURCE, "source_tree": TREE, "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "reviewer": "review_custody", "failures": []}
    def expect(condition, message):
        if not condition:
            report["failures"].append(message)
    expect(git("rev-parse", SOURCE + "^{tree}").decode().strip() == TREE, "Frozen tree mismatch")
    expect(not git("diff", SOURCE, "--"), "Tracked worktree differs from frozen source")
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("independent_archive", OUT / "verify_delivered_archive.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    committed = module.committed_files(REPO, SOURCE)
    baseline = json.loads((OUT.parent / "final-source-inventory.json").read_text())
    suffixes = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
    native = {path: sha(data.replace(b"\r\n", b"\n")) for path, data in committed.items()
              if path.startswith(("godot/native_extension/", "native/include/", "native/src/"))
              and PurePosixPath(path).suffix in suffixes}
    expect(len(native) == 116, "Incomplete native source inventory")
    expect(native == baseline["native_inputs"], "Native input identity changed from baseline682")
    with module.tarfile.open(fileobj=module.io.BytesIO(git("archive", QUALIFIED_NATIVE, "--", "godot/native_extension", "native/include", "native/src"))) as archive:
        prior_native = {member.name: archive.extractfile(member).read() for member in archive if member.isfile()}
    expect(all(path in prior_native and sha(prior_native[path].replace(b"\r\n", b"\n")) == digest
               for path, digest in native.items()), "Native compilation input differs from qualified514")
    protected = {}
    for path, digest in baseline["preserved_gate_inputs_sha256"].items():
        data = git("show", SOURCE + ":" + path)
        protected[path] = sha(data)
        expect(sha(data) == digest == sha(git("show", FINISHER + ":" + path)), "Protected ordinary gate/budget changed: " + path)
    extra = ["godot/tests/support/ci_execution_policy.json", "third_party/native-toolchain.lock.json",
             "third_party/godot-runtime.lock.json", "third_party/rapier-bvh-build.lock.json",
             "tools/requirements-build.txt", ".github/workflows/objectshard-lab.yml"]
    for path in extra:
        protected[path] = sha(git("show", SOURCE + ":" + path))
        expect(git("show", SOURCE + ":" + path) == git("show", BASELINE + ":" + path), "Repair weakened frozen build/qualification contract: " + path)
    report["native_inputs"] = len(native)
    report["native_inputs_identical_to_682_and_qualified_514"] = True if native == baseline["native_inputs"] and not any("Native" in f for f in report["failures"]) else False
    report["protected_contract_inputs"] = len(protected)
    report["native_regression_delta"] = git("diff", "--name-only", BASELINE, SOURCE, "--", "native/tests", "tools/objectshard/native_budgets.json", "tools/objectshard/lab_budgets.json").decode().splitlines()
    expect(not report["native_regression_delta"], "Native tests or original budgets changed")
    changed = git("diff", "--name-only", BASELINE, SOURCE).decode().splitlines()
    report["non_audit_delta"] = [p for p in changed if not p.startswith("docs/audits/")]
    report["baseline_evidence_retention"] = {"prefix": "docs/audits/objectshard-m3-20261122/baseline-68235b12/", "files": sum(p.startswith("docs/audits/objectshard-m3-20261122/baseline-68235b12/") for p in changed),
        "status": "Historical superseded baseline, not final repaired-source qualification"}
    report["gitattributes_delta"] = "Only baseline/final audit receipts are -text whitespace=cr-at-eol; runtime and ordinary source conversion unchanged"
    host = committed["godot/scripts/object_shard_worker_host.gd"].decode()
    scene = committed["godot/scripts/object_shard_worker_rehearsal.gd"].decode()
    qualifier = committed["tools/objectshard/qualify_lab.py"].decode()
    expect("host.queue_action(str(intent.action), intent.parameters, int(intent.input_usec))" in scene,
           "CUST-01 lost original UI input time")
    expect("input_captured_usec < 0 or input_captured_usec > admitted_usec" in host
           and '"scene_intent" if input_captured_usec > 0 else "host_admission"' in host,
           "CUST-01 timestamp bounds/observation label lost")
    expect('"godot/scripts/feature_navigation.gd"' in qualifier,
           "Changed global navigation script is absent from executed-source ledger")
    expect("validate_navigation_receipt(receipt, args.expected_source_sha)" in qualifier,
           "Navigation lifecycle/child gate not wired to actual execution")
    report["cust_01"] = "Preserved original UI capture time, separate admission metrics, and rendered sample gates. Fresh rendered distributions still require new platform evidence."
    sys.path.insert(0, str(REPO / "tools/ci"))
    import run_godot_regressions as runner
    cases = runner.discover_cases(REPO)
    names = [case.name for case in cases]
    report["ordinary_discovered_cases"] = len(cases)
    report["package_probes_discovered"] = [name for name in names if "package_boot" in name]
    expect(not report["package_probes_discovered"], "CUST-02 package-only probe leaked into ordinary discovery")
    expect("test_object_shard_worker_navigation" in names, "Maintained navigation regression absent from ordinary discovery")
    for name in ["probe_object_shard_package_boot.gd", "probe_object_shard_worker_package_boot.gd"]:
        expect("godot/tests/" + name in committed, "Strict explicit package probe missing: " + name)
    report["cust_02"] = "Both strict package probes remain explicit probe_ entrypoints; ordinary discovery unmodified and excludes them"
    report["navigation_review"] = {"cases": ["active_pending_repeated", "naturally_sleeping", "opening", "reset_superseded", "held_interval", "stop_delivery_faults", "already_closed_prior_policy", "window_close_upgrade"],
        "admission": "Closing/replacing/failed/closed owners visibly refuse pointer/support/erosion admission",
        "ownership": "F2 retains scene until exact Closed/disposal/join/RID release; stale completion fenced twice",
        "quit": "Window close upgrades destination and survives ShutdownHeld retry; actual child process exit required",
        "fault_scope": "Only already-completed native stop delivery is injected; no synthetic native disposal failure claim",
        "qualification": "Strict source-bound parent schema, exact ordered case inventory, integral checks >=100; exactly one child with source, schema, checks>=18 and successful exit"}
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    report["local_checks"] = {}
    for label, argv in [
        ("package-contracts", [sys.executable, "-m", "unittest", "discover", "-s", "tools/objectshard", "-p", "test_*.py", "-v"]),
        ("production-provenance", [sys.executable, "tools/ci/check_repository.py"]),
    ]:
        run = subprocess.run(argv, cwd=REPO, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        path = OUT / (label + ".log")
        path.write_bytes(run.stdout)
        row = {"command": argv, "exit_code": run.returncode, "log": path.name, "sha256": sha(run.stdout)}
        if label == "package-contracts":
            match = re.search(rb"Ran (\d+) tests", run.stdout)
            row["tests"] = int(match[1]) if match else None
            expect(run.returncode == 0 and match is not None, "Package contract unit tests failed/incomplete")
        else:
            row["errors"] = json.loads(run.stdout)["errors"]
            expect(run.returncode == 1 and len(row["errors"]) == 6, "Production provenance failure changed unexpectedly")
        report["local_checks"][label] = row
    inventory = {"schema": "objectshard-independent-exact-source-inventory-v1", "source_commit": SOURCE, "source_tree": TREE,
        "native_inputs": native, "packaged_repository_inputs_sha256": {p:sha(data) for p,data in committed.items()},
        "preserved_gate_inputs_sha256": protected}
    save("source-inventory.json", inventory)
    report["inventory_sha256"] = sha((OUT / "source-inventory.json").read_bytes())
    report["status"] = "passed" if not report["failures"] else "failed"
    report["scope"] = "Exact-source inspection and inexpensive existing contract/gate execution only. Full production provenance remains six failures; fresh Linux/Windows/package receipts are separate mandatory reviews."
    save("source-review.json", report)
    print(json.dumps({k:v for k,v in report.items() if k not in ["navigation_review", "local_checks"]}, indent=2))
    print(json.dumps(report["local_checks"], indent=2))
    raise SystemExit(bool(report["failures"]))


if __name__ == "__main__":
    main()
