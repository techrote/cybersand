import json
from pathlib import Path
import tempfile
import unittest

from analyze_pose_trace import read_trace, analyze


def body(source, x, gap=10, residual=0):
    return {"slot": 0, "source": source, "selected_screen": [x, 100],
            "screen_selected": {"residual_magnitude_px": residual},
            "live_screen": [x + gap, 100], "bound_screen": [x, 100],
            "guard_reason": "empty_swept_mask" if source == "live" else "material_in_swept_mask"}


def frame(n, source, x, phase=None, residual=0):
    return {"type": "frame", "process_frame": n, "time_usec": 10000*n,
            "camera_mode": 1, "camera_presented": [n, 40],
            "camera_screen_phase_px": phase or [0, 0],
            "bodies": [body(source, x, residual=residual)]}


class FrameTraceAnalysisTests(unittest.TestCase):
    def test_pose_switch_and_projection_error_have_distinct_attribution(self):
        frames = [frame(1, "mask_bound", 100),
                  frame(2, "live", 113),
                  frame(3, "live", 130, residual=3)]
        result = analyze(frames, 8.0)
        self.assertEqual(result["event_causes"]["live_vs_bound_source_switch"], 1)
        self.assertEqual(result["event_causes"]["spatial_projection_mismatch"], 1)
        self.assertEqual(result["projection_residual_over_1px"], 1)

    def test_stationary_bound_screen_jumps_detect_staleness(self):
        result = analyze([frame(1, "mask_bound", 100), frame(2, "mask_bound", 120)], 8)
        self.assertEqual(result["event_causes"]["stale_mask_bound_pose"], 1)

    def test_reject_incomplete_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "trace.jsonl"
            path.write_text('{"type":"header","schema":"cybersand-pose-trace-v1"}\n')
            with self.assertRaises(ValueError):
                read_trace(path)

    def test_complete_file_and_counts(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "trace.jsonl"
            lines = [{"type":"header","schema":"cybersand-pose-trace-v1"},
                     frame(1,"mask_bound",100),
                     {"type":"summary","frames":1,"dropped":0}]
            path.write_text("\n".join(map(json.dumps,lines))+"\n")
            header, frames, footer = read_trace(path)
            self.assertEqual(len(frames),1)
            self.assertEqual(footer["dropped"],0)


if __name__=="__main__":
    unittest.main()
