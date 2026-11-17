// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// Skeleton: outputs tied to safe constants. Owner: Vedam. Replace by the real RTL keeping the ports.
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNUSEDPARAM
module safety_fault_monitor #(
  parameter DEF_EN = 0,
  parameter DEF_WD_EN = 0
) (
  input wire clk,
  input wire rst_n,
  input wire s_sel_i,
  input wire s_we_i,
  input wire [3:0] s_be_i,
  input wire [11:0] s_addr_i,
  input wire [31:0] s_wdata_i,
  output wire [31:0] s_rdata_o,
  input wire control_tick_i,
  input wire imu_valid_i,
  input wire imu_err_i,
  input wire imu_init_done_i,
  input wire calib_done_i,
  input wire pipe_valid_i,
  input wire [31:0] angle_i,
  input wire pid_sat_i,
  input wire estop_n_i,
  input wire arm_sw_i,
  output wire pwm_enable_o,
  output wire irq_fault_o,
  output wire [7:0] dbg_o
);
  assign s_rdata_o = 32'd0;   // safe default
  assign pwm_enable_o = 1'd0;   // safe default
  assign irq_fault_o = 1'd0;   // safe default
  assign dbg_o = 8'd0;   // safe default
endmodule
`default_nettype wire
