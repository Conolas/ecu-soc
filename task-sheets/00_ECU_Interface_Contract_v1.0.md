# ECU SoC — Interface Contract v1.0

**Everyone reads this first, then reads their own sheet.**
Project: `ecu_soc_top` — hardware ECU (SoC) for a self-balancing two-wheel robot.
Status: DRAFT until Conolas signs off Section 12 (assumptions). After sign-off it is FROZEN.

---

## 0. Rules of the game

1. This document is the single source of truth for module names, port names, widths, number formats, register offsets and addresses.
2. Inside your block you can do anything you like. **On the boundary of your block (ports, register offsets/bits, timing rules below) you change nothing** without an approved Change Request (CR).
3. CR process: open a GitHub issue titled `CR: <block> – <what> – <why>`. Conolas approves or rejects. If approved, this document's version is bumped and everyone is told.
4. If your block needs a signal that is not in this contract, that is also a CR. Do not add a private wire to a neighbour.
5. Build the boundary first (Week 1), the logic second. A block whose ports are correct but whose logic is stubbed is worth more in Week 1 than a half-working block with wrong ports.

---

## 1. All blocks and owners

| # | Module (frozen name) | What it is | Owner | Reviewer |
|---|---|---|---|---|
| 1 | `ecu_soc_top` | SoC top: instantiates and wires everything below | Conolas | Kaushal |
| 2 | `cpu_subsystem` | `ibex_top` + config + tie-offs | Conolas | Kaushal |
| 3 | Firmware (C) | startup, linker script, drivers, control app | Conolas | Kaushal |
| 4 | `hw_pid_accel` | hardware PID + its register bank | Conolas | Kaushal |
| 5 | `bus_interconnect` | Ibex ports → address decode → slaves | Vedam | **Kaushal AND Conolas** |
| 6 | `i2c_sensor_subsystem` | I2C master + MPU-6050 sequencer + I2C regs | Kaushal | Conolas |
| 7 | `timer_unit` | control-tick scheduler + timer regs | Dipiksha | Kaushal |
| 8 | `sensor_pipeline` | capture, calibration, angle conversion, filter, error calc + SENS regs | Dipiksha | Kaushal |
| 9 | `rom_dp`, `ram_sp` | firmware ROM (dual read), data RAM | Vedam | Kaushal |
| 10 | `clk_rst_gen` | reset synchroniser / power-on reset | Vedam | Kaushal |
| 11 | `safety_fault_monitor` | fault detection, arm/disarm, watchdog + SAFE regs | Vedam | **Kaushal AND Conolas** |
| 12 | `actuation_subsystem` | command shaping, PWM, dead-time, motor pins + PWM regs | Jaydev | Kaushal |
| 13 | `ecu_fpga_top` | board wrapper: pins, I/O buffers, clock, input sync | Jaydev | Kaushal |

External hardware (not RTL): MPU-6050 IMU, 2× BTS7960 H-bridge modules, 2× DC motors, FPGA board.

> **Ownership note (4 Oct 2026):** `bus_interconnect` (address decode, ROM/RAM/bank select lines, bus-error responses, window constants) belongs to **Vedam**, together with the memories behind it (`rom_dp`, `ram_sp`). Kaushal reviews it and his Ibex harness (`tb_cpu_bus`) is its acceptance test; Conolas reviews the CPU-facing handshake.

---

## 2. System dataflow

```
                        Wing A — real-time hardware loop (no CPU in this path)
 MPU-6050 ──I2C──► i2c_sensor_subsystem ──imu_*──► sensor_pipeline ──err,rate──► hw_pid_accel ──pwm_cmd──► actuation_subsystem ──► 2× BTS7960 ──► motors
    ▲                    ▲                             │ angle                        │ pid_sat                 ▲ pwm_enable                          │
    │              control_tick                        ▼                              ▼                         │                                     │
    │                timer_unit                  safety_fault_monitor ─────────────────────────────────────────┘                                     │
    └───────────────────────────────────────────  robot tilts, IMU sees it  ◄─────────────────────────────────────────────────────────────────────┘

                        Wing B — supervisory CPU plane
 ibex (cpu_subsystem) ◄──instr_*──► bus_interconnect ◄──► rom_dp (instr + data-read)
                      ◄──data_* ──►                   ◄──► ram_sp
                      ◄─irq_timer, irq_fault          ◄──► register banks: TMR, I2C, SENS, PID, PWM, SAFE
```

The CPU never sits in the real-time path. It configures registers, watches status, handles faults.

---

## 3. Global conventions (apply to every block)

| Topic | Rule |
|---|---|
| Clock | ONE clock, `clk`, 50 MHz. No second clock domain anywhere. SCL is generated with clock-enables, never used as a clock. |
| Reset | `rst_n`, active-low, **synchronous** in your blocks (`if (!rst_n)` inside `always @(posedge clk)`). Asynchronous assert / synchronous release is done only inside `clk_rst_gen`. |
| Language | Verilog-2001 (`.v`). Only `cpu_subsystem` may use SystemVerilog (Ibex is SV). Start every file with `` `default_nettype none `` and end with `` `default_nettype wire ``. |
| Synthesisable | No latches, no `#` delays, no `initial` for logic, no tri-states inside blocks, no negative-edge clocks. `$readmemh` allowed only in ROM/RAM. |
| Vendor primitives | Not allowed inside RTL blocks. Anything FPGA-specific (PLL, IOBUF) lives only in `ecu_fpga_top`. |
| Naming | `snake_case`. Inputs end `_i`, outputs end `_o`, active-low ends `_n`. Parameters UPPERCASE. One module per file, file name = module name. |
| Pulses | A "pulse" is exactly one `clk` cycle high. |
| Valid rule | Every data stage has a `*_valid` pulse. Data is valid in the cycle the pulse is high and **stays stable for at least 1 further cycle**. |
| Latency rule | No stage may take more than **64 clk cycles** from its input-valid pulse to its output-valid pulse (exception: the I2C subsystem, see timing budget). |
| Defaults | Every register and every flop has a defined reset value. Documented in your sheet. |
| Parameters | Enable-type register bits reset to parameter `DEF_EN` (default 0). `ecu_soc_top` has a parameter `HW_ONLY`; when 1 it passes `DEF_EN=1` down so Wing A runs with **no CPU** (Phase 1 FPGA test). Final SoC uses `HW_ONLY=0`. |
| Lint | Must pass Verilator `--lint-only -Wall` (free) or `xrun -hal` (lab) with zero warnings you cannot justify. |

### 3.1 Number formats

| Type | Format | Notes |
|---|---|---|
| IMU raw | signed 16-bit, two's complement | after init: accel ±2 g → **16384 LSB/g**; gyro ±250 °/s → **131 LSB/(°/s)** |
| Angle | **Q16.16 signed 32-bit, radians** | value = integer / 65536. `1.0 rad = 32'h0001_0000`. Positive = leaning forward |
| Rate | Q16.16 signed 32-bit, rad/s | positive = angle increasing |
| PID gains, limits, commands | Q16.16 signed 32-bit | |
| Motor command `pwm_cmd` | Q16.16 signed, normalised **−1.0 … +1.0** (`−65536 … +65536`) | +1.0 = full drive forward |
| Multiply | `(a * b) >>> 16` with a **64-bit signed** intermediate | arithmetic shift = floor. Python `>>` matches this exactly, so Python golden models will match RTL bit-for-bit |
| Saturation | Clamp, never wrap | |

Conversion constants used by `sensor_pipeline` (multiplier-free):

- `angle_q16 = accel_raw × 4` (small-angle: θ ≈ a/g; 65536/16384 = 4). Error ≈ 4 % at 0.5 rad, negligible near upright.
- `rate_q16 = (g<<3) + (g>>>1) + (g>>>2)` = 8.75 × gyro_raw (exact value is 8.731, error 0.2 %).

### 3.2 Timing budget

| Item | Value |
|---|---|
| Control rate | **≈512 Hz**. `TICK_PERIOD = 97656` clk cycles → Ts = 1/512 s (so `ω·Ts` is just `>>>9`, used by the optional complementary filter). |
| I2C | ≈390 kHz (`CLK_DIV=31`). A 14-byte burst read ≈ 0.40 ms |
| MPU-6050 config | `SMPLRT_DIV=0`, `DLPF_CFG=2` (≈94 Hz accel / 98 Hz gyro, ≈3 ms group delay), ±2 g, ±250 °/s |
| Budget per tick | 1.95 ms period − 0.40 ms I2C − <5 µs everything else ⇒ >1.5 ms margin |
| Dominant delay in the loop | the MPU's own low-pass filter (≈3 ms), not our RTL. Keep our moving-average small |

---

## 4. Memory map

| Region | Base | Size (window) | Owner |
|---|---|---|---|
| ROM (firmware) | `0x0000_0000` | 8 KB (`…_1FFF`) | Vedam |
| Peripheral: TMR | `0x1000_0000` | 4 KB | Dipiksha |
| Peripheral: I2C | `0x1000_1000` | 4 KB | Kaushal |
| Peripheral: SENS | `0x1000_2000` | 4 KB | Dipiksha |
| Peripheral: PID | `0x1000_3000` | 4 KB | Conolas |
| Peripheral: PWM | `0x1000_4000` | 4 KB | Jaydev |
| Peripheral: SAFE | `0x1000_5000` | 4 KB | Vedam |
| RAM | `0x2000_0000` | 4 KB (`…_0FFF`) | Vedam |

Anything else is **unmapped**: reads/writes must return a bus error and cause no side effect (Vedam).
Ibex: `boot_addr_i = 0x0000_0000` ⇒ reset vector is `0x0000_0080`; vector table occupies `0x00–0x7F`.
ROM/RAM sizes are `localparam`s in ONE place (`bus_interconnect`) plus the memory modules; they may shrink for the ASIC flow (Phase 8 decision).

---

## 5. Slave-bus protocol (used by every register bank and RAM/ROM data port)

Every slave has exactly these ports (names fixed; peripheral address width 12, memory widths per module):

| Port | Dir (at slave) | Width | Meaning |
|---|---|---|---|
| `s_sel_i` | in | 1 | Access in this cycle. Asserted for exactly **one** cycle per access |
| `s_we_i` | in | 1 | 1 = write, 0 = read |
| `s_be_i` | in | 4 | Byte enables. Register banks may ignore them (firmware always uses 32-bit accesses). **RAM must honour them** |
| `s_addr_i` | in | 12 | Byte offset inside the region. Registers are word-aligned: use `s_addr_i[11:2]` |
| `s_wdata_i` | in | 32 | Write data |
| `s_rdata_o` | out | 32 | Read data, **registered**: valid in the cycle *after* `s_sel_i` |

Rules:
- Zero wait states. No `ready` signal. Every slave answers every access.
- Write takes effect on the clock edge ending the select cycle.
- Read data is registered: `always @(posedge clk) if (s_sel_i && !s_we_i) s_rdata_o <= mux(s_addr_i);`
- Read of an undefined offset returns 0. Write to an undefined or read-only offset is ignored.

Ibex side (handled by `bus_interconnect`): `gnt` is given in the **same cycle** as `req`; `rvalid` comes **one cycle later**, for reads **and writes**. Unmapped address ⇒ `rvalid` with `err=1`.

### 5.1 Register bank conventions

- Offset `0x00` is always `ID` (read-only constant). Firmware reads all IDs first to prove the bus works.
- Reserved bits read 0, ignore writes.
- `W1C` = write-1-to-clear. `SC` = self-clearing command bit (reads 0).
- All registers reset to the values in the sheets.

| Bank | ID value (ASCII + version 01) |
|---|---|
| TMR | `0x5449_4D01` |
| I2C | `0x4932_4301` |
| SENS | `0x5345_4E01` |
| PID | `0x5049_4401` |
| PWM | `0x5057_4D01` |
| SAFE | `0x5341_4601` |

---

## 6. Master signal list (the "netlist" of `ecu_soc_top`)

| Signal | Width | Format / meaning | Driver → Receiver(s) |
|---|---|---|---|
| `clk` | 1 | 50 MHz | `clk_rst_gen` → all |
| `rst_n` | 1 | active-low, synchronous release | `clk_rst_gen` → all |
| `control_tick` | 1 | pulse @ ≈512 Hz | `timer_unit` → `i2c_sensor_subsystem`, `safety_fault_monitor` |
| `imu_valid` | 1 | pulse: a full 14-byte sample was read | `i2c_sensor_subsystem` → `sensor_pipeline`, `safety_fault_monitor` |
| `imu_ax` `imu_ay` `imu_az` | 16 each | signed raw, stable while/after `imu_valid` | `i2c_sensor_subsystem` → `sensor_pipeline` |
| `imu_gx` `imu_gy` `imu_gz` | 16 each | signed raw | `i2c_sensor_subsystem` → `sensor_pipeline` |
| `imu_busy` | 1 | level: high from tick until `imu_valid` or `imu_err` | `i2c_sensor_subsystem` → `timer_unit` (overrun detect) |
| `imu_err` | 1 | pulse: transaction failed (NACK/timeout) | `i2c_sensor_subsystem` → `safety_fault_monitor` |
| `imu_init_done` | 1 | level: MPU-6050 configured OK | `i2c_sensor_subsystem` → `sensor_pipeline`, `safety_fault_monitor` |
| `setpoint` | 32 | Q16.16 rad | `hw_pid_accel` (PID regs) → `sensor_pipeline` |
| `pipe_valid` | 1 | pulse: `angle`, `err`, `rate` valid together | `sensor_pipeline` → `hw_pid_accel`, `safety_fault_monitor` |
| `angle` | 32 | Q16.16 rad, filtered, trimmed | `sensor_pipeline` → `safety_fault_monitor` |
| `err` | 32 | Q16.16, `setpoint − angle` | `sensor_pipeline` → `hw_pid_accel` |
| `rate` | 32 | Q16.16 rad/s, filtered, bias-corrected | `sensor_pipeline` → `hw_pid_accel` |
| `calib_done` | 1 | level: gyro bias captured | `sensor_pipeline` → `safety_fault_monitor` |
| `pwm_cmd_valid` | 1 | pulse | `hw_pid_accel` → `actuation_subsystem` |
| `pwm_cmd` | 32 | Q16.16 in [−1,+1] | `hw_pid_accel` → `actuation_subsystem` |
| `pid_sat` | 1 | level: last output was clamped | `hw_pid_accel` → `safety_fault_monitor` |
| `pwm_enable` | 1 | level: motors allowed | `safety_fault_monitor` → `hw_pid_accel` (`run_i`), `actuation_subsystem` |
| `irq_timer` | 1 | level, W1C in TMR | `timer_unit` → `cpu_subsystem` |
| `irq_fault` | 1 | level, cleared via SAFE regs | `safety_fault_monitor` → `cpu_subsystem` |
| `dbg[7:0]` | 8 | board LEDs | `safety_fault_monitor` → pins |
| `<bank>_sel/we/be/addr/wdata/rdata` | — | slave bus per bank (`tmr`, `i2c`, `sens`, `pid`, `pwm`, `saf`, `rom`, `ram`) | `bus_interconnect` ↔ banks |

### Top-level pins of `ecu_soc_top`

| Pin | Dir | Note |
|---|---|---|
| `clk_in`, `rst_n_in`, `pll_locked_i` | in | board clock/reset (tie `pll_locked_i=1` if no PLL) |
| `estop_n_i` | in | active-low hardware E-stop (button) |
| `arm_sw_i` | in | arm switch (Phase 1 only; tie 0 in final SoC) |
| `bench_en_i`, `bench_sel_i[1:0]` | in | open-loop motor bench test switches |
| `scl_i`, `sda_i` | in | I2C inputs |
| `scl_drive_low_o`, `sda_drive_low_o` | out | 1 = pull line low, 0 = release (open-drain) |
| `l_rpwm_o l_lpwm_o l_r_en_o l_l_en_o` | out | left BTS7960 |
| `r_rpwm_o r_lpwm_o r_r_en_o r_l_en_o` | out | right BTS7960 |
| `dbg_o[7:0]` | out | LEDs |

---

## 7. Repo layout and Git rules

```
ecu_soc_top/
  docs/      ← this contract + sheets
  rtl/{cpu,bus,mem,i2c,sensor,pid,actuation,safety,top}/
  tb/        ← one self-checking TB per module (tb_<module>.v) + models
  fpga/      ← ecu_fpga_top.v, constraints, scripts
  sw/        ← firmware, link.ld, include/ecu_regs.h, bin2hex.py
  model/     ← Python golden models
  vendor/ibex  ← git submodule, pinned to one commit
```

- Never push to `main`. Branch `feat/<module>`, open a PR.
- Every PR contains: RTL, testbench, simulation log ending in `TB_PASS <module>`, one waveform screenshot, and the checklist in Section 9.
- Review turnaround: **24 hours**. Kaushal reviews, Conolas reviews asynchronously and has the last word.
- Commit small and often (at least every 2 days). "It works on my laptop" without a commit does not exist.

---

## 8. Milestones and weekly rhythm

| Week | Milestone | Exit test |
|---|---|---|
| **W0** | Contract signed off | Conolas approves Section 12 |
| **W1** | **Skeleton (M0)**: every module exists with frozen ports, outputs tied to safe constants, lint clean, merged | `ecu_soc_top` elaborates and lints |
| **W2–3** | **Block-level (M1)**: real logic + self-checking TB per block | `TB_PASS` logs in every PR |
| **W4** | **Pair integration (M2)** in simulation | see 8.1 |
| **W5–6** | **Wing A on FPGA, no CPU (M3)**: `HW_ONLY=1`, robot on a stand: wheels react to tilt, E-stop kills them | demo video |
| **W7–8** | **Ibex + firmware (M4)**: CPU configures everything and the loop still runs; watchdog armed | demo video |
| **M3+** | RTL → GDSII (Genus/Innovus) | Phase 8 plan |

Rhythm: Monday 15-min stand-up (call). Friday: everyone posts a 1-minute waveform/video of the current state. Sunday: one-paragraph status to Conolas (done / blocked / next).

### 8.1 Pair-integration tests (Week 4)

| Pair | Test |
|---|---|
| Kaushal + Dipiksha | tick → I2C (MPU model) → `sensor_pipeline`: `angle` matches golden model |
| Dipiksha + Conolas | `sensor_pipeline` → `hw_pid_accel`: `pwm_cmd` matches golden model |
| Conolas + Jaydev | `hw_pid_accel` → `actuation_subsystem`: correct PWM duty and direction |
| Vedam + everyone | `safety_fault_monitor` in the loop: inject each fault, `pwm_enable` drops |
| Vedam + Kaushal | `bus_interconnect` + ROM/RAM driven by Kaushal's Ibex harness (`tb_cpu_bus`): read/write/byte-enable tests, six IDs read by firmware |

---

## 9. Definition of Done (every block)

- [ ] Ports and register map identical to this contract (Kaushal diffs them).
- [ ] Lint clean; no latches; no `#`; no vendor primitives.
- [ ] Self-checking TB prints `TB_PASS <module>`; covers every test vector in your sheet plus reset behaviour.
- [ ] Reset values documented and verified in the TB.
- [ ] Waveform screenshot of the main scenario in the PR.
- [ ] Short `README` in your rtl folder: what it does, parameters, known limits.
- [ ] Merged to `main` via PR.

---

## 10. General DOs and DON'Ts

**DO** freeze ports first · write the TB before/with the RTL · use `localparam` state names · keep FSMs small and readable · make one thing per always block · comment *why*, not *what* · ask early with a waveform.
**DON'T** add ports "just for debug" · use `initial` for logic · use blocking assignments in clocked blocks · share registers between two always blocks · rely on simulator-specific behaviour · edit another person's folder (open a PR/issue instead) · change a spec silently because it "seems better".

---

## 11. Asking for help (remote)

Send: (1) module + commit hash, (2) what you expected, (3) what happened, (4) a waveform screenshot with the relevant signals. Problems posted this way get answered in minutes; "it doesn't work" does not.

---

## 12. Assumptions Conolas must confirm in Week 0

| # | Assumption | Why it matters |
|---|---|---|
| A1 | 50 MHz clock (board osc, or MMCM in `ecu_fpga_top`) | all divider values |
| A2 | Control rate ≈512 Hz (`TICK_PERIOD=97656`) | timer default, complementary filter shift |
| A3 | Accel-only small-angle tilt + **gyro rate for the D term** (`D_SRC=1`) | PID and pipeline interface |
| A4 | Gyro bias auto-calibration at start (256 samples, robot still) | `calib_done`, arming rule |
| A5 | ROM 8 KB, RAM 4 KB | address decode; ASIC area |
| A6 | MPU-6050 at I2C address `0x68`, config values in Section 3.2 | I2C init sequence |
| A7 | Both motors driven by one balance command + steer + per-motor gain | actuation interface |
| A8 | Ibex interrupts: `irq_timer_i` ← timer, `irq_external_i` ← fault | firmware + wiring |
| A9 | FPGA board / voltage: 3.3 V I/O (board not yet fixed) | constraints, level shifting |

---
*Change log:* v1.0 — initial contract. v1.0 (3 Oct 2026, clarification) — `bus_interconnect` assigned to Kaushal. v1.0 (4 Oct 2026, ownership change) — `bus_interconnect` moved from Kaushal to Vedam. No port, address or format changes.
