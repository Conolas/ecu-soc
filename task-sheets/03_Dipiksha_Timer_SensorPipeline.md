# Sheet 03 — Dipiksha: `timer_unit` and `sensor_pipeline`

Read `00_ECU_Interface_Contract_v1.0.md` first.

**Role:** you own the heartbeat of the system (the timer that makes everything tick) and the whole signal-conditioning chain that turns raw IMU numbers into the clean `angle`, `rate` and `err` that the PID controller consumes. If your numbers are wrong, the robot falls over, so your blocks come with exact test vectors.

| # | Deliverable | Done when |
|---|---|---|
| A | `timer_unit` (+ TMR regs) | tick period exact; overrun and IRQ logic verified |
| B | `sensor_pipeline` (+ SENS regs) containing: `meas_capture`, `angle_conv`, `sensor_filter`, `error_calc` | matches Python golden model bit-for-bit |
| C | `model/sensor_pipeline.py` golden model | used to generate/check vectors |
| D | **Stretch:** complementary filter | improves angle estimate; selectable by a register bit |

Suggested order: A → C (write the model first for B) → B in the order capture → convert → filter → error.

---

## A. `timer_unit`

### A.1 Ports (frozen)

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | |
| `s_sel_i s_we_i s_be_i[3:0] s_addr_i[11:0] s_wdata_i[31:0]` / `s_rdata_o[31:0]` | | | slave bus (TMR bank) |
| `sched_busy_i` | in | 1 | `imu_busy` from I2C: still reading when the next tick fires ⇒ overrun |
| `control_tick_o` | out | 1 | **pulse** every `TICK_PERIOD` clk cycles |
| `irq_timer_o` | out | 1 | level: set every `IRQ_DIV` ticks, cleared by W1C |
| parameters | | | `DEF_EN=0`, `TICK_PERIOD_DEF=97656`, `IRQ_DIV_DEF=51` |

### A.2 Register map (base `0x1000_0000`)

| Off | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | `0x5449_4D01` | |
| 0x04 | CTRL | RW | b0=`DEF_EN` | b0 `EN` (ticks run); b1 `IRQ_EN`; b2 `CNT_CLR` (SC) restart counters |
| 0x08 | TICK_PERIOD | RW | 97656 | clk cycles per tick (min 1000). New value applies at the next reload (no glitchy short period) |
| 0x0C | IRQ_DIV | RW | 51 | ticks per timer interrupt (≈10 Hz) |
| 0x10 | STATUS | RO/W1C | 0 | b0 `IRQ_PENDING` (W1C), b1 `OVERRUN` (W1C) |
| 0x14 | TICK_COUNT | RO | 0 | ticks since enable |
| 0x18 | FREE_CNT | RO | 0 | free-running clk counter (timestamp) |

### A.3 Architecture
```
 clk ─► [cycle counter 0…TICK_PERIOD−1] ──wrap──► control_tick_o (registered pulse)
                                                   ├─► [tick counter] ─► TICK_COUNT
                                                   ├─► [÷IRQ_DIV] ─► IRQ_PENDING ─► irq_timer_o (if IRQ_EN)
                                                   └─► if sched_busy_i==1 at this moment ⇒ OVERRUN=1
```
Counter restarts on `EN` rising or `CNT_CLR`. `EN=0` ⇒ no ticks, no IRQ.

### A.4 Test vectors
- `TICK_PERIOD=100`: over 10 ticks the spacing between pulses is exactly 100 clk each, pulse width exactly 1.
- Default period: 97656 cycles ⇒ 1.953 ms at 50 MHz (simulate ≥ 3 ticks).
- Change `TICK_PERIOD` mid-run: the current period finishes, the next one uses the new value.
- `IRQ_DIV=3`: `irq_timer_o` rises on every 3rd tick, stays high until W1C write, then drops.
- Hold `sched_busy_i=1` during a tick ⇒ `OVERRUN` sets and stays until W1C.
- `EN=0` ⇒ no pulses.

---

## B. `sensor_pipeline`

### B.1 Ports (frozen wrapper)

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | |
| slave bus `s_*` | | | SENS bank |
| `imu_valid_i` | in | 1 | pulse from I2C |
| `imu_ax_i imu_ay_i imu_az_i imu_gx_i imu_gy_i imu_gz_i` | in | 16 each | signed raw |
| `imu_init_done_i` | in | 1 | calibration waits for this |
| `setpoint_i` | in | 32 | Q16.16 rad from PID bank |
| `pipe_valid_o` | out | 1 | pulse: `angle_o`, `err_o`, `rate_o` valid together |
| `angle_o` | out | 32 | Q16.16 rad, filtered + trimmed |
| `err_o` | out | 32 | Q16.16, `setpoint_i − angle` |
| `rate_o` | out | 32 | Q16.16 rad/s, filtered, bias-corrected |
| `calib_done_o` | out | 1 | level |
| parameters | | | `DEF_EN=0` (when 1: auto-calibrate right after `imu_init_done_i`) |

Latency `imu_valid_i` → `pipe_valid_o`: ≤ 64 cycles.

### B.2 Register map (base `0x1000_2000`)

| Off | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | `0x5345_4E01` | |
| 0x04 | CTRL | RW | 0 | b0 `CAL_START` (SC); b1 `AXIS_SEL`; b2 `INV_ANGLE`; b3 `INV_RATE`; b4 `FILT_MODE` (stretch: 1 = complementary) |
| 0x08 | FILT_SHIFT | RW | `0x22` | [2:0] angle filter `log2 N` (0–4, 0 = bypass); [6:4] rate filter `log2 N` |
| 0x0C | ANGLE_TRIM | RW | 0 | Q16.16, subtracted from the angle (balance point) |
| 0x10 | STATUS | RO | 0 | b0 `CAL_BUSY`, b1 `CAL_DONE`, b2 `DATA_FRESH` (a sample arrived in the last 2 ticks) |
| 0x14 | GYRO_BIAS_X | RO | 0 | signed, sign-extended |
| 0x18 | GYRO_BIAS_Y | RO | 0 | |
| 0x1C | GYRO_BIAS_Z | RO | 0 | |
| 0x20 | ANGLE_RAW | RO | 0 | after conversion, before filter |
| 0x24 | ANGLE_FILT | RO | 0 | after filter and trim |
| 0x28 | RATE_FILT | RO | 0 | |
| 0x2C | ERROR | RO | 0 | |
| 0x30 | SEQ_COUNT | RO | 0 | samples processed |

### B.3 Architecture
```
imu_* ─► [meas_capture] ─► [angle_conv] ─► [sensor_filter] ─► [error_calc] ─► err_o, rate_o, angle_o, pipe_valid_o
          │ latch all 6 axes together             │              (2 moving averages,
          │ gyro-bias calibration FSM             │               or complementary)
          └► calib_done_o, bias regs              └► ANGLE_RAW, telemetry regs
```

**B.3.1 `meas_capture`**
- On `imu_valid_i`: latch all six axes in the same cycle (coherent sample), bump `SEQ_COUNT`.
- Calibration FSM: `IDLE → SETTLE → ACCUM → DONE`. Starts on `CAL_START`, or automatically after `imu_init_done_i` rising if `DEF_EN=1`. `SETTLE` discards 64 samples, `ACCUM` sums 256 samples of `gx, gy, gz` in 24-bit accumulators, bias = `sum >>> 8`. Then `calib_done_o=1`.
- Output gyro = `raw − bias`, saturated to 16 bits. During calibration data keeps flowing (uncorrected); the safety block refuses to arm until `calib_done_o=1`.

**B.3.2 `angle_conv`**
- `AXIS_SEL=0`: accel axis = X, gyro axis = Y. `AXIS_SEL=1`: accel = Y, gyro = X. (Pitch about Y is seen by accel-X and gyro-Y.)
- `angle = accel × 4` (Q16.16 rad). `rate = (g<<3) + (g>>>1) + (g>>>2)`. Then `INV_ANGLE`/`INV_RATE` negate. Angle then has `ANGLE_TRIM` subtracted (after the filter, see below).
- Sign convention: **leaning forward ⇒ angle > 0**, and rate is the derivative of that angle. Angle and rate signs must agree; that is why they have separate invert bits. Get this right at the bench first.
- 1-cycle latency.

**B.3.3 `sensor_filter`**
- Two instances of `moving_avg_filter` (WIDTH=32): one for angle, one for rate. `N = 2^k`, `k` from `FILT_SHIFT`.
- Circular buffer of N samples + running sum: `sum = sum + new − oldest`; `out = sum >>> k`. Sum register has `k` extra bits.
- Changing `k` at runtime: clear the buffer and sum.
- **Group delay is (N−1)/2 samples ≈ 1 ms per step at 512 Hz. The MPU's own filter already adds ≈3 ms. Keep N small (2–8). More smoothing costs phase margin and the robot will oscillate.**
- `ANGLE_TRIM` subtracted after the filter.

**B.3.4 `error_calc`**
- `err = setpoint_i − angle` (saturating 32-bit). `rate` passed through unchanged. 1-cycle latency. Emits `pipe_valid_o`.

### B.4 Test vectors (all must pass)

| Block | Input | Expected |
|---|---|---|
| `angle_conv` | accel=4096, trim 0 | angle=16384 |
| `angle_conv` | accel=−8192 | angle=−32768 |
| `angle_conv` | gyro=131 | rate=1145 (formula gives exactly 1145) |
| `angle_conv` | gyro=−1000 | rate=−8750 |
| `angle_conv` | `INV_ANGLE=1`, accel=4096 | −16384 |
| `moving_avg` k=2 | inputs 0,0,0,0 then 4000 ×4 | outputs …0, 1000, 2000, 3000, 4000 |
| `moving_avg` k=0 | any | out = in |
| `error_calc` | setpoint=0, angle=16384 | err=−16384 |
| `error_calc` | setpoint=3277, angle=0 | err=3277 |
| calibration | 320 samples of gx=10, gy=−5, gz=3 | bias regs 10, −5, 3; then gy=−5 ⇒ corrected 0; `calib_done_o=1` |
| end-to-end | gyro/accel constant, k=0 | `pipe_valid_o` exactly once per `imu_valid_i` |

### B.5 Golden model
`model/sensor_pipeline.py`: same integer maths, same shifts. Generate ~1000 random IMU samples, run the RTL in the TB, dump `pipe` outputs to a file, and diff against Python. Zero differences allowed.

### B.6 FPGA bench test (with Kaushal's I2C on real IMU)
- Board still, flat: after calibration, gyro-corrected ≈ 0 (|rate| < 0.02 rad/s), angle ≈ 0 ± 0.02 rad (set `ANGLE_TRIM` to zero it).
- Tilt the board by hand 30°: angle ≈ 0.5 rad. (True 0.5236, small-angle formula gives 0.5.)
- Tilt forward: angle rises **and** rate is positive while moving. If rate has the opposite sign, flip `INV_RATE`.
- Capture with ILA: `angle_o`, `rate_o`, `pipe_valid_o`. `pipe_valid_o` should pulse at ≈512 Hz.

---

## D. Stretch goal — complementary filter (do after B is verified)

Selected by `CTRL.FILT_MODE`. It fuses gyro (fast, drifts) and accel (slow, noisy):
```
pred  = angle_f + (rate >>> 9)            // rate·Ts, Ts = 1/512 exactly
angle_f_new = pred − (pred >>> 6) + (angle_acc >>> 6)     // α = 63/64 ≈ 0.984
```
Multiplier-free. It removes most of the accel noise without adding the moving-average lag, and makes the robot far easier to tune. Test: constant accel angle, zero rate ⇒ `angle_f` converges to the accel angle; constant rate with zero accel input ⇒ `angle_f` ramps by `rate/512` per sample minus the small α leakage. Add to the Python golden model too.

## Your timeline

| Week | You |
|---|---|
| W1 | both wrappers with frozen ports merged; Python model skeleton |
| W2 | `timer_unit` RTL + TB (PR); `angle_conv` + `error_calc` + TB |
| W3 | `meas_capture` + calibration; `sensor_filter`; SENS regs; full random TB vs Python |
| W4 | pair test with Kaushal (tick → I2C model → your pipeline) and with Conolas (→ PID) |
| W5–6 | bench-verify angle/rate on the real IMU; help tune filter shift |
| W7–8 | stretch: complementary filter; help firmware read telemetry |

## DOs / DON'Ts
**DO** write the Python model first · use only shifts/adds where the contract says so · saturate, never wrap · verify signs on the real board · keep every stage's latency ≤ 64 cycles.
**DON'T** add a big moving-average "to be safe" · use floating point · change Q16.16 · let `pipe_valid_o` fire twice per sample · forget that `err` uses **filtered** angle.
