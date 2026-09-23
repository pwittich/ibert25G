import contextlib
import io
import unittest
from unittest.mock import Mock, patch
from test_firefly1_v5_oneway import FakeBox
from firefly1_v5_oneway_remote import Diagnostic
import firefly1_v5_all12_remote as gate


class Box(FakeBox):
    def write_u32(self, address, value):
        oldrun = self.reg[0xf8]
        super().write_u32(address, value)
        if address == 0xa0 and self.reg[0xa4] == 0x10501:
            self.reg[0xf8] = oldrun + 1
            self.reg[0xfc] = self.reg[0xf4] = 0x0c000c04 if self.fail_rx else gate.SUMMARY


class Tests(unittest.TestCase):
    def setUp(self):
        self.a, self.b = Box(), Box()
        self.a.reg.update({0xa0:5, 0xf0:5})
        self.b.reg.update({0xa0:6, 0xf0:6, 0xf8:1})
        self.now = 0
        self.source = Diagnostic(self.a, self.sleep, lambda: self.now, site='F1')
        self.rx = Diagnostic(self.b, self.sleep, lambda: self.now, site='F2')
        for endpoint in (self.source, self.rx):
            endpoint.evidence = Mock()
        self.data = {i:dict(id_status=0x1800+i, errors=0, lock_losses=0,
                           valid_cycles=gate.EXPECTED_CYCLES, tested_bits=80*gate.EXPECTED_CYCLES) for i in range(12)}

    def sleep(self, duration):
        self.now += duration

    def run_gate(self, profile='start'):
        with contextlib.redirect_stdout(io.StringIO()), patch.object(gate, 'compact'), patch.object(gate, 'read_lane', side_effect=lambda b,l:self.data[l]):
            gate.run(self.source, self.rx, lambda:[0]*12, profile, self.sleep, lambda:self.now)

    def test_two_distinct_clean_runs(self):
        self.run_gate()
        self.assertEqual(self.a.requests, [(6,2,180000,0xfff),(7,3,0,0xfff)])
        self.assertEqual(self.b.requests, [(7,2,180000,0xfff),(8,0x10501,10000,0xfff),(9,3,0,0xfff)])
        self.run_gate('repeat')
        self.assertEqual(self.a.requests[-2:], [(8,2,180000,0xfff),(9,3,0,0xfff)])
        self.assertEqual(self.b.requests[-3:], [(10,2,180000,0xfff),(11,0x10501,10000,0xfff),(12,3,0,0xfff)])
        self.assertEqual(self.b.reg[0xf8],3)

    def test_wrong_predecessor_refused(self):
        self.b.reg[0xf0]=5
        with self.assertRaises(RuntimeError): self.run_gate()
        self.assertEqual(self.a.requests+self.b.requests, [])

    def test_acquisition_failure_preserved(self):
        self.b.fail_rx=True
        with self.assertRaisesRegex(RuntimeError,'response/run'): self.run_gate()
        self.assertEqual([r[0] for r in self.b.requests],[7,8])
        self.assertEqual(self.a.requests[-1],(7,3,0,0xfff))

    def test_lane9_errors_fail_with_safe_stops(self):
        self.data[9]['errors']=1
        with self.assertRaisesRegex(RuntimeError,'lane9'): self.run_gate()
        self.assertEqual(self.b.requests[-1],(9,3,0,0xfff))

    def test_lane9_unselected_refused(self):
        self.data[9]['id_status']=9
        with self.assertRaisesRegex(RuntimeError,'lane9'): self.run_gate()


if __name__ == '__main__': unittest.main()
