// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// Skeleton: outputs tied to safe constants. Owner: Conolas. Replace by the real RTL keeping the ports.
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNUSEDPARAM
module cpu_subsystem #(
  parameter BOOT_ADDR = 32'h0000_0000
) (
  input wire clk,
  input wire rst_n,
  output wire instr_req_o,
  input wire instr_gnt_i,
  input wire instr_rvalid_i,
  output wire [31:0] instr_addr_o,
  input wire [31:0] instr_rdata_i,
  input wire instr_err_i,
  output wire data_req_o,
  input wire data_gnt_i,
  input wire data_rvalid_i,
  output wire data_we_o,
  output wire [3:0] data_be_o,
  output wire [31:0] data_addr_o,
  output wire [31:0] data_wdata_o,
  input wire [31:0] data_rdata_i,
  input wire data_err_i,
  input wire irq_timer_i,
  input wire irq_fault_i,
  output wire core_sleep_o,
  output wire double_fault_seen_o
);
  assign instr_req_o = 1'd0;   // safe default
  assign instr_addr_o = 32'd0;   // safe default
  assign data_req_o = 1'd0;   // safe default
  assign data_we_o = 1'd0;   // safe default
  assign data_be_o = 4'd0;   // safe default
  assign data_addr_o = 32'd0;   // safe default
  assign data_wdata_o = 32'd0;   // safe default
  assign core_sleep_o = 1'd0;   // safe default
  assign double_fault_seen_o = 1'd0;   // safe default
endmodule
`default_nettype wire
