#!/usr/bin/env python3
"""Fresh independent supplement controls; synthetic evidence, not qualification."""
from pathlib import Path
import sys
import unittest

ROOT = Path('/workspace/scratch/a3adba76fa99')
PROOF = ROOT / 'ci-opt003-evidence/worldgen-runtime-proof/tools/ci/ci_opt003_worldgen_runtime_proof'
PERFORMANCE = ROOT / 'ci-opt003-evidence/performance'
sys.path[:0] = [str(PROOF), str(PERFORMANCE)]
import test_compare_pair as fixtures
import audit_showcase_replay as audit
fixtures.REPOSITORY = ROOT / 'cybersand'


class IndependentReplayControls(fixtures.ReaderControls):
    def setUp(self):
        super().setUp()
        self.load('candidate')
        self.make_fixture()
        self.raw_path = self.root / 'source/build/worldgen-showcase-logs/test_megatruss_station.log'
        self.replay_path = self.folder / 'commands/worldgen-test/command.log'

    def test_valid_multiline(self):
        raw = self.raw_path.read_bytes()
        complete = raw + b'original second output row\n'
        self.raw_path.write_bytes(complete)
        self.replay_path.write_bytes(self.replay_path.read_bytes().replace(raw, complete, 1))
        self.reseal()
        self.verify()
        self.assertEqual(audit.audit(self.directory, 101, 1)['status'], 'passed')

    def test_truncated_complete_line_is_rejected_after_reseal(self):
        raw = self.raw_path.read_bytes()
        complete = raw + b'original second output row\n'
        self.replay_path.write_bytes(self.replay_path.read_bytes().replace(raw, complete, 1))
        # The raw file omits a complete final line; the command replay retains it.
        self.reseal()
        self.verify()
        with self.assertRaises(ValueError):
            audit.audit(self.directory, 101, 1)

    def test_duplicate_context_with_conflicting_body_is_rejected(self):
        header = self.raw_path.read_bytes().splitlines(keepends=True)[0]
        self.replay_path.write_bytes(self.replay_path.read_bytes() + header + b'contradictory second body\n')
        self.reseal()
        self.verify()
        with self.assertRaises(ValueError):
            audit.audit(self.directory, 101, 1)

    def test_valid_reverse_showcase_completion_order(self):
        replay = self.replay_path.read_bytes()
        names = self.expected['tests']['worldgen-test']['showcases']
        blocks = []
        for binary in names:
            raw = (self.root / 'source/build/worldgen-showcase-logs' / (Path(binary).name + '.log')).read_bytes()
            blocks.append(b'Running ' + binary.encode() + b'\n' + raw)
        complete = b''.join(blocks)
        self.assertIn(complete, replay)
        self.replay_path.write_bytes(replay.replace(complete, b''.join(reversed(blocks)), 1))
        self.reseal()
        self.verify()
        self.assertEqual(audit.audit(self.directory, 101, 1)['status'], 'passed')

    def test_valid_compiler_completion_between_showcases(self):
        replay = self.replay_path.read_bytes()
        line = next(line for line in replay.splitlines(keepends=True)
                    if line.startswith(b'g++-13 ') and line.endswith(b'-o build/test_seeded_typology_megablock\n'))
        raw = self.raw_path.read_bytes()
        replay = replay.replace(line, b'', 1).replace(raw, raw + line, 1)
        self.replay_path.write_bytes(replay)
        self.reseal()
        self.verify()
        self.assertEqual(audit.audit(self.directory, 101, 1)['status'], 'passed')


if __name__ == '__main__':
    names = ['test_valid_multiline', 'test_truncated_complete_line_is_rejected_after_reseal',
             'test_duplicate_context_with_conflicting_body_is_rejected',
             'test_valid_reverse_showcase_completion_order', 'test_valid_compiler_completion_between_showcases']
    result = unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(IndependentReplayControls(name) for name in names))
    raise SystemExit(not result.wasSuccessful())
