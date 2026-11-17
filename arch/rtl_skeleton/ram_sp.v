// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// Skeleton: outputs tied to safe constants. Owner: Vedam. Replace by the real RTL keeping the ports.
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNUSEDPARAM
module ram_sp #(
  parameter RAM_WORDS = 1024
) (
  input wire clk,
  input wire s_sel_i,
  input wire s_we_i,
  input wire [3:0] s_be_i,
  input wire [11:0] s_addr_i,
  input wire [31:0] s_wdata_i,
  output wire [31:0] s_rdata_o
);
  assign s_rdata_o = 32'd0;   // safe default
endmodule
`default_nettype wire
