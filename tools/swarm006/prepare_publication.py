#!/usr/bin/env python3
"""Prepare exact Git objects for connector-based Draft/HOLD source publication.

This helper performs no network requests and changes no Git refs. GitHub's
create_commit tool supplies its own author/timestamp, so the returned remote
commit is a new source identifier even when its tree is byte-for-byte exact.
Fetch that commit and qualify the remote SHA before describing CI as exact-HEAD.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess

BASELINES = {
    'native': 'c178feeb39899fd155b7deb9d5bde3f50ee28548',
    'workbench': '8ec6d3c62197f3ef4088d79e4aa2910f5eaa36f7',
}
MODES = {'100644': 'blob', '100755': 'blob', '120000': 'blob', '160000': 'commit'}
SHA = re.compile(r'[0-9a-f]{40}\Z')


def git(root: Path, *arguments: str) -> bytes:
    return subprocess.check_output(['git', *arguments], cwd=root, timeout=60)


def commit(root: Path, value: str) -> str:
    result = git(root, 'rev-parse', '--verify', value+'^{commit}').decode().strip()
    if not SHA.fullmatch(result): raise ValueError('Expected one full Git SHA')
    return result


def changes(root: Path, first_parent: str, target: str) -> list[dict]:
    raw = git(root, 'diff-tree', '-r', '--no-commit-id', '--raw', '--no-abbrev', '--no-renames', '-z', first_parent, target)
    fields = raw.split(b'\0')
    if fields[-1] != b'' or (len(fields)-1) % 2:
        raise ValueError('Unexpected bounded diff-tree format')
    result = []
    for index in range(0, len(fields)-1, 2):
        header, name = fields[index].decode('ascii'), fields[index+1].decode('utf-8')
        before_mode, mode, before_sha, sha, status = header.removeprefix(':').split(' ')
        if status not in ('A', 'M', 'D', 'T') or name.startswith('/') or any(part in ('', '.', '..', '.git') for part in name.split('/')):
            raise ValueError('Unsafe or unsupported source change: '+name)
        selected_mode = before_mode if status == 'D' else mode
        if selected_mode not in MODES:
            raise ValueError('Unsupported Git file mode: '+selected_mode)
        result.append({'path': name, 'mode': selected_mode, 'type': MODES[selected_mode],
                       'sha': None if status == 'D' else sha, 'previous_sha': before_sha, 'change': status})
    if not result or len(result) > 1024:
        raise ValueError('Publication needs one to1024 changed paths')
    return result


def prepare(root: Path, lane: str, first_parent: str, target: str, output: Path,
            additional_parents: list[str], expected_remote_head: str | None, message: str | None) -> dict:
    root = root.resolve();output = output.resolve()
    if output.exists(): raise ValueError('Publication directory must be fresh')
    first_parent, target = commit(root, first_parent), commit(root, target)
    additional_parents = [commit(root, parent) for parent in additional_parents]
    if expected_remote_head is not None: expected_remote_head = commit(root, expected_remote_head)
    if expected_remote_head is not None and expected_remote_head != first_parent:
        raise ValueError('An existing SWARM006 branch must advance from its exact leased head as first parent')
    baseline = BASELINES[lane]
    subprocess.run(['git', 'merge-base', '--is-ancestor', baseline, first_parent], cwd=root, check=True, timeout=60)
    subprocess.run(['git', 'merge-base', '--is-ancestor', first_parent, target], cwd=root, check=True, timeout=60)
    for parent in additional_parents:
        subprocess.run(['git', 'merge-base', '--is-ancestor', parent, target], cwd=root, check=True, timeout=60)
    if lane == 'workbench' and len(additional_parents) != 1:
        raise ValueError('Workbench publication must retain the exact one frozen remote native parent')
    if lane == 'native' and additional_parents:
        raise ValueError('Native publication is directly stacked on its verified native lineage')
    if git(root, 'status', '--porcelain', '--untracked-files=normal').strip():
        raise ValueError('Commit all intended source before preparing publication; worktree must be clean')
    entries = changes(root, first_parent, target)
    blobs = {}
    total = 0
    for entry in entries:
        if entry['type'] != 'blob' or entry['sha'] is None or entry['sha'] in blobs: continue
        sha = entry['sha'];content = git(root, 'cat-file', 'blob', sha)
        if hashlib.sha1(b'blob '+str(len(content)).encode()+b'\0'+content).hexdigest() != sha:
            raise ValueError('Local Git blob identity changed')
        total += len(content)
        if len(content) > 8*1024*1024 or total > 64*1024*1024:
            raise ValueError('Changed source exceeds the explicit publication capacity')
        blobs[sha] = {'sha': sha, 'bytes': len(content), 'sha256': hashlib.sha256(content).hexdigest(),
                      'base64': base64.b64encode(content).decode('ascii')}
    output.mkdir(parents=True)
    for sha, record in blobs.items():
        path = output/'blobs'/(sha+'.base64');path.parent.mkdir(exist_ok=True)
        encoded = record.pop('base64');path.write_text(encoded, encoding='ascii')
        record['base64_file'] = str(path);record['base64_chars'] = len(encoded)
    manifest = {
        'schema': 1, 'programme': 'GENTEK-SWARM-006', 'draft_hold': True,
        'repository_full_name': 'techrote/cybersand', 'lane': lane,
        'branch': f'experiment/gentek-swarm-006-{lane}-recovery',
        'verified_baseline': baseline, 'local_target_commit': target,
        'expected_tree_sha': git(root, 'rev-parse', target+'^{tree}').decode().strip(),
        'first_parent_sha': first_parent,
        'first_parent_tree_sha': git(root, 'rev-parse', first_parent+'^{tree}').decode().strip(),
        'additional_parent_shas': additional_parents, 'expected_remote_head': expected_remote_head,
        'message': message or git(root, 'show', '-s', '--format=%B', target).decode().rstrip('\n'),
        'source_bytes': total, 'changed_paths': entries, 'blobs': list(blobs.values()),
        'publication_policy': 'Create new branch at its verified first parent, then fast-forward with an expected-SHA lease. No main or existing historical branch mutation.',
        'qualification_policy': 'GitHub returns a new commit SHA. Fetch it, verify the exact expected tree and ordered parents, and qualify that remote SHA.',
    }
    (output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--lane', choices=BASELINES, required=True)
    parser.add_argument('--base', required=True, help='Verified first parent; nativec178 or Workbench8ec6 lineage')
    parser.add_argument('--target', default='HEAD')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--additional-parent', action='append', default=[])
    parser.add_argument('--expected-remote-head', help='Only for a previously created SWARM006 branch; must match its live head')
    parser.add_argument('--message')
    args = parser.parse_args()
    result = prepare(args.root, args.lane, args.base, args.target, args.output,
                     args.additional_parent, args.expected_remote_head, args.message)
    print(json.dumps({key: result[key] for key in ('local_target_commit', 'expected_tree_sha', 'first_parent_sha',
                                                 'additional_parent_shas', 'branch', 'source_bytes')}))


if __name__ == '__main__': main()
