"""Process credit must come from a measured root within parent lifetimes."""
import unittest
import json
from pathlib import Path
import subprocess
import sys


def process(pid, parent, start, end):
    return {"pid": pid, "parent_pid": parent,
            "creation_filetime_100ns": start, "exit_filetime_100ns": end,
            "image_path": "compiler.exe"}


class PortableLineageTests(unittest.TestCase):
    def credited(self, roots, observations):
        # The historical drivers and Lab have deliberately different modules
        # named process_owner. Keep the witness's imports in its own process,
        # just as its hosted CLI runs, without contaminating the driver suite.
        script = ("import sys,json;sys.path.insert(0,sys.argv[1]);"
                  "from portable_authoring import ProcessPathObserver;"
                  "roots,rows=json.loads(sys.argv[2]);"
                  "print(json.dumps(ProcessPathObserver._correlated(roots,rows)))")
        result = subprocess.run([sys.executable, "-I", "-B", "-c", script,
                                 str(Path(__file__).resolve().parent), json.dumps([roots, observations])],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return {(row["pid"], row["creation_filetime_100ns"])
                for row in json.loads(result.stdout)}

    def test_descendants_join_even_when_observed_out_of_order(self):
        root = process(10, 1, 100, 900)
        child = process(20, 10, 200, 800)
        linker = process(30, 20, 300, 700)
        self.assertEqual(self.credited([root], [linker, child]),
                         {(10, 100), (20, 200), (30, 300)})

    def test_foreign_tree_cannot_supply_a_linker(self):
        root = process(10, 1, 100, 900)
        self.assertEqual(self.credited([root], [process(20, 99, 200, 800)]), {(10, 100)})

    def test_unobserved_parent_pid_reuse_is_refused_by_original_exit(self):
        root = process(10, 1, 100, 200)
        # PID 10 has been reused outside the observation population; the old
        # measured process was already dead when this unrelated child began.
        self.assertEqual(self.credited([root], [process(20, 10, 300, 800)]), {(10, 100)})

    def test_observed_pid_reuse_does_not_inherit_old_root_credit(self):
        root = process(10, 1, 100, 200)
        replacement = process(10, 99, 250, 900)
        self.assertEqual(self.credited([root], [replacement, process(20, 10, 300, 800)]), {(10, 100)})

    def test_child_creation_outside_or_at_parent_lifetime_edges_is_refused(self):
        root = process(10, 1, 100, 200)
        for start in (90, 100, 200, 210):
            with self.subTest(start=start):
                self.assertEqual(self.credited([root], [process(20, 10, start, 800)]), {(10, 100)})

    def test_missing_intermediate_or_unknown_parent_end_has_no_credit(self):
        root = process(10, 1, 100, 900)
        self.assertEqual(self.credited([root], [process(30, 20, 300, 700)]), {(10, 100)})
        unknown_end = process(10, 1, 100, None)
        self.assertEqual(self.credited([unknown_end], [process(20, 10, 300, 700)]), {(10, 100)})

    def test_empty_root_population_cannot_establish_execution(self):
        self.assertEqual(self.credited([], [process(10, 1, 100, 900)]), set())


if __name__ == "__main__":
    unittest.main()
