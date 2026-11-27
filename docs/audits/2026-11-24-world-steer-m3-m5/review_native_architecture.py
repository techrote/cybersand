#!/usr/bin/env python3
"""Read-only independent review of retained CyberSand native architecture evidence.

This consumes the existing qualification artifacts; it launches no application,
uses no model or network, and writes only the explicitly requested review JSON.
It does not replace the qualification runner's source/build/runtime custody.

Final graphical example:
  python3 review_native_architecture.py \
    --representatives EVIDENCE/stages/representatives.json \
    --modules EVIDENCE/stages/module-compositions.json \
    --renders EVIDENCE/stages/architecture-render-manifest.json \
    --expected-source FULL_40_CHARACTER_COMMIT --output REVIEW.json

For an explicitly historical development audit, --allow-development-source
permits missing or different source declarations and records that limitation.
The script verifies image identity/dimensions. Visual inspection is separate.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import zlib

MAX_JSON_BYTES = 64 * 1024 * 1024
MAX_CELLS = 512 * 512
MAX_RECEIPTS = 256
REPRESENTATIVES = (
    'assembly-hangar', 'interconnected-arcology', 'biomechanical-arboretum',
    'irregular-megastructure', 'service-network', 'constructed-cavern',
)
MODULES = ('modular-assembly-hangar', 'modular-service-stack', 'modular-transfer-viaduct')
SUPPORT_MATERIALS = {58, 28, 13, 7}
HEX40 = re.compile(r'[0-9a-f]{40}\Z')
HEX64 = re.compile(r'[0-9a-f]{64}\Z')


class EvidenceError(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise EvidenceError(reason)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value) -> bytes:
    # Native receipt objects contain integers, strings and arrays. The native
    # session canonicalizes integral numeric values before retaining their hash.
    def normalize(item):
        if isinstance(item, float) and item.is_integer():
            return int(item)
        if isinstance(item, list):
            return [normalize(x) for x in item]
        if isinstance(item, dict):
            return {k: normalize(v) for k, v in item.items()}
        return item
    return json.dumps(normalize(value), sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def integer(value, label: str, low: int, high: int) -> int:
    require(type(value) is int and low <= value <= high, f'{label} must be an integer in {low}..{high}')
    return value


def hash_value(value, label: str) -> str:
    require(isinstance(value, str) and HEX64.fullmatch(value) is not None, f'{label} must be a SHA-256 identity')
    return value


def read_json(path: Path) -> dict:
    require(path.is_file() and path.stat().st_size <= MAX_JSON_BYTES, f'JSON evidence missing or exceeds 64 MiB: {path}')
    value = json.loads(path.read_text(encoding='utf-8'))
    require(isinstance(value, dict), f'JSON evidence is not an object: {path}')
    return value


def relative_file(folder: Path, name, maximum: int) -> Path:
    require(isinstance(name, str) and bool(name), 'Evidence filename is missing')
    relative = Path(name)
    require(not relative.is_absolute() and '..' not in relative.parts, 'Evidence path must stay inside its artifact directory')
    path = (folder / relative).resolve()
    require(path.is_relative_to(folder.resolve()), 'Evidence symlink escapes its artifact directory')
    require(path.is_file() and path.stat().st_size <= maximum, f'Evidence file missing or oversized: {name}')
    return path


def extent(value) -> tuple[int, int]:
    require(isinstance(value, list) and len(value) == 2, 'Expected [width, height]')
    return integer(value[0], 'width', 1, 512), integer(value[1], 'height', 1, 512)


def decode_plane(raw: bytes, width: int, height: int) -> tuple[int, ...]:
    require(len(raw) == width * height * 2, 'Native material plane has the wrong extent')
    return struct.unpack(f'<{width * height}H', raw)


def neighbors(index: int, width: int, height: int):
    x, y = index % width, index // width
    if x:
        yield index - 1
    if x + 1 < width:
        yield index + 1
    if y:
        yield index - width
    if y + 1 < height:
        yield index + width


def component_sizes(mask: set[int], width: int, height: int) -> list[int]:
    remaining = set(mask)
    sizes = []
    while remaining:
        queue = [remaining.pop()]
        for index in queue:
            for other in neighbors(index, width, height):
                if other in remaining:
                    remaining.remove(other)
                    queue.append(other)
        sizes.append(len(queue))
    return sorted(sizes, reverse=True)


def rectangle_cells(rectangles, width: int, height: int, origin=(0, 0)) -> set[int]:
    require(isinstance(rectangles, list) and len(rectangles) <= 128, 'Rectangle list missing or oversized')
    cells = set()
    for rectangle in rectangles:
        require(isinstance(rectangle, list) and len(rectangle) == 4, 'Malformed rectangle')
        x = integer(rectangle[0], 'rectangle x', 0, 2048) - origin[0]
        y = integer(rectangle[1], 'rectangle y', 0, 2048) - origin[1]
        w = integer(rectangle[2], 'rectangle width', 1, 2048)
        h = integer(rectangle[3], 'rectangle height', 1, 2048)
        require(0 <= x < x + w <= width and 0 <= y < y + h <= height, 'Rectangle exceeds the inspected region')
        cells.update(row * width + col for row in range(y, y + h) for col in range(x, x + w))
    return cells


def check_source(value, expected: str | None, development: bool, label: str) -> None:
    require(isinstance(value, str), f'{label} source declaration is malformed')
    require(value == '' or HEX40.fullmatch(value) is not None, f'{label} source declaration is not an exact commit')
    if not development:
        require(expected is not None and value == expected, f'{label} does not match the expected qualification source')


def review_example(example: dict, folder: Path, manifest_source: str, expected: str | None,
                   development: bool, group: str) -> dict:
    require(isinstance(example, dict), 'Example is not an object')
    identity = example.get('id')
    require(identity in (REPRESENTATIVES if group == 'representatives' else MODULES), 'Unexpected example identity')
    width, height = extent(example.get('extent'))
    recipe = example.get('recipe')
    require(isinstance(recipe, dict) and recipe.get('extent') == [width, height], 'Recipe extent differs from native result')
    origin_value = recipe.get('origin', example.get('origin'))
    require(isinstance(origin_value, list) and len(origin_value) == 2, 'Recipe origin is missing')
    origin = (integer(origin_value[0], 'origin x', 0, 2048), integer(origin_value[1], 'origin y', 0, 2048))
    records = example.get('native_records')
    require(isinstance(records, list) and len(records) == 3, 'Example must retain all three native stage records')
    require(isinstance(recipe.get('stages'), list) and len(recipe['stages']) == 3, 'Recipe stages are missing')
    previous = bytes(width * height * 2)
    if group == 'modules':
        source_record = example.get('source_plane')
        require(isinstance(source_record, dict), 'Module composition source plane is missing')
        source_path = relative_file(folder, source_record.get('path'), MAX_CELLS * 2)
        source = source_path.read_bytes()
        require(digest(source) == hash_value(source_record.get('sha256'), 'Initial plane'), 'Initial plane hash mismatch')
        require(source == previous, 'This registered module fixture must begin in an empty selected region')
        require(example.get('stages') == records, 'Duplicated stage evidence differs')
        require(example.get('whole_world_source_sha256') == digest(bytes(512 * 512 * 2)), 'Registered module fixture has an unexpected whole-World baseline')
    stages = []
    detail = None
    all_sources = set()
    for stage_index, record in enumerate(records):
        require(isinstance(record, dict), 'Native stage record is malformed')
        check_source(record.get('source_revision'), expected, development, 'Stage')
        require(record.get('source_revision') == manifest_source, 'Stage and manifest source declarations differ')
        all_sources.add(record['source_revision'])
        require(record.get('status') == 'completed' and record.get('native_result', {}).get('status') == 'completed', 'Native stage is not completed')
        require(record.get('final_readback_available') is True, 'Completed stage lacks final native readback')
        require(record.get('stage_id') == recipe['stages'][stage_index].get('id'), 'Stage ordering or identity differs')
        require(record.get('stage') == recipe['stages'][stage_index], 'Retained stage differs from the registered recipe')
        require(record.get('source_sha256') == digest(previous), 'Native before/after stage chain differs')
        encoded = record.get('result_materials_base64')
        require(isinstance(encoded, str) and len(encoded) <= ((MAX_CELLS * 2 + 2) // 3) * 4, 'Final native plane is missing or oversized')
        raw = base64.b64decode(encoded, validate=True)
        before = decode_plane(previous, width, height)
        after = decode_plane(raw, width, height)
        require(digest(raw) == record.get('result_sha256') == record.get('expected_sha256'), 'Native plane, final receipt and approved projection identities differ')
        receipts = record.get('native_receipts')
        require(isinstance(receipts, list) and 1 <= len(receipts) <= MAX_RECEIPTS, 'Completed stage lacks bounded native receipts')
        require(digest(canonical(receipts)) == record.get('native_receipts_sha256'), 'Native receipt collection hash differs')
        read_cells = set()
        changed_ack = checked_ack = 0
        for receipt in receipts:
            require(isinstance(receipt, dict) and receipt.get('backend') == 'CyberNativeCellWorld' and receipt.get('status') == 'completed', 'Receipt is not completed authoritative native work')
            values = {key: integer(receipt.get(key), f'receipt {key}', 0, 4096)
                      for key in ('requested', 'checked', 'confirmed', 'excluded', 'refused', 'changed', 'unchanged')}
            require(values['requested'] == values['checked'] + values['excluded'], 'Requested/checked/excluded counters differ')
            require(values['checked'] == values['confirmed'] + values['refused'], 'Checked/confirmed/refused counters differ')
            readback = receipt.get('readback')
            require(isinstance(readback, list) and values['confirmed'] == values['changed'] + values['unchanged'] == len(readback), 'Receipt readback/counter identity differs')
            require(values['checked'] > 0 and values['refused'] == 0, 'Completed recipe contains an empty or refused native chunk')
            require(receipt.get('generation') == record.get('generation'), 'Native receipt World generation differs')
            checked_ack += values['checked']
            changed_ack += values['changed']
            require(checked_ack <= MAX_CELLS, 'Native stage exceeds its absolute execution budget')
            for row in readback:
                require(isinstance(row, list) and len(row) == 4, 'Malformed native readback row')
                x = integer(row[0], 'readback x', 0, 2048) - origin[0]
                y = integer(row[1], 'readback y', 0, 2048) - origin[1]
                old = integer(row[2], 'old material', 0, 65535)
                new = integer(row[3], 'new material', 0, 65535)
                require(0 <= x < width and 0 <= y < height, 'Actual native readback escaped the selected region')
                index = y * width + x
                require(index not in read_cells, 'Normalized stage contains a repeated native cell write')
                read_cells.add(index)
                require(before[index] == old and after[index] == new, 'Native row does not match retained before/after material bytes')
        changed = {i for i, (old, new) in enumerate(zip(before, after)) if old != new}
        require(changed == read_cells, 'Native receipt cells do not equal the exact changed material cells')
        budget = record.get('budget')
        require(isinstance(budget, dict), 'Host budget is missing')
        require(len(changed) == changed_ack == record.get('changed_cells') == budget.get('changed_cells'), 'Actual changed-cell acknowledgements differ from host result')
        require(checked_ack == record.get('checked_cells') == budget.get('checked_cells'), 'Actual native work differs from the approved host budget')
        require(checked_ack <= integer(budget.get('limit'), 'stage budget limit', 1, MAX_CELLS), 'Native work exceeded the declared execution budget')
        stage = record['stage']
        require(stage.get('region') == [origin[0], origin[1], width, height], 'Retained stage region differs')
        guards = rectangle_cells(stage.get('clearances', []), width, height, origin)
        protected = rectangle_cells(stage.get('protected', []), width, height, origin)
        require(all(after[index] == 0 for index in guards), 'Native construction occupies a required clearance')
        require(not (changed & protected), 'Native construction changed a declared protected cell')
        inspection = record.get('inspection')
        require(isinstance(inspection, dict), 'Final native inspection is missing')
        check_source(inspection.get('source_commit'), expected, development, 'Inspection')
        require(inspection.get('source_commit') == manifest_source, 'Inspection and manifest source declarations differ')
        require(inspection.get('crop_sha256') == digest(raw) and inspection.get('source_world_generation') == record.get('generation'), 'Inspection crop or World generation differs')
        require(inspection.get('original_region') == [origin[0], origin[1], width, height], 'Inspection origin differs')
        require(inspection.get('original_extent') == [512, 512], 'Registered fixture requires its original 512-square World')
        require(origin[0] + width <= 512 and origin[1] + height <= 512, 'Recipe escapes the original native World')
        whole = bytearray(512 * 512 * 2)
        for y in range(height):
            whole[((y + origin[1]) * 512 + origin[0]) * 2:((y + origin[1]) * 512 + origin[0] + width) * 2] = raw[y * width * 2:(y + 1) * width * 2]
        require(digest(whole) == inspection.get('whole_plane_sha256'), 'Full native World contains unexpected material outside the selected region')
        selected_modules = stage.get('modules', [])
        resolved_modules = record.get('resolved_modules', [])
        require(isinstance(selected_modules, list) and isinstance(resolved_modules, list) and len(selected_modules) == len(resolved_modules), 'Selected/resolved module count differs')
        for selected, resolved in zip(selected_modules, resolved_modules):
            require(isinstance(selected, dict) and isinstance(resolved, dict), 'Malformed selected module reference')
            require(selected.get('module_id') == resolved.get('id') and selected.get('placement') == resolved.get('placement'), 'Resolved module placement differs from proposal')
            if 'module_sha256' in selected:
                require(selected['module_sha256'] == resolved.get('sha256'), 'Pinned module content identity differs')
        stages.append({'stage_id': record['stage_id'], 'native_receipt_chunks': len(receipts),
                       'source_sha256': digest(previous), 'result_sha256': digest(raw),
                       'checked_cells': checked_ack, 'changed_cells': changed_ack,
                       'native_readback_rows_verified': len(read_cells), 'clearance_occupied_cells': 0,
                       'protected_changed_cells': 0, 'whole_world_outside_region_empty_hash_verified': True,
                       'resolved_module_instances': len(resolved_modules)})
        if group == 'representatives' and stage_index == 2:
            context = recipe.get('evaluation_context')
            require(isinstance(context, dict), 'Representative architectural context is missing')
            require(all(before[i] == 0 and after[i] == 28 for i in changed), 'Detail stage is not exclusively new Metal in previously Empty cells')
            attached = {i for i in changed if any(before[n] in SUPPORT_MATERIALS for n in neighbors(i, width, height))}
            detail = {'new_cells': len(changed), 'each_cell_touches_prior_support': attached == changed,
                      'unattached_new_cells': len(changed - attached),
                      'new_detail_component_sizes': component_sizes(changed, width, height),
                      'identity_method': 'services-stage to detail-stage native delta; Metal is also primary structure/service material'}
            require(attached == changed, 'A detail addition lacks direct prior structural/service face contact')
            generation = context.get('detail_generation', {})
            require(generation.get('emitted_cells') == len(changed), 'Declared detail generation count differs from actual new cells')
            explicit_zones = (context.get('schema_version') == 'cybersand.architectural-stage-role-context.v1'
                              and 'zone_expansion_cells' in generation)
            if not development:
                require(explicit_zones, 'Final representative lacks explicit stage-role and expanded-zone metadata')
            if explicit_zones:
                require(context.get('material_roles_disjoint') is False and context.get('disjoint_material_reducer_compatible') is False, 'Stage-role context misrepresents overlapping material identities')
                zones = rectangle_cells(context.get('detail_zones', []), width, height)
                require(changed <= zones, 'New detail escaped the declared expanded zones')
                detail['expanded_zone_containment_verified'] = True
                detail['zone_expansion_cells'] = generation.get('zone_expansion_cells')
            else:
                detail['expanded_zone_containment_verified'] = False
                detail['legacy_context_note'] = 'Development metadata lacks explicit expanded-zone isolation; no inferred zone certificate.'
        previous = raw
    final_path = relative_file(folder, example.get('plane'), MAX_CELLS * 2)
    final = final_path.read_bytes()
    require(final == previous and digest(final) == hash_value(example.get('sha256'), 'Final native plane'), 'Final native plane file differs from completed stage evidence')
    cells = decode_plane(final, width, height)
    chosen = {i for i, material in enumerate(cells) if material in SUPPORT_MATERIALS} if group == 'representatives' else {i for i, material in enumerate(cells) if material != 0}
    sizes = component_sizes(chosen, width, height)
    if group == 'modules':
        require(example.get('face_connected_components') == len(sizes), 'Stored module composition component count differs from independent flood fill')
        require(example.get('module_instances') == sum(row['resolved_module_instances'] for row in stages), 'Module instance count differs from actual resolved native stages')
    return {'id': identity, 'family': example.get('family'), 'group': group, 'evaluable': True,
            'native_completed_stages': len(stages), 'extent': [width, height], 'origin': list(origin),
            'plane_sha256': digest(final), 'source_revisions': sorted(all_sources),
            'recipe_revision': recipe.get('recipe_revision', 'not-declared'),
            'observed_material_ids': sorted(set(cells)), 'nonempty_material_cells': sum(value != 0 for value in cells),
            'empty_fraction': sum(value == 0 for value in cells) / (width * height),
            'component_material_scope': sorted(SUPPORT_MATERIALS) if group == 'representatives' else 'all nonzero material identities',
            'material_component_count': len(sizes), 'material_component_sizes': sizes,
            'single_component': len(sizes) == 1, 'stages': stages, 'detail_delta': detail}


def review_manifest(path: Path, group: str, expected: str | None, development: bool) -> dict:
    document = read_json(path)
    check_source(document.get('source_revision'), expected, development, group)
    rows = document.get('examples')
    expected_ids = REPRESENTATIVES if group == 'representatives' else MODULES
    require(isinstance(rows, list) and len(rows) <= 9, 'Example list missing or oversized')
    seen = set()
    reviewed = []
    for row in rows:
        identity = row.get('id', 'malformed') if isinstance(row, dict) else 'malformed'
        try:
            require(isinstance(identity, str) and identity not in seen, 'Missing or duplicate example identity')
            seen.add(identity)
            reviewed.append(review_example(row, path.parent, document['source_revision'], expected, development, group))
        except (EvidenceError, ValueError, KeyError, TypeError, IndexError, AttributeError, OSError, OverflowError) as error:
            reviewed.append({'id': str(identity), 'group': group, 'evaluable': False, 'native_completed_stages': 0, 'reason': str(error)})
    missing = [identity for identity in expected_ids if identity not in seen]
    return {'manifest': path.name, 'manifest_sha256': digest(path.read_bytes()),
            'source_revision': document['source_revision'], 'godot': document.get('godot'),
            'expected_examples': len(expected_ids), 'actual_examples': len(rows), 'missing_examples': missing,
            'examples': reviewed, 'passed': not missing and len(rows) == len(expected_ids) and all(row['evaluable'] for row in reviewed)}


def png_dimensions(raw: bytes) -> list[int]:
    require(len(raw) >= 33 and raw[:8] == b'\x89PNG\r\n\x1a\n' and raw[12:16] == b'IHDR', 'Rendered frame is not a PNG')
    require(struct.unpack('>I', raw[8:12])[0] == 13, 'PNG IHDR size differs')
    require(zlib.crc32(raw[12:29]) & 0xffffffff == struct.unpack('>I', raw[29:33])[0], 'PNG IHDR checksum differs')
    return list(struct.unpack('>II', raw[16:24]))


def review_renders(path: Path, examples: list[dict], expected: str | None, development: bool) -> dict:
    document = read_json(path)
    check_source(document.get('source_revision'), expected, development, 'Render manifest')
    require(document.get('passed') is True and document.get('failures') == 0, 'Graphical harness did not pass')
    require(isinstance(document.get('display'), str) and document['display'].lower() not in ('', 'headless'), 'Graphical manifest does not declare a genuine display')
    renders = document.get('renders')
    require(isinstance(renders, list) and len(renders) <= 9, 'Render list missing or oversized')
    lookup = {row['id']: row for row in examples if row.get('evaluable')}
    seen = set()
    reviewed = []
    for row in renders:
        image_name = row.get('image', '') if isinstance(row, dict) else ''
        try:
            require(isinstance(row, dict), 'Render identity is not an object')
            require(isinstance(image_name, str) and image_name.endswith('-godot.png'), 'Unexpected native render filename')
            identity = image_name.removesuffix('-godot.png')
            require(identity in lookup and identity not in seen, 'Rendered family is duplicate or lacks verified native material evidence')
            seen.add(identity)
            native = lookup[identity]
            require(row.get('kind') == 'godot-rendered-native-material-plane', 'Frame is not declared actual Godot native-material rendering')
            require(row.get('native_material_sha256') == native['plane_sha256'], 'Rendered frame references a different native plane')
            require(all(material < 256 for material in native['observed_material_ids']), 'RG8 render input cannot retain a high uint16 material identity')
            require(isinstance(row.get('display'), str) and row['display'].lower() not in ('', 'headless'), 'Frame lacks graphical display evidence')
            require(row.get('godot') == document.get('godot'), 'Frame and render manifest runtime declarations differ')
            require(isinstance(row.get('palette'), dict) and bool(row['palette']), 'Frame lacks native shader provenance')
            image_path = relative_file(path.parent, image_name, 32 * 1024 * 1024)
            raw = image_path.read_bytes()
            require(digest(raw) == hash_value(row.get('image_sha256'), 'Rendered image'), 'Rendered PNG hash differs')
            require(png_dimensions(raw) == [side * 2 for side in native['extent']], 'Rendered framebuffer dimensions differ from exact two-times native crop')
            reviewed.append({'id': identity, 'image': image_name, 'verified': True,
                             'image_sha256': digest(raw), 'native_material_sha256': native['plane_sha256'],
                             'dimensions': png_dimensions(raw), 'renderer_identity': row,
                             'visual_review_status': 'NOT_PERFORMED_BY_THIS_SCRIPT'})
        except (EvidenceError, ValueError, KeyError, TypeError, IndexError, AttributeError, OSError, OverflowError) as error:
            reviewed.append({'image': str(image_name), 'verified': False, 'reason': str(error)})
    missing = [identity for identity in (*REPRESENTATIVES, *MODULES) if identity not in seen]
    return {'manifest': path.name, 'manifest_sha256': digest(path.read_bytes()),
            'source_revision': document['source_revision'], 'expected_frames': 9, 'actual_frames': len(renders),
            'missing_frames': missing, 'frames': reviewed,
            'passed': len(renders) == 9 and not missing and all(row['verified'] for row in reviewed),
            'scope': 'PNG identity, native-plane binding, framebuffer dimensions and retained renderer declarations; independent visual inspection remains separate.'}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--representatives', type=Path, required=True)
    parser.add_argument('--modules', type=Path, required=True)
    parser.add_argument('--renders', type=Path)
    parser.add_argument('--expected-source')
    parser.add_argument('--allow-development-source', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.expected_source is not None and HEX40.fullmatch(args.expected_source) is None:
        parser.error('--expected-source requires an exact lowercase 40-character commit')
    if not args.allow_development_source and args.expected_source is None:
        parser.error('Supply --expected-source, or explicitly request --allow-development-source')
    input_paths = [args.representatives, args.modules] + ([args.renders] if args.renders else [])
    if args.output.resolve() in [path.resolve() for path in input_paths]:
        parser.error('The review output must not overwrite an input manifest')
    report = {'schema_version': 'cybersand.native-architecture-independent-audit.v1',
              'audit_tool_sha256': digest(Path(__file__).read_bytes()),
              'expected_source': args.expected_source, 'development_source_mode': args.allow_development_source,
              'native': {}, 'renders': {'requested': False, 'passed': None},
              'claim_limits': [
                  'Source declarations are checked against the supplied expected source; binary/build custody remains in the qualification manifest.',
                  'Every retained native material row and plane is checked; queued or missing work cannot become completed evidence.',
                  'Static material connectivity and clearance are geometric diagnostics, not stability, flow, actor traversal or architectural preference.',
                  'This tool performs no visual review, native writes, network access, model inference or owner acceptance.',
                  'The nine demonstrations are separate from the thirty-attempt matched comparison.']}
    for group, path in [('representatives', args.representatives), ('modules', args.modules)]:
        try:
            report['native'][group] = review_manifest(path, group, args.expected_source, args.allow_development_source)
        except (EvidenceError, ValueError, KeyError, TypeError, AttributeError, OSError, OverflowError) as error:
            report['native'][group] = {'manifest': path.name, 'passed': False, 'reason': str(error), 'examples': []}
    examples = [row for group in report['native'].values() for row in group.get('examples', [])]
    if args.renders:
        try:
            report['renders'] = dict(requested=True, **review_renders(args.renders, examples, args.expected_source, args.allow_development_source))
        except (EvidenceError, ValueError, KeyError, TypeError, AttributeError, OSError, OverflowError) as error:
            report['renders'] = {'requested': True, 'passed': False, 'reason': str(error)}
    report['native_passed'] = all(group.get('passed', False) for group in report['native'].values())
    report['evaluable_examples'] = sum(row.get('evaluable', False) for row in examples)
    report['native_completed_stage_records'] = sum(row.get('native_completed_stages', 0) for row in examples)
    report['native_receipt_chunks'] = sum(stage['native_receipt_chunks'] for row in examples if row.get('evaluable') for stage in row['stages'])
    report['single_component_examples'] = sum(row.get('single_component', False) for row in examples)
    report['passed'] = report['native_passed'] and (report['renders']['passed'] if args.renders else True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({'review': str(args.output), 'review_sha256': digest(args.output.read_bytes()),
                      'passed': report['passed'], 'development_source_mode': args.allow_development_source,
                      'evaluable_examples': report['evaluable_examples'],
                      'native_completed_stage_records': report['native_completed_stage_records'],
                      'native_receipt_chunks': report['native_receipt_chunks'],
                      'single_component_examples': report['single_component_examples'],
                      'render_audit_requested': bool(args.renders), 'render_audit_passed': report['renders']['passed']}, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
