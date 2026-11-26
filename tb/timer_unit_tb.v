`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.11.2026 14:25:18
// Design Name: 
// Module Name: timer_unit_tb
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
module timer_unit_tb;

    reg clk;
    reg rst_n;

    reg s_sel_i;
    reg s_we_i;
    reg [3:0] s_be_i;
    reg [11:0] s_addr_i;
    reg [31:0] s_wdata_i;
    wire [31:0] s_rdata_o;

    reg sched_busy_i;
    wire control_tick_o;
    wire irq_timer_o;

    integer cycle_num;
    integer last_tick_cycle;
    integer tick_seen;
    integer expected_spacing;

    reg pulse_width_checked;

    reg [31:0] read_data;
    reg [31:0] free_count_first;

    // Instantiate timer_unit
    timer_unit #(
        .DEF_EN(0),
        .TICK_PERIOD_DEF(100),
        .IRQ_DIV_DEF(3)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),

        .s_sel_i(s_sel_i),
        .s_we_i(s_we_i),
        .s_be_i(s_be_i),
        .s_addr_i(s_addr_i),
        .s_wdata_i(s_wdata_i),
        .s_rdata_o(s_rdata_o),

        .sched_busy_i(sched_busy_i),
        .control_tick_o(control_tick_o),
        .irq_timer_o(irq_timer_o)
    );

    // 50 MHz clock: 20 ns period
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // Initialize monitor variables
    initial begin
        cycle_num = 0;
        last_tick_cycle = -1;
        tick_seen = 0;
        expected_spacing = 100;
        pulse_width_checked = 1'b0;
    end

    // Monitor tick generation and spacing
    always @(posedge clk) begin
        cycle_num = cycle_num + 1;

        if (control_tick_o) begin
            tick_seen = tick_seen + 1;

            // Check spacing for first six ticks
            if ((last_tick_cycle >= 0) &&
                (tick_seen <= 6)) begin

                if ((cycle_num - last_tick_cycle)
                    != expected_spacing) begin

                    $display("FAIL: Incorrect tick spacing");
                    $display("Expected: %0d cycles",
                             expected_spacing);
                    $display("Actual: %0d cycles",
                             cycle_num - last_tick_cycle);
                    $fatal;
                end
            end

            last_tick_cycle = cycle_num;

            $display("Tick %0d detected", tick_seen);
        end
    end

    // Check one-clock-cycle pulse width
    always @(negedge clk) begin
        if (control_tick_o === 1'b1) begin

            @(posedge clk);
            #1;

            if (control_tick_o !== 1'b0) begin
                $display("FAIL: Tick pulse longer than one cycle");
                $fatal;
            end

            pulse_width_checked = 1'b1;
        end
    end

    // Bus write task
    task bus_write;
        input [11:0] address;
        input [31:0] data;
        begin
            @(negedge clk);

            s_sel_i = 1'b1;
            s_we_i = 1'b1;
            s_addr_i = address;
            s_wdata_i = data;
            s_be_i = 4'b1111;

            @(posedge clk);
            #1;

            s_sel_i = 1'b0;
            s_we_i = 1'b0;
            s_addr_i = 12'd0;
            s_wdata_i = 32'd0;
        end
    endtask

    // Bus read task
    task bus_read;
        input [11:0] address;
        output [31:0] data;
        begin
            @(negedge clk);

            s_sel_i = 1'b1;
            s_we_i = 1'b0;
            s_addr_i = address;

            @(posedge clk);
            #1;

            data = s_rdata_o;

            s_sel_i = 1'b0;
            s_addr_i = 12'd0;
        end
    endtask

    // Main test sequence
    initial begin

        // Initialize inputs
        rst_n = 1'b0;

        s_sel_i = 1'b0;
        s_we_i = 1'b0;
        s_be_i = 4'b0000;
        s_addr_i = 12'd0;
        s_wdata_i = 32'd0;

        sched_busy_i = 1'b0;

        // Apply reset
        // TEST 0: Verify reset values
        repeat (5) @(posedge clk);
        #1;
        rst_n = 1'b1;
        bus_read(12'h004, read_data);
       if (read_data !== 32'd0) begin
         $display("FAIL: CTRL reset value");
       $fatal;
      end
        $display("PASS: CTRL reset value");

          bus_read(12'h008, read_data);
        if (read_data !== 32'd100) begin
           $display("FAIL: TICK_PERIOD reset value");
            $fatal;
         end
            $display("PASS: TICK_PERIOD reset value");

            bus_read(12'h00C, read_data);
           if (read_data !== 32'd3) begin
         $display("FAIL: IRQ_DIV reset value");
         $fatal;
        end
            $display("PASS: IRQ_DIV reset value");

           bus_read(12'h014, read_data);
           if (read_data !== 32'd0) begin
              $display("FAIL: TICK_COUNT reset value");
              $fatal;
           end
              $display("PASS: TICK_COUNT reset value");

        $display("--------------------------------");
        $display("TIMER UNIT TEST STARTED");
        $display("--------------------------------");

        // TEST 1: ID register
        bus_read(12'h000, read_data);

        if (read_data !== 32'h54494D01) begin
            $display("FAIL: ID register");
            $fatal;
        end

        $display("PASS: ID register");

        // TEST 2: Timer disabled
        repeat (250) @(posedge clk);
        #1;

        if (tick_seen != 0) begin
            $display("FAIL: Timer generated ticks while disabled");
            $fatal;
        end

        $display("PASS: No ticks when EN=0");

        // TEST 3: FREE_CNT counts while timer is disabled
        bus_read(12'h018, free_count_first);

        repeat (20) @(posedge clk);

        bus_read(12'h018, read_data);

        if (read_data <= free_count_first) begin
            $display("FAIL: FREE_CNT did not increment");
            $fatal;
        end

        $display("PASS: FREE_CNT increments");

        // TEST 4: Enable timer and interrupt
        sched_busy_i = 1'b1;

        bus_write(12'h004, 32'h00000003);

        wait (tick_seen == 1);

        @(negedge clk);
        sched_busy_i = 1'b0;

        // Check overrun
        bus_read(12'h010, read_data);

        if (read_data[1] !== 1'b1) begin
            $display("FAIL: Overrun detection");
            $fatal;
        end

        $display("PASS: Overrun detection");

        // Clear overrun using W1C
     // TEST 10: Re-enable timer
       // Clear overrun using W1C
          bus_write(12'h010, 32'h00000002);

    // Allow enable rising-edge reset to complete
     @(posedge clk);
     #1;

     bus_read(12'h014, read_data);

        if (read_data[1] !== 1'b0) begin
            $display("FAIL: Overrun W1C");
            $fatal;
        end

        $display("PASS: Overrun W1C");

        // TEST 5: Interrupt after three ticks
        // TEST 5: Interrupt after three ticks
        wait (tick_seen == 3);
        #1;

       $display("DEBUG: IRQ output = %b", irq_timer_o);
       $display("DEBUG: IRQ pending = %b", DUT.irq_pending);
       $display("DEBUG: IRQ divider count = %d", DUT.irq_div_count);
       $display("DEBUG: IRQ divider register = %d", DUT.irq_div_reg);
        $display("DEBUG: CTRL register = %b", DUT.ctrl_reg);

      if (irq_timer_o !== 1'b1) begin
         $display("FAIL: Interrupt after 3 ticks");
         $fatal;
         end

$display("PASS: Interrupt after 3 ticks");

        $display("PASS: Interrupt after 3 ticks");

        // Clear interrupt using W1C
        bus_write(12'h010, 32'h00000001);
        #1;

        if (irq_timer_o !== 1'b0) begin
            $display("FAIL: Interrupt W1C");
            $fatal;
        end

        $display("PASS: Interrupt W1C");

        // TEST 6: Wait for fourth tick
        wait (tick_seen == 4);

        // Allow pulse-width monitor to finish
        repeat (2) @(posedge clk);
        #1;

        if (pulse_width_checked !== 1'b1) begin
            $display("FAIL: Tick pulse width");
            $fatal;
        end

        $display("PASS: Tick pulse width is one clock cycle");

        // TEST 7: TICK_COUNT
        bus_read(12'h014, read_data);

        if (read_data !== 32'd4) begin
            $display("FAIL: TICK_COUNT");
            $display("Expected 4, got %0d", read_data);
            $fatal;
        end

        $display("PASS: TICK_COUNT");

        // TEST 8: Change TICK_PERIOD to 1200
        // Current active period is 100 cycles.
        // New value applies at the next reload.
        bus_write(12'h008, 32'd1200);

        bus_read(12'h008, read_data);

        if (read_data !== 32'd1200) begin
            $display("FAIL: TICK_PERIOD register write");
            $fatal;
        end

        $display("PASS: TICK_PERIOD register write");

        // Tick 5 should still use the old 100-cycle period
        wait (tick_seen == 5);

        // Tick 5 reloads the new period.
        expected_spacing = 1200;

        // Tick 6 should occur 1200 cycles after tick 5
        wait (tick_seen == 6);

        $display("PASS: New TICK_PERIOD applies at next reload");

        // TEST 9: Disable timer
        bus_write(12'h004, 32'h00000000);

        repeat (1300) @(posedge clk);
        #1;

        if (tick_seen != 6) begin
            $display("FAIL: Timer did not stop when disabled");
            $fatal;
        end

        $display("PASS: Timer stops when EN=0");

        // TICK_COUNT should hold its value while disabled
        bus_read(12'h014, read_data);

        if (read_data !== 32'd6) begin
            $display("FAIL: TICK_COUNT changed while disabled");
            $fatal;
        end

        $display("PASS: TICK_COUNT holds while disabled");

        // TEST 10: Re-enable timer
              // TEST 10: Re-enable timer
        bus_write(12'h004, 32'h00000003);

        // Allow enable-rising-edge reset to complete
        @(posedge clk);
        #1;

        bus_read(12'h014, read_data);

        if (read_data !== 32'd0) begin
            $display("FAIL: TICK_COUNT reset on enable. Read value = %d", read_data);
            $fatal;
        end

        $display("PASS: TICK_COUNT resets on enable");

        // Wait for first tick after re-enabling
        wait (tick_seen == 7);

        // TEST 11: CNT_CLR
        // EN=1, CNT_CLR=1
        bus_write(12'h004, 32'h00000005);

        bus_read(12'h014, read_data);

        if (read_data !== 32'd0) begin
            $display("FAIL: CNT_CLR did not reset TICK_COUNT");
            $fatal;
        end

        $display("PASS: CNT_CLR resets TICK_COUNT");

        // Wait for next tick after clearing counters
        wait (tick_seen == 8);

        bus_read(12'h014, read_data);

        if (read_data !== 32'd1) begin
            $display("FAIL: TICK_COUNT after CNT_CLR");
            $fatal;
        end

        $display("PASS: TICK_COUNT increments after CNT_CLR");

        // Final pulse-width check
        repeat (2) @(posedge clk);
        #1;

        $display("--------------------------------");
        $display("ALL TIMER TESTS PASSED");
        $display("--------------------------------");

        $finish;
    end

endmodule

`default_nettype wire




