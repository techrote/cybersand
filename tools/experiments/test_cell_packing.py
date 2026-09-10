"""L2 campaign boundaries and pairing, without starting native processes."""
import unittest
from pathlib import Path
from collections import defaultdict
import json
import tempfile
import gzip
import cell_packing
import summarize_cell_packing


class PackingPlanTests(unittest.TestCase):
    def test_registered_budget_and_interleaving(self):
        rows=cell_packing.plan()
        groups=defaultdict(list)
        for row in rows:
            self.assertEqual(row['ticks'],1920)
            groups[(row['comparison'],row['fixture'],row['extent'],row['workers'])].append(row)
        self.assertEqual(len(rows),448)
        self.assertEqual(len(groups),32)
        self.assertEqual(sum(r['comparison'].startswith('packing') for r in rows),280)
        self.assertEqual(sum(r['comparison'].startswith('bridge') for r in rows),56)
        self.assertEqual(sum(r['comparison'].startswith('observer') for r in rows),112)
        for series in groups.values():
            self.assertEqual(len(series),14)
            for pair in range(7):
                members=series[2*pair:2*pair+2]
                self.assertEqual([r['pair'] for r in members],[pair,pair])
                self.assertEqual([r['member'] for r in members],[0,1] if pair%2==0 else [1,0])

    def test_owner_hold_precedes_file_or_process_access(self):
        with self.assertRaisesRegex(RuntimeError,'Uncontended'):
            cell_packing.measure(Path('missing-and-must-not-be-opened'),False)

    def test_reduction_requires_all_registered_processes(self):
        with tempfile.TemporaryDirectory(dir=cell_packing.OUT) as tmp:
            directory=Path(tmp)
            plan=cell_packing.plan()
            (directory/'plan.json').write_text(json.dumps(plan))
            (directory/'identity.json').write_text(json.dumps(dict(plan=plan)))
            (directory/'results.json').write_text('[]')
            with self.assertRaisesRegex(ValueError,'Incomplete'):
                summarize_cell_packing.summarize(directory)
            self.assertFalse((directory/'reduced.json').exists())

    def test_compressed_retained_setup_is_compared_losslessly(self):
        with tempfile.TemporaryDirectory(dir=cell_packing.OUT) as tmp:
            reference,record=Path(tmp)/'retained.records.gz',Path(tmp)/'new.records'
            data=bytes(range(256))*5000
            with gzip.open(reference,'wb') as stream: stream.write(data)
            record.write_bytes(data)
            cell_packing.equal_archived_files(reference,record)
            record.write_bytes(data[:-1]+b'!')
            with self.assertRaisesRegex(RuntimeError,'Exact archived'):
                cell_packing.equal_archived_files(reference,record)


if __name__=='__main__': unittest.main()
