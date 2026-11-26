`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.11.2026 21:46:08
// Design Name: 
// Module Name: angle_conv_tb
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



`timescale 1ns / 1ps
`default_nettype none

module angle_conv_tb;

    reg clk;
    reg rst_n;

    reg sample_valid_i;

    reg signed [15:0] ax_i;
    reg signed [15:0] ay_i;
    reg signed [15:0] az_i;

    reg signed [15:0] gx_i;
    reg signed [15:0] gy_i;
    reg signed [15:0] gz_i;

    reg axis_sel_i;
    reg inv_angle_i;
    reg inv_rate_i;

    wire angle_valid_o;
    wire signed [31:0] angle_o;
    wire signed [31:0] rate_o;

    integer pass_count;
    integer fail_count;

    // DUT
    angle_conv dut (
        .clk(clk),
        .rst_n(rst_n),

        .sample_valid_i(sample_valid_i),

        .ax_i(ax_i),
        .ay_i(ay_i),
        .az_i(az_i),

        .gx_i(gx_i),
        .gy_i(gy_i),
        .gz_i(gz_i),

        .axis_sel_i(axis_sel_i),
        .inv_angle_i(inv_angle_i),
        .inv_rate_i(inv_rate_i),

        .angle_valid_o(angle_valid_o),
        .angle_o(angle_o),
        .rate_o(rate_o)
    );

    // 50 MHz clock
    always #10 clk = ~clk;


    // -----------------------------------------
    // TASK: CHECK ONE CONVERSION
    // -----------------------------------------

    task check_conversion;

        input signed [15:0] ax;
        input signed [15:0] ay;
        input signed [15:0] gx;
        input signed [15:0] gy;

        input axis_sel;
        input inv_angle;
        input inv_rate;

        input signed [31:0] expected_angle;
        input signed [31:0] expected_rate;

        begin

            @(negedge clk);

            ax_i = ax;
            ay_i = ay;
            gx_i = gx;
            gy_i = gy;

            axis_sel_i = axis_sel;
            inv_angle_i = inv_angle;
            inv_rate_i = inv_rate;

            sample_valid_i = 1'b1;

            // DUT captures input at next positive edge
            @(posedge clk);
            #1;

            if (angle_valid_o !== 1'b1 ||
                angle_o !== expected_angle ||
                rate_o !== expected_rate) begin

                $display("FAIL: Angle conversion");
                $display("Expected angle = %0d, Actual = %0d",
                         expected_angle, angle_o);
                $display("Expected rate = %0d, Actual = %0d",
                         expected_rate, rate_o);

                fail_count = fail_count + 1;

            end
            else begin

                $display("PASS: Angle = %0d, Rate = %0d",
                         angle_o, rate_o);

                pass_count = pass_count + 1;

            end

            // Remove valid signal
            @(negedge clk);
            sample_valid_i = 1'b0;

            @(posedge clk);
            #1;

            if (angle_valid_o !== 1'b0) begin
                $display("FAIL: Valid signal did not return LOW");
                fail_count = fail_count + 1;
            end

        end

    endtask


    // -----------------------------------------
    // MAIN TEST
    // -----------------------------------------

    initial begin

        clk = 0;
        rst_n = 0;

        sample_valid_i = 0;

        ax_i = 0;
        ay_i = 0;
        az_i = 0;

        gx_i = 0;
        gy_i = 0;
        gz_i = 0;

        axis_sel_i = 0;
        inv_angle_i = 0;
        inv_rate_i = 0;

        pass_count = 0;
        fail_count = 0;

        $display("");
        $display("======================================");
        $display(" ANGLE CONVERSION TEST STARTED");
        $display("======================================");

        // Reset
        repeat (3) @(negedge clk);
        rst_n = 1;

        @(posedge clk);
        #1;

        if (angle_valid_o !== 1'b0 ||
            angle_o !== 32'sd0 ||
            rate_o !== 32'sd0) begin

            $display("FAIL: Reset test");
            fail_count = fail_count + 1;

        end
        else begin

            $display("PASS: Reset test");
            pass_count = pass_count + 1;

        end


        // -------------------------------------
        // TEST 1: Positive accelerometer
        // -------------------------------------

        $display("");
        $display("TEST 1: Positive accelerometer conversion");

        check_conversion(
            4096, 0, 0, 0,
            0, 0, 0,
            16384, 0
        );


        // -------------------------------------
        // TEST 2: Negative accelerometer
        // -------------------------------------

        $display("");
        $display("TEST 2: Negative accelerometer conversion");

        check_conversion(
            -8192, 0, 0, 0,
            0, 0, 0,
            -32768, 0
        );


        // -------------------------------------
        // TEST 3: Positive gyroscope
        // -------------------------------------

        $display("");
        $display("TEST 3: Positive gyroscope conversion");

        check_conversion(
            0, 0, 0, 131,
            0, 0, 0,
            0, 1145
        );


        // -------------------------------------
        // TEST 4: Negative gyroscope
        // -------------------------------------

        $display("");
        $display("TEST 4: Negative gyroscope conversion");

        check_conversion(
            0, 0, 0, -1000,
            0, 0, 0,
            0, -8750
        );


        // -------------------------------------
        // TEST 5: Angle inversion
        // -------------------------------------

        $display("");
        $display("TEST 5: Angle sign inversion");

        check_conversion(
            4096, 0, 0, 0,
            0, 1, 0,
            -16384, 0
        );


        // -------------------------------------
        // TEST 6: Rate inversion
        // -------------------------------------

        $display("");
        $display("TEST 6: Gyroscope sign inversion");

        check_conversion(
            0, 0, 0, 131,
            0, 0, 1,
            0, -1145
        );


        // -------------------------------------
        // TEST 7: Axis selection 0
        // -------------------------------------

        $display("");
        $display("TEST 7: AXIS_SEL = 0");

        check_conversion(
            100, 200, 32, 40,
            0, 0, 0,
            400, 350
        );


        // -------------------------------------
        // TEST 8: Axis selection 1
        // -------------------------------------

        $display("");
        $display("TEST 8: AXIS_SEL = 1");

        check_conversion(
            100, 200, 32, 40,
            1, 0, 0,
            800, 280
        );


        // -------------------------------------
        // FINAL RESULTS
        // -------------------------------------

        $display("");
        $display("======================================");
        $display(" ANGLE CONVERSION TEST RESULTS");
        $display("======================================");

        $display("PASSED TESTS : %0d", pass_count);
        $display("FAILED TESTS : %0d", fail_count);

        if (fail_count == 0) begin

            $display("");
            $display("ALL ANGLE CONVERSION TESTS PASSED");

        end
        else begin

            $display("");
            $display("ANGLE CONVERSION TESTS FAILED");

        end

        $display("======================================");

        $finish;

    end

endmodule

`default_nettype wire

