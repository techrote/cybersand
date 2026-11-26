"""Configuration/refusal tests; these do not qualify an engine or application."""
import copy
import unittest
from unittest import mock

import atomic_delivery
import recovery_policy as policy
import package_windows as package


class AtomicOwnerPolicyTests(unittest.TestCase):
    def configuration(self,architecture='atomic_separate4',experimental='none'):
        value=copy.deepcopy(policy.selection())
        value.update(architecture=architecture,experimental_architecture=experimental,
            actual_submission=policy.ARCHITECTURES[architecture]['actual_submission'],
            render_lookahead=policy.ARCHITECTURES[architecture]['render_lookahead'])
        return value

    def test_no_implicit_engine_selection_or_bound_drift(self):
        for architecture in policy.ARCHITECTURES:
            value=self.configuration(architecture)
            policy.validate_selection(value)
            for field in ('actual_submission','render_lookahead'):
                bad=copy.deepcopy(value);bad[field]+=1
                with self.assertRaises(ValueError):policy.validate_selection(bad)

    def test_fallback_always_disables_experiments_and_keeps_stock(self):
        value=self.configuration(experimental='atomic_separate4');value['water_composition']=1
        self.assertEqual(policy.configuration(value,'fallback')['engine'],'stock')
        self.assertEqual(policy.configuration(value,'fallback')['render_thread'],'safe')
        self.assertEqual(set(policy.selectors(value,'fallback').values()),{'0'})
        self.assertEqual(set(policy.selectors(value,'fallback','D').values()),{'0'})
        with self.assertRaises(ValueError):policy.configuration(value,'selected','D')
        with self.assertRaises(ValueError):policy.configuration(value,'experimental','D')

    def test_optional_experiment_has_independent_explicit_mode(self):
        value=self.configuration('stock_safe','atomic_separate4')
        self.assertEqual(policy.configuration(value)['engine'],'stock')
        self.assertEqual(policy.configuration(value,'experimental')['render_lookahead'],4)
        comparisons=policy.scene_comparison_commands(value)
        self.assertEqual(len(comparisons),8)
        self.assertEqual({row['scene'] for row in comparisons.values()},{'wave512','wave1024','wave2048','mixed2048'})
        with mock.patch.object(policy,'selection',return_value=value):
            command=package.command('a'*40,mode='Experimental').decode()
            self.assertIn('-RecoveryMode Experimental',command)
            self.assertIn('-Engine Atomic -RenderThread Separate',command)
            self.assertIn('-Engine Stock -RenderThread Safe',package.command('a'*40).decode())
        value['experimental_architecture']='none'
        with self.assertRaises(ValueError):policy.configuration(value,'experimental')
        self.assertEqual({row['mode'] for row in policy.scene_comparison_commands(value).values()},{'Fallback'})

    def test_unqualified_native_candidate_cannot_be_selected(self):
        value=self.configuration();value['task_completion']=1
        with self.assertRaises(ValueError):policy.validate_selection(value)

    def test_engine02_custody_cannot_be_substituted_before_file_access(self):
        record={'root':atomic_delivery.ENGINE_ROOT,'gui':{'path':atomic_delivery.GUI,'sha256':atomic_delivery.pin()['gui_sha256']},
            'version':'4.7.stable.cybersand_egl_font_atomic.5b4e0cb0f','artifact':atomic_delivery.pin(),
            'provenance_sha256':atomic_delivery.pin()['proof_sha256'],'default':False}
        for key,value in (('source','f'*40),('run',45709374785),('attempt',2),('gui_sha256','0'*64)):
            bad=copy.deepcopy(record);bad['artifact'][key]=value
            with self.assertRaisesRegex(ValueError,'custody'):
                atomic_delivery.verify('/nonexistent',bad)
        record['default']=True
        with self.assertRaisesRegex(ValueError,'selection'):
            atomic_delivery.verify('/nonexistent',record)

    def test_component_cannot_stand_in_for_application_qualification(self):
        engine={'gui':{'sha256':atomic_delivery.pin()['gui_sha256']}}
        source={'source_tree':'b'*40,'native':{'sha256':'c'*64}}
        with self.assertRaisesRegex(ValueError,'Windows application custody'):
            atomic_delivery.verify_gate({'complete':True,'public_api_equivalent':True},engine,'a'*40,source,False)


if __name__=='__main__':unittest.main()
