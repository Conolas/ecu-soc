// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// ecu_soc_top: wires every block. HW_ONLY=1 -> blocks reset to enabled so Wing A runs with NO CPU (FPGA phase 1). Final SoC: HW_ONLY=0.
// verilator lint_off UNUSEDSIGNAL
module ecu_soc_top #(
  parameter HW_ONLY = 0
) (
  input wire clk_in,
  input wire rst_n_in,
  input wire pll_locked_i,
  input wire estop_n_i,
  input wire arm_sw_i,
  input wire bench_en_i,
  input wire [1:0] bench_sel_i,
  input wire scl_i,
  input wire sda_i,
  output wire scl_drive_low_o,
  output wire sda_drive_low_o,
  output wire l_rpwm_o,
  output wire l_lpwm_o,
  output wire l_r_en_o,
  output wire l_l_en_o,
  output wire r_rpwm_o,
  output wire r_lpwm_o,
  output wire r_r_en_o,
  output wire r_l_en_o,
  output wire [7:0] dbg_o
);

  wire clk;   // one 50 MHz clock for everything, including Ibex
  wire rst_n;   // async assert, sync release
  wire control_tick;   // about 512 Hz sample trigger; sensor_pipeline input added by ACR-2
  wire imu_valid;   // a full 14-byte sample was read
  wire [15:0] imu_ax;   // raw IMU value
  wire [15:0] imu_ay;   // raw IMU value
  wire [15:0] imu_az;   // raw IMU value
  wire [15:0] imu_gx;   // raw IMU value
  wire [15:0] imu_gy;   // raw IMU value
  wire [15:0] imu_gz;   // raw IMU value
  wire imu_busy;   // overrun detection
  wire imu_err;   // failed transaction
  wire imu_init_done;   // MPU-6050 configured
  wire [31:0] setpoint;   // from the PID SETPOINT register
  wire pipe_valid;   // angle, err, rate valid together
  wire [31:0] angle;   // filtered, trimmed
  wire [31:0] err;   // setpoint - angle
  wire [31:0] rate;   // filtered, bias-corrected
  wire calib_done;   // arming precondition
  wire pwm_cmd_valid;   // new motor command
  wire [31:0] pwm_cmd;   // balance command
  wire pid_sat;   // saturation monitor
  wire pwm_enable;   // motors allowed (the only authority over the motors)
  wire irq_timer;   // housekeeping interrupt, W1C in TMR
  wire irq_fault;   // fault interrupt, cleared through SAFE regs
  wire [15:0] duty_l;   // debug tap: ILA probe
  wire [15:0] duty_r;   // debug tap: ILA probe
  wire cpu_core_sleep;   // debug tap: ILA probe
  wire cpu_double_fault;   // debug tap: ILA probe
  wire instr_req;   // Ibex instruction port
  wire [31:0] instr_addr;   // Ibex instruction port
  wire instr_gnt;   // grant = request, same cycle
  wire instr_rvalid;   // response, next cycle
  wire [31:0] instr_rdata;   // instruction word
  wire instr_err;   // fetch error
  wire data_req;   // Ibex data port
  wire data_we;   // store
  wire [3:0] data_be;   // byte enables
  wire [31:0] data_addr;   // address
  wire [31:0] data_wdata;   // write data
  wire data_gnt;   // grant
  wire data_rvalid;   // response
  wire [31:0] data_rdata;   // read data
  wire data_err;   // bus error
  wire rom_ia_req;   // bus
  wire [12:0] rom_ia_addr;   // bus
  wire [31:0] rom_ia_rdata;   // bus
  wire rom_sel;   // bus
  wire [12:0] rom_addr;   // bus
  wire [31:0] rom_rdata;   // bus
  wire ram_sel;   // bus
  wire ram_we;   // bus
  wire [3:0] ram_be;   // bus
  wire [11:0] ram_addr;   // bus
  wire [31:0] ram_wdata;   // bus
  wire [31:0] ram_rdata;   // bus
  wire tmr_sel;   // TMR bank slave bus
  wire tmr_we;   // TMR bank slave bus
  wire [3:0] tmr_be;   // TMR bank slave bus
  wire [11:0] tmr_addr;   // TMR bank slave bus
  wire [31:0] tmr_wdata;   // TMR bank slave bus
  wire [31:0] tmr_rdata;   // TMR bank read data
  wire i2c_sel;   // I2C bank slave bus
  wire i2c_we;   // I2C bank slave bus
  wire [3:0] i2c_be;   // I2C bank slave bus
  wire [11:0] i2c_addr;   // I2C bank slave bus
  wire [31:0] i2c_wdata;   // I2C bank slave bus
  wire [31:0] i2c_rdata;   // I2C bank read data
  wire sens_sel;   // SENS bank slave bus
  wire sens_we;   // SENS bank slave bus
  wire [3:0] sens_be;   // SENS bank slave bus
  wire [11:0] sens_addr;   // SENS bank slave bus
  wire [31:0] sens_wdata;   // SENS bank slave bus
  wire [31:0] sens_rdata;   // SENS bank read data
  wire pid_sel;   // PID bank slave bus
  wire pid_we;   // PID bank slave bus
  wire [3:0] pid_be;   // PID bank slave bus
  wire [11:0] pid_addr;   // PID bank slave bus
  wire [31:0] pid_wdata;   // PID bank slave bus
  wire [31:0] pid_rdata;   // PID bank read data
  wire pwm_sel;   // PWM bank slave bus
  wire pwm_we;   // PWM bank slave bus
  wire [3:0] pwm_be;   // PWM bank slave bus
  wire [11:0] pwm_addr;   // PWM bank slave bus
  wire [31:0] pwm_wdata;   // PWM bank slave bus
  wire [31:0] pwm_rdata;   // PWM bank read data
  wire saf_sel;   // SAF bank slave bus
  wire saf_we;   // SAF bank slave bus
  wire [3:0] saf_be;   // SAF bank slave bus
  wire [11:0] saf_addr;   // SAF bank slave bus
  wire [31:0] saf_wdata;   // SAF bank slave bus
  wire [31:0] saf_rdata;   // SAF bank read data

  clk_rst_gen u_clk_rst_gen (
    .clk_in(clk_in),
    .rst_n_in(rst_n_in),
    .pll_locked_i(pll_locked_i),
    .clk(clk),
    .rst_n(rst_n)
  );

  timer_unit #(
    .DEF_EN(HW_ONLY),
    .TICK_PERIOD_DEF(97656),
    .IRQ_DIV_DEF(51)
  ) u_timer_unit (
    .clk(clk),
    .rst_n(rst_n),
    .s_sel_i(tmr_sel),
    .s_we_i(tmr_we),
    .s_be_i(tmr_be),
    .s_addr_i(tmr_addr),
    .s_wdata_i(tmr_wdata),
    .s_rdata_o(tmr_rdata),
    .sched_busy_i(imu_busy),
    .control_tick_o(control_tick),
    .irq_timer_o(irq_timer)
  );

  i2c_sensor_subsystem #(
    .DEF_EN(HW_ONLY),
    .CLK_DIV_DEF(31),
    .DEV_ADDR_DEF(7'h68)
  ) u_i2c_sensor_subsystem (
    .clk(clk),
    .rst_n(rst_n),
    .s_sel_i(i2c_sel),
    .s_we_i(i2c_we),
    .s_be_i(i2c_be),
    .s_addr_i(i2c_addr),
    .s_wdata_i(i2c_wdata),
    .s_rdata_o(i2c_rdata),
    .control_tick_i(control_tick),
    .scl_i(scl_i),
    .sda_i(sda_i),
    .scl_drive_low_o(scl_drive_low_o),
    .sda_drive_low_o(sda_drive_low_o),
    .imu_valid_o(imu_valid),
    .imu_ax_o(imu_ax),
    .imu_ay_o(imu_ay),
    .imu_az_o(imu_az),
    .imu_gx_o(imu_gx),
    .imu_gy_o(imu_gy),
    .imu_gz_o(imu_gz),
    .imu_busy_o(imu_busy),
    .imu_err_o(imu_err),
    .imu_init_done_o(imu_init_done)
  );

  sensor_pipeline #(
    .DEF_EN(HW_ONLY)
  ) u_sensor_pipeline (
    .clk(clk),
    .rst_n(rst_n),
    .s_sel_i(sens_sel),
    .s_we_i(sens_we),
    .s_be_i(sens_be),
    .s_addr_i(sens_addr),
    .s_wdata_i(sens_wdata),
    .s_rdata_o(sens_rdata),
    .control_tick_i(control_tick),
    .imu_valid_i(imu_valid),
    .imu_ax_i(imu_ax),
    .imu_ay_i(imu_ay),
    .imu_az_i(imu_az),
    .imu_gx_i(imu_gx),
    .imu_gy_i(imu_gy),
    .imu_gz_i(imu_gz),
    .imu_init_done_i(imu_init_done),
    .setpoint_i(setpoint),
    .pipe_valid_o(pipe_valid),
    .angle_o(angle),
    .err_o(err),
    .rate_o(rate),
    .calib_done_o(calib_done)
  );

  hw_pid_accel #(
    .DEF_EN(HW_ONLY),
    .DEF_KP(0),
    .DEF_KI(0),
    .DEF_KD(0),
    .DEF_SETPOINT(0),
    .DEF_OUT_LIMIT(16384)
  ) u_hw_pid_accel (
    .clk(clk),
    .rst_n(rst_n),
    .s_sel_i(pid_sel),
    .s_we_i(pid_we),
    .s_be_i(pid_be),
    .s_addr_i(pid_addr),
    .s_wdata_i(pid_wdata),
    .s_rdata_o(pid_rdata),
    .err_valid_i(pipe_valid),
    .err_i(err),
    .rate_i(rate),
    .run_i(pwm_enable),
    .pwm_cmd_o(pwm_cmd),
    .pwm_cmd_valid_o(pwm_cmd_valid),
    .pid_sat_o(pid_sat),
    .setpoint_o(setpoint)
  );

  actuation_subsystem #(
    .DEF_EN(HW_ONLY),
    .PERIOD_DEF(2500),
    .DEADTIME_DEF(250)
  ) u_actuation_subsystem (
    .clk(clk),
    .rst_n(rst_n),
    .s_sel_i(pwm_sel),
    .s_we_i(pwm_we),
    .s_be_i(pwm_be),
    .s_addr_i(pwm_addr),
    .s_wdata_i(pwm_wdata),
    .s_rdata_o(pwm_rdata),
    .cmd_valid_i(pwm_cmd_valid),
    .cmd_i(pwm_cmd),
    .pwm_enable_i(pwm_enable),
    .bench_en_i(bench_en_i),
    .bench_sel_i(bench_sel_i),
    .l_rpwm_o(l_rpwm_o),
    .l_lpwm_o(l_lpwm_o),
    .l_r_en_o(l_r_en_o),
    .l_l_en_o(l_l_en_o),
    .r_rpwm_o(r_rpwm_o),
    .r_lpwm_o(r_lpwm_o),
    .r_r_en_o(r_r_en_o),
    .r_l_en_o(r_l_en_o),
    .duty_l_o(duty_l),
    .duty_r_o(duty_r)
  );

  safety_fault_monitor #(
    .DEF_EN(HW_ONLY),
    .DEF_WD_EN(1'b0)
  ) u_safety_fault_monitor (
    .clk(clk),
    .rst_n(rst_n),
    .s_sel_i(saf_sel),
    .s_we_i(saf_we),
    .s_be_i(saf_be),
    .s_addr_i(saf_addr),
    .s_wdata_i(saf_wdata),
    .s_rdata_o(saf_rdata),
    .control_tick_i(control_tick),
    .imu_valid_i(imu_valid),
    .imu_err_i(imu_err),
    .imu_init_done_i(imu_init_done),
    .calib_done_i(calib_done),
    .pipe_valid_i(pipe_valid),
    .angle_i(angle),
    .pid_sat_i(pid_sat),
    .estop_n_i(estop_n_i),
    .arm_sw_i(arm_sw_i),
    .pwm_enable_o(pwm_enable),
    .irq_fault_o(irq_fault),
    .dbg_o(dbg_o)
  );

  rom_dp #(
    .ROM_WORDS(2048),
    .INIT_FILE("firmware.hex")
  ) u_rom_dp (
    .clk(clk),
    .ia_req_i(rom_ia_req),
    .ia_addr_i(rom_ia_addr),
    .ia_rdata_o(rom_ia_rdata),
    .s_sel_i(rom_sel),
    .s_addr_i(rom_addr),
    .s_rdata_o(rom_rdata)
  );

  ram_sp #(
    .RAM_WORDS(1024)
  ) u_ram_sp (
    .clk(clk),
    .s_sel_i(ram_sel),
    .s_we_i(ram_we),
    .s_be_i(ram_be),
    .s_addr_i(ram_addr),
    .s_wdata_i(ram_wdata),
    .s_rdata_o(ram_rdata)
  );

  bus_interconnect u_bus_interconnect (
    .clk(clk),
    .rst_n(rst_n),
    .instr_req_i(instr_req),
    .instr_addr_i(instr_addr),
    .instr_gnt_o(instr_gnt),
    .instr_rvalid_o(instr_rvalid),
    .instr_rdata_o(instr_rdata),
    .instr_err_o(instr_err),
    .data_req_i(data_req),
    .data_we_i(data_we),
    .data_be_i(data_be),
    .data_addr_i(data_addr),
    .data_wdata_i(data_wdata),
    .data_gnt_o(data_gnt),
    .data_rvalid_o(data_rvalid),
    .data_rdata_o(data_rdata),
    .data_err_o(data_err),
    .rom_ia_req_o(rom_ia_req),
    .rom_ia_addr_o(rom_ia_addr),
    .rom_ia_rdata_i(rom_ia_rdata),
    .rom_sel_o(rom_sel),
    .rom_addr_o(rom_addr),
    .rom_rdata_i(rom_rdata),
    .ram_sel_o(ram_sel),
    .ram_we_o(ram_we),
    .ram_be_o(ram_be),
    .ram_addr_o(ram_addr),
    .ram_wdata_o(ram_wdata),
    .ram_rdata_i(ram_rdata),
    .tmr_sel_o(tmr_sel),
    .tmr_we_o(tmr_we),
    .tmr_be_o(tmr_be),
    .tmr_addr_o(tmr_addr),
    .tmr_wdata_o(tmr_wdata),
    .tmr_rdata_i(tmr_rdata),
    .i2c_sel_o(i2c_sel),
    .i2c_we_o(i2c_we),
    .i2c_be_o(i2c_be),
    .i2c_addr_o(i2c_addr),
    .i2c_wdata_o(i2c_wdata),
    .i2c_rdata_i(i2c_rdata),
    .sens_sel_o(sens_sel),
    .sens_we_o(sens_we),
    .sens_be_o(sens_be),
    .sens_addr_o(sens_addr),
    .sens_wdata_o(sens_wdata),
    .sens_rdata_i(sens_rdata),
    .pid_sel_o(pid_sel),
    .pid_we_o(pid_we),
    .pid_be_o(pid_be),
    .pid_addr_o(pid_addr),
    .pid_wdata_o(pid_wdata),
    .pid_rdata_i(pid_rdata),
    .pwm_sel_o(pwm_sel),
    .pwm_we_o(pwm_we),
    .pwm_be_o(pwm_be),
    .pwm_addr_o(pwm_addr),
    .pwm_wdata_o(pwm_wdata),
    .pwm_rdata_i(pwm_rdata),
    .saf_sel_o(saf_sel),
    .saf_we_o(saf_we),
    .saf_be_o(saf_be),
    .saf_addr_o(saf_addr),
    .saf_wdata_o(saf_wdata),
    .saf_rdata_i(saf_rdata)
  );

  cpu_subsystem #(
    .BOOT_ADDR(32'h0000_0000)
  ) u_cpu_subsystem (
    .clk(clk),
    .rst_n(rst_n),
    .instr_req_o(instr_req),
    .instr_gnt_i(instr_gnt),
    .instr_rvalid_i(instr_rvalid),
    .instr_addr_o(instr_addr),
    .instr_rdata_i(instr_rdata),
    .instr_err_i(instr_err),
    .data_req_o(data_req),
    .data_gnt_i(data_gnt),
    .data_rvalid_i(data_rvalid),
    .data_we_o(data_we),
    .data_be_o(data_be),
    .data_addr_o(data_addr),
    .data_wdata_o(data_wdata),
    .data_rdata_i(data_rdata),
    .data_err_i(data_err),
    .irq_timer_i(irq_timer),
    .irq_fault_i(irq_fault),
    .core_sleep_o(cpu_core_sleep),
    .double_fault_seen_o(cpu_double_fault)
  );

endmodule
`default_nettype wire
