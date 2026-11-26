`timescale 1ns/1ps
// rom_dp : 8 KB instruction/constant ROM, two independent registered read ports.
// Sheet 04, section A.1. Ports and parameter names are frozen; do not add ports.
//
//   ia_*  : instruction-fetch port (Ibex instr side, via bus_interconnect)
//   s_*   : data-side read port    (.rodata reads, via bus_interconnect)
//
// Read timing (both ports): address and request are sampled on the rising clock
// edge; read data is valid in the following cycle and HOLDS until the next request.
// There are no write ports: the bus returns an error for writes to ROM.
//
// Contents: every word starts as a NOP (0x00000013), then INIT_FILE overwrites the
// words it lists. If the file is empty/short the rest stays NOP, so a missing image
// can never leave X in the instruction stream. The initial block is for simulation
// and FPGA BRAM initialisation only (it is memory content, not logic).
module rom_dp #(
    parameter ROM_WORDS = 2048,              // power of two, <= 2048 (13-bit byte address)
    parameter INIT_FILE = "firmware.hex"     // one 32-bit hex word per line, see sw/bin2hex.py
)(
    input  wire        clk,
    // instruction port
    input  wire        ia_req_i,
    input  wire [12:0] ia_addr_i,            // byte address, word index = [12:2]
    output reg  [31:0] ia_rdata_o,
    // data-side read port
    input  wire        s_sel_i,
    input  wire [12:0] s_addr_i,
    output reg  [31:0] s_rdata_o
);
    localparam AW = $clog2(ROM_WORDS);       // word-index width (11 for 2048 words)

    reg [31:0] mem [0:ROM_WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < ROM_WORDS; i = i + 1) mem[i] = 32'h0000_0013;   // NOP fill
        $readmemh(INIT_FILE, mem);
        ia_rdata_o = 32'h0000_0013;
        s_rdata_o  = 32'h0000_0013;
    end

    // Two separate always blocks -> true dual-port block RAM inference.
    always @(posedge clk) if (ia_req_i) ia_rdata_o <= mem[ia_addr_i[AW+1:2]];
    always @(posedge clk) if (s_sel_i)  s_rdata_o  <= mem[s_addr_i[AW+1:2]];
endmodule
