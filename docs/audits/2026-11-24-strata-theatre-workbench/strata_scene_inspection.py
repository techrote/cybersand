#!/usr/bin/env python3
"""Read-only authored-mask inspection; this does not execute CyberSand physics."""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

import numpy as np
from scipy import ndimage

ROOT = Path('/tmp/strata-theatre-cybersand')
OUTPUT = Path('/tmp/strata-scene-inspection.json')
FROZEN_TREE = '21d47b1ca2210ad61cfeac8997019586f8e0d639'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_spans(row):
    padded = np.pad(row.astype(np.int8), (1, 1))
    changes = np.diff(padded)
    return [(int(start), int(end)) for start, end in zip(np.flatnonzero(changes == 1), np.flatnonzero(changes == -1))]


def inspect(path):
    data = json.loads(path.read_text())
    width, height = data['extent']
    spawn_x, spawn_y = data['spawn']
    rectangles = {'play': data['play_rectangles'], **{key: value['rectangles'] for key, value in data['planes'].items()}}
    grids, planes, bounds_errors = {}, {}, []
    for plane, rows in rectangles.items():
        grid = np.zeros((height, width), dtype=np.uint16)
        for index, rectangle in enumerate(rows):
            valid = (len(rectangle) == 5 and all(type(value) is int for value in rectangle))
            if not valid:
                bounds_errors.append({'plane': plane, 'index': index, 'reason': 'not five integers'})
                continue
            x, y, w, h, material = rectangle
            if not (x >= 1 and y >= 1 and w > 0 and h > 0 and x + w <= width - 1 and y + h <= height - 1):
                bounds_errors.append({'plane': plane, 'index': index, 'rectangle': rectangle, 'reason': 'outside protected interior'})
                continue
            grid[y:y+h, x:x+w] = material
        grids[plane] = grid
        interior = grid[1:-1, 1:-1]
        ids, counts = np.unique(interior, return_counts=True)
        planes[plane] = {
            'rectangle_count': len(rows), 'construction_cell_writes': sum(row[2]*row[3] for row in rows),
            'occupied_interior_cells': int(np.count_nonzero(interior)),
            'occupied_interior_percent': round(100*float(np.count_nonzero(interior))/interior.size, 4),
            'stored_material_counts': {str(int(key)): int(value) for key, value in zip(ids, counts)},
            'authored_mask_sha256_u16le': hashlib.sha256(grid.astype('<u2').tobytes()).hexdigest(),
        }
    play = grids['play']
    empty = play == 0
    empty[[0, -1], :] = False
    empty[:, [0, -1]] = False
    labels, component_count = ndimage.label(empty, structure=ndimage.generate_binary_structure(2, 1))
    spawn_component = int(labels[spawn_y, spawn_x])
    component_cells = int(np.count_nonzero(labels == spawn_component)) if spawn_component else 0
    all_empty = int(np.count_nonzero(empty))
    components = []
    for component in range(1, int(component_count)+1):
        ys, xs = np.nonzero(labels == component)
        components.append({'component': component, 'includes_spawn': component == spawn_component,
                           'cells': len(xs), 'bounds_inclusive': [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]})
    occupied_y, occupied_x = np.nonzero(play)
    # Euclidean distance from the continuous authored spawn to occupied unit
    # cell boxes, then from the exact unrotated 4x3 Midge hull box to those boxes.
    def clearance(left, top, right, bottom):
        dx = np.maximum(0, np.maximum(occupied_x-right, left-(occupied_x+1)))
        dy = np.maximum(0, np.maximum(occupied_y-bottom, top-(occupied_y+1)))
        squared = dx*dx+dy*dy
        index = int(np.argmin(squared))
        return {'distance_cells': round(math.sqrt(float(squared[index])), 4),
                'nearest_occupied_cell': [int(occupied_x[index]), int(occupied_y[index])],
                'nearest_material_id': int(play[occupied_y[index], occupied_x[index]])}
    point_clearance = clearance(spawn_x, spawn_y, spawn_x, spawn_y)
    hull_clearance = clearance(spawn_x-2.0, spawn_y-1.5, spawn_x+2.0, spawn_y+1.5)
    footprint = play[math.floor(spawn_y-1.5):math.ceil(spawn_y+1.5), math.floor(spawn_x-2):math.ceil(spawn_x+2)]
    clear_centres = ndimage.binary_erosion(empty, structure=np.ones((5, 5), dtype=bool))
    safe_labels, safe_components = ndimage.label(clear_centres, structure=ndimage.generate_binary_structure(2, 1))
    safe_label = int(safe_labels[spawn_y, spawn_x])
    safe_reachable = int(np.count_nonzero(safe_labels == safe_label)) if safe_label else 0
    safe_y, safe_x = np.nonzero(safe_labels == safe_label) if safe_label else (np.array([]), np.array([]))
    safe_bounds = [int(safe_x.min()), int(safe_y.min()), int(safe_x.max()), int(safe_y.max())] if safe_reachable else None
    example_swept_paths = []
    if data['id'] == 'industrial-assembly':
        for start, end in [([64, 624], [960, 624]), ([534, 624], [500, 624]), ([500, 624], [500, 418])]:
            left, top = min(start[0], end[0])-2, min(start[1], end[1])-1.5
            right, bottom = max(start[0], end[0])+2, max(start[1], end[1])+1.5
            overlap = (occupied_x < right) & (occupied_x+1 > left) & (occupied_y < bottom) & (occupied_y+1 > top)
            example_swept_paths.append({'start': start, 'end': end,
                                        'unrotated_hull_overlapped_material_cells': int(np.count_nonzero(overlap)),
                                        'swept_unrotated_hull_clearance': clearance(left, top, right, bottom)})
    # Top-facing nonempty spans with at least 12 authored empty cells above.
    # Water is excluded from this structural-legibility inventory. Other
    # materials are not promoted to proven native collision/walking surfaces.
    solid_candidate = (play != 0) & (play != 3)
    cumulative = np.pad(np.cumsum(play != 0, axis=0, dtype=np.int32), ((1, 0), (0, 0)))
    supports = []
    for y in range(128, height-1):
        exposed = solid_candidate[y] & ((cumulative[y]-cumulative[y-12]) == 0)
        for left, right in run_spans(exposed):
            if right-left >= 64:
                supports.append({'x': left, 'y': y, 'width': right-left,
                                 'material_ids': [int(value) for value in np.unique(play[y, left:right])],
                                 'empty_headroom_cells_at_least': 12})
    base_floor = {'y': None, 'distance_below_spawn_cells': None}
    below = np.flatnonzero(play[spawn_y:, spawn_x] != 0)
    if len(below):
        base_floor = {'y': spawn_y+int(below[0]), 'distance_below_spawn_cells': int(below[0]),
                      'material_id': int(play[spawn_y+int(below[0]), spawn_x])}
    for plane in ('scripted', 'effects', 'background'):
        material = grids[plane] != 0
        inside = material[1:-1, 1:-1]
        overlap = (material & (play == 0))[1:-1, 1:-1]
        planes[plane]['authored_cells_over_empty_play'] = int(np.count_nonzero(overlap))
        planes[plane]['percent_of_plane_material_over_empty_play'] = round(100*np.count_nonzero(overlap)/max(1,np.count_nonzero(inside)), 4)
    return {
        'id': data['id'], 'title': data['title'], 'source_path': path.relative_to(ROOT).as_posix(),
        'source_sha256': sha(path), 'extent': [width, height],
        'interior_cells': (width-2)*(height-2), 'rectangle_count_all_planes': sum(len(rows) for rows in rectangles.values()),
        'bounds_errors': bounds_errors, 'all_rectangles_inside_protected_interior': not bounds_errors,
        'empty_play_interior_cells': all_empty,
        'empty_play_interior_percent': round(100*all_empty/((width-2)*(height-2)), 4),
        'point_free_space_components': int(component_count), 'spawn_component_cells': component_cells,
        'point_free_space_component_inventory': components,
        'spawn_component_percent_of_empty_interior': round(100*component_cells/max(1,all_empty), 4),
        'spawn': {'position': [spawn_x, spawn_y], 'stored_material': int(play[spawn_y, spawn_x]),
                  'selected_actor': 'midge', 'authored_hull_size': [4, 3],
                  'unrotated_hull_overlapped_material_cells': int(np.count_nonzero(footprint)),
                  'point_to_authored_cell_box_clearance': point_clearance,
                  'unrotated_hull_box_clearance': hull_clearance, 'first_authored_material_below': base_floor,
                  'conservative_5x5_clear_centre_component_cells': safe_reachable,
                  'conservative_5x5_clear_centre_component_bounds_inclusive': safe_bounds,
                  'conservative_5x5_clear_centre_components': int(safe_components)},
        'example_axis_aligned_swept_hull_paths': example_swept_paths,
        'horizontal_support_candidates': supports,
        'planes': planes, 'presentation': data['presentation'],
    }


def main():
    scenes = [inspect(ROOT/'godot/data/strata'/name) for name in ('industrial-assembly.json', 'arcology.json', 'cavern.json')]
    source_paths = ['godot/scripts/depth/workbench_strata_scenes.gd', 'godot/scripts/workbench_setup.gd',
                    'godot/scripts/gcr_flyer_authoring.gd', 'godot/scripts/gcr_review_fleet.gd',
                    'godot/authoring/flyers/manifest.json', 'godot/authoring/flyers/midge.json',
                    'native/include/cybersand/material.hpp']
    result = {
        'schema': 'strata-authored-scene-inspection-v1', 'status': 'completed',
        'source_tree': FROZEN_TREE,
        'inspection_worktree_head': subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip(),
        'scene_bytes_match_frozen_tree': all(subprocess.check_output(['git','-C',str(ROOT),'show',FROZEN_TREE+':'+scene['source_path']]) == (ROOT/scene['source_path']).read_bytes() for scene in scenes),
        'published_candidate': '99d3d9ef8cbf112e13979e6d64ed3113b4ec55fc',
        'inspection_script_sha256': sha(Path(__file__)),
        'source_inputs_sha256': {name:sha(ROOT/name) for name in source_paths},
        'method': 'Ordered axis-aligned authored rectangle replay into uint16 material masks; Empty=0. One-cell canvas rim excluded from ratios/connectivity. Four-neighbour point connectivity. No plane merging for play authority.',
        'limits': [
            'Read-only Python geometry analysis, not native World readback, physics, collision policy, material evolution or actual traversal.',
            'Any nonempty play material blocks the free-space mask, including Water; this is deliberately conservative and is not a native collider classification.',
            'Spawn clearance uses the unrotated authored 4x3 Midge hull; controls, trim, contacts, momentum and all other actors remain unqualified by this mask.',
            'The 5x5-centre mask is a conservative geometric probe, not a certified vehicle path.',
            'Horizontal support candidates describe visual ledge geometry with empty headroom, not reachable walking/jumping routes.',
            'Decorative overlap percentages compare local authored coordinates; rendered camera/parallax/opacity may change visible coverage.',
        ], 'scenes': scenes,
    }
    OUTPUT.write_text(json.dumps(result,indent=2)+'\n')
    for scene in scenes:
        print(json.dumps({key:scene[key] for key in ('id','rectangle_count_all_planes','all_rectangles_inside_protected_interior','empty_play_interior_percent','spawn_component_percent_of_empty_interior','spawn','horizontal_support_candidates')}))
    print(str(OUTPUT))


if __name__ == '__main__':
    main()
