# Task Sheets

This directory contains the detailed implementation roadmap for each team member.

## Purpose

A task sheet must tell a member not only what to build, but how to start, how to verify it, how it connects to the ECU, and what counts as complete.

## Suggested Files

```text
jatin_cpu_pid.md
kaushal_i2c_ibex_support.md
dipiksha_timer_sensing.md
vedam_memory_safety.md
jaydev_pwm_motor.md
```

## Each Task Sheet Should Include

- Objective
- Blocks owned
- What to learn first
- Implementation order
- Inputs and outputs
- Register interface
- Clock/reset behavior
- Handshake/valid signals
- Expected latency
- Unit-test plan
- FPGA-test plan
- Dependencies
- Handoff requirements
- Definition of done
- Current status
- Open issues

## Completion Standard

```text
Specification
    ↓
RTL
    ↓
Unit testbench
    ↓
Simulation passes
    ↓
Interface verified
    ↓
FPGA test where applicable
    ↓
Documentation updated
```
