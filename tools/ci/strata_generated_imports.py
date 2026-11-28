#!/usr/bin/env python3
"""Recognize six exact Godot 4.7 generated Strata texture descriptors.

These files are generated beside committed PNG artwork, never archived as source.
Only their random resource UID and line endings may vary. The entire remaining
descriptor and its committed source image are pinned; arbitrary .import files,
changed settings, redirected resources and changed artwork remain source drift.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import re
import subprocess

# path: (committed PNG SHA-256, generated descriptor SHA-256 without its UID)
DESCRIPTORS = {
    "godot/data/strata2/imports/alpha-cutout.png.import": (
        "452832a18d4b09185ecdc1220d1d0c93e8f447211463fec8c6e6705d07c3627b",
        "6074d60dcef7aa0fdb516ea5c066f6e9461bb91050df914ff6a8ec6f8bea84ca"),
    "godot/data/strata2/imports/left-half-mask.png.import": (
        "49dbf42d8cd9063f8c0048c09f72339a37ad350d8e5e97111571266f9747e8c9",
        "dd1701e17ec289d6d48eaf9f5eb6c954b77d4a8a360d62f8abddcab984f3bcb0"),
    "godot/data/strata2/reference-imports/asteroid-service-gallery.mask.png.import": (
        "e2de46497c90616aa6fda207ca6b16b5fac805682e446d34d3549bb5db239605",
        "7f36b8d083d197f0c0b763e2e320c7ad9e349fa9039c2f00df1bfa7e3ceac9b3"),
    "godot/data/strata2/reference-imports/asteroid-service-gallery.png.import": (
        "3c4236e732a9ffa17219ae83072722fdf222ead42c312aac3ba37ff2f21015f9",
        "875044c9cdf1f43588ea2370f37581cabdf70a0b8f3a295057f3cdde60026723"),
    "godot/data/strata2/reference-imports/rocket-hangar-frame.mask.png.import": (
        "8c61a3d8ee71f52f1b5a5365364880119321199c990a0b9f713c74f78f8c2e8a",
        "bba27421022ad864094d9eac12556c5927dddc098751ae4d05943cad68b2fd4d"),
    "godot/data/strata2/reference-imports/rocket-hangar-frame.png.import": (
        "7ae95ab333cf478972941a2914c63fa93f3cc1b8dc63bf1cc228b4e23cc3c960",
        "7dd63be9ec02eb55c40d329ce8bb43d1f84488429fc674157bd40ebd389fc805"),
}


def is_generated_strata_import(root: Path, relative: str) -> bool:
    expected = DESCRIPTORS.get(relative)
    if expected is None:
        return False
    root = root.resolve()
    descriptor = root / relative
    source = descriptor.with_suffix("")
    try:
        if any(not path.is_file() or path.resolve() != path for path in (descriptor, source)):
            return False
        if not 1 <= descriptor.stat().st_size <= 4096:
            return False
        data = descriptor.read_bytes().replace(b"\r\n", b"\n")
        normalized, count = re.subn(rb'^uid="uid://[a-z0-9]{1,20}"\n', b"", data, flags=re.MULTILINE)
        if count != 1 or hashlib.sha256(normalized).hexdigest() != expected[1]:
            return False
        if hashlib.sha256(source.read_bytes()).hexdigest() != expected[0]:
            return False
        committed = subprocess.check_output(
            ["git", "cat-file", "blob", "HEAD:" + relative.removesuffix(".import")],
            cwd=root, stderr=subprocess.DEVNULL, timeout=30)
        return hashlib.sha256(committed).hexdigest() == expected[0]
    except (OSError, subprocess.SubprocessError):
        return False
