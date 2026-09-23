"""Check the symmetric v7 firmware identity and all-direct managed mask."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class DirectAllV7Firmware(unittest.TestCase):
    def test_fixed_profile(self):
        text = (ROOT / 'scripts/build_direct_all_v7_firmware.sh').read_text()
        self.assertIn('-DGTTE_FIRMWARE_VERSION=0x00020407u', text)
        self.assertIn('-DGTTE_MANAGED_MASK0=0u', text)
        self.assertIn('-DGTTE_MANAGED_MASK1=0xff000000u', text)
        self.assertIn('-DGTTE_MANAGED_MASK2=0xffffffffu', text)
        self.assertIn('-DGTTE_MANAGED_MASK3=0x0000ffffu', text)
        self.assertNotIn('site in', text)

    def test_mask_is_exactly_global_lanes_56_through_111(self):
        words = (0, 0xff000000, 0xffffffff, 0x0000ffff)
        mask = sum(word << (32 * index) for index, word in enumerate(words))
        self.assertEqual(mask, ((1 << 56) - 1) << 56)
        self.assertEqual(bin(mask).count('1'), 56)

    def test_session_branch_uses_profile_macros(self):
        source = (ROOT / 'firmware/gt_test_milestone2.c').read_text()
        branch = source.split('#ifdef GTTE_ENABLE_TX_SESSION\n', 1)[1].split('#endif', 1)[0]
        for index in range(4):
            self.assertIn('mask{} == GTTE_MANAGED_MASK{}'.format(index, index), branch)


if __name__ == '__main__':
    unittest.main()
