"""Deterministic DXBC statistics via D3DDisassemble: instruction count and key opcode counts.
usage: dxbc_stats.py <file.dxbc> [...]"""
import ctypes as C, os, re, sys, json, collections

d = C.WinDLL(os.path.join(os.environ['SystemRoot'], 'System32', 'd3dcompiler_47.dll'))


def blob_bytes(b):
    vt = C.cast(C.cast(b, C.POINTER(C.c_void_p))[0], C.POINTER(C.c_void_p))
    ptr = C.WINFUNCTYPE(C.c_void_p, C.c_void_p)(vt[3])(b)
    size = C.WINFUNCTYPE(C.c_size_t, C.c_void_p)(vt[4])(b)
    return C.string_at(ptr, size)


for path in sys.argv[1:]:
    data = open(path, 'rb').read()
    out = C.c_void_p()
    hr = d.D3DDisassemble(data, len(data), 0, None, C.byref(out))
    text = blob_bytes(out).decode(errors='replace') if out.value else ''
    ops = collections.Counter()
    for line in text.splitlines():
        m = re.match(r'\s*([a-z_0-9]+)(?:_sat)?[\s(]', line)
        if m and not line.lstrip().startswith(('//', 'dcl_', 'ps_', 'vs_')):
            ops[m.group(1)] += 1
    m = re.search(r'// Approximately (\d+) instruction slots used', text)
    print(json.dumps({'file': os.path.basename(path), 'hr': hex(hr & 0xffffffff), 'slots': int(m.group(1)) if m else None,
                      'instructions': sum(ops.values()),
                      'sample': sum(v for k, v in ops.items() if k.startswith('sample')),
                      'if': ops['if_nz'] + ops['if_z'], 'loop': ops['loop'], 'switch': ops['switch'], 'movc': ops['movc']}))
