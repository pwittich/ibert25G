import contextlib
import io
import unittest

import direct_quad_v6_remote as gate


class FakeEndpoint:
    def __init__(self, site):
        self.site = site
        self.requests = []
        self.health = []
        self.record_runs = []
        self.stopped = False
        self.fail_response = None

    def healthy(self, *args, **kwargs):
        self.health.append((args, kwargs))

    def evidence(self, label):
        pass

    def submit(self, *args):
        self.requests.append(args)

    def response(self, sequence, *args, **kwargs):
        if sequence == self.fail_response:
            raise RuntimeError('injected response failure')

    def records(self, run):
        self.record_runs.append(run)
        return {'site': self.site, 'run': run}

    def stop_if_safe(self):
        self.stopped = True


class Tests(unittest.TestCase):
    def test_profiles_are_exact_global_masks(self):
        self.assertEqual(gate.PROFILES['F1']['lanes'], (60, 61, 62, 63))
        self.assertEqual(gate.PROFILES['F1']['mask'], (0, 0xf0000000, 0, 0))
        self.assertEqual(gate.PROFILES['F2']['lanes'], (104, 105, 106, 107))
        self.assertEqual(gate.PROFILES['F2']['mask'], (0, 0, 0, 0xf00))

    def test_pma_protocol(self):
        endpoints = [FakeEndpoint('F1'), FakeEndpoint('F2')]
        with contextlib.redirect_stdout(io.StringIO()):
            gate.run_pma(endpoints, sleep=lambda _: None)
        for endpoint in endpoints:
            self.assertEqual(endpoint.requests, [(1, 0, 0x11501, 10000)])
            self.assertEqual(endpoint.record_runs, [1])

    def test_f2_repair_preserves_f1_and_writes_only_f2(self):
        endpoints = [FakeEndpoint('F1'), FakeEndpoint('F2')]
        with contextlib.redirect_stdout(io.StringIO()):
            gate.run_pma_f2_repair(endpoints, sleep=lambda _: None)
        self.assertEqual(endpoints[0].requests, [])
        self.assertEqual(endpoints[0].record_runs, [1])
        self.assertEqual(endpoints[1].requests, [(1, 0, 0x11501, 10000)])
        self.assertEqual(endpoints[1].record_runs, [1])

    def test_external_two_overlapping_runs_and_stop(self):
        endpoints = [FakeEndpoint('F1'), FakeEndpoint('F2')]
        overlaps = []
        with contextlib.redirect_stdout(io.StringIO()):
            gate.run_external(endpoints, sleep=lambda _: None,
                              overlap=lambda items: overlaps.append(tuple(x.site for x in items)))
        self.assertEqual(overlaps, [('F1', 'F2'), ('F1', 'F2')])
        for endpoint in endpoints:
            self.assertEqual(endpoint.requests, [(2, 1, 2, 180000),
                                                 (3, 2, 0x10501, 10000),
                                                 (4, 3, 0x10501, 10000)])
            self.assertEqual(endpoint.record_runs, [2, 3, 3])
            self.assertTrue(endpoint.stopped)

    def test_external_failure_stops_both_without_retry(self):
        endpoints = [FakeEndpoint('F1'), FakeEndpoint('F2')]
        endpoints[1].fail_response = 3
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, 'injected'):
                gate.run_external(endpoints, sleep=lambda _: None, overlap=lambda _: None)
        self.assertTrue(all(endpoint.stopped for endpoint in endpoints))
        self.assertEqual(len(endpoints[1].requests), 2)


if __name__ == '__main__':
    unittest.main()
