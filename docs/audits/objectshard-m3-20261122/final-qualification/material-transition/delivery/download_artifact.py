"""Download one observed Actions artifact, authenticate and extract safely."""
from pathlib import Path, PurePosixPath
import datetime
import hashlib
import json
import os
import shutil
import stat
import sys
import urllib.request
import zipfile

request = json.load(sys.stdin)
metadata = request["metadata"]
out = Path(request["directory"])
out.mkdir(parents=True, exist_ok=True)
archive = out / request["file_name"]
assert request.get('resume_local') or not archive.exists(), "Refuse to overwrite retained archive"
assert metadata["workflow_run"]["head_sha"] == request["source_commit"]
assert metadata["workflow_run"]["id"] == 45003383402
assert not metadata["expired"]
digest = hashlib.sha256()
if request.get('resume_local'):
    with archive.open('rb') as source:
        while block := source.read(1024 * 1024):
            digest.update(block)
else:
    with urllib.request.urlopen(request["download_url"], timeout=120) as response, archive.open("xb") as dest:
        while block := response.read(1024 * 1024):
            dest.write(block)
            digest.update(block)
assert archive.stat().st_size == metadata["size_in_bytes"], "Archive size differs"
assert "sha256:" + digest.hexdigest() == metadata["digest"], "Archive digest differs"
extracted = out / str(metadata["id"])
if request.get('resume_local') and extracted.exists():
    # The failed extraction contains only reproducible copies of this authenticated ZIP.
    assert extracted.resolve().parent == out.resolve()
    shutil.rmtree(extracted)
extracted.mkdir(exist_ok=False)
members = []
seen = set()
with zipfile.ZipFile(archive) as zipped:
    for member in zipped.infolist():
        path = PurePosixPath(member.filename)
        assert path.parts and not path.is_absolute() and ".." not in path.parts
        assert "\\" not in member.filename and ":" not in member.filename
        assert not stat.S_ISLNK(member.external_attr >> 16)
        assert str(path).casefold() not in seen, "Duplicate/colliding ZIP member"
        seen.add(str(path).casefold())
        target = extracted.joinpath(*path.parts)
        if member.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        omit = request.get('omit_native_intermediates') and path.parts[0]=='native' and (
            'objects' in path.parts or (len(path.parts)==3 and path.name.startswith('test_object_shard_')))
        if omit:
            with zipped.open(member) as src:
                member_hash=hashlib.file_digest(src,'sha256').hexdigest()
            members.append({'path':str(path),'bytes':member.file_size,'sha256':member_hash,
                            'extracted':False,'retained_in_original_archive':True})
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with zipped.open(member) as src, target.open("xb") as dst:
            shutil.copyfileobj(src, dst)
        members.append({"path":str(path), "bytes":target.stat().st_size,"extracted":True,
                        "sha256":hashlib.file_digest(target.open("rb"), "sha256").hexdigest()})
ledger = {
    "schema":"objectshard-material-transition-artifact-custody-v1",
    "retrieved_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "source_commit":request["source_commit"],
    "artifact":metadata, "file_id":request["file_id"],
    "archive_path":str(archive), "archive_bytes":archive.stat().st_size,
    "archive_sha256":digest.hexdigest(), "extracted_path":str(extracted),
    "members":members,
    "extraction_scope":"Compiler objects and standalone native test executables retained and hashed inside the original archive to avoid duplicate scratch storage; all source, logs, receipts, actual GDExtension, traces and rendered outputs extracted." if request.get('omit_native_intermediates') else "complete",
}
ledger_path = out / (str(metadata["id"]) + "-custody.json")
ledger_path.write_text(json.dumps(ledger, indent=2) + "\n")
print(json.dumps({"status":"verified", "ledger":str(ledger_path),
                 "archive":str(archive), "extracted":str(extracted), "members":len(members)}))
