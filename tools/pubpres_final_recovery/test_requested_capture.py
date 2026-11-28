from __future__ import annotations
import ast
from pathlib import Path
import unittest

class RequestedCapturePreservation(unittest.TestCase):
    def test_only_registered_backend_parameter_is_added(self):
        root=Path(__file__).resolve().parents[2]
        old=(root/'tools/pubpres_final/run_renderer_comparison.py').read_text()
        node=next(n for n in ast.parse(old).body if isinstance(n,ast.FunctionDef) and n.name=='validate_requested_renderer')
        expected=ast.get_source_segment(old,node).replace('thread: str):','thread: str, *, expected_driver: str):').replace('"renderer": "opengl3_angle"','"renderer": expected_driver')
        actual=(Path(__file__).parent/'requested_capture.py').read_text()
        node=next(n for n in ast.parse(actual).body if isinstance(n,ast.FunctionDef) and n.name=='validate_requested_renderer')
        self.assertEqual(ast.dump(ast.parse(ast.get_source_segment(actual,node))),ast.dump(ast.parse(expected)))

if __name__=='__main__':unittest.main()
