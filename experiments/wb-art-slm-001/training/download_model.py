#!/usr/bin/env python3
"""Download only one exact official model revision, excluding GGUF/other variants."""
from __future__ import annotations

import argparse
from fnmatch import fnmatch
import json
import os
from pathlib import Path

from train_lora import sha256_file, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--profiles", type=Path, default=Path(__file__).with_name("model_profiles.json"))
    parser.add_argument("--output", type=Path, required=True, help="Private model directory, outside git")
    args = parser.parse_args()
    profile = json.loads(args.profiles.read_text())["profiles"][args.profile]
    os.environ.setdefault("HF_HUB_DISABLE_XET", "1")
    from huggingface_hub import HfApi, snapshot_download
    info = HfApi().model_info(profile["model_id"], revision=profile["revision"], files_metadata=True)
    if info.sha != profile["revision"]:
        raise ValueError("Resolved model revision does not match profile pin")
    prefix = profile["subfolder"].rstrip("/")
    prefix = prefix + "/" if prefix else ""
    patterns = ("*.safetensors", "*.safetensors.index.json", "config.json", "generation_config.json", "tokenizer*", "special_tokens_map.json", "added_tokens.json", "vocab.*", "merges.txt", "chat_template*", "*.py", "LICENSE*", "README.md")
    filenames = []
    for file in info.siblings:
        name = file.rfilename
        if not name.startswith(prefix):
            continue
        relative = name[len(prefix):]
        if "/" not in relative and any(fnmatch(relative, pattern) for pattern in patterns):
            filenames.append(name)
    if not any(name.endswith(".safetensors") for name in filenames):
        raise ValueError("No trainable safetensors weights at this exact variant")
    args.output.mkdir(parents=True, exist_ok=True)
    snapshot_download(profile["model_id"], revision=profile["revision"], allow_patterns=filenames, local_dir=args.output, max_workers=2)
    model_dir = args.output / profile["subfolder"]
    inventory = {str(p.relative_to(model_dir)): {"sha256": sha256_file(p), "bytes": p.stat().st_size} for p in sorted(model_dir.rglob("*")) if p.is_file() and ".cache" not in p.parts and p.name != "download_receipt.json"}
    write_json(args.output / "download_receipt.json", {"profile": args.profile, **profile, "resolved_revision": info.sha, "model_directory": str(model_dir.resolve()), "files": inventory})
    print(json.dumps({"profile": args.profile, "model_directory": str(model_dir.resolve()), "revision": info.sha, "files": len(inventory)}))


if __name__ == "__main__":
    main()
