# Sheet 01 — Conolas: `hw_pid_accel`, `cpu_subsystem`, firmware, `ecu_soc_top`

Read `00_ECU_Interface_Contract_v1.0.md` first. Everything below uses its names and formats.

**Role:** architect, contract owner, remote lead. You build the two hardest things (PID accelerator, Ibex integration) and the glue. Kaushal is your on-site deputy and co-owns the bus side of the CPU.

**Your deliverables**

| # | Deliverable | Done when |
|---|---|---|
| A | `ecu_soc_top` skeleton (Week 1) + final integration | elaborates in W1; full system in W7–8 |
| B | `hw_pid_accel` (+ PID register bank) | matches golden model bit-for-bit |
| C | `cpu_subsystem` (Ibex wrapper) | runs firmware in simulation and on FPGA |
| D | Firmware (C) | closed loop with CPU-configured registers |
| E | Contract ownership, reviews, weekly demo | ongoing |

---

## A. `ecu_soc_top` — do this FIRST (Week 1)

Nothing else can be integrated until this exists. In the first 3–4 days:

1. Create every module of the contract as an empty shell with the **exact** ports (you can copy port tables from each sheet), outputs tied to safe constants (`pwm_enable = 0`, valid pulses = 0, rdata = 0).
2. Instantiate all of them in `ecu_soc_top` with the signal names from Section 6 of the contract.
3. Parameter `HW_ONLY` (default 0) → passes `DEF_EN` to blocks.
4. Push to `main`, tell the team: "pull, and replace your shell with your real module keeping the ports."
5. Add a lint script (`make lint`) that everyone runs.

Integration order later (mirror of the datapath): timer + I2C → pipeline → PID → actuation → safety → bus/CPU last.

---

## B. `hw_pid_accel`

### B.1 Ports

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | |
| `s_sel_i s_we_i s_be_i[3:0] s_addr_i[11:0] s_wdata_i[31:0]` | in | — | slave bus (PID bank) |
| `s_rdata_o` | out | 32 | |
| `err_valid_i` | in | 1 | pulse (`pipe_valid`) |
| `err_i` | in | 32 | Q16.16, `setpoint − angle` |
| `rate_i` | in | 32 | Q16.16 rad/s |
| `run_i` | in | 1 | `pwm_enable` from safety. 0 ⇒ output 0, integrator cleared |
| `pwm_cmd_o` | out | 32 | Q16.16 in [−OUT_LIMIT, +OUT_LIMIT] |
| `pwm_cmd_valid_o` | out | 1 | pulse |
| `pid_sat_o` | out | 1 | level: last output was clamped |
| `setpoint_o` | out | 32 | from SETPOINT register → `sensor_pipeline` |
| parameters | | | `DEF_EN=0`, `DEF_KP=0`, `DEF_KI=0`, `DEF_KD=0`, `DEF_SETPOINT=0`, `DEF_OUT_LIMIT=16384` |

### B.2 Register map (base `0x1000_3000`)

| Off | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | `0x5049_4401` | |
| 0x04 | CTRL | RW | b0=`DEF_EN`, b2=1 | b0 `EN`; b1 `CLR_INT` (SC) clears integrator; b2 `D_SRC` (1 = derivative from gyro `rate`, 0 = derivative of error) |
| 0x08 | KP | RW | `DEF_KP` | Q16.16 |
| 0x0C | KI | RW | `DEF_KI` | Q16.16, **pre-multiplied by Ts** (firmware computes `Ki·Ts`) |
| 0x10 | KD | RW | `DEF_KD` | Q16.16. With `D_SRC=1` it multiplies rad/s. With `D_SRC=0` it must be pre-divided by Ts |
| 0x14 | SETPOINT | RW | `DEF_SETPOINT` | Q16.16 rad (upright = balance trim) |
| 0x18 | INT_LIMIT | RW | 19661 (0.3) | max \|integrator\| |
| 0x1C | OUT_LIMIT | RW | `DEF_OUT_LIMIT` (16384 = 0.25) | output clamp, max 65536. **Start low on the robot** |
| 0x20 | STATUS | RO/W1C | 0 | b0 `SAT` (live), b1 `SAT_STICKY` (W1C), b2 `ACTIVE` |
| 0x24 | P_TERM | RO | 0 | last P term |
| 0x28 | I_TERM | RO | 0 | integrator value |
| 0x2C | D_TERM | RO | 0 | last D term |
| 0x30 | U_OUT | RO | 0 | last output |

### B.3 Architecture

```
err_i ─┬─► [P: Kp·e] ───────────────┐
       ├─► [I: acc += Ki·e ; clamp ±INT_LIMIT ; freeze when saturated same direction ; clear if !run_i] ─► [SUM] ─► [CLAMP ±OUT_LIMIT] ─► pwm_cmd_o
       └─► (D_SRC=0) [D: Kd·(e − e_prev)]                                              ▲
rate_i ──► (D_SRC=1) [D: −Kd·rate]  ──────────────────────────────────────────────────┘
```

- One shared signed 32×32→64 multiplier, time-multiplexed by a small FSM: `IDLE → P → I → D → SUM → OUT` (≈8 cycles). Fewer multipliers = smaller ASIC.
- Every product: `(a*b) >>> 16`. Sum in 34 bits, then clamp.
- **Sign of D term:** error = setpoint − angle ⇒ d(error)/dt = −rate. So with `D_SRC=1`: `D = −(Kd × rate) >>> 16`.
- **Anti-windup (both required):** (1) integrator clamps to ±INT_LIMIT; (2) if the summed output is already clamped and the error has the same sign as the clamp, do not integrate.
- `run_i=0` or `EN=0`: `pwm_cmd_o=0`, integrator = 0, `e_prev = e` (avoids a derivative kick on re-enable). `pwm_cmd_valid_o` still pulses so actuation sees zero commands.
- Latency: `err_valid_i` → `pwm_cmd_valid_o` ≤ 16 cycles.

### B.4 Test vectors (all must pass)

| # | Setup | Input | Expected |
|---|---|---|---|
| 1 | Kp=65536, Ki=Kd=0, OUT_LIMIT=65536 | e=6554 | u=6554, sat=0 |
| 2 | Kp=524288, OUT_LIMIT=16384 | e=13107 | P=104856 → u=16384, sat=1 |
| 3 | Kp=0, Ki=655, INT_LIMIT big | e=6554 ×10 samples | I += 65 per sample ⇒ I=650, u=650 after the 10th |
| 4 | Kp=Ki=0, Kd=6554, D_SRC=1 | rate=65536 | D=−6554, u=−6554 |
| 5 | as #3 then `run_i=0` | | u=0 and I_TERM=0 next sample |
| 6 | Ki large, e large, OUT_LIMIT=16384 | 100 samples | integrator never exceeds INT_LIMIT and stops growing while clamped |
| 7 | D_SRC=0, Kd=65536 | e: 0 → 6554 | D=6554 on the first sample after |

**Golden model:** write `model/pid.py` (about 20 lines) with the same integer maths; run 1000 random vectors through RTL and Python; outputs must be identical. Python's `>>` is a floor shift, identical to Verilog `>>>` on signed values.

### B.5 Verification steps
1. Directed TB with the table above.
2. Random TB vs golden model (dump vectors to file, compare).
3. Closed-loop sim: simple inverted-pendulum model in the TB (a few lines of fixed-point) driving `err_i`/`rate_i` from your own `pwm_cmd_o`. It should settle for sane gains; this catches sign errors before the robot does.
4. FPGA: ILA/SignalTap on `err_i`, `rate_i`, `pwm_cmd_o`.

### B.6 Tuning recipe (robot on a stand first, wheels off the ground)
1. `OUT_LIMIT=0.25`, Ki=Kd=0. Raise Kp until the robot just starts to oscillate, then reduce ≈30 %.
2. Add Kd (gyro) until oscillation is damped. If it buzzes, Kd is too high or the rate sign is wrong.
3. Add a small Ki to remove slow drift. Adjust `SETPOINT` until it balances upright by itself.
4. Only then raise `OUT_LIMIT`.
Check signs first: tilt forward ⇒ angle > 0 ⇒ err < 0 ⇒ the wheels must drive forward. If not, flip `INV_ANGLE`/`INV_RATE` (SENS bank) or the motor direction bits (PWM bank) **before** touching gains.

---

## C. `cpu_subsystem` (Ibex)

**Split of Ibex work:** you = core configuration, wrapper, interrupts, firmware. Kaushal = `bus_interconnect` + the simulation harness. Meet in the middle at "firmware reads all six ID registers".

### C.1 Get and configure Ibex
1. `git submodule add https://github.com/lowRISC/ibex.git vendor/ibex`; pin one commit and never float it.
2. Build the file list from Ibex's own `ibex_core.core` / `ibex_top` FuseSoC file list (only `rtl/` + needed `vendor/lowrisc_ip/` primitives; ignore `dv/ syn/ formal/ lint/`).
3. **Read the `small` entry in Ibex's `ibex_configs.yaml` and copy those parameter values.** Do not guess parameter names from memory. Ibex versions differ.
4. Register file: `RegFileFF` or `RegFileFPGA` for the FPGA build; `RegFileLatch` for the ASIC flow (needs clock-gating support).
5. Keep off: ICache, PMP, debug triggers, secure/ECC features, branch target ALU, writeback stage (as in `small`).

> **Correction to my earlier note:** I told you `ibex_multdiv_slow.sv` is the "3-cycle" unit. I am no longer confident of that. In Ibex the *fast* multiplier is the multi-cycle (≈3-cycle) one and *slow* is an iterative one. Use whichever `RV32M` value the `small` entry names, and check Ibex's `Parameters` documentation page for that exact value.

### C.2 Wrapper port wiring (`cpu_subsystem`)

| `ibex_top` port | Connect to |
|---|---|
| `clk_i` / `rst_ni` | `clk` / `rst_n` |
| `test_en_i`, `hart_id_i` | `0` |
| `boot_addr_i` | `32'h0000_0000` (reset vector = `0x80`) |
| `instr_req_o / instr_gnt_i / instr_rvalid_i / instr_addr_o / instr_rdata_i / instr_err_i` | `bus_interconnect` |
| `data_req_o / data_gnt_i / data_rvalid_i / data_we_o / data_be_o / data_addr_o / data_wdata_o / data_rdata_i / data_err_i` | `bus_interconnect` |
| `irq_timer_i` | `irq_timer` |
| `irq_external_i` | `irq_fault` |
| `irq_software_i`, `irq_fast_i`, `irq_nm_i` | `0` |
| `debug_req_i` | `0` |
| `fetch_enable_i` | "on" (encoding depends on version: `1'b1` or the MuBi "on" value) |
| integrity ports (`*_intg_*`), scan/RAM-config | inputs `0`, outputs unconnected (unless SecureIbex is on) |

**Copy tie-offs from `vendor/ibex/examples/simple_system/rtl/ibex_simple_system.sv`. It is the reference for a working instantiation.**

### C.3 Boot / memory facts
- Reset PC = `boot_addr + 0x80` = `0x80`. Vector table at `0x00–0x7F` (vectored mode: exception entry at `base+0`, interrupt *n* at `base+4n`; machine timer = 7, machine external = 11).
- Firmware in ROM (read-only); `.data` initial values live in ROM and are copied to RAM at boot; `.bss` zeroed; stack top `0x2000_1000`.

---

## D. Firmware

### D.1 Files
`sw/startup.S` (vector table + reset handler) · `sw/link.ld` (ROM `0x0` 8K, RAM `0x2000_0000` 4K) · `sw/include/ecu_regs.h` (every register offset/bit from the contract and sheets, `volatile uint32_t*`) · `sw/main.c` · `sw/Makefile`.
Toolchain: lowRISC/xPack RISC-V GCC, `-march=rv32imc_zicsr -mabi=ilp32 -nostdlib -ffreestanding -Os`. Vedam provides `bin2hex.py`, which turns the built `.bin` into the ROM init file.

### D.2 Boot sequence in `main()`
1. Read all six ID registers, compare with the contract, otherwise blink the error pattern on `DBG_OUT`.
2. Configure timer: `TICK_PERIOD` (default is fine), `IRQ_DIV`, enable.
3. Configure I2C bank, wait for `INIT_DONE`.
4. Start gyro calibration; wait for `CAL_DONE` (robot must be still).
5. Load Kp/Ki/Kd, `SETPOINT`, `INT_LIMIT`, `OUT_LIMIT` (low), enable PID.
6. Set safety limits (tilt, timeouts), enable watchdog, then write `ARM=1`.
7. Loop: kick watchdog, log telemetry to a RAM ring buffer, service timer IRQ (10 Hz housekeeping), on fault IRQ read fault flags, log, apply the re-arm policy.
Hardware keeps the loop running even if the CPU stalls. Only the watchdog notices a dead CPU.

### D.3 Firmware test ladder
T0 read IDs → T1 write/read RAM → T2 LED via `DBG_OUT` → T3 timer IRQ counts ticks → T4 read IMU raw registers → T5 full boot sequence.

---

## E. Lead duties

- Approve/reject CRs within 24 h; keep the change log.
- Review PRs (Kaushal reviews first). Safety block: you review personally.
- Monday stand-up, Friday demo, Sunday status. Keep a `docs/decisions.md` log.
- Watch for silent blockers: anyone who has not committed in 3 days gets a message.

## Your timeline

| Week | You |
|---|---|
| W0–1 | sign off contract; build `ecu_soc_top` skeleton + lint script; get Ibex Simple System running in simulation (with Kaushal) |
| W2–3 | `hw_pid_accel` RTL + directed TB + golden model; firmware skeleton compiles |
| W4 | PID vs pipeline pair test (Dipiksha); PID → PWM pair test (Jaydev); random TB |
| W5–6 | Wing A on FPGA (`HW_ONLY=1`), tuning on the stand; ILA captures |
| W7–8 | `cpu_subsystem` on the real bus; firmware T0–T5; close the loop with the CPU |

## DOs / DON'Ts
**DO** freeze ports before logic · keep PID gains as registers (never as constants) · log every tuning run · limit `OUT_LIMIT` on first power-up · demand the same PR checklist from yourself.
**DON'T** tune on the ground · touch teammates' folders · let the CPU into the real-time path · float the Ibex submodule commit · postpone the skeleton.
