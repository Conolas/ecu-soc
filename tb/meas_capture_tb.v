`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.11.2026 09:56:32
// Design Name: 
// Module Name: meas_capture_tb
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

module meas_capture_tb;

    reg clk;
    reg rst_n;

    reg cal_start_i;
    reg imu_init_done_i;

    // Byte-based IMU interface
    reg [7:0] rx_byte_i;
    reg rx_valid_i;
    reg burst_done_i;
    reg burst_error_i;

    wire sample_valid_o;

    wire signed [15:0] ax_o, ay_o, az_o;
    wire signed [15:0] gx_o, gy_o, gz_o;

    wire signed [15:0] gyro_bias_x_o;
    wire signed [15:0] gyro_bias_y_o;
    wire signed [15:0] gyro_bias_z_o;

    wire calib_busy_o;
    wire calib_done_o;

    wire [31:0] seq_count_o;

    integer i;

    // DEF_EN = 1 supports automatic and manual calibration
    meas_capture #(
        .DEF_EN(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .cal_start_i(cal_start_i),
        .imu_init_done_i(imu_init_done_i),

        .rx_byte_i(rx_byte_i),
        .rx_valid_i(rx_valid_i),
        .burst_done_i(burst_done_i),
        .burst_error_i(burst_error_i),

        .sample_valid_o(sample_valid_o),

        .ax_o(ax_o),
        .ay_o(ay_o),
        .az_o(az_o),

        .gx_o(gx_o),
        .gy_o(gy_o),
        .gz_o(gz_o),

        .gyro_bias_x_o(gyro_bias_x_o),
        .gyro_bias_y_o(gyro_bias_y_o),
        .gyro_bias_z_o(gyro_bias_z_o),

        .calib_busy_o(calib_busy_o),
        .calib_done_o(calib_done_o),

        .seq_count_o(seq_count_o)
    );

    // 50 MHz clock
    always #10 clk = ~clk;


    // ==========================================
    // RESET TASK
    // ==========================================

    task reset_dut;
        begin
            @(negedge clk);

            rst_n = 0;
            cal_start_i = 0;
            imu_init_done_i = 0;

            rx_byte_i = 0;
            rx_valid_i = 0;
            burst_done_i = 0;
            burst_error_i = 0;

            repeat (3) @(negedge clk);

            rst_n = 1;

            @(negedge clk);
        end
    endtask


    // ==========================================
    // SEND ONE BYTE
    // ==========================================

    task send_byte;
        input [7:0] data;
        begin
            @(negedge clk);
            rx_byte_i = data;
            rx_valid_i = 1;

            @(negedge clk);
            rx_valid_i = 0;
        end
    endtask


    // ==========================================
    // SEND ONE COMPLETE 14-BYTE SAMPLE
    // ==========================================

    task send_sample;
        input signed [15:0] ax;
        input signed [15:0] ay;
        input signed [15:0] az;
        input signed [15:0] gx;
        input signed [15:0] gy;
        input signed [15:0] gz;

        begin
            // Accelerometer X
            send_byte(ax[15:8]);
            send_byte(ax[7:0]);

            // Accelerometer Y
            send_byte(ay[15:8]);
            send_byte(ay[7:0]);

            // Accelerometer Z
            send_byte(az[15:8]);
            send_byte(az[7:0]);

            // Temperature
            send_byte(8'h00);
            send_byte(8'h00);

            // Gyroscope X
            send_byte(gx[15:8]);
            send_byte(gx[7:0]);

            // Gyroscope Y
            send_byte(gy[15:8]);
            send_byte(gy[7:0]);

            // Gyroscope Z
            send_byte(gz[15:8]);
            send_byte(gz[7:0]);

            // Burst completion
            @(negedge clk);
            burst_done_i = 1;

            @(negedge clk);
            burst_done_i = 0;
        end
    endtask


    // ==========================================
    // MANUAL CALIBRATION TASK
    // ==========================================

    task manual_calibration;
        input signed [15:0] bias_x;
        input signed [15:0] bias_y;
        input signed [15:0] bias_z;

        begin
            cal_start_i = 1;

            @(negedge clk);
            cal_start_i = 0;

            // Check calibration started
            @(negedge clk);

            if (calib_busy_o !== 1'b1) begin
                $display("FAIL: Manual calibration did not start");
                $finish;
            end

            // 64 settling samples
            for (i = 0; i < 64; i = i + 1)
                send_sample(100, 200, 300,
                            bias_x, bias_y, bias_z);

            // 256 accumulation samples
            for (i = 0; i < 256; i = i + 1)
                send_sample(100, 200, 300,
                            bias_x, bias_y, bias_z);

            @(negedge clk);

            if (calib_done_o !== 1'b1) begin
                $display("FAIL: Manual calibration did not complete");
                $finish;
            end

            if (gyro_bias_x_o !== bias_x ||
                gyro_bias_y_o !== bias_y ||
                gyro_bias_z_o !== bias_z) begin

                $display("FAIL: Manual calibration bias incorrect");
                $display("GX = %0d", gyro_bias_x_o);
                $display("GY = %0d", gyro_bias_y_o);
                $display("GZ = %0d", gyro_bias_z_o);
                $finish;
            end
        end
    endtask


    // ==========================================
    // MAIN TEST
    // ==========================================

    initial begin

        clk = 0;
        rst_n = 0;

        cal_start_i = 0;
        imu_init_done_i = 0;

        rx_byte_i = 0;
        rx_valid_i = 0;
        burst_done_i = 0;
        burst_error_i = 0;

        $display("");
        $display("==========================================");
        $display(" MEAS_CAPTURE COMPLETE TEST STARTED");
        $display("==========================================");


        // ======================================
        // TEST 1: COMPLETE BYTE RECEPTION
        // ======================================

        reset_dut();

        $display("");
        $display("TEST 1: Complete 14-byte reception");

        send_sample(
            16'h0B70,
            16'h1FD8,
            16'h3EE0,
            16'h0A8E,
            16'hF254,
            16'h8001
        );

        if (sample_valid_o !== 1'b1 ||
            ax_o !== 16'sd2928 ||
            ay_o !== 16'sd8152 ||
            az_o !== 16'sd16096 ||
            gx_o !== 16'sd2702 ||
            gy_o !== -16'sd3500 ||
            gz_o !== -16'sd32767) begin

            $display("FAIL: Incorrect byte assembly");
            $finish;
        end

        $display("PASS: All six sensor values assembled correctly");
        $display("AX = %0d, AY = %0d, AZ = %0d",
                 ax_o, ay_o, az_o);
        $display("GX = %0d, GY = %0d, GZ = %0d",
                 gx_o, gy_o, gz_o);


        // ======================================
        // TEST 2: INCOMPLETE BURST
        // ======================================

        $display("");
        $display("TEST 2: Incomplete burst rejection");

        send_byte(8'h0B);
        send_byte(8'h70);
        send_byte(8'h1F);
        send_byte(8'hD8);

        @(negedge clk);
        burst_done_i = 1;

        @(negedge clk);
        burst_done_i = 0;

        if (sample_valid_o !== 1'b0 ||
            seq_count_o !== 32'd1) begin

            $display("FAIL: Incomplete burst was accepted");
            $finish;
        end

        $display("PASS: Incomplete burst rejected");


        // ======================================
        // TEST 3: BURST ERROR
        // ======================================

        $display("");
        $display("TEST 3: Burst error handling");

        send_byte(8'h0B);
        send_byte(8'h70);
        send_byte(8'h1F);

        @(negedge clk);
        burst_error_i = 1;

        @(negedge clk);
        burst_error_i = 0;

        if (sample_valid_o !== 1'b0 ||
            seq_count_o !== 32'd1) begin

            $display("FAIL: Burst error was not handled correctly");
            $finish;
        end

        $display("PASS: Failed burst discarded");


        // ======================================
        // TEST 4: MANUAL CALIBRATION
        // ======================================

        $display("");
        $display("TEST 4: Manual calibration");

        manual_calibration(10, -5, 3);

        $display("PASS: Manual calibration completed");
        $display("PASS: Bias X = %0d, Y = %0d, Z = %0d",
                 gyro_bias_x_o,
                 gyro_bias_y_o,
                 gyro_bias_z_o);

        if (seq_count_o !== 32'd321) begin
            $display("FAIL: Incorrect sequence count = %0d",
                     seq_count_o);
            $finish;
        end

        $display("PASS: Sequence count = 321");


        // ======================================
        // TEST 5: GYROSCOPE BIAS CORRECTION
        // ======================================

        $display("");
        $display("TEST 5: Gyroscope bias correction");

        send_sample(100, 200, 300, 10, -5, 3);

        if (gx_o !== 16'sd0 ||
            gy_o !== 16'sd0 ||
            gz_o !== 16'sd0) begin

            $display("FAIL: Gyroscope bias correction");
            $display("GX = %0d, GY = %0d, GZ = %0d",
                     gx_o, gy_o, gz_o);
            $finish;
        end

        $display("PASS: Corrected gyro values = 0, 0, 0");


        // ======================================
        // TEST 6: POSITIVE SATURATION
        // ======================================

        $display("");
        $display("TEST 6: Positive saturation");

        reset_dut();

        manual_calibration(-10, 0, 0);

        send_sample(100, 200, 300, 32767, 0, 0);

        if (gx_o !== 16'sd32767) begin
            $display("FAIL: Positive saturation");
            $display("GX = %0d", gx_o);
            $finish;
        end

        $display("PASS: Positive saturation = 32767");


        // ======================================
        // TEST 7: NEGATIVE SATURATION
        // ======================================

        $display("");
        $display("TEST 7: Negative saturation");

        reset_dut();

        manual_calibration(10, 0, 0);

        send_sample(100, 200, 300, -32768, 0, 0);

        if (gx_o !== -16'sd32768) begin
            $display("FAIL: Negative saturation");
            $display("GX = %0d", gx_o);
            $finish;
        end

        $display("PASS: Negative saturation = -32768");


        // ======================================
        // TEST 8: AUTOMATIC CALIBRATION
        // ======================================

        $display("");
        $display("TEST 8: Automatic calibration");

        reset_dut();

        // Trigger automatic calibration
        @(negedge clk);
        imu_init_done_i = 1;

        @(negedge clk);

        if (calib_busy_o !== 1'b1) begin
            $display("FAIL: Automatic calibration did not start");
            $finish;
        end

        $display("PASS: Automatic calibration started");

        // 64 settling samples
        for (i = 0; i < 64; i = i + 1)
            send_sample(100, 200, 300, 10, -5, 3);

        // 256 accumulation samples
        for (i = 0; i < 256; i = i + 1)
            send_sample(100, 200, 300, 10, -5, 3);

        @(negedge clk);

        if (calib_done_o !== 1'b1) begin
            $display("FAIL: Automatic calibration did not complete");
            $finish;
        end

        $display("PASS: Automatic calibration completed");

        if (gyro_bias_x_o !== 16'sd10 ||
            gyro_bias_y_o !== -16'sd5 ||
            gyro_bias_z_o !== 16'sd3) begin

            $display("FAIL: Automatic calibration bias incorrect");
            $display("GX = %0d, GY = %0d, GZ = %0d",
                     gyro_bias_x_o,
                     gyro_bias_y_o,
                     gyro_bias_z_o);
            $finish;
        end

        $display("PASS: Automatic calibration bias values");

        if (seq_count_o !== 32'd320) begin
            $display("FAIL: Automatic sequence count = %0d",
                     seq_count_o);
            $finish;
        end

        $display("PASS: Automatic sequence count = 320");


        // ======================================
        // ALL TESTS COMPLETE
        // ======================================

        $display("");
        $display("==========================================");
        $display(" ALL MEAS_CAPTURE TESTS PASSED");
        $display("==========================================");

        $finish;

    end

endmodule

`default_nettype wire

