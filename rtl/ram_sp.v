`timescale 1ns/1ps

module ram_sp #(
    parameter RAM_WORDS = 1024               // power of two, <= 1024 (12-bit byte address)
)(
    input  wire        clk,
    input  wire        s_sel_i,
    input  wire        s_we_i,
    input  wire [3:0]  s_be_i,
    input  wire [11:0] s_addr_i,             // byte address, word index = [11:2]
    input  wire [31:0] s_wdata_i,
    output reg  [31:0] s_rdata_o
);
    localparam AW = $clog2(RAM_WORDS);       // 10 for 1024 words

    reg [31:0] mem [0:RAM_WORDS-1];
    integer i, k;

    initial begin
        for (i = 0; i < RAM_WORDS; i = i + 1) mem[i] = 32'h0;
        s_rdata_o = 32'h0;
    end

    always @(posedge clk)
        if (s_sel_i) begin
            if (s_we_i)
                for (k = 0; k < 4; k = k + 1)
                    if (s_be_i[k]) mem[s_addr_i[AW+1:2]][8*k +: 8] <= s_wdata_i[8*k +: 8];
            s_rdata_o <= mem[s_addr_i[AW+1:2]];      // read-first
        end
endmodule
