"""Assemble verified original QA artifacts as passive data; execute no payload."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import time
import zipfile

ROOT = Path('/home/agent/goblin002/evidence').resolve()
HERE = ROOT / 'durable-data-archive'
PLAN = HERE / 'plan.json'
OUTPUT = Path('/home/agent/goblin002/deliverables/CyberSand-goblin-campaign-evidence.zip')
MAX_TOTAL = 2 * 1024**3
MAX_REVIEWS = 64
START = time.monotonic()


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def member(name):
    path = PurePosixPath(name)
    if (not isinstance(name, str) or path.is_absolute() or path.as_posix() != name
            or '..' in path.parts or '\\' in name or ':' in name):
        raise ValueError('Unsafe archive member')
    return name


def source(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT):
        raise ValueError('Only retained ordinary evidence files can be sealed')
    return path


def info(name, compressed=False):
    result = zipfile.ZipInfo(member(name), date_time=(2026, 11, 25, 0, 0, 0))
    result.compress_type = zipfile.ZIP_DEFLATED if compressed else zipfile.ZIP_STORED
    result.external_attr = (stat.S_IFREG | 0o644) << 16
    return result


def main():
    if OUTPUT.exists() or OUTPUT.with_suffix('.zip.partial').exists():
        raise ValueError('Refuse to overwrite an existing evidence archive')
    raw_plan = PLAN.read_bytes()
    if len(raw_plan) > 1024 * 1024:
        raise ValueError('Oversized fixed archive plan')
    plan = json.loads(raw_plan)
    if plan.get('pending_inputs') or plan.get('status') != 'ready_for_root_review':
        raise ValueError('Actual evidence and root-approved manifest must be complete before assembly')
    originals = plan['existing_inputs']
    reviews = plan.get('review_inputs', [])
    if not 1 <= len(originals) <= 20 or not 1 <= len(reviews) <= MAX_REVIEWS:
        raise ValueError('Outside finite artifact/review catalogue')
    records, seen, total = [], set(), 0
    for entry, kind in [(row, 'original_github_artifact') for row in originals] + [(row, 'review') for row in reviews]:
        path = source(entry['path']); name = member(entry['member'])
        if name.casefold() in seen or not name.startswith('artifacts/' if kind == 'original_github_artifact' else 'reviews/'):
            raise ValueError('Duplicate or wrongly classified archive member')
        seen.add(name.casefold())
        if kind == 'original_github_artifact':
            if not name.endswith('.zip') or type(entry.get('artifact_id')) is not int or type(entry.get('run_id')) is not int:
                raise ValueError('Original artifact lacks exact immutable workflow identity')
            if re.fullmatch('[0-9a-f]{40}', entry.get('source_commit', '')) is None:
                raise ValueError('Original artifact lacks exact candidate source')
        elif path.stat().st_size > 8 * 1024 * 1024:
            raise ValueError('Review must remain compact')
        if path.stat().st_size != entry['bytes'] or digest(path) != entry['sha256']:
            raise ValueError('Retained input changed: ' + name)
        total += entry['bytes']
        if total > MAX_TOTAL:
            raise ValueError('Evidence archive exceeds finite two-GiB input limit')
        records.append((path, name, {key: value for key, value in entry.items() if key != 'path'}, kind))
    manifest = {'schema': 'cybersand-goblin-durable-evidence-archive-v1',
                'status': 'original_artifacts_and_read_only_reviews',
                'scope': plan['scope'], 'input_plan_sha256': hashlib.sha256(raw_plan).hexdigest(),
                'original_artifacts': [row for _, _, row, kind in records if kind == 'original_github_artifact'],
                'reviews': [row for _, _, row, kind in records if kind == 'review'],
                'compact_review_references': plan.get('compact_reviews', {}),
                'excluded_primary_windows_evaluator': True,
                'new_gameplay_execution': False,
                'classification_rule': 'Original failed, unresolved, partial and completed outcomes are never rewritten. Later independent adjudication and corrected-source results are separately identified.',
                'process_scope': 'Resource receipts describe sampled launched process trees, not global process surveillance or physical NVIDIA acceptance.'}
    manifest_bytes = (json.dumps(manifest, indent=2, sort_keys=True) + '\n').encode()
    lines = ['# CyberSand goblin: original experimental evidence', '',
             'This is a passive evidence collection. It has no launcher and performs no automatic execution.', '',
             'The Windows evaluator is delivered separately. Its exact source and qualification are independent of this archive.', '',
             'Every ZIP under artifacts/ is an unchanged original downloaded GitHub Actions artifact. The index records its exact source, run, artifact identifier, byte size, SHA-256, and original scientific classification.', '',
             'Failures remain failures. An unresolved diagnostic retains its missing precondition. A later repair does not retroactively qualify an earlier attempt. Completed actions and attempted actions are reported separately.', '',
             '## Original artifact catalogue', '',
             '| Artifact | Source | Run | Classification |', '|---|---|---|---|']
    for _, name, row, kind in records:
        if kind == 'original_github_artifact':
            lines.append('| ' + name + ' | ' + row['source_commit'] + ' | ' + str(row['run_id']) + ' | ' + row.get('classification', 'See exact source-bound reports').replace('|', '/') + ' |')
    lines += ['', '## Reading the evidence', '',
              'Start with evidence-index.json and the compact reviews. Then inspect the original raw report, transcript, native acknowledgement, material capture, process receipt, and source archive for the particular conclusion.', '',
              'Coverage counts admitted observed behavior. Material adjacency/edit variety is not a whole-world coverage percentage or proof of a chemical reaction catalogue. A resumed experiment queue starts fresh disposable episodes; it does not restore an asynchronous physical checkpoint.', '',
              'Semantic replay is bound to exact supported source/runtime identities. Equal asynchronous trajectories across platforms are not claimed. Historical oracle-defect reproductions are evidence of test-oracle defects, not production game-engine bugs.', '',
              'Every member digest is independently checked after this outer archive is written. Original artifact ZIPs are stored without recompression; compact metadata may be compressed.']
    readme = ('\n'.join(lines) + '\n').encode()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    partial = OUTPUT.with_suffix('.zip.partial')
    expected = {'evidence-index.json': hashlib.sha256(manifest_bytes).hexdigest(), 'README.md': hashlib.sha256(readme).hexdigest()}
    with zipfile.ZipFile(partial, 'x', allowZip64=True) as archive:
        archive.writestr(info('evidence-index.json', True), manifest_bytes)
        archive.writestr(info('README.md', True), readme)
        for path, name, row, kind in records:
            value = hashlib.sha256()
            with path.open('rb') as source_stream, archive.open(info(name, kind == 'review'), 'w', force_zip64=True) as destination:
                for block in iter(lambda: source_stream.read(1024 * 1024), b''):
                    if time.monotonic() - START > 150:
                        raise ValueError('Bounded archive assembly deadline')
                    value.update(block); destination.write(block)
            if value.hexdigest() != row['sha256']:
                raise ValueError('Input changed while copying: ' + name)
            expected[name] = row['sha256']
    with zipfile.ZipFile(partial) as archive:
        if set(archive.namelist()) != set(expected) or len(archive.namelist()) != len(expected):
            raise ValueError('Final archive member closure differs')
        for name, checksum in expected.items():
            value = hashlib.sha256()
            with archive.open(name) as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    value.update(block)
            if value.hexdigest() != checksum:
                raise ValueError('Final nested artifact digest differs')
    # Both paths share a filesystem. Link publication fails atomically if a
    # different final archive appeared while this one was being assembled.
    os.link(partial, OUTPUT)
    partial.unlink()
    receipt = {'schema': 'cybersand-goblin-durable-evidence-archive-receipt-v1', 'status': 'pass',
               'output': str(OUTPUT), 'bytes': OUTPUT.stat().st_size, 'sha256': digest(OUTPUT),
               'manifest_sha256': hashlib.sha256(manifest_bytes).hexdigest(), 'original_artifact_count': len(originals),
               'review_count': len(reviews), 'member_count': len(expected), 'input_bytes': total,
               'all_original_bytes_preserved': True, 'post_write_member_hashes_verified': True,
               'elapsed_seconds': round(time.monotonic() - START, 3)}
    (HERE / 'evidence-index.json').write_bytes(manifest_bytes)
    (HERE / 'README.md').write_bytes(readme)
    (HERE / 'archive-receipt.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print(json.dumps(receipt, sort_keys=True))


if __name__ == '__main__':
    main()
