"""Reduce retained successful workflow/parity evidence; no test execution."""
from __future__ import annotations

import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
SOURCE = "73018218092e79fbe935aa60890e33bd9f4859ac"
TREE = "ede95a3ad7102f4059f8b425167c7fa6c1948663"
BASELINE = "0fd4af5987e77db4da3e37c757cf2c0917ae9e15"


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def write(name: str, value):
    (OUT / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


remote = json.loads((OUT / "final-workflow-readback.json").read_text())
assert remote["source"] == SOURCE and remote["run_id"] == 45003383402
job = remote["jobs"][0]
assert job["id"] == 137149569699 and job["status"] == "completed" and job["conclusion"] == "success"
skipped = [step["name"] for step in job["steps"] if step["conclusion"] == "skipped"]
assert skipped == ["Validate dependency pins and published runtime provenance"]
assert all(step["conclusion"] in ("success", "skipped") for step in job["steps"])
artifact = next(a for a in remote["artifacts"] if a["id"] == 14746754332)
assert artifact["workflow_run"]["head_sha"] == SOURCE
zip_path = ROOT / "build/m3-material-transition/delivery/m3-transition-artifact-14746754332.zip"
archive = zip_path.read_bytes()
assert len(archive) == artifact["size_in_bytes"] == 8648
assert "sha256:" + digest(archive) == artifact["digest"]
with zipfile.ZipFile(zip_path) as z:
    assert z.namelist() == ["native-parity.json"] and z.testzip() is None
    member = z.read("native-parity.json")
parity = json.loads(member)
assert digest(member) == "0681d19649f98dd514d83f7aeae439438da59e09fc15f7e8bd867611b4093573"
assert parity["status"] == "PASS"
assert parity["schema_id"] == "cybersand.material-catalogue.native-parity"
assert parity["source_commit"] == BASELINE
assert parity["world_executed"] is False and parity["godot_executed"] is False
assert parity["physics_qualification"] is False

local_guard_path = ROOT / "build/m3-material-transition/compatibility.json"
local_guard = json.loads(local_guard_path.read_text())
assert parity["protected_sources"] == local_guard
assert local_guard["status"] == "PASS" and len(local_guard["reviewed_transitions"]) == 54
input_rows = []
for entry in parity["inputs"] + parity["tool_sources"]:
    committed = subprocess.check_output(["git", "show", SOURCE + ":" + entry["path"]], cwd=ROOT)
    normalized = committed.replace(b"\r\n", b"\n")
    assert len(normalized) == entry["bytes"]
    assert digest(normalized) == entry["sha256"], entry["path"]
    input_rows.append(entry)
assert len(input_rows) == 8

log_path = OUT / remote["log"]
log_bytes = log_path.read_bytes()
log = log_bytes.decode()
assert len(log) == remote["decoded_log_characters"]
clean = re.sub(r"(?m)^\d{4}-\d\d-\d\dT[0-9:.]+Z ", "", log)
matches = list(re.finditer(r"Ran 231 tests in ([0-9.]+)s\n\s*OK", clean))
assert len(matches) == 1
seconds = float(matches[0].group(1))
assert seconds == 438.570
assert "FAILED (" not in clean and "##[error]Process completed with exit code" not in clean
position = clean.index('{\n  "commands": {')
logged_parity, _ = json.JSONDecoder().raw_decode(clean[position:])
assert logged_parity == parity

checkout = json.loads((OUT / "checkout-merge-commit.json").read_text())
assert checkout["sha"] == "bd8a9503507273c3348b2e711e6b3638860a9274"
assert checkout["tree"]["sha"] == TREE
assert SOURCE in [parent["sha"] for parent in checkout["parents"]]
assert checkout["sha"] in log
assert subprocess.check_output(["git", "rev-parse", SOURCE + "^{tree}"], cwd=ROOT).decode().strip() == TREE

report = {
    "schema": "objectshard-independent-material-transition-final-completion-v1",
    "reviewer": "review_custody; independent source, workflow and artifact audit",
    "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "status": "passed: substantive reviewed transition completed and ordinary executed documentation/catalogue gates qualified; production runtime provenance remains unpassed",
    "confirmed_unrepaired_findings_in_transition_scope": [],
    "tool_source_commit": SOURCE, "tool_source_tree": TREE,
    "qualified_runtime_source": "e034f2294663e0485cfb9adcc8ada46a6e977cee",
    "source_review": {"path": "source-review.json", "sha256": digest((OUT / "source-review.json").read_bytes())},
    "published_source_review": {"path": "published-source-review.json", "sha256": digest((OUT / "published-source-review.json").read_bytes())},
    "precision_addendum": {"path": "precision-and-local-guard-review.json", "sha256": digest((OUT / "precision-and-local-guard-review.json").read_bytes())},
    "local_exact_committed_guard": {"path": str(local_guard_path.relative_to(ROOT)), "sha256": digest(local_guard_path.read_bytes()), "status": "PASS", "reviewed_transitions": 54, "protected_sources": 27},
    "workflow": {
        "run_id": 45003383402, "job_id": 137149569699, "conclusion": "success",
        "raw_log": log_path.name, "raw_log_bytes": len(log_bytes), "raw_log_sha256": digest(log_bytes),
        "catalogue_tests": 231, "catalogue_seconds": seconds, "catalogue_result": "OK",
        "subsequent_executed_gates": "LCB scenarios/registry, M11, validation contracts, soliding contracts, lockstep reducer, retrieval, LFS and whitespace all succeeded",
        "skipped_steps": skipped,
        "checkout_merge_commit": checkout["sha"], "checkout_tree": checkout["tree"]["sha"],
        "checkout_tree_equals_published_source": True,
        "scope": "The GitHub pull-request merge checkout is a qualification ref with the same tree; no owner-authorized repository merge occurred.",
    },
    "native_metadata_parity": {
        "artifact_id": artifact["id"], "archive_bytes": len(archive), "archive_sha256": digest(archive),
        "member": "native-parity.json", "member_bytes": len(member), "member_sha256": digest(member),
        "member_equals_actual_logged_json": True, "status": parity["status"],
        "source_tool_inputs_verified": input_rows,
        "protected_result_equals_local_guard": True,
        "world_executed": False, "godot_executed": False, "physics_qualification": False,
        "source_commit_field_scope": "The parity receipt's source_commit names the immutable compatibility baseline, not the workflow checkout. Workflow/artifact identity, equal checkout tree, eight exact input facts and the 54-step protected result bind this run to the published guard.",
        "production_cutover_field_scope": "The pre-existing true field describes the previously adopted material capability consumer (#563). It is not ObjectShard production adoption and was not changed by this transition.",
    },
    "preserved_negatives": [44989675198, 44999120750, 45002794045],
    "final_disposition": [
        "The omitted finisher compatibility step is repaired through the existing authenticated per-file mechanism, with one appended entry and substantive independent review. All 53 preceding entries, remaining guard AST, baseline, frozen lock and identity inputs remain unchanged.",
        "The original predicate change is inherited from c065 and is already in qualified 001R and e034 runtime inputs. The new guard and record do not change the delivered native code, material laws or owner ZIP. No platform/package rebuild or repeated physics campaign was required or claimed.",
        "The opportunity is claimed by recorded contact before the native tick; shard chemistry follows that tick. The claim helper checks watched bounds, not chunk residency. One claimed opportunity suppresses one ordinary ignite() attempt for any supported target, while source lifetime and transport continue.",
        "Six ordinary retained-runtime provenance mismatches remain. Their Draft workflow step is skipped; the successful documentation result does not establish production publication or clear that separate gate.",
        "Before future authorized mergedown, carry the reviewed step and record to the earliest dependent #738 head containing c065 and retain the ancestry through merge commits. No donor branch modification, Ready transition, merge, release or production-default adoption is authorized by this review.",
        "The corrected audit wording and final evidence will be a later documentation descendant. Its exact published identity and input continuity must be reported separately; this completion qualifies the guard source at 73018218.",
    ],
}
write("completion-review.json", report)
files = []
for path in sorted(OUT.rglob("*")):
    if path.is_file() and path.name != "retention-manifest.json" and "__pycache__" not in path.parts:
        raw = path.read_bytes()
        files.append({"path": str(path.relative_to(OUT)), "bytes": len(raw), "sha256": digest(raw)})
write("retention-manifest.json", {
    "schema": "objectshard-independent-material-transition-retention-v1",
    "utc": report["utc"], "tool_source_commit": SOURCE, "tool_source_tree": TREE,
    "qualified_runtime_source": report["qualified_runtime_source"], "files": files,
    "scope": "This later transition audit supplements the unchanged sealed e034 review. Historical failures remain exact retained logs. The manifest excludes itself; downloaded parity ZIP/member remain in the separately authenticated delivery directory.",
})
for name in ("completion-review.json", "retention-manifest.json"):
    raw = (OUT / name).read_bytes()
    print(name, len(raw), digest(raw))
print("retained_files", len(files))
