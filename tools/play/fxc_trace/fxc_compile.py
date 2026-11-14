"""Offline D3DCompile timing of captured ANGLE HLSL with ANGLE's flags.
usage: fxc.py <file.hlsl> [--flags 0xc000] [--entry main] [--target ps_5_0] [--define K=V ...] [--repeat N]"""
import ctypes as C, ctypes.wintypes as W, sys, time, argparse, json, hashlib, os

p = argparse.ArgumentParser()
p.add_argument('hlsl')
p.add_argument('--flags', default='0xc000')
p.add_argument('--flags2', default='0')
p.add_argument('--entry', default='main')
p.add_argument('--target', default='ps_5_0')
p.add_argument('--define', action='append', default=None)
p.add_argument('--repeat', type=int, default=1)
p.add_argument('--out')
p.add_argument('--errors', action='store_true')
a = p.parse_args()
if a.define is None:
    a.define = ['ANGLE_ENABLE_LOOP_FLATTEN=1']
d = C.WinDLL(os.path.join(os.environ['SystemRoot'], 'System32', 'd3dcompiler_47.dll'))
_k32 = C.WinDLL('kernel32')
_k32.SetPriorityClass(_k32.GetCurrentProcess(), 0x80)  # HIGH_PRIORITY_CLASS: reduce desktop interference


class MACRO(C.Structure):
    _fields_ = [('Name', C.c_char_p), ('Definition', C.c_char_p)]


pairs = [x.split('=', 1) for x in a.define if x]
defs = (MACRO * (len(pairs) + 1))(*[MACRO(k.encode(), v.encode()) for k, v in pairs], MACRO(None, None))
src = open(a.hlsl, 'rb').read()


def blob_bytes(b):
    vt = C.cast(C.cast(b, C.POINTER(C.c_void_p))[0], C.POINTER(C.c_void_p))
    ptr = C.WINFUNCTYPE(C.c_void_p, C.c_void_p)(vt[3])(b)
    size = C.WINFUNCTYPE(C.c_size_t, C.c_void_p)(vt[4])(b)
    return C.string_at(ptr, size)


for i in range(a.repeat):
    code = C.c_void_p()
    err = C.c_void_p()
    t0 = time.perf_counter()
    c0 = time.thread_time()
    hr = d.D3DCompile(src, len(src), b'palette', defs, None, a.entry.encode(), a.target.encode(),
                      int(a.flags, 0), int(a.flags2, 0), C.byref(code), C.byref(err))
    cpu = time.thread_time() - c0
    wall = time.perf_counter() - t0
    msg = blob_bytes(err).decode(errors='replace') if err.value else ''
    out = blob_bytes(code) if code.value else b''
    if a.out and out:
        open(a.out, 'wb').write(out)
    row = {'hlsl': os.path.basename(a.hlsl), 'hr': hex(hr & 0xffffffff), 'wall': round(wall, 3), 'cpu': round(cpu, 3),
           'bytes': len(src), 'dxbc': len(out), 'dxbc_sha': hashlib.sha256(out).hexdigest()[:16] if out else None,
           'warnings': msg.count('warning'), 'flags': a.flags}
    if hr or a.errors:
        row['messages'] = msg[:2000]
    print(json.dumps(row), flush=True)
