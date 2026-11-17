// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// Skeleton: outputs tied to safe constants. Owner: Conolas. Replace by the real RTL keeping the ports.
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNUSEDPARAM
module hw_pid_accel #(
  parameter DEF_EN = 0,
  parameter DEF_KP = 0,
  parameter DEF_KI = 0,
  parameter DEF_KD = 0,
  parameter DEF_SETPOINT = 0,
  parameter DEF_OUT_LIMIT = 16384
) (
  input wire clk,
  input wire rst_n,
  input wire s_sel_i,
  input wire s_we_i,
  input wire [3:0] s_be_i,
  input wire [11:0] s_addr_i,
  input wire [31:0] s_wdata_i,
  output wire [31:0] s_rdata_o,
  input wire err_valid_i,
  input wire [31:0] err_i,
  input wire [31:0] rate_i,
  input wire run_i,
  output wire [31:0] pwm_cmd_o,
  output wire pwm_cmd_valid_o,
  output wire pid_sat_o,
  output wire [31:0] setpoint_o
);
  assign s_rdata_o = 32'd0;   // safe default
  assign pwm_cmd_o = 32'd0;   // safe default
  assign pwm_cmd_valid_o = 1'd0;   // safe default
  assign pid_sat_o = 1'd0;   // safe default
  assign setpoint_o = 32'd0;   // safe default
endmodule
`default_nettype wire
