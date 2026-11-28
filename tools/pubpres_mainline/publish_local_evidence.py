#!/usr/bin/env python3
"""Publish immutable local raw evidence as an artifact, never as repository files."""
import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import tarfile
import urllib.request
import campaign_request
from common import require


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    campaign_request.validate()
    record = json.loads(Path(__file__).with_name('local_evidence.json').read_bytes())
    require(record['schema'] == 'pubpres-mainline-original-local-evidence-v1', "Original local evidence custody failed")
    require([item['role'] for item in record['archives']] == ['spawn', 'presentation', 'presentation-followup'], "Original local evidence custody failed")
    args.output.mkdir(parents=True, exist_ok=False)
    for item in record['archives']:
        require(0 < item['bytes'] < 2 * 1024**2 and Path(item['filename']).name == item['filename'], "Original local evidence custody failed")
        request = urllib.request.Request('https://api.github.com/repos/techrote/cybersand/git/blobs/' + item['git_blob'],
            headers={'Authorization': 'Bearer ' + os.environ['GITHUB_TOKEN'], 'Accept': 'application/vnd.github+json'})
        with urllib.request.urlopen(request, timeout=90) as response:
            blob = json.load(response)
        require(blob['sha'] == item['git_blob'] and blob['encoding'] == 'base64', "Original local evidence custody failed")
        raw = base64.b64decode(blob['content'])
        require(len(raw) == item['bytes'] and hashlib.sha256(raw).hexdigest() == item['sha256'], "Original local evidence custody failed")
        require(hashlib.sha1(('blob ' + str(len(raw)) + '\0').encode() + raw).hexdigest() == item['git_blob'], "Original local evidence custody failed")
        with tarfile.open(fileobj=io.BytesIO(raw), mode='r:gz') as archive:
            members = archive.getmembers()
            require(len(members) < 1000 and sum(member.size for member in members) < 64 * 1024**2, "Original local evidence custody failed")
            names = set()
            for member in members:
                path = PurePosixPath(member.name)
                require(not path.is_absolute() and '..' not in path.parts and '\\' not in member.name, "Original local evidence custody failed")
                require(member.name not in names and (member.isfile() or member.isdir()), "Original local evidence custody failed")
                require(not any(word in member.name.lower() for word in ['xauthority', '.ssh', 'credential']), "Original local evidence custody failed")
                names.add(member.name)
        (args.output / item['filename']).write_bytes(raw)
    (args.output / 'ORIGINAL-LOCAL-EVIDENCE.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'archives': len(record['archives']), 'sha256_verified': True,
                      'scope': record['scope']}))


if __name__ == '__main__':
    main()
