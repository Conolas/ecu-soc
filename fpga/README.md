# FPGA

This directory contains FPGA-specific files and hardware-validation material.

## Purpose

Keep board-dependent information separate from portable ECU RTL.

## Typical Contents

```text
constraints/
scripts/
board_wrappers/
build/
programming/
hardware_tests/
```

Possible files include:

- XDC pin constraints
- Clock constraints
- FPGA top-level wrappers
- Vivado build scripts
- Synthesis/implementation settings
- Bitstream generation scripts
- Programming instructions
- ILA/debug configuration
- Hardware test notes

## Target

The primary full-system prototype target is the Arty A7-100T.

## Portability Rule

Prefer:

```text
Portable RTL
    ↓
FPGA wrapper
    ↓
Board constraints
```

rather than embedding board-specific primitives in the ECU's functional RTL.
