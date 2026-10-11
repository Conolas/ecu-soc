# ECU SoC — Hardware Blocks

This directory is the central index for the hardware blocks in the ECU SoC project.

Each block directory contains its design documentation, implementation notes, verification status, and supporting evidence.

## Block Directory

| Block | Owner | Purpose |
|---|---|---|
| `hw_pid_accel/` | Jatin | Fixed-point PID controller |
| `cpu_subsystem/` | Jatin | RISC-V CPU integration |
| `ecu_soc_top/` | Jatin | Top-level SoC integration |
| `i2c_sensor_subsystem/` | Kaushal | I2C controller and IMU communication |
| `timer_unit/` | Dipiksha | Control timer and tick generation |
| `sensor_pipeline/` | Dipiksha | Calibration, angle/rate processing, and filtering |
| `rom_dp/` | Vedam | Program ROM |
| `ram_sp/` | Vedam | Data RAM |
| `clk_rst_gen/` | Vedam | Clock and reset generation |
| `safety_fault_monitor/` | Vedam | Safety states, fault detection, and motor shutdown |
| `bus_interconnect/` | Vedam | Memory-mapped bus routing |
| `actuation_subsystem/` | Jaydev | PWM generation and motor actuation |
| `ecu_fpga_top/` | Jaydev | FPGA board integration and pin mapping |

## What Each Block Should Document

- Purpose and functionality
- Owner and current status
- Module ports and interface contract
- Clock, reset, timing, and data formats
- Register map and reset values, where applicable
- Dependencies on other blocks
- Implementation notes and design decisions
- Test cases, expected results, and verification status
- Known issues, blockers, and next actions
- Links to the canonical RTL, testbench, constraints, and waveforms

## Working Rules

1. Do not change frozen ports, register addresses, or data formats without an agreed interface update.
2. Keep canonical RTL in `rtl/` and testbenches in `tb/`.
3. Store only useful, reproducible evidence in each block's `evidence/` directory.
4. Record failed tests and known issues as well as successful results.
5. Update the block README when implementation status changes.
6. Submit changes through pull requests and include relevant verification evidence.

**Goal:** Every team member should be able to open a block directory and quickly understand its design, owner, implementation status, and verification progress.