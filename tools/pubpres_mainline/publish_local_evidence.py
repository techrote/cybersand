#!/usr/bin/env python3
"""Reassemble original bounded evidence chunks; never alter their archive bytes."""
import argparse
import base64
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import tarfile
import urllib.request
import zlib
import campaign_request
from common import require

MAX_ARCHIVE_BYTES = 2 * 1024**2
MAX_CHUNK_BYTES = 131072
MAX_CHUNKS = 16
MAX_API_BYTES = 256 * 1024
MAX_EXPANDED_BYTES = 64 * 1024**2
MAX_CONTENT_BYTES = 64 * 1024**2
MAX_MEMBERS = 1000
ROLES = ["spawn", "presentation", "presentation-followup"]


def git_blob_sha(raw):
    return hashlib.sha1(("blob " + str(len(raw)) + "\0").encode("ascii") + raw).hexdigest()


def is_hex(value, length):
    return isinstance(value, str) and re.fullmatch("[0-9a-f]{" + str(length) + "}", value) is not None


def validate_item(item):
    require(isinstance(item, dict) and set(item) == {
        "role", "filename", "bytes", "sha256", "assembled_git_blob", "chunks"},
        "Unknown original evidence archive record")
    require(item["role"] in ROLES and isinstance(item["filename"], str)
            and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*\.tar\.gz", item["filename"]) is not None
            and len(item["filename"]) <= 120, "Unsafe original evidence archive filename")
    require(type(item["bytes"]) is int and 0 < item["bytes"] < MAX_ARCHIVE_BYTES
            and is_hex(item["sha256"], 64) and is_hex(item["assembled_git_blob"], 40),
            "Invalid original evidence archive identity or bound")
    chunks = item["chunks"]
    require(isinstance(chunks, list) and 1 <= len(chunks) <= MAX_CHUNKS,
            "Original evidence chunk population exceeds its bound")
    offset = 0
    for chunk in chunks:
        require(isinstance(chunk, dict) and set(chunk) == {"offset", "bytes", "sha256", "git_blob"},
                "Unknown original evidence chunk record")
        require(type(chunk["offset"]) is int and chunk["offset"] == offset
                and type(chunk["bytes"]) is int and 0 < chunk["bytes"] <= MAX_CHUNK_BYTES
                and is_hex(chunk["sha256"], 64) and is_hex(chunk["git_blob"], 40),
                "Original evidence chunk is missing, reordered, overlapping or out of bounds")
        offset += chunk["bytes"]
        require(offset <= item["bytes"], "Original evidence chunks exceed the declared archive")
    require(offset == item["bytes"], "Original evidence chunks do not cover the complete archive")
    return item


def validate_record(record):
    require(isinstance(record, dict) and set(record) == {"schema", "scope", "archives"}
            and record["schema"] == "pubpres-mainline-original-local-evidence-v2"
            and isinstance(record["scope"], str) and record["scope"].strip(),
            "Unknown original evidence transport registration")
    archives = record["archives"]
    require(isinstance(archives, list) and len(archives) == len(ROLES),
            "Incomplete original evidence archive population")
    for item in archives:
        validate_item(item)
    require([item["role"] for item in archives] == ROLES
            and len({item["filename"] for item in archives}) == len(ROLES)
            and sum(len(item["chunks"]) for item in archives) == 25,
            "Registered original archive roles, destinations or 25-chunk population differ")
    return record


def decode_chunk(chunk, blob):
    require(isinstance(blob, dict) and blob.get("sha") == chunk["git_blob"]
            and blob.get("encoding") == "base64" and type(blob.get("size")) is int
            and blob["size"] == chunk["bytes"] and isinstance(blob.get("content"), str)
            and len(blob["content"]) <= MAX_API_BYTES, "Original evidence chunk API identity differs")
    raw = base64.b64decode("".join(blob["content"].split()), validate=True)
    require(len(raw) == chunk["bytes"] and hashlib.sha256(raw).hexdigest() == chunk["sha256"]
            and git_blob_sha(raw) == chunk["git_blob"], "Original evidence chunk byte custody failed")
    return raw


def assemble(item, fetch_blob):
    validate_item(item)
    raw = b"".join(decode_chunk(chunk, fetch_blob(chunk["git_blob"])) for chunk in item["chunks"])
    require(len(raw) == item["bytes"] and hashlib.sha256(raw).hexdigest() == item["sha256"]
            and git_blob_sha(raw) == item["assembled_git_blob"],
            "Reassembled original archive byte custody failed")
    return raw


def validate_archive(raw):
    """Validate bounded gzip/tar data without extracting or rewriting members."""
    require(0 < len(raw) < MAX_ARCHIVE_BYTES, "Original archive exceeds compressed size bound")
    try:
        with gzip.GzipFile(fileobj=io.BytesIO(raw), mode="rb") as compressed:
            expanded = compressed.read(MAX_EXPANDED_BYTES + 1)
        require(len(expanded) <= MAX_EXPANDED_BYTES, "Original archive exceeds gzip expansion bound")
        with tarfile.open(fileobj=io.BytesIO(expanded), mode="r:") as archive:
            names = set()
            total = 0
            for member in archive:
                require(len(names) + 1 < MAX_MEMBERS, "Original archive exceeds member-count bound")
                path = PurePosixPath(member.name)
                require(member.name and not path.is_absolute() and ".." not in path.parts
                        and "\\" not in member.name and not re.match(r"^[A-Za-z]:", member.name),
                        "Unsafe original archive member path")
                name = path.as_posix()
                require(name not in names and (member.isfile() or member.isdir()),
                        "Duplicate or non-regular original archive member")
                require(not any(word in member.name.lower() for word in ("xauthority", ".ssh", "credential")),
                        "Original archive contains an excluded private support file")
                require(member.size >= 0 and member.offset_data + member.size <= len(expanded),
                        "Truncated original archive member")
                total += member.size
                require(total < MAX_CONTENT_BYTES, "Original archive exceeds member-content bound")
                names.add(name)
        return {"members": len(names), "content_bytes": total, "expanded_bytes": len(expanded)}
    except (OSError, EOFError, tarfile.TarError, zlib.error) as error:
        raise ValueError("Invalid original gzip/tar archive: " + str(error)) from error


def read_blob(sha):
    require(is_hex(sha, 40), "Invalid original Git object identity")
    request = urllib.request.Request("https://api.github.com/repos/techrote/cybersand/git/blobs/" + sha,
        headers={"Authorization": "Bearer " + os.environ["GITHUB_TOKEN"], "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(request, timeout=90) as response:
        raw = response.read(MAX_API_BYTES + 1)
    require(len(raw) <= MAX_API_BYTES, "Original chunk API response exceeds its byte bound")
    return json.loads(raw)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    campaign_request.validate()
    manifest = Path(__file__).with_name("local_evidence.json").read_bytes()
    record = validate_record(json.loads(manifest))
    args.output.mkdir(parents=True, exist_ok=False)
    results = []
    for item in record["archives"]:
        raw = assemble(item, read_blob)
        inspected = validate_archive(raw)
        (args.output / item["filename"]).write_bytes(raw)
        results.append({"role": item["role"], "filename": item["filename"], "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest(), "assembled_git_blob": git_blob_sha(raw),
            "chunks": len(item["chunks"]), "archive": inspected})
    (args.output / "ORIGINAL-LOCAL-EVIDENCE.json").write_bytes(manifest)
    proof = {"schema": "pubpres-mainline-original-evidence-reassembly-v1",
        "source_commit": os.environ.get("GITHUB_SHA"), "manifest_sha256": hashlib.sha256(manifest).hexdigest(),
        "archives": results, "sha256_verified": True, "canonical_git_objects_verified": True,
        "scope": record["scope"]}
    (args.output / "REASSEMBLY.json").write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(proof))


if __name__ == "__main__":
    main()
