"""Independent bit-enumeration reference; imports no candidate or generated maps.
No entry point: importing this module never builds or executes an experiment.
"""
from dataclasses import dataclass

# Explicit reviewed positions rather than candidate mask/offset calculations.
POSITIONS = {
    'K64-E8': (64, tuple(range(56,64)), tuple(range(40,56))),
    'K64-E16': (64, tuple(range(48,64)), ()),
    'K72-E8': (72, tuple(range(56,64)), tuple(range(40,56))),
    'K72-E16': (72, tuple(range(40,56)), tuple(range(56,72))),
    'K80-E8': (80, tuple(range(56,64)), tuple(range(40,56))),
    'K80-E16': (80, tuple(range(40,56)), tuple(range(56,72))),
    'D128-E8': (128, tuple(range(56,64)), tuple(range(40,56))),
    'D128-E16': (128, tuple(range(40,56)), tuple(range(56,72))),
}
@dataclass(frozen=True)
class Record:
    material: int = 0
    a: int = 0
    b: int = 0
    epoch: int = 0
    r: int = 0
    unused: int = 0

def encode(arm, record, *, raw=False):
    capacity, epoch, extension = POSITIONS[arm]
    fields = ((record.material,tuple(range(16))), (record.a,tuple(range(16,32))),
              (record.b,tuple(range(32,40))), (record.epoch,epoch), (record.r,extension))
    occupied = {bit for _, positions in fields for bit in positions}
    unused = tuple(bit for bit in range(capacity) if bit not in occupied)
    if not raw and record.unused:
        raise ValueError('schema-valid records require unused bits zero')
    output = bytearray(capacity//8)
    for value, positions in (*fields,(record.unused,unused)):
        if type(value) is not int or not 0 <= value < (1 << len(positions)):
            raise ValueError('field outside capability/domain')
        for index, bit in enumerate(positions):
            output[bit//8] |= ((value >> index)&1) << (bit%8)
    return bytes(output)

def decode(arm, data):
    capacity, epoch, extension = POSITIONS[arm]
    if len(data) != capacity//8:
        raise ValueError('incorrect canonical byte count')
    fields=(tuple(range(16)),tuple(range(16,32)),tuple(range(32,40)),epoch,extension)
    used={bit for positions in fields for bit in positions}
    fields=(*fields,tuple(bit for bit in range(capacity) if bit not in used))
    return Record(*(sum(((data[bit//8]>>(bit%8))&1)<<i for i,bit in enumerate(positions)) for positions in fields))

def operation(arm, before, name, value=None, *, raw=False):
    """Return logical outcome and expected bytes; refusals retain exact input."""
    from dataclasses import replace
    if name == 'clear':
        after=replace(before,epoch=0)
    elif name == 'replace':
        after=value
    elif name in ('material','a','b','epoch','r','unused'):
        after=replace(before,**{name:value})
    else:
        raise ValueError('unknown oracle operation')
    previous=encode(arm,before,raw=raw)
    try:
        expected=encode(arm,after,raw=raw)
    except ValueError:
        return False,previous
    return True,expected

def check_observation(arm, before, name, value, accepted, observed, *, raw=False):
    outcome,expected=operation(arm,before,name,value,raw=raw)
    if type(accepted) is not bool or accepted != outcome or observed != expected:
        raise ValueError('operation/refusal oracle mismatch')
