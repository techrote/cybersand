#!/usr/bin/env python3
"""Qualify the actual sealed PowerShell -> CMD -> graphical Godot owner launch.

The launcher runs unchanged, without VerifyOnly or a substitute executable. A
private Windows Job owns it before its first instruction, including detached
CMD/Godot descendants. Cleanup never kills by image name or walks unrelated PIDs.
"""
from __future__ import annotations

import ctypes
import importlib.util
import json
import ntpath
import os
from pathlib import Path
import re
import struct
import subprocess
import time
import traceback
import zlib

from seal_owner import sha

ROOT = Path(__file__).resolve().parents[2]
JOB_HELPER = ROOT / 'tools/material_catalogue/process_owner.py'
MARKER = 'SHARED_WORKBENCH_LAUNCH_READY'
TITLE = 'Development workbench'
MAX_SECONDS = 240
STABLE_SECONDS = 10
MAX_LOG_BYTES = 16 * 1024 * 1024
AUDIO_POLICY = 'pinned-godot-4.7-wasapi-dummy-recovery-v1'
AUDIO_PREFIX_GRACE_SECONDS = 2.0
PINNED_ENGINE_HEADER = 'Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org'
STARTUP_ERROR = re.compile(r'(?:^|\s)(?:ERROR:|SCRIPT ERROR:|Parse Error:|Failed to load|Unable to create)')
RECOVERED_AUDIO_BLOCK = (
    'ERROR: Condition "hr != ((HRESULT)0x00000000)" is true. Returning: ERR_CANT_OPEN',
    'at: audio_device_init (drivers/wasapi/audio_driver_wasapi.cpp:275)',
    'ERROR: WASAPI: init_output_device error.',
    'at: init (drivers/wasapi/audio_driver_wasapi.cpp:600)',
    'WARNING: All audio drivers failed, falling back to the dummy driver.',
    'at: initialize (servers/audio/audio_server.cpp:258)',
)


def windows_powershell_env(environment: dict[str, str] | None = None) -> dict[str, str]:
    # pwsh -> Python -> powershell.exe otherwise inherits PS7 module locations.
    # Let Windows PowerShell construct its own defaults in this child only.
    return {key: value for key, value in (os.environ if environment is None else environment).items()
            if key.casefold() != 'psmodulepath'}


def same_path(left: str, right: str) -> bool:
    return ntpath.normcase(ntpath.normpath(left)) == ntpath.normcase(ntpath.normpath(right))


def failure_details(error: Exception, phase: dict, observer_context: dict) -> dict:
    """Retain the original failure; diagnostics never change gate admission."""
    return {'type': type(error).__module__ + '.' + type(error).__qualname__,
            'errno': getattr(error, 'errno', None), 'winerror': getattr(error, 'winerror', None),
            'phase': dict(phase), 'observer': dict(observer_context),
            'traceback': ''.join(traceback.format_exception(type(error), error, error.__traceback__))}


def owner_command(argv: list[str], engine: str, project: str) -> bool:
    if not isinstance(argv, list) or not all(isinstance(x, str) for x in argv) or not argv:
        return False
    if not same_path(argv[0], engine) or argv.count('--path') != 1 or argv.count('--') != 1:
        return False
    index = argv.index('--path')
    if index + 1 >= len(argv) or not same_path(argv[index + 1], project):
        return False
    if any(x in argv for x in ('--headless', '--editor', '-e', '--script', '-s', '--quit', '--quit-after')):
        return False
    return argv[argv.index('--') + 1:] == ['--workbench']


def evidence_errors(report: dict) -> list[str]:
    errors = []
    if (report.get('schema') != 2 or report.get('audio_diagnostic_policy') != AUDIO_POLICY
            or report.get('audio_prefix_grace_seconds') != AUDIO_PREFIX_GRACE_SECONDS):
        errors.append('the explicit recovered-audio observation policy is required')
    if report.get('platform') != 'Windows' or report.get('verify_only') is not False:
        errors.append('actual Windows owner dispatch is required')
    if report.get('launcher_returncode') != 0 or report.get('verified_source_logged') is not True:
        errors.append('source-bound PowerShell launcher did not finish verification and dispatch')
    if report.get('owned_before_resume') is not True or report.get('job_empty_after_retirement') is not True:
        errors.append('the private launcher process tree was not owned and fully retired')
    window = report.get('window', {})
    if (window.get('visible') is not True or window.get('responsive') is not True
            or TITLE not in window.get('title', '') or window.get('width', 0) < 640 or window.get('height', 0) < 360
            or report.get('stable_seconds', 0) < STABLE_SECONDS or window.get('job_member') is not True):
        errors.append('source-bound Godot did not sustain a responsive visible Workbench window')
    if not owner_command(report.get('godot_argv', []), report.get('expected_engine', ''), report.get('expected_project', '')):
        errors.append('the actual packaged graphical Workbench command was not observed')
    if (report.get('launch_marker_observed') is not True or report.get('initialization_errors') != []
            or report.get('pending_audio_diagnostics') != []):
        errors.append('Workbench entry marker is missing or startup reported an error')
    recovered = report.get('recovered_audio_diagnostics')
    covered = []
    if not isinstance(recovered, list):
        errors.append('recovered audio diagnostics must be retained explicitly')
    else:
        for item in recovered:
            lines = item.get('raw_lines', []) if isinstance(item, dict) else []
            if (not all(isinstance(line, str) for line in lines)
                    or tuple(line.strip() for line in lines) != RECOVERED_AUDIO_BLOCK
                    or item.get('engine') != PINNED_ENGINE_HEADER
                    or not isinstance(item.get('source_log'), str) or not item['source_log']
                    or type(item.get('start_line')) is not int or item['start_line'] < 1):
                errors.append('unrecognized recovered audio diagnostic')
            else:
                covered.extend((lines[0], lines[2]))
    if report.get('raw_initialization_errors') != covered:
        errors.append('raw startup errors are not fully accounted for by the exact recovered audio blocks')
    screenshot = report.get('screenshot', {})
    if (screenshot.get('distinct_sampled_colors', 0) < 32 or not re.fullmatch('[0-9a-f]{64}', screenshot.get('sha256', ''))
            or screenshot.get('width', 0) < 640 or screenshot.get('height', 0) < 360):
        errors.append('a nonblank original graphical window capture is required')
    for key in ('engine_sha256', 'native_sha256', 'reciprocal_cli_sha256', 'manifest_sha256'):
        if not re.fullmatch('[0-9a-f]{64}', report.get(key, '')) or report.get(key) != report.get('expected_' + key):
            errors.append('post-boot source/binary custody missing or mismatched: ' + key)
    return errors


class WindowsObserver:
    def __init__(self, job) -> None:
        from ctypes import wintypes as w
        self.w, self.job = w, job
        self.failure_context = {}
        self.kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        self.user = ctypes.WinDLL('user32', use_last_error=True)
        self.gdi = ctypes.WinDLL('gdi32', use_last_error=True)
        self.shell = ctypes.WinDLL('shell32', use_last_error=True)
        self.callback = ctypes.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
        signatures = {
            'QueryInformationJobObject': (self.kernel, [w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD, ctypes.c_void_p], w.BOOL),
            'OpenProcess': (self.kernel, [w.DWORD, w.BOOL, w.DWORD], w.HANDLE),
            'CloseHandle': (self.kernel, [w.HANDLE], w.BOOL),
            'QueryFullProcessImageNameW': (self.kernel, [w.HANDLE, w.DWORD, w.LPWSTR, ctypes.POINTER(w.DWORD)], w.BOOL),
            'GetProcessTimes': (self.kernel, [w.HANDLE] + [ctypes.POINTER(w.FILETIME)] * 4, w.BOOL),
            'IsProcessInJob': (self.kernel, [w.HANDLE, w.HANDLE, ctypes.POINTER(w.BOOL)], w.BOOL),
            'EnumWindows': (self.user, [self.callback, w.LPARAM], w.BOOL),
            'GetWindowThreadProcessId': (self.user, [w.HWND, ctypes.POINTER(w.DWORD)], w.DWORD),
            'GetWindowTextW': (self.user, [w.HWND, w.LPWSTR, ctypes.c_int], ctypes.c_int),
            'IsWindowVisible': (self.user, [w.HWND], w.BOOL),
            'GetWindowRect': (self.user, [w.HWND, ctypes.POINTER(w.RECT)], w.BOOL),
            'SendMessageTimeoutW': (self.user, [w.HWND, w.UINT, w.WPARAM, w.LPARAM, w.UINT, w.UINT, ctypes.POINTER(ctypes.c_size_t)], ctypes.c_ssize_t),
            'SetForegroundWindow': (self.user, [w.HWND], w.BOOL),
            'SetWindowPos': (self.user, [w.HWND, w.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, w.UINT], w.BOOL),
            'GetSystemMetrics': (self.user, [ctypes.c_int], ctypes.c_int),
            'GetDC': (self.user, [w.HWND], w.HDC),
            'ReleaseDC': (self.user, [w.HWND, w.HDC], ctypes.c_int),
            'CreateCompatibleDC': (self.gdi, [w.HDC], w.HDC),
            'CreateDIBSection': (self.gdi, [w.HDC, ctypes.c_void_p, w.UINT, ctypes.POINTER(ctypes.c_void_p), w.HANDLE, w.DWORD], w.HANDLE),
            'SelectObject': (self.gdi, [w.HDC, w.HANDLE], w.HANDLE),
            'BitBlt': (self.gdi, [w.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, w.HDC, ctypes.c_int, ctypes.c_int, w.DWORD], w.BOOL),
            'DeleteObject': (self.gdi, [w.HANDLE], w.BOOL),
            'DeleteDC': (self.gdi, [w.HDC], w.BOOL),
            'GdiFlush': (self.gdi, [], w.BOOL),
            'CommandLineToArgvW': (self.shell, [w.LPCWSTR, ctypes.POINTER(ctypes.c_int)], ctypes.POINTER(w.LPWSTR)),
            'LocalFree': (self.kernel, [w.HANDLE], w.HANDLE),
        }
        for name, (api, arguments, result) in signatures.items():
            function = getattr(api, name);function.argtypes, function.restype = arguments, result
        self.user.SetProcessDPIAware()

    def api_failure(self, api: str, **context) -> OSError:
        # Capture the failure before CloseHandle or EnumWindows can alter the
        # thread's last-error value. Keep the original Windows exception class.
        code = ctypes.get_last_error()
        self.failure_context = {'api': api, **context, 'winerror': code}
        return ctypes.WinError(code)

    def members(self) -> list[int]:
        # Microsoft JobObjectBasicProcessIdList includes live child-job members.
        # Fail closed instead of silently truncating an unexpected process tree.
        class Members(ctypes.Structure):
            _fields_ = [('assigned', self.w.DWORD), ('count', self.w.DWORD), ('pids', ctypes.c_size_t * 64)]
        value = Members()
        if not self.kernel.QueryInformationJobObject(self.job._handle, 3, ctypes.byref(value), ctypes.sizeof(value), None):
            raise self.api_failure('QueryInformationJobObject')
        if value.assigned != value.count or value.count > 64:
            raise ValueError('Owner launch exceeds bounded process observation capacity')
        return [int(value.pids[index]) for index in range(value.count)]

    def process(self, pid: int) -> dict | None:
        handle = self.kernel.OpenProcess(0x1000, False, pid)  # QUERY_LIMITED_INFORMATION
        if not handle: return None  # A short-lived import/launcher may already have retired.
        try:
            member = self.w.BOOL()
            if not self.kernel.IsProcessInJob(handle, self.job._handle, ctypes.byref(member)) or not member.value:
                return None
            path = ctypes.create_unicode_buffer(32768);size = self.w.DWORD(len(path))
            times = [self.w.FILETIME() for _ in range(4)]
            if not self.kernel.QueryFullProcessImageNameW(handle, 0, path, ctypes.byref(size)):
                raise self.api_failure('QueryFullProcessImageNameW', pid=pid)
            if not self.kernel.GetProcessTimes(handle, *(ctypes.byref(value) for value in times)):
                raise self.api_failure('GetProcessTimes', pid=pid)
            return {'pid': pid, 'image': path.value, 'created_filetime': (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime, 'job_member': True}
        finally:
            self.kernel.CloseHandle(handle)

    def windows(self, pids: list[int], engine: Path) -> list[dict]:
        found = [];failures = []
        @self.callback
        def observe(hwnd, _):
            pid = self.w.DWORD()
            try:
                self.user.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                if pid.value not in pids or not self.user.IsWindowVisible(hwnd): return True
                process = self.process(pid.value)
                if process is None or not same_path(process['image'], str(engine)): return True
                title = ctypes.create_unicode_buffer(512);self.user.GetWindowTextW(hwnd, title, len(title))
                rect = self.w.RECT();response = ctypes.c_size_t()
                if not self.user.GetWindowRect(hwnd, ctypes.byref(rect)): return True
                responsive = bool(self.user.SendMessageTimeoutW(hwnd, 0, 0, 0, 2, 500, ctypes.byref(response)))  # WM_NULL, SMTO_ABORTIFHUNG
                found.append({**process, 'hwnd': int(hwnd), 'title': title.value, 'visible': True, 'responsive': responsive,
                              'left': rect.left, 'top': rect.top, 'width': rect.right - rect.left, 'height': rect.bottom - rect.top})
                return True
            except Exception as error:
                # ctypes callbacks cannot propagate Python exceptions through
                # User32. Retain the same exception and raise it after enumeration.
                self.failure_context = {'callback': 'EnumWindowsProc', 'hwnd': int(hwnd),
                                        'pid': int(pid.value), **self.failure_context}
                failures.append(error);return False
        completed = self.user.EnumWindows(observe, 0)
        if failures: raise failures[0]
        if not completed: raise self.api_failure('EnumWindows')
        return found

    def foreground(self, window: dict) -> None:
        # Resize only the owned test window to fit this runner's physical desktop.
        width = min(1600, self.user.GetSystemMetrics(78) - 40)
        height = min(900, self.user.GetSystemMetrics(79) - 80)
        x, y = self.user.GetSystemMetrics(76) + 20, self.user.GetSystemMetrics(77) + 20
        if width < 640 or height < 360: raise ValueError('Windows runner has no usable graphical desktop')
        if not self.user.SetWindowPos(window['hwnd'], None, x, y, width, height, 0x0040):
            raise self.api_failure('SetWindowPos', pid=window['pid'], hwnd=window['hwnd'])
        self.user.SetForegroundWindow(window['hwnd'])

    def argv(self, pid: int) -> tuple[list[str], dict]:
        script = f"Get-CimInstance Win32_Process -Filter 'ProcessId={pid}' | Select-Object ProcessId,ParentProcessId,ExecutablePath,CommandLine | ConvertTo-Json -Compress"
        value = subprocess.run(['powershell.exe', '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script],
                               capture_output=True, text=True, timeout=20, check=True, env=windows_powershell_env())
        process = json.loads(value.stdout)
        count = ctypes.c_int();arguments = self.shell.CommandLineToArgvW(process['CommandLine'], ctypes.byref(count))
        if not arguments: raise self.api_failure('CommandLineToArgvW', pid=pid)
        try: return [arguments[index] for index in range(count.value)], process
        finally: self.kernel.LocalFree(arguments)

    def screenshot(self, window: dict, path: Path) -> dict:
        rect = self.w.RECT()
        if not self.user.GetWindowRect(window['hwnd'], ctypes.byref(rect)):
            raise self.api_failure('GetWindowRect', pid=window['pid'], hwnd=window['hwnd'])
        width, height = rect.right - rect.left, rect.bottom - rect.top
        if not 640 <= width <= 2560 or not 360 <= height <= 1440:
            raise ValueError('Owned window screenshot exceeds its declared bounds')
        # Top-down 32-bit RGB DIB, copied from the actual visible desktop.
        header = ctypes.create_string_buffer(struct.pack('<IiiHHIIiiII', 40, width, -height, 1, 32, 0, width * height * 4, 0, 0, 0, 0))
        screen = self.user.GetDC(None);memory = self.gdi.CreateCompatibleDC(screen)
        bits = ctypes.c_void_p();bitmap = self.gdi.CreateDIBSection(screen, header, 0, ctypes.byref(bits), None, 0)
        previous = None
        try:
            if not screen or not memory or not bitmap or not bits.value:
                raise self.api_failure('GetDC/CreateCompatibleDC/CreateDIBSection', pid=window['pid'], hwnd=window['hwnd'],
                                       screen_created=bool(screen), memory_created=bool(memory), bitmap_created=bool(bitmap),
                                       pixels_created=bool(bits.value))
            previous = self.gdi.SelectObject(memory, bitmap)
            if not self.gdi.BitBlt(memory, 0, 0, width, height, screen, rect.left, rect.top, 0x40CC0020):  # SRCCOPY | CAPTUREBLT
                raise self.api_failure('BitBlt', pid=window['pid'], hwnd=window['hwnd'])
            self.gdi.GdiFlush()
            bgra = ctypes.string_at(bits, width * height * 4)
            rgb = bytearray(width * height * 3);rgb[0::3] = bgra[2::4];rgb[1::3] = bgra[1::4];rgb[2::3] = bgra[0::4]
            raw = b''.join(b'\0' + rgb[y * width * 3:(y + 1) * width * 3] for y in range(height))
            def chunk(kind, data):
                return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
            path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                             + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
            step = max(1, width * height // 8192)
            colors = len({bytes(rgb[index * 3:index * 3 + 3]) for index in range(0, width * height, step)})
            return {'file': path.name, 'sha256': sha(path), 'width': width, 'height': height, 'distinct_sampled_colors': colors}
        finally:
            if previous: self.gdi.SelectObject(memory, previous)
            if bitmap: self.gdi.DeleteObject(bitmap)
            if memory: self.gdi.DeleteDC(memory)
            if screen: self.user.ReleaseDC(None, screen)


def classify_startup_logs(logs: dict[str, str]) -> dict:
    raw, fatal, recovered, pending = [], [], [], []
    for name, text in logs.items():
        lines = text.splitlines();clean = [line.strip() for line in lines]
        covered = set();waiting = set();engine = ''
        for index, line in enumerate(clean):
            if line.startswith('Godot Engine '): engine = line
            if engine != PINNED_ENGINE_HEADER or not line or not RECOVERED_AUDIO_BLOCK[0].startswith(line): continue
            block = clean[index:index + len(RECOVERED_AUDIO_BLOCK)]
            record = {'source_log': name, 'start_line': index + 1, 'engine': engine,
                      'raw_lines': lines[index:index + len(RECOVERED_AUDIO_BLOCK)]}
            if tuple(block) == RECOVERED_AUDIO_BLOCK:
                recovered.append({**record, 'reason': 'pinned engine explicitly recovered unavailable WASAPI output through Dummy audio'})
                covered.update((index, index + 2))
                continue
            # Only an exact sequence prefix at EOF may be a partial file flush.
            # A different stack/error, another boot or another file cannot qualify.
            if (len(clean) - index <= len(RECOVERED_AUDIO_BLOCK)
                    and all((expected.startswith(actual) if index + offset == len(clean) - 1
                             and not text.endswith(('\n', '\r')) else actual == expected)
                            for offset, (actual, expected) in enumerate(zip(block, RECOVERED_AUDIO_BLOCK)))):
                pending.append({**record, 'reason': 'incomplete pinned WASAPI/Dummy sequence; no recovery accepted yet'})
                waiting.update(range(index, len(lines)))
        for index, line in enumerate(lines):
            if STARTUP_ERROR.search(line):
                raw.append(line)
                if index not in covered and index not in waiting: fatal.append(line)
    return {'raw_initialization_errors': raw, 'initialization_errors': fatal,
            'recovered_audio_diagnostics': recovered, 'pending_audio_diagnostics': pending}


def read_logs(profile: Path, launcher_log: Path) -> tuple[dict[str, str], dict]:
    paths = [launcher_log, *sorted(profile.rglob('godot*.log'))]
    if len(paths) > 32: raise ValueError('Owner launch exceeds bounded log inventory')
    logs = {}
    for path in paths:
        if not path.exists(): continue
        if path.stat().st_size > MAX_LOG_BYTES: raise ValueError('Owner launch exceeded bounded log size: ' + str(path))
        logs[str(path)] = path.read_text(encoding='utf-8', errors='replace')
    return logs, classify_startup_logs(logs)


def qualify(launcher: Path, archive: Path, destination: Path, output: Path, source: str, metadata: dict) -> dict:
    if os.name != 'nt': raise OSError('Actual owner dispatch requires Windows')
    if destination.exists() or output.exists(): raise ValueError('Owner dispatch requires fresh output and extraction paths')
    output.mkdir(parents=True)
    profile = output / 'isolated profile with spaces';env = windows_powershell_env()
    for key, name in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local'), ('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
        path = profile / name;path.mkdir(parents=True);env[key] = str(path)
    for key in list(env):
        if key.startswith('SWARM004_UI_') or key.startswith('CYBERSAND_SWARM004_'): env.pop(key)
    command = ['powershell.exe', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(launcher),
               '-Archive', str(archive), '-Destination', str(destination)]
    engine, project = destination / 'Godot_v4.7-stable_win64.exe', destination / 'godot'
    log_path = output / 'owner-dispatch.log'
    report = {'schema': 2, 'source_commit': source, 'platform': 'Windows', 'verify_only': False,
              'audio_diagnostic_policy': AUDIO_POLICY, 'audio_prefix_grace_seconds': AUDIO_PREFIX_GRACE_SECONDS,
              'scope': 'actual owner PowerShell/CMD dispatch and graphical Workbench boot; native Apply qualification separate',
              'command': command, 'timeout_seconds': MAX_SECONDS, 'stable_required_seconds': STABLE_SECONDS,
              'expected_engine': str(engine), 'expected_project': str(project), 'archive_sha256': metadata['archive_sha256'],
              'launcher_sha256': sha(launcher), 'test_sha256': sha(Path(__file__)), 'job_helper_sha256': sha(JOB_HELPER),
              'owned_before_resume': False, 'job_empty_after_retirement': False, 'passed': False,
              'owner_nvidia_acceptance': 'pending', 'observed_processes': [], 'initialization_errors': [],
              'raw_initialization_errors': [], 'recovered_audio_diagnostics': [], 'pending_audio_diagnostics': []}
    specification = importlib.util.spec_from_file_location('swarm006_owned_process', JOB_HELPER)
    module = importlib.util.module_from_spec(specification);specification.loader.exec_module(module)
    owner = module.WindowsJob();observer = WindowsObserver(owner);process = None;started = time.monotonic()
    phase = {'stage': 'launch_owner_process'}
    try:
        with log_path.open('w', encoding='utf-8') as log:
            process = subprocess.Popen(command, cwd=output, env=env, stdout=log, stderr=log, stdin=subprocess.DEVNULL,
                                       creationflags=module.CREATE_SUSPENDED | subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW)
            report['launcher_pid'] = process.pid
            phase = {'stage': 'establish_job_ownership', 'pid': process.pid}
            owner.assign_and_resume(process);report['owned_before_resume'] = True
            deadline = started + MAX_SECONDS;stable_since = None;stable_identity = None;known = {};audio_pending_since = None
            while time.monotonic() < deadline:
                phase = {'stage': 'query_job_members'}
                members = observer.members()
                for pid in members:
                    phase = {'stage': 'observe_owned_process', 'pid': pid}
                    identity = observer.process(pid)
                    if identity: known[(pid, identity['created_filetime'])] = identity
                if len(known) > 64: raise ValueError('Owner dispatch exceeds bounded process history')
                report['observed_processes'] = list(known.values())
                phase = {'stage': 'read_startup_logs'}
                logs, diagnostics = read_logs(profile, log_path);report.update(diagnostics)
                if diagnostics['initialization_errors']: raise ValueError('Actual owner launch reported initialization errors')
                if diagnostics['pending_audio_diagnostics']:
                    if audio_pending_since is None: audio_pending_since = time.monotonic()
                    if time.monotonic() - audio_pending_since > AUDIO_PREFIX_GRACE_SECONDS:
                        raise ValueError('Incomplete audio recovery exceeded the bounded log-flush grace')
                else:
                    audio_pending_since = None
                phase = {'stage': 'inspect_owner_exit', 'pid': process.pid}
                if process.poll() not in (None, 0): raise ValueError('Owner PowerShell launcher failed')
                phase = {'stage': 'enumerate_owned_windows'}
                windows = [w for w in observer.windows(members, engine) if TITLE in w['title'] and w['responsive']]
                if len(windows) > 1: raise ValueError('Owner launch created ambiguous Workbench windows')
                if windows and any(MARKER in text for text in logs.values()) and not diagnostics['pending_audio_diagnostics']:
                    window = windows[0];identity = (window['pid'], window['created_filetime'], window['hwnd'])
                    if identity != stable_identity:
                        phase = {'stage': 'place_workbench_window', 'pid': window['pid'], 'hwnd': window['hwnd']}
                        observer.foreground(window);stable_identity = identity;stable_since = time.monotonic()
                    report['window'] = window
                    report['stable_seconds'] = time.monotonic() - stable_since
                    if report['stable_seconds'] >= STABLE_SECONDS and process.poll() == 0:
                        phase = {'stage': 'inspect_graphical_command', 'pid': window['pid'], 'hwnd': window['hwnd']}
                        report['godot_argv'], report['godot_cim'] = observer.argv(window['pid'])
                        phase = {'stage': 'verify_graphical_process_identity', 'pid': window['pid'], 'hwnd': window['hwnd']}
                        current = observer.process(window['pid'])
                        if not current or current['created_filetime'] != window['created_filetime']:
                            raise ValueError('Observed Godot identity changed during command inspection')
                        if not same_path(report['godot_cim']['ExecutablePath'], str(engine)):
                            raise ValueError('CIM executable differs from the sealed graphical Godot')
                        phase = {'stage': 'capture_workbench_window', 'pid': window['pid'], 'hwnd': window['hwnd']}
                        report['screenshot'] = observer.screenshot(window, output / 'owner-workbench-window.png')
                        break
                else:
                    stable_since = None;stable_identity = None
                if process.poll() is not None and not members: raise ValueError('Owner launch retired without a graphical Workbench')
                time.sleep(.25)
            else:
                raise TimeoutError('Actual owner dispatch did not reach a stable graphical Workbench in its bounded time')
            phase = {'stage': 'verify_extracted_runtime'}
            manifest_path = destination / 'candidate-manifest.json'
            manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
            if manifest['source_commit'] != source: raise ValueError('Extracted source changed after owner verification')
            report.update(engine_sha256=sha(engine), expected_engine_sha256=manifest['files_sha256'][engine.name],
                          native_sha256=sha(project / 'addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'),
                          expected_native_sha256=manifest['native_sha256'],
                          reciprocal_cli_sha256=sha(project / 'tools/gentek_reciprocal.exe'),
                          expected_reciprocal_cli_sha256=manifest['reciprocal_cli_sha256'],
                          manifest_sha256=sha(manifest_path), expected_manifest_sha256=metadata['manifest_sha256'])
    except Exception as error:
        report['failure'] = str(error)
        report['failure_details'] = failure_details(error, phase, observer.failure_context)
    finally:
        try:
            # The job, not a guessed PID tree, owns every Start-Process/start child.
            owner.terminate()
            if process is not None:
                if not report['owned_before_resume']: process.kill()  # Still suspended; no child code ran.
                process.wait(timeout=15);report['launcher_returncode'] = process.returncode
            until = time.monotonic() + 15
            while observer.members() and time.monotonic() < until: time.sleep(.1)
            report['remaining_owned_pids'] = observer.members()
            report['job_empty_after_retirement'] = not report['remaining_owned_pids']
        except Exception as error:
            report['cleanup_failure'] = str(error)
        finally:
            try: owner.close()
            except Exception as error: report['cleanup_failure'] = str(error)
        try:
            logs, diagnostics = read_logs(profile, log_path);report.update(diagnostics)
            report['logs_sha256'] = {str(Path(path).relative_to(output)): sha(Path(path)) for path in logs}
            report['launch_marker_observed'] = any(MARKER in text for text in logs.values())
            report['verified_source_logged'] = f'Verified GENTEK-SWARM-006 source {source};' in logs.get(str(log_path), '')
        except Exception as error:
            report['log_failure'] = str(error)
        report['wall_seconds'] = round(time.monotonic() - started, 3)
        report['validation_errors'] = evidence_errors(report)
        report['passed'] = not report['validation_errors'] and not any(key in report for key in ('failure', 'cleanup_failure', 'log_failure'))
        (output / 'owner-dispatch-qualification.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return report
