# Testbenches

This directory contains simulation testbenches for the ECU RTL.

## Purpose

Every RTL block must be verified independently before being integrated into the complete ECU.

## Suggested Structure

```text
tb/
├── cpu/
├── memory/
├── mmio/
├── timer/
├── i2c/
├── measurement/
├── filter/
├── angle/
├── error/
├── pid/
├── pwm/
├── motor/
├── safety/
└── ecu_soc/
```

## Verification Levels

### 1. Unit
Test one module in isolation.

### 2. Subsystem
Test connected groups such as:

```text
I²C → Measurement
Measurement → Filter → Angle → Error
PWM → Motor Interface
```

### 3. SoC
Test:

```text
Ibex → MMIO → Peripheral
```

### 4. Full ECU
Exercise the sensor-to-actuator path and observe:

- Sensor data
- Sample validity
- Filtered measurement
- Error
- PID output
- PWM
- Motor commands
- Safety response

## Minimum Test Categories

- Reset
- Normal operation
- Boundary values
- Enable/disable
- Invalid requests
- Error conditions
- Saturation
- Timing/latency
- Back-to-back transactions where applicable
