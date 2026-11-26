`timescale 1ns/1ps
// Self-checking testbench for ram_sp (sheet 04, A.3 vectors 3 to 7, plus extra checks).
module tb_ram_sp;
    reg clk = 0; always #5 clk = ~clk;
    reg sel = 0, we = 0; reg [3:0] be = 0; reg [11:0] addr = 0; reg [31:0] wdata = 0;
    wire [31:0] rdata;

    ram_sp #(.RAM_WORDS(1024)) dut (.clk(clk), .s_sel_i(sel), .s_we_i(we), .s_be_i(be),
        .s_addr_i(addr), .s_wdata_i(wdata), .s_rdata_o(rdata));

    integer errs = 0;
    task chk(input [31:0] got, exp, input [159:0] name);
        if (got !== exp) begin errs = errs + 1; $display("FAIL %0s got %h exp %h", name, got, exp); end
    endtask
    task wr(input [11:0] a, input [31:0] d, input [3:0] b);
        begin @(negedge clk); sel=1; we=1; addr=a; wdata=d; be=b; @(negedge clk); sel=0; we=0; end
    endtask
    task rd(input [11:0] a);                       // result is in rdata afterwards
        begin @(negedge clk); sel=1; we=0; addr=a; @(negedge clk); sel=0; #1; end
    endtask

    initial begin
        repeat (2) @(negedge clk);

        // 3. word write and read
        wr(12'h010, 32'h11223344, 4'b1111);
        rd(12'h010); chk(rdata, 32'h11223344, "word_rw");

        // 4. single byte write (lane 0)
        wr(12'h010, 32'h0000_00AA, 4'b0001);
        rd(12'h010); chk(rdata, 32'h112233AA, "be0001");

        // 5. upper half-word write
        wr(12'h010, 32'hBBCC_0000, 4'b1100);
        rd(12'h010); chk(rdata, 32'hBBCC33AA, "be1100");

        // 6. read data appears exactly one cycle after the request
        wr(12'h020, 32'hAAAA_5555, 4'hF);
        wr(12'h024, 32'h5555_AAAA, 4'hF);
        rd(12'h020);
        @(negedge clk); sel = 1; we = 0; addr = 12'h024;
        #1; chk(rdata, 32'hAAAA_5555, "not_early");      // old data until the clock edge
        @(posedge clk); #1; chk(rdata, 32'h5555_AAAA, "one_cycle");
        @(negedge clk); sel = 0;

        // 7. read during write: registered data is the OLD word, next read gives the NEW word
        wr(12'h030, 32'h0101_0101, 4'hF);
        @(negedge clk); sel=1; we=1; addr=12'h030; wdata=32'h0202_0202; be=4'hF;
        @(posedge clk); #1; chk(rdata, 32'h0101_0101, "rdw_old");
        @(negedge clk); sel=0; we=0;
        rd(12'h030); chk(rdata, 32'h0202_0202, "rdw_new");

        // extra: no byte enables -> no change
        wr(12'h030, 32'hFFFF_FFFF, 4'b0000);
        rd(12'h030); chk(rdata, 32'h0202_0202, "be0000");

        // extra: sel low -> no write even if we is high
        @(negedge clk); sel=0; we=1; addr=12'h030; wdata=32'hDEAD_BEEF; be=4'hF;
        @(negedge clk); we=0;
        rd(12'h030); chk(rdata, 32'h0202_0202, "sel_low");

        // extra: neighbouring words stay independent; last word of the RAM
        rd(12'h014); chk(rdata, 32'h0000_0000, "neighbour");
        wr(12'hFFC, 32'hCAFE_F00D, 4'hF);
        rd(12'hFFC); chk(rdata, 32'hCAFE_F00D, "last_word");

        if (errs == 0) $display("ALL PASS (ram_sp)"); else $display("%0d FAILURES (ram_sp)", errs);
        $finish;
    end
endmodule
