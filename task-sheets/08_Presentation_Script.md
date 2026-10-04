# ecu_soc — Presentation Script (67 slides)

**Project Review Phase 1 · 9 October 2026**
Speakers: **Kaushal (lead)** · **Dipiksha** · **Vedam** · **Jaydev**. Jatin is away on an internship; Kaushal covers his sections (system architecture, hardware PID, Ibex integration, firmware context).

---

## 1. How to use this script

- Spoken style, not slide-reading. The slides carry the numbers; you carry the *meaning*. If you forget a line, use the **Key point** in bold at the start of each slide.
- `[click]` = advance slide. `[point: …]` = gesture at a part of the diagram. `→ Name` = hand-off line.
- Say numbers slowly. Say "I-squared-C", "Q-sixteen-point-sixteen", "R-V thirty-two I-M-C".
- Nominal run time **≈ 29–30 minutes** at a steady pace (about 4,300 spoken words). A 20-minute fast track is in Section 5.
- Wording rule for the whole panel: say **"target," "plan," "we will measure"**. Never say "we achieved" or "proven". Do not mention fabrication. Do not claim results that are not on the slides.

### Speaker allocation

| Speaker | Slides | Approx. time |
|---|---|---|
| **Kaushal** | 1–4, 14–21, 27–29, 38 (top level), 39, 44, 45, 47, 62, 63 (own), 65–67 | ≈ 11 min |
| **Dipiksha** | 5–8, 12, 13, 22 (timer), 23–26, 40, 42, 43, 58, 63 (own) | ≈ 8 min |
| **Vedam** | 9–11, 22 (clock/reset), 33–38 (memory map), 41, 46, 48, 56, 57, 60, 61, 63 (own) | ≈ 7 min |
| **Jaydev** | 30–32, 38 (FPGA wrapper), 49–55, 59, 63 (own), 64 | ≈ 6 min |

Hand-offs are scripted. Slides 22, 38 and 63 are shared.

---

# PART A — Context and objectives  (≈ 2 min)

### Slide 1 — Title · **Kaushal** · 20 s
**Key point:** we built a hardware ECU as a SoC; Jatin is away, I cover his parts.

Good morning, ma'am and sir. We are team ecu_soc from the Department of VLSI Design and Technology, working under the guidance of Dr. Sonia Kurade. Our project is a RISC-V hardware ECU, designed as a system-on-chip, for a self-balancing robot, and we plan to take it from RTL, through FPGA validation, to layout.

I am Kaushal. With me are Dipiksha, Vedam and Jaydev. Our team lead and system architect, Jatin, is away on an internship today, so I will also cover his sections: the architecture, the hardware PID, and the Ibex CPU.

### Slide 2 — Part A divider · **Kaushal** · 3 s
Let me begin with the context and the objectives. `[click]`

### Slide 3 — What is an ECU? · **Kaushal** · 25 s
**Key point:** sense, decide, act, on time.

An ECU, an Electronic Control Unit, is a small computer inside a machine that does three things again and again, within strict time limits: it senses, it decides, and it acts. A modern vehicle carries many of them: powertrain, safety systems, body control, air conditioning, lighting, keyless entry.

`[point: the three boxes]` In our project the sensor is an IMU that measures tilt, the actuators are two motors, and in the middle is our ECU: an I-squared-C interface, a filter, a PID controller, PWM generation, a safety monitor and a small CPU. We designed it as a system-on-chip for a self-balancing robot.

### Slide 4 — Problem statement · **Kaushal** · 40 s
**Key point:** balancing is unforgiving; typical designs let software timing and software safety share one processor.

Why a balancing robot? Because it is unforgiving. A two-wheeled robot is naturally unstable, like balancing a broomstick on your palm. It has to measure its tilt and correct it within milliseconds, hundreds of times a second.

`[point: left column]` Typically this is a software loop on a general-purpose microcontroller. That has three weaknesses: the timing jitters with the firmware, the safety logic shares the same processor, so if the software stalls the protection stalls with it, and commercial ECUs are closed, so students cannot look inside.

`[point: right column]` Our approach: a dedicated hardware loop with fixed latency does the balancing. A small RISC-V CPU only configures and supervises. A hardware safety monitor can cut the motors independently of any software. Think of the human body: the reflex acts instantly without waiting for the brain; the brain, our CPU, oversees. And we verify it in simulation, validate on FPGA and carry it through layout.

→ **Dipiksha**, our objectives.

### Slide 5 — Objectives and scope · **Dipiksha** · 30 s
**Key point:** six objectives, modest scope, honest targets.

Thank you, Kaushal. We have six objectives. One: synthesizable Verilog for every block, verified against a reference model. Two: the real-time datapath, I-squared-C sensor read, calibration, filtering, fixed-point PID and PWM. Three: hardware safety, covering tilt, sensor loss, watchdog and emergency stop. Four: an Ibex RISC-V core with memory and a memory-mapped bus. Five: FPGA validation, block by block and then as a full ECU on a balancing robot. Six: the Cadence RTL-to-GDSII flow.

In scope: single-axis PID balancing, one IMU, two DC motors. Future: LQR or MPC, outer loops, wireless, multi-axis. And these are targets: we will report what we measure.

---

# PART B — Concept, methodology and positioning  (≈ 5.5 min)

### Slide 6 — Part B divider · **Dipiksha** · 3 s
Now the concept and our methodology. `[click]`

### Slide 7 — The inverted pendulum · **Dipiksha** · 40 s
**Key point:** upright is an unstable equilibrium; control must act in tens of milliseconds.

To understand the controller we need the physics. An inverted pendulum is a rod balanced upright. Upright is an equilibrium, but an unstable one: any small tilt grows.

For small angles, the tilt acceleration is gravity over length times the tilt, minus the base acceleration over length. `[point: the equation]` The first term is gravity pushing the tilt larger. The second is our control knob: accelerate the base under the lean and you push the tilt back.

How fast does it fall? The error grows by about 2.7 times every square root of l over g. For a fifteen-centimetre height that is about 0.12 seconds. So the controller must react in tens of milliseconds. In our robot the body is the pendulum, the wheels are the movable pivot, the motors provide the acceleration, and the IMU is the tilt sensor.

### Slide 8 — The balancing loop · **Dipiksha** · 30 s
**Key point:** sense, compute, act, 512 times a second.

That gives the balancing loop. `[point: boxes left to right]` The IMU measures tilt and rotation rate, we estimate the angle, compute the error, run the controller, and drive the motors through the PWM and H-bridge. The motors move the wheels, the tilt changes, and the IMU measures again. The rule: lean forward, drive forward.

One pass takes about 1.95 milliseconds, so 512 times a second. Our hardware stages take well under 5 microseconds, reading the sensor takes about 0.4 milliseconds, and the sensor's own low-pass filter, about 3 milliseconds, dominates the delay. The loop has to cope with pushes, uneven floors, battery changes and sensor noise.

→ **Vedam**, our design choices.

### Slide 9 — Why PID · **Vedam** · 30 s
**Key point:** PID is the simplest controller that maps cleanly to a small fixed-point hardware block.

Thank you, Dipiksha. Three design choices, starting with the control strategy. Fuzzy-tuned PID needs an extra rule base. LQR or state feedback needs a model, wheel encoders and matrix maths. MPC or adaptive control needs a model and an optimiser, which is overkill here.

PID needs only angle and rate, is low complexity, and fits a small fixed-point hardware block. Its gains live in registers, so tuning does not need re-synthesis. That is why PID is our choice.

### Slide 10 — Sensing and angle estimation · **Vedam** · 35 s
**Key point:** accelerometer for tilt, gyro for rate, short smoothing.

Second, sensing. An accelerometer alone gives an angle without drift, but it is noisy when the robot accelerates. A gyroscope alone is smooth and fast, but it drifts. A complementary filter combines both cheaply with one tuning constant. A Kalman filter is optimal but heavy.

Our baseline is simple: tilt from the accelerometer, the gyro rate used directly for the derivative term, and a short moving average. A shift-only complementary filter is available as an option. The sensor is the MPU-6050, an accelerometer and gyroscope in one chip, read over I-squared-C.

### Slide 11 — Hybrid implementation platform · **Vedam** · 30 s
**Key point:** option D gives fixed timing, independent safety and configurability.

Third, where to implement it. `[point: table rows]` A, software PID on an MCU: easy, but timing depends on firmware and safety shares the CPU. B, a fixed-function FPGA controller: deterministic but inflexible. C, a soft-core CPU doing everything: flexible, but timing depends on software.

D is ours: a hardware datapath with a RISC-V supervisor. Latency is fixed in clock cycles, safety is independent of software, and it is still configurable through registers. The cost is more design and verification work, and that is exactly what this project is about.

→ **Dipiksha**, the literature.

### Slide 12 — Literature survey · **Dipiksha** · 40 s
**Key point:** each work has one piece; in the works we reviewed, none has the whole combination.

Our literature survey shows that PID works, FPGAs help, and RISC-V is entering ECUs. `[point: rows]` R1 built a balancing robot with PD control in an open-source FPGA, but the IMU was read through an external Arduino. R2 used an ESP32 with a complementary filter and PID: a software loop, so no hardware determinism. R3 and R4 used National Instruments FPGA platforms: commercial, with a vendor tool flow. R5 used an ATmega with fuzzy-tuned PID. R6 is an IEEE survey saying FPGA accelerators suit latency-critical robotics. R7 studies RISC-V automotive ECUs and an interrupt-latency gap. R8 is the Ibex core itself.

Each has a piece. In the works we reviewed, none combines all of them in a small, open platform.

### Slide 13 — Is anyone else doing something similar? · **Dipiksha** · 35 s
**Key point:** the pattern is proven in industry; our contribution is an open, student-scale reference.

Is anyone else doing something similar? Honestly, yes: the architectural idea is established in industry. Texas Instruments' C2000 has a control-law accelerator that runs independently of the main CPU. There are RISC-V motor drives with hardware field-oriented control, Codasip cores with CORDIC accelerators, SignOff's dual-core RISC-V controller, and Infineon's RISC-V automotive MCUs.

What we did not find, in a limited search, is an open, small-scale reference that combines a RISC-V supervisor, a hardware PID, CPU-independent safety and a documented path to layout. So we are not competing with these products. We are building a transparent, student-scale reference of a proven pattern.

→ **Kaushal**, what is different.

### Slide 14 — What is different · **Kaushal** · 40 s
**Key point:** the novelty is the combination, openness and documentation.

Thank you. So what is different in our approach? Six things. One: the CPU is out of the loop. Balancing is a fixed-latency hardware pipeline and Ibex only supervises. Two: an independent safety monitor. Motors go off within two clock cycles, that is forty nanoseconds, and re-arming is deliberate. Three: the derivative term comes from the gyro rate, with built-in anti-windup. Four: everything is tunable through registers, with no re-synthesis. Five: a frozen interface contract, so five people build in parallel without breaking each other's blocks. Six: it is end to end and documented, from simulation to FPGA to layout.

To be precise about novelty: the individual ideas are known. What is new is this open, fully documented combination, built by students, that anyone can read and learn from.

### Slide 15 — Why it fits, and the trade-offs · **Kaushal** · 30 s
**Key point:** we state the costs openly.

We are upfront about trade-offs. Timing is fixed in clock cycles instead of varying with firmware. The CPU is free for supervision. Safety is a separate hardware monitor. Tuning means writing registers, not recompiling. Every signal is observable.

The costs: design effort is higher, and changing the algorithm needs an RTL change. We accept that for predictability and safety independence, and we will measure latency, jitter and fault response rather than assume them.

---

# PART C — System architecture and blocks  (≈ 11.5 min)

### Slide 16 — Part C divider · **Kaushal** · 3 s
Part C: the architecture and the blocks. `[click]`

### Slide 17 — System architecture and block diagram · **Kaushal** · 55 s
**Key point:** two wings: a real-time hardware loop and a supervisory CPU plane.

This is the whole system, and it has two wings. Wing A, on top, is the real-time datapath, and there is no CPU in this loop. `[point: follow the green arrows]` The MPU-6050 feeds the I-squared-C master, then measurement and calibration, angle conversion, the filter and the error calculation. The hardware PID computes the command. The PWM generator and motor interface drive two BTS7960 H-bridge modules, which drive the motors. The robot tilts, the sensor sees it, and the loop is closed.

`[point: middle boxes]` Supporting blocks: a timer that produces the 512-hertz control tick, clock and reset, and the safety monitor, which watches the angle and controls the motor-enable signal.

`[point: bottom lane]` Wing B is the supervisory plane. The Ibex CPU talks over a memory-mapped bus to ROM, RAM and six register banks: timer, I-squared-C, sensor, PID, PWM and safety. The CPU only writes numbers into registers and reads status. It is never in the real-time path.

### Slide 18 — Data flow, timing and conventions · **Kaushal** · 30 s
**Key point:** shared conventions let five people build in parallel.

A few conventions hold the design together. One 50-megahertz clock domain. Each stage passes its data with a one-cycle valid pulse. Numbers use Q-sixteen-point-sixteen fixed-point; for example, a quarter radian is 16384. Motor commands run from minus one to plus one.

In a 1.95-millisecond cycle, the I-squared-C burst takes about 0.4 milliseconds and our hardware stages take microseconds, leaving over 1.5 milliseconds of margin. Every stage must finish within 64 clock cycles, and names, widths, formats and addresses are frozen team-wide. That is what allows parallel work.

### Slide 19 — I²C master · **Kaushal** · 30 s
**Key point:** a small bit-level engine that talks to the MPU-6050 at about 390 kHz.

Now the blocks, starting with mine. The I-squared-C master talks to the MPU-6050. The lines are open-drain: the block only pulls low or releases. Speed: SCL equals clock divided by four times divider plus one. With divider 31 we get about 390 kilohertz, just under the sensor's 400-kilohertz limit.

A bit-level state machine handles start, eight data bits, acknowledge, repeated start and stop, with input synchronisers, clock stretching and a nine-pulse stuck-bus recovery. One byte is nine clocks, about 23 microseconds. We verify with a behavioural slave model covering acknowledge, no-acknowledge, repeated start and stretching, and then on the board with the ILA.

### Slide 20 — I²C master sensor subsystem · **Kaushal** · 20 s
**Key point:** layered: controller, byte engine, registers.

`[point: left to right]` The controller on the left has an init state machine, a burst-read state machine and a sample assembler. It drives the I-squared-C byte engine, which drives the pins to the MPU-6050. The register bank sits below. At the bottom you see one burst read: start, address, register 0x3B, repeated start, read address, fourteen data bytes, then no-acknowledge and stop. About 0.4 milliseconds.

### Slide 21 — MPU-6050 controller and register bank · **Kaushal** · 30 s
**Key point:** safe start-up, one coherent 14-byte sample per tick.

At start-up the controller waits about 50 milliseconds, reads WHO_AM_I and expects 0x68, wakes the sensor, because it powers up asleep, then sets the sample divider, the low-pass filter, gyro plus or minus 250 degrees per second and accelerometer plus or minus 2 g.

Every tick it reads fourteen bytes from 0x3B: accelerometer X, Y, Z, temperature, then gyro X, Y, Z, high byte first. The six values are published together only after the stop condition, so a sample is never half-updated. On a no-acknowledge or timeout it aborts, counts and skips, and three in a row triggers re-initialisation. Tick to sample ready: about 0.4 milliseconds.

→ **Dipiksha**, the timer.

### Slide 22 — Timer, clock and reset · **Dipiksha** then **Vedam** · 30 s
**Key point (Dipiksha):** the timer gives the 512 Hz heartbeat. **(Vedam):** clean clock and reset.

**Dipiksha:** The timer is mine. It is a 32-bit counter with a programmable period. The default is 97,656 cycles at 50 megahertz, about 512 hertz. It outputs the control tick, a one-cycle pulse that starts every sample, and a CPU interrupt every 51 ticks, about 10 hertz. If the sensor is still busy when the next tick arrives, an overrun flag is set. → Vedam.

**Vedam:** The clock and reset block is mine. The board oscillator feeds a clock manager that generates the 50-megahertz clock. Reset asserts immediately, releases synchronously, and is held until the clock locks, so every block starts cleanly.

### Slide 23 — Measurement capture and calibration (diagram) · **Dipiksha** · 15 s
**Key point:** the sensor pipeline end to end.

`[point: left to right]` This is the sensor pipeline, my section. Raw sensor data enters at the left, passes capture, calibration, angle conversion, the filter and the error calculation, and leaves as error, rate and a valid pulse for the PID, with the filtered angle going to the safety monitor. The calibration state machine is underneath.

### Slide 24 — Measurement capture and calibration · **Dipiksha** · 30 s
**Key point:** capture all axes together; remove the gyro bias before use.

Capture latches all six axes at the same instant, with a sequence counter, so one sample never mixes two moments.

Gyro-bias calibration: with the robot still, the true rotation rate is zero, so whatever the gyro reports is its bias. We discard the first 64 samples, average the next 256, about 0.6 seconds in total, and subtract that bias from every later reading. A constant gyro offset behaves like a false rotation, and in any filter that integrates the gyro it grows into an angle error. The state machine is idle, settle, accumulate, done. It auto-starts in hardware-only test mode, and the safety monitor refuses to arm until calibration is done.

### Slide 25 — Angle conversion and error calculation · **Dipiksha** · 45 s
**Key point:** multiplier-free conversions: ×4 for angle, shift-add ×8.75 for rate.

A still accelerometer measures gravity along its axis: a equals g sine theta. For small angles theta is about a over g. With 16384 counts per g, converting to Q-sixteen-point-sixteen radians is simply multiply by four, a shift. For example, a reading of 4096, a quarter g, becomes 16384, a quarter radian. The approximation is about 4 percent off at half a radian, and negligible near upright.

For the gyro, 131 counts per degree per second becomes about 8.73 in Q-sixteen-point-sixteen. We use shift-add 8.75: three shifts and two adds, 0.2 percent error and no multiplier. A gyro reading of 131 gives 1145.

There are axis-select and sign-invert bits for how the sensor is mounted, and a balance-point trim register. Finally, the error is setpoint minus angle, a saturating subtraction, and the rate passes through to the PID.

### Slide 26 — Digital filter · **Dipiksha** · 45 s
**Key point:** small moving average, because delay costs stability.

The filter is a moving average of two to the k samples, k from zero to four, where zero is bypass. There is one for angle and one for rate. It is a circular buffer with a running sum: one add, one subtract, one shift, no multipliers.

The trade-off: more smoothing means more phase lag. The extra delay is about N minus one over two samples, roughly N minus one milliseconds at 512 hertz, on top of the sensor's own 3 milliseconds. So N stays small, two to eight. Check: a step from 0 to 4000 with N equal to 4 gives 1000, 2000, 3000, 4000.

Optionally, a complementary filter: the new angle is alpha times the old angle plus gyro rate times Ts, plus one minus alpha times the accelerometer angle, with alpha 63 over 64 and Ts one over 512. Shifts only, selected by a register bit.

→ **Kaushal**, the PID.

### Slide 27 — Hardware PID accelerator (diagram) · **Kaushal** · 25 s
**Key point:** P, I and D share one multiplier; output is a saturated command.

Now the hardware PID. This is Jatin's block, which I will explain. `[point: left to right]` Error and rate come in on the left. The P term, the I term with a clamped accumulator, and the D term from the gyro rate share one 32-by-32 multiplier. They are summed, then saturated to the output limit, producing a motor command between minus one and plus one, plus a saturation flag. A run-enable from the safety monitor gates the block. The registers are below and the control law is at the bottom.

### Slide 28 — Hardware PID: architecture · **Kaushal** · 30 s
**Key point:** registers make it live-tunable; one multiplier keeps it small.

Inputs: error, rate and the run-enable from safety. Outputs: the motor command in Q-sixteen-point-sixteen and a saturation flag. The register bank holds Kp, Ki pre-scaled by Ts, Kd, setpoint, integrator limit, output limit and control bits, with read-only telemetry of the P, I and D terms and the output.

The datapath is P, I with a clamped accumulator, a gyro-rate D term, then sum and saturate. One shared multiplier, time-shared by a small state machine in about eight cycles, is smaller than three multipliers. Latency target: at most 16 cycles, about 0.3 microseconds. Gains are registers, so the CPU, or a hardware default, can retune live.

### Slide 29 — PID algorithm details · **Kaushal** · 40 s
**Key point:** correct signs, two anti-windup rules, no kick on re-enable.

The law: u equals Kp times error, plus Ki times Ts times the sum of errors, minus Kd times the gyro rate. The minus sign is because the error is setpoint minus angle, so its derivative is minus the rate when the setpoint is constant.

Two anti-windup rules. The integrator is clamped. And it freezes while the output is saturated in the same direction as the error, otherwise it winds up while the motors cannot respond. If safety withdraws the run-enable, the output is zero, the integrator is cleared and the previous error reset, so there is no derivative kick on re-enable.

Worked checks: Kp 1.0 and error 0.1 gives 0.1. Kp 8 and error 0.2 would give 1.6, but it saturates at the 0.25 limit and raises the flag. A Ki step of 65 counts per sample gives 650 after ten samples. Arithmetic is Q-sixteen-point-sixteen with a 64-bit intermediate product, arithmetic shift and saturating sum.

→ **Jaydev**, the actuation side.

### Slide 30 — PWM generator (diagram) · **Jaydev** · 20 s
**Key point:** from command to motor pins safely.

Thank you, Kaushal. Now the actuation side, which is mine. `[point: top row]` The command goes through a bench mux, steering and gain, a clamp and a slew limiter. `[point: lower lane]` Then a per-motor channel: duty calculation, a direction and dead-time state machine, a PWM counter, and the motor pins. At the bottom, an enable gate from the safety monitor can force everything off.

### Slide 31 — PWM generator · **Jaydev** · 35 s
**Key point:** 20 kHz, dead-time, never both outputs high.

The PWM runs at 20 kilohertz: a period of 2500 cycles at 50 megahertz. That is within the BTS7960's 25-kilohertz limit and above audible range. Duty is the command magnitude times the period, from a small multiplier, and duty and direction update only at the period boundary, so there are no runt pulses.

A positive command drives RPWM, a negative one drives LPWM, never both, with a dead-time of 250 cycles, 5 microseconds, on every direction change. Shaping: a max-duty clamp, default 0.9 for first tests, an optional slew limiter, a steering offset and per-motor gain. If enable goes low, outputs go low within two cycles. We verify with an assertion that RPWM and LPWM are never high together, and duty checks: a command of plus 0.5 gives 1250 of 2500 counts.

### Slide 32 — Motor interface and BTS7960 driver · **Jaydev** · 35 s
**Key point:** simple mapping, protected driver, careful bring-up.

The motor interface maps the PWM channels to the driver pins. For each motor: RPWM, LPWM, R-enable and L-enable. Direction-invert bits absorb wiring differences, and the enable is gated by the safety monitor.

The driver is the BTS7960 half-bridge, one module per motor. It has an integrated driver, PWM up to 25 kilohertz, a typical current limit of about 43 amps, a supply of 5.5 to 27.5 volts, and a P-channel high-side switch, so no charge pump is needed. Built-in protections include dead-time generation, over-temperature, over- and under-voltage, over-current and short-circuit.

Our bring-up discipline: logic only first and check the waveforms, then motors on a stand with wheels off the ground, common ground, and verify the module's logic-level compatibility before connecting.

→ **Vedam**, the safety monitor.

### Slide 33 — Safety and fault monitor: state machine (diagram) · **Vedam** · 20 s
**Key point:** the block that decides whether motors may move.

Thank you, Jaydev. The safety monitor is mine, and it is the most important block on the robot. `[point: three states]` Three states: disarmed, armed, fault. An emergency stop from any state forces the motors off. From disarmed, an arm request with calibration done and no stored faults gives armed, where motors are allowed. Any fault drops us to fault within two clock cycles. To recover: clear the flags, the condition must be gone, and the arm request must go low and then high again.

### Slide 34 — Safety and fault monitor: state machine (text) · **Vedam** · 30 s
**Key point:** fail-safe by default; no software needed to turn motors off.

Motors are allowed only in armed. After reset the default is motors off, and turning them off never needs software. Arming needs the arm request, calibration done, no live fault and no stored fault flags.

Any condition drops the motor enable within two clock cycles, forty nanoseconds at 50 megahertz, and the flag is latched. Re-arming is deliberate: the robot never restarts by itself. The emergency stop is honoured from any state, and the optional watchdog detects a stalled CPU.

### Slide 35 — Safety monitor: faults and responses · **Vedam** · 40 s
**Key point:** six faults, all latch, all programmable.

Six faults. Tilt: the angle beyond 0.6 radians, about 34 degrees, on three consecutive samples. Sensor timeout: no sample for 8 ticks, about 16 milliseconds. I-squared-C error: three consecutive failed transactions. PID saturation: output saturated for 256 samples, about half a second. Watchdog: no CPU kick for 100 ticks, about 195 milliseconds, if enabled. Emergency stop: an external active-low button, immediate.

All latch and turn the motors off. The thresholds are registers, and firmware can read the flags and receives an interrupt. Our tests: every fault alone, two at a time, glitch rejection, where a two-sample spike must not trip, and the re-arm sequence.

### Slide 36 — Memory subsystem and bus interconnect (diagram) · **Vedam** · 20 s
**Key point:** one decoder connects the CPU to memory and registers.

The bus interconnect is also mine. `[point: left to right]` Ibex's instruction and data ports enter on the left. Inside: an instruction path, an address decoder, a select register, a read-data mux and an error responder. On the right are the ROM, the RAM and the six register banks with their base addresses.

### Slide 37 — Memory subsystem and bus interconnect · **Vedam** · 30 s
**Key point:** zero wait states, and a bad address never hangs the CPU.

The ROM is 8 kilobytes and holds the firmware image, with two read ports, one for instruction fetch and one for constants. The RAM is 4 kilobytes, for stack and variables, and it is byte-writable. The instruction port goes to ROM. The data port goes through an address decoder to ROM, RAM and the register banks.

Protocol: the request is granted in the same cycle and data returns one cycle later, so zero wait states, and writes are acknowledged too. As a safety net, an unmapped address returns an error with no side effect, so the CPU never hangs on a bad address. Sizes are parameters, kept small on purpose to be layout-friendly.

### Slide 38 — Memory map, register banks and top level · **Vedam**, **Kaushal**, **Jaydev** · 40 s
**Key point:** one clean map; every bank has an ID word.

**Vedam:** This is the memory map: ROM at address zero, the six register banks from 0x1000_0000 in 4-kilobyte steps, timer, I-squared-C, sensor pipeline, PID, PWM and safety, and RAM at 0x2000_0000. Every bank starts with a read-only ID word, such as T-I-M, I-2-C or P-I-D, so firmware can prove the bus works. Status bits are write-one-to-clear and command bits are self-clearing. → Kaushal.

**Kaushal:** At the top level, ecu_soc_top wires all the blocks together. A HW_ONLY parameter lets the hardware loop run without the CPU for early FPGA tests. → Jaydev.

**Jaydev:** And the FPGA wrapper holds the board-specific parts: clocks, input synchronisers, open-drain I-squared-C buffers and the LEDs.

### Slide 39 — SoC system hierarchy · **Kaushal** · 25 s
**Key point:** only the wrapper is board-specific.

`[point: outer box, then inner groups]` This is the hierarchy. The FPGA wrapper surrounds ecu_soc_top. Inside are three groups: the real-time path, with timer, I-squared-C subsystem, sensor pipeline, PID and actuation; the support blocks, with the safety monitor, clock and reset and the register banks; and the supervisory plane, with the CPU, bus, ROM and RAM. Nothing board-specific lives inside ecu_soc_top, so moving to another board changes only the wrapper.

---

# PART D — The CPU: Ibex  (≈ 4.5 min)

### Slide 40 — Part D divider · **Dipiksha** · 3 s
Part D: the CPU. `[click]`

### Slide 41 — Role of the CPU · **Vedam** · 25 s
**Key point:** the CPU supervises; it never touches the real-time lane.

What does the CPU do? On the left, the supervisor lane: it boots and self-checks by reading the bank IDs, loads gains, limits and settings, starts calibration and arms or disarms, watches status and faults and logs telemetry, and serves the timer and fault interrupts. Later it can run higher-level behaviour.

On the right is the real-time lane, which the CPU does not perform: reading the sensor, computing the PID, generating PWM, or switching off the motors on a fault. So the CPU can be slow, busy or even crash without the balance loop losing its timing, and the watchdog notices a stalled CPU.

→ **Dipiksha**, why Ibex.

### Slide 42 — CPU options compared and our decision · **Dipiksha** · 35 s
**Key point:** Ibex wins on openness, simplicity and flow compatibility.

Thank you, Vedam. Our criteria were: an open licence, readable SystemVerilog that both Vivado and Cadence accept, active maintenance, verification maturity, small and simple, a clean memory interface, FPGA- and ASIC-friendly register-file options, and RISC-V toolchain support.

CV32E40P is capable but more complex than a supervisor needs. SCR1 is viable with a smaller ecosystem. PicoRV32 is compact, but development has wound down. NEORV32 is VHDL, and mixed-language complicates the Cadence flow. MicroBlaze is tied to the FPGA vendor and cannot move into an RTL-to-GDSII flow. Arm Cortex-M is licensed and closed. The decision: Ibex, small configuration.

### Slide 43 — Ibex: overview and specifications · **Dipiksha** · 35 s
**Key point:** small, open, well-documented RV32IMC core.

Ibex is a small, efficient 32-bit, in-order RISC-V core with a two-stage pipeline, written in SystemVerilog and heavily parametrisable. It originated as Zero-riscy in the PULP project, is now maintained by lowRISC, is production-quality, and is used in the OpenTitan project. The licence is Apache 2.0.

Decoding RV32IMC: RV32, 32-bit addresses and registers; I, the base integer set with 32 registers; M, multiply and divide; C, compressed 16-bit instructions for smaller code. It has machine-mode privilege, timer, external and software interrupts, fifteen fast interrupts, a non-maskable interrupt and simple request-grant memory interfaces. Published numbers for the small configuration: about 2.47 CoreMark per megahertz and about 24 kilo gate-equivalents, or 26 to 27 in open-tool synthesis with a latch register file.

→ **Kaushal**, the configuration.

### Slide 44 — The Ibex "small" configuration in detail · **Kaushal** · 40 s
**Key point:** every parameter is chosen for a supervisor role.

Thank you. Reading down the table: ISA RV32IMC, enough for firmware, with compressed code saving ROM. Two pipeline stages: simple and easy to reason about. The multiplier is the fast type with a three-cycle multiply; since the PID runs in hardware we do not need a single-cycle one. The instruction cache is off, giving predictable timing and less area.

The register file is flip-flop based in the named configuration, with FPGA and latch variants available. We use the flip-flop or FPGA version on the Arty and will evaluate the latch version for layout. Extras like PMP and bit-manipulation are off; a supervisor does not need them. Performance is about 2.47 CoreMark per megahertz, about 120 at 50 megahertz, plenty for configuration and monitoring, and the area is 24 to 27 kilo gate-equivalents.

For comparison, micro is about 0.9 CoreMark per megahertz and 15 kGE, and maxperf about 3.13 and 30 kGE. Small is the balanced middle. We pin one release and copy the parameter set from Ibex's own configuration file.

### Slide 45 — Ibex architecture and block diagram · **Kaushal** · 35 s
**Key point:** two stages, three interfaces.

`[point: outer to inner]` ibex_top contains ibex_core. The fetch stage, with the instruction interface, program counter, prefetch buffer and compressed-instruction expander, feeds the decode-and-execute stage: decoder, controller, operand muxes with forwarding, ALU, multiplier and divider, and the load-store unit. The 32-entry register file sits beside it, and the CSR block holds machine-mode status, interrupt enable and pending, the trap vector and counters.

Three interfaces leave the core: the instruction port to ROM, the data port to the bus, and the interrupt inputs.

→ **Vedam**, the block descriptions.

### Slide 46 — Ibex architecture (text) · **Vedam** · 30 s
**Key point:** what each block does, in one line.

In words: the fetch stage has the program counter, the prefetch buffer or FIFO and the expander, and it fetches ahead. The decode-and-execute stage has the decoder, which turns bits into control signals, the controller, which handles stalls, flushes and exceptions, operand muxes and forwarding, the ALU for add, shift, logic and compare, the multiplier and divider, and the load-store unit.

Decode and execute share one stage, and results write back to the register file. The load-store unit is the only way the CPU reaches memory and our hardware registers. The CSRs handle interrupts, traps and counters, and the interrupt inputs enter there.

→ **Kaushal**, how it runs.

### Slide 47 — How Ibex executes and connects to our SoC · **Kaushal** · 40 s
**Key point:** peripherals look like memory: a store becomes a register write.

The instruction path: the program counter sends an address on the instruction port, ROM returns the instruction, and it flows through fetch, decode-execute and write-back. Boot starts at the reset vector, 0x80, in ROM.

The key idea is memory-mapped I/O: our hardware registers look like memory. `[point: steps 01–04]` To set the PID gains, the firmware stores Kp, Ki and Kd to the PID bank address. The load-store unit raises a data request. The bus decoder selects the PID bank. The value lands in the register, and the hardware PID uses it on the next sample.

The handshake: request, grant in the same cycle, response valid next cycle. Simple ALU operations take about one cycle, a multiply three. The timer interrupt, about every 100 milliseconds, and the fault interrupt go to Ibex's interrupt inputs, and the core jumps through the vector table at the base address.

→ **Vedam**, the firmware.

### Slide 48 — Firmware and boot sequence · **Vedam** · 30 s
**Key point:** boot, check, configure, calibrate, arm, supervise.

At reset, startup code sets the stack, copies initialised data and clears zeroed data. Then main reads all six bank IDs and compares them with the expected values. It configures the timer and I-squared-C and waits for the sensor to initialise, starts gyro calibration and waits for it, and loads Kp, Ki, Kd, setpoint and limits, with the output limit starting low. It then sets the safety thresholds, enables the watchdog and arms. Finally it loops: kick the watchdog, log telemetry, handle interrupts and apply the re-arm policy after a fault.

The build flow: RISC-V GCC for rv32imc produces a binary, then a ROM initialisation file loaded into the FPGA. The bring-up ladder: read IDs, RAM test, LED, timer interrupt, raw IMU registers, then the full boot.

---

# PART E — Applications and scope  (≈ 1.2 min)

### Slide 49 — Part E divider · **Jaydev** · 3 s
Part E: applications. `[click]`

### Slide 50 — Where this ECU can be used · **Jaydev** · 45 s
**Key point:** direct target is balancing platforms; the architecture applies much more widely.

Where can this ECU be used? The direct target is self-balancing and inverted-pendulum platforms: two-wheeled balancing robots, mobility-scale prototypes and control-teaching rigs.

The same fixed-latency path from sensor to actuator matters for bipedal and legged robots, where posture and balance loops need it. Our ECU is a building block there, not a full gait controller. For autonomous rovers and mobile robots: wheel-motor control, chassis stabilisation and fault-safe motor shutdown, with the supervisory CPU handling mission logic.

In automotive and industrial control units: body-class, chassis-class and motor-control functions, where a hardware loop plus a supervisory CPU mirrors current ECU architectures. Drones and camera gimbals need attitude stabilisation. And in education and research it is an open, inspectable reference for ECU and SoC design. Our demonstrator is the balancing robot; the others show where the architecture applies.

### Slide 51 — Adapting the ECU (future scope) · **Jaydev** · 25 s
**Key point:** register-configured, so growth is mostly firmware or small blocks.

Because everything is register-configured, adapting the ECU is mostly firmware or small-block changes. Other sensors: SPI IMUs, wheel encoders, distance sensors. More control channels: replicate the PID block, for example one per joint or axis. Outer loops: speed or position control in firmware on top of the balance loop. Communication: UART or CAN for commands and logging. Better estimation: a Kalman filter block. And other motors: different driver stages behind the same motor interface.

---

# PART F — Hardware and tools  (≈ 1.7 min)

### Slide 52 — Part F divider · **Jaydev** · 3 s
Part F: hardware and tools. `[click]`

### Slide 53 — Hardware setup · **Jaydev** · 30 s
**Key point:** simple, staged bring-up that protects the hardware.

`[point: diagram]` A PC running Vivado connects by USB-JTAG to the Arty A7-100T FPGA board. The MPU-6050 breakout connects over I-squared-C, SCL and SDA at 3.3 volts, through a Pmod header. Two BTS7960 modules receive PWM and enable signals from the FPGA, and each drives one DC motor. A separate motor battery powers the motors, with a common ground. Switches and LEDs give us an arm switch, an emergency-stop button and status LEDs.

Bring-up order: logic and waveforms only, then motors on a stand with the wheels off the ground, then the robot on the floor.

### Slide 54 — Hardware specifications · **Jaydev** · 30 s
**Key point:** small design, comfortable device, board-agnostic.

The Arty A7-100T has a Xilinx XC7A100T with 101,440 logic cells, 15,850 slices, 4,860 kilobits of block RAM, 240 DSP slices, four Pmod connectors plus an Arduino-style header, 256 megabytes of DDR3L, 16 megabytes of Quad-SPI flash, USB-JTAG, and power from USB or 7 to 15 volts. It is supported by Vivado WebPACK.

The MPU-6050: three-axis accelerometer plus three-axis gyroscope, 16-bit ADCs, I-squared-C up to 400 kilohertz, programmable ranges, where we use plus or minus 2 g and 250 degrees per second, and an on-chip low-pass filter. Two BTS7960 modules: PWM up to 25 kilohertz, 5.5 to 27.5 volts, about 43 amps typical limit. Motor, chassis and battery ratings are to be finalised. Our design is small relative to the device, and we will report the actual utilisation after implementation. Other boards can be used: only pin constraints and the clock source change.

### Slide 55 — Software and EDA tools · **Jaydev** · 30 s
**Key point:** one toolchain from Python model to GDSII.

Tools across the whole journey. RTL entry and simulation: Xilinx Vivado with xsim. FPGA synthesis, implementation and bitstream: Vivado for Artix-7. On-chip debug: the Vivado ILA and VIO, plus a logic analyser and an oscilloscope. Clock generation: the Clocking Wizard. Reference models and plots: Python. Firmware: the RISC-V GNU toolchain. Code quality: Verilator lint and Git with pull-request reviews.

For the physical-design phase: Cadence Genus for logic synthesis and Cadence Innovus for place and route, plus other Cadence checks as available in the lab. The strip at the top shows the journey: Python model, Vivado simulation, Vivado FPGA, Genus, Innovus, GDSII.

---

# PART G — Plan, verification and wrap-up  (≈ 2.8 min)

### Slide 56 — Part G divider · **Vedam** · 3 s
Part G: our plan and verification. `[click]`

### Slide 57 — Development workflow · **Vedam** · 30 s
**Key point:** gated: nothing advances until the current stage passes.

Our workflow is gated, and every block follows the same path. One: code it against the frozen interface. Two: simulate and verify it alone, with a self-checking testbench and a golden model. Three: FPGA-test it alone, in typical and extreme conditions. Four: combine blocks one by one, simulating each combination and then FPGA-testing it. Five: the full ECU, simulate, verify, FPGA test. Six: only then move to RTL-to-GDSII.

The rule: nothing moves to the next stage until it has passed the current one. The CPU track runs alongside all stages until it is stable.

→ **Dipiksha**, verification.

### Slide 58 — Verification strategy: simulation · **Dipiksha** · 35 s
**Key point:** four levels, from block to CPU-in-the-loop.

Thank you, Vedam. Four levels. Level 1, blocks: a self-checking testbench per block, directed and random vectors, compared with a Python model. Level 2, pairs: adjacent blocks connected, I-squared-C to pipeline, pipeline to PID, PID to PWM. Level 3, the full datapath: a behavioural MPU-6050 model and the whole chain through PWM, with a simple pendulum model closing the loop. Level 4, with the CPU: Ibex running real firmware through the real bus.

Built-in checks: assertions, for example never both PWM outputs high, plus reset behaviour, boundary values, saturation and injected errors like no-acknowledge, timeout and bad address. Hygiene: lint with zero unexplained warnings, a regression script and logged results per block.

→ **Jaydev**, the FPGA plan.

### Slide 59 — FPGA test plan · **Jaydev** · 35 s
**Key point:** four stages, three test classes, defined pass criteria.

On the FPGA there are four stages. A: each block alone on the board with test fixtures and the ILA or VIO. B: blocks combined one by one, I-squared-C plus pipeline, then PID, then PWM, then safety. C: the full hardware loop with no CPU and the robot on a stand. D: the full ECU with CPU and firmware.

Three test classes. Typical operation: normal tilt and normal gains. Extreme cases: maximum and minimum inputs, saturation, noisy readings, different I-squared-C speeds, back-to-back events, reset during operation, the power-up sequence and a long-run soak. Safety and faults: every fault alone and combined, glitch rejection, emergency stop, watchdog, re-arm and unplugging the sensor. Pass criteria and logs are defined per test so nothing stays half-tested.

→ **Vedam**, the layout flow.

### Slide 60 — RTL-to-GDSII flow (Cadence) · **Vedam** · 30 s
**Key point:** we design for the flow from day one.

The RTL-to-GDSII flow with Cadence. First, freeze the RTL, lint it and define the constraints, the clock and the input-output timing. Genus converts RTL to a gate-level netlist with area and timing reports, and we simulate the netlist. Innovus handles floorplanning, placement, clock-tree synthesis and routing. Then final timing and power analysis, layout design-rule and connectivity checks, and export of the GDSII layout and reports.

We prepare from day one: a single clock, a fully synchronous design, no latches, except an evaluated register-file option, no FPGA primitives inside the RTL, and parameterised memories. Deferred to this phase: memory implementation, target frequency and constraint tuning.

---

# PART H — Timeline, team and conclusion  (≈ 3 min)

### Slide 61 — Part H divider · **Vedam** · 3 s
Part H: timeline and responsibilities. `[click]`

### Slide 62 — Timeline (tentative and flexible) · **Kaushal** · 30 s
**Key point:** gated phases; dates move if results demand it.

The timeline is tentative and flexible; each phase starts only when the previous gate is met. Phase one, October to November 2026: each block is coded and verified alone, then combined one by one and simulated together, with the real-time datapath RTL ready by the end of November. The CPU track runs in parallel throughout, covering Ibex integration, the bus and the firmware, until it is stable.

Phase two, FPGA testing, from November to the end of January or early February 2027: blocks alone, combined, then the full ECU, including safety and fault cases, with lighter work during the December exams. Phase three, RTL-to-GDSII, February to May 2027, with the target of completing it by May. The gates are: RTL ready, FPGA validated, layout done.

### Slide 63 — Team and responsibilities · **All** · 40 s
**Key point:** clear ownership; Kaushal covers Jatin.

**Kaushal:** I handle the I-squared-C subsystem, the MPU-6050 controller and the CPU simulation harness, and today I am also covering Jatin's parts. Jatin is our system architect and integration lead, responsible for the hardware PID, the Ibex integration and the firmware.
**Dipiksha:** I am responsible for the timer and control scheduler, and the sensor pipeline: measurement, calibration, angle conversion, filter and error calculation.
**Vedam:** I handle the ROM and RAM, the bus interconnect, clock and reset, the safety and fault monitor, and the firmware-to-ROM flow.
**Jaydev:** I handle the PWM generator, the motor interface, the FPGA board wrapper and motor bring-up.
**Kaushal:** Our working method: a shared interface contract, parallel block development, Git pull-request reviews and weekly checkpoints.

### Slide 64 — Risks and mitigation · **Jaydev** · 30 s
**Key point:** every risk has a plan; the hardware loop does not depend on the CPU.

We have planned for risks. If the schedule slips, the plan is gated, essentials come first, and optional features such as the complementary filter can be deferred. If CPU integration takes longer, Ibex is a proven core with a reference system, and the hardware loop runs and is tested without it. If sensor noise or lag hurts balancing, we have selectable filter lengths, tuning registers and the complementary option. For tuning difficulty, we tune on a stand with low output limits and log every run. For safety bugs, an independent monitor, exhaustive fault tests and peer review. For interface mismatches, a frozen contract and pair-integration tests. And for memory and area in the layout flow, small memories and documented decisions.

→ **Kaushal**, the conclusion.

### Slide 65 — Expected outcomes and conclusion · **Kaushal** · 40 s
**Key point:** a transparent reference ECU: fast where it must be, flexible where it can be.

Our expected outcomes, as targets: a verified, documented library of ECU blocks and a complete SoC design; an FPGA demonstration of the hardware control loop on a two-wheeled robot, with measured loop timing, latency and fault-response numbers; layout-flow results and reports; and open documentation that others can learn from.

In summary: balance control is a hardware pipeline, a small RISC-V CPU configures and supervises, and safety is independent of software. Ibex small gives us an open, compact and well-documented supervisor. And verification is staged, block, combination and full ECU, in simulation and on FPGA before any layout work. The idea we want to demonstrate is a transparent reference ECU that is fast where it must be fast and flexible where it can be.

### Slide 66 — References · **Kaushal** · 3 s
Our references are listed here for your convenience. `[click]`

### Slide 67 — Thank you · **Kaushal** · 10 s
Thank you, ma'am and sir. We would be happy to take your questions. If any are about Jatin's blocks that need more detail, we will note them and he will follow up.

---

## 5. Timing, tracks and recovery

**Time by part (nominal):** A 2 min · B 5.5 · C 11.5 · D 4.5 · E 1.2 · F 1.7 · G 2.8 · H 3 → **≈ 29–30 min**.

**20-minute fast track (keep order, skip or flash):**
- Skip: 2, 6, 16, 40, 49, 52, 56, 61 (dividers: just say the part name), 66.
- Merge/speed up: 18, 20, 24 (read only the key point), 34 (say "see previous slide"), 46, 54.
- Compress: 12 and 13 into one 40-second statement; 50 to three applications.
- Keep full: 4, 14, 17, 25, 29, 33, 35, 44, 47, 62, 65.

**If the projector fails:** use the block diagram (slide 17) from a printout and the Key-point lines only.

**If Jatin's parts get a deep question:** Kaushal answers; for a detail he does not know, say: "That is in Jatin's block; we will confirm with him and send you the exact answer."

## 6. Four fixes to say correctly (the slides are slightly looser)

1. **Slide 8:** "under 5 µs" is our logic. The PWM applies a new duty at the next period boundary, up to 50 µs later. Say "well under 5 µs for our logic".
2. **Slide 24:** say "a constant gyro offset behaves like a false rotation; it grows into an angle error in any filter that integrates the gyro".
3. **Slide 34:** say the recovery is "clear flags, condition gone, arm request low then high", as in the script.
4. **Slide 35:** say "0.6 radians, about 34 degrees". The sensor reading is closer to the sine of the angle, so the true trip angle is slightly higher, which is also fine if asked.
