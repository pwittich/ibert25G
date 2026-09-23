import contextlib
import copy
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import all_direct_v7_contract as contract
import all_direct_v7_remote as gate
import board_all_direct_v7 as board


F1_EXTERNAL = tuple(lane for lane in range(56, 112)
                    if lane not in (70, 71))
F2_EXTERNAL = tuple(lane for lane in range(56, 112)
                    if lane not in (96, 97))


def mask_for(lanes):
    words = [0, 0, 0, 0]
    for lane in lanes:
        words[lane // 32] |= 1 << (lane % 32)
    return tuple(words)


class FakeEndpoint:
    def __init__(self, site, external_lanes):
        self.site = site
        self.profile = {'external_lanes': external_lanes,
                        'external_mask': mask_for(external_lanes)}
        self.requests = []
        self.health = []
        self.record_calls = []
        self.stopped = False
        self.stop_calls = []
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

    def records(self, run, lanes, summary):
        self.record_calls.append((run, tuple(lanes), summary))
        return {'site': self.site, 'run': run}

    def stop_if_safe(self, *args, **kwargs):
        self.stopped = True
        self.stop_calls.append((args, kwargs))
        return 5 if self.site == 'F1' else 4


class FakeMailbox:
    def __init__(self, values):
        self.values = dict(values)

    def read_u32(self, address):
        return self.values[address]

    def write_u8(self, address, value):
        self.values[address] = value


class Tests(unittest.TestCase):
    def endpoints(self):
        return [FakeEndpoint('F1', F1_EXTERNAL),
                FakeEndpoint('F2', F2_EXTERNAL)]

    def released_contract(self, root):
        profiles = copy.deepcopy(contract.ENDPOINTS)
        for site, lanes in (('F1', F1_EXTERNAL), ('F2', F2_EXTERNAL)):
            bit = root / (site + '.bit')
            dcp = root / (site + '.dcp')
            elf = root / (site + '.elf')
            bit.write_bytes((site + '-bit').encode())
            dcp.write_bytes((site + '-dcp').encode())
            elf.write_bytes((site + '-elf').encode())
            profiles[site].update({
                'version': 0x20500 if site == 'F1' else 0x20501,
                'program_choice': 'all_direct_v7_' + site.lower(),
                'bit_path': bit.name,
                'bit_sha256': board.file_sha256(bit),
                'dcp_path': dcp.name,
                'dcp_sha256': board.file_sha256(dcp),
                'elf_path': elf.name,
                'elf_sha256': board.file_sha256(elf),
                'external_lanes': lanes,
                'external_mask': mask_for(lanes),
            })
        return profiles

    def test_managed_and_directional_receive_masks(self):
        self.assertEqual(contract.ALL_DIRECT_LANES, tuple(range(56, 112)))
        self.assertEqual(contract.ALL_DIRECT_MASK,
                         (0, 0xff000000, 0xffffffff, 0xffff))
        self.assertEqual(contract.ENDPOINTS['F1']['external_lanes'],
                         F1_EXTERNAL)
        self.assertEqual(contract.ENDPOINTS['F1']['external_mask'],
                         (0, 0xff000000, 0xffffff3f, 0xffff))
        self.assertEqual(contract.ENDPOINTS['F2']['external_lanes'],
                         F2_EXTERNAL)
        self.assertEqual(contract.ENDPOINTS['F2']['external_mask'],
                         (0, 0xff000000, 0xffffffff, 0xfffc))
        self.assertEqual(len(F1_EXTERNAL), 54)
        self.assertEqual(len(F2_EXTERNAL), 54)
        self.assertNotIn(70, F1_EXTERNAL)
        self.assertNotIn(71, F1_EXTERNAL)
        self.assertNotIn(96, F2_EXTERNAL)
        self.assertNotIn(97, F2_EXTERNAL)

    def test_exact_six_direct_refclk_monitors(self):
        self.assertEqual(contract.DIRECT_REFCLK_ADDRESSES,
                         (0x2c, 0x30, 0x38, 0x3c, 0x40, 0x44))
        self.assertNotIn(0x34, contract.DIRECT_REFCLK_ADDRESSES)

    def test_active_health_requires_applied_ready_status(self):
        values = {
            0xc8: gate.CAPABILITY | gate.SESSION_ACTIVE | gate.SESSION_READY,
            0xa0: 2, 0xf0: 2, 0xf8: 1, 0x9c: 0x434da501,
            0x24: 100000, 0x28: 325000, 0xd0: 0x40, 0xec: 0,
            0xd4: 0x40000000,
        }
        values.update((address, 322266)
                      for address in contract.DIRECT_REFCLK_ADDRESSES)
        endpoint = gate.Endpoint(FakeMailbox(values), 'F1')
        endpoint.identity = lambda: None
        endpoint.healthy(2, 1, active=True)
        endpoint.box.values[0xc8] = gate.CAPABILITY | gate.SESSION_ACTIVE
        with self.assertRaisesRegex(RuntimeError, 'state/session mismatch'):
            endpoint.healthy(2, 1, active=True)

    def test_placeholder_contract_fails_closed(self):
        with patch.object(contract, 'RELEASED', False):
            with self.assertRaisesRegex(RuntimeError, 'not enabled'):
                contract.validate_contract()

    def test_final_release_contract_and_real_artifacts(self):
        self.assertTrue(contract.RELEASED)
        self.assertEqual(contract.ENDPOINTS['F1']['version'], 0x00020409)
        self.assertEqual(contract.ENDPOINTS['F2']['version'], 0x00020409)
        self.assertEqual(contract.ENDPOINTS['F1']['program_choice'],
                         'direct_all_v12_f1')
        self.assertEqual(contract.ENDPOINTS['F2']['program_choice'],
                         'direct_all_v12_f2')
        archive = ('build/diagnostic_archive/'
                   'direct-all-v12-0x00020409-scoped-pass/artifacts/')
        for site in ('F1', 'F2'):
            self.assertTrue(contract.ENDPOINTS[site]['bit_path'].startswith(archive))
            self.assertTrue(contract.ENDPOINTS[site]['dcp_path'].startswith(archive))
            self.assertTrue(contract.ENDPOINTS[site]['elf_path'].startswith(archive))
        board.verify_release(board.ROOT)
        programmer = (board.ROOT / 'scripts' / 'board_program.tcl').read_text()
        self.assertIn('direct_all_v12_f1 -', programmer)
        self.assertIn('direct_all_v12_f2 {', programmer)
        self.assertIn(contract.ENDPOINTS['F1']['bit_sha256'], programmer)
        self.assertIn(contract.ENDPOINTS['F1']['elf_sha256'], programmer)
        self.assertIn(archive + 'gt_test_direct_all_v7r3.bit', programmer)
        self.assertIn(archive +
                      'firmware_direct_all_v7/gt_test_direct_all_v7.elf',
                      programmer)
        self.assertIn('direct_all_v12_f2}}', programmer)

    def test_release_verifies_both_endpoint_artifacts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            profiles = self.released_contract(root)
            with patch.object(contract, 'RELEASED', True), \
                    patch.object(contract, 'ENDPOINTS', profiles), \
                    patch.object(board, 'ENDPOINTS', profiles):
                board.verify_release(root)
                (root / 'F2.bit').write_bytes(b'changed')
                with self.assertRaisesRegex(RuntimeError,
                                             'F2 bit artifact hash mismatch'):
                    board.verify_release(root)

    def test_pma_is_ordered_and_uses_all_56(self):
        endpoints = self.endpoints()
        with contextlib.redirect_stdout(io.StringIO()):
            gate.run_pma_f1(endpoints)
        self.assertEqual(endpoints[0].requests,
                         [(1, 0, 0x11501, 10000,
                           contract.ALL_DIRECT_MASK)])
        self.assertEqual(endpoints[1].requests, [])
        endpoints = self.endpoints()
        with contextlib.redirect_stdout(io.StringIO()):
            gate.run_pma_f2(endpoints)
        self.assertEqual(endpoints[0].requests, [])
        self.assertEqual(endpoints[1].requests,
                         [(1, 0, 0x11501, 10000,
                           contract.ALL_DIRECT_MASK)])

    def test_external_uses_all_56_tx_and_site_specific_54_rx(self):
        endpoints = self.endpoints()
        overlaps = []
        with contextlib.redirect_stdout(io.StringIO()):
            gate.run_external(
                endpoints,
                overlap=lambda items: overlaps.append(
                    tuple(endpoint.site for endpoint in items)))
        self.assertEqual(overlaps, [('F1', 'F2')])
        for endpoint in endpoints:
            self.assertEqual(endpoint.requests[0],
                             (2, 1, 2, 180000,
                              contract.ALL_DIRECT_MASK))
            self.assertEqual(endpoint.requests[1],
                             (3, 2, 0x10501, 10000,
                              endpoint.profile['external_mask']))
            self.assertEqual(endpoint.record_calls[0][1],
                             tuple(endpoint.profile['external_lanes']))
            self.assertEqual(endpoint.record_calls[0][2],
                             gate.EXTERNAL_SUMMARY)
            self.assertTrue(endpoint.stopped)

    def test_external_failure_stops_both_without_retry(self):
        endpoints = self.endpoints()
        endpoints[1].fail_response = 3
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, 'injected'):
                gate.run_external(endpoints, overlap=lambda _: None)
        self.assertTrue(all(endpoint.stopped for endpoint in endpoints))
        self.assertEqual(len(endpoints[1].requests), 2)

    def test_external_resume_uses_asymmetric_preserved_sequences(self):
        endpoints = self.endpoints()
        overlaps = []
        with contextlib.redirect_stdout(io.StringIO()):
            gate.run_external_resume(
                endpoints,
                overlap=lambda items: overlaps.append(
                    tuple(endpoint.site for endpoint in items)))
        self.assertEqual(overlaps, [('F1', 'F2')])
        self.assertEqual(endpoints[0].requests,
                         [(3, 2, 2, 180000, contract.ALL_DIRECT_MASK),
                          (4, 3, 0x10501, 10000,
                           endpoints[0].profile['external_mask'])])
        self.assertEqual(endpoints[1].requests,
                         [(2, 1, 2, 180000, contract.ALL_DIRECT_MASK),
                          (3, 2, 0x10501, 10000,
                           endpoints[1].profile['external_mask'])])
        self.assertEqual(endpoints[0].health[0],
                         ((2, 1), {'state_extra': gate.SESSION_EXPIRED}))
        self.assertEqual(endpoints[1].health[0], ((1, 1), {}))
        self.assertTrue(all(endpoint.stopped for endpoint in endpoints))
        self.assertEqual(endpoints[0].health[-1], ((5, 2), {}))
        self.assertEqual(endpoints[1].health[-1], ((4, 2), {}))

    def test_remote_directory_is_new_and_non_v6(self):
        self.assertEqual(contract.REMOTE_DIRECTORY,
                         '/tmp/all-direct-v12-20260918')
        self.assertNotIn('direct-quad-v6', contract.REMOTE_DIRECTORY)


if __name__ == '__main__':
    unittest.main()
