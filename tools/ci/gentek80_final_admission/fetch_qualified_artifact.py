#!/usr/bin/env python3
"""Fetch one exact original Actions artifact and verify its immutable ZIP digest."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import urllib.error
import urllib.parse
import urllib.request

from package_retained_gentek80 import extract_pristine, require, sha, write_json


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def api(path: str, *, redirect: bool = False):
    # The token is attached only to this literal API origin, never to a signed
    # cross-origin artifact download URL. Neither token nor signed URL is logged.
    require(path.startswith("/repos/techrote/cybersand/"), "Unexpected repository API path")
    request = urllib.request.Request("https://api.github.com" + path, headers={
        "Authorization": "Bearer " + os.environ["GH_TOKEN"],
        "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "CyberSand-Gentek80-final-admission"})
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=60) as response:
            require(not redirect, "Artifact endpoint did not return an expected signed redirect")
            return json.load(response)
    except urllib.error.HTTPError as error:
        if redirect and error.code in (301, 302, 303, 307, 308):
            location = error.headers.get("Location", "")
            parsed = urllib.parse.urlsplit(location)
            require(parsed.scheme == "https" and bool(parsed.hostname) and
                    parsed.hostname != "api.github.com" and not parsed.username and not parsed.password,
                    "Invalid artifact download redirect")
            return location
        raise RuntimeError("GitHub artifact API request failed with HTTP " + str(error.code)) from None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--role", choices=("linux", "windows", "assets"), required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8"))
    expected = config["artifacts"][args.role]
    artifact_id = str(expected["id"])
    require(artifact_id.isdecimal(), "Expected exact numeric artifact identity")
    metadata = api("/repos/techrote/cybersand/actions/artifacts/" + artifact_id)
    run = api("/repos/techrote/cybersand/actions/runs/" + config["original_run_id"])
    require(str(metadata["id"]) == artifact_id and metadata["name"] == expected["name"] and
            metadata.get("expired") is False and metadata.get("digest") == "sha256:" + expected["sha256"] and
            str(metadata["workflow_run"]["id"]) == config["original_run_id"] and
            metadata["workflow_run"]["head_sha"] == config["built_source"],
            "Original artifact identity or digest differs from the committed admission inputs")
    require(str(run["id"]) == config["original_run_id"] and run["head_sha"] == config["built_source"] and
            str(run["run_attempt"]) == config["original_run_attempt"] and
            run["head_branch"] == "integration/gentek-80-001" and run["event"] == "push",
            "Original qualification run identity differs")
    destination = args.destination.resolve()
    archive = destination.with_suffix(".original-artifact.zip")
    require(not archive.exists() and not destination.exists(), "Artifact destinations must be new")
    archive.parent.mkdir(parents=True, exist_ok=True)
    location = api("/repos/techrote/cybersand/actions/artifacts/" + artifact_id + "/zip", redirect=True)
    try:
        with urllib.request.urlopen(location, timeout=120) as incoming, archive.open("wb") as outgoing:
            shutil.copyfileobj(incoming, outgoing)
    except Exception:
        raise RuntimeError("Original artifact archive download failed; no token or signed URL retained") from None
    require(archive.stat().st_size == metadata["size_in_bytes"], "Original artifact byte count mismatch")
    extract_pristine(archive, destination, expected["sha256"])
    write_json(destination.with_suffix(".download-receipt.json"), {
        "schema": "gentek80-exact-original-artifact-download-v1", "status": "passed",
        "role": args.role, "configuration_sha256": sha(args.config), "metadata": metadata,
        "original_run": {key: run.get(key) for key in
                         ("id", "run_attempt", "head_sha", "head_branch", "event", "status", "conclusion", "html_url")},
        "archive_sha256": sha(archive), "archive_bytes": archive.stat().st_size,
        "destination": str(destination)})
    print(json.dumps({"role": args.role, "artifact_id": artifact_id, "sha256": expected["sha256"], "status": "passed"}))


if __name__ == "__main__":
    main()
