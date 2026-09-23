"""Lean source/firmware contract for unbuilt all-links v1."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class AllLinksV1Source(unittest.TestCase):
    def test_identity_and_exact_full_mask(self):
        fw = (ROOT / 'scripts/build_all_links_v1_firmware.sh').read_text()
        self.assertIn('GTTE_FIRMWARE_VERSION=0x00020500u', fw)
        words = [int(x, 16) for x in re.findall(
            r'GTTE_MANAGED_MASK[0-3]=0x([0-9a-f]+)u', fw)]
        self.assertEqual(words, [0xffffffff, 0xffffffff, 0xffffffff, 0xffff])
        mask = sum(word << (32 * i) for i, word in enumerate(words))
        self.assertEqual(mask, (1 << 112) - 1)
        self.assertEqual(mask & ~((1 << 112) - 1), 0)
        self.assertNotEqual(0x00010000 & ~words[3], 0)  # lane 112 rejected

    def test_global_lane_map_and_no_forbidden_protocol(self):
        core = (ROOT / 'src/gt_test_direct_quad_v6_core.sv').read_text()
        top = (ROOT / 'src/gt_test_all_links_v1_top.sv').read_text()
        self.assertIn('112\'hffffffffffffffffffffffffffff', core)
        self.assertIn('p_ff4_recv, p_ff6_recv, reverse12(p_ff3_recv)', core)
        self.assertIn('p_ff2_recv, p_ff5_recv, p_ff1_recv', core)
        self.assertIn('.ALL_LINKS_V1(1\'b1)', top)
        self.assertNotIn('u_ibert_', top)
        self.assertNotIn('axi_c2c', top.lower())

    def test_28_quads_12_refclks_and_ack_barrier(self):
        core = (ROOT / 'src/gt_test_direct_quad_v6_core.sv').read_text()
        aggregate = (ROOT / 'src/all_links_v1_quad_aggregate.sv').read_text()
        bank = (ROOT / 'src/all_links_v1_slr_bank.sv').read_text()
        buffers = (ROOT / 'src/direct_quad_v6_refclk_buffers.sv').read_text()
        for inst in ('g_bank_slr0, 0, 0, 3', 'g_bank_slr1, 1, 3, 4',
                     'g_bank_slr2, 2, 7, 4', 'g_bank_slr3, 3, 11, 3'):
            self.assertIn(inst, core)
        self.assertIn('begin : g_left_quad', bank)
        self.assertIn('begin : g_right_quad', bank)
        self.assertEqual(buffers.count('IBUFDS_GTE4'), 2)  # two in a six-way generate
        self.assertIn('.QUADS(QUADS)', bank)
        self.assertIn('local_resetn <= resetn', bank)
        self.assertIn('tx_session_applied <= &group_session_applied', aggregate)

    def test_v2_participation_is_epoch_aligned_and_narrowly_neutralized(self):
        engine = (ROOT / 'src/gt_test_engine_core.sv').read_text()
        core = (ROOT / 'src/gt_test_direct_quad_v6_core.sv').read_text()
        bank = (ROOT / 'src/all_links_v1_slr_bank.sv').read_text()
        self.assertIn('assign accepted_lane_mask = active_lane_mask', engine)
        self.assertIn('accepted_quad_selected[accepted_q] =', core)
        self.assertIn('|accepted_lane_mask[accepted_q*4 +: 4]', core)
        self.assertIn('left_quad_selected <= left_quad_selected_in', bank)
        self.assertIn('right_quad_selected <= right_quad_selected_in', bank)
        self.assertIn('left_acquisition_ready | ~left_quad_selected', bank)
        self.assertIn('right_capture_done | ~right_quad_selected', bank)
        self.assertNotIn('quad_idle | ~', bank)
        self.assertNotIn('quad_fault | ~', bank)
        self.assertNotIn('quad_session_applied | ~', bank)

    def test_left_ip_recipe_has_exact_quads_and_properties(self):
        recipe = (ROOT / 'scripts/create_all_links_v1_left_ip.tcl').read_text()
        quads = re.search(r'foreach quad \{([^}]+)\}', recipe).group(1).split()
        self.assertEqual(quads, [str(q) for q in range(121, 135)])
        for prop in ('25.78125', '322.265625', 'QPLL0', 'INS_LOSS_NYQ {3}'):
            self.assertIn(prop, recipe)

    def test_failed_keep_hierarchy_experiment_is_inactive_and_never_dont_touch(self):
        xdc = (ROOT / 'constraints/all_links_v1_keep_hierarchy.xdc').read_text()
        self.assertIn('REF_NAME =~ gt_prbs_test_controller*', xdc)
        self.assertIn('set_property KEEP_HIERARCHY yes', xdc)
        self.assertNotIn('DONT_TOUCH', xdc)
        create = (ROOT / 'scripts/create_all_links_v1_project.tcl').read_text()
        update = (ROOT / 'scripts/update_all_links_v1_project_sources.tcl').read_text()
        self.assertNotIn('all_links_v1_keep_hierarchy.xdc', create)
        self.assertIn('remove_files -fileset constrs_1', update)
        self.assertNotIn('USED_IN_SYNTHESIS true', update)
        historical = list((ROOT / 'scripts').glob('create_*project.tcl'))
        historical += list((ROOT / 'scripts').glob('update_*project_sources.tcl'))
        for path in historical:
            if path.name == 'update_all_links_v1_project_sources.tcl':
                continue
            self.assertNotIn('all_links_v1_keep_hierarchy.xdc', path.read_text(),
                             str(path))


if __name__ == '__main__':
    unittest.main()
