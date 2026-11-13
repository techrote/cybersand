"""Model-free custody, completion and corpus contracts for the painter trainers.

Adapted from frozen #567 train_lora.py's strict JSON, complete-output handling,
positive native admission and checkpoint inventory. No legacy corpus is used.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import struct

SHA256 = re.compile(r"[a-f0-9]{64}\Z")
COMMIT = re.compile(r"[a-f0-9]{40}\Z")
ROOT = Path(__file__).resolve().parents[1]


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)


def strict_json(text):
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError("duplicate JSON key: " + key)
            value[key] = item
        return value

    def finite(value):
        raise ValueError("non-finite JSON constant: " + value)

    return json.loads(text, object_pairs_hook=unique, parse_constant=finite)


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def digest_json(value):
    return hashlib.sha256(canonical(value).encode("utf-8")).hexdigest()


def read_json(path):
    return strict_json(Path(path).read_text(encoding="utf-8"))


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".writing")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def relative_file(root, name):
    """No absolute, parent-traversal or symlink evidence paths."""
    if not isinstance(name, str) or not name or "\\" in name:
        raise ValueError("invalid evidence path")
    path = Path(name)
    if path.is_absolute() or any(part in (".", "..") for part in path.parts):
        raise ValueError("evidence path escapes bundle")
    root = Path(root).resolve(strict=True)
    current = root
    for part in path.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError("symlink evidence is not admitted")
    if not current.is_file() or not current.resolve().is_relative_to(root):
        raise ValueError("missing evidence file: " + name)
    return current


def verify_file(root, name, expected):
    if not isinstance(expected, str) or not SHA256.fullmatch(expected):
        raise ValueError("missing SHA-256 for " + str(name))
    path = relative_file(root, name)
    if sha256_file(path) != expected:
        raise ValueError("custody hash mismatch: " + name)
    return path


def profile(name, require_supported=False):
    profiles = read_json(Path(__file__).with_name("model_profiles.json"))["profiles"]
    if name not in profiles:
        raise ValueError("unknown model lane")
    selected = profiles[name]
    if not COMMIT.fullmatch(selected.get("revision", "")) or selected.get("subfolder") != "":
        raise ValueError("model requires an exact official root checkpoint")
    if require_supported:
        from lane_adapters import validate_profile
        validate_profile(name, selected)
    return selected


def compiler_module(path=None):
    path = Path(path or ROOT / "compiler.py")
    spec = importlib.util.spec_from_file_location("painter_training_compiler", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_training_corpus(directory, compiler_file=None):
    """Read TRAIN only; sealed FINAL targets are never loaded by this function.

    All split group assignments are inspected as metadata. Native files for TRAIN
    are hash checked against the native admission produced by the replay verifier.
    A JSON flag alone is never sufficient admission.
    """
    directory = Path(directory)
    manifest = read_json(relative_file(directory, "admitted-corpus.json"))
    if manifest.get("schema_version") != 1 or manifest.get("state") != "native-admitted":
        raise ValueError("native-admitted corpus required")
    if not COMMIT.fullmatch(manifest.get("source_sha", "")):
        raise ValueError("missing native source identity")
    if not SHA256.fullmatch(manifest.get("runtime_sha256", "")) or not SHA256.fullmatch(manifest.get("native_verification_sha256", "")):
        raise ValueError("missing verified native runtime/receipt identity")
    compiler_file = Path(compiler_file or ROOT / "compiler.py")
    if sha256_file(compiler_file) != manifest.get("compiler_sha256"):
        raise ValueError("native-admission/compiler identity mismatch")
    compiler = compiler_module(compiler_file)
    groups = manifest.get("structural_groups", {})
    if set(groups) != {"TRAIN", "DEVELOPMENT", "FINAL"}:
        raise ValueError("three structural partitions required")
    for split, ids in groups.items():
        if not isinstance(ids, list) or not ids or any(not isinstance(x, str) for x in ids) or len(ids) != len(set(ids)):
            raise ValueError("invalid structural groups: " + split)
    if sum(map(len, groups.values())) != len(set().union(*map(set, groups.values()))):
        raise ValueError("structural group leakage between splits")
    files = manifest.get("split_files", {})
    if set(files) != set(groups):
        raise ValueError("missing split manifest")
    entry = files["TRAIN"]
    train_file = verify_file(directory, entry["path"], entry["sha256"])
    rows = [strict_json(line) for line in train_file.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not rows or len(rows) != entry["count"] or len({r["id"] for r in rows}) != len(rows):
        raise ValueError("empty/duplicate/miscounted TRAIN rows")
    for row in rows:
        group = row.get("group_id", row.get("structural_group"))
        if (row.get("split") != "TRAIN" or group not in groups["TRAIN"]
                or row.get("structural_group", group) != group):
            raise ValueError("non-TRAIN structural group in trainer")
        if row.get("family") not in {"greebles", "pipework", "architecture"}:
            raise ValueError("unexpected drawing family")
        if not isinstance(row.get("prompt"), str) or not row["prompt"].strip() or type(row.get("program")) is not dict:
            raise ValueError("missing prompt/program")
        completion = canonical(row["program"])
        if "completion" in row and row["completion"] != completion:
            raise ValueError("completion differs from admitted program")
        if "program_sha256" in row and row["program_sha256"] != digest_json(row["program"]):
            raise ValueError("program hash mismatch")
        admission = row.get("native_admission", {})
        if (admission.get("state") != "PASS" or admission.get("native_execution") is not True
                or admission.get("verified") is not True or admission.get("source_sha") != manifest["source_sha"]
                or type(admission.get("affected_cells")) is not int or admission["affected_cells"] <= 0
                or admission.get("runtime_sha256") != manifest["runtime_sha256"]):
            raise ValueError("positive native admission required: " + row["id"])
        for name in ("png", "readback", "receipt"):
            verify_file(directory, admission.get("paths", {}).get(name), admission.get(name + "_sha256"))
        operations = row.get("compiled", {}).get("operations")
        if operations is None:
            operations = row.get("operations")
        if not isinstance(operations, list) or not operations or digest_json(operations) != admission.get("operations_sha256"):
            raise ValueError("native operations do not match admitted program")
        compiled = row["compiled"]
        recomputed = compiler.compile_program(row["program"], seed=row["seed"], focus=compiled["focus"],
                                              material=compiled["material"], allowed_materials=(compiled["material"],))
        if (recomputed != compiled or recomputed["program_sha256"] != admission.get("program_sha256")
                or row["family"] != row["program"].get("family")):
            raise ValueError("admitted program does not compile to native operations")
        receipt = read_json(relative_file(directory, admission["paths"]["receipt"]))
        if (receipt.get("id") != row["id"] or receipt.get("family") != row["family"]
                or receipt.get("seed") != row["seed"] or receipt.get("passed") is not True
                or receipt.get("program_sha256") != recomputed["program_sha256"]
                or receipt.get("operations_sha256") != recomputed["operations_sha256"]
                or receipt.get("crop_i32le_sha256") != admission["readback_sha256"]
                or receipt.get("outside_area_cells") != 0 or receipt.get("unexpected_material_cells") != 0
                or receipt.get("deterministic_replay_checked") is not True):
            raise ValueError("actual native receipt does not bind this TRAIN program")
        raw = relative_file(directory, admission["paths"]["readback"]).read_bytes()
        width, height = compiled["focus"][2:]
        if len(raw) != width * height * 4:
            raise ValueError("native material readback size mismatch")
        values = [item[0] for item in struct.iter_unpack("<i", raw)]
        if (values != compiler.rasterize_operations(operations, compiled["focus"])
                or compiler.verify_structure(recomputed, values)["passed"] is not True):
            raise ValueError("native material cells do not match compiled structural painting")
        row["completion"] = completion
    return rows, manifest


def encode_row(tokenizer, row, system, max_length):
    """Completion-only labels with a real EOS; never truncate long examples."""
    messages = [{"role": "system", "content": system}, {"role": "user", "content": row["prompt"]}]
    prefix = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    full = tokenizer.apply_chat_template(messages + [{"role": "assistant", "content": row["completion"]}], tokenize=False, add_generation_prompt=False)
    if not full.startswith(prefix):
        raise ValueError("unstable chat template prefix")
    ids = tokenizer.encode(full, add_special_tokens=False)
    prefix_ids = tokenizer.encode(prefix, add_special_tokens=False)
    boundary = 0
    for left, right in zip(ids, prefix_ids):
        if left != right:
            break
        boundary += 1
    # As in #567, a boundary-spanning BPE token must supervise the first JSON byte.
    if len(prefix_ids) - boundary > 2:
        raise ValueError("unstable BPE prompt/completion boundary")
    if len(ids) > max_length:
        raise ValueError(f"{row['id']}: {len(ids)} tokens exceeds {max_length}; no truncation")
    if boundary >= len(ids) or tokenizer.eos_token_id not in ids[boundary:]:
        raise ValueError("completion must supervise true EOS")
    return {"id": row["id"], "input_ids": ids, "labels": [-100] * boundary + ids[boundary:],
            "prefix_ids": prefix_ids, "boundary": boundary, "target_tokens": len(ids) - boundary,
            "prompt_bytes": len(row["prompt"].encode()), "completion_bytes": len(row["completion"].encode())}


def strict_completion(tokenizer, generated_ids, validator=None):
    """Keep raw text/tokens and classify first-pass JSON/EOS without repair."""
    tokens = list(generated_ids)
    eos = tokenizer.eos_token_id
    terminated = bool(tokens) and tokens[-1] == eos and eos not in tokens[:-1]
    content = tokens[:-1] if terminated else tokens
    result = {"raw_text": "", "token_ids": tokens, "text_decoded": False, "eos_terminated": terminated,
              "json_valid": False, "program_valid": False, "first_pass_accepted": False}
    try:
        text = tokenizer.decode(content, skip_special_tokens=False)
        result["raw_text"] = text
        result["text_decoded"] = True
        value = strict_json(text)
        result["json_valid"] = True
        if validator is not None:
            validator(value)
            result["program_valid"] = True
        result["first_pass_accepted"] = terminated and result["program_valid"]
    except (ValueError, TypeError, KeyError) as error:
        result["failure"] = str(error)
    return result


def verify_checkpoint(directory):
    directory = Path(directory)
    inventory = read_json(relative_file(directory, "inventory.json"))
    actual = {p.relative_to(directory).as_posix() for p in directory.rglob("*") if p.is_file() and p != directory / "inventory.json"}
    required = {"adapter/adapter_model.safetensors", "adapter/adapter_config.json", "training_state.pt", "receipt.json"}
    if not required.issubset(inventory) or set(inventory) != actual:
        raise ValueError("checkpoint file inventory mismatch")
    for name, item in inventory.items():
        path = verify_file(directory, name, item["sha256"])
        if path.stat().st_size != item["bytes"]:
            raise ValueError("checkpoint size mismatch: " + name)
    return read_json(directory / "receipt.json")
