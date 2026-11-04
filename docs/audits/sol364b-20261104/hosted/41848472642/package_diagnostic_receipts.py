from pathlib import Path
import argparse
import hashlib
import json


def sha(b):
    return hashlib.sha256(b).hexdigest()


def canonical(value):
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def save(path, value):
    path.write_bytes(canonical(value))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    args = parser.parse_args()
    base = args.repo / "docs/audits/sol364b-20261104"
    out = base / "hosted/41848472642" / args.platform
    out.mkdir(parents=True, exist_ok=False)
    original = args.artifact
    qualification_bytes = (original / "qualification.json").read_bytes()
    qualification = json.loads(qualification_bytes)
    assert qualification["source"]["sha"] == "9597abd76c01e4a940ff3ea26ff01fca43bf55a6"
    assert qualification["source"]["tree"] == "11e986214f056f3f39631bb0331b3cd4930c3d1c"
    assert qualification["status"] == "passed"
    save(out / "qualification-original.json", {
        "schema": "sol364b-original-utf8-receipt-v1",
        "reconstruction": "Encode raw_utf8 as UTF-8 without newline conversion; compare size and SHA-256.",
        "bytes": len(qualification_bytes), "sha256": sha(qualification_bytes),
        "raw_utf8": qualification_bytes.decode("utf-8"),
    })
    assert json.loads((out / "qualification-original.json").read_bytes())["raw_utf8"].encode() == qualification_bytes
    manifest = {"schema": "sol364b-hosted-diagnostic-custody-v1", "source": qualification["source"],
                "platform": args.platform, "scope": "Fresh hosted diagnostic only; historical Rapier states stay historical.",
                "qualification_original": {"bytes": len(qualification_bytes), "sha256": sha(qualification_bytes)},
                "input_records": {}, "certificate_records": {}}
    replay = original / "replay"
    summary_bytes = (replay / "summary.json").read_bytes()
    summary = json.loads(summary_bytes)
    assert canonical(summary) == summary_bytes
    assert summary["analysis_git_head"] == qualification["source"]["sha"]
    assert summary["retained_states_evaluated"] == 1452 and summary["geometry_only_unique_routes"] == 0
    (out / "summary.json").write_bytes(summary_bytes)
    manifest["summary_original"] = {"bytes": len(summary_bytes), "sha256": sha(summary_bytes)}

    old_inputs = json.loads((base / "local-9f3b/inputs.json").read_bytes())
    inputs = {}
    fields = {}
    old_matches = True
    for p in sorted((replay / "inputs").glob("*.txt")):
        raw = p.read_bytes()
        assert sha(raw) == p.stem
        lines = raw.decode("utf-8").splitlines(keepends=True)
        field = lines[-1]
        field_sha = sha(field.encode())
        fields[field_sha] = field
        inputs[p.stem] = {"prefix": "".join(lines[:-1]), "field_line_sha256": field_sha}
        assert (inputs[p.stem]["prefix"] + fields[field_sha]).encode() == raw
        old = old_inputs["inputs"].get(p.stem)
        old_matches &= old is not None and (old["prefix"] + old_inputs["shared_field_lines"][old["field_line_sha256"]]).encode() == raw
        manifest["input_records"][p.stem] = {"bytes": len(raw), "sha256": sha(raw)}
    assert len(inputs) == 349
    manifest["inputs_equal_to_original_packet"] = old_matches
    if old_matches:
        manifest["inputs_reference"] = "docs/audits/sol364b-20261104/local-9f3b/inputs.json"
    else:
        save(out / "inputs.json", {"schema": "cybersand.sol364b.lossless-probe-inputs.v1",
              "reconstruction": "Concatenate prefix and referenced shared_field_lines entry; UTF-8 SHA-256 must equal key.",
              "inputs": inputs, "shared_field_lines": fields})

    states_bytes = (replay / "states.json").read_bytes()
    states = json.loads(states_bytes)
    assert len(states) == 1452 and canonical(states) == states_bytes
    old_states = json.loads((base / "local-9f3b/states.json").read_bytes())
    identical_states = canonical(old_states) == states_bytes
    manifest["states_original"] = {"bytes": len(states_bytes), "sha256": sha(states_bytes),
                                  "exact_original_packet_reconstruction": identical_states}
    if identical_states:
        manifest["states_reference"] = "docs/audits/sol364b-20261104/local-9f3b/states.json"
        manifest["states_reconstruction"] = "json.dumps(value,indent=2,sort_keys=True,allow_nan=False) plus one LF, UTF-8."
    else:
        (out / "states.json").write_text(json.dumps(states, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n")

    certificates = {}
    for p in sorted((replay / "certificates").glob("*.json")):
        raw = p.read_bytes()
        value = json.loads(raw)
        assert canonical(value) == raw
        certificates[p.stem] = value
        manifest["certificate_records"][p.stem] = {"bytes": len(raw), "sha256": sha(raw)}
    assert set(certificates) == set(inputs)
    data = {"schema": "cybersand.sol364b.lossless-probe-certificates.v1",
            "reconstruction": "Each original certificate is json.dumps(value,indent=2,sort_keys=True,allow_nan=False) plus one LF, UTF-8.",
            "certificates": certificates}
    (out / "certificates.json").write_text(json.dumps(data, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n")
    manifest["files"] = {p.name: {"bytes": p.stat().st_size, "sha256": sha(p.read_bytes())} for p in sorted(out.iterdir()) if p.is_file()}
    save(out / "manifest.json", manifest)
    print(json.dumps({"platform": args.platform, "destination": str(out), "source": manifest["source"],
                      "input_count": len(inputs), "inputs_reused": old_matches, "states_reused": identical_states,
                      "certificates": len(certificates), "bytes": sum(p.stat().st_size for p in out.iterdir())}))


if __name__ == "__main__":
    main()
