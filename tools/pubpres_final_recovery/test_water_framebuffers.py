"""Adversarial checks for replay of the native Water framebuffer evidence."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import zlib


def png(rgb):
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))
    header = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes([0, *rgb]))) + chunk(b"IEND", b"")


class WaterFramebuffers(unittest.TestCase):
    def test_complete_control_and_rejected_evidence(self):
        spec = importlib.util.spec_from_file_location("recovery_water_reader", Path(__file__).with_name("run_qualification.py"))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        labels = ["initial_authoring_framebuffer", "submerged_framebuffer", "water_refill_framebuffer",
                  "restored_authoring_framebuffer", "multipart_limb_framebuffer"]
        steps = {str(slot): 12 for slot in range(6)}
        data = {"lifecycle": [{"stage": "multipart_motion", "steps": steps, "origins": dict(steps)}], "framebuffer": []}
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            for label in labels:
                for mode in ("shown", "hidden-control", "restored"):
                    (folder / (label + "-" + mode + ".png")).write_bytes(png([0, 0, 0] if mode == "hidden-control" else [255, 0, 0]))
                pixel = {"pixel": [0, 0], "shown": [1, 0, 0], "hidden": [0, 0, 0], "restored": [1, 0, 0]}
                data["framebuffer"].append({"label": label, "slot": 4, "size": [1, 1], "pixel_point": [0, 0],
                    "shown_identity": {"world": 1}, "hidden_identity": {"world": 1}, "restored_identity": {"world": 1},
                    "policy_order": ["1", "0", "1"], "pixels": [pixel], "maximum_visible_difference": 1,
                    "maximum_restored_error": 0})
            moving = folder / "moving-runner.png"
            moving.write_bytes(png([255, 0, 0]))
            self.assertEqual(len(module.water_framebuffers(data, folder)), 16)
            moving.unlink()
            with self.assertRaises(FileNotFoundError):
                module.water_framebuffers(data, folder)
            data["framebuffer"][1]["pixels"][0]["restored"] = [0.9, 0, 0]
            with self.assertRaisesRegex(ValueError, "visible/restored"):
                module.water_framebuffers(data, folder)
            data["framebuffer"].pop()
            with self.assertRaisesRegex(ValueError, "phase"):
                module.water_framebuffers(data, folder)


if __name__ == "__main__":
    unittest.main()
