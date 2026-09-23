"""Offline tests; no cm_interface import, network or hardware."""
import contextlib
import io
import tempfile
import unittest
from unittest.mock import patch
import firefly1_v5_oneway_remote as gate


class FakeBox:
    def __init__(self):
        self.reg = {0xc0: 0x20304, 0xc4: 0x20304, 0xc8: gate.CAP,
                    0xa0: 0, 0xf0: 0, 0xf8: 0, 0x9c: 0x434da501,
                    0x24: 100000, 0x28: 325000, 0x5c: 322266,
                    0xd0: 0x40, 0xd4: 0x40000000, 0xec: 0}
        self.requests = []
        self.refuse_session = self.fail_rx = self.timeout_rx = self.drop_doorbell = False
        self.bad_readback = False

    def read_u32(self, address):
        if self.bad_readback and address == 0xb0:
            return 0
        return self.reg.get(address, 0)

    def write_u8(self, address, value):
        assert address == 0xcc

    def write_u32(self, address, value):
        self.reg[address] = value
        if address != 0xa0:
            return
        command = self.reg[0xa4]
        self.requests.append((value, command, self.reg[0xa8], self.reg[0xb0]))
        if self.drop_doorbell:
            raise IOError('ambiguous transport failure')
        if command == 2:
            self.reg[0xc8] = gate.CAP if self.refuse_session else gate.CAP | gate.ACTIVE
            self.reg[0xf4] = int(self.refuse_session)
        elif command == 3:
            self.reg[0xc8], self.reg[0xf4] = gate.CAP, 0
        else:
            if self.timeout_rx:
                self.reg[0xc8] = gate.CAP | gate.ACTIVE | 2
                return
            self.reg[0xf8] = 1
            self.reg[0xfc] = self.reg[0xf4] = 0x0b000b04 if self.fail_rx else gate.SUMMARY
            if self.fail_rx:
                self.reg[0xc8] = gate.CAP | (1 << 18) | (1 << 16)
        self.reg[0xf0] = value


class GateTests(unittest.TestCase):
    def setUp(self):
        self.box = FakeBox()
        self.now = 0
        self.diag = gate.Diagnostic(self.box, self.sleep, lambda: self.now)
        self.events = []
        self.diag.evidence = self.events.append
        self.records = {i: dict(id_status=0x1800+i, errors=0, lock_losses=0,
                               tested_bits=gate.EXPECTED_CYCLES * 80,
                               valid_cycles=gate.EXPECTED_CYCLES) for i in range(12)}
        self.records[9].update(id_status=9, tested_bits=0, valid_cycles=0)
        self.reader = patch.object(gate, 'read_lane', side_effect=lambda b, lane: self.records[lane])
        self.reader.start()
        self.addCleanup(self.reader.stop)

    def sleep(self, seconds):
        self.now += seconds

    def run_gate(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.diag.start()

    def test_fixed_protocol(self):
        self.run_gate()
        self.assertEqual(self.box.requests, [(1, 2, 180000, 0xfff),
                                             (2, 0x10501, 10000, 0xdff), (3, 3, 0, 0xfff)])
        self.assertEqual(self.box.reg[0xf8], 1)
        self.assertEqual(self.box.reg[0xc8], gate.CAP)
        self.assertIn('before-session-stop', self.events)

    def test_bad_identity_no_request(self):
        self.box.reg[0xc4] = 0
        with self.assertRaisesRegex(RuntimeError, 'identity'):
            self.run_gate()
        self.assertEqual(self.box.requests, [])

    def test_nonfresh_no_request(self):
        self.box.reg[0xa0] = 1
        with self.assertRaisesRegex(RuntimeError, 'sequence/run'):
            self.run_gate()
        self.assertEqual(self.box.requests, [])

    def test_clock_guard_no_request(self):
        for address, value in ((0x9c, 0), (0x24, 90000), (0x28, 300000), (0x5c, 0)):
            original = self.box.reg[address]
            self.box.reg[address] = value
            with self.assertRaisesRegex(RuntimeError, 'clock'):
                self.run_gate()
            self.assertEqual(self.box.requests, [])
            self.box.reg[address] = original

    def test_platform_guard_no_request(self):
        for address, value in ((0xd0, 0), (0xec, 1), (0xd4, 0x80000000)):
            original = self.box.reg[address]
            self.box.reg[address] = value
            with self.assertRaises(RuntimeError):
                self.run_gate()
            self.assertEqual(self.box.requests, [])
            self.box.reg[address] = original

    def test_refused_session_no_rx(self):
        self.box.refuse_session = True
        with self.assertRaisesRegex(RuntimeError, 'response/run'):
            self.run_gate()
        self.assertEqual(len(self.box.requests), 1)

    def test_failed_rx_no_blind_cleanup(self):
        self.box.fail_rx = True
        with self.assertRaisesRegex(RuntimeError, 'response/run'):
            self.run_gate()
        self.assertEqual([r[0] for r in self.box.requests], [1, 2])
        self.assertIn('final', self.events)

    def test_timeout_no_retry_no_busy_stop(self):
        self.box.timeout_rx = True
        with self.assertRaisesRegex(RuntimeError, 'timeout'):
            self.run_gate()
        self.assertEqual([r[0] for r in self.box.requests], [1, 2])
        self.assertLess(self.now, 41)

    def test_ambiguous_doorbell_no_retry(self):
        self.box.drop_doorbell = True
        with self.assertRaises(IOError):
            self.run_gate()
        self.assertEqual(len(self.box.requests), 1)

    def test_descriptor_readback_no_doorbell(self):
        self.box.bad_readback = True
        with self.assertRaisesRegex(RuntimeError, 'readback'):
            self.run_gate()
        self.assertEqual(self.box.requests, [])

    def test_excluded_lane_cannot_be_selected(self):
        self.records[9]['id_status'] = 0x1809
        with self.assertRaisesRegex(RuntimeError, 'excluded'):
            self.run_gate()
        self.assertEqual(self.box.requests[-1], (3, 3, 0, 0xfff))

    def test_excluded_lane_can_sample_lock(self):
        self.records[9]['id_status'] = 0x1009
        self.run_gate()

    def test_selected_lane_errors_fail_and_stop(self):
        self.records[0]['errors'] = 1
        with self.assertRaisesRegex(RuntimeError, 'errors/losses'):
            self.run_gate()
        self.assertEqual(self.box.requests[-1][0], 3)

    def test_bad_denominator_fails_before_stop(self):
        self.records[0]['tested_bits'] += 80
        with self.assertRaisesRegex(RuntimeError, 'denominator'):
            self.run_gate()
        self.assertEqual(self.box.requests[-1][0], 3)

    def test_short_measurement_fails(self):
        self.records[0].update(tested_bits=8000, valid_cycles=100)
        with self.assertRaisesRegex(RuntimeError, 'duration'):
            self.run_gate()

    def test_post_stop_corruption_detected_even_if_individually_valid(self):
        stop = self.diag.stop_if_safe

        def corrupt():
            stop()
            self.records[0]['valid_cycles'] += 1
            self.records[0]['tested_bits'] += 80
        self.diag.stop_if_safe = corrupt
        with self.assertRaisesRegex(RuntimeError, 'records changed'):
            self.run_gate()
        self.assertEqual(self.box.reg[0xc8], gate.CAP)

    def test_stop_skips_unused_rx_sequence_after_session_setup_failure(self):
        healthy = self.diag.healthy

        def fail_after_lease(sequence, run, active=False):
            if sequence == 1:
                raise RuntimeError('injected post-session failure')
            healthy(sequence, run, active)
        self.diag.healthy = fail_after_lease
        with self.assertRaisesRegex(RuntimeError, 'injected'):
            self.run_gate()
        self.assertEqual([r[0] for r in self.box.requests], [1, 3])
        self.assertEqual(self.box.reg[0xf8], 0)

    def test_sentinel_cannot_replay(self):
        with tempfile.TemporaryDirectory() as directory:
            gate.claim_start(directory)
            with self.assertRaises(FileExistsError):
                gate.claim_start(directory)

    def test_launch_hold_before_network(self):
        import board_firefly1_v5_oneway as launcher
        with patch('sys.argv', ['launcher', 'deploy']), patch.object(launcher.subprocess, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'HOLD'):
                launcher.main()
            run.assert_not_called()

    def test_main_constructs_only_f2_after_release(self):
        # The release remains false in source. Test the public hold before any
        # Registry construction, then check fixed target spelling statically.
        with patch('sys.argv', ['remote', 'start']):
            with self.assertRaisesRegex(RuntimeError, 'HOLD'):
                gate.main()
        import inspect
        source = inspect.getsource(gate.main)
        self.assertIn("registry.fpgas['F2']", source)
        self.assertNotIn("registry.fpgas['F1']", source)


if __name__ == '__main__':
    unittest.main()
