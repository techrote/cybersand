"""Domains of Godot IDs as represented by the observed PackedInt64Arrays.

Godot 4.7 ObjectID stores uint64_t, marks RefCounted with bit 63, defines valid
as nonzero, and converts to int64_t for Variant. ImageTexture ObjectIDs can
therefore be negative in JSON. RID observations use their separate positive
signed-integer domain. Neither function confuses Python bool with an integer.
"""


def object_id(value) -> bool:
    return type(value) is int and -(1 << 63) <= value < (1 << 63) and value != 0


def texture_rid(value) -> bool:
    return type(value) is int and 0 < value < (1 << 63)
