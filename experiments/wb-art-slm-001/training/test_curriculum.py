"""Train-only curriculum tests, independent of torch and model downloads."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import hashlib
import json
import random
import unittest

from curriculum import THEMES, REPLAY_INTERVAL, epoch_indices


def rows():
    data = []
    for theme in THEMES:
        data.append({"id": f"{theme}-literal", "prompt": theme, "theme": theme, "split": "train"})
        data.extend({"id": f"{theme}-{i}", "prompt": f"Draw {theme} {i}", "theme": theme, "split": "train"} for i in range(120))
    return data


class CurriculumTests(unittest.TestCase):
    def test_bootstrap_shuffle_is_bitwise_same(self):
        data = rows()
        for epoch in (0, 1, 7):
            expected = list(range(len(data)))
            random.Random(731 + epoch).shuffle(expected)
            self.assertEqual(epoch_indices(data, 731, epoch), expected)

    def test_first_twelve_and_replays_are_balanced(self):
        data = rows()
        order = epoch_indices(data, 731, 0, "keyword-replay-v1")
        observed = [data[i]["prompt"] for i in order]
        self.assertEqual(len(order), len(data))
        self.assertEqual(set(observed[:12]), set(THEMES))
        self.assertEqual(set(observed[27:28]), {observed[0]})
        keyword_count = Counter(word for word in observed if word in THEMES)
        self.assertLessEqual(max(keyword_count.values()) - min(keyword_count.values()), 1)
        for position in range(12, len(data)):
            self.assertEqual(observed[position] in THEMES, (position - 12 + 1) % REPLAY_INTERVAL == 0)
        self.assertEqual(len([x for x in observed if x not in THEMES]), len(set(x for x in observed if x not in THEMES)))

    def test_deterministic_across_invocations_and_resume_cursor(self):
        data = rows()
        one = epoch_indices(data, 731, 0, "keyword-replay-v1")
        self.assertEqual(one, epoch_indices(data, 731, 0, "keyword-replay-v1"))
        self.assertNotEqual(one, epoch_indices(data, 731, 1, "keyword-replay-v1"))
        cursor = 247
        tail = [data[one[i]]["id"] for i in range(cursor, 400)]
        self.assertEqual(tail, [data[epoch_indices(data, 731, 0, "keyword-replay-v1")[i]]["id"] for i in range(cursor, 400)])

    def test_recorded_1152_row_corpus_exposure(self):
        train_file = Path(__file__).resolve().parents[1] / "corpus" / "train.jsonl"
        if not train_file.is_file():
            self.skipTest("Full admitted corpus not installed in this isolated test directory")
        raw = train_file.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), "972826e1af15a6babaff6e68e4c57d790c0c060a2befe050b4156c5f8ee05f66")
        data = [json.loads(line) for line in raw.splitlines()]
        self.assertEqual(len(data), 1152)
        for mode, expected_words, expected_unique, expected_groups in (
            ("shuffled-v1", 6, 400, 72),
            ("keyword-replay-v1", 36, 376, 70),
        ):
            first = epoch_indices(data, 731, 0, mode)[:400]
            observed_words = [data[i]["theme"] for i in first if data[i]["prompt"] == data[i]["theme"]]
            self.assertEqual(len(observed_words), expected_words)
            self.assertEqual(len(set(first)), expected_unique)
            self.assertEqual(len({data[i]["group_id"] for i in first}), expected_groups)
        self.assertEqual(set(data[i]["theme"] for i in epoch_indices(data, 731, 0, "keyword-replay-v1")[:12]), set(THEMES))

    def test_refuse_final_missing_or_duplicate_keywords(self):
        data = rows()
        for bad in (
            [dict(data[0], split="final")] + data[1:],
            [dict(data[0], prompt="not literal")] + data[1:],
            data + [dict(data[0], id="second-literal")],
            data + [dict(data[0], id="duplicate")],
        ):
            with self.assertRaises(ValueError):
                epoch_indices(bad, 731, 0, "keyword-replay-v1")
        with self.assertRaises(ValueError):
            epoch_indices(data, 731, 0, "unknown")


if __name__ == "__main__":
    unittest.main()
