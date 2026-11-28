"""Complete synthetic receipt contracts and rehashed semantic substitutions.

These fixtures test readers, never substitute for actual native execution.
Original Q5 files remain immutable and lack the new independent captures.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest

import reduce_evidence as subject
import runtime_custody as custody


def reference_digest(operation, extent, cells, guards):
    # Separate declarative encoding, with explicit widths matching the C++
    # contract, so fixture receipts do not call the validator under test.
    tag = b"cybersand-workbench-authoring-patch-v1"
    payload = len(tag).to_bytes(4, "little") + tag
    payload += bytes([1 if operation == "build" else 2])
    payload += b"".join(value.to_bytes(4, "little") for value in extent)
    payload += len(cells).to_bytes(8, "little")
    for x, y, before, after in cells:
        payload += x.to_bytes(4, "little", signed=True) + y.to_bytes(4, "little", signed=True) + bytes([before, after])
    payload += len(guards).to_bytes(8, "little")
    for x, y in guards:
        payload += x.to_bytes(4, "little", signed=True) + y.to_bytes(4, "little", signed=True)
    return hashlib.sha256(payload).hexdigest()


class NativeReceiptIdentity(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.runtime = {"source_commit": "a" * 40, "platform": "linux", "cli": "gentek_reciprocal",
                        "files": {"gentek_reciprocal": {"sha256": "b" * 64}}}
        self.extent = [512, 512]
        self.recipe = {"size": [2, 2], "origin": [64, 48], "layout": "centered_frame_rectangle", "border": 4}
        self.cells = [(64, 48, 0, 5), (65, 48, 0, 13)]
        self.guards = [(65, 49)]
        self.native = {"cells": [5, 13, 0, 0],
                       "ledger": [[1, 1, 0, 0, 0, 0], [2, 1, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0]],
                       "input": {"frame": {"width": 2, "height": 2, "origin": [64, 48], "protected": [0, 0, 0, 1]}}}
        for stage in ("initial", "regenerated"):
            custody.write_json(self.root / (stage + "-result.json"), self.native)
        proposal = custody.sha(self.root / "regenerated-result.json")
        baseline = bytes(512 * 512 * 2)
        installed = bytearray(baseline)
        for x, y, _before, after in self.cells:
            struct.pack_into("<H", installed, 2 * (512 * y + x), after)
        self.baseline, self.installed = baseline, bytes(installed)
        for stage in ("baseline", "undone"):
            (self.root / (stage + "-native.le16")).write_bytes(baseline)
        for stage in ("applied", "regenerated"):
            (self.root / (stage + "-native.le16")).write_bytes(installed)
        self.transactions = {}
        for generation, (label, operation, before, after) in enumerate((
                ("first_apply", "build", baseline, installed), ("undo", "remove", installed, baseline),
                ("reapply", "build", baseline, installed)), 3):
            changed = self.cells if operation == "build" else [(x, y, new, old) for x, y, old, new in self.cells]
            receipt = {"schema": 1, "operation": operation, "proposal_sha256": proposal,
                       "patch_sha256": reference_digest(operation, self.extent, changed, self.guards),
                       "changed_cells": len(changed), "protected_cells": len(self.guards),
                       "source_native_generation": generation, "source_revision": generation + 2, "source_tick": 0,
                       "semantics": "retained-native-transaction-v1"}
            self.transactions[label] = {"operation": operation,
                "source_capture": {"native_generation": generation, "revision": generation + 2, "tick": 0, "extent": self.extent},
                "installed_capture": {"native_generation": generation + 1, "revision": generation + 3, "tick": 0, "extent": self.extent},
                "receipt": receipt, "source_material_sha256": hashlib.sha256(before).hexdigest(),
                "installed_material_sha256": hashlib.sha256(after).hexdigest()}
        final = copy.deepcopy(self.transactions["reapply"]["receipt"])
        self.reports = {"create": {"native_recipe": self.recipe, "native_transactions": self.transactions,
                                   "native_receipt": copy.deepcopy(final)},
                        "reopen": {"native_transactions": {}, "native_receipt": copy.deepcopy(final)}}
        self.map_path = self.root / "profile/data/godot/app_userdata/Cyber Sand Reference Sandbox/workbench/setup-swarm004-interactive-evaluation.json"
        self.map_path.parent.mkdir(parents=True)
        self.map_path.write_bytes(b'{"synthetic_authored_fixture":true}\n')
        self.saved_evidence = Path(str(self.map_path) + ".swarm004-evidence.json")
        self.saved_evidence.write_bytes((self.root / "regenerated-result.json").read_bytes())
        (self.root / "regenerated-request.txt").write_bytes(b"synthetic request\n")
        self.sidecar_path = Path(str(self.map_path) + ".swarm004.json")
        self.sidecar = {"schema": 1, "status": "accepted_native_material_architecture", "native_receipt": final,
            "authoring_territory": {"layout": self.recipe["layout"], "border": self.recipe["border"]},
            "cell_count": 2, "map_sha256": custody.sha(self.map_path), "evidence_sha256": proposal,
            "proposal_sha256": proposal, "request_sha256": custody.sha(self.root / "regenerated-request.txt"),
            "native_source": self.runtime["source_commit"], "cli_sha256": self.runtime["files"][self.runtime["cli"]]["sha256"]}
        custody.write_json(self.sidecar_path, self.sidecar)
        self.record_saved_artifacts()

    def record_saved_artifacts(self):
        for report in self.reports.values():
            report["saved_artifacts"] = {"map_sha256": custody.sha(self.map_path),
                "sidecar_sha256": custody.sha(self.sidecar_path), "evidence_sha256": custody.sha(self.saved_evidence)}

    def validate(self):
        subject.validate_native_transactions(self.root, "transaction", self.reports, self.runtime)

    def change_final(self, field, value):
        # Rehashing report/log envelopes cannot conceal semantic contradictions;
        # mutate every duplicated receipt to exercise the independent joins.
        self.transactions["reapply"]["receipt"][field] = value
        for report in self.reports.values():
            report["native_receipt"][field] = value
        self.sidecar["native_receipt"][field] = value
        custody.write_json(self.sidecar_path, self.sidecar)

    def test_complete_build_undo_reapply_and_saved_receipt_pass(self):
        self.validate()

    def test_canonical_native_encoding_includes_full_extent_direction_and_guards(self):
        expected = reference_digest("build", self.extent, self.cells, self.guards)
        self.assertEqual(subject.native_patch_identity(self.baseline, self.installed, self.extent, self.native, self.recipe, "build")["patch_sha256"], expected)
        self.assertNotEqual(expected, reference_digest("remove", self.extent, [(x, y, new, old) for x, y, old, new in self.cells], self.guards))
        self.assertNotEqual(expected, reference_digest("build", [2048, 2048], self.cells, self.guards))
        self.assertNotEqual(expected, reference_digest("build", self.extent, self.cells, []))

    def test_all_three_transactions_and_fresh_read_only_reopen_are_required(self):
        for label in ("first_apply", "undo", "reapply"):
            witness = self.transactions.pop(label)
            with self.assertRaisesRegex(ValueError, "three original transaction witnesses"):
                self.validate()
            self.transactions[label] = witness
        self.reports["reopen"]["native_transactions"] = self.transactions
        with self.assertRaisesRegex(ValueError, "read-only Reopen"):
            self.validate()

    def test_rehashed_nonzero_wrong_count_is_refused(self):
        self.change_final("changed_cells", 1)
        self.sidecar["cell_count"] = 1
        custody.write_json(self.sidecar_path, self.sidecar)
        with self.assertRaisesRegex(ValueError, "count, protection or patch digest"):
            self.validate()

    def test_rehashed_false_patch_digest_and_protection_are_refused(self):
        for field, bad in (("patch_sha256", "0" * 64), ("protected_cells", 0)):
            original = self.transactions["reapply"]["receipt"][field]
            self.change_final(field, bad)
            with self.assertRaisesRegex(ValueError, "count, protection or patch digest"):
                self.validate()
            self.change_final(field, original)

    def test_invalid_schema_semantics_operation_and_integer_types_are_refused(self):
        for field, bad in (("schema", 999), ("schema", True), ("semantics", "fabricated"),
                           ("operation", "remove"), ("changed_cells", 2.0), ("protected_cells", True)):
            original = self.transactions["reapply"]["receipt"][field]
            self.change_final(field, bad)
            with self.assertRaisesRegex(ValueError, "schema, semantics or captured source"):
                self.validate()
            self.change_final(field, original)

    def test_source_fence_must_match_independent_capture(self):
        for field in ("source_native_generation", "source_revision", "source_tick"):
            original = self.transactions["reapply"]["receipt"][field]
            self.change_final(field, original + 1)
            with self.assertRaisesRegex(ValueError, "captured source identity"):
                self.validate()
            self.change_final(field, original)
        self.transactions["reapply"]["source_capture"]["native_generation"] = -10
        self.change_final("source_native_generation", -10)
        with self.assertRaisesRegex(ValueError, "independent source/installed capture"):
            self.validate()

    def test_collapsed_or_disconnected_generation_sequence_is_refused(self):
        originals = copy.deepcopy(self.transactions)
        for witness in self.transactions.values():
            for kind in ("source_capture", "installed_capture"):
                witness[kind].update(native_generation=0, revision=0, tick=0)
            witness["receipt"].update(source_native_generation=0, source_revision=0, source_tick=0)
        with self.assertRaisesRegex(ValueError, "actual installed generation sequence"):
            self.validate()
        self.transactions.clear(); self.transactions.update(originals)
        self.transactions["undo"]["source_capture"]["native_generation"] = 99
        self.transactions["undo"]["installed_capture"]["native_generation"] = 100
        self.transactions["undo"]["receipt"]["source_native_generation"] = 99
        with self.assertRaisesRegex(ValueError, "actual installed generation sequence"):
            self.validate()

    def test_rehashed_proposal_substitution_is_refused(self):
        self.change_final("proposal_sha256", "0" * 64)
        self.sidecar.update(proposal_sha256="0" * 64, evidence_sha256="0" * 64)
        custody.write_json(self.sidecar_path, self.sidecar)
        with self.assertRaisesRegex(ValueError, "proposal differs from original native output"):
            self.validate()

    def test_source_or_installed_capture_must_name_actual_complete_planes(self):
        for key in ("source_material_sha256", "installed_material_sha256"):
            old = self.transactions["reapply"][key]
            self.transactions["reapply"][key] = "0" * 64
            with self.assertRaisesRegex(ValueError, "capture differs from original readback"):
                self.validate()
            self.transactions["reapply"][key] = old

    def test_foreign_world_change_is_refused_even_with_updated_capture_hash(self):
        path = self.root / "regenerated-native.le16"
        changed = bytearray(path.read_bytes())
        struct.pack_into("<H", changed, 0, 13)
        path.write_bytes(changed)
        self.transactions["reapply"]["installed_material_sha256"] = custody.sha(path)
        with self.assertRaisesRegex(ValueError, "actual source/installed material changes"):
            self.validate()

    def test_protected_native_patch_is_refused(self):
        for stage in ("initial", "regenerated"):
            native = copy.deepcopy(self.native)
            native["input"]["frame"]["protected"][0] = 1
            custody.write_json(self.root / (stage + "-result.json"), native)
        for witness in self.transactions.values():
            witness["receipt"]["proposal_sha256"] = custody.sha(self.root / "regenerated-result.json")
        with self.assertRaisesRegex(ValueError, "intersects original protection"):
            self.validate()

    def test_terminal_receipt_must_equal_actual_reapply(self):
        self.reports["create"]["native_receipt"]["source_tick"] = 99
        self.reports["reopen"]["native_receipt"]["source_tick"] = 99
        with self.assertRaisesRegex(ValueError, "actual reapply acknowledgement"):
            self.validate()

    def test_saved_receipt_source_runtime_map_request_and_native_bytes_are_bound(self):
        for field, bad in (("native_receipt", {}), ("native_source", "0" * 40), ("cli_sha256", "0" * 64),
                           ("map_sha256", "0" * 64), ("request_sha256", "0" * 64), ("cell_count", 1), ("cell_count", 2.0),
                           ("authoring_territory", {"layout": "fabricated", "border": 999})):
            changed = copy.deepcopy(self.sidecar)
            changed[field] = bad
            custody.write_json(self.sidecar_path, changed)
            self.record_saved_artifacts()
            with self.assertRaisesRegex(ValueError, "saved native receipt differs"):
                self.validate()
        custody.write_json(self.sidecar_path, self.sidecar)
        self.saved_evidence.write_bytes(b'{"substituted":true}\n')
        self.record_saved_artifacts()
        with self.assertRaisesRegex(ValueError, "saved native receipt differs"):
            self.validate()

    def test_substituted_saved_map_and_rehashed_sidecar_are_refused(self):
        self.map_path.write_bytes(b"not an authored map and not JSON\n")
        self.sidecar["map_sha256"] = custody.sha(self.map_path)
        custody.write_json(self.sidecar_path, self.sidecar)
        with self.assertRaisesRegex(ValueError, "Create/fresh-Reopen process witnesses"):
            self.validate()

    def test_create_and_reopen_must_witness_the_same_saved_files(self):
        self.reports["reopen"]["saved_artifacts"]["map_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "Create/fresh-Reopen process witnesses"):
            self.validate()

    def test_missing_saved_receipt_is_refused(self):
        self.sidecar_path.unlink()
        with self.assertRaisesRegex(ValueError, "saved native evidence is absent"):
            self.validate()


if __name__ == "__main__":
    unittest.main()
