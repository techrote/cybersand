"""Trusted immutable profiles, Atlas-derived API charging and capacity gates."""
from __future__ import annotations
import dataclasses
import datetime as dt
import json
import math
import os
from pathlib import Path
import re
import stat
from urllib.parse import urlsplit

from atlas_agent.budget import Budget
from atlas_agent.credit_gate import evaluate as atlas_credit_evaluate, enforce as atlas_credit_enforce
from atlas_agent.pricing import Rates, load_table, rates_for, text_tokens_upper_bound, image_tokens_upper_bound

SCHEMA = 'cybersand.workbench-api-agent.profile/1'
HARD = {'max_model_calls': 64, 'max_tools': 95, 'max_run_seconds': 3500,
        'max_input_tokens_per_call': 120000, 'max_total_input_tokens': 1000000,
        'max_total_output_tokens': 250000, 'max_output_tokens': 4096,
        'max_images': 24, 'max_image_bytes': 8*1024*1024,
        'max_evidence_bytes': 100*1024*1024, 'max_history_bytes': 240000,
        'max_tool_result_bytes': 24000, 'max_retries': 3,
        'max_total_retries': 12, 'max_native_ticks': 480, 'max_request_bytes': 8500000}
DEFAULT = {'max_model_calls': 18, 'max_tools': 30, 'max_run_seconds': 900,
           'max_input_tokens_per_call': 32000, 'max_total_input_tokens': 160000,
           'max_total_output_tokens': 20000, 'max_output_tokens': 1024,
           'max_images': 8, 'max_image_bytes': 3*1024*1024,
           'max_evidence_bytes': 40*1024*1024, 'max_history_bytes': 140000,
           'max_tool_result_bytes': 12000, 'max_retries': 2,
           'max_total_retries': 6, 'max_native_ticks': 120, 'max_request_bytes': 6000000}
PROVIDERS = ('openai_responses','nvidia_chat','ollama_chat','fixture')
KEY_ENV = {'openai_responses':'OPENAI_API_KEY','nvidia_chat':'NVIDIA_API_KEY'}
ENDPOINTS = {'openai_responses':'https://api.openai.com/v1/responses',
             'nvidia_chat':'https://integrate.api.nvidia.com/v1/chat/completions',
             'ollama_chat':'http://127.0.0.1:11434/v1/chat/completions'}

class ConfigError(ValueError): pass


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding='utf-8'), parse_constant=lambda _: (_ for _ in ()).throw(ValueError('non-json constant')))
    if not isinstance(value,dict): raise ConfigError('config must be JSON object')
    return value


def keys_exact(o: dict, allowed: set[str], required: set[str]) -> None:
    if not isinstance(o,dict) or set(o)-allowed or required-set(o):
        raise ConfigError(f'fields mismatch: extra={sorted(set(o)-allowed) if isinstance(o,dict) else "not object"}; missing={sorted(required-set(o)) if isinstance(o,dict) else "not object"}')


def loopback(url:str)->bool:
    try:
        u=urlsplit(url)
        return (u.scheme=='http' and u.hostname in ('localhost','127.0.0.1','::1') and
                u.port is not None and not u.username and not u.password and not u.fragment and not u.query)
    except (ValueError,TypeError): return False


def strict_endpoint(provider:str, url:str, fixture_mode:bool)->None:
    u=urlsplit(url)
    if u.username or u.password or u.query or u.fragment: raise ConfigError('credentials/query in endpoint refused')
    if provider=='fixture':
        if not loopback(url): raise ConfigError('fixture endpoint must be loopback HTTP')
    elif provider=='ollama_chat':
        if not loopback(url) or not u.path.endswith('/v1/chat/completions'):
            raise ConfigError('local Ollama only through explicit loopback /v1/chat/completions')
    elif provider=='openai_responses':
        if not (u.scheme=='https' and u.hostname=='api.openai.com' and u.path=='/v1/responses'):
            if not (fixture_mode and loopback(url) and u.path=='/v1/responses'):
                raise ConfigError('OpenAI Responses host/path not allowlisted')
    elif provider=='nvidia_chat':
        if not (u.scheme=='https' and u.hostname=='integrate.api.nvidia.com' and u.path=='/v1/chat/completions'):
            if not (fixture_mode and loopback(url) and u.path=='/v1/chat/completions'):
                raise ConfigError('NVIDIA Catalog host/path not allowlisted')


def load_profile(path: Path, *, fixture_mode: bool=False) -> dict:
    cfg=read_json(path)
    keys_exact(cfg,{'schema','provider','endpoint','model','capabilities','limits','credentials','pricing','spend','local_compute'},
               {'schema','provider','endpoint','model','capabilities','limits','credentials','spend'})
    if cfg['schema']!=SCHEMA or cfg['provider'] not in PROVIDERS: raise ConfigError('unsupported schema/provider')
    if not isinstance(cfg['model'],str) or not 1<=len(cfg['model'])<=120 or re.search(r'[\r\n\x00]',cfg['model']):
        raise ConfigError('invalid model name')
    if cfg['model'].startswith('REPLACE_') and not fixture_mode: raise ConfigError('placeholder is not a qualified model')
    strict_endpoint(cfg['provider'],cfg['endpoint'],fixture_mode)
    cap=cfg['capabilities']
    keys_exact(cap,{'tools','images','strict_tools','parallel_tools','image_detail'}, {'tools','images','strict_tools','parallel_tools','image_detail'})
    if cap['tools'] is not True or cap['images'] is not True: raise ConfigError('visual tool tasks require tools and image capability')
    if any(type(cap[k]) is not bool for k in ('strict_tools','parallel_tools')): raise ConfigError('invalid capability bool')
    if cap['image_detail'] not in ('low','high','auto'): raise ConfigError('unsupported image detail')
    lim=cfg['limits'];keys_exact(lim,set(HARD),set())
    merged=DEFAULT|lim
    for k,v in merged.items():
        if type(v) is not int or v<1 or v>HARD[k]:raise ConfigError('limit '+k+' outside hard bounds')
    if merged['max_tools']>=96: raise ConfigError('reserve owner Stop slot')
    if merged['max_image_bytes']>merged['max_evidence_bytes']: raise ConfigError('image > evidence budget')
    cfg['limits']=merged
    key=cfg['credentials'];keys_exact(key,{'env','file'},set())
    if len(key)!=1:raise ConfigError('credentials must select exactly one env or file reference (empty env for local)')
    provider=cfg['provider'];ref=key.get('env','')
    if provider in KEY_ENV and 'env' in key and not re.fullmatch(r'[A-Z][A-Z0-9_]{1,70}',ref):
        raise ConfigError('cloud credential env invalid')
    if provider in ('ollama_chat','fixture') and key != {'env':''}:
        raise ConfigError('local/fixture profile does not accept cloud credentials')
    spend=cfg['spend'];keys_exact(spend, {'max_usd_per_run','max_usd_per_call','authorised_ceiling_usd','authorisation_ref','credit_attestation_file','rates','rates_checked_utc','rates_source','max_age_days','require_costs_crosscheck','expected_project'},
                {'max_usd_per_run','max_usd_per_call','authorised_ceiling_usd','authorisation_ref'})
    for k in ('max_usd_per_run','max_usd_per_call','authorised_ceiling_usd'):
        if type(spend[k]) not in (int,float) or not math.isfinite(spend[k]) or not 0<=spend[k]<=1000:raise ConfigError('invalid spend '+k)
    if type(spend['authorisation_ref']) is not str or len(spend['authorisation_ref'])>160:raise ConfigError('authorization reference invalid')
    if provider=='ollama_chat' and cfg.get('local_compute','unknown') not in ('unknown','operator_metered'):
        raise ConfigError('local GPU compute costing is separate from API spend')
    return cfg


def credential(cfg:dict)->str:
    ref=cfg['credentials']
    if cfg['provider'] in ('ollama_chat','fixture'):return ''
    if 'env' in ref: key=os.environ.get(ref['env'],'')
    else:
        p=Path(ref['file']).expanduser()
        if not p.is_file() or p.is_symlink():raise ConfigError('credential file unavailable')
        st=p.stat()
        if st.st_uid!=os.getuid() or stat.S_IMODE(st.st_mode)&0o077: raise ConfigError('credential file must be owned by user mode 0600')
        key=p.read_text(encoding='utf-8').strip()
    if len(key)<20 or re.search(r'\s',key):raise ConfigError('credential missing/invalid; no paid request performed')
    return key


def pricing_rates(cfg:dict)->Rates:
    provider=cfg['provider'];sp=cfg['spend'];model=cfg['model']
    if provider=='openai_responses':return rates_for(model,load_table())
    if provider=='nvidia_chat':
        checked=dt.date.fromisoformat(sp['rates_checked_utc'])
        days=(dt.datetime.now(dt.timezone.utc).date()-checked).days
        if days<0 or days>min(int(sp.get('max_age_days',30)),45): raise ConfigError('NVIDIA host-supplied rate verification stale')
        if not (isinstance(sp.get('rates_source'),str) and sp['rates_source'].startswith('https://')):raise ConfigError('NVIDIA rate source required')
        rate=sp['rates']
        if not isinstance(rate,dict) or set(rate)!={'input_usd_per_1m','output_usd_per_1m'}:raise ConfigError('explicit NVIDIA rate table required')
        if any(type(v) not in (float,int) or not math.isfinite(v) or v<=0 for v in rate.values()):raise ConfigError('unverified/nonpositive NVIDIA rate is not a spending authorization')
        return Rates(model,float(rate['input_usd_per_1m']),float(rate['input_usd_per_1m']),float(rate['output_usd_per_1m']),1000000,False,
                     {'method':'patch','patch_size':32,'patch_budget':{'low':30000,'high':30000,'auto':30000},'multiplier':2.46},sp['rates_source'],sp['rates_checked_utc'],120000)
    return Rates(model,0,0,0,1000000,False,{'method':'patch','patch_size':32,'patch_budget':{'low':30000,'high':30000,'auto':30000},'multiplier':2.46},'local-not-billed-api','local',120000)


def validate_live(cfg:dict, *, allow_live:bool, fixture_mode:bool, probe=None, source_dirty:bool|None=True)->tuple[Budget,dict]:
    if not fixture_mode and not allow_live:raise ConfigError('live requests require explicit --allow-live')
    sp=cfg['spend'];prov=cfg['provider']
    if fixture_mode:rates=pricing_rates(cfg) if prov!='nvidia_chat' else Rates(cfg['model'],0,0,0,1000000,False,{'method':'patch','patch_size':32,'patch_budget':{'low':30000,'high':30000,'auto':30000},'multiplier':2.46},'fixture','fixture',120000)
    else:rates=pricing_rates(cfg)
    gate={'mode':'fixture' if fixture_mode else 'live','model':cfg['model'],'pricing_source':rates.source_url}
    if not fixture_mode and prov!='ollama_chat':
        credential(cfg)
        if not sp['authorisation_ref'] or sp['max_usd_per_run']<=0 or sp['authorised_ceiling_usd']<sp['max_usd_per_run']:
            raise ConfigError('charged provider needs spend reference, positive run budget and authorised ceiling')
        if prov=='openai_responses':
            att_file=sp.get('credit_attestation_file')
            att=read_json(Path(att_file)) if att_file else None
            # Atlas checks its selected env value but the workbench profile
            # may also use a private credential FILE. Provide the same secret
            # only in the in-memory gate environment: never mutate os.environ,
            # write it to a receipt, or weaken Atlas credit requirements.
            atlas_gate_env=dict(os.environ)
            atlas_gate_env['CYBERSAND_WB_OPENAI_KEY']=credential(cfg)
            atlas_cfg={'spend':{'max_usd_per_call':sp['max_usd_per_call'], 'max_usd_per_run':sp['max_usd_per_run'],
                 'authorised_ceiling_usd':sp['authorised_ceiling_usd'],'authorisation_ref':sp['authorisation_ref'],
                 'require_costs_crosscheck':sp.get('require_costs_crosscheck',False), 'costs_key_env':'OPENAI_ADMIN_KEY', 'expected_project':sp.get('expected_project'),
                 'credit_expiry_margin_hours':24,'attestation_max_age_hours':72,'credit_attestation':att},
                 'api':{'key_env':'CYBERSAND_WB_OPENAI_KEY'},
                 'model':cfg['model'],'task':{'allow_dirty_source':False}}
            report=atlas_credit_evaluate(atlas_cfg,atlas_gate_env,load_table(),dt.datetime.now(dt.timezone.utc),
                           probe,None,source_dirty=source_dirty,base_url='https://api.openai.com/v1')
            atlas_credit_enforce(report)
            gate['atlas_credit_gate']={k:v for k,v in report.items() if k!='rates'}
        else:
            # Never conflate a published catalog listing with an owner's credit/grant balance.
            if not sp.get('credit_attestation_file'):raise ConfigError('NVIDIA requires explicit owner funding attestation file')
            att=read_json(Path(sp['credit_attestation_file']))
            required={'checked_utc','remaining_usd','expires_utc','auto_recharge_disabled','api_only','eligible_models'}
            if not required.issubset(att):raise ConfigError('NVIDIA funding attestation fields missing')
            checked=dt.datetime.fromisoformat(att['checked_utc'].replace('Z','+00:00'))
            expires=dt.datetime.fromisoformat(att['expires_utc'].replace('Z','+00:00'))
            now=dt.datetime.now(dt.timezone.utc)
            if not (0<=(now-checked).total_seconds()<=72*3600 and expires>=now+dt.timedelta(hours=24)
                    and att['auto_recharge_disabled'] is True and att['api_only'] is True and
                    cfg['model'] in att['eligible_models'] and type(att['remaining_usd']) in (float,int)
                    and att['remaining_usd']>=sp['max_usd_per_run']):
                raise ConfigError('NVIDIA owner funding attestation is missing/expired/insufficient')
            gate['funding_attestation']='owner-attested-not-machine-verified'
    # Atlas Budget preserves reservations and ambiguous spend accounting.
    limits=cfg['limits']; b=Budget(limits={'max_iterations':limits['max_model_calls'],
         'max_api_calls':limits['max_model_calls']+limits['max_total_retries'],
         'max_input_tokens_per_call':limits['max_input_tokens_per_call'],
         'max_total_input_tokens':limits['max_total_input_tokens'],
         'max_total_output_tokens':limits['max_total_output_tokens'],
         'max_run_seconds':limits['max_run_seconds']},
         spend={**sp,'max_usd_per_call':sp['max_usd_per_call'] if not fixture_mode else 1000,
                'max_usd_per_run':sp['max_usd_per_run'] if not fixture_mode else 1000,
                'authorised_ceiling_usd':sp['authorised_ceiling_usd'] if not fixture_mode else 1000},
         rates=rates, live=not fixture_mode and prov!='ollama_chat')
    return b,gate
