# RTL

This directory contains the synthesizable hardware implementation.

## Suggested Structure

```text
rtl/
├── cpu/
├── bus/
├── memory/
├── timer/
├── i2c/
├── sensing/
├── control/
├── pwm/
├── motor/
├── safety/
└── top/
```

## Functional Areas

### CPU
- Ibex integration/wrapper
- Instruction interface
- Data interface
- Interrupt interface

### Bus
- MMIO interconnect
- Address decoding
- Peripheral selection
- Read/write response routing

### Memory
- Instruction ROM
- Data RAM
- Memory wrappers/controllers

### Sensor
- I²C master
- IMU reader
- Measurement synchronization
- Digital filtering
- Angle conversion/scaling
- Error calculation

### Control
- Hardware PID
- PID register bank
- Saturation
- Anti-windup

### Timing
- Timer
- Control tick
- Optional timer interrupt

### Actuation
- PWM generator
- Motor interface
- Actuator output stage

### Safety
- Fault monitor
- Watchdog
- Tilt cutoff
- Sensor timeout
- Motor-enable interlock
- Status registers

### Top
- `ecu_soc_top`

## RTL Rules

- Keep functional RTL synthesizable.
- Define reset behavior explicitly.
- Define signal widths explicitly.
- Avoid hidden timing assumptions.
- Use documented interfaces.
- Avoid unnecessary FPGA-specific primitives.
- Every functional block must have a corresponding testbench in `tb/`.
