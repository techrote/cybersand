#!/usr/bin/env python3
"""One loaded LFM adapter -> 60 unrepaired first-pass model predictions -> native replay cases.

Only Training may execute heavy inference. This utility never trains, applies Art,
renders fake images or opens the reserved FINAL split. A native packet is a REQUEST,
not evidence of successful execution. Every rejected prediction remains in the
60-request denominator with zero associated replay cases.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time

HERE = Path(__file__).resolve().parent
EXP = HERE.parent
TRAINING = EXP / 'training'
sys.path.insert(0, str(TRAINING))

FROZEN_GALLERY_GIT_BLOB = '0d15d6b51387f01ca4a981c1a33896cfc531ff63'
THEMES = ('roots', 'coral', 'veins', 'mycelium', 'strata', 'dunes', 'crystals',
          'honeycomb', 'labyrinth', 'ruins', 'circuitry', 'ribs')
VARIANTS = ('literal', 'paraphrase', 'modifier', 'composition', 'contrast')
SEEDS = (17, 73)


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def frozen_cohort(path: Path) -> tuple[dict, str]:
    raw = path.read_bytes()
    git_blob = hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()
    if git_blob != FROZEN_GALLERY_GIT_BLOB:
        raise ValueError('Refusing changed 60-request DEVELOPMENT cohort Git blob: ' + git_blob)
    doc = json.loads(raw)
    if (doc.get('state') != 'FROZEN_BEFORE_NEW_MODEL_PREDICTIONS'
            or doc.get('request_count') != 60
            or doc.get('themes') != list(THEMES)
            or doc.get('variants') != list(VARIANTS)):
        raise ValueError('Frozen 60-request cohort contract changed')
    host = doc['host_context']
    if (host.get('focus_width'), host.get('focus_height'), host.get('material_id'), host.get('seeds')) != (96, 96, 58, list(SEEDS)):
        raise ValueError('Host material, focus or seed context changed')
    requests = doc['requests']
    if len(requests) != 60 or len({r['id'] for r in requests}) != 60:
        raise ValueError('Invalid request denominator/duplicate request IDs')
    expected = {(theme, variant) for theme in THEMES for variant in VARIANTS}
    if {(r['theme'], r['variant']) for r in requests} != expected:
        raise ValueError('Missing/duplicate theme and variant pairs')
    if any(not isinstance(r['prompt'], str) or not r['prompt'].strip() or
           not isinstance(r['id'], str) or len(r['id']) > 38 or
           not all(c.isascii() and (c.isalnum() or c in '_-') for c in r['id'])
           for r in requests):
        raise ValueError('Unsafe request ID or empty prompt')
    return doc, hashlib.sha256(raw).hexdigest()


def model_identity(model_dir: Path, adapter_dir: Path, compiler_path: Path) -> dict:
    from train_lora import sha256_file
    contract = json.loads((adapter_dir / 'inference_contract.json').read_text())
    config = json.loads((adapter_dir / 'adapter_config.json').read_text())
    if config['base_model_name_or_path'] != contract['model_id'] or config['revision'] != contract['revision']:
        raise ValueError('Adapter base identity differs from its inference contract')
    if sha256_file(compiler_path) != contract['compiler_sha256']:
        raise ValueError('Compiler differs from the pinned training/inference contract')
    for name, expected in contract['model_files'].items():
        if sha256_file(model_dir / name) != expected:
            raise ValueError('Pinned model file changed: ' + name)
    return {'contract': contract, 'adapter_sha256': sha(adapter_dir / 'adapter_model.safetensors'),
            'adapter_config_sha256': sha(adapter_dir / 'adapter_config.json'),
            'contract_sha256': sha(adapter_dir / 'inference_contract.json')}


def native_cases_for(program: dict, request: dict, compiler, prefix: str) -> tuple[list[dict], dict]:
    from export_native_cases import replay_case_id
    from train_lora import canonical
    cases, aliases = [], {}
    for seed in SEEDS:
        case_id, original_id = replay_case_id(prefix, request['id'], seed)
        if len(case_id) > 38 or case_id in aliases:
            raise ValueError('Native replay ID is invalid or duplicated')
        report = compiler.compile_with_report(program, 96, 96, seed, material=58,
                                              max_shapes=2048, max_estimated_cells=131072)
        cases.append({**report, 'id': case_id, 'theme': request['theme'],
                      'predicted_theme': program['theme'], 'kind': 'model-prediction',
                      'variant': request['variant'], 'prediction_id': request['id'],
                      'prompt': request['prompt'], 'seed': seed,
                      'operations_sha256': hashlib.sha256(canonical(report['operations']).encode()).hexdigest()})
        aliases[case_id] = {'prediction_id': request['id'], 'original_case_id': original_id,
                            'seed': seed, 'aliased': case_id != original_id}
    return cases, aliases


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cohort', type=Path, default=EXP / 'evaluation/gallery60_development_frozen.json')
    p.add_argument('--preflight-only', action='store_true', help='Validate frozen prompts; no model loaded or files created')
    p.add_argument('--model-dir', type=Path)
    p.add_argument('--adapter-dir', type=Path)
    p.add_argument('--compiler', type=Path, default=EXP / 'controls/pattern_compiler.py')
    p.add_argument('--output', type=Path, help='New private output directory; never inside Git')
    p.add_argument('--prefix', required=True, help='Short unique model identity used in replay aliases')
    p.add_argument('--threads', type=int, default=3)
    p.add_argument('--device', default='cpu')
    p.add_argument('--wall-seconds', type=int, default=3000)
    args = p.parse_args()
    cohort, cohort_sha = frozen_cohort(args.cohort)
    if not args.prefix or len(args.prefix) > 10 or not all(c.isascii() and (c.isalnum() or c in '_-') for c in args.prefix):
        raise ValueError('Model replay prefix must be 1–10 safe ASCII characters')
    if args.preflight_only:
        print(json.dumps({'frozen_gallery': True, 'requests': 60, 'seeds': SEEDS,
                          'cohort_sha256': cohort_sha, 'git_blob': FROZEN_GALLERY_GIT_BLOB}, indent=2))
        return 0
    if not args.model_dir or not args.adapter_dir or not args.output:
        p.error('--model-dir, --adapter-dir and --output are required for real inference')
    if args.output.resolve().is_relative_to(EXP.parents[1].resolve()):
        raise ValueError('Private model/native evidence must be stored OUTSIDE the Git checkout')
    if args.output.exists():
        raise FileExistsError('Never overwrite model raw evidence: ' + str(args.output))
    if args.threads not in range(1, 17) or not 300 <= args.wall_seconds <= 14400:
        raise ValueError('Unbounded thread/wall time request refused')
    identity = model_identity(args.model_dir, args.adapter_dir, args.compiler)
    contract = identity.pop('contract')
    from infer import load_compiler
    from train_lora import (choose_device_dtype, decode_generation, messages_for,
                            strict_json, write_json)
    compiler = load_compiler(args.compiler)
    os.environ.setdefault('TOKENIZERS_PARALLELISM', 'false')
    import torch
    from transformers import AutoTokenizer, AutoModelForCausalLM
    from peft import PeftModel
    torch.set_num_threads(args.threads)
    torch.set_num_interop_threads(1)
    device, dtype = choose_device_dtype(args.device)
    tokenizer = AutoTokenizer.from_pretrained(args.model_dir, local_files_only=True,
        trust_remote_code=contract['trust_remote_code'])
    if hashlib.sha256(str(tokenizer.chat_template).encode()).hexdigest() != contract['chat_template_sha256']:
        raise ValueError('Tokenizer template has changed')
    if tokenizer.pad_token_id is None:
        tokenizer.pad_token = tokenizer.eos_token
    base = AutoModelForCausalLM.from_pretrained(args.model_dir, local_files_only=True,
        trust_remote_code=contract['trust_remote_code'], dtype=dtype,
        attn_implementation='eager').to(device)
    model = PeftModel.from_pretrained(base, args.adapter_dir, is_trainable=False).eval()
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'raw').mkdir()
    meta = {'cohort_sha256': cohort_sha, 'frozen_git_blob': FROZEN_GALLERY_GIT_BLOB,
            'model_id': contract['model_id'], 'revision': contract['revision'],
            'compiler_sha256': contract['compiler_sha256'], **identity, 'seeds': SEEDS,
            'host_focus': [96, 96], 'host_material': 58, 'model_request_denominator': 60,
            'model_output': 'raw greedy EOS-terminated content JSON, no repair, no retry, no fallback',
            'native_execution': False, 'model_native_workbench_receipt': None}
    write_json(args.output / 'identity.json', meta)
    start = time.monotonic()
    rows, cases, aliases, rejected = [], [], {}, []
    try:
        for request in cohort['requests']:
            if time.monotonic() - start > args.wall_seconds:
                raise TimeoutError('Whole-batch wall time exhausted; partial evidence retained, do not claim 60/60')
            prefix = tokenizer.apply_chat_template(messages_for({'prompt': request['prompt']}, contract['system']),
                tokenize=False, add_generation_prompt=True, enable_thinking=False)
            inputs = tokenizer(prefix, return_tensors='pt', add_special_tokens=False).to(device)
            if inputs['input_ids'].shape[-1] + contract['max_new_tokens'] > contract['max_length']:
                raise ValueError('Frozen request exceeds pinned token budget: ' + request['id'])
            t0 = time.monotonic()
            with torch.inference_mode():
                prediction = model.generate(**inputs, max_new_tokens=contract['max_new_tokens'],
                    do_sample=False, use_cache=True, eos_token_id=tokenizer.eos_token_id,
                    pad_token_id=tokenizer.pad_token_id)
            tokens = prediction[0, inputs['input_ids'].shape[-1]:].tolist()
            raw = decode_generation(tokenizer, tokens)
            (args.output / 'raw' / (request['id'] + '.txt')).write_text(raw, encoding='utf-8')
            row = {'id': request['id'], 'theme': request['theme'], 'variant': request['variant'],
                   'prompt': request['prompt'], 'completion': raw, 'raw_sha256': hashlib.sha256(raw.encode()).hexdigest(),
                   'output_tokens': len(tokens), 'eos_emitted': bool(tokens and tokens[-1] == tokenizer.eos_token_id),
                   'seconds': round(time.monotonic() - t0, 3), 'first_pass_accepted': False}
            try:
                if not row['eos_emitted']:
                    raise ValueError('Unterminated EOS or empty completion')
                program = strict_json(raw)
                compiler.validate_program(program)
                pending, mapping = native_cases_for(program, request, compiler, args.prefix)
                if any(c['id'] in aliases for c in pending):
                    raise ValueError('Duplicate replay case ID')
                cases.extend(pending)
                aliases.update(mapping)
                row.update({'first_pass_accepted': True, 'program': program,
                            'predicted_theme': program['theme'], 'native_case_ids': [c['id'] for c in pending]})
            except (ValueError, TypeError, KeyError) as exc:
                row['rejection'] = f'{type(exc).__name__}: {exc}'
                rejected.append({'id': request['id'], 'reason': row['rejection']})
            rows.append(row)
            with (args.output / 'predictions.jsonl').open('a', encoding='utf-8') as f:
                f.write(json.dumps(row, ensure_ascii=False, allow_nan=False, sort_keys=True) + '\n')
            print(json.dumps({'id': row['id'], 'accepted': row['first_pass_accepted'],
                              'completed': len(rows), 'out_of': 60}), flush=True)
    finally:
        summary = {'complete': len(rows) == 60, 'requests_processed': len(rows),
                   'request_denominator': 60, 'first_pass_accepted': sum(x['first_pass_accepted'] for x in rows),
                   'first_pass_rejected': len(rejected), 'replay_eligible_requests': len(cases) // len(SEEDS),
                   'native_cases_requested': len(cases), 'native_cases_executed': 0,
                   'raw_failures': rejected, 'elapsed_seconds': round(time.monotonic() - start, 3)}
        write_json(args.output / 'summary.json', summary)
        write_json(args.output / 'native_cases.json', {'cases': cases, 'excluded_predictions': rejected,
            'case_id_aliases': aliases, 'counts': summary, 'manifest': meta})
        print(json.dumps(summary, indent=2), flush=True)
    return 0 if len(rows) == 60 else 3


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError, TimeoutError) as e:
        print(f'Gallery inference refused/incomplete: {e}', file=sys.stderr)
        raise SystemExit(2)