"""Sealed Windows comparators and complete portable result contracts.

Pins refer to the already collected Windows records, not values supplied by the
archive under review. JSON canonicalization permits harmless whitespace changes;
it preserves every field, value and type, including provenance and case metadata.
No new collection or independent acceptance is implied by comparison.
"""
import hashlib
import json


# Full result.json and published *-summary.json at 10bab295213c9f7249b9b75276b9fe6126eea1d1.
# Byte seals and collection identities are recorded in the dated review closure.
COMPARATOR_SHA256 = {
    'optional': frozenset((
        'b375c4df75d55a9333bd99f0b19e42005b3629b8d251e53a40a39c251c9e7650',
        'bdea86da525d8db90b17b59bca5247ab83bbaa990aadfb11858bfcbf9571eeb8',
    )),
    'touch': frozenset((
        '950b0428e9bcb97efe396d396845f4c37e0e0829df6a555b3692b5f04e001938',
        '42387dd430c744dd142b000703abff03c6887360559b15e401e31f0df500a937',
    )),
}
OPTIONAL_FIELDS = frozenset('''status timing tail_bits side mode checks cell_size
    cell_alignment tail_element_size tail_element_alignment owner_object_size
    base_capacity_bytes pointer_capacity_bytes tail_array_bytes allocated_owners
    resident_owners dense_tail_arithmetic_bytes nonzero_payloads consumer_reads
    consumer_writes allocations refusals operation_projection_hash logical_hash'''.split())
TOUCH_FIELDS = frozenset('''status timing mode observations native_ticks recoveries
    checks scheduled_cores configured_workers'''.split())
RESULT_FIELDS = {'optional': OPTIONAL_FIELDS, 'touch': TOUCH_FIELDS}
# Only Wasm32's std::vector/unique_ptr representation differs. Linux x86-64 has
# no exceptions. Both excluded Wasm fields are still required and checked below.
WASM_ABI_FIELDS = frozenset(('owner_object_size', 'pointer_capacity_bytes'))


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode('utf-8')


def authenticate_comparator(kind, value):
    if not isinstance(value, dict) or hashlib.sha256(canonical(value)).hexdigest() not in COMPARATOR_SHA256[kind]:
        raise ValueError('unregistered Windows ' + kind + ' comparator identity')


def compare_result(kind, data, windows=None, *, wasm=False):
    fields = RESULT_FIELDS[kind]
    if not isinstance(data, dict) or set(data) != fields:
        raise ValueError(kind + ' result schema: missing or extra fields')
    exceptions = WASM_ABI_FIELDS if wasm and kind == 'optional' else frozenset()
    if windows is not None:
        for key in sorted(fields - exceptions):
            # Canonical JSON also refuses bool/int substitution and changes inside
            # the observation array; Python's True == 1 is insufficient here.
            if canonical(data[key]) != canonical(windows[key]):
                raise ValueError(kind + ' portable result disagreement: ' + key)
    if exceptions:
        if (type(data['owner_object_size']) is not int or data['owner_object_size'] != 72 or
                type(data['pointer_capacity_bytes']) is not int or
                data['pointer_capacity_bytes'] != data['resident_owners'] * 4):
            raise ValueError('Wasm32 owner/pointer accounting')
