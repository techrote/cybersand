"""Explicitly sealed reader revision; never changes the collected evidence authority."""
import json
import re
from pathlib import Path

VERIFIER_FILES = (
    'readback.py', 'provenance.py', 'world_oracle.py', 'oracle.py',
    'matrix.py', 'storage_oracle.py', 'negative.py', 'overlay.py',
)
PREFIX = 'tools/experiments/mat003_correctness/'
HEX = re.compile(r'[0-9a-f]{64}\Z')


def revision_sources(root, authority, result, path, expected_sha256, digest):
    """Accept only a complete, exact replacement reader set for this frozen archive.

    The old source snapshot is still checked by verify_provenance. A reader
    revision can change only which sealed Python reader bytes run now; it cannot
    change compiler, binaries, cases, source snapshots or original authority.
    """
    path = Path(path)
    if not isinstance(expected_sha256, str) or not HEX.fullmatch(expected_sha256):
        raise ValueError('reader revision seal format')
    if path.is_symlink() or path.stat().st_size > 1024 * 1024:
        raise ValueError('reader revision envelope')
    if digest(path) != expected_sha256:
        raise ValueError('reader revision seal mismatch')
    revision = json.loads(path.read_text(encoding='utf-8'))
    if revision.get('schema') != 1 or revision.get('kind') != 'mat003-readback-revision':
        raise ValueError('reader revision schema')
    if (revision.get('readback_only') is not True or
            revision.get('candidate_processes_allowed') != 0 or
            revision.get('builds_allowed') != 0 or
            revision.get('timing_allowed') is not False):
        raise ValueError('reader revision expands execution scope')
    if revision.get('validation_class') != 'author-validation-pending-independent-review':
        raise ValueError('reader revision acceptance class')
    owner = revision.get('owner_authorization', {})
    if owner.get('authorized') is not True or not isinstance(owner.get('reference'), str) or not owner['reference'].strip():
        raise ValueError('reader revision owner authorization missing')
    for name in ('authority.json', 'result.json', 'inventory.json'):
        if revision.get('evidence_sha256', {}).get(name) != digest(Path(root) / name):
            raise ValueError('reader revision bound to different evidence: ' + name)
    if (revision.get('source_commit') != result.get('source_commit') or
            revision.get('source_tree') != result.get('source_tree')):
        raise ValueError('reader revision changes collected source identity')
    original = {PREFIX + name: authority['source_sha256'][PREFIX + name] for name in VERIFIER_FILES}
    if revision.get('original_verifier_sha256') != original:
        raise ValueError('reader revision changes original source seals')
    revised = revision.get('revised_verifier_sha256', {})
    required = {PREFIX + name for name in (*VERIFIER_FILES, 'verifier_revision.py')}
    if not isinstance(revised, dict) or set(revised) != required:
        raise ValueError('reader revision incomplete/extra source set')
    for relative, seal in revised.items():
        if not isinstance(seal, str) or not HEX.fullmatch(seal):
            raise ValueError('reader revision source seal format')
        source = Path(__file__).parent / relative.removeprefix(PREFIX)
        if source.is_symlink() or digest(source) != seal:
            raise ValueError('reader revision source identity mismatch: ' + relative)
    return revised
