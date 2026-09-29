# Ibex-Based Real-Time ECU

A processor-based, hardware-accelerated Electronic Control Unit (ECU) for real-time stabilization of a two-wheel self-balancing robot.

The architecture combines an Ibex RISC-V processor for programmable supervision with dedicated hardware for the deterministic sensing, control, and actuation path.

## Architecture

```text
                         +----------------------+
                         |      Ibex RISC-V     |
                         |       CPU            |
                         +----------+-----------+
                                    |
                              CPU Data Port
                                    |
                                    v
                         +----------------------+
                         |   MMIO Interconnect  |
                         |    Address Decoder   |
                         +----------+-----------+
                                    |
              +---------------------+----------------------+
              |            |             |          |      |
              v            v             v          v      v
            Timer         I2C          Filter       PID    PWM
                           |              |           |      |
                           v              v           |      v
                          IMU       Control Data     |  Motor IF
                                                     |
 IMU -> I2C -> Measurement -> Filter -> Angle -> Error -> PID -> PWM -> Motor
  ^                                                                       |
  |                                                                       v
  +-------------------- Robot / H-Bridge / Motors <-----------------------+
```

## Repository Layout

```text
.
├── docs/
├── fpga/
├── rtl/
├── task-sheets/
├── tb/
├── waveforms/
└── README.md
```

## Directory Roles

- `rtl/` - synthesizable ECU hardware.
- `tb/` - module and system testbenches.
- `fpga/` - board-specific constraints, scripts, wrappers and hardware setup.
- `docs/` - architecture, interfaces, memory/register maps, timing and design decisions.
- `task-sheets/` - detailed work instructions and milestones for each team member.
- `waveforms/` - simulation waveform evidence and debugging captures.

## Main Hardware Blocks

### Processor
- Ibex RISC-V CPU
- Ibex wrapper/integration
- Instruction memory
- Data RAM
- Interrupt integration

### Interconnect
- MMIO bus
- Address decoder
- Peripheral register interfaces

### Sensor path
- I²C master
- IMU initialization/readout
- Measurement register and synchronizer
- Digital filter
- Angle conversion/scaling
- Error calculation

### Control
- Hardware PID accelerator
- PID configuration/status registers
- Saturation
- Anti-windup

### Timing and actuation
- Timer/control scheduler
- Timer interrupt
- PWM generator
- Motor interface

### Safety
- Tilt cutoff
- Sensor timeout
- Watchdog
- Fault logic
- Motor-enable interlock
- Status/fault registers

## Team Ownership

| Member | Primary responsibility |
|---|---|
| Jatin | Ibex integration, MMIO architecture, hardware PID, firmware, top-level integration |
| Kaushal | I²C/IMU subsystem and CPU bring-up support |
| Dipiksha | Timer, measurement path, filtering, angle/scaling and error calculation |
| Vedam | Memory subsystem and safety/fault subsystem |
| Jaydev | PWM, motor interface, actuator outputs and FPGA pin/constraint work |

## Definition of Done

A block is not complete merely because the RTL compiles.

Use:

```text
Specification
    ↓
RTL
    ↓
Unit testbench
    ↓
Simulation
    ↓
Interface verification
    ↓
FPGA verification
    ↓
System integration
```

## Rules

1. Keep shared interfaces stable.
2. Document widths, reset behavior, timing and handshakes.
3. Do not change another member's interface without agreement.
4. Keep board-specific code out of portable RTL where possible.
5. Every RTL block must have a testbench.
6. Save important waveform evidence.
7. Keep the verified RTL baseline stable before ASIC implementation.

## FPGA and ASIC

The complete ECU is intended to be prototyped on a sufficiently resourced FPGA such as the Arty A7-100T.

After functional FPGA validation, the verified RTL will be taken into the intended SCL 180 nm RTL-to-GDSII flow.

The FPGA implementation and ASIC implementation should share the same logical architecture and portable RTL wherever practical.
