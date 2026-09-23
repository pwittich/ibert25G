"""Offline regressions for exact v7 BD ELF association retargeting."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class V7ProjectUtils(unittest.TestCase):
    def test_retarget_is_path_only_and_format_independent(self):
        source = (ROOT / 'scripts/direct_quad_v6_project_utils.tcl').read_text()
        proc = source.split('proc direct_v7_retarget_inherited_elf', 1)[1]
        self.assertIn('string map [list $old $new]', proc)
        self.assertIn('regexp -all {"type": "ELF"}', proc)
        old = 'firmware_firefly1_loopback_v5/gt_test_firefly1_loopback_v5.elf'
        new = 'firmware_direct_all_v7/gt_test_direct_all_v7.elf'
        samples = [
            '      "file": {\n        "name": "../../../../../%s",\n        "type": "ELF"\n      },' % old,
            '    "elf_association": {\n      "file": {\n        "name": "../../../../../%s",\n        "type": "ELF"\n      }\n    }' % old,
        ]
        for sample in samples:
            changed = sample.replace(old, new)
            self.assertEqual(changed.count(new), 1)
            self.assertEqual(changed.count('"type": "ELF"'), 1)
            self.assertNotIn(old, changed)

    def test_retry_directory_is_new(self):
        source = (ROOT / 'scripts/create_direct_all_v7_project.tcl').read_text()
        self.assertIn('set project_name_override gt_test_direct_all_v7r3', source)
        self.assertIn('set project_dir [file join $repo_dir build $project_name_override]', source)
        self.assertIn('save_project_as -include_local_ip_cache $project_name_override $project_dir', source)
        self.assertIn('get_property IS_GENERATED $f', source)
        self.assertIn('remove_files $inherited', source)
        self.assertIn('direct_v7_assert_single_bd_elf $bd', source)


if __name__ == '__main__':
    unittest.main()
