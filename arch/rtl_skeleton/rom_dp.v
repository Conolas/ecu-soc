// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// Skeleton: outputs tied to safe constants. Owner: Vedam. Replace by the real RTL keeping the ports.
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNUSEDPARAM
module rom_dp #(
  parameter ROM_WORDS = 2048,
  parameter INIT_FILE = "firmware.hex"
) (
  input wire clk,
  input wire ia_req_i,
  input wire [12:0] ia_addr_i,
  output wire [31:0] ia_rdata_o,
  input wire s_sel_i,
  input wire [12:0] s_addr_i,
  output wire [31:0] s_rdata_o
);
  assign ia_rdata_o = 32'd0;   // safe default
  assign s_rdata_o = 32'd0;   // safe default
endmodule
`default_nettype wire
