import contextlib
import io
import unittest
from unittest.mock import Mock, patch
from test_firefly1_v5_oneway import FakeBox
from firefly1_v5_oneway_remote import Diagnostic
import firefly1_v5_managed_receive_remote as gate


class Tests(unittest.TestCase):
    def setUp(self):
        self.a, self.b = FakeBox(), FakeBox()
        for box in (self.a, self.b):
            box.reg[0xa0] = box.reg[0xf0] = 3
        self.now = 0
        self.source = Diagnostic(self.a, self.sleep, lambda: self.now, site='F1')
        self.rx = Diagnostic(self.b, self.sleep, lambda: self.now, site='F2')
        for endpoint in (self.source, self.rx):
            endpoint.evidence = Mock()
        self.rx.records = Mock(return_value={'stable': True})

    def sleep(self, delay):
        self.now += delay

    def run_gate(self):
        with contextlib.redirect_stdout(io.StringIO()), patch.object(gate, 'compact'):
            gate.run(self.source, self.rx, Mock(return_value=[0]*12), self.sleep, lambda: self.now)

    def test_zero_rssi_does_not_gate_exact_receive_protocol(self):
        self.run_gate()
        self.assertEqual(self.a.requests, [(4, 2, 180000, 0xfff), (5, 3, 0, 0xfff)])
        self.assertEqual(self.b.requests, [(4, 2, 180000, 0xfff), (5, 0x10501, 10000, 0xdff), (6, 3, 0, 0xfff)])
        self.assertEqual((self.a.reg[0xf8], self.b.reg[0xf8]), (0, 1))

    def test_wrong_predecessor_no_writes(self):
        self.b.reg[0xa0] = 0
        with self.assertRaisesRegex(RuntimeError, 'sequence/run'):
            self.run_gate()
        self.assertEqual(self.a.requests + self.b.requests, [])

    def test_receive_failure_stops_source_preserves_receiver_fault(self):
        self.b.fail_rx = True
        with self.assertRaisesRegex(RuntimeError, 'response/run'):
            self.run_gate()
        self.assertEqual([r[0] for r in self.b.requests], [4, 5])
        self.assertEqual(self.a.requests[-1], (5, 3, 0, 0xfff))

    def test_receive_timeout_no_replay(self):
        self.b.timeout_rx = True
        with self.assertRaisesRegex(RuntimeError, 'timeout'):
            self.run_gate()
        self.assertEqual([r[0] for r in self.b.requests], [4, 5])
        self.assertEqual(self.a.reg[0xc8], gate.CAP)

    def test_pre_receive_safe_stop_skips_to_six(self):
        self.b.reg.update({0xa0:4, 0xf0:4, 0xc8:gate.CAP|gate.ACTIVE})
        with contextlib.redirect_stdout(io.StringIO()):
            gate.safe_stop(self.rx)
        self.assertEqual(self.b.requests, [(6, 3, 0, 0xfff)])

    def test_ambiguous_state_refuses_stop(self):
        self.b.reg.update({0xa0:5, 0xf0:4, 0xc8:gate.CAP|gate.ACTIVE})
        with contextlib.redirect_stdout(io.StringIO()):
            gate.safe_stop(self.rx)
        self.assertEqual(self.b.requests, [])


if __name__ == '__main__':
    unittest.main()
