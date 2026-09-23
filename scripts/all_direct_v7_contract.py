#!/usr/bin/env python3
"""Release pins for the all-direct cleanup-repair validation launchers.

The symmetric build and independent routed audit are complete.  This contract
pins the exact BIT, routed DCP and ELF used for both explicit endpoint
programming choices.
"""

RELEASED = True
# V12 starts from freshly programmed endpoints. Keep it in a new namespace;
# all v11 sentinels and evidence are consumed and must never be reused.
REMOTE_DIRECTORY = '/tmp/all-direct-v12-20260918'

ALL_DIRECT_LANES = tuple(range(56, 112))
ALL_DIRECT_MASK = (0x00000000, 0xff000000, 0xffffffff, 0x0000ffff)
# q221-q234 use exactly the N, P, B, E, G and I REFCLK0 inputs.  r13/0x34 is
# rt_r0_l and is not a direct-link reference clock.
DIRECT_REFCLK_ADDRESSES = (0x2c, 0x30, 0x38, 0x3c, 0x40, 0x44)
EXTERNAL_FITTED_COUNT = 54
EXTERNAL_LANES = {
    'F1': tuple(lane for lane in ALL_DIRECT_LANES if lane not in (70, 71)),
    'F2': tuple(lane for lane in ALL_DIRECT_LANES if lane not in (96, 97)),
}
EXTERNAL_MASKS = {
    'F1': (0x00000000, 0xff000000, 0xffffff3f, 0x0000ffff),
    'F2': (0x00000000, 0xff000000, 0xffffffff, 0x0000fffc),
}

# Separate entries are mandatory even if review eventually selects one
# symmetric bitstream for both sites.  In that case the two choices and hashes
# may intentionally be identical; they must still be filled explicitly.
ENDPOINTS = {
    'F1': {
        'version': 0x00020409,
        'program_choice': 'direct_all_v12_f1',
        'bit_path': 'build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/artifacts/gt_test_direct_all_v7r3.bit',
        'bit_sha256': '5bce735128e22f3be029972e0290bf8a552dc196e08258a071b7ef31b30c5697',
        'dcp_path': 'build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/artifacts/gt_test_direct_all_v7r3_routed.dcp',
        'dcp_sha256': '68d0e0535f4eb8f4b17169545a0f171415222da342a2bd1170a8942523454260',
        'elf_path': 'build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/artifacts/firmware_direct_all_v7/gt_test_direct_all_v7.elf',
        'elf_sha256': 'a2370f4b0b6132bffef5323aca834b5a4c174dfedeb4b0c113df6a0bc6a3c163',
        # Receive selection excludes this endpoint's two unpopulated inputs.
        # The TX-session command still uses all 56 managed bits because that
        # is the firmware session ABI; the two peerless drivers are harmless.
        'external_lanes': EXTERNAL_LANES['F1'],
        'external_mask': EXTERNAL_MASKS['F1'],
    },
    'F2': {
        'version': 0x00020409,
        'program_choice': 'direct_all_v12_f2',
        'bit_path': 'build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/artifacts/gt_test_direct_all_v7r3.bit',
        'bit_sha256': '5bce735128e22f3be029972e0290bf8a552dc196e08258a071b7ef31b30c5697',
        'dcp_path': 'build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/artifacts/gt_test_direct_all_v7r3_routed.dcp',
        'dcp_sha256': '68d0e0535f4eb8f4b17169545a0f171415222da342a2bd1170a8942523454260',
        'elf_path': 'build/diagnostic_archive/direct-all-v12-0x00020409-scoped-pass/artifacts/firmware_direct_all_v7/gt_test_direct_all_v7.elf',
        'elf_sha256': 'a2370f4b0b6132bffef5323aca834b5a4c174dfedeb4b0c113df6a0bc6a3c163',
        'external_lanes': EXTERNAL_LANES['F2'],
        'external_mask': EXTERNAL_MASKS['F2'],
    },
}


def validate_contract():
    if RELEASED is not True:
        raise RuntimeError('all-direct v7 release contract is not enabled')
    required = ('version', 'program_choice', 'bit_path', 'bit_sha256',
                'dcp_path', 'dcp_sha256', 'elf_path', 'elf_sha256',
                'external_lanes', 'external_mask')
    for site in ('F1', 'F2'):
        profile = ENDPOINTS.get(site, {})
        missing = [name for name in required if profile.get(name) in (None, '')]
        if missing:
            raise RuntimeError('%s release contract incomplete: %s' %
                               (site, ','.join(missing)))
        if not isinstance(profile['version'], int) or profile['version'] <= 0:
            raise RuntimeError(site + ' invalid identity pin')
        for name in ('bit_sha256', 'dcp_sha256', 'elf_sha256'):
            value = profile[name]
            if len(value) != 64 or any(ch not in '0123456789abcdef' for ch in value):
                raise RuntimeError('%s invalid %s pin' % (site, name))
        lanes = tuple(profile['external_lanes'])
        mask = tuple(profile['external_mask'])
        if lanes != EXTERNAL_LANES[site] or mask != EXTERNAL_MASKS[site]:
            raise RuntimeError(site + ' fixed external topology changed')
        if len(lanes) != EXTERNAL_FITTED_COUNT or len(set(lanes)) != len(lanes):
            raise RuntimeError(site + ' external fitted-lane count mismatch')
        if any(lane not in ALL_DIRECT_LANES for lane in lanes):
            raise RuntimeError(site + ' external lane outside managed range')
        derived = [0, 0, 0, 0]
        for lane in lanes:
            derived[lane // 32] |= 1 << (lane % 32)
        if mask != tuple(derived):
            raise RuntimeError(site + ' external lane/mask mismatch')
    if ALL_DIRECT_LANES != tuple(range(56, 112)):
        raise RuntimeError('all-direct lane range changed')
    if ALL_DIRECT_MASK != (0, 0xff000000, 0xffffffff, 0x0000ffff):
        raise RuntimeError('all-direct mask changed')
    if DIRECT_REFCLK_ADDRESSES != (0x2c, 0x30, 0x38, 0x3c, 0x40, 0x44):
        raise RuntimeError('all-direct REFCLK monitor set changed')
    return ENDPOINTS
