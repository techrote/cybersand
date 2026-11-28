from __future__ import annotations

import difflib
import random
import unittest

import engine_contract as contract
import patch_stack


def diff(before, after, name="one.cpp"):
    return "".join(difflib.unified_diff(before, after, fromfile="a/" + name, tofile="b/" + name)).encode()


class ExactComposition(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.normalize = staticmethod(contract.original_normalizer(contract.ROOT))

    def test_actual_registered_four_patch_chain(self):
        result = contract.verify_patch_stack()
        self.assertTrue(result["complete"])
        self.assertEqual(sum(row["stages"] > 1 for row in result["files"]), 3)

    def test_repeated_file_edits_consume_exact_previous_bytes(self):
        original = [f"line {i}\n" for i in range(30)]
        middle = original.copy(); middle[9] = "first change\n"
        final = middle.copy(); final[9] = "second change\n"; final[18:18] = ["extra\n"]
        stack = [diff(original, middle), diff(middle, final)]
        self.assertTrue(patch_stack.verify(stack, diff(original, final), self.normalize)["complete"])
        mutations = [list(reversed(stack)), stack[:1],
                     [stack[0], stack[1].replace(b"-first change", b"-wrong preimage")]]
        for altered in mutations:
            with self.subTest(altered=altered), self.assertRaises(ValueError):
                patch_stack.verify(altered, diff(original, final), self.normalize)
        unwanted = final.copy(); unwanted[25] = "undeclared\n"
        with self.assertRaises(ValueError):
            patch_stack.verify(stack, diff(original, unwanted), self.normalize)

    def test_shifted_coordinates_and_untouched_identity(self):
        rng = random.Random(767)
        for trial in range(40):
            original = [f"line {i}\n" for i in range(35)]
            current, stack = original.copy(), []
            for stage in range(4):
                changed = current.copy()
                position = rng.randrange(2, len(changed) - 3)
                changed[position:position + (stage % 3)] = [f"stage {trial}:{stage}:{i}\n" for i in range(1 + stage % 2)]
                stack.append(diff(current, changed))
                current = changed
            with self.subTest(trial=trial):
                self.assertTrue(patch_stack.verify(stack, diff(original, current), self.normalize)["complete"])
                wrong = current.copy(); wrong[-2] = "unrelated line changed\n"
                with self.assertRaises(ValueError):
                    patch_stack.verify(stack, diff(original, wrong), self.normalize)

    def test_extra_file_or_duplicate_within_stage_is_rejected(self):
        a = diff(["old\n"], ["new\n"])
        b = diff(["old\n"], ["new\n"], "two.cpp")
        for stack, final in (([a], a+b), ([a+a], a), ([a, b], a)):
            with self.subTest(stack=stack), self.assertRaises(ValueError):
                patch_stack.verify(stack, final, self.normalize)


if __name__ == "__main__":
    unittest.main()
