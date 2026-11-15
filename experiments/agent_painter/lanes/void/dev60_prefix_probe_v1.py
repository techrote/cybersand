"""VOID provisional DEV60 static prefix check. NOT a frozen benchmark."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import adapter

SYSTEM = ("Return only one valid CyberSand painter program JSON object. "
          "Follow the requested structure. Do not set host seeds, material permissions or focus.")
SYSTEM_SHA256 = "2beaa9dbcd9a006c6bdeb4b0f96fd56fdb50eb0cfc4e8056b7f64bb30a21661c"
FAMILIES = ("greebles", "pipework", "architecture")
FORMS = {f"F{i}" for i in range(5)}
KEYS = {"id", "family", "group_id", "formulation_id", "prompt", "prompt_sha256"}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def strict_json(raw):
    if raw.startswith(b"\xef\xbb\xbf"):
        raise ValueError("BOM forbidden")
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result
    def invalid(value):
        raise ValueError("nonfinite JSON constant")
    return json.loads(raw.decode("utf-8", errors="strict"),
                      object_pairs_hook=unique, parse_constant=invalid)


def audit(rows, ceiling):
    if type(ceiling) is not int or ceiling < 1:
        raise ValueError("positive fixed integer ceiling required")
    if digest(SYSTEM.encode("utf-8")) != SYSTEM_SHA256:
        raise ValueError("VOID historical system instruction mismatch")
    profile = strict_json((Path(__file__).parent / "profile.json").read_bytes())
    if (profile["model_id"], profile["revision"], profile["max_sequence_tokens"],
        profile["vocabulary_size"], profile["special_token_ids"],
        profile["framing"]["id"]) != (adapter.MODEL_ID, adapter.REVISION, 2048,
                                     259, {"pad": 256, "bos": 257, "eos": 258},
                                     "cybersand-void-task-v1"):
        raise ValueError("VOID pinned model/encoder/framing changed")
    if type(rows) is not list or len(rows) != 60:
        raise ValueError("exactly 60 provisional requests required")
    tokenizer = adapter.CyberSandVoidByteTokenizer()
    ids, groups, report = set(), {}, []
    for row in rows:
        if type(row) is not dict or set(row) != KEYS:
            raise ValueError("unexpected/missing field: targets forbidden")
        rid, family, group, form, prompt = (row[k] for k in
            ("id", "family", "group_id", "formulation_id", "prompt"))
        if any(type(v) is not str for v in (rid, family, group, form, prompt, row["prompt_sha256"])):
            raise ValueError("request fields must be strings")
        if not rid or not group or not prompt.strip() or family not in FAMILIES or form not in FORMS:
            raise ValueError("invalid request identity")
        if rid in ids:
            raise ValueError("duplicate request ID")
        ids.add(rid)
        raw = prompt.encode("utf-8", errors="strict")
        if digest(raw) != row["prompt_sha256"]:
            raise ValueError("prompt digest mismatch")
        forms = groups.setdefault((family, group), set())
        if form in forms:
            raise ValueError("duplicate group form")
        forms.add(form)
        tokens = adapter.encode_prompt(tokenizer, prompt, SYSTEM)
        if any(type(t) is not int or not 0 <= t <= 255 for t in tokens):
            raise ValueError("unexpected prefix special token")
        if list(tokenizer.decode(tokens).encode("utf-8")) != tokens:
            raise ValueError("prefix UTF-8 roundtrip changed")
        remaining = 2048 - len(tokens) - ceiling
        if remaining < 0:
            raise ValueError("fixed context budget exceeded; no truncation")
        report.append({"id": rid, "family": family, "group_id": group,
                       "formulation_id": form, "prompt_sha256": digest(raw),
                       "prefix_tokens": len(tokens), "prefix_ids_sha256": digest(bytes(tokens)),
                       "headroom_after_ceiling": remaining})
    if any(sum(key[0] == family for key in groups) != 4 for family in FAMILIES):
        raise ValueError("must provide four groups per family")
    if any(forms != FORMS for forms in groups.values()):
        raise ValueError("must provide all five formulations per group")
    report.sort(key=lambda r: r["id"])
    return {"status": "PROVISIONAL_PREFIX_ONLY_NOT_DEV60_READY",
            "model_id": adapter.MODEL_ID, "revision": adapter.REVISION,
            "framing": adapter.FRAMING_ID, "automatic_bos": False,
            "terminal_eos_id": 258, "context_tokens": 2048,
            "system_sha256": SYSTEM_SHA256, "provisional_ceiling": ceiling,
            "requests": 60, "groups": 12,
            "max_prefix_tokens": max(r["prefix_tokens"] for r in report),
            "min_headroom": min(r["headroom_after_ceiling"] for r in report),
            "prefixes": report, "target_representability_checked": False,
            "dev60_frozen": False, "model_inference": False,
            "new_native_operations": 0, "new_train_admissions": 0,
            "final_targets_opened": False}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target-free-requests", type=Path, required=True)
    ap.add_argument("--provisional-ceiling", type=int, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    if args.output.exists():
        ap.error("refusing to overwrite evidence")
    doc = strict_json(args.target_free_requests.read_bytes())
    if type(doc) is not dict or set(doc) != {"rows"}:
        raise ValueError("target-free provisional rows object required")
    result = audit(doc["rows"], args.provisional_ceiling)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
