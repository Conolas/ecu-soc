# Sheet 02 — Kaushal: `i2c_sensor_subsystem`, `bus_interconnect`, Ibex sim harness, deputy lead

Read `00_ECU_Interface_Contract_v1.0.md` first.

**Role:** second pillar. You own the sensor input of the whole system and the bus that lets the CPU talk to everything. You are also the **on-site deputy**: you review the others' PRs and keep them unblocked while Conolas is remote.

| # | Deliverable | Done when |
|---|---|---|
| A | `i2c_sensor_subsystem` (I2C master + MPU-6050 sequencer + I2C regs) | reads a 14-byte sample every tick, on model and on real MPU-6050 |
| B | `bus_interconnect` | all address/protocol tests pass with ROM/RAM/regs |
| C | Ibex simulation harness (`tb_cpu_bus`) | test firmware runs on Ibex through your bus |
| D | Deputy: PR reviews | 24 h turnaround |

---

## A. `i2c_sensor_subsystem`

### A.1 Ports (frozen)

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | |
| `s_sel_i s_we_i s_be_i[3:0] s_addr_i[11:0] s_wdata_i[31:0]` / `s_rdata_o[31:0]` | | | slave bus (I2C bank) |
| `control_tick_i` | in | 1 | pulse from `timer_unit`: start a sample read |
| `scl_i`, `sda_i` | in | 1 | raw pin inputs (2-FF synchronise inside) |
| `scl_drive_low_o`, `sda_drive_low_o` | out | 1 | 1 = pull low, 0 = release. Never drive a 1 |
| `imu_valid_o` | out | 1 | pulse: complete sample ready |
| `imu_ax_o imu_ay_o imu_az_o imu_gx_o imu_gy_o imu_gz_o` | out | 16 each | signed raw, stable after `imu_valid_o` until next sample |
| `imu_busy_o` | out | 1 | high from tick until `imu_valid_o`/`imu_err_o` |
| `imu_err_o` | out | 1 | pulse: transaction failed |
| `imu_init_done_o` | out | 1 | level: MPU-6050 configured |
| parameters | | | `DEF_EN=0`, `CLK_DIV_DEF=31`, `DEV_ADDR_DEF=7'h68` |

### A.2 Register map (base `0x1000_1000`)

| Off | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | `0x4932_4301` | |
| 0x04 | CTRL | RW | b0=`DEF_EN` | b0 `EN` (reader active); b1 `REINIT` (SC) rerun init; b2 `SOFT_TRIG` (SC) start a read without a tick |
| 0x08 | CLK_DIV | RW | 31 | `f_scl = f_clk / (4·(CLK_DIV+1))` ⇒ 390.6 kHz at 50 MHz |
| 0x0C | STATUS | RO/W1C | 0 | b0 `INIT_DONE`, b1 `BUSY`, b2 `ERR_STICKY` (W1C), b3 `TIMEOUT_STICKY` (W1C) |
| 0x10 | ERR_COUNT | RO | 0 | saturating count of failed transactions |
| 0x14 | SAMPLE_COUNT | RO | 0 | good samples since reset |
| 0x18 | DEV_ADDR | RW | 0x68 | 7-bit device address |
| 0x20 | AX | RO | 0 | sign-extended to 32 |
| 0x24 | AY | RO | 0 | |
| 0x28 | AZ | RO | 0 | |
| 0x2C | GX | RO | 0 | |
| 0x30 | GY | RO | 0 | |
| 0x34 | GZ | RO | 0 | |

### A.3 Architecture — three layers

```
control_tick_i ──► [ mpu6050_ctrl : init FSM + burst-read sequencer ] ──cmd/rsp──► [ i2c_master : byte engine ] ──► SCL/SDA pins
                                  │ assembles 6×16-bit, pulses imu_valid_o                 ▲ 2-FF synchronisers on scl_i/sda_i
                                  └── [ i2c_regs ]  ◄── slave bus
```

**Layer 1 — `i2c_master` (byte engine).** Recommended internal interface (yours to change): `cmd_valid/ready`, `cmd_start`, `cmd_stop`, `cmd_write`, `cmd_read`, `cmd_nack` (send NACK after this read byte), `cmd_data[7:0]`; response `rsp_valid`, `rsp_data[7:0]`, `rsp_slave_ack`. Bit-level FSM with a 4-phase tick from the `CLK_DIV` divider: START, 8 data bits, ACK slot, repeated START, STOP. Support **clock stretching** (wait until `scl_i` really is high before continuing). Never drive SDA/SCL high, only release.

**Layer 2 — `mpu6050_ctrl` (sequencer).**
Init (after reset, once `EN`, or on `REINIT`):
1. Wait ≈50 ms power-up delay (parameter).
2. Read `WHO_AM_I` (`0x75`), expect `0x68`. Mismatch ⇒ `ERR_STICKY`, retry.
3. Write `PWR_MGMT_1 (0x6B) = 0x01` — the chip **powers up asleep**; skipping this is the #1 cause of "all zeros".
4. Write `SMPLRT_DIV (0x19) = 0x00`, `CONFIG (0x1A) = 0x02`, `GYRO_CONFIG (0x1B) = 0x00`, `ACCEL_CONFIG (0x1C) = 0x00`.
5. `imu_init_done_o = 1`.
Per tick: START, `addr+W`, reg `0x3B`, repeated START, `addr+R`, read 14 bytes (ACK the first 13, NACK the 14th), STOP. Byte order (high byte first): `ax = {b0,b1}`, `ay = {b2,b3}`, `az = {b4,b5}`, temp `{b6,b7}` (discard), `gx = {b8,b9}`, `gy = {b10,b11}`, `gz = {b12,b13}`.
Only after the STOP: update the six output registers together and pulse `imu_valid_o`. **Never** output a half-updated sample.
Errors: NACK or a transaction longer than 1.5 ms ⇒ abort, send STOP, pulse `imu_err_o`, count it, skip this sample. If the bus is stuck (SDA low), clock out 9 SCL pulses then STOP. After 3 consecutive errors, re-run init.
If a tick arrives while busy, ignore it (the timer flags the overrun via `imu_busy_o`).

**Layer 3 — `i2c_regs`.** The map above.

### A.4 Expected behaviour (numbers you can check)
- `CLK_DIV=31`: SCL ≈ 390.6 kHz (period 2.56 µs). A full burst ≈ 400 µs; **`control_tick` → `imu_valid` latency must be in 380–440 µs**.
- WHO_AM_I read returns `0x68` on the model.
- Model returns `ax=0x1000, ay=0xF000, az=0x4000, gx=0x0083, gy=0xFF00, gz=0x0000` ⇒ outputs 4096, −4096, 16384, 131, −256, 0.
- Kill the model (no ACK) ⇒ `imu_err_o` pulse, `ERR_COUNT` increments, no `imu_valid_o`.

### A.5 Verification
1. Write `tb/mpu6050_model.v`: behavioural I2C slave with a 128-byte register file, address `0x68`, repeated-START, auto-increment, `WHO_AM_I=0x68`, sleep bit behaviour (reads 0 while asleep), optional NACK and clock-stretch injection.
2. `tb_i2c_sensor_subsystem.v` self-checks: init sequence writes exactly the values above (model logs them), sample decode, latency window, error injection, `REINIT`, register reads.
3. FPGA: 4.7 kΩ pull-ups to 3.3 V (GY-521 boards already have them). **Never connect 5 V to FPGA pins.** Check with a logic analyser/ILA: SCL frequency, ACK on every byte, values change when the board is tilted.

---

## B. `bus_interconnect`

### B.1 Ports (frozen)

| Group | Ports |
|---|---|
| Common | `clk`, `rst_n` |
| Ibex instr (from CPU) | `instr_req_i`, `instr_addr_i[31:0]` → `instr_gnt_o`, `instr_rvalid_o`, `instr_rdata_o[31:0]`, `instr_err_o` |
| Ibex data (from CPU) | `data_req_i`, `data_we_i`, `data_be_i[3:0]`, `data_addr_i[31:0]`, `data_wdata_i[31:0]` → `data_gnt_o`, `data_rvalid_o`, `data_rdata_o[31:0]`, `data_err_o` |
| ROM instr port | `rom_ia_req_o`, `rom_ia_addr_o[12:0]`, `rom_ia_rdata_i[31:0]` |
| ROM data-read | `rom_sel_o`, `rom_addr_o[12:0]`, `rom_rdata_i[31:0]` |
| RAM | `ram_sel_o`, `ram_we_o`, `ram_be_o[3:0]`, `ram_addr_o[11:0]`, `ram_wdata_o[31:0]`, `ram_rdata_i[31:0]` |
| Each bank `tmr`, `i2c`, `sens`, `pid`, `pwm`, `saf` | `<b>_sel_o`, `<b>_we_o`, `<b>_be_o[3:0]`, `<b>_addr_o[11:0]`, `<b>_wdata_o[31:0]`, `<b>_rdata_i[31:0]` |

### B.2 Behaviour
- **Instruction side:** only ROM is fetchable. `instr_gnt_o = instr_req_i` (same cycle); `instr_rvalid_o` next cycle with `rom_ia_rdata_i`. Any address outside ROM ⇒ `instr_rvalid_o` with `instr_err_o=1`.
- **Data side:** decode `data_addr_i` per the memory map (contract §4). `data_gnt_o = data_req_i` (same cycle). One cycle later: `data_rvalid_o=1` and `data_rdata_o` = the **registered** selected slave read data. Register the select (`sel_q`) so back-to-back accesses return the right data.
- **Writes also get `rvalid`.** Ibex waits for it.
- **Errors:** unmapped address, or write to ROM ⇒ `rvalid` with `err=1`, no slave selected, no side effect. No access may ever hang the CPU.
- Slave selects are one-cycle pulses aligned with the request.
- Window constants (`ROM_BASE`, `ROM_MASK`, …) as `localparam`s in one place.

### B.3 Test vectors

| # | Access | Expected |
|---|---|---|
| 1 | write `0xDEADBEEF` to `0x2000_0010`, read back | same value, `err=0` |
| 2 | byte write `0xAA` to `0x2000_0011` (`be=4'b0010`) | only that byte changes |
| 3 | read `0x1000_0000`, `0x1000_1000`, … `0x1000_5000` | the six ID values |
| 4 | read `0x3000_0000` | `err=1`, no hang |
| 5 | write to `0x0000_0010` (ROM) | `err=1` |
| 6 | 3 back-to-back reads (RAM, TMR, PID) | each response matches its own address |
| 7 | instr fetch `0x0000_0080` | ROM word, `err=0`; fetch `0x2000_0000` ⇒ `err=1` |

Use a simple TB master that mimics Ibex timing, using dummy slave models (Vedam's memories + a stub register file returning the ID).

---

## C. Ibex simulation harness (`tb_cpu_bus`)

This is your half of the CPU workload.

1. **Week 1:** get the stock Ibex "Simple System" (`vendor/ibex/examples/simple_system`) building and running "hello world" (Verilator, or the lab simulator). Get the RISC-V GCC toolchain first (lowRISC releases). Goal: you can compile a C file and see it execute.
2. **Week 3–4:** replace Simple System's memory/bus with **our** `rom_dp`, `ram_sp`, `bus_interconnect` and stub banks. Instantiate Ibex through Conolas's `cpu_subsystem`.
3. Test firmware (tiny C): read the six IDs and check them; write/read RAM; write a bank register and read it back; count to 100 and write a "PASS" value to a magic RAM address the TB watches.
4. Hand the working harness to Conolas so he can run real firmware in it.

## D. Deputy duties

- Review every PR within 24 h with the checklist (contract §9): ports match, lint, `TB_PASS`, no latches, reset values, README.
- Review, don't rewrite. Write comments; the owner fixes.
- Safety block (`safety_fault_monitor`): review line by line, then Conolas reviews again.
- Merge to `main` only when the checklist is fully ticked. Keep `main` always lint-clean.
- If someone is blocked for more than a day, help them, then tell Conolas.

## Your timeline

| Week | You |
|---|---|
| W1 | I2C shell with frozen ports merged; `mpu6050_model.v`; Ibex Simple System runs hello-world |
| W2 | byte engine + TB; read WHO_AM_I in sim |
| W3 | sequencer + regs; full sim latency test; `bus_interconnect` RTL + TB |
| W4 | pair test with Dipiksha (tick → pipeline); pair test with Vedam (bus ↔ memories) |
| W5–6 | real MPU-6050 on FPGA; help bring up Wing A |
| W7–8 | `tb_cpu_bus` with real firmware; CPU on FPGA with Conolas |

## DOs / DON'Ts
**DO** publish the sample only after STOP · test NACK, timeout and stuck-bus · keep pins open-drain · keep `rvalid` timing exact.
**DON'T** drive SDA/SCL high · leave the MPU asleep · let any address hang the bus · edit others' code during review · add ports to your wrapper.
