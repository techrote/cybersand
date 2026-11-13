#!/usr/bin/env python3
"""Build and score blinded *development-only* native-model image-pair review.

Uses immutable independently verified pilot receipts; never evaluates final split,
changes model programs, trains a model, or claims native/current-main qualification.
"""
from __future__ import annotations

import argparse
import base64
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import random
import statistics

THEMES = tuple(sorted('roots coral veins mycelium strata dunes crystals honeycomb labyrinth ruins circuitry ribs'.split()))
PILOT_SOURCE = '90719c72b9fcf90593fb7878354051ad601b47fd'
ADAPTER = '02b9263e543eb464e6b58f1f74960c98d5aec4ec117baddfcf22b4d5dd4c84b2'


def load(p):
    return json.loads(Path(p).read_text(encoding='utf-8'))


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def build(packet: Path, output: Path, order_seed: int = 20261113):
    """Refuse incomplete/corrupt packet before exposing any review images."""
    prov = packet / 'model-provenance'
    predicts = {}
    for cohort, name in [('development', 'development-predictions.json'),
                         ('keyword', 'keyword-predictions.json')]:
        for p in load(prov / name)['records']:
            if p['id'] in predicts or p['theme'] not in THEMES or not p['group_id']:
                raise ValueError('duplicate/invalid original prediction')
            predicts[p['id']] = dict(p, cohort=cohort)
    if len(predicts) != 36 or sum(p['first_pass_accepted'] is True for p in predicts.values()) != 34:
        raise ValueError('frozen request denominator changed; do not silently replace candidate')
    verified = load(packet / 'verified-admission-receipts.json')
    gates = verified.get('global_gates', {})
    if (verified.get('passed') is not True or len(gates) < 15 or not all(x is True for x in gates.values())
            or verified.get('runtime', {}).get('source_commit') != PILOT_SOURCE):
        raise ValueError('unqualified native pilot or failed global Stop/protection gates')
    gallery = load(packet / 'model-gallery-index.json')
    if gallery['model']['adapter_sha256'] != ADAPTER or gallery['denominators']['original_requests'] != 36:
        raise ValueError('model candidate identity or request denominator differs')
    actual = {c['id']: c for c in load(packet / 'input-cases.json')['cases']}
    receipts = {c['id']: c for c in verified['cases']}
    aliases = load(prov / 'case-id-mapping.json')['cases']
    if len(aliases) != 68 or len(receipts) != 68 or set(actual) != set(receipts) or len(actual) != 68:
        raise ValueError('native replay cases/receipts do not close')
    paired = defaultdict(list)
    for alias in aliases:
        rid, cid = alias['prediction_id'], alias['replay_case_id']
        if rid not in predicts or cid not in receipts or cid not in actual or len(cid) > 38:
            raise ValueError('missing or long replay alias')
        pred, receipt, case = predicts[rid], receipts[cid], actual[cid]
        if (pred['first_pass_accepted'] is not True or receipt.get('success') is not True
                or receipt.get('outside_focus_violations') != 0 or receipt.get('unexpected_material_cells') != 0
                or receipt.get('acknowledged_cells', 0) <= 0):
            raise ValueError('invalid prediction or native receipt')
        if (alias['seed'] != case['seed'] or alias['operations_sha256'] != case['operations_sha256']
                or receipt['operations_sha256'] != case['operations_sha256']
                or case['prediction_id'] != rid or case['theme'] != pred['theme']):
            raise ValueError('prediction/seed/geometry/receipt binding mismatch')
        png = packet / receipt['png']
        raw = packet / receipt['raw_materials']
        if (png.name != cid + '.png' or sha(png) != receipt['image_sha256']
                or sha(raw) != receipt['readback_sha256'] or raw.stat().st_size != 96 * 96 * 4):
            raise ValueError('source-native image or material bytes do not match receipt')
        paired[rid].append((alias['seed'], png, receipt['image_sha256'], receipt['readback_sha256']))
    admitted = {rid for rid, p in predicts.items() if p['first_pass_accepted'] is True}
    if set(paired) != admitted or any(sorted(x[0] for x in v) != [17, 73] for v in paired.values()):
        raise ValueError('request/seed denominators not closed')
    rejects = [p for p in predicts.values() if not p['first_pass_accepted']]
    if len(rejects) != 2 or any(p['theme'] != 'coral' for p in rejects):
        raise ValueError('the frozen two first-pass coral failures must remain visible')
    order = sorted(admitted)
    random.Random(order_seed).shuffle(order)
    custody = {name: sha(packet / name) for name in ('verified-admission-receipts.json',
        'input-cases.json', 'model-gallery-index.json',
        'model-provenance/development-predictions.json',
        'model-provenance/keyword-predictions.json',
        'model-provenance/case-id-mapping.json')}
    token = hashlib.sha256(json.dumps([custody, order, order_seed], sort_keys=True).encode()).hexdigest()
    key = {'schema_version': 1, 'review_token': token, 'candidate': 'LFM350-step400',
           'scope': 'historical-linux-headless-dev-plus-keywords; not withheld-final',
           'source_sha256': custody, 'original_requests': 36, 'first_pass_rejected': 2,
           'native_admitted_requests': 34, 'model_adapted': True,
           'excluded': [{'prediction_id': p['id'], 'group_id': p['group_id'], 'theme': p['theme'],
                         'failure': 'first-pass-invalid'} for p in rejects], 'items': []}
    cards = []
    options = '<option value="">Unrated</option><option value="unsure">Unrecognizable / unsure</option>' + ''.join(
        f'<option value="{theme}">{theme}</option>' for theme in THEMES)
    for index, rid in enumerate(order):
        p = predicts[rid]
        qid = f'q{index+1:03d}'
        pair = sorted(paired[rid])
        key['items'].append({'id': qid, 'prediction_id': rid, 'group_id': p['group_id'],
                             'cohort': p['cohort'], 'theme': p['theme'],
                             'symbolic_theme_correct': p['theme_field_correct'] is True,
                             'symbolic_motif_correct': p['primary_motif_correct'] is True,
                             'seeds': [x[0] for x in pair], 'png_sha256': [x[2] for x in pair],
                             'readback_sha256': [x[3] for x in pair]})
        images = ''.join(f'<img alt="Unlabeled native material readback, host seed {seed}" '
                         f'src="data:image/png;base64,{base64.b64encode(path.read_bytes()).decode()}">'
                         for seed, path, _, _ in pair)
        cards.append(f'<article data-id="{qid}"><strong>Pair {qid}</strong>'
                     f'<div class="images">{images}</div>'
                     f'<label>Recognized family <select class="guess">{options}</select></label>'
                     '<label>Visual quality <select class="quality">' + ''.join(
                         f'<option value="{j}">{j}</option>' for j in ('', 1, 2, 3, 4, 5)) + '</select></label>'
                     '<label>Pair variety <select class="variety">' + ''.join(
                         f'<option value="{j}">{j}</option>' for j in ('', 1, 2, 3, 4, 5)) + '</select></label></article>')
    document = '''<!doctype html><html lang="en"><meta charset="utf-8"><title>Blind native-model review</title>
<style>body{background:#161a20;color:#f4f4f0;font:15px system-ui;margin:2rem auto;max-width:1200px}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:1rem}
article{background:#262d35;border:1px solid #53616c;padding:1rem;border-radius:8px}
.images{display:flex;gap:9px;margin:12px 0}.images img{width:46%;image-rendering:pixelated;background:#151515}
label{display:block;margin:9px 0}select{margin-left:6px;max-width:100%}button{padding:10px;margin:20px 0}
</style><h1>Blinded pattern-family recognition</h1>
<p>34 accepted model requests, two real native seed readbacks per request. Classify each <b>pair once</b>,
not each seed. Family, prompt, model output and group IDs are deliberately hidden. Quality and variety
ratings are optional, subjective and separate from recognition. No final-assessment images are used.
Historical Linux headless material images, not desktop screenshots. Two malformed model requests have
no image; the scoring key retains both as first-pass failures. Never treat these pairs as 68 independent prompts.</p>
<button id="export">Export responses as JSON (partial answers permitted)</button><span id="count"></span>
<main>__CARDS__</main>
<script>const token="__TOKEN__";
function exportAnswers(){const rows=[...document.querySelectorAll('article')].map(el=>({
 id:el.dataset.id,label:el.querySelector('.guess').value,quality:el.querySelector('.quality').value,
 variety:el.querySelector('.variety').value}));
const payload={schema_version:1,review_token:token,rows};
const blob=new Blob([JSON.stringify(payload,null,2)+'\\n'],{type:'application/json'});
const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='blind_native_review_responses.json';a.click();
setTimeout(()=>URL.revokeObjectURL(url),500);}
document.querySelector('#export').onclick=exportAnswers;
document.querySelectorAll('select').forEach(el=>el.addEventListener('change',()=>{
 const n=[...document.querySelectorAll('.guess')].filter(el=>el.value).length;
 document.querySelector('#count').textContent=` ${n}/34 families classified`;}));</script></html>'''
    output.mkdir(parents=True, exist_ok=False)
    (output / 'review.html').write_text(document.replace('__CARDS__', '\n'.join(cards)).replace('__TOKEN__', token))
    (output / 'answer_key.json').write_text(json.dumps(key, indent=2) + '\n')
    return {'review_pairs': len(order), 'image_count': len(order) * 2, 'first_pass_failures_excluded_from_images': len(rejects),
            'html_sha256': sha(output / 'review.html'), 'key_sha256': sha(output / 'answer_key.json')}


def score(key_path: Path, response_path: Path):
    key, data = load(key_path), load(response_path)
    if data.get('review_token') != key.get('review_token') or data.get('schema_version') != 1:
        raise ValueError('responses belong to another candidate/native image packet')
    rows = data.get('rows')
    if not isinstance(rows, list) or len(rows) != len(key['items']):
        raise ValueError('missing or repeated review items')
    by_id = {}
    for row in rows:
        if not isinstance(row, dict) or row.get('id') in by_id or row.get('id') is None:
            raise ValueError('duplicate/invalid reviewed case')
        if row.get('label') not in (*THEMES, 'unsure', ''):
            raise ValueError('unknown visual theme label')
        if row.get('quality', '') not in ('', '1', '2', '3', '4', '5') or row.get('variety', '') not in ('', '1', '2', '3', '4', '5'):
            raise ValueError('rating outside 1..5')
        by_id[row['id']] = row
    if set(by_id) != {x['id'] for x in key['items']}:
        raise ValueError('unknown or missing item')
    if any(not x['label'] for x in rows):
        return {'scope': key['scope'], 'state': 'INCOMPLETE',
                'rated': sum(bool(x['label']) for x in rows), 'required': len(rows), 'go_no_go': 'HOLD'}
    groups, themes, cohorts = defaultdict(list), defaultdict(list), defaultdict(list)
    quality, variety, confusion, semantic_failures = [], [], [], []
    for item in key['items']:
        review = by_id[item['id']]
        good = int(review['label'] == item['theme'])
        if not good:
            confusion.append({'prediction_id': item.get('prediction_id', item['id']),
                              'expected': item['theme'], 'recognized': review['label'],
                              'group_id': item['group_id']})
        if item.get('symbolic_theme_correct') is False or item.get('symbolic_motif_correct') is False:
            semantic_failures.append({'prediction_id': item.get('prediction_id', item['id']),
                                      'expected': item['theme'],
                                      'theme_field_correct': item.get('symbolic_theme_correct'),
                                      'primary_motif_correct': item.get('symbolic_motif_correct'),
                                      'native_admitted': True})
        groups[item['group_id']].append(good)
        themes[item['theme']].append(good)
        cohorts[item['cohort']].append(good)
        if review['quality']:
            quality.append(int(review['quality']))
        if review['variety']:
            variety.append(int(review['variety']))
    matched = sum(sum(v) for v in groups.values())
    group_values = [statistics.mean(v) for v in groups.values()]
    sampler = random.Random(20261113)
    boot = sorted(statistics.mean(sampler.choices(group_values, k=len(group_values)))
                  for _ in range(10000))
    end_to_end_groups = dict(groups)
    for rejected in key['excluded']:
        end_to_end_groups.setdefault(rejected['group_id'], []).append(0)
    return {'scope': key['scope'], 'state': 'ONE_BLIND_REVIEW_COMPLETE',
            'candidate': key['candidate'], 'one_rater_not_human_acceptance': True,
            'conditional_native_image_recognition': {'matched': matched, 'admitted_requests': len(key['items']),
                                                     'pct': round(100 * matched / len(key['items']), 3)},
            'end_to_end_all_original_requests': {'matched': matched, 'requests': key['original_requests'],
                                                 'pct': round(100 * matched / key['original_requests'], 3),
                                                 'malformed_without_image': key['first_pass_rejected']},
            'structural_group_macro_accuracy': {'groups': len(groups), 'pct': round(100 * statistics.mean(group_values), 3),
                'bootstrap_95_pct': [round(100 * boot[250], 3), round(100 * boot[9749], 3)],
                'interval_note': 'Resampled structural groups; not a human-population confidence interval'},
            'all_original_structural_groups': {'groups': len(end_to_end_groups),
                'macro_pct': round(100 * statistics.mean(statistics.mean(v) for v in end_to_end_groups.values()), 3)},
            'by_theme': {t: {'correct': sum(v), 'n': len(v)} for t, v in sorted(themes.items())},
            'by_cohort': {t: {'correct': sum(v), 'n': len(v)} for t, v in sorted(cohorts.items())},
            'blind_theme_confusions': confusion, 'symbolic_failures_despite_native_pass': semantic_failures,
            'raw_first_pass_failures': key['excluded'],
            'subjective_quality_1to5': {'ratings': len(quality), 'mean': round(statistics.mean(quality), 3) if quality else None},
            'subjective_variety_1to5': {'ratings': len(variety), 'mean': round(statistics.mean(variety), 3) if variety else None},
            'threshold_80_pct': 'PROVISIONAL_RATER_ONLY', 'go_no_go': 'HOLD'}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    b = sub.add_parser('build')
    b.add_argument('--packet', type=Path, required=True)
    b.add_argument('--output', type=Path, required=True)
    b.add_argument('--order-seed', type=int, default=20261113)
    s = sub.add_parser('score')
    s.add_argument('--key', type=Path, required=True)
    s.add_argument('--responses', type=Path, required=True)
    a = p.parse_args()
    print(json.dumps(build(a.packet, a.output, a.order_seed) if a.command == 'build' else score(a.key, a.responses), indent=2))


if __name__ == '__main__':
    main()
