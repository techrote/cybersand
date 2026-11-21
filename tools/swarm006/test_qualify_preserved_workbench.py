#!/usr/bin/env python3
"""Reject incomplete preservation reports and uncommitted executable source."""
import unittest
import json
from unittest.mock import patch

import qualify_preserved_workbench as q


class CompletionTests(unittest.TestCase):
    def test_complete_real_reports_and_no_duplicate_completion(self):
        line = 'SWARM004_CONTROLS {"checks":280,"failures":[],"completed":true}'
        self.assertEqual(q.completion(line, "SWARM004_CONTROLS")["checks"], 280)
        for invalid in ("", line + "\n" + line, line.replace('true', 'false'), line.replace('[]', '["failed"]'), line.replace('280', '0')):
            with self.assertRaises(ValueError):
                q.completion(invalid, "SWARM004_CONTROLS")

    def test_native_architecture_and_real_water_completion_are_required(self):
        arch = 'ARCHITECTURE_RESULTS phase=native checks=300 failures=0 complete=true'
        self.assertEqual(q.completion(arch, "ARCHITECTURE_RESULTS")["checks"], 300)
        with self.assertRaises(ValueError):
            q.completion(arch.replace('true', 'false'), "ARCHITECTURE_RESULTS")
        record = {"checks":100,"failures":[],"real_workbench":True,"sections":dict.fromkeys(q.WATER_SECTIONS, True)}
        water = 'WORKBENCH_WAVE_RESULT ' + json.dumps(record)
        self.assertEqual(q.completion(water, "WORKBENCH_WAVE_RESULT")["checks"], 100)
        for sections in ({}, {"activation":True}, dict.fromkeys(q.WATER_SECTIONS, False), dict.fromkeys(q.WATER_SECTIONS, 1)):
            with self.assertRaises(ValueError):
                q.completion('WORKBENCH_WAVE_RESULT ' + json.dumps(dict(record, sections=sections)), "WORKBENCH_WAVE_RESULT")

    def test_generated_uid_does_not_hide_real_untracked_or_modified_source(self):
        with patch.object(q, 'git', side_effect=[' M godot/scripts/existing.gd', 'godot/tests/generated.gd.uid\ngodot/shaders/generated.gdshader.uid\ngodot/tests/new.gd\ngodot/scenes/new.tscn']):
            delta = q.source_delta(('godot/tests', 'godot/scripts'))
        self.assertIn(' M godot/scripts/existing.gd', delta)
        self.assertIn('?? godot/tests/new.gd', delta)
        self.assertNotIn('generated.gd.uid', delta)
        self.assertNotIn('generated.gdshader.uid', delta)
        self.assertIn('?? godot/scenes/new.tscn', delta)

    def test_mode_and_scale_cannot_substitute_for_fresh_process_reopen(self):
        paint = 'PAINT_EDITOR_WORKBENCH {"checks":12,"failures":[],"reopen":"1"}'
        q.completion(paint, 'PAINT_EDITOR_WORKBENCH', 'paint-reopen')
        with self.assertRaises(ValueError):
            q.completion(paint.replace('"1"', '"0"'), 'PAINT_EDITOR_WORKBENCH', 'paint-reopen')
        record = {"checks":100,"failures":[],"completed":True,"phase":"reopen","side":512,"workers":1,"canonical_bytes":524288}
        q.completion('FLATTEN_RESULT '+json.dumps(record), 'FLATTEN_RESULT', 'flatten-reopen')
        for key, value in (("phase","author"),("side",16),("workers",8),("workers",True),("canonical_bytes",512)):
            with self.assertRaises(ValueError):
                q.completion('FLATTEN_RESULT '+json.dumps(dict(record, **{key:value})), 'FLATTEN_RESULT', 'flatten-reopen')

    def test_project_and_scene_assets_are_in_source_identity(self):
        with patch.object(q, 'git', return_value='godot/project.godot\ngodot/main.tscn'), patch.object(q, 'sha', side_effect=['project-sha','scene-sha']):
            self.assertEqual(q.source_inputs(), {'godot/project.godot':'project-sha','godot/main.tscn':'scene-sha'})


if __name__ == '__main__':
    unittest.main()
