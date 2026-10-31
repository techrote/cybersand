#!/usr/bin/env python3
"""NONQUALIFYING single-exit hypotheses for the exact retained palette shader.

This intentionally bounded parser only transforms if branches whose taken arm
always returns. It moves the original continuation into an explicit else arm;
it never adds a predicate flag, loop, switch, duplicate formula, or eager work.
Every original return expression is assigned to the existing initialized local
colour, followed by one function-level return. All other statement bytes and
condition bytes are retained. Unsupported control flow is rejected.
"""
from __future__ import annotations

import argparse
import dataclasses
import hashlib
import json
import re
from pathlib import Path

FROZEN_HOIST_SHA256 = "426c2b8a829d6ca216659b73f7663ba6c7f6dddd300726b81ed1eec85bbd3e1d"
FROZEN_UNIFIED_SHA256 = "10edc6410eeed27a4883e7452abe5d5a47f213b256886c89daa0b88dbd33600f"
CATALOGUES = ("apply_building_finish", "apply_material_flair")
WARNING_HELPERS = ("apply_neighbour_relief", "apply_structured_fill")


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


@dataclasses.dataclass
class Token:
    text: str
    start: int
    end: int


@dataclasses.dataclass
class Node:
    kind: str
    start: int
    end: int
    raw: str
    leading: str = ""
    condition: str = ""
    header: str = ""
    children: list | None = None
    trailing: str = ""
    then: "Node | None" = None
    other: "Node | None" = None
    expression: str = ""


class FrozenParser:
    def __init__(self, text):
        self.text = text
        expression = r"\s+|//[^\n]*(?:\n|$)|/\*.*?\*/|[A-Za-z_][A-Za-z_0-9]*|."
        self.tokens = [Token(m.group(), m.start(), m.end())
                       for m in re.finditer(expression, text, re.S)
                       if not (m.group().isspace() or m.group().startswith(("//", "/*")))]

    def matching(self, index, opening, closing):
        require(self.tokens[index].text == opening, "Missing opening delimiter")
        depth = 1
        at = index + 1
        while at < len(self.tokens):
            token = self.tokens[at].text
            if token == opening:
                depth += 1
            elif token == closing:
                depth -= 1
                if depth == 0:
                    return at
            at += 1
        raise RuntimeError("Unclosed frozen delimiter")

    def statement(self, index):
        token = self.tokens[index]
        start = token.start
        if token.text == "{":
            closing = self.matching(index, "{", "}")
            children = []
            at, previous = index + 1, token.end
            while at < closing:
                child, at = self.statement(at)
                child.leading = self.text[previous:child.start]
                children.append(child)
                previous = child.end
            require(at == closing, "Block statement crossed its boundary")
            end = self.tokens[closing].end
            return Node("block", start, end, self.text[start:end], children=children,
                        trailing=self.text[previous:self.tokens[closing].start]), closing + 1
        if token.text == "if":
            opening = index + 1
            closing = self.matching(opening, "(", ")")
            then, at = self.statement(closing + 1)
            other = None
            if at < len(self.tokens) and self.tokens[at].text == "else":
                other, at = self.statement(at + 1)
            end = (other or then).end
            return Node("if", start, end, self.text[start:end],
                        condition=self.text[self.tokens[opening].end:self.tokens[closing].start],
                        header=self.text[start:then.start], then=then, other=other), at
        if token.text in ("for", "while"):
            closing = self.matching(index + 1, "(", ")")
            body, at = self.statement(closing + 1)
            require(not has_return(body), "Return inside a loop is outside this experiment")
            return Node("raw", start, body.end, self.text[start:body.end]), at
        require(token.text not in ("do", "switch", "case", "else"),
                "Unsupported frozen statement")
        at = index
        while at < len(self.tokens):
            current = self.tokens[at].text
            if current == ";":
                end = self.tokens[at].end
                kind = "return" if token.text == "return" else "raw"
                expression = self.text[token.end:self.tokens[at].start].strip() if kind == "return" else ""
                return Node(kind, start, end, self.text[start:end], expression=expression), at + 1
            if current in ("(", "["):
                at = self.matching(at, current, ")" if current == "(" else "]")
            elif current in ("{", "}"):
                raise RuntimeError("Unexpected compound ordinary statement")
            at += 1
        raise RuntimeError("Missing frozen statement terminator")

    def function(self, name):
        matches = [i for i, token in enumerate(self.tokens)
                   if token.text == name and i and self.tokens[i - 1].text == "vec4"
                   and self.tokens[i + 1].text == "("]
        require(len(matches) == 1, "Function anchor missing or duplicated")
        index = matches[0]
        closing = self.matching(index + 1, "(", ")")
        body, _ = self.statement(closing + 1)
        require(body.kind == "block", "Function body is not a block")
        return self.tokens[index - 1].start, body


def has_return(node):
    if node.kind == "return":
        return True
    if node.kind == "block":
        return any(has_return(child) for child in node.children)
    if node.kind == "if":
        return has_return(node.then) or (node.other is not None and has_return(node.other))
    return False


def always_returns(node):
    if node.kind == "return":
        return True
    if node.kind == "block":
        return any(always_returns(child) for child in node.children)
    if node.kind == "if":
        return node.other is not None and always_returns(node.then) and always_returns(node.other)
    return False


def meaningful_tokens(text):
    return tuple(token.text for token in FrozenParser(text).tokens)


def original_tree(sequence, continuation=("missing-return",)):
    """Canonical evaluation tree: non-returning statements stay opaque bytes."""
    if not sequence:
        return continuation
    first, rest = sequence[0], sequence[1:]
    tail = original_tree(rest, continuation)
    if first.kind == "return":
        require(not rest, "Unreachable frozen statements after return")
        return ("result", meaningful_tokens(first.expression))
    if first.kind == "if" and has_return(first):
        require(first.other is None and always_returns(first.then),
                "Only returning taken arms without an existing else are supported")
        branch = first.then.children if first.then.kind == "block" else [first.then]
        return ("if", meaningful_tokens(first.condition), original_tree(branch), tail)
    require(not has_return(first), "Unsupported nested return")
    return ("statement", meaningful_tokens(first.raw), tail)


def transform_sequence(sequence, returns, branches):
    if not sequence:
        return []
    first, rest = sequence[0], sequence[1:]
    if first.kind == "return":
        require(not rest, "Unreachable frozen statements after return")
        require(first.expression == "colour"
                or re.fullmatch(r"apply_burn\(colour, pixel, condition\)", first.expression)
                or re.fullmatch(r"apply_detail_edges\(colour, material_id, flair, pixel, extent, edge, exposed, condition\)", first.expression),
                "Return expression is outside the reviewed float4 local-value forms")
        returns.append({"start": first.start, "end": first.end, "expression": first.expression,
                        "original_statement_sha256": digest(first.raw.encode())})
        return [{"kind": "assignment", "node": first}]
    if first.kind == "if" and has_return(first):
        require(first.other is None and always_returns(first.then),
                "Only returning taken arms without an existing else are supported")
        branch = first.then.children if first.then.kind == "block" else [first.then]
        branches.append({"condition": first.condition,
                         "condition_sha256": digest(first.condition.encode()),
                         "taken_arm_always_returns": True,
                         "continuation_evaluated_only_when_original_condition_false": True})
        return [{"kind": "if", "node": first,
                 "then": transform_sequence(branch, returns, branches),
                 "else": transform_sequence(rest, returns, branches)}]
    require(not has_return(first), "Unsupported nested return")
    return [{"kind": "raw", "node": first}] + transform_sequence(rest, returns, branches)


def transformed_tree(sequence):
    require(bool(sequence), "Missing transformed leaf")
    first, rest = sequence[0], sequence[1:]
    node = first["node"]
    if first["kind"] == "assignment":
        require(not rest, "Work after original-return assignment")
        return ("result", meaningful_tokens(node.expression))
    if first["kind"] == "if":
        require(not rest, "Work after exclusive return dispatch")
        return ("if", meaningful_tokens(node.condition),
                transformed_tree(first["then"]), transformed_tree(first["else"]))
    return ("statement", meaningful_tokens(node.raw), transformed_tree(rest))


def emitted_tree(sequence, continuation=("return-current-colour",)):
    """Normalize the reparsed emitted source, without consulting its IR.

    Only a full local-colour assignment immediately before the function return
    becomes a result leaf. A dispatch with that same continuation must have an
    explicit else. Earlier nonreturning statements, including their internal
    conditionals, remain exact opaque token sequences just as in original_tree.
    This rejects extra work after a return assignment and omitted/reordered
    emitted branches independently of transform_sequence/render_sequence.
    """
    if not sequence:
        return continuation
    first, rest = sequence[0], sequence[1:]
    tail = emitted_tree(rest, continuation)
    require(not has_return(first), "Unexpected return inside emitted dispatch")
    if tail == ("return-current-colour",):
        if first.kind == "raw":
            match = re.fullmatch(r"colour\s*=\s*(.*?)\s*;", first.raw, re.S)
            require(match is not None, "Emitted leaf does not assign its result")
            return ("result", meaningful_tokens(match.group(1)))
        if first.kind == "if":
            require(first.other is not None, "Emitted dispatch lacks an exclusive else")
            then = first.then.children if first.then.kind == "block" else [first.then]
            other = first.other.children if first.other.kind == "block" else [first.other]
            return ("if", meaningful_tokens(first.condition),
                    emitted_tree(then), emitted_tree(other))
        raise RuntimeError("Unexpected emitted leaf shape")
    return ("statement", meaningful_tokens(first.raw), tail)


def render_sequence(sequence, first_leading=True):
    text = ""
    for index, item in enumerate(sequence):
        node = item["node"]
        leading = node.leading if first_leading or index else ""
        if item["kind"] == "raw":
            text += leading + node.raw
        elif item["kind"] == "assignment":
            text += leading + "colour = " + node.expression + ";"
        else:
            text += leading + node.header + "{"
            text += render_sequence(item["then"])
            text += node.then.trailing if node.then.kind == "block" else ""
            text += "} else"
            alternate = item["else"]
            if len(alternate) == 1 and alternate[0]["kind"] == "if":
                # Comments and whitespace between original branches remain.
                text += "\n" + render_sequence(alternate)
            else:
                text += " {" + render_sequence(alternate) + "\n\t}"
    return text


def single_exit_function(text, name):
    parser = FrozenParser(text)
    start, body = parser.function(name)
    original = text[start:body.end]
    require(always_returns(body), "Function has an unreturned path")
    returns, branches = [], []
    transformed = transform_sequence(body.children, returns, branches)
    before_tree = original_tree(body.children)
    after_tree = transformed_tree(transformed)
    require(before_tree == after_tree, "Canonical evaluation tree differs")
    replacement_body = "{" + render_sequence(transformed) + "\n\treturn colour;\n}"
    result = text[:body.start] + replacement_body + text[body.end:]
    result_parser = FrozenParser(result)
    result_start, result_body = result_parser.function(name)
    replacement = result[result_start:result_body.end]
    result_return_tokens = [token for token in FrozenParser(replacement).tokens if token.text == "return"]
    require(len(result_return_tokens) == 1, "Generated function does not have one return")
    require(result_body.children[-1].kind == "return"
            and result_body.children[-1].expression == "colour", "Final return differs")
    # This is a separate normalization of the rendered bytes after reparsing,
    # not a comparison against the intermediate transformed representation.
    actual_emitted_tree = emitted_tree(result_body.children[:-1])
    require(before_tree == actual_emitted_tree, "Rendered source evaluation tree differs")
    require("switch" not in [token.text for token in FrozenParser(replacement).tokens],
            "Switch introduced")
    for keyword in ("for", "while", "discard"):
        require(sum(token.text == keyword for token in FrozenParser(original).tokens)
                == sum(token.text == keyword for token in FrozenParser(replacement).tokens),
                "Loop/discard count changed")
    return result, {"function": name, "original_sha256": digest(original.encode()),
                    "candidate_sha256": digest(replacement.encode()),
                    "original_return_count": len(returns), "candidate_return_count": 1,
                    "return_assignments": returns, "exclusive_branches": branches,
                    "canonical_evaluation_tree_sha256": digest(json.dumps(before_tree, separators=(",", ":")).encode()),
                    "canonical_evaluation_tree_equal": True,
                    "independent_emitted_source_tree_equal": True,
                    "unchanged_statement_and_condition_tokens": True,
                    "unconditional_final_return": "colour"}


def transform_functions(source, names):
    receipts = []
    for name in names:
        source, receipt = single_exit_function(source, name)
        receipts.append(receipt)
    return source, receipts


def single_exit_variants(data: bytes, unified_data: bytes | None = None) -> list[dict]:
    require(digest(data) == FROZEN_HOIST_SHA256, "Expected exact frozen hoist shader")
    original = data.decode("utf-8")
    catalogue, catalogue_receipts = transform_functions(original, CATALOGUES)
    warning, warning_receipts = transform_functions(catalogue, WARNING_HELPERS)
    cases = [("hoist-control-cold", original, []),
             ("single-exit-catalogues-cold", catalogue, catalogue_receipts),
             ("single-exit-warning-helpers-cold", warning, catalogue_receipts + warning_receipts)]
    if unified_data is not None:
        require(digest(unified_data) == FROZEN_UNIFIED_SHA256, "Expected exact frozen unified shader")
        unified, receipts = transform_functions(unified_data.decode("utf-8"), CATALOGUES + WARNING_HELPERS)
        cases.append(("unified-single-exit-warning-helpers-cold", unified, receipts))
    return [{"name": name,
             "scope": "unchanged retained control" if not checks else "NONQUALIFYING full-visual single-exit control-flow hypothesis",
             "qualification_passed": False, "full_visual_candidate": bool(checks),
             "shader": shader.encode("utf-8"), "sha256": digest(shader.encode("utf-8")),
             "source_checks": checks}
            for name, shader, checks in cases]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--unified-source", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    rows = single_exit_variants(args.source.read_bytes(),
                               args.unified_source.read_bytes() if args.unified_source else None)
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = []
    for row in rows:
        (args.output / (row["name"] + ".gdshader")).write_bytes(row["shader"])
        manifest.append({key: value for key, value in row.items() if key != "shader"})
    (args.output / "variants.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps([{key: row[key] for key in ("name", "sha256")} for row in manifest], indent=2))


if __name__ == "__main__":
    main()
