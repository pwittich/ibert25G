"""Independent eye-scan image contract; hardware release is a separate gate."""
VERSION = 0x00020503
RELEASED = False
BIT_SHA256 = "e170ead04e42c662e4a711c156a048e22da3c7c280e6820a6e644daec5b2850f"
DCP_SHA256 = "af25ba8aa3f5d04437af04f854631b2605b005355bd5f5399f4e7f5157e40873"
ELF_SHA256 = "c9b85dbce9299d50974b660e40778806a4d86d4354a181035a9848e5d42445e7"
CM_COMMIT = "64260cf23b01c9da987feda1fbf51567240c2c71"
RUNTIME_FILES = (
    "board_eye_scan.py", "eye_scan_v1_contract.py", "eye_scan_data.py",
    "all_links_v3_contract.py", "all_links_v2_timed_common.py",
    "all_links_v2_timed_contract.py", "milestone3_12hour_external_soak.py",
)


def require_release():
    import re
    if not RELEASED or not all(isinstance(value, str) and
                              re.fullmatch("[0-9a-f]{64}", value)
                              for value in (BIT_SHA256, DCP_SHA256, ELF_SHA256)):
        raise RuntimeError("eye-scan v1 is UNRELEASED: audited artifact pins and reviewed hardware gate required")
