"""Timing reductions retain actual provenance and never create a correctness gate."""

import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import execution_telemetry as subject


class TimingTests(unittest.TestCase):
    def test_all_existing_structured_marker_families_retain_phase_metrics(self):
        log = '\n'.join([
            'ACTOR_SESSION_TIMING {"steps":1200,"elapsed_usec":12345}',
            'PHYSICS_ASYNC {"completed_ticks":72,"worker_cpu_usec":43}',
            'PLAY_LIFE001_RESULT {"cycles":[{"construct_usec":4,"shutdown_usec":2},{"construct_usec":6,"shutdown_usec":3}]}',
            '{"step_usec":15,"construction_usec":25}',
        ])
        _, _, metrics = subject.runtime_observations(log)
        self.assertEqual(metrics['ACTOR_SESSION_TIMING.elapsed_usec'], 12345)
        self.assertEqual(metrics['PHYSICS_ASYNC.completed_ticks'], 72)
        self.assertEqual(metrics['PLAY_LIFE001_RESULT.cycles.construct_usec.count'], 2)
        self.assertEqual(metrics['PLAY_LIFE001_RESULT.cycles.construct_usec.max'], 6)
        self.assertEqual(metrics['NATIVE_JSON.step_usec'], 15)

    def test_renderer_and_compiler_unknowns_are_explicit(self):
        renderer, _, _ = subject.runtime_observations('OpenGL API 3.3 - ANGLE - D3D11\n')
        self.assertEqual(renderer['backend'], 'angle')
        self.assertEqual(renderer['compiler'], 'unknown')
        self.assertEqual(renderer['cache_state'], 'unknown')

    def test_failed_original_is_retained_without_ratio_verdict(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            value = subject.record_case(root, {'name':'native-test','role':'native-command','status':'failed',
                'elapsed_seconds':21,'natural_completion':True,'returncode':19}, 'late assertion failure', root=root)
            self.assertEqual(value['result'], 'failed')
            self.assertEqual(value['wall_seconds'], 21)
            self.assertNotIn('baseline_ratio', value)
            self.assertEqual(json.loads((root/'performance.jsonl').read_text()), value)

    def test_no_native_compiler_or_cpu_resource_claim_is_invented(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            value = subject.record_case(root, {'name':'native-test','role':'native-command',
                'status':'passed','elapsed_seconds':1,'natural_completion':True}, '', root=root)
            self.assertFalse(value['resources']['available'])
            self.assertEqual(value['renderer']['backend'], 'native')
            self.assertEqual(value['renderer']['cache_state'], 'not-applicable')

    def test_telemetry_source_reads_share_one_operation_allowance(self):
        subject.source_identity.cache_clear()
        with mock.patch.object(subject.time, 'monotonic', side_effect=[0,10,301,302]), \
             mock.patch.object(subject.subprocess,'check_output',return_value=b'') as command:
            value = subject.source_identity(Path('/timing-control'))
        self.assertEqual(command.call_count, 1)
        self.assertEqual(command.call_args.kwargs['timeout'], 290)
        self.assertIsNone(value['commit'])
        self.assertIsNone(value['tree'])
        subject.source_identity.cache_clear()


if __name__ == '__main__':
    unittest.main()
