# The Numbers and Formulas in the ECU Deck — Explained

For each number: **where it comes from**, **what it means**, **what happens if you change it**, and **which other blocks it touches**. Every value below was recomputed while writing this guide.

**Notation:** Q16.16 = 32-bit fixed-point (Section 2) · `Ts` = control period (1/512 s) · `f_clk` = 50 MHz · "tick" = one control cycle.
**Three habits that make the whole design easier to reason about**
1. Almost every constant is a **count of 20 ns clock cycles**. Convert with `time = cycles × 20 ns`.
2. Almost every signal is **Q16.16**. `real value = integer / 65536`.
3. A number is either **free to tune** (gains, limits, thresholds), or **structural** (clock, Q-format, sample rate, address map). Structural numbers ripple through many blocks (Section 16).

---

## 1. The master clock: 50 MHz and the cycle-to-time table

- **Source:** the Arty A7 board has a 100 MHz oscillator (confirm in its reference manual); a clock-manager (MMCM) divides it to a clean 50 MHz. Period = 1 / 50 MHz = **20 ns**.
- **Why 50 MHz:** slow enough that an FPGA meets timing with large margin, fast enough that every constant below is a comfortable whole number of cycles (2500 cycles = exactly 20 kHz, 128 cycles per I²C bit…).
- **Meaning:** every "cycle" count on the slides is in these 20 ns units.

| Constant | Cycles | Time | Used for |
|---|---|---|---|
| Reset hold | 255 | 5.1 µs | reset stays low a little after release |
| Block latency cap | 64 | 1.28 µs | max time any stage may take |
| PID latency target | 16 | 0.32 µs | input pulse → output pulse |
| PWM dead-time | 250 | 5 µs | both outputs low at direction change |
| PWM period | 2500 | 50 µs | = 20 kHz |
| I²C one bit | 128 | 2.56 µs | one SCL period at DIV = 31 |
| Control tick | 97,656 | 1.953 ms | = 512 Hz |

**If you change f_clk:** every cycle count above must be recomputed (I²C divider, timer period, PWM period, dead-time, reset hold), otherwise all the real-world times move. Cycle counts are *not* automatically scaled; they are fixed numbers in registers/parameters.

---

## 2. Q16.16 fixed-point — the number system everything shares

- **Format:** a signed 32-bit integer where the low 16 bits are the fraction. **real = integer / 65536.**
  - 1.0 → 65536 (`0x0001_0000`) · 0.25 → 16384 · −0.5 → −32768 (`0xFFFF_8000`) · smallest step 1/65536 = 0.0000153.
- **Range:** −32768 … +32767.99998. Far more than needed: an angle is within ±π, a gyro rate within ±4.4 rad/s (250 °/s).
- **Why not floating point:** floating-point hardware is big, slow, and its timing is harder to guarantee. Integers add in one cycle and multiply in a fixed number of cycles.
- **Why 16 + 16:** the integer part must hold the largest gain (tens) and the fraction must resolve angles finely. One raw accelerometer count is 4 Q-units, so the format is 4× finer than the sensor.
- **Multiplication rule (slide "Fixed-point"):** `(a × b) >> 16`.
  Why: (a/65536)·(b/65536) = ab/2³². To express the product in Q16.16 multiply by 65536 → ab/65536 = `ab >> 16`.
  The raw product needs **64 bits** (32 × 32); shifting right 16 and keeping the low 32 bits gives the result.
  `>>` here is an *arithmetic* shift: it rounds toward −∞ ("floor"). −13080.5 becomes −13081, +13080.5 becomes +13080. Python's `>>` behaves the same, which is why a Python model can match the hardware exactly.
- **Saturating:** results clamp at the limits instead of wrapping. A wrap would turn a huge positive command into a huge negative one.
- **If you change the format** (e.g. Q8.24 for finer resolution): every block, the firmware header, and all test vectors change. The conversion constants (×4, ×8.75) change too. Not worth it.

---

## 3. The inverted-pendulum numbers (slide "The Inverted Pendulum")

**Formula: θ̈ ≈ (g/l)·θ − (1/l)·a**
- θ = tilt from vertical (rad), θ̈ = how fast the tilt speeds up, g = 9.81 m/s², l = height of the centre of mass above the wheel axle, a = acceleration of the wheels.
- **Derivation:** put yourself on the accelerating base. A fictitious force −m·a acts on the mass. Torque balance about the pivot: m·l²·θ̈ = m·g·l·sinθ − m·a·l·cosθ. For small angles sinθ ≈ θ and cosθ ≈ 1 → θ̈ = (g/l)θ − a/l. ✔
- **First term (g/l)·θ:** gravity. Positive feedback — a lean makes the lean grow. That is "unstable".
- **Second term −a/l:** your control knob. Accelerating the wheels *toward the lean* (a > 0 when θ > 0) reduces θ̈.
- **Balance condition:** θ̈ = 0 ⇒ **a = g·θ.** A 0.1 rad lean (5.7°) needs about 0.98 m/s² of wheel acceleration. So the controller must turn a tilt into an acceleration, and the gain must be large enough (K > g in acceleration-per-radian) that the loop beats gravity's destabilising term.

**"Error grows about 2.7× every √(l/g)":**
- The unstable solution is θ ∝ e^(t/τ) with **τ = √(l/g)**. e = 2.718 → "2.7× per τ".
- For l = 15 cm: τ = √(0.15/9.81) = **0.124 s** (the slide rounds to 0.12 s).

| l (centre-of-mass height) | τ | Unstable pole √(g/l) |
|---|---|---|
| 10 cm | 101 ms | 9.9 rad/s |
| **15 cm** | **124 ms** | **8.1 rad/s** |
| 20 cm | 143 ms | 7.0 rad/s |
| 30 cm | 175 ms | 5.7 rad/s |

- **What it means:** a taller robot falls more slowly, so it is *easier* to balance; a short, squat robot falls faster and needs a faster, tighter loop.
- **"Controller reacts in tens of milliseconds":** the total delay in the loop must be a small fraction of τ. A common rule of thumb is delay < τ/5 ≈ 25 ms. Our loop's total sensor-to-motor delay is about 3.5 ms (Section 4), so there is a big margin.
- **If your real l differs:** measure your robot's balance height. The gains you need scale with g/l, and the tilt-cutoff threshold depends on it.
- **Caution:** 15 cm is an *example* value, not a measurement of your chassis.

---

## 4. The loop-timing numbers (slides "Balancing loop" and "Data flow, timing")

**512 Hz and 1.95 ms**
- Ts = 1/512 s = **1.953 ms**. Hardware gets it as `f_clk / 97,656 = 512.0013 Hz`.
- **Why 512 and not 500:** 512 = 2⁹. Then `ω·Ts` (rate × time step) is just `ω >> 9`, a free shift in hardware. The difference between 500 and 512 Hz is irrelevant to the control.
- **Why not slower:** the delay of a sampled loop grows with the period; 512 Hz keeps the sampling delay (~1 ms average) negligible next to τ.
- **Why not faster:** the I²C burst takes 0.4 ms (Section 6) and the MPU-6050 produces new data at 1 kHz with our settings. Reading faster than 1 kHz returns repeats.

**"Sensor read about 0.4 ms"** — 156 SCL clock periods × 2.56 µs = 399 µs (derived in Section 6).

**"Hardware under 5 µs"**
- Every stage may take at most 64 cycles (1.28 µs). In practice: capture 1 + angle 1 + filter ≈ 3 + error 1 + PID ≤ 16 ≈ **22 cycles ≈ 0.44 µs**. "Under 5 µs" is a generous bound.
- **Not counted in that number:** the PWM block applies a new duty only at the next PWM period boundary, up to **50 µs** later. Still tiny, but say "under ~60 µs including PWM" if someone asks.

**"About 3 ms sensor low-pass dominates"**
- The MPU-6050's internal digital low-pass filter (setting 2: ≈ 94 Hz accel, ≈ 98 Hz gyro) delays the data by about **3.0 ms (accel) / 2.8 ms (gyro)**. This happens *inside the sensor*, before our hardware sees any data.
- **Total sensor-to-motor delay ≈ 3.0 (sensor filter) + 0.4 (I²C) + ~0.5 (our logic) + up to 0.05 (PWM) ≈ 3.5–4 ms**, plus the moving-average delay if enabled (Section 10).

**Margin "over 1.5 ms":** 1.953 − 0.4 = 1.55 ms. That idle time is why the timer period can't be shortened much (Section 5).

**If you change the control rate (the most far-reaching number in the design):**
1. Timer period register (`TICK_PERIOD`).
2. `Ki` pre-scaling (`Ki_eff = Ki·Ts`) and, if used, the `D_SRC = 0` derivative scaling (`Kd/Ts`).
3. Complementary filter: its `ω·Ts` shift (>>9 is only right for exactly 512 Hz) and its time constant.
4. Moving-average delay in ms (delay = (N−1)/2 samples).
5. All safety counts in *ticks* (their real-time meaning scales): 3-sample tilt debounce, 8-tick sensor timeout, 256-sample saturation, 100-tick watchdog, 51-tick interrupt.
6. The I²C budget: burst (0.4 ms) must fit with margin.

---

## 5. Timer, clock and reset numbers (slide "Timer, clock and reset")

| Number | Origin | Meaning / effect of changing |
|---|---|---|
| **97,656** | 50,000,000 / 512 = 97,656.25 → 97,656 | One tick every 1.9531 ms. Actual rate 512.0013 Hz (0.0003% fast). Smaller → faster loop; but see below. |
| **32-bit counter** | cheap to build | Period register can hold up to 4.29×10⁹ cycles = **85.9 s**. The free-running timestamp wraps every 85.9 s. |
| **51 ticks ≈ 10 Hz** | 51 × 1.953 ms = **99.6 ms** | CPU timer interrupt for slow housekeeping (telemetry, kicking the watchdog). Change `IRQ_DIV` freely; it does not affect the real-time loop. |
| **Overrun flag** | `imu_busy` still high when the next tick fires | Means the sensor read took longer than a period. It is a warning that the period is too short or the I²C is too slow. |
| **Reset hold 255 cycles** | 255 × 20 ns = 5.1 µs | Gives the reset a clean, bounce-proof end. Free to change; keep it larger than the bounce you expect. |
| **2-flop synchroniser** | standard | Stops a signal arriving at a random moment from putting a flop into an undefined (metastable) state. |

**Practical minimum for `TICK_PERIOD`:** the I²C burst (≈ 0.4 ms = 20,000 cycles) must finish before the next tick. The register guard in the sheet says 1000 cycles, but a safe floor is about **25,000–30,000 cycles** (0.5–0.6 ms ≈ 1.7–2 kHz). Below that, `OVERRUN` fires every tick.

---

## 6. The I²C and MPU-6050 numbers (slides "I²C master" and "MPU-6050 controller")

**f_SCL = f_clk / (4·(DIV+1))**
- Why **4**: the bit engine splits each SCL period into four equal phases (SCL low, SDA changes, SCL rises, SCL high). Data therefore changes only while SCL is low and is stable around the rising edge.
- **DIV = 31 → 50 MHz / 128 = 390.625 kHz.** One bit = 2.56 µs.

| DIV | f_SCL | Comment |
|---|---|---|
| 30 | 403 kHz | **above** the 400 kHz limit of the MPU-6050 — don't |
| **31** | **390.6 kHz** | chosen: just under the limit |
| 124 | 100.0 kHz | standard mode; burst becomes 1.56 ms |

**"One byte = 9 clocks ≈ 23 µs":** 8 data bits + 1 acknowledge bit = 9 SCL periods × 2.56 µs = **23.04 µs**.

**The 14-byte burst ≈ 0.4 ms**
- Registers `0x3B … 0x48` hold: accel X, Y, Z (6 bytes) + temperature (2) + gyro X, Y, Z (6) = **14 bytes**.
- Bit-times: START ≈ 1 + address+W 9 + register address 9 + repeated START ≈ 1 + address+R 9 + 14 × 9 = 126 + STOP ≈ 1 = **156**. 156 × 2.56 µs = **399 µs**.
- Reading all 14 in one go matters: all axes come from the *same instant*. Separate reads could mix two moments.

**Start-up and configuration values**

| Value | Meaning |
|---|---|
| Address `0x68` | 7-bit address with the AD0 pin low (`0x69` if high) |
| `WHO_AM_I` (`0x75`) = `0x68` | identity check: proves the chip talks |
| `PWR_MGMT_1` (`0x6B`) = `0x01` | wakes the chip (it powers up asleep) and uses a gyro clock |
| `SMPLRT_DIV` = 0 | sample rate = gyro output rate / (1 + 0). With the filter on, that rate is 1 kHz |
| `CONFIG` = `0x02` (DLPF_CFG = 2) | on-chip low-pass ≈ 94 Hz accel / 98 Hz gyro, delay ≈ 3.0 / 2.8 ms |
| `GYRO_CONFIG` = 0 | ±250 °/s → 131 LSB per °/s |
| `ACCEL_CONFIG` = 0 | ±2 g → 16384 LSB per g |
| Wait 50 ms | power-up time before register access (the datasheet may require longer — check; 100 ms is the safe choice) |

**DLPF setting vs delay (from the MPU-6000/6050 register map; verify against your datasheet)**

| DLPF_CFG | Accel bandwidth / delay | Gyro bandwidth / delay |
|---|---|---|
| 0 | 260 Hz / 0 ms | 256 Hz / 0.98 ms |
| 1 | 184 Hz / 2.0 ms | 188 Hz / 1.9 ms |
| **2** | **94 Hz / 3.0 ms** | **98 Hz / 2.8 ms** |
| 3 | 44 Hz / 4.9 ms | 42 Hz / 4.8 ms |

Lower setting → less delay but more noise reaching the PID. Higher → smoother but later. 2 is the usual compromise for balancing.

**Error numbers**
- **Timeout 1.5 ms:** about 3.75 × the normal 0.4 ms burst — long enough never to trip falsely, short enough to abort a stuck transfer well before the next tick. **At DIV = 124 (burst 1.56 ms) this timeout would trip on every read — change them together.**
- **3 consecutive errors → re-initialise:** one failed read is noise; three in a row means the sensor lost its configuration.
- **9 clock pulses to free a stuck bus:** a slave holding SDA low is in the middle of a byte (8 data + ACK = 9 clocks). Pulsing SCL 9 times lets it finish.
- **4.7 kΩ pull-ups:** the bus is open-drain, so pull-ups create the high level. The value sets rise time (and therefore the maximum speed).

**Affects other blocks:** DIV and DLPF change the delay and budget (Section 4). The range settings change the constants in Section 8.

---

## 7. Measurement capture and calibration numbers (slide "Measurement capture and calibration")

- **Coherent capture:** all six axes are latched on the same clock edge, so one "sample" never mixes two moments.
- **Gyro-bias calibration:** with the robot still, the true rate is zero, so whatever the gyro reports is its **bias**. Average it and subtract it later.
  - **Discard 64 samples:** 64 / 512 = **0.125 s** for everything to settle after power-up and for you to let go of the robot.
  - **Average 256 samples:** 256 / 512 = **0.5 s.** Total 0.625 s → the slide's "about 0.6 s".
  - **Why 256 = 2⁸:** the average is `sum >> 8`, with no divider.
  - **Why 24-bit accumulators:** each reading is a signed 16-bit number (up to 2¹⁵ in magnitude) and 256 = 2⁸ of them are summed: 2¹⁵ × 2⁸ = 2²³, which exactly fits a signed 24-bit number. The rule is `accumulator width = 16 + log2(N)`.
  - **Averaging benefit:** random noise shrinks by √256 = **16×**.
- **If you change them:** more samples → better bias estimate but a longer wait; fewer → noisier bias. Keep N a power of two and widen the accumulator accordingly. The robot must be still the whole time; moving it corrupts the bias and nothing detects that, so firmware should sanity-check the stored bias.

**What a gyro bias really does (a nuance the slide simplifies):**
- Slide wording: "a small constant gyro offset integrates into a growing angle error." That is true when the angle is *built by integrating the gyro*.
- In our **baseline** (angle from the accelerometer, gyro used directly as the D term), the bias does not integrate; it adds a constant false rotation rate. Effect: `D = −Kd × bias`, a constant motor offset. Example: bias 2 °/s = 0.035 rad/s, Kd = 0.1 → 0.0035 of full command (≈ 0.35 % duty). Small, but the robot slowly drifts.
- In the **complementary-filter option** (which does integrate the gyro) a bias creates a steady angle error ≈ `bias × τ` = 0.035 × 0.123 s = **0.0043 rad (≈ 0.25°)**, where τ is the filter time constant (Section 10).
- Either way, calibration removes it. You may want to reword the slide as "a constant gyro offset looks like a false rotation".

---

## 8. Angle conversion numbers (slide "Angle conversion and error calculation")

**Accelerometer → tilt: θ ≈ a / g**
- A still accelerometer measures the reaction to gravity along its axis: **a_x = g·sinθ.** For small angles sinθ ≈ θ, so θ ≈ a_x/g.
- **16384 LSB per g:** the ±2 g range maps ±2 g onto ±32768 counts: 32768 / 2 = 16384.
- **×4:** the Q16.16 value of θ (rad) is `θ × 65536 = (raw/16384) × 65536 = raw × 4`. A shift left by 2 — no multiplier.
- **Example:** raw 4096 = 0.25 g → θ ≈ 0.25 rad → **16384** ✔ (matches the slide).
- **"About 4 % off at 0.5 rad":** sin(0.5) = 0.4794, so the reading is 4.1 % below the true 0.5 rad. Near upright (a few degrees) the error is under 0.1 %.
- **Consequence for the tilt cutoff:** our "angle" is really sinθ. A measured 0.6 corresponds to a true angle of asin(0.6) = **36.9°**, not 34.4° (0.6 rad). Safety thresholds act on the *measured* value.
- **A bigger caveat — linear acceleration:** the accelerometer cannot tell gravity from acceleration. If the robot accelerates at 1 m/s², the accel reading shows a *false tilt* of 1/9.81 ≈ **0.1 rad (5.8°)**. This is why accel-only angle is noisy during motion and why the complementary filter exists.

**Gyro → rate: the ×8.75**
- 131 LSB per °/s (32768 / 250 = 131.07).
- ω(°/s) = raw / 131 → ω(rad/s) = raw / 131 × π/180 = raw × 1.3323×10⁻⁴ → in Q16.16 multiply by 65536: **raw × 8.731.**
- Hardware uses `(raw << 3) + (raw >> 1) + (raw >> 2)` = **8.75 × raw** — three shifts and two adds, no multiplier. Error = (8.75 − 8.731) / 8.731 = **0.21 %.**
- **Example:** raw 131 → 1048 + 65 + 32 = **1145**; the exact value is 1143.8.
- **Improvement if you ever need it:** subtract raw >> 6 as well: 8.734 → error 0.03 %.

**If you change the sensor ranges**
- ±4 g → 8192 LSB/g → the accel constant becomes **×8**. ±500 °/s → 65.5 LSB/(°/s) → the gyro constant becomes **≈ ×17.46** (shift-add 16 + 1 + ½).
- So `ACCEL_CONFIG`/`GYRO_CONFIG` (set by the I²C sequencer) and these constants (in the sensor pipeline) are **coupled**. Change one, change the other.
- Wider range = can measure bigger rates/accelerations but coarser resolution.

**Mounting and trim:** the axis-select and invert bits absorb how the sensor is bolted on. `ANGLE_TRIM` is subtracted so that the robot's real balance point reads zero (if upright reads +0.02 rad, trim = 0.02 × 65536 ≈ 1311).

**Error calculation: e = setpoint − θ** — see the sign discussion next.

---

## 9. The sign chain: which way should the wheels turn?

Take θ > 0 as "leaning forward" and a > 0 as "wheels accelerating forward". From Section 3: θ̈ = (g/l)θ − a/l, so **forward wheel acceleration reduces forward lean.** The controller must therefore produce: forward lean → forward acceleration.

With **e = setpoint − θ** and a positive Kp, a forward lean makes e negative and **u negative**. If "positive command = forward", the robot would drive *backward* and fall. So *one sign must flip somewhere in the chain*:

| Place | Control |
|---|---|
| Angle sign | `INV_ANGLE` in the sensor pipeline |
| Rate sign | `INV_RATE` (the rate and angle must agree with each other) |
| Motor direction | `DIR_INV_L`, `DIR_INV_R` in the PWM bank |

**The bench rule (do this once):** with the robot on a stand, tilt it forward by hand. The wheels must spin in the direction that would chase the lean. If not, flip one of the bits above, not the gains. The rate sign check: while the robot is tilting forward, the rate must be positive when the angle is increasing.

---

## 10. The filter numbers (slide "Digital filter")

**Moving average of 2^k samples (k = 0…4, so N = 1, 2, 4, 8, 16):** output = sum of the last N samples / N. Implemented as a running sum (add the new sample, subtract the oldest) and a shift.

**Step response, N = 4:** a step from 0 to 4000 gives 1000, 2000, 3000, 4000. (First output sees one new sample out of four: 4000/4 = 1000.)

**Delay = (N−1)/2 samples.** One sample = 1.953 ms.

| N | Delay | Noise reduction (random noise) |
|---|---|---|
| 1 (bypass) | 0 ms | 1× |
| 2 | 0.98 ms | 1.4× |
| 4 | 2.9 ms | 2× |
| 8 | 6.8 ms | 2.8× |
| 16 | 14.6 ms | 4× |

- The slide's "about (N−1) ms per step" is the same thing: (N−1)/2 samples × 1.953 ms ≈ (N−1) ms.
- **Why N stays small (2–8):** delay costs phase margin. Rule: a delay of *t* seconds at loop frequency *f* costs `360 × f × t` degrees of phase. At a 10 Hz loop bandwidth: 3 ms (sensor filter alone) = **10.8°**; add N = 4 (2.9 ms) and 0.4 ms of I²C → 6.4 ms = **23°**. Phase margin is exactly what keeps the loop from oscillating; spending it on smoothing is expensive.

**Complementary filter (optional): θ_f = α·(θ_f + ω·Ts) + (1 − α)·θ_acc**
- Read it as: predict the new angle by integrating the gyro (`θ_f + ω·Ts`), then pull gently toward the accelerometer angle.
- **α = 63/64 = 0.984.** Hardware form: `pred = θ_f + (ω >> 9)`, then `θ_f = pred − (pred >> 6) + (θ_acc >> 6)`. Shifts only.
- **Time constant:** τ = α·Ts / (1 − α) = 0.984 × 1.953 ms / 0.0156 = **123 ms**; crossover frequency 1/(2πτ) = **1.29 Hz.** Below ~1.3 Hz the accelerometer wins (so gyro drift is cancelled); above it the gyro wins (so vibrations and short accelerations are ignored).

| α | τ | Crossover | Effect |
|---|---|---|---|
| 31/32 | 61 ms | 2.6 Hz | trusts accel more: less drift, more noise/vibration |
| **63/64** | **123 ms** | **1.29 Hz** | chosen |
| 127/128 | 248 ms | 0.64 Hz | trusts gyro more: smoother, slower to correct drift |

- `ω >> 9` is exactly `ω·Ts` only because Ts = 2⁻⁹ s. At any other sample rate the constant changes (Section 4).

---

## 11. The PID numbers (slides "PID architecture" and "PID algorithm")

**Law:** `u[k] = Kp·e[k] + Ki·Ts·Σe − Kd·ω[k]`

| Gain | Unit | Meaning |
|---|---|---|
| Kp | command per radian | "how hard to push per radian of lean" |
| Ki | command per (radian·second) | cancels slow steady offsets |
| Kd | command per (rad/s) | damping: opposes the rate of change |

- **Output u:** a normalised motor command, −1.0 … +1.0 (Q16.16: ±65536). +1.0 = full drive.
- **Why `−Kd·ω`:** e = setpoint − θ, so d(e)/dt = −dθ/dt = **−ω** when the setpoint is constant (slide: "(constant setpoint)"). Using the gyro's ω directly is far cleaner than differentiating a noisy angle.
- **Why Ki is pre-multiplied by Ts:** the continuous integral Ki·∫e dt becomes Ki·Ts·Σe. Pre-storing `Ki_eff = Ki·Ts` saves a multiply every sample. **Physical Ki = Ki_eff × 512.** Example: Ki_eff = 0.01 → physical Ki = 5.12 per second.
- If `D_SRC = 0` (derivative of the error instead of the gyro): `Kd_eff = Kd/Ts = Kd × 512`.

**Worked checks from the slide**
1. **Kp = 1.0, e = 0.1 → u = 0.1.** In integers: (65536 × 6554) >> 16 = 6554 = 0.1. About 10 % command.
2. **Kp = 8.0, e = 0.2:** P = 1.6, but `OUT_LIMIT = 0.25` clamps u to 0.25 and raises the saturation flag.
3. **Ki step of 65 counts:** Ki_eff = 0.01 = 655 counts; e = 0.1 = 6554 counts. (655 × 6554) >> 16 = 65.5 → **65** per sample (floor). After 10 samples: **650** counts = 0.0099. Over one second (512 samples) the integrator would add ≈ 0.51 if not clamped — which is why it *is* clamped.

**Defaults and why**
- **OUT_LIMIT = 0.25:** a deliberately weak first-power setting for bring-up. With the output limited to a quarter of full drive, the wheels cannot hit a violent command if gains are wrong. The cost: it can only recover small leans (balance needs a = g·θ; if full drive gives, say, 5 m/s², then 25 % gives about 1.25 m/s², i.e. leans up to ~0.13 rad ≈ 7° — illustrative numbers). **Raise it in steps once balancing works.**
- **INT_LIMIT = 0.3:** the integrator may not contribute more than 30 % command, so it cannot swamp P and D.

**Anti-windup**
- *Clamp:* |integrator| ≤ INT_LIMIT.
- *Freeze when saturated:* if the output is already at its limit and the error pushes the same way, don't integrate. Otherwise the integrator keeps growing while the motors can't respond ("windup"), then overshoots badly.
- *Disable behaviour:* when safety withdraws the run-enable, output = 0, integrator cleared, previous error reset. Without the reset, re-enabling would see a stale error difference and produce a sudden kick.

**Latency "≤ 16 cycles ≈ 0.3 µs":** one shared 32×32 multiplier is reused in turn for P, I and D (about 8 cycles including add/saturate); 16 cycles = 0.32 µs is the allowed ceiling. Sharing one multiplier is smaller than three (an area saving that matters for the layout phase).

**Effect of changing a gain**
- Kp too small → cannot hold the robot; too large → fast oscillation.
- Kd too small → oscillation never dies; too large → buzzing/noise amplification and amplified by any sensor noise or sign error.
- Ki too large → slow, growing oscillation; zero → a steady lean offset stays.
- The right values depend on: the robot's l (Section 3), motor strength, battery voltage (duty maps to volts), MAX_DUTY, filter delay, and the sample rate.

---

## 12. The PWM and driver numbers (slides "PWM generator" and "Motor interface")

**20 kHz → period 2500 cycles:** 50,000,000 / 20,000 = 2500. Above audible range for most adults, below the BTS7960's **25 kHz** maximum. Higher frequency = more switching loss and may exceed the driver's limit; lower (< ~15 kHz) = audible whine and larger current ripple.

**Resolution:** 2500 steps = 11.3 bits; one step = 0.04 % duty.

**Duty = |command| × PERIOD / 65536** (slide: "|command| × period from a small multiplier").
- Command 0.5 = 32768 → 32768 × 2500 >> 16 = **1250** counts (50 %). Command −0.25 → 625 counts on the LPWM side.
- **The 65535 clamp:** +1.0 = 65536 doesn't fit a 16-bit magnitude, so the magnitude is limited to 65535 → duty 2499/2500 (99.96 %), a harmless 1-count loss.
- **MAX_DUTY = 0.9 = `0xE666` (58982):** 0.9 × 65536 = 58982. Gives a duty of 2249 counts max. It protects the motors and driver during bring-up. **It also caps the voltage the motors ever see, so it changes the loop's effective gain.**

**Average motor voltage = duty × V_battery.** This is how the PID's dimensionless u becomes torque. The same u gives less push on a sagging battery, so gains tuned at full charge drift as the battery drops. (A common fix is to scale by measured battery voltage; not in scope here.)

**Dead-time 250 cycles = 5 µs:** on a direction change the "forward" side must stop before the "reverse" side starts, or both drivers would conduct at once (a short, "shoot-through"). 5 µs is much longer than the driver's own switching times. It is 10 % of one PWM period (50 µs), and a reversal happens at most once per 1.95 ms control cycle, so the lost drive is negligible.
- Too short → risk of shoot-through current spikes. Too long → a small "dead zone" around zero command.
- RPWM and LPWM must **never** be high together; the testbench asserts it on every clock.

**Slew limiter (default 0.1 per update):** a jump from 0 to 1.0 takes 10 updates = 19.5 ms. It protects against violent steps but adds a delay and can limit authority in a real fall — keep it off (or high) while tuning balance.

**Update only at the period boundary:** the new duty and direction are latched at the start of each 50 µs period. Changing them mid-period would create a runt pulse (a much shorter or longer pulse than intended).

**Steering and gains:** `left = cmd + steer`, `right = cmd − steer`, each multiplied by its own gain (default 1.0). Per-motor gain compensates for two motors that aren't identical (e.g. 1.00 vs 1.05).

**Safety gating "within 2 cycles":** the enable path has two registers: the output drops to zero 40 ns after the safety monitor withdraws permission.

**BTS7960 numbers:** typical current limit about 43 A (far above a small robot's motors), 5.5–27.5 V supply, PWM up to 25 kHz, built-in protections. Check that the module accepts 3.3 V logic from the FPGA before connecting.

---

## 13. The safety-monitor numbers (slides "Safety state machine" and "Faults and responses")

| Number | Derivation | Why this value / effect of changing |
|---|---|---|
| **Tilt 0.6 rad (≈ 34°)** on **3 consecutive samples** | 0.6 rad = 34.4°; 3 × 1.953 = **5.9 ms** | Beyond roughly this angle the wheels can't catch the robot. Because our angle is sinθ (Section 8), 0.6 measured = **36.9° true**. **Lower it** (e.g. to ~0.35–0.4) once tuned so motors stop *before* a hard fall. Three samples reject a single noisy sample; 1 would false-trip, 10 (20 ms) would react late. |
| **Sensor timeout 8 ticks** | 8 × 1.953 = **15.6 ms** | Longest allowed gap with no new sample. Compared with τ = 124 ms it is short enough to be safe. Smaller (2–3) = trips on one missed burst; larger = flying blind longer. |
| **I²C error: 3 consecutive** | — | One failed read is noise; three is a fault. |
| **PID saturation: 256 samples** | 256 / 512 = **0.5 s** | A persistent saturated output means the controller can't recover (robot down or pinned). A hard push can saturate briefly, so 0.5 s is near the 0.3–0.7 s recovery times reported in the literature — consider ~1 s (512) if big pushes false-trip. |
| **Watchdog 100 ticks** | 100 × 1.953 = **195 ms** | The CPU must "kick" faster than this. Your 10 Hz timer interrupt kicks every 99.6 ms: only a 2× margin. Kick it from the timer interrupt, never from the main loop alone. |
| **Motors off ≤ 2 clock cycles** | 2 × 20 ns = **40 ns** | The enable output is a register, so shutdown is limited only by two clock edges. Mechanically irrelevant: the point is it needs no software. |
| **E-stop ≤ 3 clocks** | 2-flop synchroniser + 1 | 60 ns. Never debounced in hardware: a real E-stop must act immediately. |

**State logic in one sentence:** DISARMED → ARMED requires arm request ∧ calibration done ∧ no live fault ∧ no stored flags; any fault latches a flag and drops the enable; recovery requires clearing the flag, the condition gone, and the arm request toggled low then high. A robot must never restart by itself.

**Affects other blocks:** it reads the filtered angle (sensor pipeline), the sample/error pulses (I²C), the saturation flag (PID), the calibration-done flag, the E-stop pin and CPU watchdog kicks; it drives the enable into the PID (clears the integrator) and the PWM block (outputs low).

---

## 14. The memory, bus and Ibex numbers

**Sizes**
- **ROM 8 KB = 2¹³ bytes** → 13 address bits, 2048 words of 32 bits. **RAM 4 KB = 2¹²** → 12 address bits, 1024 words. Each **register bank window = 4 KB** (12 bits), so the top 20 bits of the address choose the bank (`0x1000_0` + bank number) — a very cheap decode. Most of each 4 KB window is unused; that's fine.
- **ASCII ID words:** `0x5449_4D01` = bytes 0x54 'T', 0x49 'I', 0x4D 'M', then version 01. Reading it proves the bus reaches the block.
- **Reset vector `0x80`:** Ibex starts at `boot_addr + 0x80`; with boot_addr = 0 the first instruction is at `0x0000_0080`. The first 0x80 bytes hold the trap/interrupt vector table.

**Bus timing:** grant in the same cycle as the request, data back one cycle later. A load or store takes at least 2 cycles. "Zero wait states" means no extra stall cycles.

**Why the memory sizes matter for the layout phase**
- 12 KB × 8 = **98,304 bits.** If built from flip-flops (≈ 5–6 gate-equivalents each) that is roughly **540 kGE** — about **20×** the Ibex core (≈ 24 kGE). Memories, not the CPU, would dominate the area. That is why sizes are parameters and kept small. (Approximate; the layout-phase memory strategy decides this.)

**Ibex numbers**
- **2.47 CoreMark/MHz:** CoreMark is a standard benchmark; "per MHz" makes it independent of clock. At 50 MHz: **≈ 123 CoreMark** — plenty for configuration and monitoring.
- **≈ 24 kGE:** area in "gate equivalents" (one GE = one 2-input NAND gate). The README gives ≈ 24 kGE as a commercial estimate; open-tool synthesis numbers are ≈ 26–27 kGE with the latch register file.
- **micro ≈ 0.9 CoreMark/MHz (≈ 15 kGE), maxperf ≈ 3.13 (≈ 30 kGE):** smaller = slower, faster = bigger. Small is the middle.
- **3-cycle multiplier** (`RV32MFast`): a multiply takes 3 cycles instead of 1. Our firmware barely multiplies (the PID is in hardware), so 3 is fine and saves area.
- **32 registers × 32 bits = 1024 bits** in the register file; as flip-flops that's ≈ 5–6 kGE, around a quarter of the core. A latch-based register file is smaller, which is why it will be evaluated for the layout flow.
- **15 fast interrupts:** Ibex has `irq_fast_i[14:0]`, plus timer, external, software and non-maskable inputs. We use the timer and an external (fault) input.
- **"Instruction cache off":** no cache = no unpredictable cache-miss timing and less area.

---

## 15. One complete worked example: a 0.1 rad lean, end to end

Robot leans forward by 0.1 rad (5.7°); upright setpoint 0; Kp = 2.0, Ki = Kd = 0 (rate ≈ 0); OUT_LIMIT = 0.25; filter bypass.

| Step | Calculation | Result |
|---|---|---|
| Physics | a_x = g·sin(0.1) = 0.0998 g | |
| MPU raw | 0.0998 × 16384 = 1635.6 → | **1635** counts |
| Angle conv | 1635 × 4 | **6540** (= 0.0998 rad) |
| Error | 0 − 6540 | **−6540** |
| PID P | (131072 × −6540) >> 16 | **−13080** (= −0.1996) |
| Saturate | |−0.1996| < 0.25 | unchanged |
| PWM duty | (13080 × 2500) >> 16 | **498** of 2500 counts = **19.9 %** |
| Direction | negative → LPWM (before any `DIR_INV`) | |
| Motors | 0.199 × V_battery | average voltage |
| Safety | 0.0998 < 0.6 | no fault |

Timing: tilt sensed → raw value ≈ 3 ms later (sensor filter) → I²C 0.4 ms → logic ≈ 0.5 µs → PWM updates within 50 µs. If the lean was 0.3 rad, P would be −0.6 → clamped to −0.25 and the saturation flag would start counting toward 256 samples.

---

## 16. "If I change X, what else must change?"

| Change | Also update | What happens to the ECU |
|---|---|---|
| **f_clk** | I²C DIV, `TICK_PERIOD`, PWM `PERIOD`, dead-time, reset hold, all ms/µs claims | all real-world times shift |
| **Control rate (Ts)** | `TICK_PERIOD`, `Ki_eff`, `Kd_eff` (D_SRC = 0), complementary `>>9` and α, tick-based safety counts, IRQ divider, I²C budget | gains need retuning; safety times change |
| **I²C DIV** | burst timeout (1.5 ms), `TICK_PERIOD` floor, sensor delay | slower bus → later data, less margin |
| **DLPF_CFG** | moving-average N (total delay), phase margin | smoother vs later |
| **Accel/gyro range** | ×4 and ×8.75 constants, axis scaling, safety limit meaning | wrong constant = wrong angle everywhere |
| **Q-format** | every block, firmware header, all test vectors | not recommended |
| **Kp / Ki / Kd** | nothing structural; saturation/safety thresholds interplay | balance quality |
| **OUT_LIMIT / MAX_DUTY** | tuning of Kp (effective gain), saturation fault count | authority to recover |
| **Filter N** | loop phase margin → gains | delay vs noise |
| **PWM `PERIOD`** | BTS7960 limit (≤ 25 kHz), dead-time as % of period, duty resolution | audible noise, losses |
| **Dead-time** | PWM period (keep it ≪ period) | safety vs dead zone |
| **Tilt limit** | knowledge of true angle (sinθ), motor authority | when motors cut |
| **Memory sizes** | decoder windows, linker script, ROM init file, layout area | address map changes |
| **Address map** | bus decoder, `ecu_regs.h`, contract, every sheet | firmware breaks if mismatched |

---

## 17. Which numbers are free to tune and which are structural

- **Free to tune at the bench (registers):** Kp, Ki, Kd, SETPOINT, INT_LIMIT, OUT_LIMIT, ANGLE_TRIM, filter shifts, MAX_DUTY, slew step, steer, motor gains, dead-time (carefully), all safety thresholds and timeouts, IRQ divider, I²C clock divider (within the sensor limit).
- **Structural (change only with a plan, a CR and testbench updates):** f_clk, Ts (512 Hz), Q16.16, ADC ranges and their conversion constants, address map, ROM/RAM sizes, the 64-cycle block rule, the 14-byte burst format.

---

## 18. Small corrections worth making on the slides after reading this guide

1. **Calibration slide:** "a constant gyro offset integrates into a growing angle error" is only true when the gyro is integrated. Safer wording: "a constant gyro offset looks like a false rotation rate."
2. **Timing slide:** "hardware stages under 5 µs" does not include the PWM period boundary (up to 50 µs). Say "under ~60 µs including the PWM boundary".
3. **Safety slides:** the tilt threshold is applied to the measured quantity (≈ sinθ), so 0.6 trips at ≈ 37° true. Say "|θ| > 0.6 rad (measured)".
4. **Safety state-machine slide:** after a fault the sequence is FAULT → DISARMED → ARMED (the arm request must go low, then high); it does not jump straight to ARMED.
