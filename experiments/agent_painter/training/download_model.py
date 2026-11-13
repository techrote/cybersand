#!/usr/bin/env python3
"""Download one public, immutable safetensors model; no remote code or secrets."""
from __future__ import annotations

import argparse
from fnmatch import fnmatch
import os
from pathlib import Path

from common import profile, read_json, sha256_file, write_json


def download(lane, destination):
    selected = profile(lane, require_supported=True)
    os.environ.setdefault("HF_HUB_DISABLE_XET", "1")
    from huggingface_hub import HfApi, snapshot_download

    destination = Path(destination)
    if destination.exists():
        raise ValueError("model destination already exists; do not overwrite a pinned snapshot")
    info = HfApi(token=False).model_info(selected["model_id"], revision=selected["revision"], files_metadata=True)
    if info.sha != selected["revision"] or info.private or info.gated:
        raise ValueError("model must be the exact public ungated revision")
    license_name = (info.card_data or {}).get("license")
    if license_name != selected.get("card_license", selected["license"]):
        raise ValueError("model license differs from reviewed profile")
    for field in ("license_name", "license_link"):
        if field in selected and (info.card_data or {}).get(field) != selected[field]:
            raise ValueError("model license declaration differs from reviewed profile: " + field)
    patterns = ("*.safetensors", "*.safetensors.index.json", "config.json", "generation_config.json",
                "tokenizer*", "special_tokens_map.json", "added_tokens.json", "vocab.*", "merges.txt",
                "chat_template*", "LICENSE*", "README.md")
    # A reviewed source file may be retained as inert, hash-bound provenance.
    # Loaders never execute it or enable trust_remote_code.
    filenames = [item.rfilename for item in info.siblings if "/" not in item.rfilename
                 and (item.rfilename in selected["required_hashes"]
                      or (not item.rfilename.endswith(".py")
                          and any(fnmatch(item.rfilename, pattern) for pattern in patterns)))]
    if not set(selected["required_hashes"]).issubset(filenames):
        raise ValueError("missing pinned model/tokenizer files")
    snapshot_download(selected["model_id"], revision=selected["revision"], allow_patterns=filenames,
                      local_dir=destination, max_workers=2, token=False)
    files = {name: {"sha256": sha256_file(destination / name), "bytes": (destination / name).stat().st_size}
             for name in sorted(filenames)}
    for name, expected in selected["required_hashes"].items():
        if files[name]["sha256"] != expected:
            raise ValueError("upstream byte identity mismatch: " + name)
    config = read_json(destination / "config.json")
    if config.get("model_type") != selected["model_type"] or config.get("architectures") != [selected["architecture"]]:
        raise ValueError("model architecture differs from lane profile")
    if config.get("auto_map"):
        raise ValueError("unexpected remote model code mapping")
    receipt = {"schema_version": 1, "profile": selected,
               "lane": lane, "model_id": selected["model_id"], "revision": info.sha,
               "license": selected["license"], "card_license": license_name,
               "trust_remote_code": False, "files": files}
    write_json(destination / "download_receipt.json", receipt)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default="smol")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    receipt = download(args.profile, args.output)
    print(f"Pinned public {receipt['model_id']}@{receipt['revision']}: {len(receipt['files'])} verified files", flush=True)


if __name__ == "__main__":
    main()
