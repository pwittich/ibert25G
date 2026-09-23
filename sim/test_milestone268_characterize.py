import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import milestone268_characterize as c


def clean_capture():
    overview = {"request sequence": 1, "response sequence": 1,
                "hardware run ID": 1, "engine state": 0,
                "hardware summary": 0x40401, "response code": 0x40401}
    lanes = {str(n): [0x1800 | n, 0, 0, 8000, 0, 0, 100, 0] for n in range(12, 16)}
    meta = [0x54520001, 130, 1, 1, 0, 0, 0, 0]
    return dict(restart_before=[0x52430001, 1, 0, 0, 0, 0, 0, 0], epoch_before=0,
                capture=dict(overview=overview, overview_after=copy.deepcopy(overview),
                             lanes=lanes, lanes_after=copy.deepcopy(lanes),
                             metadata_before=meta, metadata_after=list(meta),
                             slots=[[0] * 8 for _ in range(64)],
                             recovery=[0x52430001, 1, 1, 1, 0xf0303, 1, 0, 0],
                             platform=[0, 1 << 30, 0, 1 << 19, 0, 0, 0, 0],
                             profiles={str(n): [0x45520001, 100, 0, 0, 0, 0, 1, 0]
                                       for n in range(12, 16)}))


class OperatorValidation(unittest.TestCase):
    def test_clean(self):
        c.validate(clean_capture(), 1, 1, "clean")

    def test_wrong_sequence(self):
        with self.assertRaises(RuntimeError):
            c.validate(clean_capture(), 2, 1, "clean")

    def test_unexpected_restart(self):
        raw = clean_capture()
        raw["capture"]["recovery"][2:4] = [2, 2]
        raw["capture"]["recovery"][5] = 2
        with self.assertRaises(RuntimeError):
            c.validate(raw, 1, 1, "clean")

    def test_torn_publication(self):
        raw = clean_capture()
        raw["capture"]["lanes_after"]["12"][3] += 1
        with self.assertRaises(RuntimeError):
            c.validate(raw, 1, 1, "clean")

    def test_no_evidence_of_stimulus(self):
        with self.assertRaises(RuntimeError):
            c.validate(clean_capture(), 1, 1, "external-pulse")


if __name__ == "__main__":
    unittest.main()
