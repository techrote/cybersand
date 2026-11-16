import tempfile
from pathlib import Path
import unittest

from experiments.driv3r.frankenlayers_lab.flows import LAB_FLOWS, validate_flows
from experiments.driv3r.frankenlayers_lab.patch_lab import ATTN_GUARD, TARGET, patch

class FrankenLabTests(unittest.TestCase):
    def test_six_and_four_distinct_skeletons(self):
        validate_flows()
        self.assertEqual({n: len(v) for n, v in LAB_FLOWS.items()},
                         {"skele6": 6, "aero6": 6, "skele4": 4, "aero4": 4})
        self.assertNotEqual(LAB_FLOWS["skele6"], LAB_FLOWS["aero6"])
        self.assertNotEqual(LAB_FLOWS["skele4"], LAB_FLOWS["aero4"])
        self.assertTrue(all(v[0] == 0 and v[-1] == 23 for v in LAB_FLOWS.values()))

    def test_invalid_flows_rejected(self):
        for name in LAB_FLOWS:
            mutated = dict(LAB_FLOWS)
            mutated[name] = (0, 4, 4, 23) if name.endswith("4") else (0, 4, 5, 6, 23, 24)
            with self.subTest(name=name), self.assertRaises(ValueError):
                validate_flows(mutated)

    def test_exact_source_patch_and_guard(self):
        original = """#include "models.h"
#include "../llama-memory-hybrid-iswa.h"

void f() {
    for (int il = 0; il < n_layer; ++il) {
        auto * prev_cur = cur;
        if (il == n_layer - 1 && inp_out_ids) {
            cur = x;
        }
    }
}
"""
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            p = root / TARGET
            p.parent.mkdir(parents=True)
            p.write_text(original)
            r = patch(root)
            output = p.read_text()
            for name, layers in LAB_FLOWS.items():
                self.assertIn(f'mode == "{name}"', output)
                self.assertIn("{" + ",".join(map(str, layers)) + "}", output)
            self.assertEqual(output.count(ATTN_GUARD), 1)
            self.assertIn("!hparams.is_recr(source_il)", output)
            self.assertIn("!d1_has_full || !d1_has_sliding", output)
            self.assertIn("if constexpr (decision)", output)
            self.assertIn("d1_step + 1 == d1_flow.size()", output)
            self.assertFalse(r["weights_modified"])
            self.assertFalse(r["game_code_modified"])
            with self.assertRaises(RuntimeError):
                patch(root)

if __name__ == "__main__":
    unittest.main()
