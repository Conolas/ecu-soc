// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// Skeleton: outputs tied to safe constants. Owner: Kaushal. Replace by the real RTL keeping the ports.
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNUSEDPARAM
module i2c_sensor_subsystem #(
  parameter DEF_EN = 0,
  parameter CLK_DIV_DEF = 31,
  parameter DEV_ADDR_DEF = 7'h68
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
  input wire scl_i,
  input wire sda_i,
  output wire scl_drive_low_o,
  output wire sda_drive_low_o,
  output wire imu_valid_o,
  output wire [15:0] imu_ax_o,
  output wire [15:0] imu_ay_o,
  output wire [15:0] imu_az_o,
  output wire [15:0] imu_gx_o,
  output wire [15:0] imu_gy_o,
  output wire [15:0] imu_gz_o,
  output wire imu_busy_o,
  output wire imu_err_o,
  output wire imu_init_done_o
);
  assign s_rdata_o = 32'd0;   // safe default
  assign scl_drive_low_o = 1'd0;   // safe default
  assign sda_drive_low_o = 1'd0;   // safe default
  assign imu_valid_o = 1'd0;   // safe default
  assign imu_ax_o = 16'd0;   // safe default
  assign imu_ay_o = 16'd0;   // safe default
  assign imu_az_o = 16'd0;   // safe default
  assign imu_gx_o = 16'd0;   // safe default
  assign imu_gy_o = 16'd0;   // safe default
  assign imu_gz_o = 16'd0;   // safe default
  assign imu_busy_o = 1'd0;   // safe default
  assign imu_err_o = 1'd0;   // safe default
  assign imu_init_done_o = 1'd0;   // safe default
endmodule
`default_nettype wire
