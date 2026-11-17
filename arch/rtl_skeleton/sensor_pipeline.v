// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// Skeleton: outputs tied to safe constants. Owner: Dipiksha. Replace by the real RTL keeping the ports.
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNUSEDPARAM
module sensor_pipeline #(
  parameter DEF_EN = 0
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
  input wire [15:0] imu_ax_i,
  input wire [15:0] imu_ay_i,
  input wire [15:0] imu_az_i,
  input wire [15:0] imu_gx_i,
  input wire [15:0] imu_gy_i,
  input wire [15:0] imu_gz_i,
  input wire imu_init_done_i,
  input wire [31:0] setpoint_i,
  output wire pipe_valid_o,
  output wire [31:0] angle_o,
  output wire [31:0] err_o,
  output wire [31:0] rate_o,
  output wire calib_done_o
);
  assign s_rdata_o = 32'd0;   // safe default
  assign pipe_valid_o = 1'd0;   // safe default
  assign angle_o = 32'd0;   // safe default
  assign err_o = 32'd0;   // safe default
  assign rate_o = 32'd0;   // safe default
  assign calib_done_o = 1'd0;   // safe default
endmodule
`default_nettype wire
