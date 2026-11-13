"""Synthetic contract tests only; no mock packet is native execution evidence."""
import json
from pathlib import Path
import struct
import tempfile
import unittest

import audit_v11_native_pairs as audit

SOURCE = "9" * 40
NATIVE = "a" * 64


def save(path, obj):
    path.write_text(json.dumps(obj, indent=2) + "\n")


def fixture(root):
    cases, aliases, engine, receipts, events = [], {}, [], [], []
    for variant in range(8):
        for seed in (17, 73):
            pair = {}
            for tag, version in (("c10", "wb-art-slm-001/1.0.0"),
                                 ("c11", "wb-art-slm-001/1.1.0-coral-spread")):
                cid = f"{tag}-coral-v{variant}-s{seed}"
                operations = [{"shape": "line", "material": 58, "width": 1,
                               "x0": 1, "y0": 1, "x1": 2, "y1": 2 if tag == "c10" else 3}]
                ophash = audit.digest(json.dumps(operations, sort_keys=True,
                                                separators=(",", ":")).encode())
                cases.append({"id": cid, "theme": "coral", "width": 96, "height": 96,
                              "seed": seed, "program_sha256": "f" * 64,
                              "operations_sha256": ophash, "operations": operations})
                pair[tag] = {"case_id": cid, "compiler_version": version,
                             "operations_sha256": ophash}
                # Deliberate synthetic single pixels in top versus bottom third.
                cell = [0] * 9216
                cell[(10 if tag == "c11" else 80) * 96 + 5] = 58
                binary = struct.pack("<9216i", *cell)
                (root / (cid + ".materials.i32le")).write_bytes(binary)
                (root / (cid + ".png")).write_bytes(b"synthetic-test-PNG")
                full = bytearray(512 * 512 * 4)
                struct.pack_into("<i", full, ((10 if tag == "c11" else 80) * 512 + 5) * 4, 58)
                whole_sha = audit.digest(full)
                events.append({"case": cid, "receipt": {"backend": "CyberNativeCellWorld",
                    "status": "completed", "tick": 0, "before_source": {"tick": 0},
                    "readback": [[5, 10 if tag == "c11" else 80, 0, 58]],
                    "confirmed": 1, "checked": 1, "changed": 1,
                    "excluded": 0, "refused": 0}})
                for capture_sha in (whole_sha, audit.digest(bytes(512 * 512 * 4)),
                                    whole_sha, whole_sha):
                    events.append({"case": cid, "capture": {
                        "backend": "CyberNativeCellWorld", "status": "completed",
                        "region_xywh": [0, 0, 512, 512],
                        "materials_i32le_sha256": capture_sha}})
                engine.append({"id": cid, "passed": True,
                               "terminal": {"status": "completed", "checked": 1,
                                            "changed": 1, "unchanged": 0},
                               "raw_materials": cid + ".materials.i32le",
                               "whole_world_i32le_sha256": whole_sha,
                               "history_and_reopen_checked": True, "operations_sha256": ophash,
                               "program_sha256": "f" * 64, "filled_cells": 1,
                               "crop_i32le_sha256": audit.digest(binary)})
                receipts.append({"id": cid, "success": True, "operations_sha256": ophash,
                                 "history_and_reopen_checked": True, "outside_focus_violations": 0,
                                 "unexpected_material_cells": 0, "changed_cells": 1,
                                 "acknowledged_cells": 1, "filled_cells": 1,
                                 "raw_materials": cid + ".materials.i32le", "png": cid + ".png",
                                 "readback_sha256": audit.digest(binary),
                                 "image_sha256": audit.digest(b"synthetic-test-PNG")})
            aliases[f"reference-coral-v{variant}-s{seed}"] = pair
    manifest = {"purpose": "not-yet-executed-v1-v11-coral-native-pair",
                "required_native_history_mode": "each",
                "candidate_compiler_version": "wb-art-slm-001/1.1.0-coral-spread",
                "parent_compiler_sha256": "a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb",
                "cases": cases, "aliases": aliases}
    save(root / "pairs.json", manifest)
    save(root / "input-cases.json", {"cases": cases})
    save(root / "runtime-custody.json", {"source_commit": SOURCE, "native_sha256": NATIVE,
        "normalized_manifest_sha256": audit.digest((root / "input-cases.json").read_bytes())})
    save(root / "process-result.json", {"exit_code": 0, "timed_out": False,
        "input_unchanged": True, "harness_unchanged": True, "runtime_unchanged": True})
    (root / "native-receipts.jsonl").write_text(
        "".join(json.dumps(event) + "\n" for event in events))
    save(root / "native-summary.json", {"passed": True, "cases_completed": 32,
        "cases_requested": 32, "cases": engine})
    verified = {"passed": True, "failures": [], "runtime": {"source_commit": SOURCE,
        "native_sha256": NATIVE}, "global_gates": {k: True for k in audit.GATES},
        "cases": receipts}
    for filename, key in (("process-result.json", "process_result_sha256"),
                          ("runtime-custody.json", "runtime_custody_sha256"),
                          ("native-summary.json", "engine_summary_sha256"),
                          ("native-receipts.jsonl", "native_receipts_sha256")):
        verified[key] = audit.digest((root / filename).read_bytes())
    save(root / "verified-admission-receipts.json", verified)
    return manifest, verified


class PairGateTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.manifest, self.verified = fixture(self.root)

    def audit(self):
        return audit.analyze(self.root / "pairs.json", self.root,
                             source_sha=SOURCE, native_sha=NATIVE)

    def test_synthetic_contract_is_not_native_claim(self):
        result = self.audit()
        self.assertEqual(result["native_pairs"], 16)
        self.assertEqual(result["mean_v1_top_fraction"], 0)
        self.assertEqual(result["mean_v11_top_fraction"], 1)
        self.assertFalse(result["human_accepted"])
        self.assertFalse(result["windows_qualified"])
        self.assertTrue(all(c["raw_native_chain"]["history_captures"] == 4
                            for c in result["cases"].values()))

    def test_all_cases_require_real_history_receipt(self):
        self.verified["cases"][0]["history_and_reopen_checked"] = False
        save(self.root / "verified-admission-receipts.json", self.verified)
        with self.assertRaisesRegex(ValueError, "per case"):
            self.audit()

    def test_material_readback_tampering_refused(self):
        cid = self.manifest["cases"][0]["id"]
        (self.root / (cid + ".materials.i32le")).write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "stored native crop disagrees with receipt chain"):
            self.audit()

    def test_input_mutation_refused_even_with_passing_receipts(self):
        self.manifest["cases"][0]["seed"] = 91
        save(self.root / "pairs.json", self.manifest)
        with self.assertRaisesRegex(ValueError, "inputs differ"):
            self.audit()

    def test_missing_stop_gate_refused(self):
        self.verified["global_gates"]["stop_native_readback_exact"] = False
        save(self.root / "verified-admission-receipts.json", self.verified)
        with self.assertRaisesRegex(ValueError, "global gates"):
            self.audit()

    def test_unqualified_source_refused(self):
        with self.assertRaisesRegex(ValueError, "pinned"):
            audit.analyze(self.root / "pairs.json", self.root,
                          source_sha="main", native_sha=NATIVE)

    def test_path_traversal_refused(self):
        self.verified["cases"][0]["raw_materials"] = "../" + self.verified["cases"][0]["raw_materials"]
        save(self.root / "verified-admission-receipts.json", self.verified)
        with self.assertRaisesRegex(ValueError, "canonical local basename"):
            self.audit()


    def test_forged_verifier_without_native_receipts_rejected(self):
        path = self.root / "native-receipts.jsonl"
        path.write_text('{"case":"invariant-stop","receipt":{"status":"completed"}}\n')
        self.verified["native_receipts_sha256"] = audit.digest(path.read_bytes())
        save(self.root / "verified-admission-receipts.json", self.verified)
        with self.assertRaisesRegex(ValueError, "missing raw native draw receipt"):
            self.audit()

    def test_discontinuous_before_row_rejected_after_rehash(self):
        path = self.root / "native-receipts.jsonl"
        events = [json.loads(line) for line in path.read_text().splitlines()]
        next(e for e in events if "receipt" in e)["receipt"]["readback"][0][2] = 58
        path.write_text("".join(json.dumps(e) + "\n" for e in events))
        self.verified["native_receipts_sha256"] = audit.digest(path.read_bytes())
        save(self.root / "verified-admission-receipts.json", self.verified)
        with self.assertRaisesRegex(ValueError, "discontinuous native before-state"):
            self.audit()

    def test_forged_engine_world_hash_rejected_after_rehash(self):
        engine = json.loads((self.root / "native-summary.json").read_text())
        engine["cases"][0]["whole_world_i32le_sha256"] = "0" * 64
        save(self.root / "native-summary.json", engine)
        self.verified["engine_summary_sha256"] = audit.digest(
            (self.root / "native-summary.json").read_bytes())
        save(self.root / "verified-admission-receipts.json", self.verified)
        with self.assertRaisesRegex(ValueError, "complete native World hash"):
            self.audit()

    def test_forged_undo_capture_rejected_after_rehash(self):
        path = self.root / "native-receipts.jsonl"
        events = [json.loads(line) for line in path.read_text().splitlines()]
        cid = self.manifest["cases"][0]["id"]
        undo = [e for e in events if e.get("case") == cid and "capture" in e][1]
        undo["capture"]["materials_i32le_sha256"] = "0" * 64
        path.write_text("".join(json.dumps(e) + "\n" for e in events))
        self.verified["native_receipts_sha256"] = audit.digest(path.read_bytes())
        save(self.root / "verified-admission-receipts.json", self.verified)
        with self.assertRaisesRegex(ValueError, "undo native history capture differs"):
            self.audit()

    def test_missing_reopen_capture_rejected_after_rehash(self):
        path = self.root / "native-receipts.jsonl"
        events = [json.loads(line) for line in path.read_text().splitlines()]
        cid = self.manifest["cases"][0]["id"]
        i = [i for i, e in enumerate(events) if e.get("case") == cid and "capture" in e][-1]
        del events[i]
        path.write_text("".join(json.dumps(e) + "\n" for e in events))
        self.verified["native_receipts_sha256"] = audit.digest(path.read_bytes())
        save(self.root / "verified-admission-receipts.json", self.verified)
        with self.assertRaisesRegex(ValueError, "missing or extra native history captures"):
            self.audit()

    def test_forged_zero_changed_receipt_rejected_after_rehash(self):
        path = self.root / "native-receipts.jsonl"
        events = [json.loads(line) for line in path.read_text().splitlines()]
        next(e for e in events if "receipt" in e)["receipt"]["changed"] = 0
        path.write_text("".join(json.dumps(e) + "\n" for e in events))
        self.verified["native_receipts_sha256"] = audit.digest(path.read_bytes())
        save(self.root / "verified-admission-receipts.json", self.verified)
        with self.assertRaisesRegex(ValueError, "native changed count"):
            self.audit()


if __name__ == "__main__":
    unittest.main()
