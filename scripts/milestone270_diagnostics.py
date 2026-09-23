#!/usr/bin/env python3
"""Read-mostly v270 diagnostic evidence capture."""
import milestone268_diagnostics as diagnostics

if __name__ == "__main__":
    diagnostics.VERSION = 0x00020114
    diagnostics.main()
