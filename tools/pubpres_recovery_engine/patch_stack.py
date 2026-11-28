"""Prove sequential same-file patches and one final diff have identical edits.

The frozen parser still validates each individual LF unified diff. Indexed
original lines stand for the untouched source, so omitted source bytes cannot
be silently replaced. Removed lines constrain those identities; contradictory
preimages fail. Final vectors must agree in both known bytes and untouched line
identity. This permits sequential patches to revisit a file, not undeclared
changes, reordered edits or duplicate paths within an individual patch.
"""
from __future__ import annotations

import json


def need(ok, message):
    if not ok:
        raise ValueError(message)


def verify(stack, combined, normalize):
    parsed = [json.loads(normalize(item)) for item in stack]
    final = json.loads(normalize(combined))
    paths = {row["path"] for stage in parsed for row in stage}
    need(paths == {row["path"] for row in final}, "Combined patch omits or adds a file")
    results = []
    for name in sorted(paths):
        stages = [row for stage in parsed for row in stage if row["path"] == name]
        expected = next(row for row in final if row["path"] == name)
        need(all(row["mode"] == expected["mode"] == "100644" for row in stages), "Patch mode differs")
        edits = [edit for row in stages + [expected] for edit in row["edits"]]
        largest = max(edit["old_line"] + len(edit["removed"]) for edit in edits)
        expansion = sum(abs(len(edit["added"]) - len(edit["removed"])) for edit in edits)
        count = largest + expansion + 32
        need(count < 200000, "Unbounded patch coordinate")
        original = list(range(count))
        known = {}

        def apply(lines, row):
            result = list(lines)
            for edit in reversed(row["edits"]):
                index = edit["old_line"] - 1
                removed = edit["removed"]
                need(0 <= index <= len(result) and index + len(removed) <= len(result), "Patch coordinates exceed original")
                for actual, declared in zip(result[index:index + len(removed)], removed):
                    if type(actual) is int:
                        need(actual not in known or known[actual] == declared,
                             "Contradictory original line across patch stages")
                        known[actual] = declared
                    else:
                        need(actual == declared, "Later patch does not consume exact earlier postimage")
                result[index:index + len(removed)] = edit["added"]
            return result

        staged = original
        for stage in stages:
            staged = apply(staged, stage)
        actual = apply(original, expected)

        def resolve(lines):
            return [known.get(line, ("unchanged-original-line", line)) if type(line) is int else line for line in lines]

        need(resolve(staged) == resolve(actual), "Combined diff is not the exact sequential patch result: " + name)
        results.append({"path": name, "stages": len(stages), "net_line_delta": len(staged) - len(original),
                        "constrained_original_lines": len(known)})
    return {"schema": "pubpres-exact-patch-stack-composition-v1", "complete": True, "files": results}
