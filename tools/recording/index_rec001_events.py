#!/usr/bin/env python3
"""Offline, bounded REC-001 v2 observation bookmarks. Not physics/replay evidence.

Consumes retained raw material IDs and separately timed actor metadata. It never
connects to the simulation. All event times are observation times, not inferred
occurrence times; unchanged captured bytes cannot prove simulation inactivity.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path
from xml.sax.saxutils import escape

SCHEMA = 'cybersand-state-recording-v2'
EVIDENCE = 'simulation-state-evidence-not-exact-replay'
FRAME_NAME = re.compile(r'frame-(\d{6})\.json\Z')
MAX_FRAMES = 4096
MAX_CELLS = 4_194_304
MAX_TOTAL_BYTES = 256 * 1024 * 1024
MAX_META_BYTES = 2 * 1024 * 1024


class EvidenceError(ValueError):
    pass


def require(ok: bool, message: str) -> None:
    if not ok:
        raise EvidenceError(message)


def as_int(x: object, where: str, minimum: int = 0) -> int:
    require(type(x) is int and x >= minimum, f'{where}: expected integer >= {minimum}')
    return x


def number(x: object, where: str) -> float:
    require(type(x) in (int, float) and math.isfinite(x), f'{where}: expected finite number')
    return float(x)


def obj(x: object, where: str) -> dict:
    require(isinstance(x, dict), f'{where}: expected JSON object')
    return x


def read_file(root: Path, relative: str, limit: int) -> bytes:
    require('/' not in relative and '\\' not in relative and relative not in ('.', '..'), 'unsafe filename')
    path = root / relative
    require(not path.is_symlink() and path.is_file(), f'missing/unsafe file: {relative}')
    require(path.stat().st_size <= limit, f'oversized input: {relative}')
    return path.read_bytes()


def read_json(root: Path, filename: str) -> tuple[dict, str, int]:
    raw = read_file(root, filename, MAX_META_BYTES)
    try:
        result = json.loads(raw)
    except (ValueError, UnicodeDecodeError) as exc:
        raise EvidenceError(f'invalid JSON: {filename}: {exc}') from exc
    return obj(result, filename), hashlib.sha256(raw).hexdigest(), len(raw)


def point(value: object, where: str) -> tuple[float, float] | None:
    if value is None or value == []:
        return None
    require(isinstance(value, list) and len(value) == 2, f'{where}: expected point [x,y]')
    return number(value[0], where + '[0]'), number(value[1], where + '[1]')


def extract_session(root: Path) -> dict:
    root = Path(root)
    require(root.is_dir() and not root.is_symlink(), 'session is not a real directory')
    manifest, manifest_sha, total = read_json(root, 'recording.json')
    require(manifest.get('schema_id') == SCHEMA and manifest.get('schema_version') == 2,
            'unsupported REC-001 schema')
    require(manifest.get('evidence_kind') == EVIDENCE, 'incorrect evidence kind')
    require(manifest.get('disposition') in ('complete', 'incomplete'), 'unknown disposition')
    config = obj(manifest.get('configuration'), 'configuration')
    roi = config.get('roi')
    require(isinstance(roi, list) and len(roi) == 4, 'missing/invalid fixed ROI')
    x, y = as_int(roi[0], 'roi.x', -(2**63)), as_int(roi[1], 'roi.y', -(2**63))
    width, height = as_int(roi[2], 'roi.width', 1), as_int(roi[3], 'roi.height', 1)
    require(width * height <= MAX_CELLS, 'ROI cell budget exceeded')
    counters = obj(manifest.get('counters'), 'counters')
    written = as_int(counters.get('written_frames'), 'written_frames')
    attempts = as_int(counters.get('capture_attempts'), 'capture_attempts')
    enqueued = as_int(counters.get('enqueued_frames'), 'enqueued_frames')
    dropped = as_int(counters.get('dropped_frames'), 'dropped_frames')
    require(written <= enqueued <= attempts and written <= MAX_FRAMES, 'invalid or excessive frame counts')
    drops = obj(manifest.get('drops'), 'drops')
    retained = drops.get('retained')
    require(isinstance(retained, list) and len(retained) <= 256, 'invalid/oversized drop ledger')
    omitted = as_int(drops.get('omitted_count'), 'drops.omitted_count')
    require(len(retained) + omitted == dropped, 'drop ledger inconsistent with dropped_frames')
    if manifest['disposition'] == 'complete':
        require(enqueued == written and attempts == enqueued + dropped,
                'complete capture counters inconsistent')
    observed = list(root.glob('frame-*.json'))
    require(len(observed) == written, 'frame count disagrees with recording manifest')
    require(all(FRAME_NAME.fullmatch(p.name) and not p.is_symlink() for p in observed),
            'unsafe/unknown frame metadata')
    session = obj(manifest.get('session', {}), 'session')
    start_mono = session.get('start_monotonic_usec')
    if start_mono is not None:
        start_mono = as_int(start_mono, 'session.start_monotonic_usec')
    identity = obj(manifest.get('identity'), 'identity')
    source = obj(identity.get('source', {}), 'identity.source')
    revision = str(source.get('source_revision', 'unavailable'))
    provenance = ('unverified' if revision in ('', 'unavailable') or 'synthetic' in revision.lower()
                  else 'declared-not-cryptographically-proven')
    frames: list[dict] = []
    events: list[dict] = []
    previous_ids: bytes | None = None
    previous_gen: tuple[int, int] | None = None
    previous_actor: tuple[int, int] | None = None
    previous_actor_point: tuple[float, float] | None = None
    previous_body_points: dict[str, tuple[float, float]] = {}
    previous_elapsed = -1
    previous_scenario: str | None = None
    last_source_digests = []
    reused_count = 0
    for n in range(1, written + 1):
        stem = f'frame-{n:06d}'
        meta, meta_sha, size = read_json(root, stem + '.json')
        total += size + width * height
        require(total <= MAX_TOTAL_BYTES, 'aggregate input budget exceeded')
        require(meta.get('schema_id') == SCHEMA and meta.get('evidence_kind') == EVIDENCE,
                f'{stem}: incompatible evidence metadata')
        require(meta.get('frame_index') == n, f'{stem}: frame index mismatch')
        require(meta.get('recording_roi') == roi, f'{stem}: ROI changed mid-session')
        require(meta.get('material_ids_file') == stem + '.ids', f'{stem}: invalid raw ID reference')
        ids = read_file(root, stem + '.ids', width * height)
        require(len(ids) == width * height, f'{stem}: wrong raw ID payload length')
        gen = obj(meta.get('material_generation'), f'{stem}.material_generation')
        actor = obj(meta.get('actor_sample'), f'{stem}.actor_sample')
        gen_pair = (as_int(gen.get('render_snapshot_serial'), 'render serial'),
                    as_int(gen.get('completed_simulation_tick'), 'material tick'))
        actor_pair = (as_int(actor.get('snapshot_serial'), 'snapshot serial'),
                      as_int(actor.get('completed_simulation_tick'), 'actor tick'))
        elapsed = as_int(meta.get('elapsed_monotonic_usec'), 'elapsed_monotonic_usec')
        require(elapsed >= previous_elapsed, f'{stem}: nonmonotonic elapsed time')
        if previous_gen is not None:
            require(gen_pair[0] >= previous_gen[0] and gen_pair[1] >= previous_gen[1],
                    f'{stem}: material generation went backwards')
            require(gen_pair[0] != previous_gen[0] or gen_pair[1] == previous_gen[1],
                    f'{stem}: material tick changed under unchanged serial')
        if previous_actor is not None:
            require(actor_pair[0] >= previous_actor[0] and actor_pair[1] >= previous_actor[1],
                    f'{stem}: actor sample went backwards')
            require(actor_pair[0] != previous_actor[0] or actor_pair[1] == previous_actor[1],
                    f'{stem}: actor tick changed under unchanged serial')
        require(actor_pair[1] >= gen_pair[1], f'{stem}: sampled actor predates material generation')
        scenario = obj(meta.get('scenario', {}), f'{stem}.scenario')
        scenario_id = str(scenario.get('id', 'unavailable'))
        if previous_scenario is not None and scenario_id != previous_scenario:
            events.append({'kind': 'scenario-identity-change-observed', 'frame': n,
                           'observed_elapsed_usec': elapsed, 'previous_scenario_id': previous_scenario,
                           'scenario_id': scenario_id})
        frame = {'frame': n, 'elapsed_usec': elapsed, 'generation_serial': gen_pair[0],
                 'material_tick': gen_pair[1], 'actor_snapshot_serial': actor_pair[0],
                 'actor_tick': actor_pair[1], 'ids_sha256': hashlib.sha256(ids).hexdigest(),
                 'metadata_sha256': meta_sha, 'worker_count_claim': meta.get('worker_count', 'unavailable'),
                 'scenario_id': scenario_id, 'backend_claim': meta.get('backend', 'unavailable')}
        if previous_gen == gen_pair:
            require(ids == previous_ids, f'{stem}: raw material bytes changed without generation')
            reused_count += 1
        elif previous_ids is not None:
            transitions = Counter()
            cells = 0
            xlo, ylo, xhi, yhi = width, height, -1, -1
            for index, (before, after) in enumerate(zip(previous_ids, ids)):
                if before != after:
                    cells += 1
                    cx, cy = index % width, index // width
                    xlo, xhi = min(xlo, cx), max(xhi, cx)
                    ylo, yhi = min(ylo, cy), max(yhi, cy)
                    transitions[(before, after)] += 1
            if cells:
                events.append({'kind': 'material-change-observed', 'frame': n,
                               'observed_elapsed_usec': elapsed,
                               'from_material_tick': previous_gen[1], 'to_material_tick': gen_pair[1],
                               'from_generation_serial': previous_gen[0], 'to_generation_serial': gen_pair[0],
                               'changed_cells': cells, 'world_bbox_inclusive': [x + xlo, y + ylo, x + xhi, y + yhi],
                               'top_transitions': [{'from_id': a, 'to_id': b, 'cells': k}
                                                   for (a, b), k in transitions.most_common(12)]})
        player = obj(meta.get('player', {}), f'{stem}.player')
        current_player = point(player.get('origin'), f'{stem}.player.origin')
        if previous_actor is not None and actor_pair[0] != previous_actor[0] and previous_actor_point is not None and current_player is not None:
            dx = current_player[0] - previous_actor_point[0]
            dy = current_player[1] - previous_actor_point[1]
            if dx != 0 or dy != 0:
                events.append({'kind': 'player-displacement-observed', 'frame': n,
                               'observed_elapsed_usec': elapsed, 'from_actor_tick': previous_actor[1],
                               'to_actor_tick': actor_pair[1], 'delta': [dx, dy],
                               'distance_cells': math.hypot(dx, dy),
                               'representation': str(player.get('representation', 'unavailable'))})
        if previous_actor is not None and actor_pair[0] == previous_actor[0] and previous_actor_point is not None and current_player != previous_actor_point:
            raise EvidenceError(f'{stem}: actor pose changed without new sample')
        bodies = meta.get('rigid_bodies', [])
        require(isinstance(bodies, list) and len(bodies) <= 4096, f'{stem}: invalid body array')
        next_bodies = {}
        for body in bodies:
            body = obj(body, f'{stem}.body')
            body_id = body.get('id')
            require(type(body_id) in (str, int), f'{stem}: invalid rigid body ID')
            key = str(body_id)
            require(key not in next_bodies, f'{stem}: duplicate rigid body ID')
            center = point(body.get('center'), f'{stem}.body[{key}].center')
            if center is not None:
                next_bodies[key] = center
                if previous_actor is not None and actor_pair[0] != previous_actor[0] and key in previous_body_points:
                    dist = math.dist(center, previous_body_points[key])
                    if dist > 0:
                        events.append({'kind': 'rigid-displacement-observed', 'frame': n,
                                       'body_id': key, 'distance_cells': dist,
                                       'observed_elapsed_usec': elapsed,
                                       'from_actor_tick': previous_actor[1], 'to_actor_tick': actor_pair[1]})
                elif previous_actor is not None and actor_pair[0] == previous_actor[0] and key in previous_body_points:
                    require(center == previous_body_points[key], f'{stem}: rigid pose changed without sample')
        frame['raw_cells'] = len(ids)
        frames.append(frame)
        last_source_digests.append(frame['ids_sha256'])
        previous_ids, previous_gen, previous_actor = ids, gen_pair, actor_pair
        previous_elapsed = elapsed
        previous_scenario = scenario_id
        previous_actor_point = current_player
        previous_body_points = next_bodies
    drop_attempts: set[int] = set()
    for drop in retained:
        drop = obj(drop, 'drops.retained[]')
        attempt = as_int(drop.get('attempt'), 'drop.attempt', 1)
        require(attempt <= attempts and attempt not in drop_attempts, 'invalid/repeated capture drop attempt')
        drop_attempts.add(attempt)
        drop_clock = drop.get('capture_observed_monotonic_usec')
        if drop_clock is not None:
            drop_clock = as_int(drop_clock, 'drop.capture_observed_monotonic_usec')
        relative_clock = (max(0, drop_clock - start_mono) if drop_clock is not None and start_mono is not None else None)
        events.append({'kind': 'capture-drop-recorded', 'attempt': attempt,
                       'reason': str(drop.get('reason', 'unavailable')),
                       'observed_elapsed_usec': relative_clock,
                       'capture_observed_monotonic_usec': drop_clock})
    if omitted:
        events.append({'kind': 'capture-drop-events-omitted', 'count': omitted,
                       'note': 'bounded ledger overflow; exact missing drop times not reconstructable'})
    return {'format': 'REC-001-v2-observation-event-index-1', 'semantics': 'observation-only-not-exact-replay',
            'input_manifest_sha256': manifest_sha, 'session_name': session.get('name', root.name),
            'source_revision_claim': revision, 'provenance_status': provenance,
            'disposition': manifest['disposition'], 'roi': roi,
            'counter_summary': {'capture_attempts': attempts, 'written_frames': written,
                                'dropped_frames': dropped, 'drop_events_omitted': omitted,
                                'material_generation_reused_frames': reused_count},
            'frames': frames, 'events': events,
            'limitations': ['Material changes are differences between retained generations, not event time or cause.',
                            'Actor movement is sampled separately; do not infer contact, penetration or impulse.',
                            'Unchanged captured bytes do not establish unchanged simulation between captures.',
                            'Raw IDs contain no Water quantity, temperature or reaction eligibility.',
                            'No deterministic replay or owner gameplay-feel acceptance is asserted.']}


def render_svg(report: dict) -> str:
    frames = report['frames']
    left, right, height = 95, 1180, 350
    max_elapsed = max([1] + [f['elapsed_usec'] for f in frames])
    material = Counter()
    player = Counter()
    rigid = Counter()
    for event in report['events']:
        if event['kind'] == 'material-change-observed':
            material[event['frame']] += event['changed_cells']
        elif event['kind'] == 'player-displacement-observed':
            player[event['frame']] += event['distance_cells']
        elif event['kind'] == 'rigid-displacement-observed':
            rigid[event['frame']] += event['distance_cells']
    maxima = [max([1] + list(c.values())) for c in [material, player, rigid]]
    rows = [('Material ID changes', material, maxima[0], 120),
            ('Player displacement', player, maxima[1], 210),
            ('Rigid displacement', rigid, maxima[2], 300)]
    items = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 {height}" role="img">',
             '<title>REC-001 observation-only event timeline</title>',
             '<rect width="1280" height="350" fill="#101923"/>',
             '<text x="30" y="28" fill="#edf3f9" font-family="monospace" font-size="17">REC-001 • Observed event bookmarks</text>',
             '<text x="30" y="49" fill="#acc0d4" font-family="monospace" font-size="12">Capture time, not causation. Separate material / actor clocks.</text>']
    for title, counts, peak, baseline in rows:
        items.append(f'<line x1="{left}" y1="{baseline}" x2="{right}" y2="{baseline}" stroke="#536477"/>')
        items.append(f'<text x="30" y="{baseline - 52}" fill="#d7e7f6" font-family="monospace" font-size="13">{escape(title)}</text>')
        for f in frames:
            value = counts.get(f['frame'], 0)
            if value:
                xcoord = left + f['elapsed_usec'] / max_elapsed * (right - left)
                bar = 42 * value / peak
                items.append(f'<rect x="{xcoord:.2f}" y="{baseline - bar:.2f}" width="5" height="{bar:.2f}" fill="#8dc7ed"><title>frame {f["frame"]}: {value:.3f}</title></rect>')
    items.append(f'<text x="{left}" y="337" fill="#acc0d4" font-family="monospace" font-size="12">0 ms</text>')
    items.append(f'<text x="{right - 90}" y="337" fill="#acc0d4" font-family="monospace" font-size="12">{max_elapsed/1000:.0f} ms</text>')
    for event in report['events']:
        if event['kind'] == 'capture-drop-recorded' and event['observed_elapsed_usec'] is not None:
            t = event['observed_elapsed_usec']
            xcoord = left + max(0, min(max_elapsed, t)) / max_elapsed * (right - left)
            items.append(f'<line x1="{xcoord:.2f}" x2="{xcoord:.2f}" y1="65" y2="315" stroke="#f8a8a8" stroke-dasharray="3,5"><title>recorded capture drop attempt {event["attempt"]}</title></line>')
        if event['kind'] == 'capture-drop-events-omitted':
            items.append('<text x="800" y="28" fill="#ffd07f" font-family="monospace" font-size="11">DROP LEDGER OVERFLOW</text>')
    items.append('</svg>')
    return '\n'.join(items) + '\n'


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('session', type=Path)
    ap.add_argument('output_directory', type=Path)
    args = ap.parse_args(argv)
    try:
        require(not args.output_directory.exists(), 'refusing existing output directory')
        report = extract_session(args.session)
        args.output_directory.mkdir(parents=True, exist_ok=False)
        (args.output_directory / 'events.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n', encoding='utf-8')
        (args.output_directory / 'timeline.svg').write_text(render_svg(report), encoding='utf-8')
        print(f'{len(report["frames"])} observed frames; {len(report["events"])} bookmarks; output {args.output_directory}')
        return 0
    except (EvidenceError, OSError) as exc:
        print(f'REFUSED: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
