"""Read-only source and owner-guide review of the exact d503 delivery.

This produces derived identity/status records only. It does not export or
aggregate runtime logs, prompts, journals, profiles, or credentials.
"""
import hashlib
import json
import pathlib
import posixpath
import re
import subprocess
import urllib.parse
import zipfile

ROOT = pathlib.Path('/tmp/art-d503-windows-custody')
REPO = pathlib.Path('/tmp/art-collaborative-002-source-v2')
SOURCE = 'd503d824aac4128968f7dfba5dccd540c3c07b59'
TREE = '464c60288d5461d61578b000ae68ac029cffb5bd'
PREFIX = 'art-workbench-collaborative-002-windows/'
GUIDE = 'docs/operations/art-workbench-collaborative-evaluation.md'
BRIEFS = 'godot/data/art_collaborative_briefs.json'


def sha(value):
    return hashlib.sha256(value).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=REPO)


def write(name, value):
    (ROOT / name).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


assert git('rev-parse', SOURCE + '^{tree}').decode().strip() == TREE
tracked = {}
for item in git('ls-tree', '-rz', SOURCE).split(b'\0'):
    if not item:
        continue
    info, path = item.split(b'\t', 1)
    mode, kind, oid = info.decode().split(' ')
    assert kind == 'blob'
    tracked[path.decode()] = oid

with zipfile.ZipFile(ROOT / 'portable-d503.zip') as package:
    manifest = json.loads(package.read(PREFIX + 'candidate-manifest.json'))
    assert manifest['source_commit'] == SOURCE and manifest['source_tree'] == TREE
    files = manifest['files_sha256']
    comparison = {'source': SOURCE, 'source_tree': TREE, 'canonical_matches': [],
                  'materialized_lfs_matches': [], 'materialized_lfs_identity': {},
                  'generated_or_external': [], 'mismatches': []}
    for path in sorted(files):
        actual = package.read(PREFIX + path)
        assert sha(actual) == files[path]
        if path not in tracked:
            comparison['generated_or_external'].append(path)
            continue
        committed = git('cat-file', 'blob', tracked[path])
        if actual == committed:
            comparison['canonical_matches'].append(path)
            continue
        pointer = re.fullmatch(rb'version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n', committed)
        if pointer and sha(actual) == pointer[1].decode() and len(actual) == int(pointer[2]):
            comparison['materialized_lfs_matches'].append(path)
            comparison['materialized_lfs_identity'][path] = {'sha256': sha(actual), 'bytes': len(actual)}
        else:
            comparison['mismatches'].append({'path': path, 'source_sha256': sha(committed), 'payload_sha256': sha(actual)})
    assert not comparison['mismatches'], comparison['mismatches']
    assert len(comparison['canonical_matches']) == 1092
    assert len(comparison['materialized_lfs_matches']) == 2
    provider_sources = {
        'delivery': SOURCE,
        'corrected_delivery_first_attempt': '3a0ec3659f23d8e997e6721aa754d5a8ebe48512',
        'qualified_prior_application': 'bcc92927ce3894a16d5544923cfbf7b1d0339fda',
        'linux_native_handoff_probe': '04ca36243614e89c44aa0e673b725a30d8b8cd7b',
    }
    provider_files = ['art_provider.gd', 'art_response_preparation.gd', 'art_redaction.gd',
                      'art_traffic_archive.gd', 'art_proposal_transport.gd']
    closure = {}
    for name in provider_files:
        path = 'godot/scripts/' + name
        hashes = {label: sha(git('show', commit + ':' + path)) for label, commit in provider_sources.items()}
        hashes['delivered_payload'] = sha(package.read(PREFIX + path))
        assert len(set(hashes.values())) == 1
        closure[path] = hashes
    write('independent-provider-closure-review.json', {
        'sources': provider_sources, 'passed': True, 'files_sha256': closure,
        'exact_five_file_closure_equal': True,
        'scope': 'Exact Git and final payload byte identity. The independently recorded 04ca 115-check result remains Linux headless actual-native host-mount evidence over unchanged Architecture 17c; no additional runtime execution, production factory mount or combined Windows qualification is claimed.',
        'architecture_source': '17c6b5b35049b7b2541c2deeea23c02fd1e2fc5d',
    })
    generated_source_copies = {}
    for path in comparison['generated_or_external']:
        if path.startswith('godot/authoring/worldgen/'):
            source_path = path.replace('godot/authoring/worldgen/', 'examples/worldgen/', 1)
            assert package.read(PREFIX + path) == git('show', SOURCE + ':' + source_path)
            generated_source_copies[path] = {'source_path': source_path, 'sha256': files[path]}
    comparison['generated_source_copies_verified'] = generated_source_copies
    write('source-payload-comparison.json', comparison)

    guide = package.read(PREFIX + GUIDE)
    assert guide == git('show', SOURCE + ':' + GUIDE)
    assert manifest['principal_guide'] == GUIDE
    # The top-level README is another complete copy of this owner guide.
    readme = package.read(PREFIX + 'READ-ME.md')
    assert readme.replace(b'\r\n', b'\n') == guide.replace(b'\r\n', b'\n')
    text = guide.decode('utf-8')
    stripped = re.sub(r'(?ms)^(`{3,}|~{3,})[^\n]*\n.*?^\1[ \t]*(?:\n|$)', '', text)
    stripped = re.sub(r'`+[^`]*`+', '', stripped)
    links = re.findall(r'!?\[[^\]]*\]\(([^)\n]+)\)', stripped)
    links += re.findall(r'(?m)^ {0,3}\[[^\]\n]+\]:\s*(\S+)', stripped)
    local_links, online_links = [], []
    for destination in links:
        target = urllib.parse.urlsplit(destination.strip('<> '))
        if target.scheme:
            assert target.scheme == 'https' and target.netloc == 'github.com'
            online_links.append(destination)
            continue
        assert not target.netloc and '\\' not in destination
        if not target.path:
            continue
        path = urllib.parse.unquote(target.path)
        relative = posixpath.normpath(posixpath.join(posixpath.dirname(GUIDE), path))
        assert not path.startswith('/') and not relative.startswith('../') and relative != '..'
        assert relative in files and sha(package.read(PREFIX + relative)) == files[relative]
        local_links.append(relative)
    brief_raw = package.read(PREFIX + BRIEFS)
    assert brief_raw == git('show', SOURCE + ':' + BRIEFS)
    brief = json.loads(brief_raw)
    assert brief['schema'] == 'cybersand-art-creative-briefs-v1' and brief['count'] == 24
    ids = [item['id'] for item in brief['briefs']]
    expected = [f'B{i:02}' for i in range(1, 13)] + [f'H{i:02}' for i in range(1, 5)] + [f'C{i:02}' for i in range(1, 5)] + [f'R{i:02}' for i in range(1, 5)]
    assert set(ids) == set(expected) and len(ids) == len(set(ids)) == 24
    assert all(isinstance(item['prompt'], str) and item['prompt'].strip() for item in brief['briefs'])
    necessary = {
        'offline_24_brief_protocol': '## Run a complete 24-brief owner-model evaluation',
        'exact_bundled_brief_path': BRIEFS,
        'pause_before_native_operations': 'Pause simulation',
        'finite_direct_default': '**Turns 1** and **Run s 0**',
        'numeric_loopback': '**127.0.0.1**',
        'skip_retires_residual': 'retires the residual proposal and preview',
        'fresh_comparison_session': 'Start a fresh game session for each comparison arm',
        'explicit_no_startup_request': 'sends no model request',
        'original_physical_pending': 'physical Windows/NVIDIA no-listener report remains an owner',
        'fixture_model_distinction': 'does not count as a real-model result',
        'unsupported_native_modules': 'not executable through this primitive proposal schema',
    }
    assert all(token in text for token in necessary.values())
    review = {'source_commit': SOURCE, 'source_tree': TREE, 'passed': True,
              'scope': 'Independent exact delivered guide/README/source/brief identities and ordinary Markdown link closure; online background is optional and not fetched by this check.',
              'guide_sha256': sha(guide), 'guide_bytes': len(guide),
              'readme_sha256': sha(readme), 'readme_bytes': len(readme),
              'readme_equals_complete_guide_after_exact_lf_normalization': True,
              'local_markdown_destinations': local_links, 'optional_online_destinations': online_links,
              'absent_local_destinations': [], 'bundled_brief_sha256': sha(brief_raw),
              'brief_ids': ids, 'complete_prompt_count': len(ids),
              'instruction_checks': {key: True for key in necessary}}
    write('independent-guide-review.json', review)
    print(json.dumps({'source_files': len(comparison['canonical_matches']),
                      'lfs_materializations': len(comparison['materialized_lfs_matches']),
                      'generated_source_copies': len(generated_source_copies),
                      'guide': review}, indent=2))
