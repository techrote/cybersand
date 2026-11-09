"""Host-editable language only; machine schemas and native permissions stay owned."""
import json
import hashlib
from pathlib import Path

def sections(overrides=None,mode="tools"):
    if mode not in ("tools","scanline"):raise ValueError("unknown authoring mode")
    defaults=json.loads(Path(__file__).with_name('boilerplate_scanline.json' if mode=='scanline' else 'boilerplate.json').read_text(encoding='utf-8'))
    if overrides is None:return defaults
    if not isinstance(overrides,dict) or set(overrides)-set(defaults):
        raise ValueError('unknown boilerplate section')
    if any(not isinstance(v,str) or len(v.encode('utf-8'))>8192 for v in overrides.values()):
        raise ValueError('boilerplate section must be text up to8192 bytes')
    result=defaults|overrides
    if sum(len(v.encode('utf-8')) for v in result.values())>24576:
        raise ValueError('boilerplate exceeds24576 bytes total')
    return result

def from_start(frame):
    if not frame.get('boilerplate_file'):return sections(frame.get('boilerplate'),frame.get('authoring_mode','tools'))
    if frame.get('boilerplate') is not None:raise ValueError('select inline OR file boilerplate')
    if frame['boilerplate_file']!='config/boilerplate.json':raise ValueError('invalid boilerplate path')
    root=Path(frame['bridge_root']).resolve(strict=True)
    path=root/'config/boilerplate.json'
    if (root/'config').is_symlink() or path.is_symlink() or not path.resolve(strict=True).is_relative_to(root):
        raise ValueError('boilerplate path escaped session')
    if path.stat().st_size>200000:raise ValueError('boilerplate file capacity exceeded')
    data=path.read_bytes()
    if hashlib.sha256(data).hexdigest()!=frame.get('boilerplate_sha256'):raise ValueError('boilerplate hash mismatch')
    return sections(json.loads(data),frame.get('authoring_mode','tools'))
