"""Independently join four original Windows core/editor process chains.

Usage: python review_windows_core.py EXTRACTED_EVIDENCE_ROOT OUTPUT_JSON
This only reads original qualification, process, log and report files.
"""
from pathlib import Path
import hashlib
import json
import sys

SOURCE = "50c6df89528dc9ecdc5316d8c67abf203e192254"
TREE = "d9740be7cafb8ac7b7d6eee4a16219989745fd95"
EXPECTED = {
    "scripts/ambient/ambient_engine.gd": "a406e33433327229c077dc8cfdb065196c4eecea70a51752c2cc9120adc60ab7",
    "tests/test_ambient_living_engine.gd": "a48857d610fe2a630e3a5e3ee6fc1f4319847c5809325cdad5c595a72768fee2",
}
WINDOWS_ENGINE = "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    root, output = map(Path, sys.argv[1:])
    qualifications, cases = [], []
    for folder in ("ambient", "extracted-package"):
        qp = root / folder / "qualification.json"
        q = json.loads(qp.read_bytes())
        qualifications.append(q)
        assert q["source_commit"] == SOURCE and q["source_tree"] == TREE
        assert q["status"] == "passed" and q["input_custody"] == "passed" and not q["local_delta"]
        assert q["platform"] == "win32"
        assert all(q["project_inputs_sha256"][k] == v for k, v in EXPECTED.items())
        for case, count, marker in (("living_engine", 648, "AMBIENT_LIVING_ENGINE_RESULT "),
                                    ("living_editor", 96, "AMBIENT_LIVING_EDITOR ")):
            matches = [c for c in q["cases"] if c["name"] == case]
            assert len(matches) == 1
            c = matches[0]
            directory = root / folder / case
            pp, lp, rp = [directory / name for name in ("process.json", "process.log", "report.json")]
            process, report = json.loads(pp.read_bytes()), json.loads(rp.read_bytes())
            log = lp.read_text()
            terminals = [json.loads(line[len(marker):]) for line in log.splitlines() if line.startswith(marker)]
            assert len(terminals) == 1 and terminals[0] == report
            assert c["process_sha256"] == sha(pp)
            assert c["log_sha256"] == process["log_sha256"] == sha(lp)
            assert c["report_sha256"] == sha(rp)
            assert process["exit_code"] == c["exit_code"] == 0
            assert process["status"] == c["status"] == "passed"
            assert report["checks"] == c["completion"]["checks"] == count
            assert not report["failures"] and c["completion"]["failures"] == 0
            assert c["command"] == process["command"] and process["pid"] == c["pid"]
            assert not any(marker in log for marker in ("ERROR:", "WARNING:", "SCRIPT ERROR"))
            assert process["command"][0] == q["godot"]["binary"]
            project_path = process["command"][process["command"].index("--path") + 1]
            assert ("ambient owner package" in project_path if folder == "extracted-package"
                    else "\\cybersand\\cybersand\\godot" in project_path)
            checked = {"scope": folder, "case": case, "checks": count,
                       "qualification_sha256": sha(qp), "process_sha256": sha(pp),
                       "log_sha256": sha(lp), "report_sha256": sha(rp),
                       "pid": process["pid"], "command": process["command"],
                       "terminal_matches_original_report": True, "exit_code": 0}
            if case == "living_editor":
                live = report["live_audition"]
                assert [live[k] for k in ("paused_generation", "playing_generation", "unapplied_generation", "applied_generation")] == [4, 5, 5, 6]
                assert live["resume_configuration_unchanged"] and live["unapplied_configuration_unchanged"]
                assert report["platform"] == "Windows" and report["display"] == "headless"
                checked.update(actual_mounted_editor=live, display=report["display"])
            else:
                assert report["failure_labels"] == [] and report["engine"] == "ambient-engine/v2"
                checked["scope_note"] = report["scope"]
            cases.append(checked)
    source, extracted = qualifications
    for key in ("project_inputs_sha256", "source_inputs_sha256", "runtime"):
        assert source[key] == extracted[key]
    assert source["godot"]["sha256"] == extracted["godot"]["sha256"] == WINDOWS_ENGINE
    assert len({case["pid"] for case in cases}) == 4
    result = {
        "status": "PASS", "application": SOURCE, "tree": TREE,
        "artifact": {"id": 14995491989, "bytes": 28268700,
                     "sha256": "5d12ce325cc0c3024a7c60e4e303e8fed8ef55a437596def809624c561c1101d",
                     "metadata_scope": "Independently checked through the GitHub Actions artifact API; shared download/CRC/full inventory owned by the authoring lane."},
        "scope": "Independent read-only spot check of original Windows source and extracted living-engine and mounted-editor executions. Full archive, payload, graphical and launcher audit belongs to the authoring lane. No engine was launched by this reader.",
        "reader_sha256": sha(Path(__file__)), "cases": cases,
        "complete_source_and_project_inventories_equal_between_source_and_extracted": True,
        "source_input_count": len(source["source_inputs_sha256"]),
        "loaded_project_input_count": len(source["project_inputs_sha256"]),
        "declared_engine_and_living_fixture_hashes": EXPECTED,
        "windows_console_engine_sha256": WINDOWS_ENGINE,
        "limits": ["Pure living-core checks add zero physical actor episodes.",
                   "The mounted editor fixtures are headless actual scene/UI/native-owner execution, not manual interaction or physical display acceptance.",
                   "Matching inputs and process/report/terminal identities do not replace the complete portable payload and actual graphical audit."],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "source": SOURCE,
                      "cases": [(c["scope"], c["case"], c["checks"]) for c in cases], "output": str(output)}))


if __name__ == "__main__":
    main()
