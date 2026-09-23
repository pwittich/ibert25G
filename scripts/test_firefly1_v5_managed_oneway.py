import contextlib
import io
import unittest
from unittest.mock import Mock
import firefly1_v5_managed_oneway_remote as gate


class Endpoint:
    def __init__(self, site):
        self.site = site
        self.requests = []
        self.stopped = False
        self.fail_receive = False
        self.fail_stop = False

    def healthy(self, *args, **kwargs):
        pass

    def evidence(self, label):
        pass

    def submit(self, *args):
        self.requests.append(args)

    def response(self, sequence, *args):
        if self.fail_receive and sequence == 2:
            raise RuntimeError('receive failed')

    def records(self):
        return {'stable': True}

    def stop_if_safe(self):
        self.stopped = True
        if self.fail_stop:
            raise RuntimeError('stop failed')


class Tests(unittest.TestCase):
    def setUp(self):
        self.source, self.rx = Endpoint('F1'), Endpoint('F2')
        self.off = [40.] * 12
        self.on = [1200.] * 12
        self.on[2] = 61.2

    def run_gate(self):
        with contextlib.redirect_stdout(io.StringIO()):
            gate.run(self.source, self.rx, Mock(side_effect=[self.off, self.on, self.off]), sleep=lambda _: None)

    def test_success_exact_protocol(self):
        self.run_gate()
        self.assertEqual(self.source.requests, [(1, 0, 2, 180000, 0xfff)])
        self.assertEqual(self.rx.requests, [(1, 0, 2, 180000, 0xfff), (2, 1, 0x10501, 10000, 0xdff)])
        self.assertTrue(self.source.stopped and self.rx.stopped)

    def test_low_power_no_receive_both_stopped(self):
        self.on[0] = 40
        with self.assertRaisesRegex(RuntimeError, 'RSSI'):
            self.run_gate()
        self.assertEqual(len(self.rx.requests), 1)
        self.assertTrue(self.source.stopped and self.rx.stopped)

    def test_no_increase_no_receive(self):
        self.off[0] = self.on[0]
        with self.assertRaisesRegex(RuntimeError, 'RSSI'):
            self.run_gate()
        self.assertEqual(len(self.rx.requests), 1)

    def test_receive_failure_no_retry_both_stopped(self):
        self.rx.fail_receive = True
        with self.assertRaisesRegex(RuntimeError, 'receive failed'):
            self.run_gate()
        self.assertEqual(len(self.rx.requests), 2)
        self.assertTrue(self.source.stopped and self.rx.stopped)

    def test_first_stop_failure_still_stops_source(self):
        self.rx.fail_stop = True
        with self.assertRaisesRegex(RuntimeError, 'safe stop'):
            self.run_gate()
        self.assertTrue(self.source.stopped)

    def test_rssi_descending_big_endian(self):
        device = Mock()
        device.read_block.return_value = b''.join((c*10).to_bytes(2, 'big') for c in range(11, -1, -1))
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(gate.rssi(device), list(range(12)))
        device.read_block.assert_called_once_with(0x01ce, 24)


if __name__ == '__main__':
    unittest.main()
