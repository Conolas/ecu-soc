# Sheet 04 — Vedam: `rom_dp`, `ram_sp`, `clk_rst_gen`, `safety_fault_monitor`, firmware-to-ROM flow

Read `00_ECU_Interface_Contract_v1.0.md` first.

**Role:** you own the memory the CPU runs from, the reset that starts everything cleanly, and the **safety block that decides whether the motors are allowed to move**. The safety block is the most important thing on the robot: a bug there can damage hardware or hurt someone. It gets the most careful testing and is reviewed by both Kaushal and Conolas.

| # | Deliverable | Done when |
|---|---|---|
| A | `rom_dp` and `ram_sp` | all tests pass; infer BRAM on FPGA |
| B | `clk_rst_gen` | clean reset assert/release, verified in sim |
| C | `safety_fault_monitor` (+ SAFE regs, `DBG_OUT`) | every fault scenario verified; motors off ≤ 2 clk after a fault |
| D | `sw/bin2hex.py` + Makefile rule | firmware `.bin` → ROM init file automatically |

Suggested order: B (easy, everyone needs it) → A → D → C (spend most of your time here).

---

## A. Memories

### A.1 `rom_dp` (8 KB, two read ports)

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk` | in | 1 | |
| `ia_req_i` | in | 1 | instruction fetch request |
| `ia_addr_i` | in | 13 | byte address (use `[12:2]` as word index) |
| `ia_rdata_o` | out | 32 | registered: valid the cycle after `ia_req_i` |
| `s_sel_i` | in | 1 | data-side read request |
| `s_addr_i` | in | 13 | byte address |
| `s_rdata_o` | out | 32 | registered |
| parameters | | | `ROM_WORDS=2048`, `INIT_FILE="firmware.hex"` |

Two independent read ports (instruction fetch and `.rodata` reads), so infer a true dual-port ROM. Contents loaded with `$readmemh(INIT_FILE, mem)` in an `initial` block wrapped so it is only used for simulation/FPGA. Writes do not exist (the bus returns an error for writes to ROM). Word 0 to `0x7F` is the vector table, `0x80` the reset handler.

### A.2 `ram_sp` (4 KB, byte-writable)

Slave bus exactly per contract §5: `s_sel_i, s_we_i, s_be_i[3:0], s_addr_i[11:0], s_wdata_i[31:0]`, `s_rdata_o[31:0]` registered. `RAM_WORDS=1024`. **Byte enables must work per byte** (compilers emit `sb` and `sh`).

### A.3 Test vectors

| # | Test | Expected |
|---|---|---|
| 1 | ROM init file with words `0x00000013, 0x00000013, …` and a known word at `0x80` | `ia_rdata_o` returns them one cycle after request |
| 2 | ROM: both ports read different addresses in the same cycle | both correct |
| 3 | RAM: write `0x11223344` at `0x10`, read | `0x11223344` |
| 4 | RAM: `be=4'b0001` write `0xAA` at `0x10` | word becomes `0x112233AA` |
| 5 | RAM: `be=4'b1100` write `0xBBCC0000` | word becomes `0xBBCC33AA` |
| 6 | RAM: read data appears exactly one cycle after `s_sel_i` | checked in TB |
| 7 | RAM: read-during-write same address | defined behaviour: new data on next read (document it) |

### A.4 ASIC note (read later, plan now)
On FPGA these infer block RAM. In the ASIC flow (Phase 8) flop-based memory of this size is large. Keep the memories in their own small files and never scatter memory logic elsewhere so they can be swapped for SCL memory macros or shrunk. Sizes are `localparam`s.

---

## B. `clk_rst_gen`

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk_in` | in | 1 | board clock (already 50 MHz after the wrapper's PLL, if any) |
| `rst_n_in` | in | 1 | external reset button, active-low, **asynchronous, may bounce** |
| `pll_locked_i` | in | 1 | tie 1 if no PLL |
| `clk` | out | 1 | = `clk_in` (buffering is done by the FPGA tool) |
| `rst_n` | out | 1 | active-low, asserted asynchronously, released synchronously |

Behaviour:
- Reset is asserted **immediately** when `rst_n_in` is low or `pll_locked_i` is low.
- Release: 2-flop synchroniser on the release edge, plus a power-on hold counter of 255 clk cycles after both conditions are OK, so `rst_n` never releases inside a bounce.
- This is the **only** block allowed to use an asynchronous reset. Comment why.
- Tests: bounce `rst_n_in` (low 3 clk, high 1 clk, low 2 clk, high) ⇒ `rst_n` stays low for the whole sequence and releases 255+2 cycles after the final high; `rst_n` assertion is immediate; `pll_locked_i=0` holds reset.

---

## C. `safety_fault_monitor`

### C.1 Ports (frozen)

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | |
| slave bus `s_*` | | | SAFE bank |
| `control_tick_i` | in | 1 | pulse |
| `imu_valid_i` | in | 1 | pulse: sample received |
| `imu_err_i` | in | 1 | pulse: I2C transaction failed |
| `imu_init_done_i` | in | 1 | level |
| `calib_done_i` | in | 1 | level |
| `pipe_valid_i` | in | 1 | pulse: `angle_i` valid |
| `angle_i` | in | 32 | Q16.16 rad, filtered |
| `pid_sat_i` | in | 1 | level |
| `estop_n_i` | in | 1 | hardware E-stop, active-low, raw (you synchronise) |
| `arm_sw_i` | in | 1 | arm switch, raw (you synchronise; tied 0 in the final SoC) |
| `pwm_enable_o` | out | 1 | **1 = motors allowed**. Default 0 |
| `irq_fault_o` | out | 1 | level while any fault flag is set and unmasked |
| `dbg_o` | out | 8 | LEDs |
| parameters | | | `DEF_EN=0` (when 1, `ARM` behaves as if set by switch-less bring-up: arming still requires all conditions), `DEF_WD_EN=0` |

### C.2 Register map (base `0x1000_5000`)

| Off | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | `0x5341_4601` | |
| 0x04 | CTRL | RW | 0 (`DEF_WD_EN` in b1) | b0 `ARM`; b1 `WD_EN`; b2 `TILT_EN` (reset 1); b3 `FAULT_CLR` (SC) clear flags whose condition is gone; b4 `IRQ_EN` |
| 0x08 | WD_KICK | WO | – | any write restarts the watchdog |
| 0x0C | TILT_LIMIT | RW | 39322 (0.6 rad ≈ 34°) | Q16.16, compared with \|angle\| |
| 0x10 | SENSOR_TIMEOUT | RW | 8 | control ticks without `imu_valid_i` |
| 0x14 | SAT_LIMIT | RW | 256 | consecutive saturated samples |
| 0x18 | WD_TIMEOUT | RW | 100 | ticks (≈195 ms) without a kick |
| 0x1C | FAULT_STATUS | RO | 0 | sticky flags (below) |
| 0x20 | FAULT_LIVE | RO | 0 | same bits, live conditions |
| 0x24 | STATE | RO | 0 | 0 `DISARMED`, 1 `ARMED`, 2 `FAULT` |
| 0x28 | DBG_OUT | RW | 0 | firmware LED bits (see dbg mapping) |

Fault bits: `0 TILT`, `1 SENSOR_TIMEOUT`, `2 I2C_ERR`, `3 PID_SAT`, `4 WATCHDOG`, `5 ESTOP`, `6–7 reserved`.
`dbg_o[3:0] = {calib_done_i, imu_init_done_i, fault_any, pwm_enable_o}`, `dbg_o[7:4] = DBG_OUT[7:4]`.

### C.3 Behaviour (state machine)

```
            arm_req && calib_done && no live fault && flags==0
 DISARMED ───────────────────────────────────────────────────► ARMED   (pwm_enable_o = 1)
    ▲   ▲                                                       │  any fault condition
    │   └──── arm_req falls (deliberate disarm) ◄───────────────┤  (pwm_enable_o = 0 within ≤ 2 clk)
    │                                                           ▼
    └───── FAULT_CLR written AND condition gone AND arm_req toggled low→high ◄──── FAULT
```
- `arm_req = ARM_reg | arm_sw_synced`.
- After reset: `DISARMED`, `pwm_enable_o=0`.
- **Fail-safe default:** any doubt ⇒ motors off. `pwm_enable_o` is a registered output, and never depends on a CPU action to turn *off*.
- Conditions (only evaluated while `ARMED`, except E-stop which always latches):
  - **TILT:** `|angle_i| > TILT_LIMIT` on 3 consecutive `pipe_valid_i` (debounce), if `TILT_EN`.
  - **SENSOR_TIMEOUT:** no `imu_valid_i` for `SENSOR_TIMEOUT` consecutive `control_tick_i`.
  - **I2C_ERR:** 3 consecutive `imu_err_i` pulses (reset the count on `imu_valid_i`).
  - **PID_SAT:** `pid_sat_i` high for `SAT_LIMIT` consecutive `pipe_valid_i`.
  - **WATCHDOG:** if `WD_EN`, no `WD_KICK` write for `WD_TIMEOUT` ticks. Disabled by default so Phase 1 (no CPU) works.
  - **ESTOP:** `estop_n_i` low (2-FF synchroniser, then immediate): from any state force `pwm_enable_o=0` and set the flag.
- Re-arming a latched fault needs the deliberate sequence: clear flags, condition gone, `arm_req` low then high. A robot must never restart by itself.
- `irq_fault_o = IRQ_EN & (|FAULT_STATUS)`.

### C.4 Test scenarios (each is a TB case with an expected outcome)

| # | Scenario | Expected |
|---|---|---|
| 1 | Reset | `DISARMED`, `pwm_enable_o=0`, all flags 0 |
| 2 | `ARM=1` while `calib_done_i=0` | stays `DISARMED` |
| 3 | `ARM=1`, calib done, no faults | `ARMED`, `pwm_enable_o=1` |
| 4 | angle = 0.7 rad for 1 then 2 then 3 samples | after the 3rd: TILT flag, `pwm_enable_o=0` within ≤2 clk |
| 5 | angle spike 0.7 for only 2 samples then 0 | **no** fault (debounce) |
| 6 | no `imu_valid_i` for 8 ticks | SENSOR_TIMEOUT flag |
| 7 | 3 consecutive `imu_err_i` | I2C_ERR flag; 2 errors then a valid sample ⇒ no flag |
| 8 | `pid_sat_i` high 256 samples | PID_SAT flag |
| 9 | `WD_EN=1`, no kick for 100 ticks | WATCHDOG flag; kicking regularly ⇒ none |
| 10 | `estop_n_i` low (even when `DISARMED`) | ESTOP flag, `pwm_enable_o=0` in ≤ 3 clk |
| 11 | After a fault: write `FAULT_CLR` while condition still live | flag stays |
| 12 | Fault gone, `FAULT_CLR`, but `ARM` never toggled | stays `FAULT`/disabled |
| 13 | Fault gone, `FAULT_CLR`, `ARM` low then high | `ARMED` again |
| 14 | Two faults at once | both flags set |

### C.5 FPGA test
Arm with the switch; tilt the board past the limit by hand: LED shows fault, outputs off. Press E-stop: off immediately. Power-cycle: motors disabled after boot until armed. Only then connect the real motor supply.

---

## D. Firmware → ROM flow

`sw/bin2hex.py <in.bin> <out.hex>`: read the binary, pad to a multiple of 4 bytes, write one 8-hex-digit word per line, **little-endian** (byte 0 is the least significant byte), no `@` address lines. `sw/Makefile` target `rom` builds the firmware and produces `firmware.hex` for `$readmemh`. Test with a 3-instruction binary and compare against the `objdump` disassembly (word `0x00000013` = `nop`). Note: `objcopy -O verilog` addresses can be confusing; this script avoids the problem.

## Your timeline

| Week | You |
|---|---|
| W1 | shells with frozen ports merged for `rom_dp`, `ram_sp`, `clk_rst_gen`, `safety_fault_monitor`; `clk_rst_gen` finished |
| W2 | `rom_dp`, `ram_sp` + TB; `bin2hex.py` |
| W3 | `safety_fault_monitor` RTL + regs |
| W4 | all 14 scenarios in a self-checking TB; pair test: safety in the loop with everyone |
| W5–6 | FPGA: arm switch, E-stop, LED flags on the real board |
| W7–8 | watchdog with real firmware (`WD_EN`, `WD_KICK`); help debug boot issues |

## DOs / DON'Ts
**DO** default every safety output to "motors off" · latch faults · test every fault, including two at once · debounce sensor glitches but never debounce E-stop · keep the safety FSM small enough to read in one sitting · ask Kaushal and Conolas to review before you consider it done.
**DON'T** let software be required to *disable* motors · let a fault clear itself · use `initial` for logic · add extra ports · enable the watchdog by default (Phase 1 has no CPU).
