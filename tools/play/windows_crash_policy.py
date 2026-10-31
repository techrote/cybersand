"""Versioned watchdogs for the retained-source Windows diagnostic only.

The production-source equality check intentionally keeps this apparatus on the
original crash source. It cannot import the newer main-branch CI policy without
changing the source under investigation. These are execution ceilings, not
performance acceptance thresholds. Deliberately hung adverse controls retain
their short, independently identified deadlines.
"""

POLICY = {
    'schema': 'play-windows-diagnostic-watchdogs-v2',
    'operation_seconds': 300,
    'godot_import_seconds': 1200,
    'complex_fixture_seconds': 3600,
    'hosted_job_minutes': 270,
    'diagnostic_stage_minutes': 180,
    'cleanup_seconds': 10,
    'orphan_control_seconds': 3,
    'hang_control_ms': 500,
    'dump_timeout_control_ms': 15000,
}

OPERATION_SECONDS = POLICY['operation_seconds']
IMPORT_MS = POLICY['godot_import_seconds'] * 1000
FIXTURE_MS = POLICY['complex_fixture_seconds'] * 1000
CAPTURE_MS = OPERATION_SECONDS * 1000
CONTROL_MS = OPERATION_SECONDS * 1000
CLEANUP_SECONDS = POLICY['cleanup_seconds']
ORPHAN_CONTROL_SECONDS = POLICY['orphan_control_seconds']
HANG_CONTROL_MS = POLICY['hang_control_ms']
DUMP_TIMEOUT_CONTROL_MS = POLICY['dump_timeout_control_ms']


def case_limit_ms(name: str, fixture: str) -> int:
    """Keep execution and independent readback on one prescribed inventory."""
    if name == 'control-hang':
        return HANG_CONTROL_MS
    if name == 'control-dump-writer-timeout':
        return DUMP_TIMEOUT_CONTROL_MS
    if name.startswith('control-'):
        return CONTROL_MS
    if name == 'import':
        return IMPORT_MS
    if name == fixture:
        return FIXTURE_MS
    raise ValueError('Unknown diagnostic workload: ' + name)
