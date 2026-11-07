#!/usr/bin/env python3
"""GEN-006 experimental disk publication / owner ACK / eviction interleaving fixture.

Never use as a CyberSand World serializer. A synthetic, complete-looking opaque
record represents one signed-coordinate chunk; no native code executes here.
Only the disk/owner sequencing claims tested below are in scope.
"""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from dataclasses import dataclass

MAX_PAYLOAD = 8192
INT64_MIN, INT64_MAX = -(1 << 63), (1 << 63) - 1


class Refused(Exception):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise Refused(code)


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      allow_nan=False, ensure_ascii=True).encode("ascii")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@dataclass(frozen=True)
class Snapshot:
    world: str
    session: str
    incarnation: int
    coord: tuple[int, int]
    recipe: str
    generation: int
    data: bytes

    @property
    def hash(self) -> str:
        return digest(self.data)


class Owner:
    def __init__(self, *, session="session-1", incarnation=1, generation=1,
                 data=None, coord=(-1, 0), recipe="recipe-1"):
        self.world, self.session, self.incarnation = "world-1", session, incarnation
        self.coord, self.recipe, self.generation = coord, recipe, generation
        self.data = copy.deepcopy(data if data is not None else {
            "cells": [{"index": 0, "material": 3, "water_amount": 127,
                       "coherence": 12}, {"index": 2, "material": 0}],
            "intents": [{"index": 2, "kind": "explicit_empty"},
                        {"index": 0, "kind": "same_value"}],
            "thermal": [{"index": 1, "temperature": 410}],
            "activity": [{"index": 0, "due_tick": 260}],
            "events": [], "completed_tick": 255,
            "material_identity": "legacy-132-slots", "solver_identity": "native-control",
        })
        self.dirty = True
        self.resident = True
        self.leases = 0
        self.pins = set()
        self.failed = False
        self.in_tick = False
        self.pending_boundary = False

    def mutate(self, key, value):
        require(self.resident, "NOT_RESIDENT")
        require(not (self.failed or self.in_tick), "UNSAFE_MUTATION")
        self.data[key] = copy.deepcopy(value)
        self.generation += 1
        self.dirty = True

    def snapshot(self) -> Snapshot:
        require(self.resident, "NOT_RESIDENT")
        require(not (self.failed or self.in_tick), "UNSAFE_SNAPSHOT")
        require(self.leases < 2, "SNAPSHOT_BACKPRESSURE")
        require(all(type(n) is int and INT64_MIN <= n <= INT64_MAX for n in self.coord),
                "INVALID_COORDINATE")
        data = canonical(self.data)
        require(len(data) <= MAX_PAYLOAD, "SNAPSHOT_TOO_LARGE")
        self.leases += 1
        return Snapshot(self.world, self.session, self.incarnation,
                        self.coord, self.recipe, self.generation, data)

    def release(self, snap: Snapshot):
        require(self.leases > 0, "UNBALANCED_LEASE")
        self.leases -= 1

    def ack(self, snap: Snapshot, disk: "Disk") -> None:
        require(self.leases > 0, "MISSING_LEASE")
        require(self.session == snap.session and self.incarnation == snap.incarnation
                and self.world == snap.world and self.coord == snap.coord
                and self.recipe == snap.recipe and self.generation == snap.generation,
                "STALE_ACK")
        require(not (self.failed or self.in_tick), "UNSAFE_ACK")
        saved = disk.read()
        require(saved["generation"] == snap.generation and saved["hash"] == snap.hash
                and saved["world"] == snap.world and tuple(saved["coord"]) == snap.coord
                and saved["recipe"] == snap.recipe, "NOT_DURABLE")
        self.dirty = False

    def evict(self) -> None:
        require(self.resident, "NOT_RESIDENT")
        require(not (self.failed or self.in_tick), "UNSAFE_EVICTION")
        require(not self.dirty and self.leases == 0, "NOT_DURABLY_CLEAN")
        require(not self.pins and not self.pending_boundary, "PINNED_AUTHORITY")
        self.data = None  # model loss of the only live synthetic cell payload
        self.resident = False


class Disk:
    """One-process, single-chunk modeled owner. Real POSIX file operations.

    The client serializes writes under the exclusive owner; this class is not
    a cross-process transaction engine or a Windows filesystem qualification.
    """
    def __init__(self, root: Path):
        self.root = root
        (root / "blobs").mkdir(parents=True)
        self.manifest = root / "manifest.json"
        self.binding = None

    def bind(self, owner: Owner) -> None:
        self.binding = (owner.world, owner.session, owner.incarnation,
                        owner.coord, owner.recipe)

    def _sync_dir(self, directory: Path) -> None:
        fd = os.open(directory, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)

    def _write_atomic(self, path: Path, data: bytes, fault: str | None, stage: str) -> None:
        fd, name = tempfile.mkstemp(prefix=".gen006-", dir=path.parent)
        try:
            with os.fdopen(fd, "wb") as output:
                output.write(data)
                output.flush()
                os.fsync(output.fileno())
            if fault == f"after_{stage}_temp_sync":
                raise RuntimeError("INJECTED_TORN_PUBLICATION")
            os.replace(name, path)
            self._sync_dir(path.parent)
        finally:
            if os.path.exists(name):
                os.unlink(name)

    def read(self) -> dict:
        require(self.manifest.exists(), "NO_VALID_CHECKPOINT")
        try:
            entry = json.loads(self.manifest.read_bytes())
            require(set(entry) == {"version", "world", "coord", "recipe", "generation", "hash"}
                    and entry["version"] == 1, "INVALID_MANIFEST")
            require(type(entry["generation"]) is int and entry["generation"] >= 0,
                    "INVALID_MANIFEST")
            require(type(entry["coord"]) is list and len(entry["coord"]) == 2
                    and all(type(n) is int and INT64_MIN <= n <= INT64_MAX for n in entry["coord"]),
                    "INVALID_COORDINATE")
            require(type(entry["hash"]) is str and len(entry["hash"]) == 64
                    and all(c in "0123456789abcdef" for c in entry["hash"]), "INVALID_MANIFEST")
            data = (self.root / "blobs" / (entry["hash"] + ".json")).read_bytes()
            require(len(data) <= MAX_PAYLOAD and digest(data) == entry["hash"],
                    "CORRUPT_CHECKPOINT")
            obj = json.loads(data)
            require(isinstance(obj, dict), "CORRUPT_CHECKPOINT")
            return dict(entry, data=obj)
        except (OSError, ValueError, TypeError, KeyError) as e:
            raise Refused("CORRUPT_CHECKPOINT") from e

    def commit(self, snap: Snapshot, owner: Owner, *, fault=None, before_publish=None):
        require(len(snap.data) <= MAX_PAYLOAD, "SNAPSHOT_TOO_LARGE")
        path = self.root / "blobs" / (snap.hash + ".json")
        self._write_atomic(path, snap.data, fault, "blob")
        if fault == "after_blob_sync":
            raise RuntimeError("INJECTED_TORN_PUBLICATION")
        if before_publish:
            before_publish()  # controlled test-only interleaving at owner barrier
        require(self.binding == (snap.world, snap.session, snap.incarnation,
                                 snap.coord, snap.recipe), "RETIRED_SESSION")
        require(not (owner.failed or owner.in_tick), "UNSAFE_COMMIT")
        require((owner.world, owner.session, owner.incarnation, owner.coord,
                 owner.recipe, owner.generation) ==
                (snap.world, snap.session, snap.incarnation, snap.coord,
                 snap.recipe, snap.generation), "STALE_SNAPSHOT")
        try:
            old = self.read()
        except Refused as e:
            if str(e) != "NO_VALID_CHECKPOINT":
                raise
            old = None
        if old is not None:
            require(old["world"] == snap.world and tuple(old["coord"]) == snap.coord
                    and old["recipe"] == snap.recipe, "INCOMPATIBLE_IDENTITY")
            require(old["generation"] <= snap.generation, "STALE_PUBLICATION")
            if old["generation"] == snap.generation:
                require(old["hash"] == snap.hash, "GENERATION_COLLISION")
                return "ALREADY_DURABLE"
        entry = {"version": 1, "world": snap.world, "coord": list(snap.coord),
                 "recipe": snap.recipe, "generation": snap.generation,
                 "hash": snap.hash}
        self._write_atomic(self.manifest, canonical(entry), fault, "manifest")
        if fault == "after_manifest_replace":
            raise RuntimeError("INJECTED_ACK_LOSS")
        return "DURABLE"

    def restore(self, *, session: str, incarnation: int, recipe="recipe-1") -> Owner:
        entry = self.read()
        require(entry["world"] == "world-1" and entry["recipe"] == recipe,
                "INCOMPATIBLE_IDENTITY")
        owner = Owner(session=session, incarnation=incarnation,
                      generation=entry["generation"], data=entry["data"],
                      coord=tuple(entry["coord"]), recipe=entry["recipe"])
        owner.dirty = False
        self.bind(owner)
        return owner


class SaveAckFaultTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.disk = Disk(Path(self.tmp.name))
        self.owner = Owner()
        self.disk.bind(self.owner)

    def save(self, owner=None, **kwargs):
        owner = owner or self.owner
        s = owner.snapshot()
        try:
            result = self.disk.commit(s, owner, **kwargs)
            owner.ack(s, self.disk)
            return result
        finally:
            owner.release(s)

    def test_signed_chunk_and_exact_semantic_payload_survive_restart(self):
        self.assertEqual(self.save(), "DURABLE")
        self.owner.evict()
        self.assertIsNone(self.owner.data)
        self.assertFalse(self.owner.resident)
        with self.assertRaisesRegex(Refused, "NOT_RESIDENT"):
            self.owner.snapshot()
        new = self.disk.restore(session="session-2", incarnation=2)
        self.assertEqual(new.coord, (-1, 0))
        self.assertEqual(new.data, Owner().data)
        self.assertEqual(new.data["intents"][0]["kind"], "explicit_empty")
        self.assertEqual(new.data["cells"][0]["water_amount"], 127)
        new.evict()

    def test_stale_snapshot_cannot_clear_dirty_or_publish(self):
        old = self.owner.snapshot()
        self.owner.mutate("completed_tick", 256)
        with self.assertRaisesRegex(Refused, "STALE_SNAPSHOT"):
            self.disk.commit(old, self.owner)
        with self.assertRaisesRegex(Refused, "STALE_ACK"):
            self.owner.ack(old, self.disk)
        self.owner.release(old)
        self.assertTrue(self.owner.dirty)
        self.assertFalse(self.disk.manifest.exists())
        self.assertEqual(self.save(), "DURABLE")
        self.assertEqual(self.disk.read()["generation"], 2)

    def test_interleaved_new_edit_before_publication_refused(self):
        s = self.owner.snapshot()
        with self.assertRaisesRegex(Refused, "STALE_SNAPSHOT"):
            self.disk.commit(s, self.owner,
                             before_publish=lambda: self.owner.mutate("completed_tick", 257))
        self.owner.release(s)
        self.assertFalse(self.disk.manifest.exists())
        self.assertTrue(self.owner.dirty)

    def test_old_async_result_after_newer_durable_write_refused(self):
        old = self.owner.snapshot()
        self.owner.mutate("v", 1)
        self.save()
        with self.assertRaisesRegex(Refused, "STALE_SNAPSHOT"):
            self.disk.commit(old, self.owner)
        self.owner.release(old)
        self.assertEqual(self.disk.read()["generation"], 2)

    def test_crash_before_manifest_keeps_previous_checkpoint(self):
        self.save()
        self.owner.mutate("completed_tick", 256)
        for fault in ("after_blob_temp_sync", "after_blob_sync", "after_manifest_temp_sync"):
            s = self.owner.snapshot()
            with self.assertRaisesRegex(RuntimeError, "INJECTED"):
                self.disk.commit(s, self.owner, fault=fault)
            self.owner.release(s)
            self.assertEqual(self.disk.read()["generation"], 1)
            self.assertTrue(self.owner.dirty)
            with self.assertRaisesRegex(Refused, "NOT_DURABLY_CLEAN"):
                self.owner.evict()
        self.save()
        self.assertEqual(self.disk.read()["generation"], 2)

    def test_crash_after_manifest_is_recoverable_without_ack(self):
        s = self.owner.snapshot()
        with self.assertRaisesRegex(RuntimeError, "INJECTED_ACK_LOSS"):
            self.disk.commit(s, self.owner, fault="after_manifest_replace")
        self.owner.release(s)
        with self.assertRaisesRegex(Refused, "NOT_DURABLY_CLEAN"):
            self.owner.evict()
        self.assertEqual(self.disk.read()["generation"], 1)
        new = self.disk.restore(session="restarted", incarnation=33)
        new.evict()

    def test_duplicate_same_generation_idempotent_but_different_bytes_refuse(self):
        self.save()
        self.assertEqual(self.save(), "ALREADY_DURABLE")
        s = self.owner.snapshot()
        altered = Snapshot(s.world, s.session, s.incarnation, s.coord, s.recipe,
                           s.generation, canonical(dict(self.owner.data, forged=True)))
        with self.assertRaisesRegex(Refused, "GENERATION_COLLISION"):
            self.disk.commit(altered, self.owner)
        self.owner.release(s)
        self.assertEqual(self.disk.read()["hash"], digest(canonical(self.owner.data)))

    def test_old_session_fenced_after_restore(self):
        old = self.owner.snapshot()
        self.save()
        new = self.disk.restore(session="new", incarnation=2)
        with self.assertRaisesRegex(Refused, "RETIRED_SESSION"):
            self.disk.commit(old, self.owner)
        self.owner.release(old)
        self.assertEqual(self.disk.read()["generation"], 1)
        self.assertFalse(new.dirty)

    def test_eviction_refuses_body_pin_pending_boundary_and_live_lease(self):
        self.save()
        self.owner.pins.add("rapier-body")
        with self.assertRaisesRegex(Refused, "PINNED_AUTHORITY"):
            self.owner.evict()
        self.owner.pins.clear()
        self.owner.pending_boundary = True
        with self.assertRaisesRegex(Refused, "PINNED_AUTHORITY"):
            self.owner.evict()
        self.owner.pending_boundary = False
        s = self.owner.snapshot()
        with self.assertRaisesRegex(Refused, "NOT_DURABLY_CLEAN"):
            self.owner.evict()
        self.owner.release(s)
        self.owner.evict()
        self.assertFalse(self.owner.resident)

    def test_corrupted_blob_fails_closed(self):
        self.save()
        manifest = self.disk.read()
        blob = self.disk.root / "blobs" / (manifest["hash"] + ".json")
        blob.write_bytes(b"broken")
        with self.assertRaisesRegex(Refused, "CORRUPT_CHECKPOINT"):
            self.disk.restore(session="new", incarnation=2)

    def test_wrong_recipe_fails_closed(self):
        self.save()
        with self.assertRaisesRegex(Refused, "INCOMPATIBLE_IDENTITY"):
            self.disk.restore(session="new", incarnation=2, recipe="new-recipe")

    def test_failed_tick_snapshot_and_eviction_refused(self):
        self.owner.failed = True
        with self.assertRaisesRegex(Refused, "UNSAFE_SNAPSHOT"):
            self.owner.snapshot()
        with self.assertRaisesRegex(Refused, "UNSAFE_EVICTION"):
            self.owner.evict()

    def test_bounded_snapshot_leases_and_payload(self):
        s1, s2 = self.owner.snapshot(), self.owner.snapshot()
        with self.assertRaisesRegex(Refused, "SNAPSHOT_BACKPRESSURE"):
            self.owner.snapshot()
        self.owner.release(s1)
        self.owner.release(s2)
        self.owner.mutate("oversize", "X" * MAX_PAYLOAD)
        with self.assertRaisesRegex(Refused, "SNAPSHOT_TOO_LARGE"):
            self.owner.snapshot()

    def test_signed_coordinate_overflow_rejected_before_capture(self):
        self.owner.coord = (INT64_MAX + 1, 0)
        with self.assertRaisesRegex(Refused, "INVALID_COORDINATE"):
            self.owner.snapshot()
        self.owner.coord = (INT64_MIN, INT64_MAX)
        s = self.owner.snapshot()
        self.owner.release(s)


if __name__ == "__main__":
    unittest.main(verbosity=2)
