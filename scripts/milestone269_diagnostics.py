#!/usr/bin/env python3
"""Read-mostly dump for matching v269 FW/HW and banked trace schema."""
import milestone268_diagnostics as diagnostics

if __name__ == "__main__":
    diagnostics.VERSION = 0x00020113
    diagnostics.main()
