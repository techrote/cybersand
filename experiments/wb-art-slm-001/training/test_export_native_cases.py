"""Model-free native replay export regression tests; no trainer or native runtime."""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import tempfile
import types
import unittest

# The actual exporter imports inference/training utility names; use pure-stdlib
# stubs to test its unchanged raw-output and native-case contract without torch.
def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


def strict_json(raw):
    def unique(pairs):
        obj = {}
        for k, v in pairs:
            if k in obj:
                raise ValueError("duplicate JSON field")
            obj[k] = v
        return obj
    return json.loads(raw, object_pairs_hook=unique,
                      parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x)))


class FakeCompiler:
    def validate_program(self, program):
        if not isinstance(program, dict) or program.get("theme") not in ("roots", "ribs"):
            raise ValueError("invalid theme")

    def compile_with_report(self, program, width, height, seed):
        self.validate_program(program)
        if seed == 999:
            raise ValueError("synthetic second-seed failure")
        return {"width": width, "height": height, "seed": seed,
                "operations": [{"type": "point", "x": seed % width, "material": 58}]}


class ExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = Path(__file__).with_name("export_native_cases.py")
        fake_infer = types.ModuleType("infer")
        fake_infer.load_compiler = lambda _: FakeCompiler()
        fake_train = types.ModuleType("train_lora")
        fake_train.canonical = canonical
        fake_train.strict_json = strict_json
        fake_train.sha256_file = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
        fake_train.write_json = lambda p, v: Path(p).write_text(json.dumps(v))
        old = {name: sys.modules.get(name) for name in ("infer", "train_lora")}
        try:
            sys.modules.update(infer=fake_infer, train_lora=fake_train)
            spec = importlib.util.spec_from_file_location("wb_slm_native_export_under_test", source)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            cls.exporter = module
        finally:
            for name, original in old.items():
                if original is None:
                    del sys.modules[name]
                else:
                    sys.modules[name] = original

    def raw(self, identifier="request-1", theme="roots", *, eos=True, valid=True):
        return {"id": identifier, "theme": theme, "group_id": "dev-group", "prompt": theme,
                "completion": canonical({"theme": theme}), "eos_emitted": eos,
                "first_pass_accepted": valid, "json_valid": valid, "program_valid": valid}

    def bundle(self, rows, seeds=(17, 73), prefix="lfm-stage-400"):
        return self.exporter.export_predictions({"records": rows, "summary": {"count": len(rows)}},
                                                {"suite": "dev"}, FakeCompiler(), list(seeds), prefix)

    def test_short_ids_remain_readable_and_aliases_are_complete(self):
        bundle = self.bundle([self.raw()])
        ids = [case["id"] for case in bundle["cases"]]
        self.assertEqual(ids, ["lfm-stage-400-request-1-s17", "lfm-stage-400-request-1-s73"])
        self.assertEqual(set(ids), set(bundle["case_id_aliases"]))
        self.assertEqual(bundle["counts"]["raw_requests"], 1)
        self.assertEqual(bundle["counts"]["replay_cases"], 2)
        self.assertTrue(all(not a["aliased"] for a in bundle["case_id_aliases"].values()))

    def test_long_unicode_ids_have_stable_safe_bounded_aliases(self):
        original = "prediction/" + "rîbs" * 80
        rows = [self.raw(original, theme="ribs")]
        a = self.bundle(rows, prefix="model-candidate-with-long-name")
        b = self.bundle(rows, prefix="model-candidate-with-long-name")
        self.assertEqual(a, b)
        for c in a["cases"]:
            self.assertRegex(c["id"], r"^[A-Za-z0-9_-]{1,38}$")
            self.assertEqual(c["prediction_id"], original)
            self.assertEqual(a["case_id_aliases"][c["id"]]["prediction_id"], original)
            self.assertTrue(a["case_id_aliases"][c["id"]]["aliased"])
            self.assertLessEqual(len("slm-pilot-" + c["id"]), 48)

    def test_unterminated_and_invalid_rows_remain_in_denominator(self):
        rows = [self.raw("valid"), self.raw("truncated", eos=False), self.raw("invalid", valid=False)]
        bundle = self.bundle(rows)
        self.assertEqual(bundle["counts"], {"raw_requests": 3, "raw_first_pass_accepted": 2,
                                             "replay_eligible_requests": 1, "excluded_requests": 2,
                                             "replay_cases": 2, "seeds_per_request": 2})
        self.assertEqual({x["id"] for x in bundle["excluded_predictions"]}, {"truncated", "invalid"})

    def test_bad_second_seed_excludes_entire_request(self):
        bundle = self.bundle([self.raw("good")], seeds=(17, 999))
        self.assertEqual(bundle["cases"], [])
        self.assertEqual(bundle["case_id_aliases"], {})
        self.assertEqual(bundle["counts"]["excluded_requests"], 1)

    def test_duplicate_prediction_ids_fail_instead_of_deduplicating(self):
        with self.assertRaisesRegex(ValueError, "Duplicate original"):
            self.bundle([self.raw("same"), self.raw("same")])

    def test_duplicate_or_invalid_seeds_and_prefix_fail(self):
        for seeds in ((), (17, 17), (-1,), (2**63,)):
            with self.subTest(seeds=seeds), self.assertRaises(ValueError):
                self.bundle([self.raw()], seeds=seeds)
        with self.assertRaisesRegex(ValueError, "Replay prefix"):
            self.bundle([self.raw()], prefix="has spaces")

    def test_raw_program_and_completion_are_unmodified(self):
        row = self.raw("veins-long-original", theme="roots")
        row["completion"] = '{ "theme" : "roots" }'
        bundle = self.bundle([row])
        self.assertEqual(bundle["cases"][0]["raw_completion"], row["completion"])
        self.assertEqual(bundle["cases"][0]["prediction_id"], row["id"])

    def test_rejected_malformed_json_and_bad_theme(self):
        row1, row2 = self.raw("broken"), self.raw("bad")
        row1["completion"] = '{"theme":12.3.4}'
        row2["completion"] = '{"theme":"unknown"}'
        bundle = self.bundle([row1, row2])
        self.assertEqual(bundle["counts"]["replay_cases"], 0)
        self.assertEqual(len(bundle["excluded_predictions"]), 2)

    def test_count_or_empty_records_fail_closed(self):
        e = self.exporter.export_predictions
        with self.assertRaisesRegex(ValueError, "denominator"):
            e({"records": [self.raw()], "summary": {"count": 999}}, {}, FakeCompiler(), [17], "test")
        with self.assertRaisesRegex(ValueError, "No raw"):
            e({"records": [], "summary": {"count": 0}}, {}, FakeCompiler(), [17], "test")


if __name__ == "__main__":
    unittest.main()
