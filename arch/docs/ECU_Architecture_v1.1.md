# ecu_soc_top: Architecture Specification v1.1 (generated)

GENERATED from `arch/arch_data.py` and `arch/arch_text.py` by `arch/gen_md.py`. Do not edit by hand: change the model, run `python3 arch_check.py && python3 gen_md.py`. The checker proves: every port is connected to exactly one net, widths match, directions match, every net has one driver, the memory map has no overlap, every register offset is unique, the firmware header matches the registers, and the contract signals are all present.

## 1. Architecture change requests v1.0 -> v1.1

| ID | Change | Why | Effect |
|---|---|---|---|
| ACR-1 | Input synchronisers live INSIDE ecu_soc_top | v1.0 had the board wrapper synchronise estop/arm/bench AND safety synchronise estop/arm again (double sync, wrong for the ASIC where there is no wrapper). Now: raw pins enter the SoC; safety_fault_monitor synchronises estop_n_i and arm_sw_i; actuation_subsystem synchronises bench_en_i and bench_sel_i (2-FF each); i2c already synchronises scl_i/sda_i; clk_rst_gen handles rst_n_in and pll_locked_i. ecu_fpga_top does NO synchronisation. | internal to safety and actuation; no port change; removes logic from the FPGA-only wrapper |
| ACR-2 | sensor_pipeline gets control_tick_i (1 bit) | The SENS STATUS bit DATA_FRESH ("a sample arrived in the last 2 ticks") needs a time base, but sensor_pipeline had no tick input. Add control_tick_i from timer_unit. | one new input port on sensor_pipeline; one more load on net control_tick |
| ACR-3 | SAFE.CTRL reset value made unambiguous | v1.0 said "reset 0" and "TILT_EN reset 1". Now: reset = 0x04 | (DEF_WD_EN<<1) | DEF_EN, i.e. TILT_EN=1, ARM=DEF_EN. | documentation only |
| ACR-4 | Debug taps declared | duty_l_o, duty_r_o (actuation), core_sleep_o, double_fault_seen_o (cpu) and dbg_o are debug/bring-up taps: they drive named nets with no functional load. FPGA: ILA probes / LEDs. ASIC: left unconnected (dbg_o may become spare pins). | no port change; classification only |
| ACR-5 | Reset-assertion rule for testbenches and Ibex | Ibex flops reset on the FALLING EDGE of rst_ni (asynchronous). Every testbench must start rst_n high and pull it low after time 0. Our blocks keep synchronous resets; only clk_rst_gen uses async assert. | verification rule |
| ACR-7 | imu_init_done_o is low during (re-)initialisation | The sheet did not say what imu_init_done_o does when the sequencer re-runs init after 3 consecutive errors. Now: it goes low when init starts and high when init completes. Arming needs calib_done_i, which is reachable only after init; imu_init_done_i is also shown on dbg_o[2]. | behaviour clarification inside i2c_sensor_subsystem; no port change |
| ACR-6 | Ibex port list updated to the pinned commit af456e2 | The v1.0 sheet listed an older Ibex port set. cpu_subsystem (starter kit, lint-clean) now ties every port; its external interface is unchanged. | internal to cpu_subsystem |

## 2. Block inventory

| Block | Kind | Owner | Language | Ports | Parameters |
|---|---|---|---|---|---|
| `clk_rst_gen` | rtl | Vedam | Verilog-2001 | 5 | - |
| `timer_unit` | rtl | Dipiksha | Verilog-2001 | 11 | DEF_EN=0, TICK_PERIOD_DEF=97656, IRQ_DIV_DEF=51 |
| `i2c_sensor_subsystem` | rtl | Kaushal | Verilog-2001 | 23 | DEF_EN=0, CLK_DIV_DEF=31, DEV_ADDR_DEF=7'h68 |
| `sensor_pipeline` | rtl | Dipiksha | Verilog-2001 | 23 | DEF_EN=0 |
| `hw_pid_accel` | rtl | Conolas | Verilog-2001 | 16 | DEF_EN=0, DEF_KP=0, DEF_KI=0, DEF_KD=0, DEF_SETPOINT=0, DEF_OUT_LIMIT=16384 |
| `actuation_subsystem` | rtl | Jaydev | Verilog-2001 | 23 | DEF_EN=0, PERIOD_DEF=2500, DEADTIME_DEF=250 |
| `safety_fault_monitor` | rtl | Vedam | Verilog-2001 | 21 | DEF_EN=0, DEF_WD_EN=0 |
| `rom_dp` | rtl | Vedam | Verilog-2001 | 7 | ROM_WORDS=2048, INIT_FILE="firmware.hex" |
| `ram_sp` | rtl | Vedam | Verilog-2001 | 7 | RAM_WORDS=1024 |
| `bus_interconnect` | rtl | Vedam | Verilog-2001 | 65 | ROM_BASE, ROM_MASK, RAM_BASE, BANK_BASE (localparams) |
| `cpu_subsystem` | rtl | Conolas | SystemVerilog (Ibex) | 21 | BOOT_ADDR=32'h0000_0000 |
| `ecu_soc_top` | top | Conolas | Verilog-2001 | 0 | HW_ONLY=0 (1 = Wing A runs without CPU; FPGA phase 1 only) |
| `ecu_fpga_top` | fpga | Jaydev | Verilog-2001 + FPGA primitives | 0 | HW_ONLY (passed to ecu_soc_top) |

## 3. Memory map

| Window | Base | Size | Block | Note |
|---|---|---|---|---|
| ROM | `0x00000000` | 0x2000 | `rom_dp` | 8 KB, firmware (read-only) |
| TMR | `0x10000000` | 0x1000 | `timer_unit` | register bank |
| I2C | `0x10001000` | 0x1000 | `i2c_sensor_subsystem` | register bank |
| SENS | `0x10002000` | 0x1000 | `sensor_pipeline` | register bank |
| PID | `0x10003000` | 0x1000 | `hw_pid_accel` | register bank |
| PWM | `0x10004000` | 0x1000 | `actuation_subsystem` | register bank |
| SAFE | `0x10005000` | 0x1000 | `safety_fault_monitor` | register bank |
| RAM | `0x20000000` | 0x1000 | `ram_sp` | 4 KB, data + stack |

## 4. Top-level pins of ecu_soc_top

| Pin | Dir | Width | Class | Meaning |
|---|---|---|---|---|
| `clk_in` | in | 1 | core | 50 MHz clock (from the FPGA clock generator or the ASIC clock pad) |
| `rst_n_in` | in | 1 | core | external reset, active-low, async |
| `pll_locked_i` | in | 1 | fpga | clock-generator lock; tie 1 if none |
| `estop_n_i` | in | 1 | core | hardware E-stop, active-low |
| `arm_sw_i` | in | 1 | bringup | arm switch (phase 1 only; tie 0 in the final SoC) |
| `bench_en_i` | in | 1 | bringup | open-loop motor bench mode |
| `bench_sel_i` | in | 2 | bringup | bench command select |
| `scl_i` | in | 1 | core | I2C SCL input |
| `sda_i` | in | 1 | core | I2C SDA input |
| `scl_drive_low_o` | out | 1 | core | 1 = pull SCL low |
| `sda_drive_low_o` | out | 1 | core | 1 = pull SDA low |
| `l_rpwm_o` | out | 1 | core | left BTS7960 RPWM |
| `l_lpwm_o` | out | 1 | core | left BTS7960 LPWM |
| `l_r_en_o` | out | 1 | core | left R_EN |
| `l_l_en_o` | out | 1 | core | left L_EN |
| `r_rpwm_o` | out | 1 | core | right BTS7960 RPWM |
| `r_lpwm_o` | out | 1 | core | right BTS7960 LPWM |
| `r_r_en_o` | out | 1 | core | right R_EN |
| `r_l_en_o` | out | 1 | core | right L_EN |
| `dbg_o` | out | 8 | dbg | LEDs / debug pins |

## 5. Master netlist (every net, one driver)

| Net | Width | Kind | Format | Driver | Loads | Class |
|---|---|---|---|---|---|---|
| `clk` | 1 | clock | clock | `clk_rst_gen.clk` | `timer_unit.clk`, `i2c_sensor_subsystem.clk`, `sensor_pipeline.clk`, `hw_pid_accel.clk`, `actuation_subsystem.clk`, `safety_fault_monitor.clk`, `rom_dp.clk`, `ram_sp.clk`, `bus_interconnect.clk`, `cpu_subsystem.clk` | core |
| `rst_n` | 1 | level | level | `clk_rst_gen.rst_n` | `timer_unit.rst_n`, `i2c_sensor_subsystem.rst_n`, `sensor_pipeline.rst_n`, `hw_pid_accel.rst_n`, `actuation_subsystem.rst_n`, `safety_fault_monitor.rst_n`, `bus_interconnect.rst_n`, `cpu_subsystem.rst_n` | core |
| `clk_in` | 1 | clock | clock | `pin clk_in` | `clk_rst_gen.clk_in` | core |
| `rst_n_in` | 1 | level | level | `pin rst_n_in` | `clk_rst_gen.rst_n_in` | core |
| `pll_locked_i` | 1 | level | level | `pin pll_locked_i` | `clk_rst_gen.pll_locked_i` | fpga |
| `control_tick` | 1 | pulse | pulse | `timer_unit.control_tick_o` | `i2c_sensor_subsystem.control_tick_i`, `sensor_pipeline.control_tick_i`, `safety_fault_monitor.control_tick_i` | core |
| `imu_valid` | 1 | pulse | pulse | `i2c_sensor_subsystem.imu_valid_o` | `sensor_pipeline.imu_valid_i`, `safety_fault_monitor.imu_valid_i` | core |
| `imu_ax` | 16 | data | int16 | `i2c_sensor_subsystem.imu_ax_o` | `sensor_pipeline.imu_ax_i` | core |
| `imu_ay` | 16 | data | int16 | `i2c_sensor_subsystem.imu_ay_o` | `sensor_pipeline.imu_ay_i` | core |
| `imu_az` | 16 | data | int16 | `i2c_sensor_subsystem.imu_az_o` | `sensor_pipeline.imu_az_i` | core |
| `imu_gx` | 16 | data | int16 | `i2c_sensor_subsystem.imu_gx_o` | `sensor_pipeline.imu_gx_i` | core |
| `imu_gy` | 16 | data | int16 | `i2c_sensor_subsystem.imu_gy_o` | `sensor_pipeline.imu_gy_i` | core |
| `imu_gz` | 16 | data | int16 | `i2c_sensor_subsystem.imu_gz_o` | `sensor_pipeline.imu_gz_i` | core |
| `imu_busy` | 1 | level | level | `i2c_sensor_subsystem.imu_busy_o` | `timer_unit.sched_busy_i` | core |
| `imu_err` | 1 | pulse | pulse | `i2c_sensor_subsystem.imu_err_o` | `safety_fault_monitor.imu_err_i` | core |
| `imu_init_done` | 1 | level | level | `i2c_sensor_subsystem.imu_init_done_o` | `sensor_pipeline.imu_init_done_i`, `safety_fault_monitor.imu_init_done_i` | core |
| `setpoint` | 32 | data | Q16.16 rad | `hw_pid_accel.setpoint_o` | `sensor_pipeline.setpoint_i` | core |
| `pipe_valid` | 1 | pulse | pulse | `sensor_pipeline.pipe_valid_o` | `hw_pid_accel.err_valid_i`, `safety_fault_monitor.pipe_valid_i` | core |
| `angle` | 32 | data | Q16.16 rad | `sensor_pipeline.angle_o` | `safety_fault_monitor.angle_i` | core |
| `err` | 32 | data | Q16.16 | `sensor_pipeline.err_o` | `hw_pid_accel.err_i` | core |
| `rate` | 32 | data | Q16.16 rad/s | `sensor_pipeline.rate_o` | `hw_pid_accel.rate_i` | core |
| `calib_done` | 1 | level | level | `sensor_pipeline.calib_done_o` | `safety_fault_monitor.calib_done_i` | core |
| `pwm_cmd_valid` | 1 | pulse | pulse | `hw_pid_accel.pwm_cmd_valid_o` | `actuation_subsystem.cmd_valid_i` | core |
| `pwm_cmd` | 32 | data | Q16.16 [-1,+1] | `hw_pid_accel.pwm_cmd_o` | `actuation_subsystem.cmd_i` | core |
| `pid_sat` | 1 | level | level | `hw_pid_accel.pid_sat_o` | `safety_fault_monitor.pid_sat_i` | core |
| `pwm_enable` | 1 | level | level | `safety_fault_monitor.pwm_enable_o` | `hw_pid_accel.run_i`, `actuation_subsystem.pwm_enable_i` | core |
| `irq_timer` | 1 | level | level | `timer_unit.irq_timer_o` | `cpu_subsystem.irq_timer_i` | core |
| `irq_fault` | 1 | level | level | `safety_fault_monitor.irq_fault_o` | `cpu_subsystem.irq_fault_i` | core |
| `estop_n_i` | 1 | level | level | `pin estop_n_i` | `safety_fault_monitor.estop_n_i` | core |
| `arm_sw_i` | 1 | level | level | `pin arm_sw_i` | `safety_fault_monitor.arm_sw_i` | bringup |
| `bench_en_i` | 1 | level | level | `pin bench_en_i` | `actuation_subsystem.bench_en_i` | bringup |
| `bench_sel_i` | 2 | data | code | `pin bench_sel_i` | `actuation_subsystem.bench_sel_i` | bringup |
| `scl_i` | 1 | level | level | `pin scl_i` | `i2c_sensor_subsystem.scl_i` | core |
| `sda_i` | 1 | level | level | `pin sda_i` | `i2c_sensor_subsystem.sda_i` | core |
| `scl_drive_low_o` | 1 | level | level | `i2c_sensor_subsystem.scl_drive_low_o` | `pin scl_drive_low_o` | core |
| `sda_drive_low_o` | 1 | level | level | `i2c_sensor_subsystem.sda_drive_low_o` | `pin sda_drive_low_o` | core |
| `l_rpwm_o` | 1 | level | level | `actuation_subsystem.l_rpwm_o` | `pin l_rpwm_o` | core |
| `l_lpwm_o` | 1 | level | level | `actuation_subsystem.l_lpwm_o` | `pin l_lpwm_o` | core |
| `l_r_en_o` | 1 | level | level | `actuation_subsystem.l_r_en_o` | `pin l_r_en_o` | core |
| `l_l_en_o` | 1 | level | level | `actuation_subsystem.l_l_en_o` | `pin l_l_en_o` | core |
| `r_rpwm_o` | 1 | level | level | `actuation_subsystem.r_rpwm_o` | `pin r_rpwm_o` | core |
| `r_lpwm_o` | 1 | level | level | `actuation_subsystem.r_lpwm_o` | `pin r_lpwm_o` | core |
| `r_r_en_o` | 1 | level | level | `actuation_subsystem.r_r_en_o` | `pin r_r_en_o` | core |
| `r_l_en_o` | 1 | level | level | `actuation_subsystem.r_l_en_o` | `pin r_l_en_o` | core |
| `dbg_o` | 8 | data | LED bits | `safety_fault_monitor.dbg_o` | `pin dbg_o` | dbg |
| `duty_l` | 16 | data | counts | `actuation_subsystem.duty_l_o` | (debug tap) | dbg |
| `duty_r` | 16 | data | counts | `actuation_subsystem.duty_r_o` | (debug tap) | dbg |
| `cpu_core_sleep` | 1 | level | level | `cpu_subsystem.core_sleep_o` | (debug tap) | dbg |
| `cpu_double_fault` | 1 | level | level | `cpu_subsystem.double_fault_seen_o` | (debug tap) | dbg |
| `instr_req` | 1 | bus | level | `cpu_subsystem.instr_req_o` | `bus_interconnect.instr_req_i` | core |
| `instr_addr` | 32 | bus | byte addr | `cpu_subsystem.instr_addr_o` | `bus_interconnect.instr_addr_i` | core |
| `instr_gnt` | 1 | bus | level | `bus_interconnect.instr_gnt_o` | `cpu_subsystem.instr_gnt_i` | core |
| `instr_rvalid` | 1 | bus | pulse | `bus_interconnect.instr_rvalid_o` | `cpu_subsystem.instr_rvalid_i` | core |
| `instr_rdata` | 32 | bus | word | `bus_interconnect.instr_rdata_o` | `cpu_subsystem.instr_rdata_i` | core |
| `instr_err` | 1 | bus | level | `bus_interconnect.instr_err_o` | `cpu_subsystem.instr_err_i` | core |
| `data_req` | 1 | bus | level | `cpu_subsystem.data_req_o` | `bus_interconnect.data_req_i` | core |
| `data_we` | 1 | bus | level | `cpu_subsystem.data_we_o` | `bus_interconnect.data_we_i` | core |
| `data_be` | 4 | bus | mask | `cpu_subsystem.data_be_o` | `bus_interconnect.data_be_i` | core |
| `data_addr` | 32 | bus | byte addr | `cpu_subsystem.data_addr_o` | `bus_interconnect.data_addr_i` | core |
| `data_wdata` | 32 | bus | word | `cpu_subsystem.data_wdata_o` | `bus_interconnect.data_wdata_i` | core |
| `data_gnt` | 1 | bus | level | `bus_interconnect.data_gnt_o` | `cpu_subsystem.data_gnt_i` | core |
| `data_rvalid` | 1 | bus | pulse | `bus_interconnect.data_rvalid_o` | `cpu_subsystem.data_rvalid_i` | core |
| `data_rdata` | 32 | bus | word | `bus_interconnect.data_rdata_o` | `cpu_subsystem.data_rdata_i` | core |
| `data_err` | 1 | bus | level | `bus_interconnect.data_err_o` | `cpu_subsystem.data_err_i` | core |
| `rom_ia_req` | 1 | bus | pulse | `bus_interconnect.rom_ia_req_o` | `rom_dp.ia_req_i` | core |
| `rom_ia_addr` | 13 | bus | byte addr | `bus_interconnect.rom_ia_addr_o` | `rom_dp.ia_addr_i` | core |
| `rom_ia_rdata` | 32 | bus | word | `rom_dp.ia_rdata_o` | `bus_interconnect.rom_ia_rdata_i` | core |
| `rom_sel` | 1 | bus | pulse | `bus_interconnect.rom_sel_o` | `rom_dp.s_sel_i` | core |
| `rom_addr` | 13 | bus | byte addr | `bus_interconnect.rom_addr_o` | `rom_dp.s_addr_i` | core |
| `rom_rdata` | 32 | bus | word | `rom_dp.s_rdata_o` | `bus_interconnect.rom_rdata_i` | core |
| `ram_sel` | 1 | bus | pulse | `bus_interconnect.ram_sel_o` | `ram_sp.s_sel_i` | core |
| `ram_we` | 1 | bus | level | `bus_interconnect.ram_we_o` | `ram_sp.s_we_i` | core |
| `ram_be` | 4 | bus | mask | `bus_interconnect.ram_be_o` | `ram_sp.s_be_i` | core |
| `ram_addr` | 12 | bus | byte offset | `bus_interconnect.ram_addr_o` | `ram_sp.s_addr_i` | core |
| `ram_wdata` | 32 | bus | word | `bus_interconnect.ram_wdata_o` | `ram_sp.s_wdata_i` | core |
| `ram_rdata` | 32 | bus | word | `ram_sp.s_rdata_o` | `bus_interconnect.ram_rdata_i` | core |
| `tmr_sel` | 1 | bus | pulse | `bus_interconnect.tmr_sel_o` | `timer_unit.s_sel_i` | core |
| `tmr_we` | 1 | bus | level | `bus_interconnect.tmr_we_o` | `timer_unit.s_we_i` | core |
| `tmr_be` | 4 | bus | mask | `bus_interconnect.tmr_be_o` | `timer_unit.s_be_i` | core |
| `tmr_addr` | 12 | bus | byte offset | `bus_interconnect.tmr_addr_o` | `timer_unit.s_addr_i` | core |
| `tmr_wdata` | 32 | bus | word | `bus_interconnect.tmr_wdata_o` | `timer_unit.s_wdata_i` | core |
| `tmr_rdata` | 32 | bus | word | `timer_unit.s_rdata_o` | `bus_interconnect.tmr_rdata_i` | core |
| `i2c_sel` | 1 | bus | pulse | `bus_interconnect.i2c_sel_o` | `i2c_sensor_subsystem.s_sel_i` | core |
| `i2c_we` | 1 | bus | level | `bus_interconnect.i2c_we_o` | `i2c_sensor_subsystem.s_we_i` | core |
| `i2c_be` | 4 | bus | mask | `bus_interconnect.i2c_be_o` | `i2c_sensor_subsystem.s_be_i` | core |
| `i2c_addr` | 12 | bus | byte offset | `bus_interconnect.i2c_addr_o` | `i2c_sensor_subsystem.s_addr_i` | core |
| `i2c_wdata` | 32 | bus | word | `bus_interconnect.i2c_wdata_o` | `i2c_sensor_subsystem.s_wdata_i` | core |
| `i2c_rdata` | 32 | bus | word | `i2c_sensor_subsystem.s_rdata_o` | `bus_interconnect.i2c_rdata_i` | core |
| `sens_sel` | 1 | bus | pulse | `bus_interconnect.sens_sel_o` | `sensor_pipeline.s_sel_i` | core |
| `sens_we` | 1 | bus | level | `bus_interconnect.sens_we_o` | `sensor_pipeline.s_we_i` | core |
| `sens_be` | 4 | bus | mask | `bus_interconnect.sens_be_o` | `sensor_pipeline.s_be_i` | core |
| `sens_addr` | 12 | bus | byte offset | `bus_interconnect.sens_addr_o` | `sensor_pipeline.s_addr_i` | core |
| `sens_wdata` | 32 | bus | word | `bus_interconnect.sens_wdata_o` | `sensor_pipeline.s_wdata_i` | core |
| `sens_rdata` | 32 | bus | word | `sensor_pipeline.s_rdata_o` | `bus_interconnect.sens_rdata_i` | core |
| `pid_sel` | 1 | bus | pulse | `bus_interconnect.pid_sel_o` | `hw_pid_accel.s_sel_i` | core |
| `pid_we` | 1 | bus | level | `bus_interconnect.pid_we_o` | `hw_pid_accel.s_we_i` | core |
| `pid_be` | 4 | bus | mask | `bus_interconnect.pid_be_o` | `hw_pid_accel.s_be_i` | core |
| `pid_addr` | 12 | bus | byte offset | `bus_interconnect.pid_addr_o` | `hw_pid_accel.s_addr_i` | core |
| `pid_wdata` | 32 | bus | word | `bus_interconnect.pid_wdata_o` | `hw_pid_accel.s_wdata_i` | core |
| `pid_rdata` | 32 | bus | word | `hw_pid_accel.s_rdata_o` | `bus_interconnect.pid_rdata_i` | core |
| `pwm_sel` | 1 | bus | pulse | `bus_interconnect.pwm_sel_o` | `actuation_subsystem.s_sel_i` | core |
| `pwm_we` | 1 | bus | level | `bus_interconnect.pwm_we_o` | `actuation_subsystem.s_we_i` | core |
| `pwm_be` | 4 | bus | mask | `bus_interconnect.pwm_be_o` | `actuation_subsystem.s_be_i` | core |
| `pwm_addr` | 12 | bus | byte offset | `bus_interconnect.pwm_addr_o` | `actuation_subsystem.s_addr_i` | core |
| `pwm_wdata` | 32 | bus | word | `bus_interconnect.pwm_wdata_o` | `actuation_subsystem.s_wdata_i` | core |
| `pwm_rdata` | 32 | bus | word | `actuation_subsystem.s_rdata_o` | `bus_interconnect.pwm_rdata_i` | core |
| `saf_sel` | 1 | bus | pulse | `bus_interconnect.saf_sel_o` | `safety_fault_monitor.s_sel_i` | core |
| `saf_we` | 1 | bus | level | `bus_interconnect.saf_we_o` | `safety_fault_monitor.s_we_i` | core |
| `saf_be` | 4 | bus | mask | `bus_interconnect.saf_be_o` | `safety_fault_monitor.s_be_i` | core |
| `saf_addr` | 12 | bus | byte offset | `bus_interconnect.saf_addr_o` | `safety_fault_monitor.s_addr_i` | core |
| `saf_wdata` | 32 | bus | word | `bus_interconnect.saf_wdata_o` | `safety_fault_monitor.s_wdata_i` | core |
| `saf_rdata` | 32 | bus | word | `safety_fault_monitor.s_rdata_o` | `bus_interconnect.saf_rdata_i` | core |

## 6. Blocks

### 6.1 `clk_rst_gen`

Diagram: `diagrams/blk_clk_rst_gen.png`.  Kind rtl, owner Vedam, Verilog-2001. Produces the single clock and the single reset of the whole SoC.

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk_in` | in | 1 | clock | `clk_in` | pin clk_in | core | board clock, already 50 MHz |
| `rst_n_in` | in | 1 | level | `rst_n_in` | pin rst_n_in | core | external reset button, active-low, ASYNC, may bounce |
| `pll_locked_i` | in | 1 | level | `pll_locked_i` | pin pll_locked_i | fpga | clock-generator lock (tie 1 if none) |
| `clk` | out | 1 | clock | `clk` | timer_unit.clk, i2c_sensor_subsystem.clk, sensor_pipeline.clk, hw_pid_accel.clk, actuation_subsystem.clk, safety_fault_monitor.clk, rom_dp.clk, ram_sp.clk, bus_interconnect.clk, cpu_subsystem.clk | core | = clk_in |
| `rst_n` | out | 1 | level | `rst_n` | timer_unit.rst_n, i2c_sensor_subsystem.rst_n, sensor_pipeline.rst_n, hw_pid_accel.rst_n, actuation_subsystem.rst_n, safety_fault_monitor.rst_n, bus_interconnect.rst_n, cpu_subsystem.rst_n | core | active-low; asserted asynchronously, released synchronously |

**How the data moves inside**

1. clk_in is passed unchanged to clk (a wire; the FPGA tool adds the global buffer). There is no second clock anywhere.
2. rst_n_in (asynchronous, may bounce) and pll_locked_i are combined: rst_ok = rst_n_in AND pll_locked_i. If rst_ok is 0 the rst_n flop is cleared ASYNCHRONOUSLY, i.e. rst_n falls at once. This is the only asynchronous reset in the design.
3. When rst_ok returns to 1, a 2-flop synchroniser re-times it to clk, so release is synchronous.
4. A power-on hold counter then counts 255 clk cycles (5.1 us). Any new low on rst_ok restarts it, so a bouncing button can never release reset early.
5. When the hold finishes, rst_n goes high on a clk edge. Release happens 255 + 2 = 257 cycles after the last rising edge of rst_ok.

**Timing and numbers:** assert: 0 cycles (asynchronous); release: 257 cycles = 5.14 us after the last bounce

**FPGA-only / bring-up / GDSII notes:** pll_locked_i comes from the FPGA clock generator (tie 1 if there is none). In the GDSII it is the lock of a PLL macro, or tied 1 with an external 50 MHz clock pad. The rest is identical.

**Verification:** bounce test (low 3, high 1, low 2, high): rst_n stays low for the whole sequence and releases 257 cycles after the final high; pll_locked_i = 0 holds reset. Testbench rule for Ibex (ACR-5): start rst_n high and pull it low after time 0.

### 6.2 `timer_unit`

Diagram: `diagrams/blk_timer_unit.png`.  Kind rtl, owner Dipiksha, Verilog-2001. The heartbeat: one control_tick pulse every TICK_PERIOD clk cycles (about 512 Hz) starts every sample; a slow interrupt serves the CPU.

Parameters: `DEF_EN=0`, `TICK_PERIOD_DEF=97656`, `IRQ_DIV_DEF=51`

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk` | in | 1 | clock | `clk` | clk_rst_gen.clk | core | 50 MHz system clock |
| `rst_n` | in | 1 | level | `rst_n` | clk_rst_gen.rst_n | core | active-low reset, synchronous release |
| `s_sel_i` | in | 1 | pulse | `tmr_sel` | bus_interconnect.tmr_sel_o | core | access this cycle (exactly one cycle per access) |
| `s_we_i` | in | 1 | level | `tmr_we` | bus_interconnect.tmr_we_o | core | 1 = write, 0 = read |
| `s_be_i` | in | 4 | mask | `tmr_be` | bus_interconnect.tmr_be_o | core | byte enables (register banks may ignore; RAM must honour) |
| `s_addr_i` | in | 12 | byte offset | `tmr_addr` | bus_interconnect.tmr_addr_o | core | byte offset inside the region; word aligned, use [11:2] |
| `s_wdata_i` | in | 32 | word | `tmr_wdata` | bus_interconnect.tmr_wdata_o | core | write data |
| `s_rdata_o` | out | 32 | word | `tmr_rdata` | bus_interconnect.tmr_rdata_i | core | read data, REGISTERED: valid the cycle after s_sel_i |
| `sched_busy_i` | in | 1 | level | `imu_busy` | i2c_sensor_subsystem.imu_busy_o | core | imu_busy: still reading when the next tick fires => overrun |
| `control_tick_o` | out | 1 | pulse | `control_tick` | i2c_sensor_subsystem.control_tick_i, sensor_pipeline.control_tick_i, safety_fault_monitor.control_tick_i | core | one clk cycle every TICK_PERIOD cycles (about 512 Hz) |
| `irq_timer_o` | out | 1 | level | `irq_timer` | cpu_subsystem.irq_timer_i | core | set every IRQ_DIV ticks; cleared by W1C |

**Register bank TMR**, base `0x10000000` (reads are registered: valid the cycle after `s_sel_i`)

| Offset | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | 0x54494D01 | "TIM" + version 01 |
| 0x04 | CTRL | RW | b0=DEF_EN | b0 EN (ticks run); b1 IRQ_EN; b2 CNT_CLR (SC) restart counters |
| 0x08 | TICK_PERIOD | RW | 97656 | clk cycles per tick (min 1000); new value applies at next reload |
| 0x0C | IRQ_DIV | RW | 51 | ticks per timer interrupt (about 10 Hz) |
| 0x10 | STATUS | RO/W1C | 0 | b0 IRQ_PENDING (W1C); b1 OVERRUN (W1C) |
| 0x14 | TICK_COUNT | RO | 0 | ticks since enable |
| 0x18 | FREE_CNT | RO | 0 | free-running clk counter (timestamp) |

**How the data moves inside**

1. CPU writes land in tmr_regs (EN, IRQ_EN, TICK_PERIOD, IRQ_DIV). Reset values: EN = DEF_EN, TICK_PERIOD = 97656, IRQ_DIV = 51.
2. cycle_counter counts 0 ... TICK_PERIOD-1 on every clk while EN = 1. A new TICK_PERIOD written mid-run is only loaded at the wrap, so there is never a short or long glitch period.
3. At the wrap, tick_gen emits control_tick_o: a registered pulse exactly 1 clk wide (1.953 ms apart at the default).
4. Each tick increments tick_counter (TICK_COUNT) and clocks irq_divider. free_counter (32-bit) runs on every clk independently and is the timestamp FREE_CNT.
5. After IRQ_DIV ticks, irq_pending sets. irq_timer_o = irq_pending AND IRQ_EN, a LEVEL that stays high until the CPU writes 1 to STATUS.IRQ_PENDING (W1C).
6. overrun_detect: at every tick, if sched_busy_i (imu_busy) is still high, STATUS.OVERRUN sets (sticky, W1C): the I2C read of the previous sample did not finish within one period.

**Timing and numbers:** 97656 cycles = 1.953 ms tick; 51 ticks = 99.6 ms interrupt. The register minimum is 1000 cycles, but because the I2C burst needs about 20,000 cycles (0.4 ms) a practical floor is about 25,000 cycles. EN = 0: no ticks, no interrupt. Counters restart on EN rising or CNT_CLR.

**FPGA-only / bring-up / GDSII notes:** nothing FPGA-specific. DEF_EN follows HW_ONLY.

**Verification:** TICK_PERIOD = 100: ten pulses exactly 100 clk apart, width 1; change period mid-run; IRQ_DIV = 3; hold sched_busy_i high at a tick; EN = 0.

### 6.3 `i2c_sensor_subsystem`

Diagram: `diagrams/blk_i2c_sensor_subsystem.png`.  Kind rtl, owner Kaushal, Verilog-2001. Reads the MPU-6050 over I2C on every control_tick and publishes one coherent 6-axis sample.

Parameters: `DEF_EN=0`, `CLK_DIV_DEF=31`, `DEV_ADDR_DEF=7'h68`

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk` | in | 1 | clock | `clk` | clk_rst_gen.clk | core | 50 MHz system clock |
| `rst_n` | in | 1 | level | `rst_n` | clk_rst_gen.rst_n | core | active-low reset, synchronous release |
| `s_sel_i` | in | 1 | pulse | `i2c_sel` | bus_interconnect.i2c_sel_o | core | access this cycle (exactly one cycle per access) |
| `s_we_i` | in | 1 | level | `i2c_we` | bus_interconnect.i2c_we_o | core | 1 = write, 0 = read |
| `s_be_i` | in | 4 | mask | `i2c_be` | bus_interconnect.i2c_be_o | core | byte enables (register banks may ignore; RAM must honour) |
| `s_addr_i` | in | 12 | byte offset | `i2c_addr` | bus_interconnect.i2c_addr_o | core | byte offset inside the region; word aligned, use [11:2] |
| `s_wdata_i` | in | 32 | word | `i2c_wdata` | bus_interconnect.i2c_wdata_o | core | write data |
| `s_rdata_o` | out | 32 | word | `i2c_rdata` | bus_interconnect.i2c_rdata_i | core | read data, REGISTERED: valid the cycle after s_sel_i |
| `control_tick_i` | in | 1 | pulse | `control_tick` | timer_unit.control_tick_o | core | start a sample read |
| `scl_i` | in | 1 | level | `scl_i` | pin scl_i | core | raw SCL pin (2-FF synchronised inside) |
| `sda_i` | in | 1 | level | `sda_i` | pin sda_i | core | raw SDA pin (2-FF synchronised inside) |
| `scl_drive_low_o` | out | 1 | level | `scl_drive_low_o` | pin scl_drive_low_o | core | 1 = pull SCL low, 0 = release (open-drain) |
| `sda_drive_low_o` | out | 1 | level | `sda_drive_low_o` | pin sda_drive_low_o | core | 1 = pull SDA low, 0 = release |
| `imu_valid_o` | out | 1 | pulse | `imu_valid` | sensor_pipeline.imu_valid_i, safety_fault_monitor.imu_valid_i | core | complete 14-byte sample ready |
| `imu_ax_o` | out | 16 | int16 | `imu_ax` | sensor_pipeline.imu_ax_i | core | signed raw ax, stable after imu_valid_o |
| `imu_ay_o` | out | 16 | int16 | `imu_ay` | sensor_pipeline.imu_ay_i | core | signed raw ay, stable after imu_valid_o |
| `imu_az_o` | out | 16 | int16 | `imu_az` | sensor_pipeline.imu_az_i | core | signed raw az, stable after imu_valid_o |
| `imu_gx_o` | out | 16 | int16 | `imu_gx` | sensor_pipeline.imu_gx_i | core | signed raw gx, stable after imu_valid_o |
| `imu_gy_o` | out | 16 | int16 | `imu_gy` | sensor_pipeline.imu_gy_i | core | signed raw gy, stable after imu_valid_o |
| `imu_gz_o` | out | 16 | int16 | `imu_gz` | sensor_pipeline.imu_gz_i | core | signed raw gz, stable after imu_valid_o |
| `imu_busy_o` | out | 1 | level | `imu_busy` | timer_unit.sched_busy_i | core | high from tick until imu_valid_o or imu_err_o |
| `imu_err_o` | out | 1 | pulse | `imu_err` | safety_fault_monitor.imu_err_i | core | transaction failed (NACK / timeout) |
| `imu_init_done_o` | out | 1 | level | `imu_init_done` | sensor_pipeline.imu_init_done_i, safety_fault_monitor.imu_init_done_i | core | MPU-6050 configured |

**Register bank I2C**, base `0x10001000` (reads are registered: valid the cycle after `s_sel_i`)

| Offset | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | 0x49324301 | "I2C" + version 01 |
| 0x04 | CTRL | RW | b0=DEF_EN | b0 EN; b1 REINIT (SC); b2 SOFT_TRIG (SC) |
| 0x08 | CLK_DIV | RW | 31 | f_scl = f_clk / (4*(CLK_DIV+1)) = 390.6 kHz |
| 0x0C | STATUS | RO/W1C | 0 | b0 INIT_DONE; b1 BUSY; b2 ERR_STICKY (W1C); b3 TIMEOUT_STICKY (W1C) |
| 0x10 | ERR_COUNT | RO | 0 | saturating count of failed transactions |
| 0x14 | SAMPLE_COUNT | RO | 0 | good samples since reset |
| 0x18 | DEV_ADDR | RW | 0x68 | 7-bit device address |
| 0x20 | AX | RO | 0 | raw, sign-extended |
| 0x24 | AY | RO | 0 | raw |
| 0x28 | AZ | RO | 0 | raw |
| 0x2C | GX | RO | 0 | raw |
| 0x30 | GY | RO | 0 | raw |
| 0x34 | GZ | RO | 0 | raw |

**How the data moves inside**

1. After reset, once EN = 1 (or DEF_EN), mpu6050_ctrl waits about 50 ms, reads WHO_AM_I (0x75, expects 0x68), then writes PWR_MGMT_1 (0x6B) = 0x01 (the chip powers up asleep), SMPLRT_DIV (0x19) = 0x00, CONFIG (0x1A) = 0x02, GYRO_CONFIG (0x1B) = 0x00, ACCEL_CONFIG (0x1C) = 0x00. Then imu_init_done_o goes high (ACR-7: it is low during any (re-)initialisation).
2. On every control_tick_i (ignored while busy) the sequencer raises imu_busy_o and issues: START, addr+W, register 0x3B, repeated START, addr+R, 14 byte reads (ACK the first 13, NACK the 14th), STOP.
3. i2c_master turns each command into bit activity. The clock divider makes four phases per SCL period: f_scl = 50 MHz / (4 x (CLK_DIV + 1)) = 390.6 kHz at CLK_DIV = 31 (one bit 2.56 us, one byte 23 us). SDA/SCL are only ever pulled low or released (scl_drive_low_o, sda_drive_low_o); the inputs scl_i and sda_i pass through 2-flop synchronisers; clock stretching is honoured by waiting until scl_i is really high.
4. Received bytes (high byte first) go to sample_assembler: ax = {b0,b1}, ay = {b2,b3}, az = {b4,b5}, temperature {b6,b7} discarded, gx = {b8,b9}, gy = {b10,b11}, gz = {b12,b13}.
5. Only after the STOP condition are all six values copied together into imu_*_o and the AX...GZ registers, SAMPLE_COUNT increments, imu_valid_o pulses and imu_busy_o falls. A half-updated sample is never visible.
6. Errors: a NACK, or a transaction longer than 1.5 ms, aborts, sends STOP, pulses imu_err_o, increments ERR_COUNT and sets ERR_STICKY (or TIMEOUT_STICKY); the sample is skipped. A stuck SDA gets 9 SCL pulses then STOP. Three consecutive errors re-run the init sequence.

**Timing and numbers:** control_tick_i to imu_valid_o: 380-440 us (156 SCL periods x 128 cycles = 19,968 cycles = 0.399 ms). Model values ax=0x1000, ay=0xF000, az=0x4000, gx=0x0083, gy=0xFF00, gz=0 give 4096, -4096, 16384, 131, -256, 0.

**FPGA-only / bring-up / GDSII notes:** the open-drain pad (scl_pad, sda_pad) is made in ecu_fpga_top with an IOBUF and 4.7 kOhm pull-ups to 3.3 V; in the GDSII it is an open-drain pad cell. This block only produces drive_low and reads the synchronised pin level.

**Verification:** behavioural MPU-6050 model with 128-byte register file, repeated start, auto-increment, sleep bit, NACK and clock-stretch injection; latency window; REINIT; stuck-bus recovery.

### 6.4 `sensor_pipeline`

Diagram: `diagrams/blk_sensor_pipeline.png`.  Kind rtl, owner Dipiksha, Verilog-2001. Turns raw IMU counts into the angle, rate and error the PID consumes, using only shifts and adds.

Parameters: `DEF_EN=0`

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk` | in | 1 | clock | `clk` | clk_rst_gen.clk | core | 50 MHz system clock |
| `rst_n` | in | 1 | level | `rst_n` | clk_rst_gen.rst_n | core | active-low reset, synchronous release |
| `s_sel_i` | in | 1 | pulse | `sens_sel` | bus_interconnect.sens_sel_o | core | access this cycle (exactly one cycle per access) |
| `s_we_i` | in | 1 | level | `sens_we` | bus_interconnect.sens_we_o | core | 1 = write, 0 = read |
| `s_be_i` | in | 4 | mask | `sens_be` | bus_interconnect.sens_be_o | core | byte enables (register banks may ignore; RAM must honour) |
| `s_addr_i` | in | 12 | byte offset | `sens_addr` | bus_interconnect.sens_addr_o | core | byte offset inside the region; word aligned, use [11:2] |
| `s_wdata_i` | in | 32 | word | `sens_wdata` | bus_interconnect.sens_wdata_o | core | write data |
| `s_rdata_o` | out | 32 | word | `sens_rdata` | bus_interconnect.sens_rdata_i | core | read data, REGISTERED: valid the cycle after s_sel_i |
| `control_tick_i` | in | 1 | pulse | `control_tick` | timer_unit.control_tick_o | core | ACR-2: time base for DATA_FRESH (sample within last 2 ticks) |
| `imu_valid_i` | in | 1 | pulse | `imu_valid` | i2c_sensor_subsystem.imu_valid_o | core | sample ready |
| `imu_ax_i` | in | 16 | int16 | `imu_ax` | i2c_sensor_subsystem.imu_ax_o | core | signed raw ax |
| `imu_ay_i` | in | 16 | int16 | `imu_ay` | i2c_sensor_subsystem.imu_ay_o | core | signed raw ay |
| `imu_az_i` | in | 16 | int16 | `imu_az` | i2c_sensor_subsystem.imu_az_o | core | signed raw az |
| `imu_gx_i` | in | 16 | int16 | `imu_gx` | i2c_sensor_subsystem.imu_gx_o | core | signed raw gx |
| `imu_gy_i` | in | 16 | int16 | `imu_gy` | i2c_sensor_subsystem.imu_gy_o | core | signed raw gy |
| `imu_gz_i` | in | 16 | int16 | `imu_gz` | i2c_sensor_subsystem.imu_gz_o | core | signed raw gz |
| `imu_init_done_i` | in | 1 | level | `imu_init_done` | i2c_sensor_subsystem.imu_init_done_o | core | calibration waits for this |
| `setpoint_i` | in | 32 | Q16.16 rad | `setpoint` | hw_pid_accel.setpoint_o | core | balance setpoint from PID bank |
| `pipe_valid_o` | out | 1 | pulse | `pipe_valid` | hw_pid_accel.err_valid_i, safety_fault_monitor.pipe_valid_i | core | angle_o, err_o, rate_o valid together |
| `angle_o` | out | 32 | Q16.16 rad | `angle` | safety_fault_monitor.angle_i | core | filtered + trimmed; + = leaning forward |
| `err_o` | out | 32 | Q16.16 | `err` | hw_pid_accel.err_i | core | setpoint_i - angle |
| `rate_o` | out | 32 | Q16.16 rad/s | `rate` | hw_pid_accel.rate_i | core | filtered, bias-corrected |
| `calib_done_o` | out | 1 | level | `calib_done` | safety_fault_monitor.calib_done_i | core | gyro bias captured |

**Register bank SENS**, base `0x10002000` (reads are registered: valid the cycle after `s_sel_i`)

| Offset | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | 0x53454E01 | "SEN" + version 01 |
| 0x04 | CTRL | RW | 0 | b0 CAL_START (SC); b1 AXIS_SEL; b2 INV_ANGLE; b3 INV_RATE; b4 FILT_MODE (1 = complementary) |
| 0x08 | FILT_SHIFT | RW | 0x22 | [2:0] angle log2 N (0-4); [6:4] rate log2 N |
| 0x0C | ANGLE_TRIM | RW | 0 | Q16.16, subtracted from the filtered angle |
| 0x10 | STATUS | RO | 0 | b0 CAL_BUSY; b1 CAL_DONE; b2 DATA_FRESH (a sample arrived within the last 2 ticks) |
| 0x14 | GYRO_BIAS_X | RO | 0 | signed |
| 0x18 | GYRO_BIAS_Y | RO | 0 | signed |
| 0x1C | GYRO_BIAS_Z | RO | 0 | signed |
| 0x20 | ANGLE_RAW | RO | 0 | after conversion, before filter |
| 0x24 | ANGLE_FILT | RO | 0 | after filter and trim |
| 0x28 | RATE_FILT | RO | 0 | filtered rate |
| 0x2C | ERROR | RO | 0 | setpoint - angle |
| 0x30 | SEQ_COUNT | RO | 0 | samples processed |

**How the data moves inside**

1. imu_valid_i: meas_capture latches all six raw axes in the SAME cycle (coherent sample) and increments SEQ_COUNT.
2. Calibration FSM IDLE -> SETTLE -> ACCUM -> DONE. It starts on CAL_START, or automatically on the rising edge of imu_init_done_i if DEF_EN = 1. SETTLE discards 64 samples; ACCUM adds gx, gy, gz of 256 samples into three 24-bit accumulators; bias = sum >>> 8 (readable in GYRO_BIAS_X/Y/Z); calib_done_o = 1. From then on gyro = sat16(raw - bias). During calibration data keeps flowing uncorrected.
3. angle_conv: AXIS_SEL = 0 uses accel X and gyro Y, AXIS_SEL = 1 uses accel Y and gyro X. angle = accel x 4 (Q16.16 rad, e.g. 4096 -> 16384). rate = (g<<3) + (g>>>1) + (g>>>2) = 8.75 x g (131 -> 1145). INV_ANGLE / INV_RATE negate. Latency 1 cycle.
4. sensor_filter: two moving_avg_filter instances (32-bit), one for angle and one for rate. N = 2^k from FILT_SHIFT (reset 0x22 = k 2 for both; k = 0 bypasses). Circular buffer of N samples with running sum: sum = sum + new - oldest; out = sum >>> k. Changing k clears buffer and sum. Optional complementary filter (FILT_MODE = 1): pred = angle_f + (rate >>> 9); angle_f = pred - (pred >>> 6) + (angle_acc >>> 6).
5. trim: angle_o = filtered angle - ANGLE_TRIM (the trim is subtracted after the filter).
6. error_calc: err_o = setpoint_i - angle_o (saturating 32-bit). rate passes through. One pulse pipe_valid_o is emitted with angle_o, err_o and rate_o all valid in that cycle.
7. Telemetry registers record ANGLE_RAW (after conversion), ANGLE_FILT, RATE_FILT, ERROR, SEQ_COUNT. STATUS.DATA_FRESH sets with every pipe_valid_o and clears if no sample arrived within 2 control_tick_i (ACR-2).

**Timing and numbers:** imu_valid_i to pipe_valid_o <= 64 cycles (about 6-8 in practice). Filter delay (N-1)/2 samples = about (N-1) ms at 512 Hz, on top of the MPU-6050 low-pass (about 3 ms).

**FPGA-only / bring-up / GDSII notes:** nothing FPGA-specific; DEF_EN follows HW_ONLY (auto-calibration).

**Verification:** angle_conv, moving_avg, error_calc and calibration vectors; 1000 random samples against model/sensor_pipeline.py with zero differences; exactly one pipe_valid_o per imu_valid_i.

### 6.5 `hw_pid_accel`

Diagram: `diagrams/blk_hw_pid_accel.png`.  Kind rtl, owner Conolas, Verilog-2001. Hardware PID: u = Kp*e + Ki*Ts*sum(e) - Kd*rate in Q16.16, one shared multiplier, at most 16 cycles.

Parameters: `DEF_EN=0`, `DEF_KP=0`, `DEF_KI=0`, `DEF_KD=0`, `DEF_SETPOINT=0`, `DEF_OUT_LIMIT=16384`

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk` | in | 1 | clock | `clk` | clk_rst_gen.clk | core | 50 MHz system clock |
| `rst_n` | in | 1 | level | `rst_n` | clk_rst_gen.rst_n | core | active-low reset, synchronous release |
| `s_sel_i` | in | 1 | pulse | `pid_sel` | bus_interconnect.pid_sel_o | core | access this cycle (exactly one cycle per access) |
| `s_we_i` | in | 1 | level | `pid_we` | bus_interconnect.pid_we_o | core | 1 = write, 0 = read |
| `s_be_i` | in | 4 | mask | `pid_be` | bus_interconnect.pid_be_o | core | byte enables (register banks may ignore; RAM must honour) |
| `s_addr_i` | in | 12 | byte offset | `pid_addr` | bus_interconnect.pid_addr_o | core | byte offset inside the region; word aligned, use [11:2] |
| `s_wdata_i` | in | 32 | word | `pid_wdata` | bus_interconnect.pid_wdata_o | core | write data |
| `s_rdata_o` | out | 32 | word | `pid_rdata` | bus_interconnect.pid_rdata_i | core | read data, REGISTERED: valid the cycle after s_sel_i |
| `err_valid_i` | in | 1 | pulse | `pipe_valid` | sensor_pipeline.pipe_valid_o | core | pipe_valid |
| `err_i` | in | 32 | Q16.16 | `err` | sensor_pipeline.err_o | core | setpoint - angle |
| `rate_i` | in | 32 | Q16.16 rad/s | `rate` | sensor_pipeline.rate_o | core | filtered rate |
| `run_i` | in | 1 | level | `pwm_enable` | safety_fault_monitor.pwm_enable_o | core | pwm_enable: 0 => output 0, integrator cleared |
| `pwm_cmd_o` | out | 32 | Q16.16 [-1,+1] | `pwm_cmd` | actuation_subsystem.cmd_i | core | clamped to +-OUT_LIMIT |
| `pwm_cmd_valid_o` | out | 1 | pulse | `pwm_cmd_valid` | actuation_subsystem.cmd_valid_i | core | new command (also pulses with 0 when not running) |
| `pid_sat_o` | out | 1 | level | `pid_sat` | safety_fault_monitor.pid_sat_i | core | last output was clamped |
| `setpoint_o` | out | 32 | Q16.16 rad | `setpoint` | sensor_pipeline.setpoint_i | core | SETPOINT register -> sensor_pipeline |

**Register bank PID**, base `0x10003000` (reads are registered: valid the cycle after `s_sel_i`)

| Offset | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | 0x50494401 | "PID" + version 01 |
| 0x04 | CTRL | RW | b0=DEF_EN, b2=1 | b0 EN; b1 CLR_INT (SC); b2 D_SRC (1 = D from gyro rate) |
| 0x08 | KP | RW | DEF_KP | Q16.16 |
| 0x0C | KI | RW | DEF_KI | Q16.16, pre-multiplied by Ts (Ki*Ts) |
| 0x10 | KD | RW | DEF_KD | Q16.16 (rad/s when D_SRC=1) |
| 0x14 | SETPOINT | RW | DEF_SETPOINT | Q16.16 rad |
| 0x18 | INT_LIMIT | RW | 19661 | max |integrator| (0.3) |
| 0x1C | OUT_LIMIT | RW | DEF_OUT_LIMIT (16384) | output clamp, max 65536 |
| 0x20 | STATUS | RO/W1C | 0 | b0 SAT (live); b1 SAT_STICKY (W1C); b2 ACTIVE |
| 0x24 | P_TERM | RO | 0 | last P term |
| 0x28 | I_TERM | RO | 0 | integrator |
| 0x2C | D_TERM | RO | 0 | last D term |
| 0x30 | U_OUT | RO | 0 | last output |

**How the data moves inside**

1. err_valid_i (pipe_valid): the input gate captures err_i and rate_i. If run_i = 0 or EN = 0 the output is forced to 0, the integrator is cleared, e_prev = e (no derivative kick on re-enable) and pwm_cmd_valid_o still pulses (value 0) so actuation sees zero commands.
2. pid_fsm steps IDLE -> P -> I -> D -> SUM -> OUT (about 8 cycles) and time-shares one signed 32x32 -> 64 bit multiplier; every product is (a*b) >>> 16.
3. P = Kp*e. I: acc += Ki*e (Ki already holds Ki*Ts); clamp to +-INT_LIMIT; freeze while the summed output is already clamped in the direction of the error. D: with D_SRC = 1, D = -(Kd*rate) >>> 16 (because error = setpoint - angle, d(error)/dt = -rate); with D_SRC = 0, D = Kd*(e - e_prev) (Kd must then be pre-divided by Ts).
4. SUM adds P + I + D in 34 bits. The result is clamped to +-OUT_LIMIT (maximum 65536); SAT = 1 if it was clamped. pwm_cmd_o = result and pwm_cmd_valid_o pulses.
5. The SETPOINT register value is driven continuously on setpoint_o to sensor_pipeline. Telemetry: P_TERM, I_TERM, D_TERM, U_OUT; STATUS.SAT (live), SAT_STICKY (W1C), ACTIVE.

**Timing and numbers:** err_valid_i to pwm_cmd_valid_o <= 16 cycles (0.32 us). Sign rule: leaning forward => angle > 0 => err < 0 => u < 0; the motor direction bits must make u < 0 drive the wheels forward. Vectors: Kp = 65536, e = 6554 -> u = 6554; Kp = 524288, e = 13107, OUT_LIMIT 16384 -> clamped, sat = 1.

**FPGA-only / bring-up / GDSII notes:** nothing FPGA-specific; DEF_EN, DEF_KP... follow HW_ONLY (no CPU: defaults must already balance the robot).

**Verification:** 7 directed vectors, 1000 random vectors against model/pid.py bit-for-bit, closed-loop pendulum model.

### 6.6 `actuation_subsystem`

Diagram: `diagrams/blk_actuation_subsystem.png`.  Kind rtl, owner Jaydev, Verilog-2001. Turns the PID command into safe PWM for two BTS7960 drivers.

Parameters: `DEF_EN=0`, `PERIOD_DEF=2500`, `DEADTIME_DEF=250`

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk` | in | 1 | clock | `clk` | clk_rst_gen.clk | core | 50 MHz system clock |
| `rst_n` | in | 1 | level | `rst_n` | clk_rst_gen.rst_n | core | active-low reset, synchronous release |
| `s_sel_i` | in | 1 | pulse | `pwm_sel` | bus_interconnect.pwm_sel_o | core | access this cycle (exactly one cycle per access) |
| `s_we_i` | in | 1 | level | `pwm_we` | bus_interconnect.pwm_we_o | core | 1 = write, 0 = read |
| `s_be_i` | in | 4 | mask | `pwm_be` | bus_interconnect.pwm_be_o | core | byte enables (register banks may ignore; RAM must honour) |
| `s_addr_i` | in | 12 | byte offset | `pwm_addr` | bus_interconnect.pwm_addr_o | core | byte offset inside the region; word aligned, use [11:2] |
| `s_wdata_i` | in | 32 | word | `pwm_wdata` | bus_interconnect.pwm_wdata_o | core | write data |
| `s_rdata_o` | out | 32 | word | `pwm_rdata` | bus_interconnect.pwm_rdata_i | core | read data, REGISTERED: valid the cycle after s_sel_i |
| `cmd_valid_i` | in | 1 | pulse | `pwm_cmd_valid` | hw_pid_accel.pwm_cmd_valid_o | core | new command (about 512 Hz) |
| `cmd_i` | in | 32 | Q16.16 [-1,+1] | `pwm_cmd` | hw_pid_accel.pwm_cmd_o | core | balance command from PID |
| `pwm_enable_i` | in | 1 | level | `pwm_enable` | safety_fault_monitor.pwm_enable_o | core | from safety: 0 => everything off |
| `bench_en_i` | in | 1 | level | `bench_en_i` | pin bench_en_i | bringup | 1 = ignore cmd_i, use bench table |
| `bench_sel_i` | in | 2 | code | `bench_sel_i` | pin bench_sel_i | bringup | 00 -> 0, 01 -> +0.25, 10 -> -0.25, 11 -> +0.5 |
| `l_rpwm_o` | out | 1 | level | `l_rpwm_o` | pin l_rpwm_o | core | left BTS7960 RPWM |
| `l_lpwm_o` | out | 1 | level | `l_lpwm_o` | pin l_lpwm_o | core | left BTS7960 LPWM |
| `l_r_en_o` | out | 1 | level | `l_r_en_o` | pin l_r_en_o | core | left BTS7960 R_EN |
| `l_l_en_o` | out | 1 | level | `l_l_en_o` | pin l_l_en_o | core | left BTS7960 L_EN |
| `r_rpwm_o` | out | 1 | level | `r_rpwm_o` | pin r_rpwm_o | core | right BTS7960 RPWM |
| `r_lpwm_o` | out | 1 | level | `r_lpwm_o` | pin r_lpwm_o | core | right BTS7960 LPWM |
| `r_r_en_o` | out | 1 | level | `r_r_en_o` | pin r_r_en_o | core | right BTS7960 R_EN |
| `r_l_en_o` | out | 1 | level | `r_l_en_o` | pin r_l_en_o | core | right BTS7960 L_EN |
| `duty_l_o` | out | 16 | counts | `duty_l` | (debug tap) | dbg | current left duty counts (debug) |
| `duty_r_o` | out | 16 | counts | `duty_r` | (debug tap) | dbg | current right duty counts (debug) |

**Register bank PWM**, base `0x10004000` (reads are registered: valid the cycle after `s_sel_i`)

| Offset | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | 0x50574D01 | "PWM" + version 01 |
| 0x04 | CTRL | RW | b0=DEF_EN, b4=1 | b0 EN; b1 SLEW_EN; b2 DIR_INV_L; b3 DIR_INV_R; b4 CLAMP_EN |
| 0x08 | PERIOD | RW | 2500 | PWM period in clk cycles (20 kHz); applies at the period wrap |
| 0x0C | MAX_DUTY | RW | 0xE666 | Q0.16 max duty (0.9) |
| 0x10 | DEADTIME | RW | 250 | clk cycles, both outputs low on reversal (5 us) |
| 0x14 | SLEW_STEP | RW | 6554 | max command change per update, Q16.16 (0.1) |
| 0x18 | STEER | RW | 0 | Q16.16: left = cmd + steer, right = cmd - steer |
| 0x1C | GAIN_L | RW | 65536 | Q16.16 left gain |
| 0x20 | GAIN_R | RW | 65536 | Q16.16 right gain |
| 0x24 | STATUS | RO | 0 | b0 ENABLED; b1 CLAMPED (sticky, W1C); b2 IN_DEADTIME_L; b3 IN_DEADTIME_R |
| 0x28 | DUTY_L | RO | 0 | current duty counts |
| 0x2C | DUTY_R | RO | 0 | current duty counts |

**How the data moves inside**

1. On cmd_valid_i the source is chosen: if bench_en_i (synchronised, bring-up only) the bench table is used (00 -> 0, 01 -> +16384, 10 -> -16384, 11 -> +32768), else cmd_i.
2. steer_gain: left_raw = cmd + steer and right_raw = cmd - steer, each multiplied by GAIN_L / GAIN_R ((a*b) >>> 16).
3. clamp: each channel limited to +-65536 (+-1.0) when CLAMP_EN = 1; STATUS.CLAMPED sets.
4. slew limiter (SLEW_EN): the value moves toward the target by at most SLEW_STEP (6554 = 0.1) per update; when pwm_enable_i rises it starts from 0, so full scale takes 10 updates (about 19.5 ms).
5. Per channel: mag16 = min(|cmd|, 65535), then min(mag16, MAX_DUTY); duty_counts = (mag16 x PERIOD) >> 16 (cmd 0.5 -> 1250 of 2500; MAX_DUTY 0.9 -> 2249).
6. Direction: cmd > 0 drives RPWM, cmd < 0 drives LPWM, DIR_INV_x swaps them. The dead-time FSM (RUN_FWD, RUN_REV, DEAD) holds both outputs low for DEADTIME = 250 cycles (5 us) on every reversal. RPWM and LPWM are NEVER high together.
7. The PWM core counts 0 ... PERIOD-1 and is high while count < duty_counts. Duty and direction are latched at the period wrap (double-buffered), so no runt pulses.
8. enable_gate: every *_EN pin = pwm_enable_i AND EN. When 0, both PWM outputs and all four enables are low within 2 clk. Bench mode is still gated by pwm_enable_i.

**Timing and numbers:** cmd_valid_i to the next PWM period wrap <= 1 period (50 us); PERIOD 2500 cycles = 20 kHz. Vectors: cmd +32768 -> duty 1250; cmd +131072 -> clamped, duty 2499; steer 6554, cmd 32768 -> left 1500, right 999.

**FPGA-only / bring-up / GDSII notes:** bench_en_i / bench_sel_i are bring-up only (tie 0 in the GDSII). duty_l_o / duty_r_o are debug taps. Synchronisers for the bench pins are inside this block (ACR-1).

**Verification:** 13 vectors; assertion !(rpwm && lpwm) on every clock for the whole simulation; scope check of 20 kHz and duty.

### 6.7 `safety_fault_monitor`

Diagram: `diagrams/blk_safety_fault_monitor.png`.  Kind rtl, owner Vedam, Verilog-2001. Decides whether the motors may move. Fail-safe: any doubt makes pwm_enable_o = 0 within 2 clk, faults latch, re-arming is deliberate.

Parameters: `DEF_EN=0`, `DEF_WD_EN=0`

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk` | in | 1 | clock | `clk` | clk_rst_gen.clk | core | 50 MHz system clock |
| `rst_n` | in | 1 | level | `rst_n` | clk_rst_gen.rst_n | core | active-low reset, synchronous release |
| `s_sel_i` | in | 1 | pulse | `saf_sel` | bus_interconnect.saf_sel_o | core | access this cycle (exactly one cycle per access) |
| `s_we_i` | in | 1 | level | `saf_we` | bus_interconnect.saf_we_o | core | 1 = write, 0 = read |
| `s_be_i` | in | 4 | mask | `saf_be` | bus_interconnect.saf_be_o | core | byte enables (register banks may ignore; RAM must honour) |
| `s_addr_i` | in | 12 | byte offset | `saf_addr` | bus_interconnect.saf_addr_o | core | byte offset inside the region; word aligned, use [11:2] |
| `s_wdata_i` | in | 32 | word | `saf_wdata` | bus_interconnect.saf_wdata_o | core | write data |
| `s_rdata_o` | out | 32 | word | `saf_rdata` | bus_interconnect.saf_rdata_i | core | read data, REGISTERED: valid the cycle after s_sel_i |
| `control_tick_i` | in | 1 | pulse | `control_tick` | timer_unit.control_tick_o | core | time base for time-outs and watchdog |
| `imu_valid_i` | in | 1 | pulse | `imu_valid` | i2c_sensor_subsystem.imu_valid_o | core | sample received |
| `imu_err_i` | in | 1 | pulse | `imu_err` | i2c_sensor_subsystem.imu_err_o | core | I2C transaction failed |
| `imu_init_done_i` | in | 1 | level | `imu_init_done` | i2c_sensor_subsystem.imu_init_done_o | core | sensor configured |
| `calib_done_i` | in | 1 | level | `calib_done` | sensor_pipeline.calib_done_o | core | gyro bias captured |
| `pipe_valid_i` | in | 1 | pulse | `pipe_valid` | sensor_pipeline.pipe_valid_o | core | angle_i valid |
| `angle_i` | in | 32 | Q16.16 rad | `angle` | sensor_pipeline.angle_o | core | filtered angle |
| `pid_sat_i` | in | 1 | level | `pid_sat` | hw_pid_accel.pid_sat_o | core | PID output clamped |
| `estop_n_i` | in | 1 | level | `estop_n_i` | pin estop_n_i | core | hardware E-stop, active-low, raw (synchronised inside) |
| `arm_sw_i` | in | 1 | level | `arm_sw_i` | pin arm_sw_i | bringup | arm switch, raw (synchronised inside); tie 0 in final SoC |
| `pwm_enable_o` | out | 1 | level | `pwm_enable` | hw_pid_accel.run_i, actuation_subsystem.pwm_enable_i | core | 1 = motors allowed; default 0; registered |
| `irq_fault_o` | out | 1 | level | `irq_fault` | cpu_subsystem.irq_fault_i | core | IRQ_EN & any sticky fault |
| `dbg_o` | out | 8 | LED bits | `dbg_o` | pin dbg_o | dbg | [3:0]={calib_done,init_done,fault_any,pwm_enable}, [7:4]=DBG_OUT[7:4] |

**Register bank SAFE**, base `0x10005000` (reads are registered: valid the cycle after `s_sel_i`)

| Offset | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0x00 | ID | RO | 0x53414601 | "SAF" + version 01 |
| 0x04 | CTRL | RW | 0x04 | DEF_WD_EN<<1 | DEF_EN | b0 ARM; b1 WD_EN; b2 TILT_EN (reset 1); b3 FAULT_CLR (SC); b4 IRQ_EN |
| 0x08 | WD_KICK | WO | - | any write restarts the watchdog |
| 0x0C | TILT_LIMIT | RW | 39322 | Q16.16 rad (0.6), compared with |angle| |
| 0x10 | SENSOR_TIMEOUT | RW | 8 | control ticks without imu_valid |
| 0x14 | SAT_LIMIT | RW | 256 | consecutive saturated samples |
| 0x18 | WD_TIMEOUT | RW | 100 | ticks (195 ms) without a kick |
| 0x1C | FAULT_STATUS | RO | 0 | sticky: b0 TILT, b1 SENSOR_TIMEOUT, b2 I2C_ERR, b3 PID_SAT, b4 WATCHDOG, b5 ESTOP |
| 0x20 | FAULT_LIVE | RO | 0 | same bits, live |
| 0x24 | STATE | RO | 0 | 0 DISARMED, 1 ARMED, 2 FAULT |
| 0x28 | DBG_OUT | RW | 0 | firmware LED bits -> dbg_o[7:4] |

**How the data moves inside**

1. input_sync passes estop_n_i and arm_sw_i through 2 flops each (ACR-1).
2. Detectors, evaluated only while ARMED (the E-stop always latches): TILT = |angle_i| > TILT_LIMIT on 3 consecutive pipe_valid_i (if TILT_EN); SENSOR_TIMEOUT = no imu_valid_i for SENSOR_TIMEOUT consecutive control_tick_i; I2C_ERR = 3 consecutive imu_err_i (cleared by imu_valid_i); PID_SAT = pid_sat_i high for SAT_LIMIT consecutive pipe_valid_i; WATCHDOG = no WD_KICK write for WD_TIMEOUT ticks (if WD_EN); ESTOP = synchronised estop_n_i low, immediate, from any state.
3. fault_flags keeps sticky bits in FAULT_STATUS (bit 0 TILT, 1 SENSOR_TIMEOUT, 2 I2C_ERR, 3 PID_SAT, 4 WATCHDOG, 5 ESTOP); FAULT_LIVE shows the live conditions.
4. arm_fsm: arm_req = ARM | synchronised arm_sw_i. DISARMED -> ARMED when arm_req AND calib_done_i AND no live fault AND flags == 0. Any fault: ARMED -> FAULT. FAULT -> DISARMED only after FAULT_CLR (condition gone) and arm_req low; then ARM low-to-high arms again. A robot never restarts by itself.
5. pwm_enable_o is a registered output: 1 only in ARMED, 0 within 2 clk of any fault (3 clk from the E-stop pin). It never depends on a CPU action to turn OFF.
6. irq_fault_o = IRQ_EN AND (any sticky flag): a level, cleared by clearing the flags. dbg_o[3:0] = {calib_done_i, imu_init_done_i, fault_any, pwm_enable_o}; dbg_o[7:4] = DBG_OUT[7:4].

**Timing and numbers:** fault to pwm_enable_o low <= 2 clk; E-stop <= 3 clk. Reset: DISARMED, pwm_enable_o = 0, CTRL = 0x04 (TILT_EN = 1; ACR-3). Watchdog off by default (phase 1 has no CPU).

**FPGA-only / bring-up / GDSII notes:** arm_sw_i is bring-up only (tie 0 in the GDSII); dbg_o drives LEDs on the FPGA and spare pins (or nothing) in the GDSII.

**Verification:** 14 scenarios: reset, arm without calibration, tilt debounce (3 vs 2 samples), sensor time-out, I2C errors (3 vs 2), saturation, watchdog, E-stop while disarmed, clear while condition live, re-arm sequence, two faults at once.

### 6.8 `rom_dp`

Diagram: `diagrams/blk_rom_dp.png`.  Kind rtl, owner Vedam, Verilog-2001. 8 KB firmware ROM with two independent read ports.

Parameters: `ROM_WORDS=2048`, `INIT_FILE="firmware.hex"`

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk` | in | 1 | clock | `clk` | clk_rst_gen.clk | core | 50 MHz |
| `ia_req_i` | in | 1 | pulse | `rom_ia_req` | bus_interconnect.rom_ia_req_o | core | instruction fetch request |
| `ia_addr_i` | in | 13 | byte addr | `rom_ia_addr` | bus_interconnect.rom_ia_addr_o | core | use [12:2] as word index |
| `ia_rdata_o` | out | 32 | word | `rom_ia_rdata` | bus_interconnect.rom_ia_rdata_i | core | registered: valid the cycle after ia_req_i |
| `s_sel_i` | in | 1 | pulse | `rom_sel` | bus_interconnect.rom_sel_o | core | data-side read request |
| `s_addr_i` | in | 13 | byte addr | `rom_addr` | bus_interconnect.rom_addr_o | core | data-side address |
| `s_rdata_o` | out | 32 | word | `rom_rdata` | bus_interconnect.rom_rdata_i | core | registered |

**How the data moves inside**

1. Port A (instruction side): when ia_req_i is high, the word at ia_addr_i[12:2] is registered into ia_rdata_o (valid the next cycle).
2. Port B (data side): when s_sel_i is high, the word at s_addr_i[12:2] is registered into s_rdata_o (constants and .rodata).
3. The array has 2048 x 32 bits and is loaded with $readmemh(INIT_FILE = "firmware.hex") at simulation / FPGA configuration. There is no write port: a store to ROM never arrives (the bus answers it with an error).

**Timing and numbers:** registered reads: one cycle

**FPGA-only / bring-up / GDSII notes:** $readmemh initialisation and BRAM inference are FPGA/simulation features; in the GDSII the ROM is a macro or mask ROM and firmware.hex becomes its programming file.

**Verification:** two ports read different addresses in the same cycle; word at 0x80; read latency one cycle.

### 6.9 `ram_sp`

Diagram: `diagrams/blk_ram_sp.png`.  Kind rtl, owner Vedam, Verilog-2001. 4 KB data RAM with byte write enables (compilers emit sb and sh).

Parameters: `RAM_WORDS=1024`

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk` | in | 1 | clock | `clk` | clk_rst_gen.clk | core | 50 MHz |
| `s_sel_i` | in | 1 | pulse | `ram_sel` | bus_interconnect.ram_sel_o | core | access this cycle (exactly one cycle per access) |
| `s_we_i` | in | 1 | level | `ram_we` | bus_interconnect.ram_we_o | core | 1 = write, 0 = read |
| `s_be_i` | in | 4 | mask | `ram_be` | bus_interconnect.ram_be_o | core | byte enables (register banks may ignore; RAM must honour) |
| `s_addr_i` | in | 12 | byte offset | `ram_addr` | bus_interconnect.ram_addr_o | core | byte offset inside the region; word aligned, use [11:2] |
| `s_wdata_i` | in | 32 | word | `ram_wdata` | bus_interconnect.ram_wdata_o | core | write data |
| `s_rdata_o` | out | 32 | word | `ram_rdata` | bus_interconnect.ram_rdata_i | core | read data, REGISTERED: valid the cycle after s_sel_i |

**How the data moves inside**

1. When s_sel_i and s_we_i are high, each byte lane i of word s_addr_i[11:2] is written if s_be_i[i] = 1.
2. When s_sel_i is high, the addressed word is registered into s_rdata_o (valid the next cycle). Read during write to the same address returns the new data on the next read (documented behaviour).

**Timing and numbers:** registered read: one cycle

**FPGA-only / bring-up / GDSII notes:** block RAM inference; in the GDSII an SRAM macro or a flop array (area decision of the layout phase; 12 KB of memory dominates the area).

**Verification:** word write; byte write 0xAA at be 0001; halfword write at be 1100; read latency exactly one cycle.

### 6.10 `bus_interconnect`

Diagram: `diagrams/blk_bus_interconnect.png`.  Kind rtl, owner Vedam, Verilog-2001. Connects Ibex to the memories and the six register banks. Zero wait states; every address gets an answer.

Parameters: `ROM_BASE`, `ROM_MASK`, `RAM_BASE`, `BANK_BASE (localparams)`

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk` | in | 1 | clock | `clk` | clk_rst_gen.clk | core | 50 MHz system clock |
| `rst_n` | in | 1 | level | `rst_n` | clk_rst_gen.rst_n | core | active-low reset, synchronous release |
| `instr_req_i` | in | 1 | level | `instr_req` | cpu_subsystem.instr_req_o | core | from Ibex |
| `instr_addr_i` | in | 32 | byte addr | `instr_addr` | cpu_subsystem.instr_addr_o | core | from Ibex |
| `instr_gnt_o` | out | 1 | level | `instr_gnt` | cpu_subsystem.instr_gnt_i | core | = instr_req_i (same cycle) |
| `instr_rvalid_o` | out | 1 | pulse | `instr_rvalid` | cpu_subsystem.instr_rvalid_i | core | one cycle after the request |
| `instr_rdata_o` | out | 32 | word | `instr_rdata` | cpu_subsystem.instr_rdata_i | core | ROM word |
| `instr_err_o` | out | 1 | level | `instr_err` | cpu_subsystem.instr_err_i | core | fetch outside ROM |
| `data_req_i` | in | 1 | level | `data_req` | cpu_subsystem.data_req_o | core | from Ibex |
| `data_we_i` | in | 1 | level | `data_we` | cpu_subsystem.data_we_o | core | 1 = store |
| `data_be_i` | in | 4 | mask | `data_be` | cpu_subsystem.data_be_o | core | byte enables |
| `data_addr_i` | in | 32 | byte addr | `data_addr` | cpu_subsystem.data_addr_o | core | from Ibex |
| `data_wdata_i` | in | 32 | word | `data_wdata` | cpu_subsystem.data_wdata_o | core | from Ibex |
| `data_gnt_o` | out | 1 | level | `data_gnt` | cpu_subsystem.data_gnt_i | core | = data_req_i (same cycle) |
| `data_rvalid_o` | out | 1 | pulse | `data_rvalid` | cpu_subsystem.data_rvalid_i | core | one cycle later, reads AND writes |
| `data_rdata_o` | out | 32 | word | `data_rdata` | cpu_subsystem.data_rdata_i | core | registered read mux |
| `data_err_o` | out | 1 | level | `data_err` | cpu_subsystem.data_err_i | core | unmapped address or write to ROM |
| `rom_ia_req_o` | out | 1 | pulse | `rom_ia_req` | rom_dp.ia_req_i | core | ROM instruction port request |
| `rom_ia_addr_o` | out | 13 | byte addr | `rom_ia_addr` | rom_dp.ia_addr_i | core | ROM instruction address |
| `rom_ia_rdata_i` | in | 32 | word | `rom_ia_rdata` | rom_dp.ia_rdata_o | core | ROM instruction data |
| `rom_sel_o` | out | 1 | pulse | `rom_sel` | rom_dp.s_sel_i | core | ROM data-read select |
| `rom_addr_o` | out | 13 | byte addr | `rom_addr` | rom_dp.s_addr_i | core | ROM data address |
| `rom_rdata_i` | in | 32 | word | `rom_rdata` | rom_dp.s_rdata_o | core | ROM data |
| `ram_sel_o` | out | 1 | pulse | `ram_sel` | ram_sp.s_sel_i | core | RAM select |
| `ram_we_o` | out | 1 | level | `ram_we` | ram_sp.s_we_i | core | RAM write |
| `ram_be_o` | out | 4 | mask | `ram_be` | ram_sp.s_be_i | core | RAM byte enables |
| `ram_addr_o` | out | 12 | byte offset | `ram_addr` | ram_sp.s_addr_i | core | RAM address |
| `ram_wdata_o` | out | 32 | word | `ram_wdata` | ram_sp.s_wdata_i | core | RAM write data |
| `ram_rdata_i` | in | 32 | word | `ram_rdata` | ram_sp.s_rdata_o | core | RAM read data |
| `tmr_sel_o` | out | 1 | pulse | `tmr_sel` | timer_unit.s_sel_i | core | TMR bank slave bus |
| `tmr_we_o` | out | 1 | level | `tmr_we` | timer_unit.s_we_i | core | TMR bank slave bus |
| `tmr_be_o` | out | 4 | mask | `tmr_be` | timer_unit.s_be_i | core | TMR bank slave bus |
| `tmr_addr_o` | out | 12 | byte offset | `tmr_addr` | timer_unit.s_addr_i | core | TMR bank slave bus |
| `tmr_wdata_o` | out | 32 | word | `tmr_wdata` | timer_unit.s_wdata_i | core | TMR bank slave bus |
| `tmr_rdata_i` | in | 32 | word | `tmr_rdata` | timer_unit.s_rdata_o | core | TMR bank slave bus |
| `i2c_sel_o` | out | 1 | pulse | `i2c_sel` | i2c_sensor_subsystem.s_sel_i | core | I2C bank slave bus |
| `i2c_we_o` | out | 1 | level | `i2c_we` | i2c_sensor_subsystem.s_we_i | core | I2C bank slave bus |
| `i2c_be_o` | out | 4 | mask | `i2c_be` | i2c_sensor_subsystem.s_be_i | core | I2C bank slave bus |
| `i2c_addr_o` | out | 12 | byte offset | `i2c_addr` | i2c_sensor_subsystem.s_addr_i | core | I2C bank slave bus |
| `i2c_wdata_o` | out | 32 | word | `i2c_wdata` | i2c_sensor_subsystem.s_wdata_i | core | I2C bank slave bus |
| `i2c_rdata_i` | in | 32 | word | `i2c_rdata` | i2c_sensor_subsystem.s_rdata_o | core | I2C bank slave bus |
| `sens_sel_o` | out | 1 | pulse | `sens_sel` | sensor_pipeline.s_sel_i | core | SENS bank slave bus |
| `sens_we_o` | out | 1 | level | `sens_we` | sensor_pipeline.s_we_i | core | SENS bank slave bus |
| `sens_be_o` | out | 4 | mask | `sens_be` | sensor_pipeline.s_be_i | core | SENS bank slave bus |
| `sens_addr_o` | out | 12 | byte offset | `sens_addr` | sensor_pipeline.s_addr_i | core | SENS bank slave bus |
| `sens_wdata_o` | out | 32 | word | `sens_wdata` | sensor_pipeline.s_wdata_i | core | SENS bank slave bus |
| `sens_rdata_i` | in | 32 | word | `sens_rdata` | sensor_pipeline.s_rdata_o | core | SENS bank slave bus |
| `pid_sel_o` | out | 1 | pulse | `pid_sel` | hw_pid_accel.s_sel_i | core | PID bank slave bus |
| `pid_we_o` | out | 1 | level | `pid_we` | hw_pid_accel.s_we_i | core | PID bank slave bus |
| `pid_be_o` | out | 4 | mask | `pid_be` | hw_pid_accel.s_be_i | core | PID bank slave bus |
| `pid_addr_o` | out | 12 | byte offset | `pid_addr` | hw_pid_accel.s_addr_i | core | PID bank slave bus |
| `pid_wdata_o` | out | 32 | word | `pid_wdata` | hw_pid_accel.s_wdata_i | core | PID bank slave bus |
| `pid_rdata_i` | in | 32 | word | `pid_rdata` | hw_pid_accel.s_rdata_o | core | PID bank slave bus |
| `pwm_sel_o` | out | 1 | pulse | `pwm_sel` | actuation_subsystem.s_sel_i | core | PWM bank slave bus |
| `pwm_we_o` | out | 1 | level | `pwm_we` | actuation_subsystem.s_we_i | core | PWM bank slave bus |
| `pwm_be_o` | out | 4 | mask | `pwm_be` | actuation_subsystem.s_be_i | core | PWM bank slave bus |
| `pwm_addr_o` | out | 12 | byte offset | `pwm_addr` | actuation_subsystem.s_addr_i | core | PWM bank slave bus |
| `pwm_wdata_o` | out | 32 | word | `pwm_wdata` | actuation_subsystem.s_wdata_i | core | PWM bank slave bus |
| `pwm_rdata_i` | in | 32 | word | `pwm_rdata` | actuation_subsystem.s_rdata_o | core | PWM bank slave bus |
| `saf_sel_o` | out | 1 | pulse | `saf_sel` | safety_fault_monitor.s_sel_i | core | SAF bank slave bus |
| `saf_we_o` | out | 1 | level | `saf_we` | safety_fault_monitor.s_we_i | core | SAF bank slave bus |
| `saf_be_o` | out | 4 | mask | `saf_be` | safety_fault_monitor.s_be_i | core | SAF bank slave bus |
| `saf_addr_o` | out | 12 | byte offset | `saf_addr` | safety_fault_monitor.s_addr_i | core | SAF bank slave bus |
| `saf_wdata_o` | out | 32 | word | `saf_wdata` | safety_fault_monitor.s_wdata_i | core | SAF bank slave bus |
| `saf_rdata_i` | in | 32 | word | `saf_rdata` | safety_fault_monitor.s_rdata_o | core | SAF bank slave bus |

**How the data moves inside**

1. Instruction side: instr_gnt_o = instr_req_i (same cycle). Only ROM is fetchable: rom_ia_req_o and rom_ia_addr_o[12:0] drive the ROM instruction port; one cycle later instr_rvalid_o = 1 with instr_rdata_o = rom_ia_rdata_i. A fetch outside ROM returns instr_rvalid_o with instr_err_o = 1.
2. Data side: data_gnt_o = data_req_i (same cycle). The address decoder compares the top address bits: ROM window addr[31:13] == 0; bank n addr[31:12] == 0x10000 + n; RAM addr[31:12] == 0x20000; anything else is unmapped.
3. The select / write-enable / byte-enable / address / write-data signals fan out to the 8 targets; the selects are one-cycle pulses aligned with the request.
4. sel_q registers the decoded select (and the error flag). One cycle later the read-data mux outputs the REGISTERED read data of the selected slave on data_rdata_o together with data_rvalid_o = 1. Writes also get data_rvalid_o (Ibex waits for it).
5. error responder: an unmapped address, or a write to ROM, returns data_rvalid_o with data_err_o = 1, selects no slave and causes no side effect. No access may ever hang the CPU. Ibex turns the error into exception cause 1, 5 or 7 at vector offset 0x00.

**Timing and numbers:** grant: same cycle; response: next cycle; a load or store therefore takes at least 2 cycles in Ibex.

**FPGA-only / bring-up / GDSII notes:** nothing FPGA-specific.

**Verification:** 7 vectors: RAM word and byte write; read the six IDs; unmapped read; write to ROM; 3 back-to-back reads of different targets; instruction fetch from ROM and from RAM (error); acceptance = real Ibex reads all six IDs (tb_cpu_bus: PASS).

### 6.11 `cpu_subsystem`

Diagram: `diagrams/blk_cpu_subsystem.png`.  Kind rtl, owner Conolas, SystemVerilog (Ibex). Ibex RV32IMC (small configuration) with every unused port tied off. It supervises; it is never in the real-time loop.

Parameters: `BOOT_ADDR=32'h0000_0000`

**Ports** (comes from / goes to is taken from the netlist)

| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |
|---|---|---|---|---|---|---|---|
| `clk` | in | 1 | clock | `clk` | clk_rst_gen.clk | core | 50 MHz system clock |
| `rst_n` | in | 1 | level | `rst_n` | clk_rst_gen.rst_n | core | active-low reset, synchronous release |
| `instr_req_o` | out | 1 | level | `instr_req` | bus_interconnect.instr_req_i | core | instruction request |
| `instr_gnt_i` | in | 1 | level | `instr_gnt` | bus_interconnect.instr_gnt_o | core | granted |
| `instr_rvalid_i` | in | 1 | pulse | `instr_rvalid` | bus_interconnect.instr_rvalid_o | core | response valid |
| `instr_addr_o` | out | 32 | byte addr | `instr_addr` | bus_interconnect.instr_addr_i | core | fetch address |
| `instr_rdata_i` | in | 32 | word | `instr_rdata` | bus_interconnect.instr_rdata_o | core | instruction |
| `instr_err_i` | in | 1 | level | `instr_err` | bus_interconnect.instr_err_o | core | bus error |
| `data_req_o` | out | 1 | level | `data_req` | bus_interconnect.data_req_i | core | data request |
| `data_gnt_i` | in | 1 | level | `data_gnt` | bus_interconnect.data_gnt_o | core | granted |
| `data_rvalid_i` | in | 1 | pulse | `data_rvalid` | bus_interconnect.data_rvalid_o | core | response valid |
| `data_we_o` | out | 1 | level | `data_we` | bus_interconnect.data_we_i | core | store |
| `data_be_o` | out | 4 | mask | `data_be` | bus_interconnect.data_be_i | core | byte enables |
| `data_addr_o` | out | 32 | byte addr | `data_addr` | bus_interconnect.data_addr_i | core | address |
| `data_wdata_o` | out | 32 | word | `data_wdata` | bus_interconnect.data_wdata_i | core | write data |
| `data_rdata_i` | in | 32 | word | `data_rdata` | bus_interconnect.data_rdata_o | core | read data |
| `data_err_i` | in | 1 | level | `data_err` | bus_interconnect.data_err_o | core | bus error |
| `irq_timer_i` | in | 1 | level | `irq_timer` | timer_unit.irq_timer_o | core | machine timer interrupt (mcause 7, vector 0x1C) |
| `irq_fault_i` | in | 1 | level | `irq_fault` | safety_fault_monitor.irq_fault_o | core | machine external interrupt (mcause 11, vector 0x2C) |
| `core_sleep_o` | out | 1 | level | `cpu_core_sleep` | (debug tap) | dbg | high while the core sleeps (wfi) |
| `double_fault_seen_o` | out | 1 | level | `cpu_double_fault` | (debug tap) | dbg | exception inside an exception handler |

**How the data moves inside**

1. After reset (async inside Ibex) the first instruction is fetched from boot_addr 0x0 + 0x80 through the instruction port; the bus answers from ROM.
2. IF stage: program counter, prefetch buffer, compressed-instruction expander. ID/EX stage: decoder, controller, ALU, multiplier/divider and the load/store unit. 32 registers in flip-flops.
3. Loads and stores leave on the data port (data_req_o, data_we_o, data_be_o, data_addr_o, data_wdata_o) and stall the pipeline until data_rvalid_i; a bus error becomes exception cause 5 (load) or 7 (store).
4. irq_timer_i (machine timer, mcause 7) jumps to vector 0x1C and irq_fault_i (machine external, mcause 11) to vector 0x2C once the interrupt is enabled in mie and mstatus.MIE; all interrupts are off after reset and the lines are level-sensitive.
5. Tie-offs: test_en_i = 0, scan_rst_ni = 1, hart_id_i = 0, fetch_enable_i = on (MuBi), mcounteren_writable_i = on, debug_req_i = 0, irq_software / irq_fast / irq_nm = 0, CHERIoT off, integrity and scrambling inputs 0. Outputs core_sleep_o and double_fault_seen_o are debug taps.

**Timing and numbers:** load/store >= 2 cycles; multiply 3; divide 38; first fetch at 0x80.

**FPGA-only / bring-up / GDSII notes:** RegFileFF (or RegFileFPGA) and a pass-through prim_clock_gating on the FPGA; RegFileLatch and a real clock-gating cell are options for the GDSII; test_en_i / scan_rst_ni become scan connections in the layout flow.

**Verification:** tb_cpu_bus with the real Ibex: ID read test, RAM test, timer-interrupt test and the full application were run (all PASS); lint of the wrapper against the pinned Ibex commit af456e2: 0 warnings.

### 6.12 `ecu_soc_top`

Diagram: `diagrams/blk_ecu_soc_top.png`.  Kind top, owner Conolas, Verilog-2001. The SoC top: instantiates and wires the 11 RTL blocks exactly as the netlist; no logic of its own.

Parameters: `HW_ONLY=0 (1 = Wing A runs without CPU; FPGA phase 1 only)`

**How the data moves inside**

1. Parameter HW_ONLY (default 0). HW_ONLY = 1 passes DEF_EN = 1 to timer_unit, i2c_sensor_subsystem, sensor_pipeline, hw_pid_accel, actuation_subsystem and safety_fault_monitor, so Wing A runs with no CPU (FPGA phase 1). DEF_WD_EN stays 0.
2. Wing A (real-time): i2c -> sensor_pipeline -> hw_pid_accel -> actuation, with control_tick from the timer and pwm_enable from the safety monitor.
3. Wing B (supervisory): cpu_subsystem <-> bus_interconnect <-> rom_dp, ram_sp and the six register banks; irq_timer and irq_fault return to the CPU.
4. The 20 top-level pins are raw: the SoC itself synchronises them (ACR-1).

**Timing and numbers:** worst-case tick-to-motor path 22,550 cycles (0.451 ms) in a 97,656-cycle tick: margin 1.50 ms.

**FPGA-only / bring-up / GDSII notes:** HW_ONLY, arm_sw_i, bench_en_i, bench_sel_i, dbg_o and pll_locked_i are FPGA / bring-up items (see the FPGA-only table).

**Verification:** lint with Verilator -Wall: 0 warnings (generated skeleton and with the real Ibex wrapper); netlist checker: 36 checks pass.

### 6.13 `ecu_fpga_top`

Diagram: `diagrams/blk_ecu_fpga_top.png`.  Kind fpga, owner Jaydev, Verilog-2001 + FPGA primitives. FPGA-only board wrapper; replaced by the pad ring in the GDSII.

Parameters: `HW_ONLY (passed to ecu_soc_top)`

**How the data moves inside**

1. fpga_clk_gen (MMCM) turns the 100 MHz board oscillator into exactly 50 MHz and a locked signal: clk_in and pll_locked_i of ecu_soc_top.
2. The open-drain pad logic drives scl_pad / sda_pad low or lets them float (external pull-ups) and returns the pin levels as scl_i / sda_i.
3. All other pins (reset, E-stop, arm, bench, motor pins, LEDs) go straight through buffers; there are NO synchronisers here (ACR-1).
4. Instantiates ecu_soc_top with HW_ONLY (1 for the phase-1 bitstream, 0 for the final).

**Timing and numbers:** n/a

**FPGA-only / bring-up / GDSII notes:** the whole block is FPGA-only.

**Verification:** pin table and XDC; clock constraint 20 ns; scope the PWM pins with the motor supply disconnected before connecting motors.

### 6.14 `firmware`

Diagram: `diagrams/blk_firmware.png`.  Kind sw, owner Conolas, C + RISC-V assembly. C program in ROM that configures and supervises the hardware through the register banks.

**How the data moves inside**

1. startup.S: vector table at 0x00-0x7F (exceptions at 0x00, timer 0x1C, external 0x2C), reset jump at 0x80, stack pointer = 0x2000_1000, copy .data, clear .bss, mtvec, call main.
2. main.c boot: read the six ID words; configure the timer; enable I2C and wait INIT_DONE; set the pipeline bits and start calibration; load Kp, Ki*Ts, Kd, setpoint and limits; configure PWM; set the safety thresholds, enable watchdog and fault interrupt; enable interrupts; ARM.
3. Loop: on the timer heartbeat kick the watchdog and read telemetry; on a fault report read FAULT_STATUS and stay disarmed.
4. Rules: volatile 32-bit register access, time-out on every wait, interrupt handlers never read-modify-write peripheral registers.

**Timing and numbers:** boot-and-configure sequence is about 250 instructions (252 words of code).

**FPGA-only / bring-up / GDSII notes:** firmware.hex is the ROM initialisation file.

**Verification:** software model: tests 0, 1, 2, 4 pass and the application makes 32 register writes; real Ibex testbench: tests 0, 1, 3 and the application (same 32 writes).

## 7. FPGA-only and bring-up items (not in the GDSII)

| Item | Class | What | GDSII equivalent |
|---|---|---|---|
| ecu_fpga_top (entire wrapper) | FPGA | board wrapper: pin buffers, clock generator, open-drain pad logic, LED drivers, constraints | replaced by the pad ring / ecu_asic_top |
| fpga_clk_gen (MMCM/PLL) | FPGA | board oscillator (100 MHz on the Arty A7) -> exactly 50 MHz; produces pll_locked | external 50 MHz clock pad (or an ASIC PLL macro) |
| pll_locked_i | FPGA/ASIC | lock status of the clock generator; holds reset | real PLL lock if a PLL macro is used, else tie 1 |
| IOBUF / tri-state for scl_pad, sda_pad | FPGA | assign pad = drive_low ? 1b0 : 1bz (open-drain) | library open-drain I/O pad cell |
| arm_sw_i | bring-up | arm switch used when no CPU exists (phase 1) | tie 0; firmware arms through SAFE.CTRL |
| bench_en_i, bench_sel_i[1:0] | bring-up | open-loop motor bench table in actuation_subsystem | tie 0 (logic is optimised away) or keep as test-mode pins |
| HW_ONLY parameter and the DEF_EN plumbing | FPGA | phase-1 mode: Wing A runs with no CPU (blocks reset to enabled) | HW_ONLY = 0; DEF_EN constants removed or left at 0 |
| dbg_o[7:0] LEDs | FPGA/ASIC | status LEDs: fault, armed, calibrated | spare debug pins or removed |
| duty_l_o, duty_r_o, core_sleep_o, double_fault_seen_o | FPGA | debug taps probed by the ILA | unconnected |
| Vivado ILA / VIO cores and mark_debug attributes | FPGA | on-chip logic analyser | none |
| $readmemh ROM initialisation (rom_dp INIT_FILE) | FPGA/sim | ROM contents loaded at configuration/simulation start | ROM macro or mask ROM; firmware.hex becomes the programming file |
| BRAM inference for rom_dp / ram_sp | FPGA | block RAM | SRAM macros or flop arrays (area decision in the layout phase) |
| prim_clock_gating pass-through | FPGA | Ibex clock gate replaced by a wire | library clock-gating cell, or keep the wire |
| RegFile = RegFileFF / RegFileFPGA | FPGA | Ibex register file in flip-flops / distributed RAM | RegFileLatch (needs clock gating) or keep flip-flops |
| test_en_i, scan_rst_ni on ibex_top | DFT | tied 0 / 1 in FPGA | scan chain connections in the layout flow |
| rst_n_in button debounce by hold counter | FPGA/ASIC | the 255-cycle hold in clk_rst_gen | kept (power-on reset) |

## 8. Automated check result

```
PASS  net names unique (112 nets)
PASS  every one of the 222 block ports is connected to exactly one net
PASS  every one of the 20 top-level pins is connected to exactly one net
PASS  108 nets have loads; 4 are declared debug taps (no functional load)
PASS  port naming rule (_i / _o) holds everywhere
PASS  bank bus ports follow _o/_i too
PASS  TMR: 7 registers, offsets unique, word aligned, inside the 4 KB window
PASS  TMR: ID register at 0x00 = 0x54494D01
PASS  TMR: ID ASCII "TIM" + version 01
PASS  I2C: 13 registers, offsets unique, word aligned, inside the 4 KB window
PASS  I2C: ID register at 0x00 = 0x49324301
PASS  I2C: ID ASCII "I2C" + version 01
PASS  SENS: 13 registers, offsets unique, word aligned, inside the 4 KB window
PASS  SENS: ID register at 0x00 = 0x53454E01
PASS  SENS: ID ASCII "SEN" + version 01
PASS  PID: 13 registers, offsets unique, word aligned, inside the 4 KB window
PASS  PID: ID register at 0x00 = 0x50494401
PASS  PID: ID ASCII "PID" + version 01
PASS  PWM: 12 registers, offsets unique, word aligned, inside the 4 KB window
PASS  PWM: ID register at 0x00 = 0x50574D01
PASS  PWM: ID ASCII "PWM" + version 01
PASS  SAFE: 11 registers, offsets unique, word aligned, inside the 4 KB window
PASS  SAFE: ID register at 0x00 = 0x53414601
PASS  SAFE: ID ASCII "SAF" + version 01
PASS  memory map: 8 windows, no overlap
PASS  every window is aligned to its size (decode = top address bits only)
PASS  contract section 6 cross-check: all 23 contract signals present, every contract receiver is wired
PASS  firmware header ecu_regs.h matches the model: all 69 registers at the right offsets
PASS  timing: tick-to-pwm worst case 22550 cycles (0.451 ms) < tick period 97656 cycles (1.953 ms); margin 1.50 ms
PASS  every RTL block has clk; rst_n on all except rom_dp and ram_sp (pure memories)
PASS  bank TMR: timer_unit has the full slave bus
PASS  bank I2C: i2c_sensor_subsystem has the full slave bus
PASS  bank SENS: sensor_pipeline has the full slave bus
PASS  bank PID: hw_pid_accel has the full slave bus
PASS  bank PWM: actuation_subsystem has the full slave bus
PASS  bank SAF: safety_fault_monitor has the full slave bus
NOTE  vs contract v1.0: control_tick: extra receiver(s) ['sensor_pipeline'] (ACR)
```
