"""Exercise the real native CLI's material admission and sampled JSON accounting."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ci"))
from execution_policy import watchdog_seconds
from native_execution_policy import PHYSICS_DISPATCH_WORKERS, PHYSICS_INVOCATIONS


MATERIAL_COUNT = 132
BUILDING_IDS = range(81, MATERIAL_COUNT)
INVALID_IDS = (
    "-1", "-125", "-175", "-255", "-256", "10", "132", "255", "256",
    "257", "337", "387", "65536", "65617", "2147483647", "2147483648",
    "-2147483648", "9223372036854775807", "9223372036854775808",
    "-9223372036854775809", "81bad", "81.0", "0x51", "",
)


def invocation_plan() -> list[dict]:
    # unittest sorts the three existing method names. Preserve that observation
    # order even when independent native processes finish in a different order.
    plan = []
    for material in BUILDING_IDS:
        for role in ("upper", "lower"):
            plan.append({"name": f"material-{material}-{role}",
                         "top": material if role == "upper" else 1,
                         "bottom": 1 if role == "upper" else material})
    for index, material in enumerate(INVALID_IDS):
        for role in ("upper", "lower"):
            plan.append({"name": f"invalid-{index}-{role}",
                         "top": material if role == "upper" else 1,
                         "bottom": 1 if role == "upper" else material})
    for material in (2, 80):
        for role in ("upper", "lower"):
            plan.append({"name": f"material-{material}-{role}",
                         "top": material if role == "upper" else 1,
                         "bottom": 1 if role == "upper" else material})
    if len(plan) != PHYSICS_INVOCATIONS or len({row["name"] for row in plan}) != len(plan):
        raise ValueError("Physics invocation inventory differs from its complete execution budget")
    return plan


def invocation_command(executable: Path, top: int | str, bottom: int | str) -> list[str]:
    return [str(executable), str(top), str(bottom), "packed", "2", "0",
            "1", "1", "baseline", "1", "0", "3"]


def execute_invocation(executable: Path, output: Path, item: dict) -> dict:
    label = item["name"]
    command = invocation_command(executable, item["top"], item["bottom"])
    timeout_seconds = watchdog_seconds("operation_seconds")
    started = time.monotonic()
    timed_out = False
    launch_error = None
    try:
        result = subprocess.run(command, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=timeout_seconds)
        stdout, stderr, returncode = result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        def decoded(value: str | bytes | None) -> str:
            return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value or ""
        stdout, stderr, returncode = decoded(error.stdout), decoded(error.stderr), None
        timed_out = True
    except OSError as error:
        launch_error = type(error).__name__ + ": " + str(error)
        stdout, stderr, returncode = "", launch_error + "\n", None
    (output / (label + ".jsonl")).write_text(stdout, encoding="utf-8")
    (output / (label + ".stderr.log")).write_text(stderr, encoding="utf-8")
    return {"name": label, "command": command, "returncode": returncode,
            "timed_out": timed_out, "launch_error": launch_error,
            "seconds": round(time.monotonic() - started, 3),
            "watchdog_key": "operation_seconds", "timeout_seconds": timeout_seconds,
            "stdout_sha256": hashlib.sha256(stdout.encode()).hexdigest(),
            "stderr_sha256": hashlib.sha256(stderr.encode()).hexdigest(),
            "stdout": stdout, "stderr": stderr}


def dispatch_invocations(executable: Path, output: Path, plan: list[dict]) -> list[dict]:
    labels = [item["name"] for item in plan]
    if len(set(labels)) != len(labels) or any(not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", label) for label in labels):
        raise ValueError("Physics output labels must be unique safe names")
    with ThreadPoolExecutor(max_workers=PHYSICS_DISPATCH_WORKERS, thread_name_prefix="physics-cli") as executor:
        futures = [executor.submit(execute_invocation, executable, output, item) for item in plan]
        # Only immutable per-label process results cross this boundary. All
        # unittest assertions/subTest contexts remain on the calling thread.
        return [future.result() for future in futures]


def evidence_record(result: dict) -> dict:
    return {key: value for key, value in result.items() if key not in {"stdout", "stderr"}}


class CharacterisationCliTests(unittest.TestCase):
    executable: Path
    output: Path
    records: list[dict]
    prepared_results: dict[str, dict] | None = None
    checked_invocations: list[str]

    def invoke(self, label: str, top: int | str, bottom: int | str) -> dict:
        if self.prepared_results is None:
            result = execute_invocation(self.executable, self.output, {"name": label, "top": top, "bottom": bottom})
            self.records.append(evidence_record(result))
        else:
            result = self.prepared_results[label]
            self.checked_invocations.append(label)
            self.assertEqual(result["command"], invocation_command(self.executable, top, bottom),
                             "prefetched native command differs from the original scientific invocation")
        self.assertIsNone(result["launch_error"], f"{label}: CLI could not launch")
        self.assertFalse(result["timed_out"],
                         f"{label}: CLI exceeded its configured {result['timeout_seconds']:g}-second watchdog")
        return result

    def check_material(self, material: int, role: str) -> None:
        label = f"material-{material}-{role}"
        top, bottom = (material, 1) if role == "upper" else (1, material)
        result = self.invoke(label, top, bottom)
        self.assertEqual(result["returncode"], 0, f"{label}: see retained stderr")
        self.assertEqual(result["stderr"], "", f"{label}: unexpected diagnostic")
        rows = [json.loads(line) for line in result["stdout"].splitlines()]
        self.assertEqual([row["type"] for row in rows], ["sample", "sample", "result"])
        initial, final, summary = rows
        self.assertEqual([initial["tick"], final["tick"]], [0, 1])
        self.assertEqual(summary["completed_ticks"], 1)
        self.assertEqual(summary["overflow"], 0)
        self.assertEqual([summary["left_x"], summary["surface_y"], summary["floor_y"]], [64, 96, 98])
        # The documented 3-wide, 2-deep seed-0 fixture observes x=62..69,
        # y=0..100: 808 cells, with total y moment 8 * (100 * 101 / 2).
        for sample in (initial, final):
            self.assertEqual(len(sample["counts"]), MATERIAL_COUNT)
            self.assertEqual(len(sample["sum_y"]), MATERIAL_COUNT)
            self.assertEqual(sum(sample["counts"]), 808)
            self.assertEqual(sum(sample["sum_y"]), 40400)
        # Independent rectangle accounting: 48 upper cells at y=80..95,
        # 6 lower cells at y=96..97, 204 enclosure cells and 550 Empty cells.
        counts, sums = [0] * MATERIAL_COUNT, [0] * MATERIAL_COUNT
        counts[0], sums[0] = 550, 25625
        if role == "upper":
            counts[1], sums[1] = 210, 10575
            counts[material], sums[material] = 48, 4200
            centroid = Fraction(175, 2)
        else:
            counts[1], sums[1] = 252, 14196
            counts[material], sums[material] = 6, 579
            centroid = Fraction(193, 2)
        self.assertEqual(initial["counts"], counts)
        self.assertEqual(initial["sum_y"], sums)
        self.assertEqual(Fraction(initial["sum_y"][material], initial["counts"][material]), centroid)
        self.assertEqual(initial["water_mass"], 0)
        # Existing Sand enclosed by Wall has no movement opportunity in one tick.
        if material == 2:
            self.assertEqual(final["counts"], counts)
            self.assertEqual(final["sum_y"], sums)

    def test_all_building_slots_in_both_layers(self) -> None:
        for material in BUILDING_IDS:
            for role in ("upper", "lower"):
                with self.subTest(material=material, role=role):
                    self.check_material(material, role)

    def test_original_material_controls(self) -> None:
        for material in (2, 80):
            for role in ("upper", "lower"):
                with self.subTest(material=material, role=role):
                    self.check_material(material, role)

    def test_invalid_materials_are_rejected_before_fixture_output(self) -> None:
        for index, material in enumerate(INVALID_IDS):
            for role in ("upper", "lower"):
                with self.subTest(material=material, role=role):
                    top, bottom = (material, 1) if role == "upper" else (1, material)
                    result = self.invoke(f"invalid-{index}-{role}", top, bottom)
                    self.assertEqual(result["returncode"], 1)
                    self.assertEqual(result["stdout"], "")
                    self.assertTrue(result["stderr"].strip())
                    self.assertNotIn("Sanitizer", result["stderr"])
                    self.assertNotIn("runtime error:", result["stderr"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    CharacterisationCliTests.executable = args.executable.resolve(strict=True)
    CharacterisationCliTests.output = args.output
    plan = invocation_plan()
    prefetched = dispatch_invocations(CharacterisationCliTests.executable, args.output, plan)
    CharacterisationCliTests.records = [evidence_record(row) for row in prefetched]
    CharacterisationCliTests.prepared_results = {row["name"]: row for row in prefetched}
    CharacterisationCliTests.checked_invocations = []
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(CharacterisationCliTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    expected_order = [row["name"] for row in plan]
    complete = CharacterisationCliTests.checked_invocations == expected_order
    passed = result.wasSuccessful() and complete
    report = {"status": "passed" if passed else "failed",
              "executable": str(CharacterisationCliTests.executable),
              "executable_sha256": hashlib.sha256(CharacterisationCliTests.executable.read_bytes()).hexdigest(),
              "test_groups": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
              "building_ids": list(BUILDING_IDS), "invalid_ids": list(INVALID_IDS),
              "dispatch_workers": PHYSICS_DISPATCH_WORKERS, "planned_invocations": expected_order,
              "checked_invocations": CharacterisationCliTests.checked_invocations,
              "complete_invocation_inventory": complete,
              "invocations": CharacterisationCliTests.records}
    (args.output / "results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"CLI material accounting: {report['status']}; {len(report['invocations'])} invocations")
    return int(not passed)


if __name__ == "__main__":
    raise SystemExit(main())
