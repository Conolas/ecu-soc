`timescale 1ns/1ps
// Self-checking testbench for rom_dp (sheet 04, A.3 vectors 1 and 2, plus hold/fill checks).
module tb_rom_dp;
    // If Vivado cannot find the file, replace with its full path (forward slashes).
    localparam HEX = "D:/Vedam/Project files/tb_rom_init.hex";

    reg clk = 0; always #5 clk = ~clk;
    reg         ia_req = 0; reg [12:0] ia_addr = 0; wire [31:0] ia_rdata;
    reg         s_sel  = 0; reg [12:0] s_addr  = 0; wire [31:0] s_rdata;

    rom_dp #(.ROM_WORDS(2048), .INIT_FILE(HEX)) dut (
        .clk(clk),
        .ia_req_i(ia_req), .ia_addr_i(ia_addr), .ia_rdata_o(ia_rdata),
        .s_sel_i(s_sel),   .s_addr_i(s_addr),   .s_rdata_o(s_rdata));

    integer errs = 0;
    task chk(input [31:0] got, exp, input [159:0] name);
        if (got !== exp) begin errs = errs + 1; $display("FAIL %0s got %h exp %h", name, got, exp); end
    endtask

    initial begin
        repeat (2) @(negedge clk);

        // 1. instruction port: NOP word, then the known word at 0x80, one cycle after request
        @(negedge clk); ia_req = 1; ia_addr = 13'h000;
        @(posedge clk); #1; chk(ia_rdata, 32'h0000_0013, "ia_nop");
        @(negedge clk); ia_addr = 13'h080;
        #1; chk(ia_rdata, 32'h0000_0013, "ia_not_early");        // still old data before the edge
        @(posedge clk); #1; chk(ia_rdata, 32'hCAFE_F00D, "ia_0x80");
        @(negedge clk); ia_req = 0;

        // 2. both ports, different addresses, same cycle
        @(negedge clk); ia_req = 1; ia_addr = 13'h080; s_sel = 1; s_addr = 13'h014;
        @(posedge clk); #1;
        chk(ia_rdata, 32'hCAFE_F00D, "dual_ia"); chk(s_rdata, 32'h1234_5678, "dual_s");
        @(negedge clk); ia_req = 0; s_sel = 0;

        // 3. data holds while no request is made, even if the address changes
        @(negedge clk); ia_addr = 13'h000; s_addr = 13'h000;
        @(posedge clk); #1;
        chk(ia_rdata, 32'hCAFE_F00D, "hold_ia"); chk(s_rdata, 32'h1234_5678, "hold_s");

        // 4. words not listed in the file are NOP; last word of the ROM
        @(negedge clk); ia_req = 1; ia_addr = 13'h190;           // word 100
        @(posedge clk); #1; chk(ia_rdata, 32'h0000_0013, "fill_nop");
        @(negedge clk); ia_addr = 13'h1FFC;                      // word 2047
        @(posedge clk); #1; chk(ia_rdata, 32'h0000_0013, "last_word");
        @(negedge clk); ia_req = 0;

        if (errs == 0) $display("ALL PASS (rom_dp)"); else $display("%0d FAILURES (rom_dp)", errs);
        $finish;
    end
endmodule
