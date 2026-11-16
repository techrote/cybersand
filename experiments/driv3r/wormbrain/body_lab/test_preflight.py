"""Pure-stdlib, no fake model/native execution in tests."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from experiments.driv3r.wormbrain.body_lab.preflight import (
    HostView, Refusal, Lease, FourSlotPreflight, native_envelope, swept_menu,
    corrected_prompt, new_ink_from_readbacks, synthetic_world, demo
)


def empty(protected=()):
    return HostView((0,)*9216,protected)


class BodyLabPreflight(unittest.TestCase):
    def test_36_36_64_8_is_only_current_native_envelope(self):
        self.assertEqual(native_envelope(36,36,64,8),(36,36,64,8))
        for values in ((128,36,64,8),(36,128,64,8),(36,36,128,8),(36,36,64,9)):
            with self.subTest(values=values), self.assertRaises(Refusal):
                native_envelope(*values)
        with self.assertRaises(Refusal):
            native_envelope(1,1,1,0,extended=True)

    def test_negative_or_boolean_budget_refused(self):
        for n in (-1,True,1.25):
            with self.assertRaises(Refusal):
                native_envelope(n,0,0,0)

    def test_four_cell_swept_does_not_jump_intermediate_obstacles(self):
        menu=swept_menu(empty(((14,24,1,1),)),(12,24))
        self.assertEqual(menu["INK_E_1"],((13,24),))
        self.assertNotIn("INK_E_2",menu)
        self.assertEqual(menu["INK_W_4"],((11,24),(10,24),(9,24),(8,24)))
        self.assertEqual(menu["STOP"],())

    def test_swept_respects_focus_and_max_four(self):
        with self.assertRaises(Refusal):
            swept_menu(empty(),(12,24),span=5)
        with self.assertRaises(Refusal):
            swept_menu(empty(),(-1,24))
        menu=swept_menu(empty(),(0,0))
        self.assertNotIn("INK_N_1",menu)
        self.assertNotIn("INK_W_1",menu)
        self.assertIn("INK_E_4",menu)

    def test_swept_respects_existing_ink(self):
        material=[0]*9216
        material[24*96+14]=58
        menu=swept_menu(HostView(tuple(material)),(12,24))
        self.assertIn("INK_E_1",menu)
        self.assertNotIn("INK_E_2",menu)

    def test_actual_inked_cells_not_cursor_history_length(self):
        initial=empty()
        changed=list(initial.material)
        changed[24*96+13]=58
        changed[24*96+14]=58
        final=HostView(tuple(changed))
        self.assertEqual(new_ink_from_readbacks(initial,final),2)
        state={"already_inked_cells_this_run":8,"recent_positions":[[12,24]]*8}
        corrected=corrected_prompt(state,initial,final)
        self.assertEqual(corrected["already_inked_cells_this_run"],2)
        self.assertEqual(state["already_inked_cells_this_run"],8)

    def test_protected_or_nonink_material_change_rejected(self):
        initial=empty(((40,40,2,2),))
        changed=list(initial.material)
        changed[40*96+40]=58
        with self.assertRaises(Refusal):
            new_ink_from_readbacks(initial,HostView(tuple(changed),initial.protected))
        changed[40*96+40]=0
        changed[25*96+24]=57
        with self.assertRaises(Refusal):
            new_ink_from_readbacks(initial,HostView(tuple(changed),initial.protected))

    def test_four_distinct_worlds_no_duplicate_leases(self):
        f=FourSlotPreflight()
        for i in range(4):
            f.register(Lease(f"l{i}","wrangler",f"r{i//2}",f"world{i}","lm",570+i))
        self.assertEqual(f.summary()["registered"],4)
        self.assertEqual(f.summary()["verified_active_model_processes"],0)
        with self.assertRaises(Refusal):
            f.register(Lease("extra","wrangler","r3","world-extra","lm",0))
        g=FourSlotPreflight()
        g.register(Lease("same","wrangler","r1","world","lm",1))
        with self.assertRaises(Refusal):
            g.register(Lease("different","wrangler","r2","world","lm",2))

    def test_no_synthetic_stubs_counted_as_live_models(self):
        f=FourSlotPreflight()
        f.register(Lease("l","w","r","world","lm",1))
        with self.assertRaises(Refusal):
            f.add_synthetic("l",{"evidence_class":"native"})
        f.add_synthetic("l",{"evidence_class":"model-free-synthetic"})
        self.assertEqual(f.summary()["native_receipts"],0)
        self.assertEqual(f.summary()["verified_active_model_processes"],0)
        with self.assertRaises(Refusal):
            f.add_synthetic("l",{"evidence_class":"model-free-synthetic"})

    def test_four_original_synthetic_gallery_png_bytes_reproducible(self):
        with tempfile.TemporaryDirectory() as d:
            a=Path(d)/"one"
            b=Path(d)/"two"
            x=demo(a)
            self.assertEqual(x,demo(b))
            self.assertEqual(len(x["artifacts"]),4)
            self.assertEqual(x["roster"]["registered"],4)
            self.assertEqual(x["roster"]["verified_active_model_processes"],0)
            hashes=set()
            for item in x["artifacts"]:
                data=(a/item["png"]).read_bytes()
                self.assertTrue(data.startswith(b"\x89PNG\r\n\x1a\n"))
                self.assertEqual(hashlib.sha256(data).hexdigest(),item["png_sha256"])
                self.assertEqual(data,(b/item["png"]).read_bytes())
                hashes.add(item["png_sha256"])
                trace=json.loads((a/item["trace"]).read_text())
                self.assertFalse(trace["model_execution"])
                self.assertFalse(trace["native_execution"])
                self.assertLessEqual(trace["synthetic_painted_cells"],36)
            self.assertEqual(len(hashes),4)


if __name__=="__main__":
    unittest.main()
