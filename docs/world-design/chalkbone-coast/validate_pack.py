#!/usr/bin/env python3
"""Source-aware structural checks for the proposed Chalkbone Coast *design* pack.

No native engine or rendering validation is implied. Python stdlib only.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_ROOT = HERE.parents[2]  # docs/world-design/chalkbone-coast -> repo root
STATUS = {'static', 'reactive-static', 'open-dynamic', 'time-evolving'}
REACTIVE_KERNELS = {k for k in range(1, 27)}


def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(b'blob ' + str(len(data)).encode('ascii') + b'\0' + data).hexdigest()


def check(pack: dict, repo_root: Path | None = None) -> dict:
    errors = []
    def require(test, what):
        if not test:
            errors.append(what)
    require(pack.get('schema_id') == 'cybersand.world-feature-pack.proposal', 'proposal schema mismatch')
    require(pack.get('schema_version') == 1, 'proposal schema version mismatch')
    co = pack.get('coordinate_contract', {})
    require('half-open' in co.get('bounds', ''), 'non-half-open rectangle contract')
    palette_rows = pack.get('palette', [])
    palette = {p['id']:p for p in palette_rows}
    require(len(palette) == len(palette_rows), 'duplicate palette ID')
    require(0 in palette and palette[0]['name'] == 'empty', 'missing Empty material 0')
    for mid, mat in palette.items():
        require(type(mid) is int and 0 <= mid <= 131 and mid != 10, f'invalid palette ID {mid}')
        require(len(mat['rgba']) == 4 and all(type(x) is int and 0 <= x <= 255 for x in mat['rgba']), f'bad RGBA at {mid}')
        require(type(mat['movable']) is bool, f'bad movable at {mid}')
        require(mat['state'] in range(6), f'bad state at {mid}')
    ids = set()
    base_used = set()
    counts = {'feature_rectangles': 0, 'scene_rectangles': 0, 'placements': 0, 'mobile_module_rectangles': 0, 'mobility_cells': 0}
    by_id = {}
    def geometry(rows, wh, label):
        used = set()
        require(isinstance(rows, list) and len(rows) > 0, f'{label}: missing rectangles')
        for i, r in enumerate(rows):
            good = isinstance(r, list) and len(r) == 5 and all(type(v) is int for v in r)
            require(good, f'{label}[{i}]: rectangle must have 5 integers')
            if not good: continue
            x,y,w,h,m = r
            require(w > 0 and h > 0 and 0 <= x and 0 <= y and x + w <= wh[0] and y + h <= wh[1], f'{label}[{i}]: out of bounds')
            require(m in palette, f'{label}[{i}]: unapproved material ID {m}')
            used.add(m)
        return used
    features = pack.get('features', [])
    require(4 <= len(features) <= 10, 'expected 4-10 meaningful modules')
    for f in features:
        fid = f['id']; wh = f['size']
        require(fid not in ids, f'duplicate feature {fid}'); ids.add(fid)
        by_id[fid] = f
        require(len(wh) == 2 and all(type(v) is int and v > 0 for v in wh), f'{fid}: invalid dimensions')
        require(f['status'] in STATUS, f'{fid}: unsupported status')
        require(f['anchor'] == {'type':'ground-contact','point':[wh[0]//2,wh[1]]}, f'{fid}: anchor must contact bottom centre')
        require(len(f.get('placement_rules',[])) >= 2, f'{fid}: missing placement caveats')
        module_used = geometry(f['rectangles'], wh, fid)
        base_used.update(module_used)
        counts['feature_rectangles'] += len(f['rectangles'])
        mobile = {m for m in module_used if m in palette and palette[m]['movable']}
        reactive = {m for m in module_used if m in palette and palette[m]['kernel'] != 0 and m != 0}
        if f['status'] == 'static':
            require(not mobile and not reactive, f'{fid}: static contains mobile or active-kernel IDs: {mobile}|{reactive}')
        elif f['status'] == 'reactive-static':
            require(not mobile and bool(reactive), f'{fid}: reactive-static must have fixed but active-kernel IDs')
        elif f['status'] in {'open-dynamic','time-evolving'}:
            require(bool(mobile), f'{fid}: dynamic tag without a mobile source material')
        counts['mobile_module_rectangles'] += sum(1 for r in f['rectangles'] if r[4] in mobile)
        variants = f.get('variants', [])
        require(len(variants) >= 2, f'{fid}: needs at least two alternatives')
        seen_variants=set()
        for v in variants:
            require(v['id'] not in seen_variants and v['id'] != 'base', f'{fid}: duplicate variant name')
            seen_variants.add(v['id'])
            require(bool(v['swap']), f'{fid}:{v["id"]} has no swaps')
            for old,new in v['swap'].items():
                require(old.isdigit() and int(old) in module_used, f'{fid}:{v["id"]}: nonexistent source {old}')
                require(type(new) is int and new in palette, f'{fid}:{v["id"]}: undefined replacement {new}')
                base_used.add(new)
        if f['status'] == 'reactive-static':
            inert = [v for v in variants if v['id']=='fossilised']
            require(bool(inert), f'{fid}: no inert fossilised fallback')
        if f['status'] in {'open-dynamic','time-evolving'}:
            solid = [v for v in variants if any(palette[new]['movable'] is False and palette[new]['kernel'] == 0 for new in v['swap'].values() if new in palette)]
            require(bool(solid), f'{fid}: no nonmobile alternative')
    scene = pack.get('scene',{})
    sz = scene.get('size',[0,0])
    base_used.update(geometry(scene.get('rectangles',[]), sz, 'scene'))
    counts['scene_rectangles'] = len(scene.get('rectangles',[]))
    placed = scene.get('placements',[])
    require(len(placed) == len(features), 'combined scene must place each feature exactly once')
    counts['placements'] = len(placed)
    seen_placed=set()
    areas=[]
    for a in placed:
        fid=a['feature']; require(fid in by_id, f'unknown scene feature {fid}')
        if fid not in by_id: continue
        require(fid not in seen_placed, f'duplicate scene feature placement {fid}'); seen_placed.add(fid)
        f=by_id[fid]; x,y=a['x'],a['y']; w,h=f['size']
        require(type(x) is int and type(y) is int and x>=0 and y>=0 and x+w<=sz[0] and y+h<=sz[1], f'{fid}: scene placement out of bounds')
        require(a['variant']=='base' or any(v['id']==a['variant'] for v in f['variants']), f'{fid}: unknown variant')
        for pid,px,py,pw,ph in areas:
            require(x>=px+pw or px>=x+w or y>=py+ph or py>=y+h, f'{fid}: overlapping AABB with {pid}')
        areas.append((fid,x,y,w,h))
    require(base_used <= set(palette), f'palette missing IDs {base_used - set(palette)}')
    # The design pack is source pinned. If checked out in the actual repo, compare
    # both blob identities and every palette row against the authoritative catalogue.
    source_status = 'SKIPPED: full current source not present in this working directory'
    if repo_root is not None:
        native_path=repo_root/pack['source']['native_material_enum']
        cat_path=repo_root/pack['source']['shadow_catalogue']
        if not native_path.exists() or not cat_path.exists():
            errors.append('repo-root supplied but source file missing')
        else:
            nb=native_path.read_bytes(); cb=cat_path.read_bytes()
            require(git_blob_sha(nb)==pack['source']['native_enum_blob_sha'], 'native material.hpp blob SHA changed')
            require(git_blob_sha(cb)==pack['source']['shadow_catalogue_blob_sha'], 'catalogue blob SHA changed')
            ntext=nb.decode('utf-8').split('enum class MaterialState')[0]
            current_ids={int(m.group(1)) for m in re.finditer(r'^\s*[A-Z][A-Za-z0-9_]*\s*=\s*(\d+),', ntext, re.M) for _ in [0]}
            cat=json.loads(cb); cmap={m['id']:m for m in cat['native']['materials']}
            for mid,mat in palette.items():
                require(mid in current_ids, f'palette ID {mid} missing from native enum')
                if mid in cmap:
                    other=cmap[mid]
                    for attr in ('name','state','movable','kernel','rgba'):
                        require(other[attr]==mat[attr], f'{mid} source catalogue mismatch for {attr}')
                else: errors.append(f'{mid} missing from authoritative catalogue')
            source_status='PASS: source blobs and palette matched exact pinned files' if not errors else 'FAIL'
    # small raster count is a structural budget, *not* a native performance result.
    W,H=sz
    if errors:
        return {'ok':False,'errors':errors,'source_check':source_status,'counts':counts}
    if W>0 and H>0 and W*H<=400_000:
        raster=[0]*(W*H)
        def paint(r,ox=0,oy=0,swaps=None):
            x,y,w,h,m=r; m=(swaps or {}).get(str(m),m)
            for yy in range(y+oy,y+oy+h):
                raster[yy*W+x+ox:yy*W+x+ox+w]=[m]*w
        for r in scene['rectangles']:paint(r)
        for placement in placed:
            f=by_id[placement['feature']]
            swap=next((v['swap'] for v in f['variants'] if v['id']==placement['variant']),{})
            for r in f['rectangles']:paint(r,placement['x'],placement['y'],swap)
        counts['mobility_cells'] = sum(1 for m in raster if m in palette and palette[m]['movable'])
        counts['nonempty_cells']=sum(x!=0 for x in raster)
    return {'ok':not errors,'errors':errors,'source_check':source_status,'counts':counts}


def self_test(base):
    def bad(edit,label):
        obj=copy.deepcopy(base);edit(obj);r=check(obj)
        if r['ok']:raise AssertionError(f'mutation was improperly accepted: {label}')
    bad(lambda d: d['features'][0]['rectangles'].append([0,0,1,1,10]),'invalid material 10')
    bad(lambda d: d['features'][0]['rectangles'].append([0,0,1,1,24]),'moving brine inside static')
    bad(lambda d: d['features'][0].update(id=d['features'][1]['id']),'duplicate module ID')
    bad(lambda d: d['features'][0]['rectangles'].append([200,0,1,1,99]),'out of bounds')
    bad(lambda d: d['scene']['placements'][0].update(x=-1),'negative placement')
    bad(lambda d: d['scene']['placements'][0].update(x=130,y=84),'overlap')
    bad(lambda d: d['features'][0]['variants'][0]['swap'].update({'999':99}),'nonexistent substitution')
    bad(lambda d: d['features'][0]['variants'][0]['swap'].update({'99':10}),'invalid replacement')
    bad(lambda d: d['features'][0].update(status='time-evolving'),'dynamic without mobile')
    bad(lambda d: d['features'][5].update(status='static'),'active-kernel inside inert static')
    bad(lambda d: d['features'][6].update(status='static'),'fluid inside inert static')
    bad(lambda d: d['palette'][0].update(name='bogus'),'Empty sentinel altered')
    print('SELF-TEST PASS: 12 independently invalid mutations rejected')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--pack',type=Path,default=HERE/'pack.json')
    parser.add_argument('--repo-root',type=Path,help='fail if pinned native and catalogue files absent; verify exact blob SHAs and rows')
    parser.add_argument('--self-test',action='store_true')
    a=parser.parse_args(); d=json.loads(a.pack.read_text(encoding='utf-8'))
    result=check(d,a.repo_root)
    print(json.dumps(result,indent=2))
    if a.self_test:self_test(d)
    return 0 if result['ok'] else 1

if __name__=='__main__':
    raise SystemExit(main())
