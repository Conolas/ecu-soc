# Sheet 05 — Jaydev: `actuation_subsystem` and `ecu_fpga_top`

Read `00_ECU_Interface_Contract_v1.0.md` first.

**Role:** you turn the controller's decision into real motor motion, and you make the design run on the actual FPGA board. Your blocks are the last thing in the loop before the motors, so correctness and safe behaviour matter as much as functionality. Every number you need is below; nothing is left to interpretation.

| # | Deliverable | Done when |
|---|---|---|
| A | `actuation_subsystem` (command shaping, PWM, dead-time, motor pins, PWM regs) | all test vectors pass; PWM verified on a scope/logic analyser |
| B | `ecu_fpga_top` (board wrapper, I/O buffers, sync, constraints) | design builds and pins are correct |
| C | Motor bench bring-up procedure executed on hardware | motors spin in both directions safely from switches |

Suggested order: A in simulation → B (pin table early, since it takes board time) → C.

---

## A. `actuation_subsystem`

### A.1 Ports (frozen)

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | |
| slave bus `s_*` | | | PWM bank |
| `cmd_valid_i` | in | 1 | pulse: new command (≈512 Hz) |
| `cmd_i` | in | 32 | Q16.16 in [−1, +1]: balance command from PID |
| `pwm_enable_i` | in | 1 | from safety. 0 ⇒ everything off |
| `bench_en_i` | in | 1 | 1 = ignore `cmd_i`, use the bench command table |
| `bench_sel_i` | in | 2 | 00 → 0, 01 → +0.25, 10 → −0.25, 11 → +0.5 (Q16.16: 0, 16384, −16384, 32768) |
| `l_rpwm_o l_lpwm_o l_r_en_o l_l_en_o` | out | 1 each | left BTS7960 |
| `r_rpwm_o r_lpwm_o r_r_en_o r_l_en_o` | out | 1 each | right BTS7960 |
| `duty_l_o`, `duty_r_o` | out | 16 each | current duty counts (debug) |
| parameters | | | `DEF_EN=0`, `PERIOD_DEF=2500`, `DEADTIME_DEF=250` |

`bench_en_i` still passes through `pwm_enable_i`: the bench mode can never move motors while disarmed.

### A.2 Register map (base `0x1000_4000`)

| Off | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | `0x5057_4D01` | |
| 0x04 | CTRL | RW | b0=`DEF_EN`, b4=1 | b0 `EN`; b1 `SLEW_EN`; b2 `DIR_INV_L`; b3 `DIR_INV_R`; b4 `CLAMP_EN` (reset 1) |
| 0x08 | PERIOD | RW | 2500 | PWM period in clk cycles ⇒ 20 kHz. Takes effect at the period wrap |
| 0x0C | MAX_DUTY | RW | `0xE666` | Q0.16 max duty (0.9). **Keep low during first tests** |
| 0x10 | DEADTIME | RW | 250 | clk cycles both outputs low on a direction change (5 µs) |
| 0x14 | SLEW_STEP | RW | 6554 | max command change per update, Q16.16 (0.1) |
| 0x18 | STEER | RW | 0 | Q16.16: `left = cmd + steer`, `right = cmd − steer` |
| 0x1C | GAIN_L | RW | 65536 | Q16.16 left gain (1.0) |
| 0x20 | GAIN_R | RW | 65536 | right gain |
| 0x24 | STATUS | RO | 0 | b0 `ENABLED`, b1 `CLAMPED` (sticky W1C), b2 `IN_DEADTIME_L`, b3 `IN_DEADTIME_R` |
| 0x28 | DUTY_L | RO | 0 | current duty counts |
| 0x2C | DUTY_R | RO | 0 | |

### A.3 Architecture
```
cmd_i ─► [bench mux] ─► [steer & gain] ─► [clamp ±1.0] ─► [slew limiter] ─┬─► channel L: [abs→duty] [dir + dead-time FSM] [PWM counter] ─► l_rpwm / l_lpwm
                                                                          └─► channel R: (same)                                          ─► r_rpwm / r_lpwm
pwm_enable_i & EN ─► l_r_en, l_l_en, r_r_en, r_l_en   (and forces both PWM outputs low)
```

**Step by step (per `cmd_valid_i`):**
1. Select source: bench table if `bench_en_i`, else `cmd_i`.
2. `left_raw = cmd + steer`, `right_raw = cmd − steer`. Multiply by `GAIN_L`/`GAIN_R` (`(a*b)>>>16`). Clamp each to ±65536 (if `CLAMP_EN`; set STATUS `CLAMPED`).
3. Slew limiter (if `SLEW_EN`): output moves toward the target by at most `SLEW_STEP` per update. When `pwm_enable_i` rises, start from 0 (ramp from rest, never jump).
4. Per channel: `mag16 = min(|cmd|, 65535)`, then `mag16 = min(mag16, MAX_DUTY)`. `duty_counts = (mag16 × PERIOD) >> 16` (16×12-bit multiply, one DSP/multiplier is fine).
5. Direction: cmd > 0 ⇒ `RPWM = pwm`, `LPWM = 0`; cmd < 0 ⇒ `LPWM = pwm`, `RPWM = 0`; `DIR_INV_x` swaps them (decided on the bench by which way the wheel turns).
6. **Dead-time FSM per channel:** states `RUN_FWD`, `RUN_REV`, `DEAD`. If the new direction differs from the current one, go to `DEAD`: both PWM outputs low for `DEADTIME` cycles, then run in the new direction. **RPWM and LPWM must never be high at the same time**, in any state. This is a hard requirement (shoot-through protection).
7. PWM core: up-counter `0…PERIOD−1`; output high while `count < duty_counts`. **Duty and direction are latched at the period wrap** (double-buffered) so no glitches or runt pulses.
8. `R_EN`/`L_EN` (both halves) = `pwm_enable_i && EN`. When 0: both PWM outputs low and both enables low within 2 clk.

Latency: `cmd_valid_i` to the next period wrap: ≤ 1 PWM period (50 µs).

### A.4 Test vectors (all must pass)

| # | Setup | Input | Expected |
|---|---|---|---|
| 1 | PERIOD=2500, MAX_DUTY=`0xFFFF`, gains 1.0, steer 0 | cmd=+32768 (0.5) | both channels: `RPWM` high 1250 of every 2500 clk; `LPWM` = 0; `duty_*_o = 1250` |
| 2 | same | cmd=−16384 (−0.25) | `LPWM` high 625 of 2500; `RPWM`=0 |
| 3 | same | cmd=+131072 (2.0) | clamped to 1.0, then `mag16 = min(65536, 65535) = 65535` ⇒ duty = (65535·2500)>>16 = **2499**; `CLAMPED` set |
| 4 | MAX_DUTY=`0xE666` | cmd=+65536 | duty = 2249 (floor of 0.9·2500) |
| 5 | steer=6554 (0.1) | cmd=+32768 | left 39322 → duty 1500; right 26214 → duty 999 |
| 6 | `SLEW_EN`, `SLEW_STEP=6554` | cmd jumps 0 → +65536 | targets after each update: 6554, 13108, … reaches full in 10 updates |
| 7 | cmd +0.5 then −0.5 | | `RPWM` stops, both low ≥ `DEADTIME` cycles, then `LPWM` starts. **Assertion: `!(rpwm && lpwm)` at every clock, every channel, whole simulation** |
| 8 | `pwm_enable_i=0` while running | | all PWM and `*_EN` low within 2 clk |
| 9 | `pwm_enable_i` 0 → 1 with `SLEW_EN` | cmd=+1.0 | ramps from 0, no jump |
| 10 | change `PERIOD` mid-run | | current period completes, next uses new value; no runt pulse |
| 11 | `DIR_INV_L=1`, cmd=+0.5 | | left drives `LPWM` instead of `RPWM`; right unchanged |
| 12 | `bench_en_i=1`, `bench_sel_i=2'b11` | any `cmd_i` | behaves as cmd=+32768 |
| 13 | reset | | all outputs low, all enables low |

Measure in the TB: PWM period = 2500 clk exactly ⇒ 20 kHz.

---

## B. `ecu_fpga_top` (board wrapper)

### B.1 What it does
- Board clock → (if the board oscillator is not 50 MHz) an MMCM/PLL to exactly 50 MHz; `pll_locked` to `clk_rst_gen`.
- Synchronises **all** asynchronous board inputs with 2 flops (buttons, switches): `estop_n`, `arm_sw`, `bench_en`, `bench_sel`.
- I2C open-drain buffers, in the wrapper only:
  ```verilog
  assign scl_pad = scl_drive_low ? 1'b0 : 1'bz;   // external pull-up to 3.3 V
  assign sda_pad = sda_drive_low ? 1'b0 : 1'bz;
  // inputs: scl_i = scl_pad, sda_i = sda_pad
  ```
- Instantiates `ecu_soc_top` with `HW_ONLY` as a parameter (1 for Phase 1 bitstream).
- Drives LEDs from `dbg_o[7:0]`.

### B.2 Pin table (fill the "FPGA pin" column for your board; standard `LVCMOS33`)

| Signal | Dir | Board resource | FPGA pin |
|---|---|---|---|
| `clk_board` | in | oscillator | |
| `rst_n_in` | in | push-button | |
| `estop_n_i` | in | push-button / switch, **active-low** | |
| `arm_sw_i` | in | slide switch | |
| `bench_en_i` | in | slide switch | |
| `bench_sel_i[1:0]` | in | 2 slide switches | |
| `scl_pad`, `sda_pad` | inout | header pins → GY-521 | |
| `l_rpwm_o l_lpwm_o l_r_en_o l_l_en_o` | out | header → left BTS7960 | |
| `r_rpwm_o r_lpwm_o r_r_en_o r_l_en_o` | out | header → right BTS7960 | |
| `dbg_o[7:0]` | out | 8 LEDs | |

Also create the clock constraint (20 ns period on the 50 MHz clock) and I/O standards. Write a one-page `fpga/README` with the build command and the pin table. Do this **in Week 1–2**, before you need the board.

---

## C. Motor bench bring-up (hardware, do in this order — no skipping)

1. **Motor supply disconnected.** Power the FPGA only. Flash the Phase 1 bitstream.
2. Arm switch OFF: scope/logic-analyser on `l_rpwm_o`, `l_lpwm_o`, `*_en`: all low. ✔
3. Arm switch ON, `bench_en=1`, `bench_sel=01`: 20 kHz, ≈25 % duty on `RPWM`, `LPWM` low. Then `10`: swapped. Then `11`: ≈50 %. Check frequency and duty with the analyser.
4. Verify the 3.3 V logic level is accepted by your BTS7960 module (check its datasheet; if in doubt use a level shifter). Verify **common ground** between FPGA, module and battery.
5. Press E-stop: outputs fall immediately.
6. Only now connect the motor supply, **wheels off the ground**, `MAX_DUTY` set low (e.g. 0.2 via a bitstream parameter or, later, firmware).
7. `bench_sel` 01 / 10: wheel turns one way and the other. Set `DIR_INV_L`/`DIR_INV_R` so that positive command = wheel driving the robot forward.
8. Have a hard power switch within reach at all times.

Deliver a photo/video of steps 3 and 7 to the group.

---

## Your timeline

| Week | You |
|---|---|
| W1 | shells with frozen ports merged (`actuation_subsystem`, `ecu_fpga_top`); pin table drafted |
| W2 | `pwm_generator` core + dead-time FSM + TB (vectors 1, 2, 7, 13) |
| W3 | command shaping, slew, PWM regs, all 13 vectors; constraints file + FPGA build script |
| W4 | pair test with Conolas (PID → PWM) |
| W5 | bench bring-up steps 1–7 |
| W6 | help with Wing A closed-loop demo (wheels off the ground) |
| W7–8 | support CPU bring-up; `MAX_DUTY`/`STEER` from firmware |

## DOs / DON'Ts
**DO** put `assert(!(rpwm && lpwm))` in your TB · test with the motor supply disconnected first · keep the wheels off the ground for early tests · label every wire · check ground and voltage levels with a multimeter.
**DON'T** connect 5 V to FPGA pins · skip the dead-time · update duty in the middle of a period · power the motors before the outputs are verified · add ports to the actuation wrapper.
