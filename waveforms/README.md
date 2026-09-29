# Waveforms

This directory stores important simulation waveform evidence.

## Purpose

Waveforms should demonstrate actual functional behavior and help debug integration problems.

## Suggested Organization

```text
waveforms/
├── cpu/
├── bus/
├── i2c/
├── timer/
├── measurement/
├── filter/
├── pid/
├── pwm/
├── safety/
└── full_ecu/
```

## Important Captures

### CPU/MMIO
- CPU request
- Address
- Read/write
- Peripheral select
- Response

### I²C
- START
- Address
- R/W
- ACK/NACK
- Register address
- Data
- STOP

### Timer
- Counter
- Period
- Compare
- `control_tick`

### Measurement/filter
- Raw sample
- Valid
- Filter state
- Filtered output
- Angle

### PID
- Error
- Previous error
- Integral state
- P term
- I term
- D term
- Unsaturated output
- Saturated output
- Output valid

### PWM
- Period
- Duty
- Counter
- PWM output

### Safety
- Fault input
- Fault latch
- Motor enable
- Reset/clear

### Full ECU
- CPU/MMIO transaction
- Sensor sample
- Control tick
- Error
- PID output
- PWM
- Motor enable

Use descriptive names and add a short note explaining what each waveform proves.
