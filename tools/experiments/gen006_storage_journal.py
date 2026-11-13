"""G6J1 experimental, bounded, synchronous, single-owner edit journal.

Standalone storage primitive for GEN-006 #194. NOT integrated with #486, not
production-safe streaming or general physics persistence. Supported only for
edits in a frozen native-tick epoch; caller stages, validates and replays edits
in a private native World. No ACK is permitted before append() returns.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import struct
import tempfile
import zlib
from dataclasses import dataclass
from typing import Callable

HEADER = struct.Struct('<4sqqQQQQIII')  # 64 bytes
EDIT = struct.Struct('<4sQQQBBBBHhQI')  # 48 bytes
MAX_CHECKPOINT = 2_097_152
MAX_EDITS = 4_096
MAX_BATCH = 64
MAGIC = b'G6J1'
KINDS = {1, 2, 3, 4}  # Wall, Dig, Water, WaterTemp


def require(condition: bool, error: str) -> None:
    if not condition:
        raise ValueError(error)


def crc(data: bytes) -> int:
    return zlib.crc32(data) & 0xffffffff


def chain(data: bytes, prior: int = 0) -> int:
    return int.from_bytes(hashlib.blake2b(prior.to_bytes(8, 'little') + data,
                                        digest_size=8).digest(), 'little')


def sync_dir(directory: Path) -> None:
    if os.name != 'nt':
        fd = os.open(directory, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0))
        try:
            os.fsync(fd)
        finally:
            os.close(fd)


@dataclass(frozen=True)
class Identity:
    x: int
    y: int
    incarnation: int
    generation: int
    tick: int
    physical_hash: int


@dataclass(frozen=True)
class Mutation:
    kind: int
    x: int
    y: int
    amount: int
    temperature: int
    generation: int
    tick: int
    physical_hash: int

    def validate(self) -> None:
        require(self.kind in KINDS, 'G6J_KIND_REFUSED')
        require(0 <= self.x < 64 and 0 <= self.y < 64,
                'G6J_COORD_REFUSED')
        require(0 <= self.amount <= 65535 and -32768 <= self.temperature <= 32767,
                'G6J_PAYLOAD_REFUSED')
        require(self.kind in (3, 4) or (self.amount == 0 and self.temperature == 0),
                'G6J_NONWATER_PAYLOAD_REFUSED')


@dataclass(frozen=True)
class Recovery:
    identity: Identity
    checkpoint: bytes
    edits: tuple[Mutation, ...]
    valid_length: int
    tail_chain: int
    torn_tail: bool

    @property
    def generation(self) -> int:
        return self.edits[-1].generation if self.edits else self.identity.generation


def _recover_bytes(raw: bytes) -> Recovery:
    require(HEADER.size <= len(raw) <= HEADER.size + MAX_CHECKPOINT +
            MAX_EDITS * EDIT.size, 'G6J_FILE_LENGTH_REFUSED')
    magic, x, y, inc, gen, tick, physical_hash, length, base_crc, head_crc = HEADER.unpack_from(raw)
    require(magic == MAGIC and crc(raw[:HEADER.size - 4]) == head_crc and inc != 0,
            'G6J_HEADER_REFUSED')
    require(0 < length <= MAX_CHECKPOINT and length <= len(raw) - HEADER.size,
            'G6J_CHECKPOINT_LENGTH_REFUSED')
    base = raw[HEADER.size:HEADER.size + length]
    require(crc(base) == base_crc, 'G6J_CHECKPOINT_CRC_REFUSED')
    cursor = HEADER.size + length
    prev = chain(raw[:cursor])
    edits: list[Mutation] = []
    torn = False
    while cursor < len(raw):
        if len(raw) - cursor < EDIT.size:
            torn = True
            break
        require(len(edits) < MAX_EDITS, 'G6J_MAX_EDITS_REFUSED')
        frame = raw[cursor:cursor + EDIT.size]
        tag, next_gen, edit_tick, digest, kind, lx, ly, reserved, amount, temp, prior, checksum = EDIT.unpack(frame)
        require(tag == b'EDIT' and reserved == 0 and prior == prev and
                crc(frame[:-4]) == checksum, 'G6J_EDIT_INTEGRITY_REFUSED')
        edit = Mutation(kind, lx, ly, amount, temp, next_gen, edit_tick, digest)
        edit.validate()
        require(edit_tick == tick, 'G6J_TICK_DOMAIN_REFUSED')
        expected = edits[-1].generation if edits else gen
        require(expected < 2**64 - 1 and next_gen == expected + 1,
                'G6J_GENERATION_SEQUENCE_REFUSED')
        prev = chain(frame[:-4], prev)
        edits.append(edit)
        cursor += EDIT.size
    return Recovery(Identity(x, y, inc, gen, tick, physical_hash), base,
                    tuple(edits), cursor, prev, torn)


def recover(path: Path) -> Recovery:
    return _recover_bytes(Path(path).read_bytes())


class Journal:
    def __init__(self, path: Path, state: Recovery):
        self.path = Path(path)
        self.state = state
        self._poisoned = False
        # Bind the handle to the already-validated file, not just its length.
        # A same-sized checkpoint from another incarnation must never receive
        # this handle's edit record. This is not an interprocess writer lock.
        st = self.path.stat()
        self._file_identity = (st.st_dev, st.st_ino)
        with self.path.open('rb') as f:
            self._header = f.read(HEADER.size)
            self._last_record = b''
            if state.edits:
                f.seek(-EDIT.size, os.SEEK_END)
                self._last_record = f.read(EDIT.size)
        require(st.st_size == state.valid_length and len(self._header) == HEADER.size,
                'G6J_EXTERNAL_WRITE_REFUSED')

    @classmethod
    def create(cls, path: Path, identity: Identity, checkpoint: bytes) -> Journal:
        path = Path(path)
        require(identity.incarnation != 0, 'G6J_INCARCATION_REQUIRED')
        require(0 < len(checkpoint) <= MAX_CHECKPOINT, 'G6J_BASE_SIZE_REFUSED')
        path.parent.mkdir(parents=True, exist_ok=True)
        require(not path.exists(), 'G6J_DESTINATION_EXISTS')
        # A killed writer may leave its stage behind. A unique, exclusive stage
        # avoids permanently wedging creation after that crash and cannot
        # truncate another process's staged checkpoint. It is NOT an owner lock.
        first = HEADER.pack(MAGIC, identity.x, identity.y, identity.incarnation,
                            identity.generation, identity.tick, identity.physical_hash,
                            len(checkpoint), crc(checkpoint), 0)
        header = first[:-4] + struct.pack('<I', crc(first[:-4]))
        fd, stage_name = tempfile.mkstemp(prefix='.' + path.name + '.g6j-',
                                          suffix='.staging', dir=path.parent)
        stage = Path(stage_name)
        try:
            with os.fdopen(fd, 'wb') as f:
                f.write(header)
                f.write(checkpoint)
                f.flush()
                os.fsync(f.fileno())
            # Hard-link publication refuses to overwrite an existing checkpoint.
            os.link(stage, path)
        finally:
            # A successful link retains the checkpoint inode at destination.
            # A failed sync/link must not leave a new busy stage behind.
            stage.unlink(missing_ok=True)
        sync_dir(path.parent)  # publication ACK is not allowed before this
        return cls(path, recover(path))

    @classmethod
    def open(cls, path: Path, x: int, y: int, incarnation: int) -> Journal:
        state = recover(path)
        require((state.identity.x, state.identity.y, state.identity.incarnation) ==
                (x, y, incarnation), 'G6J_IDENTITY_REFUSED')
        require(not state.torn_tail, 'G6J_TORN_TAIL_REPAIR_REQUIRED')
        return cls(Path(path), state)

    @classmethod
    def rollover_torn_tail(cls, source: Path, destination: Path,
                           x: int, y: int, incarnation: int,
                           expected_generation: int,
                           verify_staged_replay: Callable[[Recovery], bool]) -> Journal:
        """Publish an appendable, no-clobber copy of a *verified* torn prefix.

        The caller exclusively owns both paths, retires all source handles,
        and must replay the prefix into an isolated native World before
        returning True. Never silently truncate the original forensic record.
        This is a new-file publication, not in-place repair or multiwriter lock.
        """
        source, destination = Path(source), Path(destination)
        require(source != destination and
                source.parent.resolve() == destination.parent.resolve() and
                not source.is_symlink() and not destination.is_symlink(),
                'G6J_ROLLOVER_PATH_REFUSED')
        require(not destination.exists(), 'G6J_DESTINATION_EXISTS')
        # Read from one open source descriptor; reject a changing source
        # rather than rebuilding a successor from inconsistent file versions.
        with source.open('rb') as f:
            original = os.fstat(f.fileno())
            raw = f.read(HEADER.size + MAX_CHECKPOINT + MAX_EDITS * EDIT.size + 1)
            after_read = os.fstat(f.fileno())
        signature = lambda st: (st.st_dev, st.st_ino, st.st_size, st.st_mtime_ns)
        require(signature(original) == signature(after_read) and
                signature(original) == signature(source.stat()),
                'G6J_ROLLOVER_SOURCE_CHANGED')
        state = _recover_bytes(raw)
        require(state.torn_tail, 'G6J_ROLLOVER_NO_TORN_TAIL')
        require((state.identity.x, state.identity.y, state.identity.incarnation) ==
                (x, y, incarnation), 'G6J_IDENTITY_REFUSED')
        require(state.generation == expected_generation,
                'G6J_STALE_GENERATION')
        clean = raw[:state.valid_length]
        verified = _recover_bytes(clean)
        require(not verified.torn_tail and verified.identity == state.identity and
                verified.edits == state.edits and verified.tail_chain == state.tail_chain,
                'G6J_ROLLOVER_PREFIX_REFUSED')
        require(bool(verify_staged_replay(state)),
                'G6J_ROLLOVER_NATIVE_REPLAY_REFUSED')
        require(signature(original) == signature(source.stat()),
                'G6J_ROLLOVER_SOURCE_CHANGED')
        # Unique, same-directory, fully flushed staging file; the hard link
        # can only create a NEW destination. Preserve the torn source as
        # original failure evidence, including its unacknowledged suffix.
        fd, stage_name = tempfile.mkstemp(prefix='.' + destination.name + '.g6j-',
                                          suffix='.staging', dir=destination.parent)
        stage = Path(stage_name)
        try:
            with os.fdopen(fd, 'wb') as f:
                f.write(clean)
                f.flush()
                os.fsync(f.fileno())
            require(signature(original) == signature(source.stat()),
                    'G6J_ROLLOVER_SOURCE_CHANGED')
            os.link(stage, destination)
        finally:
            stage.unlink(missing_ok=True)
        sync_dir(destination.parent)
        return cls.open(destination, x, y, incarnation)

    def append(self, edit: Mutation, expected_generation: int) -> None:
        """Original single-edit ACK, now a one-element durable group."""
        self.append_batch((edit,), expected_generation)

    def append_batch(self, edits: tuple[Mutation, ...],
                     expected_generation: int) -> None:
        """Preflight a bounded frozen-tick group; fsync once before group ACK.

        The serialized native owner must stage all edits before this call.
        No member can be individually ACKed until the whole group is durable.
        An I/O failure requires handle retirement and explicit recovery;
        complete unacknowledged frames may remain visible on the filesystem.
        """
        # Reject iterators before materialization: an unbounded iterable may
        # otherwise exhaust memory before the declared batch cap is checked.
        require(isinstance(edits, (tuple, list)), 'G6J_BATCH_SEQUENCE_REFUSED')
        require(0 < len(edits) <= MAX_BATCH, 'G6J_BATCH_SIZE_REFUSED')
        require(not self._poisoned, 'G6J_HANDLE_POISONED')
        edits = tuple(edits)
        state = self.state
        require(not state.torn_tail, 'G6J_TORN_TAIL_REPAIR_REQUIRED')
        require(state.generation == expected_generation and
                expected_generation < 2**64 - len(edits),
                'G6J_STALE_GENERATION')
        require(len(state.edits) + len(edits) <= MAX_EDITS,
                'G6J_MAX_EDITS_REFUSED')
        prior = state.tail_chain
        frames: list[bytes] = []
        # Validate ALL edits before modifying the file: no partial preflight.
        for index, edit in enumerate(edits):
            edit.validate()
            require(edit.generation == expected_generation + index + 1,
                    'G6J_GENERATION_SEQUENCE_REFUSED')
            require(edit.tick == state.identity.tick, 'G6J_TICK_DOMAIN_REFUSED')
            frame = EDIT.pack(b'EDIT', edit.generation, edit.tick,
                              edit.physical_hash, edit.kind, edit.x, edit.y,
                              0, edit.amount, edit.temperature, prior, 0)
            record = frame[:-4] + struct.pack('<I', crc(frame[:-4]))
            frames.append(record)
            prior = chain(record[:-4], prior)
        payload = b''.join(frames)
        committed = Recovery(state.identity, state.checkpoint,
                             state.edits + edits, state.valid_length + len(payload),
                             prior, False)
        try:
            # Validate the actual descriptor used for append. Not a writer lock.
            with self.path.open('r+b') as f:
                st = os.fstat(f.fileno())
                require(st.st_size == state.valid_length and
                        (st.st_dev, st.st_ino) == self._file_identity,
                        'G6J_EXTERNAL_WRITE_REFUSED')
                require(f.read(HEADER.size) == self._header,
                        'G6J_EXTERNAL_WRITE_REFUSED')
                if state.edits:
                    f.seek(-EDIT.size, os.SEEK_END)
                    require(f.read(EDIT.size) == self._last_record,
                            'G6J_EXTERNAL_WRITE_REFUSED')
                f.seek(0, os.SEEK_END)
                require(f.write(payload) == len(payload), 'G6J_BATCH_SHORT_WRITE')
                f.flush()
                os.fsync(f.fileno())  # one durability barrier for the entire group
            post = self.path.stat()
            require((post.st_dev, post.st_ino) == self._file_identity and
                    post.st_size == committed.valid_length,
                    'G6J_EXTERNAL_WRITE_REFUSED')
        except BaseException:
            # A failed fsync can leave fully formed but unacknowledged records,
            # and a retry would create an ambiguous generation/ACK boundary.
            # Retire this handle even if an external repair restored its length.
            self._poisoned = True
            raise
        self.state = committed
        self._last_record = frames[-1]


def replay_checked(recovery: Recovery, apply, physical_hash) -> None:
    """Operate ONLY on an isolated staged World; never mutate a live World."""
    require(physical_hash() == recovery.identity.physical_hash,
            'G6J_BASE_PHYSICAL_HASH_REFUSED')
    for edit in recovery.edits:
        require(apply(edit), 'G6J_REPLAY_COMMAND_REFUSED')
        require(physical_hash() == edit.physical_hash, 'G6J_REPLAY_HASH_REFUSED')
