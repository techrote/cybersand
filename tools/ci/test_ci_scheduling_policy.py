import copy
from pathlib import Path
import tempfile
import unittest
import re
import yaml

from check_ci_scheduling_policy import check, inventory, matrix_cardinality, routine_concurrency, WorkflowLoader


class SchedulingPolicyTests(unittest.TestCase):
    def test_every_workflow_is_inventoried_and_valid(self):
        root = Path(__file__).resolve().parents[2]
        report = inventory(root)
        expected = {p.relative_to(root).as_posix() for p in (root / '.github/workflows').glob('*.y*ml')}
        self.assertEqual({w['file'] for w in report['workflows']}, expected)
        self.assertEqual(check(report), [])

    def test_actions_on_key_and_duplicate_rejection(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            folder = root / '.github/workflows'
            folder.mkdir(parents=True)
            path = folder / 'sample.yml'
            path.write_text('on: [push, workflow_dispatch]\njobs:\n  test:\n    runs-on: ubuntu-24.04\n')
            self.assertEqual(set(inventory(root)['workflows'][0]['triggers']), {'push', 'workflow_dispatch'})
            path.write_text('on: push\njobs:\n  test: {}\n  test: {}\n')
            with self.assertRaisesRegex(ValueError, 'duplicate YAML key'):
                inventory(root)

    def test_cartesian_exclusion_and_include_expansion(self):
        self.assertEqual(matrix_cardinality({'os': ['linux', 'windows'], 'n': ['1', '2']}), 4)
        self.assertEqual(matrix_cardinality({'os': ['linux', 'windows'], 'n': ['1', '2'],
            'exclude': [{'os': 'linux', 'n': '1'}], 'include': [{'extra': 'yes'}, {'os': 'macos'}]}), 4)
        # Includes augment original rows; incompatible includes become new rows.
        self.assertEqual(matrix_cardinality({'fruit': ['apple', 'pear'],
            'include': [{'color': 'green'}, {'fruit': 'apple', 'color': 'red'},
                        {'fruit': 'banana'}, {'fruit': 'banana', 'color': 'yellow'}]}), 4)
        self.assertEqual(matrix_cardinality({'include': [{'x': '1'}, {'x': '2'}]}), 2)
        self.assertEqual(matrix_cardinality({'os': []}), 0)

    def test_dynamic_counts_are_never_invented(self):
        for matrix in ['${{ fromJSON(needs.plan.outputs.matrix) }}',
                       {'case': '${{ inputs.cases }}'}, {'case': ['${{ inputs.case }}']}]:
            self.assertIsNone(matrix_cardinality(matrix))

    def report(self):
        return {'workflows': [{'file': '.github/workflows/example.yml',
            'triggers': {'workflow_dispatch': None}, 'concurrency': None,
            'jobs': [{'id': 'test', 'strategy': {'matrix': {'case': ['a', 'b', 'c']},
                     'fail-fast': 'false', 'max-parallel': '2'}, 'literal_matrix_jobs': 3}]}]}

    def test_missing_or_unbounded_parallelism_is_rejected(self):
        for value in [None, '0', '9', '${{ inputs.parallelism }}', 'true']:
            report = self.report()
            strategy = report['workflows'][0]['jobs'][0]['strategy']
            if value is None:
                del strategy['max-parallel']
            else:
                strategy['max-parallel'] = value
            self.assertTrue(check(report))

    def test_manual_cancellation_and_matrix_fail_fast_are_rejected(self):
        report = self.report()
        self.assertEqual(check(report), [])
        report['workflows'][0]['concurrency'] = {'group': 'same-ref', 'cancel-in-progress': 'true'}
        self.assertTrue(check(report))
        report['workflows'][0]['concurrency'] = None
        report['workflows'][0]['jobs'][0]['strategy']['fail-fast'] = 'true'
        self.assertTrue(check(report))

    def test_routine_pr_group_and_manual_run_identity_are_enforced(self):
        report = self.report()
        workflow = report['workflows'][0]
        workflow['file'] = '.github/workflows/native.yml'
        workflow['concurrency'] = routine_concurrency('native')
        self.assertEqual(check(report), [])
        for group in ['native-${{ github.ref }}', 'all-ci', 'native-${{ github.sha }}']:
            changed = copy.deepcopy(report)
            changed['workflows'][0]['concurrency']['group'] = group
            self.assertTrue(check(changed))

    def test_stress_inventory_is_preserved_and_capped(self):
        report = inventory(Path(__file__).resolve().parents[2])
        stress = next(w for w in report['workflows'] if w['file'].endswith('/physical-timeout-stress.yml'))
        cases = [j for j in stress['jobs'] if j['id'] in {'stress-linux', 'stress-windows'}]
        self.assertEqual(len(cases), 2)
        self.assertTrue(all(j['literal_matrix_jobs'] == 10 for j in cases))
        self.assertTrue(all(j['runner_slots_upper_bound'] == 3 for j in cases))

    def test_rapier_exception_cannot_hide_growing_fanout(self):
        report = self.report()
        report['workflows'][0]['file'] = '.github/workflows/rapier-bvh-build.yml'
        job = report['workflows'][0]['jobs'][0]
        del job['strategy']['max-parallel']
        job['literal_matrix_jobs'] = 2
        self.assertEqual(check(report), [])
        job['literal_matrix_jobs'] = 3
        self.assertTrue(check(report))

    def test_repaired_parent_budgets_cover_explicit_children_and_headroom(self):
        root = Path(__file__).resolve().parents[2]
        repaired = {
            'physical-actor-stress.yml': ['linux-build'],
            'physical-timeout-stress.yml': ['linux-build'],
            'issue49-water-apparatus.yml': ['apparatus'],
            'release-hashes.yml': ['hashes'],
            'play-busy001b-host.yml': ['linux-real-host', 'windows-build'],
        }
        for filename, names in repaired.items():
            workflow = yaml.load((root / '.github/workflows' / filename).read_text(), Loader=WorkflowLoader)
            for name in names:
                with self.subTest(workflow=filename, job=name):
                    job = workflow['jobs'][name]
                    scripts = '\n'.join(step.get('run', '') for step in job['steps'])
                    child_minutes = sum(int(value) for value in re.findall(r'\btimeout (\d+)m\b', scripts))
                    self.assertGreater(child_minutes, 0)
                    self.assertGreaterEqual(int(job['timeout-minutes']), child_minutes + 10)


if __name__ == '__main__':
    unittest.main()
