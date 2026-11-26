`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.11.2026 17:23:45
// Design Name: 
// Module Name: timer_unit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



`default_nettype none
`timescale 1ns / 1ps

module timer_unit #(
    parameter DEF_EN          = 0,
    parameter TICK_PERIOD_DEF = 97656,
    parameter IRQ_DIV_DEF     = 51
)(
    input  wire        clk,
    input  wire        rst_n,

    // Slave bus interface
    input  wire        s_sel_i,
    input  wire        s_we_i,
    input  wire [3:0]  s_be_i,
    input  wire [11:0] s_addr_i,
    input  wire [31:0] s_wdata_i,
    output wire [31:0] s_rdata_o,

    // Timer interface
    input  wire        sched_busy_i,
    output wire        control_tick_o,
    output wire        irq_timer_o
);

    // Register offsets
    localparam ADDR_ID          = 12'h000;
    localparam ADDR_CTRL        = 12'h004;
    localparam ADDR_TICK_PERIOD = 12'h008;
    localparam ADDR_IRQ_DIV     = 12'h00C;
    localparam ADDR_STATUS      = 12'h010;
    localparam ADDR_TICK_COUNT  = 12'h014;
    localparam ADDR_FREE_CNT    = 12'h018;

    // Internal output registers
    reg [31:0] s_rdata_reg;
    reg        control_tick_reg;

    assign s_rdata_o     = s_rdata_reg;
    assign control_tick_o = control_tick_reg;

    // Timer registers
    reg [1:0]  ctrl_reg;
    reg [31:0] tick_period_reg;
    reg [31:0] tick_period_active;
    reg [31:0] irq_div_reg;

    // Internal counters
    reg [31:0] cycle_count;
    reg [31:0] irq_div_count;
    reg [31:0] tick_count;
    reg [31:0] free_count;

    // Status flags
    reg irq_pending;
    reg overrun;

    // Enable edge detection
    reg ctrl_en_d;

    wire ctrl_write;
    wire status_write;
    wire cnt_clr;
    wire enable_rise;
    wire tick_event;
    wire irq_event;

    assign ctrl_write =
        s_sel_i && s_we_i && (s_addr_i == ADDR_CTRL);

    assign status_write =
        s_sel_i && s_we_i && (s_addr_i == ADDR_STATUS);

    assign cnt_clr =
        ctrl_write && s_be_i[0] && s_wdata_i[2];

    assign enable_rise = ctrl_reg[0] && !ctrl_en_d;

    assign tick_event =
        ctrl_reg[0] &&
        (cycle_count == (tick_period_active - 1'b1));

    assign irq_event =
        tick_event &&
        ((irq_div_reg <= 1) ||
         (irq_div_count >= (irq_div_reg - 1'b1)));

    // Byte-enable register write helper
    function [31:0] merge_bytes;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0]  byte_enable;
        integer i;
        begin
            merge_bytes = old_value;
            for (i = 0; i < 4; i = i + 1) begin
                if (byte_enable[i])
                    merge_bytes[i*8 +: 8] =
                        new_value[i*8 +: 8];
            end
        end
    endfunction

    // Interrupt output
    assign irq_timer_o =
        ctrl_reg[0] && ctrl_reg[1] && irq_pending;

    // Main sequential logic
    always @(posedge clk) begin
        if (!rst_n) begin
            ctrl_reg           <= {1'b0, DEF_EN[0]};
            tick_period_reg    <= TICK_PERIOD_DEF;
            tick_period_active <= TICK_PERIOD_DEF;
            irq_div_reg        <= IRQ_DIV_DEF;

            cycle_count        <= 32'd0;
            irq_div_count      <= 32'd0;
            tick_count         <= 32'd0;
            free_count         <= 32'd0;

            irq_pending        <= 1'b0;
            overrun            <= 1'b0;

            ctrl_en_d          <= DEF_EN[0];

            s_rdata_reg        <= 32'd0;
            control_tick_reg   <= 1'b0;
        end
        else begin

            // Free-running counter
            free_count <= free_count + 1'b1;

            // Default: one-cycle tick pulse
            control_tick_reg <= 1'b0;

            // Track previous enable state
            ctrl_en_d <= ctrl_reg[0];

            // CTRL register write
            if (ctrl_write && s_be_i[0]) begin
                ctrl_reg <= s_wdata_i[1:0];
            end

            // TICK_PERIOD register write
            if (s_sel_i && s_we_i &&
                (s_addr_i == ADDR_TICK_PERIOD) &&
                (|s_be_i)) begin

                if (merge_bytes(tick_period_reg,
                                s_wdata_i,
                                s_be_i) < 32'd1000)
                    tick_period_reg <= 32'd1000;
                else
                    tick_period_reg <= merge_bytes(
                        tick_period_reg,
                        s_wdata_i,
                        s_be_i
                    );
            end

            // IRQ_DIV register write
            if (s_sel_i && s_we_i &&
                (s_addr_i == ADDR_IRQ_DIV)) begin

                irq_div_reg <= merge_bytes(
                    irq_div_reg,
                    s_wdata_i,
                    s_be_i
                );
            end

            // Registered read response
            if (s_sel_i && !s_we_i) begin
                case (s_addr_i)
                    ADDR_ID:
                        s_rdata_reg <= 32'h54494D01;

                    ADDR_CTRL:
                        s_rdata_reg <= {29'd0, 1'b0, ctrl_reg};

                    ADDR_TICK_PERIOD:
                        s_rdata_reg <= tick_period_reg;

                    ADDR_IRQ_DIV:
                        s_rdata_reg <= irq_div_reg;

                    ADDR_STATUS:
                        s_rdata_reg <= {
                            30'd0,
                            overrun,
                            irq_pending
                        };

                    ADDR_TICK_COUNT:
                        s_rdata_reg <= tick_count;

                    ADDR_FREE_CNT:
                        s_rdata_reg <= free_count;

                    default:
                        s_rdata_reg <= 32'd0;
                endcase
            end

            // Timer counter and tick generation
            if (enable_rise || cnt_clr) begin
                cycle_count        <= 32'd0;
                tick_count         <= 32'd0;
                irq_div_count      <= 32'd0;
                tick_period_active <= tick_period_reg;
            end
            else if (!ctrl_reg[0]) begin
                cycle_count   <= 32'd0;
                irq_div_count <= 32'd0;
            end
            else if (tick_event) begin
                cycle_count      <= 32'd0;
                tick_count       <= tick_count + 1'b1;
                control_tick_reg <= 1'b1;

                // Apply programmed period at reload
                tick_period_active <= tick_period_reg;

                if (irq_event)
                    irq_div_count <= 32'd0;
                else
                    irq_div_count <= irq_div_count + 1'b1;
            end
            else begin
                cycle_count <= cycle_count + 1'b1;
            end

            // W1C status flags
            if (status_write && s_be_i[0]) begin
                if (s_wdata_i[0])
                    irq_pending <= 1'b0;

                if (s_wdata_i[1])
                    overrun <= 1'b0;
            end

            // New events take priority over simultaneous W1C
            if (irq_event)
                irq_pending <= 1'b1;

            if (tick_event && sched_busy_i)
                overrun <= 1'b1;

        end
    end

endmodule

`default_nettype wire
