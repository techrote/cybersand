"""Adverse controls for source-byte, backend and publication compatibility."""
from __future__ import annotations

import collections
import copy
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import compatibility as guard


def admitted_sources(sources: dict[str, bytes]) -> dict[str, bytes]:
    """Baseline bytes, with each production reviewed transition's target applied."""
    current = dict(sources)
    for entry in guard.REVIEWED_TRANSITIONS:
        current[entry["path"]] = subprocess.run(
            ["git", "-C", str(guard.ROOT), "show", f"{entry['source_commit']}:{entry['path']}"],
            check=True, capture_output=True, timeout=30, env=guard.git_environment()).stdout
    return current


class CompatibilityGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = guard.retained_sources()
        cls.lock = guard.build_lock(cls.sources)
        cls.current = admitted_sources(cls.sources)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mat-auth-compat-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for relative, data in self.current.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.lock_path = self.root / guard.LOCK
        self.lock_path.parent.mkdir(parents=True, exist_ok=True)
        self.write_lock(self.lock)

    def write_lock(self, value):
        self.lock_path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

    def check(self):
        return guard.check(self.root)

    def reject(self, expression):
        with self.assertRaisesRegex(guard.CompatibilityError, expression):
            self.check()

    def test_current_source_passes_without_writing(self):
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns)
                  for p in self.root.rglob("*") if p.is_file()}
        result = self.check()
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["protected_sources"], 27)
        self.assertFalse(result["production_cutover"])
        self.assertFalse(result["runtime_execution"])
        self.assertEqual(before, {p: (p.read_bytes(), p.stat().st_mtime_ns)
                                  for p in self.root.rglob("*") if p.is_file()})

    def test_formatting_only_header_change_is_not_value_parity(self):
        path = self.root / guard.CATALOGUE_SOURCES[0]
        path.write_bytes(b"// harmless-looking generated banner\n" + path.read_bytes())
        self.reject("material.hpp: LF source-byte drift")

    def test_crlf_normalization_matches_existing_identity_contract(self):
        for name in guard.CATALOGUE_SOURCES:
            path = self.root / name
            path.write_bytes(guard.lf(path.read_bytes()).replace(b"\n", b"\r\n"))
        self.assertEqual(self.check()["catalogue_digest"], self.lock["catalogue_digest"])

    def test_changed_source_and_refreshed_hash_cannot_rebaseline(self):
        value = copy.deepcopy(self.lock)
        name = guard.CATALOGUE_SOURCES[1]
        path = self.root / name
        path.write_bytes(path.read_bytes() + b"\n// generated row reordering\n")
        for entry in value["source_locks"]:
            if entry["path"] == name:
                entry["lf_sha256"] = guard.sha(path.read_bytes())
        value["catalogue_digest"] = guard.catalogue_digest(
            {p: (self.root / p).read_bytes() for p in guard.CATALOGUE_SOURCES})
        self.write_lock(value)
        self.reject("/source_locks: differs from immutable")

    def test_missing_protected_consumer_is_not_skipped(self):
        (self.root / "native/src/world_quantity.inc").unlink()
        self.reject("world_quantity.inc: required legacy consumer unavailable")

    def test_dropped_lock_entry_is_rejected(self):
        value = copy.deepcopy(self.lock)
        value["source_locks"].pop()
        self.write_lock(value)
        self.reject("/source_locks: differs from immutable")

    def test_renamed_baseline_is_rejected(self):
        value = copy.deepcopy(self.lock)
        value["source_commit"] = "f" * 40
        self.write_lock(value)
        self.reject("/source_commit: expected retained")

    def test_schema_boolean_cannot_alias_integer(self):
        value = copy.deepcopy(self.lock)
        value["schema_version"] = True
        self.write_lock(value)
        self.reject("/schema_version: supported version is integer 1")

    def test_duplicate_json_keys_fail(self):
        text = self.lock_path.read_text()
        self.lock_path.write_text(text.replace('"schema_version": 1,',
                                               '"schema_version": 1, "schema_version": 1,'))
        self.reject("duplicate JSON key")

    def test_unknown_top_level_field_fails(self):
        value = copy.deepcopy(self.lock)
        value["accept_new_identity"] = True
        self.write_lock(value)
        self.reject("expected exactly")

    def test_nonfinite_lock_fails(self):
        self.lock_path.write_text(self.lock_path.read_text().replace('"schema_version": 1',
                                                                    '"schema_version": NaN'))
        self.reject("non-finite JSON value")

    def test_fallback_density_is_not_normalized_to_native(self):
        path = self.root / "godot/scripts/cell_world.gd"
        before = path.read_bytes()
        self.assertIn(b"\t\tSLUSH:\n\t\t\treturn 1100", before)
        path.write_bytes(before.replace(b"\t\tSLUSH:\n\t\t\treturn 1100",
                                        b"\t\tSLUSH:\n\t\t\treturn 1080"))
        self.reject("cell_world.gd: LF source-byte drift")

    def test_fallback_fact_cannot_claim_native_density(self):
        value = copy.deepcopy(self.lock)
        value["fallback_source_facts"]["density_by_byte_id"][21] = 1080
        value["fallback_source_facts"]["slush_density"] = 1080
        self.write_lock(value)
        self.reject("/fallback_source_facts: differs from immutable")

    def test_fallback_boolean_is_not_an_id(self):
        value = copy.deepcopy(self.lock)
        value["fallback_source_facts"]["identity_constants"]["WALL"] = True
        self.write_lock(value)
        self.reject("/fallback_source_facts: differs from immutable")

    def test_policy_vector_drift_is_not_regenerated_away(self):
        path = self.root / "docs/reference/liquid-policy-wire-vectors.json"
        path.write_bytes(path.read_bytes() + b" ")
        self.reject("liquid-policy-wire-vectors.json: LF source-byte drift")

    def test_world_state_or_wake_change_requires_separate_admission(self):
        path = self.root / "native/src/world.cpp"
        path.write_bytes(path.read_bytes() + b"\n// changed endpoint or wake authority\n")
        self.reject("world.cpp: LF source-byte drift")

    def test_new_native_consumer_cannot_import_shadow(self):
        path = self.root / "native/src/accidental_cutover.cpp"
        path.write_text('#include "materials/catalogue/generated/catalogue_shadow.hpp"\n')
        self.reject("accidental_cutover.cpp: production/native test imports shadow output")

    def test_new_godot_consumer_cannot_load_shadow(self):
        path = self.root / "godot/scripts/accidental_cutover.gd"
        path.write_text('const Bad = preload("res://catalogue_shadow.gd")\n')
        self.reject("accidental_cutover.gd: production/native test imports shadow output")

    def test_basename_only_candidate_include_is_refused(self):
        path = self.root / "native/src/accidental_cutover.cpp"
        path.write_text('#include "catalogue.shadow.hpp"\n')
        self.reject("accidental_cutover.cpp: production/native test imports shadow output")

    def test_native_include_fragments_and_cpp_suffixes_are_protected(self):
        for suffix in (".inc", ".cc", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".c"):
            with self.subTest(suffix=suffix):
                path = self.root / ("native/src/accidental_cutover" + suffix)
                path.write_text('#include "materials/catalogue/generated/catalogue.shadow.hpp"\n')
                self.reject("accidental_cutover.*: production/native test imports shadow output")
                path.unlink()

    def test_experimental_id_claim_cannot_be_relabelled_production(self):
        value = copy.deepcopy(self.lock)
        value["experimental_claims"]["status"] = "production"
        self.write_lock(value)
        self.reject("/experimental_claims: differs from immutable")

    def test_source_observed_backend_facts_are_exact(self):
        facts = guard.fallback_facts(self.sources)
        self.assertEqual(len(facts["identity_constants"]), 131)
        self.assertEqual(len(facts["density_by_byte_id"]), 256)
        self.assertEqual(facts["slush_density"], 1100)
        self.assertEqual(facts["density_by_byte_id"][12], 0)  # Native Acid differs.
        self.assertEqual(len(facts["hard_surface_ids"]), 101)
        self.assertNotIn(132, facts["hard_surface_ids"])
        self.assertEqual(facts["granular_support_ids"], [2, 13, 14, 19, 23, 25, 26, 27, 29])
        self.assertEqual(len(facts["base_rgba8"]), 132)


def _remove_tree(path: Path) -> None:
    # Git writes read-only loose objects; Windows refuses to unlink them as-is.
    def retry(function, target, *_):
        os.chmod(target, stat.S_IWRITE)
        function(target)
    if sys.version_info >= (3, 12):
        shutil.rmtree(path, onexc=retry)
    else:
        shutil.rmtree(path, onerror=retry)


class ReviewedTransitionGuards(unittest.TestCase):
    """Positive and adverse controls for code-pinned reviewed transitions.

    A shared clone of this repository receives real fixture commits: two chained
    reviewed steps for one protected consumer, a step whose blob has CRLF line
    endings, a squash-like commit unreachable from HEAD, a commit that does not
    descend from the baseline, and a HEAD (merging both reviewed lines) that
    commits a complete record, records each missing one fact and an unrelated
    record. Every check authenticates against that Git history. Git runs with
    location variables removed, so this fixture can never touch the developer's
    own repository even when the tests run inside a hook or `git rebase -x`.
    """
    PATH = "native/src/world_pressure.inc"
    RECORD = "docs/audits/fixture-reviewed-transition.md"
    UNRELATED = "docs/audits/fixture-unrelated.md"
    FACTS = ("path", "from_lf_sha256", "to_lf_sha256", "source_commit")

    @classmethod
    def setUpClass(cls):
        cls.sources = guard.retained_sources()
        cls.lock = guard.build_lock(cls.sources)
        cls.directory = Path(tempfile.mkdtemp(prefix="mat-auth-transition-"))
        cls.addClassCleanup(_remove_tree, cls.directory)
        cls.repository = cls.directory / "repository"
        subprocess.run(["git", "clone", "--quiet", "--shared", "--no-checkout",
                        str(guard.ROOT), str(cls.repository)], check=True, capture_output=True, timeout=120,
                       env=guard.git_environment())
        cls.baseline_bytes = cls.sources[cls.PATH]
        cls.first_bytes = cls.baseline_bytes + b"\n// reviewed behaviour-preserving edit\n"
        cls.second_bytes = cls.first_bytes + b"// second reviewed edit\n"
        cls.first = cls.commit(guard.BASELINE, {cls.PATH: cls.first_bytes})
        cls.second = cls.commit(cls.first, {cls.PATH: cls.second_bytes})
        cls.crlf = cls.commit(guard.BASELINE, {cls.PATH: guard.lf(cls.first_bytes).replace(b"\n", b"\r\n")})
        cls.unretained = cls.commit(guard.BASELINE, {cls.PATH: cls.first_bytes + b"// squashed\n"})
        cls.predecessor = cls.commit(cls.git("rev-parse", guard.BASELINE + "^").strip(),
                                     {cls.PATH: cls.first_bytes})
        cls.step1 = cls.entry(cls.baseline_bytes, cls.first_bytes, cls.first)
        cls.step2 = cls.entry(cls.first_bytes, cls.second_bytes, cls.second)
        cls.crlf_step = cls.entry(cls.baseline_bytes, cls.first_bytes, cls.crlf)
        record = "\n".join(["# Fixture reviewed transitions", cls.PATH,
                            *(f"{step['from_lf_sha256']} -> {step['to_lf_sha256']} at {step['source_commit']}"
                              for step in (cls.step1, cls.step2, cls.crlf_step)), ""]).encode()
        files = {cls.RECORD: record, cls.UNRELATED: b"# Unrelated\n"}
        cls.partial = {}
        for omitted in cls.FACTS:
            name = f"docs/audits/fixture-without-{omitted.replace('_', '-')}.md"
            kept = [cls.step1[key] for key in cls.FACTS if key != omitted]
            files[name] = "\n".join(["# Partial fixture record", *kept, ""]).encode()
            cls.partial[omitted] = name
        head = cls.commit((cls.second, cls.crlf), files)
        cls.git("update-ref", "--no-deref", "HEAD", head)

    @classmethod
    def git(cls, *arguments: str, data: bytes | None = None, index: Path | None = None) -> str:
        environment = {**guard.git_environment(), "GIT_AUTHOR_NAME": "fixture",
                       "GIT_AUTHOR_EMAIL": "fixture@invalid", "GIT_COMMITTER_NAME": "fixture",
                       "GIT_COMMITTER_EMAIL": "fixture@invalid"}
        if index is not None:
            environment["GIT_INDEX_FILE"] = str(index)
        return subprocess.run(["git", "-C", str(cls.repository), *arguments], input=data, check=True,
                              capture_output=True, timeout=60, env=environment).stdout.decode()

    @classmethod
    def commit(cls, parents: str | tuple[str, ...], files: dict[str, bytes]) -> str:
        index = cls.directory / f"index-{len(list(cls.directory.glob('index-*')))}"
        for name, data in files.items():
            blob = cls.git("hash-object", "-w", "--stdin", data=data).strip()
            cls.git("update-index", "--add", "--cacheinfo", f"100644,{blob},{name}", index=index)
        tree = cls.git("write-tree", index=index).strip()
        parent_arguments = [part for parent in ((parents,) if isinstance(parents, str) else parents)
                            for part in ("-p", parent)]
        return cls.git("commit-tree", tree, *parent_arguments, "-m", "fixture").strip()

    @classmethod
    def entry(cls, before: bytes, after: bytes, commit: str, **changes) -> dict:
        value = {"path": cls.PATH, "from_lf_sha256": guard.sha(before), "to_lf_sha256": guard.sha(after),
                 "source_commit": commit, "record": cls.RECORD, "issue": 201, "pr": 382}
        value.update(changes)
        return value

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mat-auth-transition-root-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for relative, data in self.sources.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.lock_path = self.root / guard.LOCK
        self.lock_path.parent.mkdir(parents=True, exist_ok=True)
        self.lock_path.write_text(json.dumps(self.lock, indent=2) + "\n", encoding="utf-8")

    def write(self, data: bytes, path: str | None = None) -> None:
        (self.root / (path or self.PATH)).write_bytes(data)

    def check(self, transitions):
        return guard.check(self.root, baseline_repository=self.repository, transitions=transitions)

    def reject(self, transitions, expression):
        with self.assertRaisesRegex(guard.CompatibilityError, expression):
            self.check(transitions)

    def test_reviewed_transition_admits_exact_target_and_keeps_identities(self):
        self.write(self.first_bytes)
        lock_before = self.lock_path.read_bytes()
        result = self.check((self.step1,))
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["reviewed_transitions"], [self.step1])
        self.assertEqual(self.lock_path.read_bytes(), lock_before)

    def test_crlf_target_uses_the_existing_lf_contract(self):
        self.write(self.first_bytes.replace(b"\n", b"\r\n"))
        self.assertEqual(self.check((self.step1,))["status"], "PASS")

    def test_crlf_blob_at_the_source_commit_is_lf_normalized(self):
        self.write(self.first_bytes)
        self.assertEqual(self.check((self.crlf_step,))["status"], "PASS")

    def test_git_location_variables_cannot_redirect_authentication(self):
        self.write(self.first_bytes)
        decoy = self.directory / "decoy-git-dir"
        with patch.dict(os.environ, {"GIT_DIR": str(decoy), "GIT_INDEX_FILE": str(decoy / "index"),
                                     "GIT_OBJECT_DIRECTORY": str(decoy / "objects")}):
            self.assertEqual(self.check((self.step1,))["status"], "PASS")
        self.assertFalse(decoy.exists())

    def test_identity_inputs_cover_every_lock_derived_read(self):
        # build_lock hashes every protected path once for source_locks; any
        # further read feeds a digest or fallback fact, i.e. a retained identity.
        class Recording(dict):
            def __init__(self, data):
                super().__init__(data)
                self.reads = collections.Counter()

            def __getitem__(self, key):
                self.reads[key] += 1
                return super().__getitem__(key)

        recording = Recording(self.sources)
        guard.build_lock(recording)
        derived = {path for path, count in recording.reads.items() if count > 1}
        self.assertEqual(len(derived), 6)
        self.assertLessEqual(derived, guard.IDENTITY_INPUTS)
        self.assertLessEqual(guard.IDENTITY_INPUTS, set(guard.SOURCE_ROLES))
        for path in ("docs/reference/liquid-policy-wire-vectors.json", "tools/lcb/policy_contract.py",
                     "native/include/cybersand/liquid_policy_catalogue.hpp"):
            self.assertIn(path, guard.IDENTITY_INPUTS)
        self.assertNotIn(self.PATH, guard.IDENTITY_INPUTS)

    def test_ordered_chain_admits_a_later_reviewed_edit(self):
        self.write(self.second_bytes)
        self.assertEqual(self.check((self.step1, self.step2))["reviewed_transitions"], [self.step1, self.step2])

    def test_old_bytes_are_refused_once_a_transition_exists(self):
        self.reject((self.step1,), "world_pressure.inc: .*expected reviewed transition target")

    def test_further_edit_beyond_the_target_needs_its_own_step(self):
        self.write(self.first_bytes + b"// unreviewed\n")
        self.reject((self.step1,), "A further edit needs its own reviewed transition")
        self.write(self.second_bytes)
        self.reject((self.step1,), "expected reviewed transition target")

    def test_unreviewed_edit_and_lock_only_hash_edit_still_fail(self):
        self.write(self.first_bytes)
        self.reject((), "world_pressure.inc: LF source-byte drift")
        value = copy.deepcopy(self.lock)
        for entry in value["source_locks"]:
            if entry["path"] == self.PATH:
                entry["lf_sha256"] = guard.sha(self.first_bytes)
        self.lock_path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        self.reject((), "/source_locks: differs from immutable")
        self.reject((self.step1,), "/source_locks: differs from immutable")

    def test_transition_does_not_cover_any_other_locked_file(self):
        self.write(self.first_bytes)
        other = "native/src/world.cpp"
        self.write(self.sources[other] + b"\n// riding along\n", other)
        self.reject((self.step1,), "world.cpp: LF source-byte drift")

    def test_target_hash_must_be_the_authenticated_commit_bytes(self):
        forged = self.first_bytes + b"// forged\n"
        self.write(forged)
        self.reject((self.entry(self.baseline_bytes, forged, self.first),), "not the authenticated bytes")

    def test_from_hash_must_be_the_currently_admitted_hash(self):
        self.write(self.first_bytes)
        self.reject((dict(self.step1, from_lf_sha256="0" * 64),), "from_lf_sha256 must equal")
        self.write(self.second_bytes)
        self.reject((self.step2,), "from_lf_sha256 must equal")
        self.reject((self.step1, self.step1), r"REVIEWED_TRANSITIONS\[1\].*from_lf_sha256 must equal")

    def test_noop_transition_is_refused(self):
        self.reject((self.entry(self.baseline_bytes, self.baseline_bytes, self.first),), "must change the bytes")

    def test_squashed_or_unretained_commit_is_refused(self):
        changed = self.first_bytes + b"// squashed\n"
        self.write(changed)
        self.reject((self.entry(self.baseline_bytes, changed, self.unretained),), "not retained in HEAD's history")

    def test_commit_must_descend_from_the_baseline_and_previous_step(self):
        self.write(self.first_bytes)
        self.reject((self.entry(self.baseline_bytes, self.first_bytes, self.predecessor),),
                    "does not descend from " + guard.BASELINE)
        self.write(self.second_bytes)
        self.reject((self.step1, dict(self.step2, source_commit=self.unretained)), "does not descend from " + self.first)

    def test_unknown_or_identity_paths_are_refused(self):
        self.reject((dict(self.step1, path="native/src/unlisted.cpp"),), "is not a protected consumer")
        self.reject((dict(self.step1, path=["native/src/world.cpp"]),), "is not a protected consumer")
        for name in sorted(guard.IDENTITY_INPUTS):
            with self.subTest(name=name):
                self.assertIn(name, guard.SOURCE_ROLES)
                self.reject((dict(self.step1, path=name),), "feeds a retained identity")

    def test_record_must_be_committed_and_name_every_fact(self):
        self.write(self.first_bytes)
        self.reject((dict(self.step1, record="docs/audits/missing.md"),), "is not committed at HEAD")
        self.reject((dict(self.step1, record=self.UNRELATED),), "does not name")
        for omitted, record in self.partial.items():
            with self.subTest(omitted=omitted):
                self.reject((dict(self.step1, record=record),), "does not name " + re.escape(self.step1[omitted]))
        for record in ("docs/other/record.md", "docs/audits/../record.md", "docs/audits/record.txt"):
            with self.subTest(record=record):
                self.reject((dict(self.step1, record=record),), "record: expected a Markdown path")

    def test_fields_are_exact_and_strictly_typed(self):
        self.write(self.first_bytes)
        extra = dict(self.step1, accepted=True)
        missing = {key: value for key, value in self.step1.items() if key != "pr"}
        for transitions, expression in (
                ((extra,), "expected exactly"), ((missing,), "expected exactly"), (("entry",), "expected exactly"),
                ((dict(self.step1, pr=True),), "pr: expected a positive integer"),
                ((dict(self.step1, issue=0),), "issue: expected a positive integer"),
                ((dict(self.step1, source_commit=self.first[:12]),), "source_commit: expected a full"),
                ((dict(self.step1, source_commit=self.first.upper()),), "source_commit: expected a full"),
                ((dict(self.step1, to_lf_sha256=self.step1["to_lf_sha256"].upper()),), "to_lf_sha256: expected"),
                ({"0": self.step1}, "expected an ordered sequence")):
            with self.subTest(transitions=transitions):
                self.reject(transitions, expression)

    def test_production_table_is_valid_and_excludes_identity_inputs(self):
        lock = guard.read_lock(guard.ROOT / guard.LOCK)
        targets = guard.admitted_transitions(lock, guard.REVIEWED_TRANSITIONS, guard.ROOT)
        self.assertFalse(set(targets) & guard.IDENTITY_INPUTS)
        self.assertIsInstance(guard.REVIEWED_TRANSITIONS, tuple)


if __name__ == "__main__":
    unittest.main()
