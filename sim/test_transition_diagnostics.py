import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import transition_diagnostics as d


class DiagnosticDecodeTest(unittest.TestCase):
    def test_ring_order(self):
        m = d.metadata([0x54520001, (64 << 7) | (3 << 1) | 0x4000, 1, 67, 0, 0, 0, 0])
        slots = [[n, 0, 0, 0, 0, 0, 0, 0] for n in range(64)]
        self.assertEqual([r["tick"] for r in d.chronological(m, slots)],
                         list(range(3, 64)) + [0, 1, 2])

    def test_active_rejected(self):
        with self.assertRaises(ValueError):
            d.chronological(dict(active=True), [])

    def test_expanded_ring(self):
        m = d.metadata([0x54520002, (256 << 9) | (44 << 1) | (1 << 18), 1, 300, 0, 0, 0, 0])
        slots = [[n, 0, 0, 0, 0, 0, 0, 0] for n in range(256)]
        self.assertEqual(m["capacity"], 256)
        self.assertTrue(m["overflow"])
        self.assertEqual([r["tick"] for r in d.chronological(m, slots)],
                         list(range(44, 256)) + list(range(44)))

    def test_profile(self):
        r = d.profile([0x45520001, 100, 7, 4, 20, 32, 1, 0])
        self.assertEqual(r["error_span"], 13)
        self.assertEqual(r["maximum_consecutive"], 4)

    def test_incomplete_and_saturated(self):
        for values in ([0x45520001, 100, 0, 0, 0, 0, 0, 0],
                       [0x45520001, 0xffffffff, 0, 0, 0, 0, 1, 0]):
            with self.assertRaises(ValueError):
                d.profile(values)


if __name__ == "__main__":
    unittest.main()
