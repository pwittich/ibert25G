# Constraint playbook

## Review checklist

- Ensure every real clock is defined once at the correct object.
- Derive generated clocks from the transforming primitive and master clock.
- Check asynchronous clock groups against actual CDC circuitry.
- Use false paths only for paths that are functionally never timed.
- Bound valid asynchronous transfers with appropriate CDC structure and constraints; do not use blanket false paths to suppress analysis.
- Review multicycle setup and its paired hold constraint together.
- Look for empty object collections and constraints overridden later in the read order.
- Check package pin, I/O standard, bank voltage, differential polarity, and dedicated clock-route use.

## This repository

Preserve all physical lane and REFCLK ordering documented in `README.md` and the XDC files. FireFly 3 has deliberate reversed wrapper packing. FF6 RX lane 1 deliberately uses `M48`/`M49`. Do not normalize either mapping.

The two IBERTs must contain only the FireFly and FPGA-to-FPGA 25.78125-Gb/s lanes. REFCLK0 is 322.265625 MHz. The 10-Gb/s AXI C2C interface is excluded.

The encrypted IBERT floorplan Tcl must execute in the correct wrapper hierarchy through the pre-place hook. Expect 14 pblocks for each IBERT core. Keep SysMon placement one instance per SLR and preserve the four visibly labeled I2C addresses in `src/top.sv`.

