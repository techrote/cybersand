#!/usr/bin/env python3
"""Boundary/overlap adversaries for the supplemental retained-trace audit."""
import unittest

from causal_intervals import aggregate, intersection_usec, partition, union_intervals


class CausalIntervalTests(unittest.TestCase):
    def gap(self, native_time=30, callback=80):
        return partition({"time_usec":10},
                         {"time_usec":110,"start_usec":callback,"step":2,
                          "native_tick_used":7,"completed_body_sample":4},
                         {"time_usec":native_time} if native_time is not None else None,
                         [(0,20),(15,50),(40,60),(60,65),(95,120)])

    def test_nested_duplicate_adjacent_intervals_are_union_not_sum(self):
        values=[(15,50),(0,20),(40,60),(60,65),(15,50),(95,120),(130,130)]
        self.assertEqual(union_intervals(values),[(0,65),(95,120)])
        self.assertEqual(intersection_usec(values,30,80),35)
        self.assertEqual(intersection_usec(values,10,110),70)
        self.assertEqual(intersection_usec(values,65,95),0)
        self.assertEqual(intersection_usec(values,0,0),0)

    def test_partition_and_clipped_overlap_conserve_exact_gap(self):
        row=self.gap()
        self.assertTrue(row["ordered"])
        self.assertEqual(row["partition_ms"],{
            "previous_completion_to_native_observation":.020,
            "native_observation_to_successful_callback":.050,
            "successful_callback_to_completion":.030})
        self.assertEqual(row["publication_overlap_ms"],{
            "previous_completion_to_native_observation":.020,
            "native_observation_to_successful_callback":.035,
            "successful_callback_to_completion":.015,"entire_gap":.070})
        value=aggregate([row])
        self.assertAlmostEqual(value["publication_overlap"]["native_observation_to_successful_callback"]["share_of_this_partition"],.7)
        self.assertAlmostEqual(value["publication_overlap"]["entire_gap"]["share_of_ordered_inter_step_span"],.7)

    def test_missing_or_reversed_boundary_is_preserved_not_clamped(self):
        for native,callback in ((None,80),(5,80),(90,80),(120,80),(30,120),(30,5)):
            with self.subTest(native=native,callback=callback):
                row=self.gap(native,callback)
                self.assertFalse(row["ordered"])
                self.assertIsNone(row["partition_ms"])
                self.assertIsNone(row["publication_overlap_ms"])
                self.assertEqual(row["gap_ms"],.1)
                self.assertEqual(row["boundaries"]["native_completion_observed_usec"],native)
                self.assertEqual(row["boundaries"]["successful_callback_start_usec"],callback)
        value=aggregate([self.gap(),self.gap(90)])
        self.assertEqual((value["observed_gaps"],value["ordered_gaps"],value["unpartitioned_gaps"]),(2,1,1))
        self.assertEqual(value["unpartitioned_steps"],[2])
        self.assertEqual(value["all_observed_gap_ms"]["count"],2)
        self.assertEqual(value["gap_ms"]["count"],1)
        self.assertIsNone(aggregate([self.gap(None)])["partition"])

    def test_clock_types_and_reversed_transactions_refused(self):
        for values in ([(2,1)],[(True,2)],[(0,2.0)],[(-1,2)]):
            with self.subTest(values=values),self.assertRaises(ValueError):
                union_intervals(values)
        for value in (False,30.0,-1):
            with self.subTest(value=value),self.assertRaises(ValueError):
                self.gap(value)


if __name__ == "__main__":
    unittest.main()
