#!/usr/bin/env python3
"""Fail-closed, source-derived verifier for the 2048x1024 stress-canvas fixture.

Interprets ONLY the box-stamp subset used by stress_canvas() and independently
reimplements rectangles() row/run merging; never trusts the committed 129 count.
This is source inspection, not a substitute for executing GDScript in Godot.
"""
import argparse
import ast
import hashlib
import json
import re
from pathlib import Path


def expression(source, env):
    # GDScript Array.size() is the sole syntax not shared with Python here.
    source = re.sub(r"\b([A-Za-z_]\w*)\.size\(\)", r"len(\1)", source)
    node = ast.parse(source, mode="eval").body

    def value(n):
        if isinstance(n, ast.Constant) and type(n.value) is int:
            return n.value
        if isinstance(n, ast.Name) and n.id in env:
            return env[n.id]
        if isinstance(n, ast.List):
            return [value(e) for e in n.elts]
        if isinstance(n, ast.Subscript):
            return value(n.value)[value(n.slice)]
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.USub):
            return -value(n.operand)
        if isinstance(n, ast.BinOp):
            a, b = value(n.left), value(n.right)
            if isinstance(n.op, ast.Add):
                return a + b
            if isinstance(n.op, ast.Sub):
                return a - b
            if isinstance(n.op, ast.Mult):
                return a * b
            if isinstance(n.op, ast.Div):
                return a / b  # Vector2i truncates the final float toward zero.
        if (isinstance(n, ast.Call) and isinstance(n.func, ast.Name)
                and n.func.id in ("len", "range") and not n.keywords):
            args = [value(arg) for arg in n.args]
            return len(*args) if n.func.id == "len" else range(*args)
        raise ValueError(f"unsupported stress_canvas expression: {source!r}: {ast.dump(n)}")

    return value(node)


def arguments(source):
    result, start, depth = [], 0, 0
    for index, letter in enumerate(source):
        if letter in "([":
            depth += 1
        elif letter in ")]":
            depth -= 1
        elif letter == "," and depth == 0:
            result.append(source[start:index].strip())
            start = index + 1
        if depth < 0:
            raise ValueError(f"unbalanced expression {source!r}")
    if depth:
        raise ValueError(f"unbalanced expression {source!r}")
    result.append(source[start:].strip())
    return result


def source_stamps(path):
    source = path.read_text(encoding="utf-8")
    constants = {match[1]: int(match[2]) for match in re.finditer(
        r"^const ([A-Z][A-Z_0-9]*) := (\d+)\s*$", source, re.M)}
    head = "static func stress_canvas("
    tail = "static func builtin("
    if source.count(head) != 1 or source.count(tail) != 1:
        raise ValueError("could not uniquely identify Godot functions")
    code = source[source.index(head):source.index(tail)].splitlines()[1:]
    stamps = []
    env = dict(constants)

    def evaluate_block(start, end):
        cursor = start
        while cursor < end:
            raw = code[cursor]
            line = raw.split("#", 1)[0].strip()
            cursor += 1
            if not line:
                continue

            loop = re.fullmatch(r"for (\w+): (?:int|Array) in (.*):", line)
            if loop:
                inner_start = cursor
                indentation = len(raw) - len(raw.lstrip())
                while cursor < end:
                    following = code[cursor]
                    if following.strip() and len(following) - len(following.lstrip()) <= indentation:
                        break
                    cursor += 1
                loop_value = expression(loop[2], env)
                iterator = range(loop_value) if isinstance(loop_value, int) else loop_value
                for item in iterator:
                    env[loop[1]] = item
                    evaluate_block(inner_start, cursor)
                continue

            assignment = re.fullmatch(r"var (\w+) := (\[.*\])", line)
            if assignment:
                env[assignment[1]] = expression(assignment[2], env)
                continue

            if line.startswith("_box(") and line.endswith(")"):
                parts = arguments(line[5:-1])
                if len(parts) != 4 or parts[0] != "e":
                    raise ValueError(f"unexpected box arguments: {line}")
                coords = []
                for word in parts[1:3]:
                    if not word.startswith("Vector2i(") or not word.endswith(")"):
                        raise ValueError(f"unsupported coordinate: {word}")
                    point = arguments(word[len("Vector2i("):-1])
                    if len(point) != 2:
                        raise ValueError(f"coordinate must have 2 members: {word}")
                    coords.append([int(expression(v, env)) for v in point])
                stamps.append((*coords[0], *coords[1], expression(parts[3], env)))
                continue

            if (line.startswith(("var data := fresh(", "var e: Array = data.edits",
                                 "var spots := [[", "data.actors.append(",
                                 "data.next_id =", "data.material ="))
                    or line == "return data"):
                continue
            raise ValueError(f"unknown scene statement (refusing to ignore): {line}")

    evaluate_block(0, len(code))
    if not stamps:
        raise ValueError("no source stamps")
    return stamps


def merge_stamps(stamps, width=2048, height=1024):
    raster = bytearray(width * height)
    painted_rows = set()
    for x0, y0, x1, y1, material in stamps:
        if not (0 <= x0 < x1 <= width and 0 <= y0 < y1 <= height
                and isinstance(material, int) and 0 < material <= 255):
            raise ValueError(f"invalid source stamp: {(x0, y0, x1, y1, material)}")
        segment = bytes([material]) * (x1 - x0)
        for y in range(y0, y1):
            raster[y * width + x0:y * width + x1] = segment
            painted_rows.add(y)

    runs, open_run = [], {}
    for y in sorted(painted_rows):
        x = 0
        while x < width:
            start = x
            material = raster[y * width + x]
            while x < width and raster[y * width + x] == material:
                x += 1
            if material == 0:
                continue
            key = (start, x - start, material)
            existing = open_run.get(key)
            if existing is not None and runs[existing][1] + runs[existing][3] == y:
                runs[existing][3] += 1
            else:
                open_run[key] = len(runs)
                runs.append([start, y, x - start, 1, material])
    return runs, raster


def check_fixture(fixture_path, source_path):
    stamps = source_stamps(source_path)
    canonical, raster = merge_stamps(stamps)
    records = []
    for line in fixture_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        fields = line.split()
        if len(fields) != 5:
            raise ValueError(f"invalid fixture line {line!r}")
        records.append([int(word) for word in fields])

    from_fixture = bytearray(len(raster))
    for x, y, w, h, material in records:
        if not (0 <= x < x + w <= 2048 and 0 <= y < y + h <= 1024
                and 0 < material <= 255):
            raise ValueError(f"out-of-bounds fixture rectangle: {(x, y, w, h, material)}")
        row = bytes([material]) * w
        for yy in range(y, y + h):
            from_fixture[yy * 2048 + x:yy * 2048 + x + w] = row

    a, b = {tuple(row) for row in canonical}, {tuple(row) for row in records}
    diffs = sum(x != y for x, y in zip(raster, from_fixture))
    outcome = {
        "source": str(source_path),
        "source_sha256": hashlib.sha256(source_path.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
        "fixture": str(fixture_path),
        "fixture_sha256": hashlib.sha256(fixture_path.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
        "authored_stamps": len(stamps),
        "source_merged_rectangles": len(canonical),
        "fixture_rectangles": len(records),
        "source_raster_sha256": hashlib.sha256(raster).hexdigest(),
        "fixture_raster_sha256": hashlib.sha256(from_fixture).hexdigest(),
        "missing_rectangles": len(a - b),
        "unexpected_rectangles": len(b - a),
        "raster_differing_cells": diffs,
        "pass": (len(a) == len(canonical) == len(records) == len(b)
                 and not a.symmetric_difference(b) and diffs == 0),
    }
    return outcome


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, default=Path("godot/scripts/workbench_setup.gd"))
    ap.add_argument("--fixture", type=Path, default=Path("native/bench/data/neighbour_stress_rectangles.txt"))
    ap.add_argument("--out", type=Path)
    args = ap.parse_args()
    result = check_fixture(args.fixture, args.source)
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    print(encoded, end="")
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(encoded, encoding="utf-8")
    if not result["pass"]:
        raise SystemExit("stress-canvas fixture differs from source-derived raster or rectangles")


if __name__ == "__main__":
    main()
