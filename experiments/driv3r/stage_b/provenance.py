"""Stage B request admission, frozen inputs, source custody and evidence archive.

Hashing and native source custody reuse Stage A's qualified implementation.
Stage B has separate request, custody, publication and artifact identities;
packaging original failures never converts them into successful qualification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

from .. import provenance as foundation
from .catalog import CATALOGS, catalogs


ROOT = foundation.ROOT
ACCEPTED_STAGE_A = "ee95f547f31fb1ac9cdd34536bf36dffe7af1d0c"
BRANCH = "refs/heads/research/570-driv3r-stage-a"
REQUEST_PATH = "experiments/driv3r/stage_b/qualification-request.json"
PROTOCOL_PATH = "experiments/driv3r/stage_b/protocol.json"
REQUEST_FIELDS = {
    "schema": "driv3r-stage-b-request-v1", "foundation_sha": foundation.FOUNDATION,
    "accepted_base": foundation.ACCEPTED_BASE, "accepted_stage_a_sha": ACCEPTED_STAGE_A,
    "model": "LiquidAI/d1-2B-GGUF", "quantization": "Q8_0", "stage": "B",
    "training": False, "schedules": False, "production_defaults": False,
    "publish_research_evidence": True,
}
LIMITS = {"max_model_requests": 144, "max_campaign_seconds": 5400,
          "max_changed_cells_per_episode": 1024, "max_episode_seconds": 420,
          "request_seconds": 60, "direct_max_decisions": 8,
          "fuzzy_max_decisions": 1, "vector_max_decisions": 2}


def _sha(value, length=64):
    return isinstance(value, str) and re.fullmatch(r"[a-f0-9]{%d}" % length, value) is not None


def validate_request(data: object) -> dict:
    fields = set(REQUEST_FIELDS) | {"sequence", "protocol_sha256", "catalog_sha256"}
    if type(data) is not dict or set(data) != fields:
        raise ValueError("Stage B request fields differ from the frozen contract")
    for key, expected in REQUEST_FIELDS.items():
        if type(data[key]) is not type(expected) or data[key] != expected:
            raise ValueError("Unapproved Stage B request field: " + key)
    if type(data["sequence"]) is not int or not 1 <= data["sequence"] <= 1000:
        raise ValueError("Request sequence must be an integer in 1..1000")
    if not _sha(data["protocol_sha256"]):
        raise ValueError("Full frozen protocol SHA256 required")
    if (type(data["catalog_sha256"]) is not dict or set(data["catalog_sha256"]) != set(CATALOGS)
            or not all(_sha(value) for value in data["catalog_sha256"].values())):
        raise ValueError("Exactly the three frozen Stage B catalog hashes are required")
    return dict(data)


def validate_protocol(data: object) -> dict:
    keys = {"schema", "accepted_stage_a_sha", "purpose", "primary_encoding", "runtime", "development", "held_out",
            "random_seeds", "additional_baseline", "limits", "probes", "scoring", "stage_c_gate", "freeze_policy", "claims"}
    if type(data) is not dict or set(data) != keys:
        raise ValueError("Stage B protocol shape differs from frozen contract")
    expected = {"schema": "driv3r-stage-b-protocol-v1", "accepted_stage_a_sha": ACCEPTED_STAGE_A,
                "primary_encoding": "compact", "random_seeds": [570, 571, 572], "limits": LIMITS,
                "development": {"direct": 2, "fuzzy": 2, "vector": 1,
                                "policies": ["model", "geometric_or_fixed", "random_570"]},
                "held_out": {"direct": 4, "fuzzy": 4, "vector": 3,
                             "policies": ["model", "geometric_or_fixed", "random_570", "random_571", "random_572"]}}
    for key, value in expected.items():
        # Canonical JSON comparison also refuses bool-as-integer substitutions.
        if foundation.canonical(data[key]) != foundation.canonical(value):
            raise ValueError("Unapproved frozen Stage B protocol value: " + key)
    runtime = data["runtime"]
    if (type(runtime) is not dict or set(runtime) != {"cpu_threads", "context_tokens", "physical_batch_tokens", "reason"}
            or any(type(runtime[key]) is not int or runtime[key] != value for key, value in
                   (("cpu_threads", 2), ("context_tokens", 4096), ("physical_batch_tokens", 4096)))
            or type(runtime["reason"]) is not str or not runtime["reason"]):
        raise ValueError("Stage B runtime resources differ from the explicitly measured bound")
    probes = data["probes"]
    if (type(probes) is not dict or probes.get("no_native_execution") is not True
            or probes.get("development") != ["canonical", "compact_repeat", "original_stage_a", "without_host_metrics_direct_only"]
            or probes.get("held_out") != ["canonical", "compact_repeat", "reverse_candidates", "objective_paraphrase", "without_host_metrics_direct_only"]):
        raise ValueError("Stage B probes must remain bounded paired read-only decisions")
    gate = data["stage_c_gate"]
    if type(gate) is not dict or gate.get("family_success") != {"direct": 3, "fuzzy": 3, "vector": 2}:
        raise ValueError("Frozen usefulness thresholds differ")
    if type(data["scoring"]) is not dict or set(data["scoring"]) != {"direct", "fuzzy", "vector", "random", "all"}:
        raise ValueError("Stage B scoring families incomplete")
    if type(data["claims"]) is not list or not data["claims"] or any(type(v) is not str for v in data["claims"]):
        raise ValueError("Stage B claim boundaries must be explicit")
    return data


def frozen_inputs(root: Path = ROOT) -> dict:
    """Bind exact protocol and scenario bytes, including all scoring metadata."""
    protocol_file = root / PROTOCOL_PATH
    if protocol_file.is_symlink():
        raise ValueError("Protocol cannot be a symlink")
    protocol = validate_protocol(json.loads(protocol_file.read_text(encoding="utf-8")))
    fixtures, hashes = catalogs(root)
    identities, case_ids = {}, set()
    for relative in CATALOGS:
        path = root / relative
        if path.is_symlink():
            raise ValueError("Catalog cannot be a symlink")
        family = path.name.split("_")[0]
        cases = json.loads(path.read_text(encoding="utf-8"))["cases"]
        counts = {split: sum(case.get("split") == split for case in cases)
                  for split in ("development", "held_out")}
        if (sum(counts.values()) != len(cases)
                or any(counts[split] != protocol[split][family] for split in counts)):
            raise ValueError("Catalog split differs from frozen protocol: " + family)
        for case in cases:
            ident = case.get("id")
            if not isinstance(ident, str) or not ident.startswith("b-"+family+"-") or ident in case_ids:
                raise ValueError("Duplicate or wrong-family Stage B case identity")
            case_ids.add(ident)
            if (type(case.get("objective")) is not str or type(case.get("paraphrase")) is not str
                    or not case["objective"] or not case["paraphrase"] or case["objective"] == case["paraphrase"]):
                raise ValueError("Each case requires a frozen distinct objective paraphrase")
        identities[family] = {"counts": counts, "case_ids": [case["id"] for case in cases]}
    return {"schema": "driv3r-stage-b-frozen-inputs-v1",
            "accepted_stage_a_sha": ACCEPTED_STAGE_A,
            "protocol_sha256": foundation.digest(protocol_file), "catalog_sha256": hashes,
            "fixture_count": len(fixtures), "cohorts": identities, "limits": protocol["limits"]}


def request_payload(sequence: int, root: Path = ROOT) -> dict:
    """Prepare a concrete request; only writing its dedicated file arms a push."""
    frozen = frozen_inputs(root)
    return validate_request({**REQUEST_FIELDS, "sequence": sequence,
                             "protocol_sha256": frozen["protocol_sha256"],
                             "catalog_sha256": frozen["catalog_sha256"]})


def _committed_bytes(root: Path, source_sha: str, relative: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), "show", source_sha+":"+relative],
                                   stderr=subprocess.PIPE, timeout=60)


def validate_trigger(data: dict, source_sha: str, root: Path = ROOT, environment=None) -> dict:
    """A push must change the dedicated request and advance its sequence once."""
    env = os.environ if environment is None else environment
    event = env.get("GITHUB_EVENT_NAME")
    if event is None and env.get("GITHUB_ACTIONS") != "true":
        return {"event": "explicit_local_cli", "sequence": data["sequence"]}
    if event not in ("push", "workflow_dispatch") or env.get("GITHUB_REF") != BRANCH:
        raise ValueError("Stage B heavy qualification requires its branch-bound explicit trigger")
    if env.get("GITHUB_REPOSITORY") != "techrote/cybersand":
        raise ValueError("Stage B qualification belongs to techrote/cybersand")
    receipt = {"event": event, "ref": env["GITHUB_REF"], "sequence": data["sequence"]}
    if event == "workflow_dispatch":
        return receipt
    payload = json.loads(Path(env["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
    before = payload.get("before")
    if not _sha(before, 40) or payload.get("after") != source_sha:
        raise ValueError("Push event does not bind its before/after source")
    if before == "0"*40:
        previous = None
    else:
        changed = foundation.git(root, "diff", "--name-only", before, source_sha, "--", REQUEST_PATH).splitlines()
        if changed != [REQUEST_PATH]:
            raise ValueError("Push did not change the explicit Stage B request file")
        try:
            previous = validate_request(json.loads(_committed_bytes(root, before, REQUEST_PATH)))
        except subprocess.CalledProcessError:
            previous = None  # First request on an existing branch.
    expected = 1 if previous is None else previous["sequence"]+1
    if data["sequence"] != expected:
        raise ValueError("Push request sequence must advance exactly once")
    return {**receipt, "before_sha": before, "previous_sequence": None if previous is None else previous["sequence"]}


def request(path: Path, source_sha: str, root: Path = ROOT, environment=None) -> dict:
    if path.resolve() != (root / REQUEST_PATH).resolve() or path.is_symlink():
        raise ValueError("Only the dedicated committed Stage B request path is accepted")
    data = validate_request(json.loads(path.read_text(encoding="utf-8")))
    if not _sha(source_sha, 40) or foundation.git(root, "rev-parse", "HEAD") != source_sha:
        raise ValueError("Request must bind the complete checked-out source SHA")
    for ancestor in (foundation.FOUNDATION, foundation.ACCEPTED_BASE, ACCEPTED_STAGE_A):
        foundation.git(root, "merge-base", "--is-ancestor", ancestor, source_sha)
    for relative in (REQUEST_PATH, PROTOCOL_PATH, *CATALOGS):
        if (root / relative).read_bytes() != _committed_bytes(root, source_sha, relative):
            raise ValueError("Uncommitted Stage B input differs from source: " + relative)
    frozen = frozen_inputs(root)
    if any(data[key] != frozen[key] for key in ("protocol_sha256", "catalog_sha256")):
        raise ValueError("Request hashes do not match the frozen protocol/catalog bytes")
    trigger = validate_trigger(data, source_sha, root, environment)
    return {"schema": "driv3r-stage-b-request-receipt-v1", "request": data,
            "source_sha": source_sha, "source_tree": foundation.git(root, "rev-parse", "HEAD^{tree}"),
            "request_sha256": foundation.digest(path), "frozen_inputs": frozen, "trigger": trigger,
            "workflow_run": os.environ.get("GITHUB_RUN_ID"),
            "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT")}


def source_identity(source_sha: str, root: Path = ROOT) -> dict:
    inherited = foundation.source_identity(source_sha, root)
    foundation.git(root, "merge-base", "--is-ancestor", ACCEPTED_STAGE_A, source_sha)
    required = [PROTOCOL_PATH, REQUEST_PATH, *CATALOGS, ".github/workflows/driv3r-stage-b.yml",
                "experiments/driv3r/ci_stage_b.sh", "experiments/driv3r/stage_b/provenance.py"]
    if any(path not in inherited["source_inputs"] for path in required):
        raise ValueError("Stage B source inventory is incomplete")
    return {**inherited, "schema": "driv3r-stage-b-source-custody-v1", "stage": "B",
            "accepted_stage_a_sha": ACCEPTED_STAGE_A, "frozen_inputs": frozen_inputs(root)}


def _publication_eligible(directory: Path, source_sha: str) -> bool:
    """Behavioral HOLD is publishable; incomplete/unsafe execution is not."""
    try:
        exit_record = json.loads((directory / "qualification-exit.json").read_text(encoding="utf-8"))
        summary = json.loads((directory / "execution/summary.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False
    return (exit_record.get("schema") == "driv3r-stage-b-qualification-exit-v1"
            and exit_record.get("source_sha") == source_sha
            and type(exit_record.get("exit_code")) is int and exit_record["exit_code"] == 0
            and type(exit_record.get("log_capture_exit_code")) is int and exit_record["log_capture_exit_code"] == 0
            and summary.get("schema") == "driv3r-stage-b-summary-v1"
            and summary.get("source_sha") == source_sha
            and summary.get("infrastructure_passed") is True and summary.get("campaign_complete") is True
            and not summary.get("development", False) and not summary.get("development_only", False))


def package(directory: Path, output: Path, source_sha: str) -> dict:
    """Reuse original-byte inventory/verification with separate Stage B names."""
    if not _sha(source_sha, 40):
        raise ValueError("Full immutable source SHA required")
    if output.exists() or output.resolve().is_relative_to(directory.resolve()):
        raise ValueError("Publication refuses overwriting or nesting evidence output")
    custody = json.loads((directory / "source-custody.json").read_text(encoding="utf-8"))
    if (custody.get("schema") != "driv3r-stage-b-source-custody-v1" or custody.get("stage") != "B"
            or custody.get("accepted_stage_a_sha") != ACCEPTED_STAGE_A or custody.get("source_sha") != source_sha
            or not _sha(custody.get("source_tree"), 40) or type(custody.get("source_inputs")) is not dict
            or custody.get("source_inputs_sha256") != hashlib.sha256(foundation.canonical(custody["source_inputs"])).hexdigest()):
        raise ValueError("Evidence source custody differs from Stage B publication identity")
    frozen = custody.get("frozen_inputs", {})
    if (frozen.get("accepted_stage_a_sha") != ACCEPTED_STAGE_A or not _sha(frozen.get("protocol_sha256"))
            or type(frozen.get("catalog_sha256")) is not dict or set(frozen["catalog_sha256"]) != set(CATALOGS)
            or not all(_sha(v) for v in frozen["catalog_sha256"].values())):
        raise ValueError("Stage B frozen input custody is incomplete")
    frozen_hashes = {PROTOCOL_PATH: frozen["protocol_sha256"], **frozen["catalog_sha256"]}
    if any(custody["source_inputs"].get(path) != value for path, value in frozen_hashes.items()):
        raise ValueError("Frozen protocol/catalog hashes differ from source inventory")
    receipt = json.loads((directory / "request.json").read_text(encoding="utf-8"))
    admitted = validate_request(receipt.get("request"))
    if (receipt.get("schema") != "driv3r-stage-b-request-receipt-v1" or receipt.get("source_sha") != source_sha
            or receipt.get("source_tree") != custody["source_tree"]
            or receipt.get("request_sha256") != custody["source_inputs"].get(REQUEST_PATH)
            or any(admitted[key] != frozen[key] for key in ("protocol_sha256", "catalog_sha256"))):
        raise ValueError("Request receipt differs from Stage B source/frozen inputs")
    evidence = foundation.inventory(directory)
    if any(row["path"] == "EVIDENCE-INVENTORY.json" for row in evidence["files"]):
        raise ValueError("Reserved evidence inventory path already exists")
    output.mkdir(parents=True)
    archive = output / ("driv3r-stage-b-" + source_sha[:12] + ".zip")
    with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as target:
        for row in evidence["files"]:
            path = directory / row["path"]
            if foundation.digest(path) != row["sha256"]:
                raise ValueError("Evidence changed while packaging: " + row["path"])
            target.write(path, row["path"])
        target.writestr("EVIDENCE-INVENTORY.json", json.dumps(evidence, indent=2, sort_keys=True)+"\n")
    with zipfile.ZipFile(archive) as packaged:
        if packaged.testzip() is not None:
            raise ValueError("Evidence ZIP failed CRC verification")
        for row in evidence["files"]:
            content = packaged.read(row["path"])
            if len(content) != row["bytes"] or hashlib.sha256(content).hexdigest() != row["sha256"]:
                raise ValueError("Packaged original bytes differ: " + row["path"])
    assets = [{"file": archive.name, "bytes": archive.stat().st_size, "sha256": foundation.digest(archive)}]
    manifest = {"schema": "driv3r-stage-b-publication-v1", "stage": "B", "source_sha": source_sha,
                "source_tree": custody["source_tree"], "foundation_sha": foundation.FOUNDATION,
                "accepted_base": foundation.ACCEPTED_BASE, "accepted_stage_a_sha": ACCEPTED_STAGE_A,
                "protocol_sha256": frozen["protocol_sha256"], "catalog_sha256": frozen["catalog_sha256"],
                "workflow_run": os.environ.get("GITHUB_RUN_ID"), "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
                "draft_hold": True, "publication_is_acceptance": False,
                "publication_eligible": _publication_eligible(directory, source_sha),
                "purpose": "Original bounded Stage B research, including failed behavioral outcomes; consult execution summary",
                "evidence_files_sha256": evidence["files_sha256"], "assets": assets}
    foundation.write_json(output / "MANIFEST.json", manifest)
    with (output / "SHA256SUMS.txt").open("x", encoding="utf-8") as sums:
        sums.write("".join(row["sha256"]+"  "+row["file"]+"\n" for row in assets))
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    command = sub.add_parser("request")
    command.add_argument("--path", type=Path, default=ROOT / REQUEST_PATH)
    command.add_argument("--source-sha", required=True)
    command.add_argument("--output", type=Path, required=True)
    command = sub.add_parser("source")
    command.add_argument("--source-sha", required=True)
    command.add_argument("--output", type=Path, required=True)
    command = sub.add_parser("package")
    command.add_argument("--directory", type=Path, required=True)
    command.add_argument("--output", type=Path, required=True)
    command.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    if args.command == "package":
        result = package(args.directory, args.output, args.source_sha)
    else:
        result = request(args.path, args.source_sha) if args.command == "request" else source_identity(args.source_sha)
        foundation.write_json(args.output, result)
    print(json.dumps({key: result.get(key) for key in ("schema", "source_sha", "source_tree", "publication_eligible")}, sort_keys=True))


if __name__ == "__main__":
    main()
