#!/usr/bin/env python3
"""WORM-001: replayable *non-model*, *non-native* local-steering baseline.

The host alone owns bounds, obstacles, legal moves, seeded randomness and Stop.
Raw model actions may be replayed, but replay is transport, not learned policy.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import random
import struct
import zlib
from pathlib import Path

ACTIONS = ('STRAIGHT', 'LEFT', 'RIGHT', 'BRANCH', 'RETRACE', 'STOP')
DIRECTIONS = ((1, 0), (0, 1), (-1, 0), (0, -1))
POLICIES = ('random', 'wall', 'fidget')
FAMILIES = ('greebles', 'pipework', 'architecture')


def initial_world(seed: int, size: int = 96) -> set[tuple[int, int]]:
    if size < 24:
        raise ValueError('size must be at least 24')
    rng = random.Random(seed ^ 0x6A9B17)
    blocks: set[tuple[int, int]] = set()
    for _ in range(max(7, size // 6)):
        w, h = rng.randint(3, max(4, size // 11)), rng.randint(3, max(4, size // 9))
        x, y = rng.randint(4, size - w - 5), rng.randint(4, size - h - 5)
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if abs(xx - 7) + abs(yy - size // 2) > 9:
                    blocks.add((xx, yy))
    return blocks


def run(seed: int, mode: str = 'fidget', family: str = 'greebles',
        steps: int = 240, size: int = 96, raw_actions: list[str] | None = None) -> dict:
    if mode not in POLICIES + ('replay',) or family not in FAMILIES:
        raise ValueError('unknown mode or family')
    if not (0 <= steps <= 4096) or not (24 <= size <= 256):
        raise ValueError('unbounded steps/size')
    if mode == 'replay' and raw_actions is None:
        raise ValueError('replay requires raw actions')
    rng = random.Random(seed ^ 0xD431C0DE)
    obstacles = initial_world(seed, size)
    x, y, heading = 7, size // 2, 0
    trajectory = [(x, y)]
    visited = {(x, y): 1}
    branching = set()
    history = []
    events = []
    stopped = False
    invalid = 0
    new_visits = 0
    branches = 0
    retraces = 0

    for tick in range(steps):
        moves = {}
        for name, rotation in [('STRAIGHT', 0), ('LEFT', -1), ('RIGHT', 1)]:
            d = (heading + rotation) % 4
            nx, ny = x + DIRECTIONS[d][0], y + DIRECTIONS[d][1]
            if 0 <= nx < size and 0 <= ny < size and (nx, ny) not in obstacles:
                moves[name] = (nx, ny, d)
        legal = list(moves)
        forward_choices = [a for a, dest in moves.items() if (dest[0], dest[1]) not in visited]
        if len(forward_choices) >= 2 and len(history) < 2048:
            legal.append('BRANCH')
        if history:
            legal.append('RETRACE')
        legal.append('STOP')
        neighbourhood = []
        for dy in range(-2, 3):
            line = ''
            for dx in range(-2, 3):
                px, py = x + dx, y + dy
                line += ('@' if dx == dy == 0 else
                         '#' if not (0 <= px < size and 0 <= py < size) or (px, py) in obstacles else
                         '+' if (px, py) in visited else '.')
            neighbourhood.append(line)
        observation = {'x': x, 'y': y, 'heading': heading, 'local_5x5': neighbourhood,
                       'legal': legal, 'last_actions': [e['applied'] for e in events[-4:]],
                       'family': family, 'tick': tick}
        if mode == 'replay':
            raw = raw_actions[tick] if tick < len(raw_actions) else 'STOP'
        elif mode == 'wall':
            raw = next((a for a in ('RIGHT', 'STRAIGHT', 'LEFT') if a in forward_choices), None)
            if raw is None:
                raw = 'RETRACE' if 'RETRACE' in legal else 'STOP'
        elif mode == 'random':
            pool = forward_choices * 3 + [a for a in legal if a != 'STOP']
            raw = rng.choice(pool) if pool else 'STOP'
        else:
            weights = {'STRAIGHT': 5, 'LEFT': 2, 'RIGHT': 2, 'BRANCH': 1, 'RETRACE': 1, 'STOP': 0}
            if family == 'greebles':
                weights.update({'STRAIGHT': 3, 'LEFT': 4, 'RIGHT': 4, 'BRANCH': 2})
            elif family == 'pipework':
                weights.update({'STRAIGHT': 8, 'LEFT': 2, 'RIGHT': 2, 'BRANCH': 2})
            else:
                weights.update({'STRAIGHT': 6, 'LEFT': 2, 'RIGHT': 2, 'BRANCH': 1})
            pool = [a for a in legal if a != 'STOP']
            if forward_choices:
                pool = [a for a in pool if a not in moves or a in forward_choices]
            raw = rng.choices(pool, weights=[weights[a] for a in pool], k=1)[0] if pool else 'STOP'

        applied = raw if raw in legal else ('RETRACE' if 'RETRACE' in legal else 'STOP')
        invalid += int(applied != raw)
        prior = (x, y, heading)
        if applied == 'STOP':
            stopped = True
        elif applied == 'RETRACE':
            x, y, heading = history.pop()
            retraces += 1
        else:
            arm = applied
            if applied == 'BRANCH':
                branches += 1
                branching.add((x, y))
                arm = next((a for a in ('RIGHT', 'LEFT', 'STRAIGHT') if a in forward_choices), None)
                if arm is None:
                    arm = next((a for a in ('STRAIGHT', 'LEFT', 'RIGHT') if a in moves), None)
            if arm is None:
                raise AssertionError('branch without legal arm')
            history.append(prior)
            x, y, heading = moves[arm]
            new_visits += int((x, y) not in visited)
            visited[(x, y)] = visited.get((x, y), 0) + 1
        trajectory.append((x, y))
        events.append({'observation': observation, 'raw_choice': raw,
                       'applied': applied, 'position_after': [x, y],
                       'raw_legal': raw in legal})
        if stopped:
            break

    return {'contract': 'cybersand.worm.observation-action/0-experimental',
            'engine': 'python-stdlib-baseline-not-native',
            'seed': seed, 'mode': mode, 'family': family,
            'size': size, 'step_budget': steps, 'steps_executed': len(events),
            'obstacles': sorted([list(p) for p in obstacles]),
            'trajectory': [list(p) for p in trajectory],
            'branch_points': sorted([list(p) for p in branching]), 'events': events,
            'metrics': {'unique_trail_cells': len(visited), 'new_steps': new_visits,
                        'branches': branches, 'retraces': retraces,
                        'invalid_raw_choices': invalid, 'terminated_by_stop': stopped,
                        'total_revisit_contacts': sum(v - 1 for v in visited.values())}}


def png_bytes(record: dict, scale: int = 4) -> bytes:
    if not (1 <= scale <= 10):
        raise ValueError('scale out of range')
    n = record['size']
    obstacles = {tuple(p) for p in record['obstacles']}
    path = [tuple(p) for p in record['trajectory']]
    segments = set(path)
    branches = {tuple(p) for p in record['branch_points']}
    latest = {p: i for i, p in enumerate(path)}
    rows = bytearray()
    for y in range(n):
        row = bytearray()
        for x in range(n):
            p = (x, y)
            if p == path[-1]:
                c = (243, 210, 72)
            elif p in branches:
                c = (225, 115, 216)
            elif p in obstacles:
                c = (78, 81, 96)
            elif p in segments:
                t = latest[p] / max(len(path)-1, 1)
                c = (round(28 + 68*t), round(139 + 77*t), round(190 + 40*t))
            else:
                c = (14, 19, 29)
            row.extend(c * scale)
        for _ in range(scale):
            rows.append(0)
            rows.extend(row)

    def chunk(typ: bytes, data: bytes) -> bytes:
        return (struct.pack('>I', len(data)) + typ + data
                + struct.pack('>I', zlib.crc32(typ + data) & 0xffffffff))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', n*scale, n*scale, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b''))


def write_result(record: dict, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    identity = f"{record['family']}-{record['mode']}-{record['seed']}"
    canonical = json.dumps(record, sort_keys=True, separators=(',', ':')).encode('utf-8') + b'\n'
    (out / (identity + '.json')).write_bytes(canonical)
    png = png_bytes(record)
    (out / (identity + '.png')).write_bytes(png)
    print(json.dumps({'id': identity, 'sha256_json': hashlib.sha256(canonical).hexdigest(),
                      'sha256_png': hashlib.sha256(png).hexdigest(),
                      'metrics': record['metrics']}, sort_keys=True))


def main():
    p = argparse.ArgumentParser(description='WORM-001 stdlib baselines; NOT learned or native')
    p.add_argument('--output', type=Path, default=Path('worm-gallery'))
    p.add_argument('--seeds', default='11,29')
    p.add_argument('--families', default=','.join(FAMILIES))
    p.add_argument('--modes', default=','.join(POLICIES))
    p.add_argument('--steps', type=int, default=260)
    p.add_argument('--size', type=int, default=96)
    p.add_argument('--replay-actions', type=Path, default=None)
    opts = p.parse_args()
    actions = None
    if opts.replay_actions:
        data = opts.replay_actions.read_text(encoding='utf-8')
        actions = json.loads(data) if data.lstrip().startswith('[') else data.splitlines()
        if not isinstance(actions, list) or not all(isinstance(x, str) for x in actions):
            raise ValueError('invalid replay actions')
    for seed in map(int, opts.seeds.split(',')):
        for family in opts.families.split(','):
            for mode in ('replay',) if actions is not None else opts.modes.split(','):
                write_result(run(seed, mode, family, opts.steps, opts.size, actions), opts.output)


if __name__ == '__main__':
    main()
