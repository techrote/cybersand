"""Independent scalar audit of original M6/M7 catalogue evidence inside a ZIP.

No Godot execution. Receipt counters/revisions and actual whole-plane identities
are checked; TileHost receipt-row hashes are retained, not re-derived without
their original row bytes. The scope is static geometry and custody.
"""
from pathlib import Path, PurePosixPath
import argparse
import base64
import hashlib
import json
import struct
import zipfile


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def plane(raw, extent):
    width, height = extent
    assert type(width) is int and type(height) is int
    assert 0 < width <= 512 and 0 < height <= 512
    assert len(raw) == width * height * 2
    return list(struct.unpack(f'<{width * height}H', raw))


def packed(cells):
    return struct.pack(f'<{len(cells)}H', *cells)


def region(rect, extent):
    assert isinstance(rect, list) and len(rect) == 4
    assert all(type(value) is int for value in rect)
    x, y, width, height = rect
    assert min(x, y) >= 0 and min(width, height) > 0
    assert x + width <= extent[0] and y + height <= extent[1]
    return (yy * extent[0] + xx for yy in range(y, y + height) for xx in range(x, x + width))


def transformed(x, y, width, height, transform):
    if transform == 'identity': return x, y
    if transform == 'mirror_x': return width - 1 - x, y
    if transform == 'mirror_y': return x, height - 1 - y
    if transform == 'rotate_90': return height - 1 - y, x
    if transform == 'rotate_180': return width - 1 - x, height - 1 - y
    if transform == 'rotate_270': return y, width - 1 - x
    raise AssertionError('Unknown orthogonal transform')


def component_count(cells, extent):
    width, height = extent
    unseen = {index for index, value in enumerate(cells) if value != 0}
    count = 0
    while unseen:
        count += 1
        queue = [unseen.pop()]
        while queue:
            index = queue.pop()
            x, y = index % width, index // width
            for neighbor in (index - 1 if x else -1, index + 1 if x + 1 < width else -1,
                             index - width if y else -1, index + width if y + 1 < height else -1):
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    queue.append(neighbor)
    return count


def run(args):
    prefix = args.prefix
    rows = []
    with zipfile.ZipFile(args.package) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names))
        assert len(names) == len({name.casefold() for name in names})

        def read(relative):
            path = PurePosixPath(relative)
            assert not path.is_absolute() and '..' not in path.parts and '\\' not in relative
            raw = archive.read(prefix + relative)
            assert len(raw) <= 16 * 1024 * 1024
            return raw

        report_raw = read('native-catalogue-report.json')
        report = json.loads(report_raw)
        assert report['source_revision'] == args.source and report['passed'] is True and report['failures'] == []
        assert report['checks'] > 0 and report['model_calls'] == 0
        assert report['native_active_core_capacity'] == 1024 and report['development_core_capacity_override'] == 0
        observations = report['observations']
        assert len(observations) == 100
        summaries = {row['id']: row for row in report['modules']}
        assert len(summaries) == 40
        library_raw = read('curated-library-v2.json')
        library = json.loads(library_raw)
        modules = {module['id']: module for module in library['modules']}
        assert len(modules) == 40 and modules.keys() == summaries.keys()
        geometry, shapes = {}, set()
        for identity, module in modules.items():
            assert 'native_readback_verified' not in module
            assert json.loads(read('modules/' + identity + '.json')) == module
            assert summaries[identity]['content_sha256'] == module['content_sha256']
            assert summaries[identity]['native_readback_verified'] is True
            raw = base64.b64decode(module['geometry']['cells_base64'], validate=True)
            assert sha(raw) == module['geometry']['sha256']
            assert read('planes/' + identity + '.u16le') == raw
            cells = plane(raw, module['extent'])
            geometry[identity] = cells
            key = tuple(module['extent']), raw
            assert key not in shapes
            shapes.add(key)
            assert component_count(cells, module['extent']) == 1
            for clearance in module['clearances']:
                assert all(cells[index] == 0 for index in region(clearance, module['extent']))
            if module['format'] == 'cybersand-native-module-v2':
                for connector in module['attachments']:
                    ax, ay = connector['point']; bx, by = connector.get('end', connector['point'])
                    assert ax == bx or ay == by
                    facing = connector['facing']
                    assert sum(abs(value) for value in facing) == 1
                    for y in range(min(ay, by), max(ay, by) + 1):
                        for x in range(min(ax, bx), max(ax, bx) + 1):
                            assert cells[y * module['extent'][0] + x] != 0
                            nx, ny = x + facing[0], y + facing[1]
                            if 0 <= nx < module['extent'][0] and 0 <= ny < module['extent'][1]:
                                assert cells[ny * module['extent'][0] + nx] == 0

        seen = set()
        for observation in observations:
            identity, phase, transform = observation['id'], observation['phase'], observation['transform']
            key = identity, phase, transform
            assert key not in seen
            seen.add(key)
            assert observation['source_revision'] == args.source and observation['native_binary_sha256'] == args.native
            assert observation['status'] == 'completed'
            raw_record = read(observation['record_path'])
            assert sha(raw_record) == observation['record_sha256']
            record = json.loads(raw_record)
            assert record['state'] == 'completed' and record['attempt_id'] == observation['attempt_id']
            config = record['config']; extent = config['extent']; width, height = extent
            before_raw = base64.b64decode(record['source_materials_base64'], validate=True)
            after_raw = base64.b64decode(record['material_cells_base64'], validate=True)
            before, after = plane(before_raw, extent), plane(after_raw, extent)
            provenance = record['provenance']
            assert provenance['source_revision'] == args.source and provenance['native_binary_sha256'] == args.native
            assert sha(before_raw) == provenance['source_material_sha256'] == observation['source_sha256']
            assert sha(after_raw) == record['material_sha256'] == provenance['material_sha256'] == observation['material_sha256']
            projected = before.copy()
            for operation in config['operations']:
                assert operation['shape'] == 'rectangle'
                box = [operation['x0'], operation['y0'], operation['x1'] - operation['x0'] + 1,
                       operation['y1'] - operation['y0'] + 1]
                material = operation['material']
                for index in region(box, extent):
                    assert projected[index] in (0, 58, material)
                    projected[index] = material
            assert projected == after
            acknowledged = before.copy()
            for x, y, rw, rh, material in record['accepted_edits']:
                for index in region([x, y, rw, rh], extent): acknowledged[index] = material
            assert acknowledged == after
            checked = changed = excluded = 0
            receipts = record['receipts']; assert receipts
            previous = receipts[0]['before_source']['revision']
            generation = receipts[0]['before_source']['generation']
            for receipt in receipts:
                assert receipt['backend'] == 'CyberNativeCellWorld' and receipt['status'] == 'completed'
                for counter in ('requested', 'checked', 'changed', 'unchanged', 'confirmed', 'excluded', 'refused'):
                    assert type(receipt[counter]) is int and 0 <= receipt[counter] <= 4096
                assert receipt['requested'] == receipt['checked']
                assert receipt['checked'] == sum(receipt[name] for name in ('changed', 'unchanged', 'excluded', 'refused'))
                assert receipt['confirmed'] == receipt['changed'] + receipt['unchanged']
                assert receipt['refused'] == 0
                assert receipt['before_source']['revision'] == previous
                assert receipt['generation'] == receipt['before_source']['generation'] == generation
                assert receipt['revision'] == previous + receipt['changed']
                previous = receipt['revision']
                checked += receipt['checked']; changed += receipt['changed']; excluded += receipt['excluded']
            assert sum(a != b for a, b in zip(before, after)) <= changed
            assert checked <= config['budget_cells']
            full = [0] * (512 * 512)
            for y in range(height): full[y * 512:y * 512 + width] = after[y * width:(y + 1) * width]
            capture = record['metrics']['native_capture']
            assert capture['byte_count'] == 512 * 512 * 2 and capture['sha256'] == sha(packed(full))
            assert record['metrics']['outside_unchanged'] is True
            module = modules[identity]; mw, mh = module['extent']
            if phase == 'source':
                assert transform == 'identity' and all(value == 0 for value in before)
                harvest = module['provenance']['harvest']
                assert harvest['source_extent'] == extent and harvest['source_plane_sha256'] == sha(after_raw)
                assert [after[index] for index in region(harvest['source_region'], extent)] == geometry[identity]
                assert module['provenance']['attempt_id'] == observation['attempt_id']
            else:
                assert phase == 'replay' and extent == [128, 128] and transform in module['allowed_transforms']
                oracle = [0] * (128 * 128)
                for index in region([2, 2, 3, 3], extent): oracle[index] = 13
                assert before == oracle
                for y in range(mh):
                    for x in range(mw):
                        value = geometry[identity][y * mw + x]
                        tx, ty = transformed(x, y, mw, mh, transform)
                        if value: oracle[(ty + 9) * 128 + tx + 7] = value
                assert after == oracle
                assert read('planes/' + identity + '-' + transform + '-replay.u16le') == after_raw
                assert all(after[index] == 13 for index in region([2, 2, 3, 3], extent))
                for clearance in module['clearances']:
                    for index in region(clearance, [mw, mh]):
                        tx, ty = transformed(index % mw, index // mw, mw, mh, transform)
                        assert after[(ty + 9) * 128 + tx + 7] == 0
            rows.append(dict(id=identity, phase=phase, transform=transform, native_chunks=len(receipts),
                             checked=checked, changed=changed, excluded=excluded, plane_sha256=sha(after_raw),
                             full_world_sha256=sha(packed(full))))
        assert {identity for identity, phase, transform in seen if phase == 'source'} == modules.keys()
        assert {identity for identity, phase, transform in seen if phase == 'replay' and transform == 'identity'} == modules.keys()
        asymmetric = {'offset-buttress', 'offset-manifold', 'diagonal-transfer-spine', 'pump-on-plinth'}
        assert {identity for identity, phase, transform in seen if transform != 'identity'} == asymmetric
        for identity in asymmetric:
            assert {transform for name, phase, transform in seen if name == identity and phase == 'replay'} == {
                'identity', 'mirror_x', 'mirror_y', 'rotate_90', 'rotate_180', 'rotate_270'}
        result = dict(schema='cybersand-independent-native-catalogue-archive-review-v1', status='PASS',
                      input_archive=args.package.name, input_archive_bytes=args.package.stat().st_size,
                      input_archive_sha256=hashlib.file_digest(args.package.open('rb'),'sha256').hexdigest(), input_prefix=prefix,
                      source_revision=args.source, native_binary_sha256=args.native, enclosing_campaign_status=args.campaign_status,
                      native_active_core_capacity=1024, report_sha256=sha(report_raw), library_sha256=sha(library_raw),
                      observed_checks=report['checks'], modules=40, source_observations=40, identity_replays=40,
                      asymmetric_replays=20, asymmetric_parts=sorted(asymmetric),
                      receipt_chunks=sum(row['native_chunks'] for row in rows),
                      excluded_cells=sum(row['excluded'] for row in rows), observations=rows,
                      exported_current_process_attestation=False, receipt_row_hashes_rederived=False,
                      scope='Independent scalar reconstruction of all100 actual catalogue records, original recipe/accepted-edit and transformed local/full native material planes, revision/counter chains, clearances, occupied connector faces, protected Stone marker, and complete512-square capture hashes. Twenty variant observations cover four named asymmetric parts; no all-part/pose exhaustive native claim, physical simulation, inference or owner acceptance.')
        args.output.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps({'status':'PASS','report':str(args.output),'sha256':sha(args.output.read_bytes()),
                          'observations':100,'modules':40,'receipt_chunks':result['receipt_chunks'],
                          'excluded_cells':result['excluded_cells']}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--native', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--prefix', default='architecture-evidence/collaborative/catalogue/', choices=['architecture-evidence/collaborative/catalogue/','application/architecture/collaborative/catalogue/','extracted-evaluator/architecture/collaborative/catalogue/'])
    parser.add_argument('--campaign-status', default='unknown', choices=['passed','failed','unknown'])
    run(parser.parse_args())
