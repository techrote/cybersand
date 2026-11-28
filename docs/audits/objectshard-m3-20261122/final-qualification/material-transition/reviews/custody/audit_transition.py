"""Read-only source review of the inherited ObjectShard Fire compatibility step.

Writes only its independent review directory. It neither changes the guard nor
executes native/runtime qualification; those source-bound results are retained.
"""
from __future__ import annotations

import ast
import datetime
import hashlib
import json
from pathlib import Path
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
PREVIOUS = "5afe5643097c543f7d8a6840ced9afac58dd053e"
SOURCE = "c06550371ac5448642bff7e4ecb64fe9cd1df728"
QUALIFIED = "e034f2294663e0485cfb9adcc8ada46a6e977cee"
PRE_GUARD_HEAD = "10d191bbf"
TOOL = "tools/material_catalogue/compatibility.py"
RECORD = "docs/audits/2026-11-22-objectshard-external-fire-world-transition.md"
WORLD = "native/src/world.cpp"
FROM = "bc24ccd2e7457f61c75abdc13d20c2ccd82863fdf427f0c13ccaa1a05ad9d214"
TO = "5bb8ccded21bb73077ea86086d6fb25b9cbca67bda84013e67fa87d96b1c8cd1"


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args], cwd=ROOT)


def hash_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def lf(value: bytes) -> bytes:
    return value.replace(b"\r\n", b"\n")


def write(name: str, value):
    (OUT / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def module(code: bytes) -> dict:
    namespace = {"__name__": "independent_transition_review", "__file__": str(ROOT / TOOL)}
    exec(compile(code, TOOL, "exec"), namespace)
    return namespace


def other_ast(code: bytes) -> str:
    tree = ast.parse(code)
    tree.body = [node for node in tree.body if not (
        isinstance(node, ast.AugAssign) and isinstance(node.target, ast.Name)
        and node.target.id == "REVIEWED_TRANSITIONS"
    )]
    return ast.dump(tree, include_attributes=False)


old_tool = git("show", PRE_GUARD_HEAD + ":" + TOOL)
new_tool = (ROOT / TOOL).read_bytes()
old, new = module(old_tool), module(new_tool)
old_steps, new_steps = old["REVIEWED_TRANSITIONS"], new["REVIEWED_TRANSITIONS"]
assert len(old_steps) == 53 and len(new_steps) == 54
assert new_steps[:-1] == old_steps
expected_entry = {
    "path": WORLD, "from_lf_sha256": FROM, "to_lf_sha256": TO,
    "source_commit": SOURCE, "record": RECORD, "issue": 281, "pr": 741,
}
assert new_steps[-1] == expected_entry
assert other_ast(old_tool) == other_ast(new_tool)
assert WORLD not in new["IDENTITY_INPUTS"]

identities = []
for path in sorted(new["IDENTITY_INPUTS"]):
    current = (ROOT / path).read_bytes()
    assert lf(current) == lf(git("show", PREVIOUS + ":" + path))
    identities.append({"path": path, "lf_sha256": hash_bytes(lf(current))})
assert len(identities) == 12
lock_path = "materials/catalogue/compatibility-lock.json"
lock = (ROOT / lock_path).read_bytes()
assert lock == git("show", PRE_GUARD_HEAD + ":" + lock_path)

source_bytes = {}
for commit in (PREVIOUS, SOURCE, "514d76fbf4df30eb05353bc14b6a4ec3ea9bf61c",
               "44abd754d014a44078a41792d2d46967a9b8cf30", QUALIFIED, PRE_GUARD_HEAD):
    value = git("show", commit + ":" + WORLD)
    actual = hash_bytes(lf(value))
    assert actual == (FROM if commit == PREVIOUS else TO)
    source_bytes[git("rev-parse", commit).decode().strip()] = {
        "bytes": len(value), "lf_sha256": actual,
        "git_blob": git("rev-parse", commit + ":" + WORLD).decode().strip(),
    }
old_world = git("show", PREVIOUS + ":" + WORLD)
new_world = git("show", SOURCE + ":" + WORLD)
old_predicate = b"            if (slow_interaction_due(10U)) {\n"
new_predicate = (
    b"            if (slow_interaction_due(10U) && (object_shard_mutations_ == nullptr ||\n"
    b"                !object_shard_mutations_->external_fire_claimed(x, y, tick_index_))) {\n"
)
# Exact replacement, not a loose description of a larger consumer edit.
assert old_world.count(old_predicate) == 1
assert old_world.replace(old_predicate, new_predicate) == new_world
assert (ROOT / WORLD).read_bytes() == new_world
for a, b in ((PREVIOUS, SOURCE), (SOURCE, "HEAD")):
    assert subprocess.run(["git", "merge-base", "--is-ancestor", a, b], cwd=ROOT).returncode == 0

record_bytes = (ROOT / RECORD).read_bytes()
for fact in (WORLD, FROM, TO, SOURCE):
    assert fact in record_bytes.decode()

inventory = json.loads((ROOT / "build/review-custody/final-e034f229/source-inventory.json").read_text())
continuity = json.loads((ROOT / "docs/audits/objectshard-m3-20261122/final-qualification/runtime-input-continuity.json").read_text())
input_exclusion = {}
for name, entries in continuity["groups"].items():
    assert TOOL not in entries
    input_exclusion[name] = {"inputs": len(entries), "contains_guard": False}
assert TOOL not in inventory["packaged_repository_inputs_sha256"]
input_exclusion["packaged_repository_inputs"] = {
    "inputs": len(inventory["packaged_repository_inputs_sha256"]), "contains_guard": False,
}
runtime_delta = git("diff", "--name-only", QUALIFIED, "--", "native", "godot", "tools/objectshard",
                    ".github/workflows/objectshard-lab.yml", "docs/operations/objectshard-lab-playtest.md",
                    "docs/operations/objectshard-m3-preflight-playtest.md").decode().splitlines()
assert not runtime_delta, runtime_delta

workflow = json.loads((OUT / "workflow-readback.json").read_text())
for row in workflow["runs"]:
    if row["source"] == PRE_GUARD_HEAD:
        row["source"] = git("rev-parse", PRE_GUARD_HEAD).decode().strip()
    log = (OUT / row["log"]).read_bytes()
    row["stored_log_sha256"] = hash_bytes(log)
    row["stored_log_bytes"] = len(log)
    text = log.decode()
    assert len(text) == row["original_decoded_content_characters"]
    assert FROM in text and TO in text and "A further edit needs its own reviewed transition" in text
    step = next(x for x in row["jobs"]["jobs"][0]["steps"] if x["name"] == "Check material catalogue shadow compatibility")
    assert step["conclusion"] == "failure"
    provenance = next(x for x in row["jobs"]["jobs"][0]["steps"] if x["name"] == "Validate dependency pins and published runtime provenance")
    assert provenance["conclusion"] == "skipped"
write("workflow-readback.json", workflow)

qualified_review = ROOT / "build/review-custody/final-e034f229/linux-execution-review.json"
linux = json.loads(qualified_review.read_text())
external = next(x for x in linux["native_sanitizer"]["suites"] if x["suite"] == "external_fire")
assert external["checks"] == 3683 and linux["native_sanitizer"]["checks"] == 93529
assert linux["native_sanitizer"]["world_test_cases"] == 192
review = {
    "schema": "objectshard-independent-material-transition-source-review-v1",
    "reviewer": "review_custody; independent of the inherited native change and transition implementation",
    "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "pre_transition_publication": git("rev-parse", PRE_GUARD_HEAD).decode().strip(),
    "qualified_runtime_source": QUALIFIED,
    "status": "Source review passes; the appended substantive reviewed transition is justified. Committed-record guard and ordinary workflow validation remain separate pending results.",
    "findings": [],
    "new_entry": expected_entry,
    "source_bytes": source_bytes,
    "exact_world_delta": {"old": old_predicate.decode(), "new": new_predicate.decode(), "only_replacement": True},
    "guard_integrity": {
        "prior_entries": 53, "candidate_entries": 54, "all_prior_entries_equal": True,
        "all_other_python_ast_equal": True, "baseline": new["BASELINE"],
        "lock_lf_sha256": hash_bytes(lf(lock)), "lock_unchanged": True,
        "identity_inputs_unchanged_since_prior_reviewed_source": identities,
        "old_tool_sha256": hash_bytes(old_tool), "candidate_tool_sha256": hash_bytes(new_tool),
        "record_sha256": hash_bytes(record_bytes),
    },
    "behavior_review": [
        "Ordinary Worlds leave the private unique_ptr mutation journal null. The original slow_interaction_due predicate is evaluated once and in the original order; null short-circuiting makes the added conjunct true without consulting any claim span.",
        "Only an enabled ObjectShard journal with a resident, same-tick, already-claimed external Fire opportunity suppresses the existing ignition attempt. That is the intended opt-in ownership correction, not default World behavior equivalence for enabled ObjectShards.",
        "The deterministic sample, ignition value, remaining Fire lifetime transition, transport, thermal behavior and surrounding rule order are byte-identical in the full protected consumer diff. The shared Wood lifecycle law is not rewritten by this delta.",
        "MutationJournal::external_fire_claimed is a const noexcept bounded query: exact tick, nonempty span, contains(x,y), then the claimed bit. A missing, out-of-range or different-tick claim returns false.",
        "The coordinator owns the fixed claim storage. Its serial native World receives the const span immediately before tick; normal completion and exception paths both clear the borrowed span. No Rapier, additional World or additional chemistry clock is introduced.",
        "Existing source-bound tests explicitly cover one source opportunity across bodies/segments, suppression of a second World ignition after displacement, continued Fire lifetime and transport, cleared reset history and failed-motion recovery. The final native external-Fire suite passed 3,683 checks; ordinary World passed 192 unfiltered cases.",
    ],
    "existing_qualification": {
        "run_id": 44999117090, "linux_artifact": 14746310288,
        "linux_review_sha256": hash_bytes(qualified_review.read_bytes()),
        "native_checks": 93529, "external_fire_checks": 3683, "ordinary_world_cases": 192,
        "asan": True, "ubsan": True, "leak_sanitizer": False,
        "scope": "Previously independently verified final runtime execution; no new native campaign or newly claimed behavior comparison was performed for this review.",
    },
    "package_input_exclusion": input_exclusion,
    "runtime_input_delta_from_qualified_source": runtime_delta,
    "owner_zip": {"bytes": 93168827, "sha256": "61678a8c8ae3ab8e3b05cbb624fe15b4b259710fd879aa209542583a78b74a0b", "requires_rebuild_for_guard_entry": False},
    "inherited_gate_failures": [
        {"source": row["source"], "run": row["run"], "job": row["job"], "log": row["log"],
         "log_sha256": row["stored_log_sha256"], "failure_lines": row["failure_lines"]}
        for row in workflow["runs"]
    ],
    "disposition": [
        "Complete the existing reviewed per-file transition mechanism with this single authenticated source step and substantive committed record. Do not refresh the lock, replace the old transition, modify the guard checks or edit runtime provenance manifests.",
        "This is a compatibility-tool/evidence descendant of e034, not a purely documentation descendant. Runtime and delivered package qualification remain explicitly attributed to e034.",
        "The compatibility guard requires the audit record committed at HEAD. A precommit source review is not a passing guard result. Report focused guard tests and the full ordinary documentation workflow separately after publication.",
        "The missing transition predates M3: the same failure is independently retained at #738, e034 and the documentation descendant. It is distinct from six retained native-runtime provenance failures, whose Draft workflow step was skipped.",
        "Before an owner-authorized #738 mergedown, carry the entry and record onto the earliest dependent head containing c065 and qualify that exact head. Do not modify or merge the donor branch in this mission.",
        "Preserve the reviewed source ancestry through merge commits. Squash or rebase requires separately reviewed repointing to an actual retained source commit; a green material-catalogue check never clears native-runtime provenance or grants merge authority.",
    ],
}
write("source-review.json", review)
for name in ("source-review.json", "workflow-readback.json"):
    print(name, hash_bytes((OUT / name).read_bytes()))
