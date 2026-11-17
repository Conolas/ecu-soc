// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// Skeleton: outputs tied to safe constants. Owner: Jaydev. Replace by the real RTL keeping the ports.
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNUSEDPARAM
module actuation_subsystem #(
  parameter DEF_EN = 0,
  parameter PERIOD_DEF = 2500,
  parameter DEADTIME_DEF = 250
) (
  input wire clk,
  input wire rst_n,
  input wire s_sel_i,
  input wire s_we_i,
  input wire [3:0] s_be_i,
  input wire [11:0] s_addr_i,
  input wire [31:0] s_wdata_i,
  output wire [31:0] s_rdata_o,
  input wire cmd_valid_i,
  input wire [31:0] cmd_i,
  input wire pwm_enable_i,
  input wire bench_en_i,
  input wire [1:0] bench_sel_i,
  output wire l_rpwm_o,
  output wire l_lpwm_o,
  output wire l_r_en_o,
  output wire l_l_en_o,
  output wire r_rpwm_o,
  output wire r_lpwm_o,
  output wire r_r_en_o,
  output wire r_l_en_o,
  output wire [15:0] duty_l_o,
  output wire [15:0] duty_r_o
);
  assign s_rdata_o = 32'd0;   // safe default
  assign l_rpwm_o = 1'd0;   // safe default
  assign l_lpwm_o = 1'd0;   // safe default
  assign l_r_en_o = 1'd0;   // safe default
  assign l_l_en_o = 1'd0;   // safe default
  assign r_rpwm_o = 1'd0;   // safe default
  assign r_lpwm_o = 1'd0;   // safe default
  assign r_r_en_o = 1'd0;   // safe default
  assign r_l_en_o = 1'd0;   // safe default
  assign duty_l_o = 16'd0;   // safe default
  assign duty_r_o = 16'd0;   // safe default
endmodule
`default_nettype wire
