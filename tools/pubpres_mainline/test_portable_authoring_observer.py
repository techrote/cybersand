"""Focused controls for compiler-probe observability and sampler race handling."""
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PortableAuthoringObserverTests(unittest.TestCase):
    def test_generated_probe_keeps_bounded_real_assembler_work_observable(self):
        program = r'''
import re, sys
import types
sys.modules['ramcache_strata_lab_package'] = types.ModuleType('ramcache_strata_lab_package')
sys.modules['lab'] = types.ModuleType('lab')
sys.path.insert(0, str(__import__('pathlib').Path(sys.argv[1]) / 'tools/pubpres_mainline'))
from portable_authoring import (PROBE_FUNCTION_COUNT, PROBE_VOLATILE_ASSIGNMENTS_PER_FUNCTION,
                                compiler_probe_source)
source, evidence, expected = compiler_probe_source()
assert evidence['representative_performance_workload'] is False
assert 'as.exe' in evidence['reason']
assert evidence['function_count'] == PROBE_FUNCTION_COUNT == 128
assert evidence['volatile_assignments_per_function'] == PROBE_VOLATILE_ASSIGNMENTS_PER_FUNCTION == 128
assert evidence['volatile_assignment_count'] == 16384
assert evidence['source_bytes'] == len(source.encode('ascii'))
assert 0 < evidence['source_bytes'] < 2_000_000
assert source.count('volatile probe_word value = input;') == PROBE_FUNCTION_COUNT
assert source.count('value = (value + 0x') == PROBE_FUNCTION_COUNT * PROBE_VOLATILE_ASSIGNMENTS_PER_FUNCTION
names = [f'portable_material_probe_{index:03d}' for index in range(PROBE_FUNCTION_COUNT)]
assert all(f'extern "C" probe_word {name}(' in source for name in names)
assert all(f'&{name},' in source for name in names)
mask = (1 << 64) - 1
checksum = 0
for function_index in range(PROBE_FUNCTION_COUNT):
    value = function_index + 17
    for operation_index in range(PROBE_VOLATILE_ASSIGNMENTS_PER_FUNCTION):
        addend = (((function_index + 1) * 0x9E3779B97F4A7C15)
                  + ((operation_index + 1) * 0xBF58476D1CE4E5B9)) & mask
        xor_mask = ((((function_index + 1) * 0x94D049BB133111EB)
                     ^ ((operation_index + 1) * 0xD6E8FEB86659FD93)) & mask)
        value = ((value + addend) & mask) ^ xor_mask
    checksum ^= value
assert expected == f'offline-material-ok:{checksum}'
assert evidence['expected_executable_stdout'] == expected
print('probe-source-controls-passed')
'''
        completed = subprocess.run(
            [sys.executable, "-I", "-B", "-c", program, str(ROOT)], cwd=ROOT,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=30,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
        self.assertEqual(completed.returncode, 0, completed.stderr.decode("utf-8", errors="replace"))
        self.assertIn(b"probe-source-controls-passed", completed.stdout)

    def test_negative_control_accepts_behavior_without_collect2_path_credit(self):
        program = r'''
import sys, types
from pathlib import Path
sys.modules['ramcache_strata_lab_package'] = types.ModuleType('ramcache_strata_lab_package')
sys.modules['lab'] = types.ModuleType('lab')
sys.path.insert(0, str(Path(sys.argv[1]) / 'tools/pubpres_mainline'))
from portable_authoring import _negative_control_attempt_valid, _original_unicode_control
markers = ['collect2.exe: fatal error: cannot find', "'ld'", 'compilation terminated.']
good = {
    'status': 'reproduced_expected_failure_behavior_only',
    'expected_failure_observed': True, 'compiler_exit': 1,
    'expected_failure_markers': markers, 'expected_failure_markers_seen': markers,
    'compiler_stderr': "collect2.exe: fatal error: cannot find 'ld'\\ncompilation terminated.",
    'executable_absent': True, 'expected_absent_processes': ['ld.exe'],
    'expected_absent_processes_observed': [], 'observer_errors': [],
    'compiler_root_observed': True,
    'required_actual_processes_observed': ['as.exe', 'cc1plus.exe', 'g++.exe'],
    'actual_process_paths_inside_bundle': True, 'collect2_path_credit': False,
    'fully_observed_process_chain': False,
}
assert _negative_control_attempt_valid(good)
# If a future sampler catches collect2, retain its real observation while this
# negative-only contract still grants no positive candidate path credit.
observed = {**good, 'collect2_process_observed': True,
            'collect2_observed_paths': ['C:/original/cxx/collect2.exe']}
assert _negative_control_attempt_valid(observed)
for key, value in [
    ('compiler_exit', 0),
    ('expected_absent_processes_observed', ['ld.exe']),
    ('observer_errors', ['snapshot enumeration failed']),
    ('compiler_root_observed', False),
    ('required_actual_processes_observed', ['cc1plus.exe', 'g++.exe']),
    ('actual_process_paths_inside_bundle', False),
    ('collect2_path_credit', True),
    ('fully_observed_process_chain', True),
]:
    assert not _negative_control_attempt_valid({**good, key: value}), key
skipped = _original_unicode_control(Path('unused-parent'), None, None, [])
assert skipped['status'] == 'not_run_prerequisite_failed'
assert skipped['qualification_credit'] == 'none' and skipped['attempts'] == []
mismatched = _original_unicode_control(Path('unused-parent'), None, None, [
    {'label': 'ascii', 'minimal_compile_link_execute': {'source_sha256': 'a' * 64}},
    {'label': 'unicode', 'minimal_compile_link_execute': {'source_sha256': 'b' * 64}},
])
assert mismatched['status'] == 'failed_source_mismatch' and mismatched['attempts'] == []
print('negative-control-contract-controls-passed')
'''
        completed = subprocess.run(
            [sys.executable, "-I", "-B", "-c", program, str(ROOT)], cwd=ROOT,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=30,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
        self.assertEqual(completed.returncode, 0, completed.stderr.decode("utf-8", errors="replace"))
        self.assertIn(b"negative-control-contract-controls-passed", completed.stdout)

    def test_pid_query_races_are_warnings_without_process_credit(self):
        program = r'''
import ctypes, sys, threading
import types
from ctypes import wintypes
from pathlib import Path
sys.modules['ramcache_strata_lab_package'] = types.ModuleType('ramcache_strata_lab_package')
sys.modules['lab'] = types.ModuleType('lab')
sys.path.insert(0, str(Path(sys.argv[1]) / 'tools/pubpres_mainline'))
from portable_authoring import ProcessPathObserver

observer = object.__new__(ProcessPathObserver)
observer.interval_seconds = 0
observer._stop = threading.Event()
observer._lock = threading.Lock()
observer._records = {}
observer._roots = {}
observer._handles = {}
observer._errors = []
observer._sampling_warnings = {}
observer._sampling_warning_overflow = 0
observer.names = {'as.exe'}
snapshots = {'count': 0}

def snapshot(flags, pid):
    snapshots['count'] += 1
    if snapshots['count'] == 2:
        observer._stop.set()
    ctypes.set_last_error(0)
    return 1

def first(handle, entry_pointer):
    entry = ctypes.cast(entry_pointer, ctypes.POINTER(observer.Entry)).contents
    entry.th32ProcessID = 9001
    entry.th32ParentProcessID = 8001
    entry.szExeFile = 'as.exe'
    return 1

def next_entry(handle, entry_pointer):
    ctypes.set_last_error(18)
    return 0

def open_process(access, inherit, pid):
    ctypes.set_last_error(5)
    return 0

observer._snapshot = snapshot
observer._first = first
observer._next = next_entry
observer._open = open_process
observer._close = lambda handle: 1
observer._sample()
assert observer._errors == [], observer._errors
assert observer._records == {}, observer._records
assert len(observer._sampling_warnings) == 1, observer._sampling_warnings
warning = next(iter(observer._sampling_warnings.values()))
assert warning['phase'] == 'OpenProcess'
assert warning['pid'] == 9001
assert warning['image_name'] == 'as.exe'
assert warning['winerror'] == 5
assert warning['count'] == 2

query_race = object.__new__(ProcessPathObserver)
query_race.interval_seconds = 0
query_race._stop = threading.Event()
query_race._lock = threading.Lock()
query_race._records = {}
query_race._roots = {}
query_race._handles = {}
query_race._errors = []
query_race._sampling_warnings = {}
query_race._sampling_warning_overflow = 0
query_race.names = {'as.exe'}
query_snapshots = {'count': 0}
def query_snapshot(flags, pid):
    query_snapshots['count'] += 1
    if query_snapshots['count'] == 2:
        query_race._stop.set()
    ctypes.set_last_error(0)
    return 2
def query_first(handle, entry_pointer):
    entry = ctypes.cast(entry_pointer, ctypes.POINTER(query_race.Entry)).contents
    entry.th32ProcessID = 9002
    entry.th32ParentProcessID = 8001
    entry.szExeFile = 'as.exe'
    return 1
def query_next(handle, entry_pointer):
    ctypes.set_last_error(18)
    return 0
def query_identity(handle, pid, parent_pid):
    raise ctypes.WinError(31)
query_race._snapshot = query_snapshot
query_race._first = query_first
query_race._next = query_next
query_race._open = lambda access, inherit, pid: 77
query_race._identity = query_identity
query_race._close = lambda handle: 1
query_race._sample()
assert query_race._errors == [], query_race._errors
assert query_race._records == {}, query_race._records
query_warning = next(iter(query_race._sampling_warnings.values()))
assert query_warning['phase'] == 'process identity read'
assert query_warning['pid'] == 9002
assert query_warning['winerror'] == 31
assert query_warning['count'] == 2

fatal = object.__new__(ProcessPathObserver)
fatal.interval_seconds = 0
fatal._stop = threading.Event()
fatal._lock = threading.Lock()
fatal._errors = []
fatal._sampling_warnings = {}
fatal._sampling_warning_overflow = 0
def failed_snapshot(flags, pid):
    fatal._stop.set()
    ctypes.set_last_error(5)
    return wintypes.HANDLE(-1).value
fatal._snapshot = failed_snapshot
fatal._close = lambda handle: 1
fatal._sample()
assert fatal._errors and fatal._errors[0].startswith('snapshot enumeration:')
assert fatal._sampling_warnings == {}
print('sampling-race-controls-passed')
'''
        completed = subprocess.run(
            [sys.executable, "-I", "-B", "-c", program, str(ROOT)], cwd=ROOT,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=30,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
        self.assertEqual(completed.returncode, 0, completed.stderr.decode("utf-8", errors="replace"))
        self.assertIn(b"sampling-race-controls-passed", completed.stdout)


if __name__ == "__main__":
    unittest.main()
