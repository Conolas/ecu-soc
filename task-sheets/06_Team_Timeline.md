# ECU SoC — Team Timeline (internal target schedule)

Companion to `00_ECU_Interface_Contract_v1.0.md` and the five member sheets. All dates below are **internal targets**. Weeks run Monday → Sunday. The check for each week happens on the **Sunday**: your PR merged, your `TB_PASS` log posted, and your status message sent to Conolas.

Ownership reminder: `bus_interconnect` is Vedam's (first RTL in W2, all 7 test vectors in W3). Kaushal reviews it and his `tb_cpu_bus` harness is its acceptance test in W4.

Assumption: about 10–12 focused hours per person per week. If that is unrealistic for you, say so in Week 1, not in Week 4.

---

## 1. The big picture

| Phase | Dates | Goal |
|---|---|---|
| **RTL** | now → Sat 31 Oct | every block written, tested in simulation, integrated, **frozen** |
| **FPGA** | Mon 2 Nov → Sun 29 Nov | Wing A running the robot, then Ibex + firmware closing the loop |
| **Exams** | Tue 1 Dec → 31 Dec | no RTL changes; light reading only |
| **RTL → GDSII** | Mon 4 Jan → Sun 28 Feb | Genus synthesis, gate-level sim, Innovus, signoff checks |

There is no slack in this plan on purpose. Each week has exactly one job. If a week is missed, it is recovered the next week by working harder, not by moving the deadline.

### Team gates

| Date (Sunday unless noted) | Gate | Exit test |
|---|---|---|
| **Sun 4 Oct** | **G0 — Skeleton**: every module exists with frozen ports, lint clean, merged | `ecu_soc_top` elaborates |
| **Sun 18 Oct** | **G1 — Blocks done**: real logic + self-checking TB for every block | `TB_PASS` in every PR |
| **Sun 25 Oct** | **G2 — Pairs done**: all five pair-integration tests pass | Contract §8.1 |
| **Sat 31 Oct** | **G3 — RTL FREEZE v1.0**: full-system simulation passes (`HW_ONLY=1` and `HW_ONLY=0`); only bug-fix PRs after this | tag `v1.0-rtl` |
| **Sun 15 Nov** | **G4 — Wing A on FPGA**: robot on a stand, wheels react to tilt, E-stop works | demo video |
| **Sun 22 Nov** | **G5 — CPU on FPGA**: firmware boots, reads all IDs, configures the loop | demo video |
| **Sun 29 Nov** | **G6 — FPGA validated**: balancing attempts recorded, safety tests logged | tag `v1.0-fpga` |
| **Sun 28 Feb** | **G7 — GDSII** | signoff report |

---

## 2. Week calendar

| Wk | Dates | Theme |
|---|---|---|
| W1 | 28 Sep – 4 Oct | Skeleton: frozen ports, shells, tools |
| W2 | 5 – 11 Oct | First half of the real logic |
| W3 | 12 – 18 Oct | Second half + register banks → **G1** |
| W4 | 19 – 25 Oct | Pair integration + CPU harness → **G2** |
| W5 | 26 Oct – 1 Nov | Full-system sim, lint, **RTL freeze (31 Oct)** |
| W6 | 2 – 8 Nov | FPGA bring-up, block by block |
| W7 | 9 – 15 Nov | Wing A closed loop, tuning → **G4** |
| W8 | 16 – 22 Nov | Ibex + firmware on FPGA → **G5** |
| W9 | 23 – 29 Nov | Balancing runs, safety report, docs → **G6** |
| — | 1 – 31 Dec | Exams |
| G1–G8 | 4 Jan – 28 Feb | RTL → GDSII (Section 8) |

Conolas is remote until about the end of October (adjust once his return date is fixed); Kaushal runs the on-site day-to-day. Public holidays, festivals and internal assessments are not in this table. If you know one falls in a week, tell the group at the Monday stand-up and swap work between weeks instead of dropping it.

---

## 3. Rules that apply to every week

1. Sunday check = PR merged + `TB_PASS` log + one-paragraph status to Conolas (done / blocked / next).
2. Two days of silence = Conolas or Kaushal messages you. Being stuck is fine; being stuck quietly is not.
3. Blocked for more than a day: post module + commit + waveform screenshot (Contract §11).
4. Slipping a gate by more than 2 days: Kaushal and Conolas re-split work on Monday. Ports never change to catch up.
5. After G3 (31 Oct) no new features. Only bug fixes, through PRs.
6. Review turnaround: 24 hours.

---

## 4. Conolas — `hw_pid_accel`, `cpu_subsystem`, firmware, `ecu_soc_top`

| Week | Blocks / sub-blocks | Done when (Sunday) |
|---|---|---|
| **W1** (→ 4 Oct) | Contract sign-off (Section 12 assumptions). `ecu_soc_top` skeleton with all shells, `HW_ONLY` parameter, `make lint` script, repo + branch rules. Ibex Simple System running with Kaushal. RISC-V toolchain installed | shells of all 13 modules merged; lint passes; everyone has pulled |
| **W2** (5–11 Oct) | `hw_pid_accel`: PID register bank; shared-multiplier FSM with P, I, D terms; `model/pid.py`; firmware skeleton (`startup.S`, `link.ld`, `ecu_regs.h`) | test vectors 1–4 pass; firmware skeleton compiles |
| **W3** (12–18 Oct) | `hw_pid_accel` completion: anti-windup (both rules), `run_i` behaviour, `D_SRC`, saturation flag; random TB vs golden model. `cpu_subsystem` wrapper with `small` config copied from Ibex, tie-offs | vectors 1–7 pass; random TB has zero diffs; PID PR merged (**G1**) |
| **W4** (19–25 Oct) | Closed-loop TB with a simple pendulum model; pair tests with Dipiksha (pipeline → PID) and Jaydev (PID → PWM); CPU running test firmware T0–T2 in Kaushal's harness | both pair tests pass (**G2**); T0–T2 pass in simulation |
| **W5** (26 Oct – 1 Nov) | Firmware `main.c` boot sequence and T3–T5 in simulation; full-system sim in both modes; final review of every PR; FPGA build with timing report; freeze | tag `v1.0-rtl` on **Sat 31 Oct** (**G3**) |
| **W6** (2–8 Nov) | PID on the board with ILA; support each member's bring-up; prepare tuning log sheet | PID outputs seen on ILA for a hand-tilted IMU |
| **W7** (9–15 Nov) | Wing A tuning on the stand (recipe in your sheet: OUT_LIMIT low, Kp → Kd → Ki) | tuned gains recorded; wheels react correctly (**G4**) |
| **W8** (16–22 Nov) | `cpu_subsystem` on the real bus on FPGA; firmware T0–T5; firmware configures every register and the loop still runs | T5 passes on the board (**G5**) |
| **W9** (23–29 Nov) | Balancing runs, raise `OUT_LIMIT` step by step; collect all logs; write the results page | `v1.0-fpga` tag (**G6**) |
| **Dec** | Exams. Optional reading only: Genus/Innovus flow documents (≤ 2 h/week) | — |
| **Jan–Feb** | Top-level SDC, Innovus floorplan/place/CTS/route, signoff (Section 8) | — |

---

## 5. Kaushal — `i2c_sensor_subsystem`, Ibex harness, deputy lead

| Week | Blocks / sub-blocks | Done when (Sunday) |
|---|---|---|
| **W1** | I2C shell with frozen ports merged; `tb/mpu6050_model.v` started; Ibex Simple System hello-world running; **start reviewing PRs** | shells merged; hello-world visible in simulation |
| **W2** | `i2c_master` byte engine: START, STOP, write byte, read byte, ACK/NACK, repeated START, clock stretching, 2-FF synchronisers; TB | WHO_AM_I read returns `0x68` on the model |
| **W3** | `mpu6050_ctrl`: init sequence, 14-byte burst read, decode, error/timeout handling; `i2c_regs` | `control_tick`→`imu_valid` latency 380–440 µs (**G1**) |
| **W4** | Pair test with Dipiksha (tick → I2C model → pipeline). `tb_cpu_bus` with Vedam's ROM/RAM/bus and Conolas's test firmware | pair test passes (**G2**); firmware reads six IDs through Vedam's bus |
| **W5** | Final lint pass on every merged block; RTL-freeze checklist for all 13 modules; error-injection tests (NACK, stuck SDA) | all PRs merged; freeze checklist signed (**G3**) |
| **W6** | Real MPU-6050 on FPGA: ACK on every byte, SCL ≈ 390 kHz, raw values change when tilted; logic-analyser captures | verified with screenshots |
| **W7** | Wing A support; I2C robustness (unplug/replug the IMU, watch error counters and recovery); help Dipiksha bench-check signs | sensor unplug recovered cleanly (**G4**) |
| **W8** | CPU bring-up with Conolas: ILA on the bus, address decode checks on hardware | six IDs read by firmware on the board (**G5**) |
| **W9** | Long-run I2C soak test (≥ 30 min, zero unexplained errors); demo support | soak log in the repo (**G6**) |
| **Dec** | Exams. Optional: Genus reading, gate-level simulation setup notes | — |
| **Jan–Feb** | Genus synthesis of I2C; gate-level simulation harness (Section 8) | — |

---

## 6. Dipiksha — `timer_unit`, `sensor_pipeline`

| Week | Blocks / sub-blocks | Done when (Sunday) |
|---|---|---|
| **W1** | Shells for `timer_unit` and `sensor_pipeline` with frozen ports merged; `model/sensor_pipeline.py` skeleton; Q16.16 arithmetic understood | shells merged; Python helper functions for Q16.16 multiply/shift |
| **W2** | `timer_unit` RTL + TMR regs + TB (all six vectors). `angle_conv` and `error_calc` + TBs | timer + angle_conv + error_calc PRs opened, vectors pass |
| **W3** | `meas_capture` with calibration FSM (`SETTLE 64 → ACCUM 256`); `moving_avg_filter` ×2 (`sensor_filter`); SENS registers; random TB vs Python | zero diffs vs golden model; all B.4 vectors pass (**G1**) |
| **W4** | Pair tests: with Kaushal (tick → I2C model → your pipeline) and with Conolas (pipeline → PID). Latency ≤ 64 cycles checked. Start the complementary-filter Python model | both pair tests pass (**G2**) |
| **W5** | Complementary filter RTL (`FILT_MODE`) + TB + golden vectors; lint; README | stretch merged or explicitly deferred to Conolas by Wed 28 Oct; freeze (**G3**) |
| **W6** | Bench-verify on the real IMU: gyro bias small after calibration, angle ≈ 0 flat, ≈ 0.5 rad at 30°, signs of angle and rate agree; ILA screenshots | numbers recorded in the repo |
| **W7** | Filter tuning on the robot: compare `FILT_SHIFT` values, note oscillation vs lag; check timer overrun flag stays 0; try complementary mode | recommended filter setting written down (**G4**) |
| **W8** | Firmware reads your telemetry registers (angle, rate, error, calibration bias) and prints/logs them | telemetry readable by the CPU (**G5**) |
| **W9** | Final numbers: noise, drift, latency; one-page block report | report merged (**G6**) |
| **Dec** | Exams. Optional: Genus reading | — |
| **Jan–Feb** | Genus synthesis of timer + sensor pipeline (Section 8) | — |

---

## 7. Vedam — `rom_dp`, `ram_sp`, `clk_rst_gen`, `safety_fault_monitor`, `bus_interconnect`

| Week | Blocks / sub-blocks | Done when (Sunday) |
|---|---|---|
| **W1** | Shells for all five modules with frozen ports merged; **`clk_rst_gen` complete** with TB (bounce test, PLL-lock hold) | `clk_rst_gen` PR merged |
| **W2** | `rom_dp` (two read ports, `$readmemh` init) and `ram_sp` (byte enables) with TB vectors 1–7; `bus_interconnect` first RTL version (decoder, handshake, error responder) | memory PRs open, vectors pass; bus RTL pushed so Kaushal's harness can start |
| **W3** | `bus_interconnect` all 7 test vectors; `sw/bin2hex.py` + Makefile rule (`nop` word matches `objdump`); `safety_fault_monitor`: FSM (`DISARMED → ARMED → FAULT`), ESTOP synchroniser, TILT/SENSOR_TIMEOUT/I2C_ERR/PID_SAT/WATCHDOG detection, SAFE regs, `DBG_OUT` | bus vectors 1–7 pass (**G1** for memories, reset, bus); safety scenarios 1–8 pass (safety RTL first version) |
| **W4** | Safety scenarios 9–14; review by Kaushal, then Conolas; pair test of the bus with Kaushal's `tb_cpu_bus` harness; pair test with everyone (inject each fault in the loop) | all 14 scenarios pass; firmware reads six IDs through your bus; both reviews done (**G2**) |
| **W5** | Fix review comments; final TB pass; lint; README; short note on ASIC memory options (flop-based vs macro, sizes) | freeze (**G3**) |
| **W6** | FPGA: firmware `.hex` loads into ROM; arm switch, E-stop, LED fault flags on the real board; power-cycle leaves motors disabled | photos/video of each check |
| **W7** | Wing A safety validation: tilt cutoff by hand, unplug the IMU (SENSOR_TIMEOUT), E-stop in the loop, fault re-arm sequence | every test logged as pass/fail (**G4**) |
| **W8** | Watchdog with real firmware (`WD_EN`, `WD_KICK`); boot from ROM on the board; verify the watchdog trips when the CPU is halted | watchdog test logged (**G5**) |
| **W9** | Safety report: table of every scenario, result on hardware, evidence link | report merged (**G6**) |
| **Dec** | Exams. Optional: read about SRAM macros and memory compilers | — |
| **Jan–Feb** | ASIC memory strategy with Conolas; synthesis of memories, bus, safety monitor, clock/reset (Section 8) | — |

---

## 8. Jaydev — `actuation_subsystem`, `ecu_fpga_top`

| Week | Blocks / sub-blocks | Done when (Sunday) |
|---|---|---|
| **W1** | Shells for `actuation_subsystem` and `ecu_fpga_top` with frozen ports merged; pin table drafted for your board; build script skeleton | shells merged; pin table in `fpga/README` |
| **W2** | PWM counter core (period, double-buffered duty) + per-channel dead-time FSM; TB vectors 1, 2, 7, 13 with the `!(rpwm && lpwm)` assertion | those four vectors pass; assertion never fires |
| **W3** | Command shaping (steer, gains, clamp), slew limiter, MAX_DUTY, PWM regs, bench mux; all 13 vectors | all vectors pass (**G1**) |
| **W4** | Pair test with Conolas (PID → PWM). `ecu_fpga_top`: clock/PLL, 2-FF input synchronisers, open-drain I2C buffers, LEDs; constraints file with clock and pins | pair test passes (**G2**); full design builds for the board |
| **W5** | Phase 1 bitstream (`HW_ONLY=1`); PWM checked on the board with **motor supply disconnected** (bench steps 1–3); lint; README | bitstream + waveform photos; freeze (**G3**) |
| **W6** | Motor bench bring-up steps 1–7 (Sheet 05 §C): E-stop, 20 kHz, duty, both directions, `DIR_INV_L/R` decided | photo/video of steps 3 and 7 |
| **W7** | Closed loop on the stand with wheels off the ground; ramp `MAX_DUTY` up step by step; measure dead-time effect | robot reacts correctly to tilt (**G4**) |
| **W8** | Firmware writes `STEER`, `GAIN_L/R`, `MAX_DUTY`; wiring tidy-up (grounds, connectors, labels) | registers changed by firmware take effect on the wheels (**G5**) |
| **W9** | Wiring/pin documentation; balancing-run support; one-page block report | report merged (**G6**) |
| **Dec** | Exams. Optional: read about I/O pad rings | — |
| **Jan–Feb** | Genus synthesis of actuation; I/O pin planning for Innovus with Conolas (Section 8) | — |

---

## 9. Phase after FPGA: RTL → GDSII (4 Jan – 28 Feb)

| Wk | Dates | Everyone (own blocks) | Conolas + Kaushal (top level) |
|---|---|---|---|
| G1 | 4–10 Jan | Tool setup, libraries/PDK check, write per-block SDC (clock, I/O delays, false paths) | Check that `v1.0-fpga` still builds; decide target frequency |
| G2 | 11–17 Jan | First Genus synthesis of own blocks; fix latches, unintended logic, lint | Memory strategy (Vedam): flops vs macros, final sizes |
| G3 | 18–24 Jan | Timing to closure per block (setup slack ≥ 0), area/power reports | Top-level Genus synthesis; integrate memories |
| G4 | 25–31 Jan | Fix findings; re-run testbenches on the synthesised netlist | Gate-level simulation of the top (Kaushal leads) |
| G5 | 1–7 Feb | Support: fix any netlist-sim mismatches in own blocks | Innovus: floorplan, I/O placement, power plan |
| G6 | 8–14 Feb | Support: review timing/DRC reports for own blocks | Placement, CTS, first routing |
| G7 | 15–21 Feb | Fix reported violations in own RTL/SDC | Route, optimise, STA signoff, DRC/LVS |
| G8 | 22–28 Feb | Documentation for own blocks; results tables | Final GDSII, reports, presentation material |

Details will be refined at the start of January once we know the exact PDK and tool versions. The RTL you deliver in October is what goes into this flow. No latches, no vendor primitives and no `initial` logic now means no rework in January.

---

## 10. One-line summary per person

| Person | Must be done by 31 Oct | Must be done by 29 Nov |
|---|---|---|
| **Conolas** | `hw_pid_accel`, `cpu_subsystem`, firmware in sim, `ecu_soc_top`, freeze | tuned loop, CPU on FPGA, `v1.0-fpga` |
| **Kaushal** | I2C subsystem, Ibex harness, all reviews | real IMU verified, CPU on bus, soak test |
| **Dipiksha** | timer, full sensor pipeline (+ complementary filter) | angle/rate verified on hardware, filter settings chosen |
| **Vedam** | ROM/RAM, reset, `bus_interconnect`, safety monitor (all 14 scenarios) | safety validated on hardware, watchdog with firmware |
| **Jaydev** | PWM/actuation (13 vectors), FPGA top, bitstream | motors bench-verified, closed loop on stand |
