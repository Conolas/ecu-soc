`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.11.2026 09:39:49
// Design Name: 
// Module Name: meas_capture
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

module meas_capture #(
    parameter DEF_EN = 0
)(
    input  wire clk,
    input  wire rst_n,

    // Calibration control
    input  wire cal_start_i,
    input  wire imu_init_done_i,

    // MPU6050 byte input
    input  wire [7:0] rx_byte_i,
    input  wire       rx_valid_i,
    input  wire       burst_done_i,
    input  wire       burst_error_i,

    // Coherent captured measurements
    output reg sample_valid_o,
    output reg signed [15:0] ax_o,
    output reg signed [15:0] ay_o,
    output reg signed [15:0] az_o,
    output reg signed [15:0] gx_o,
    output reg signed [15:0] gy_o,
    output reg signed [15:0] gz_o,

    // Bias telemetry
    output reg signed [15:0] gyro_bias_x_o,
    output reg signed [15:0] gyro_bias_y_o,
    output reg signed [15:0] gyro_bias_z_o,

    // Calibration status
    output wire calib_busy_o,
    output reg calib_done_o,

    // Number of valid samples processed
    output reg [31:0] seq_count_o
);

    // ------------------------------------------------
    // 1. MPU6050 BYTE ASSEMBLY
    // ------------------------------------------------

    // Byte counter: 0 to 14
    reg [3:0] byte_count;
    reg burst_bad;

    // High-byte storage
    reg [7:0] ax_high;
    reg [7:0] ay_high;
    reg [7:0] az_high;
    reg [7:0] temp_high;
    reg [7:0] gx_high;
    reg [7:0] gy_high;
    reg [7:0] gz_high;

    // Complete 16-bit sensor values
    reg signed [15:0] raw_ax;
    reg signed [15:0] raw_ay;
    reg signed [15:0] raw_az;
    reg signed [15:0] raw_gx;
    reg signed [15:0] raw_gy;
    reg signed [15:0] raw_gz;

    // Temperature is stored internally
    reg signed [15:0] raw_temp;

    // A sample is accepted only after all 14 bytes
    // have arrived and the burst has completed successfully.
    wire sample_accept;

    assign sample_accept =
        burst_done_i &&
        (byte_count == 4'd14) &&
        !burst_bad &&
        !burst_error_i;

    // ------------------------------------------------
    // 2. CALIBRATION FSM
    // ------------------------------------------------

    localparam IDLE   = 2'd0;
    localparam SETTLE = 2'd1;
    localparam ACCUM  = 2'd2;
    localparam DONE   = 2'd3;

    reg [1:0] state;

    // Calibration counters
    reg [6:0] settle_count;
    reg [8:0] accum_count;

    // Signed 24-bit accumulation registers
    reg signed [23:0] accum_gx;
    reg signed [23:0] accum_gy;
    reg signed [23:0] accum_gz;

    // Detect rising edge of IMU initialization
    reg imu_init_done_d;

    wire auto_start;
    wire start_req;

    assign auto_start =
        (DEF_EN != 0) && imu_init_done_i && !imu_init_done_d;

    assign start_req = cal_start_i || auto_start;

    assign calib_busy_o =
        (state == SETTLE) || (state == ACCUM);

    // ------------------------------------------------
    // 3. GYRO ACCUMULATION
    // ------------------------------------------------

    // Sign-extend raw gyro measurements to 24 bits
    wire signed [23:0] gx_ext =
        {{8{raw_gx[15]}}, raw_gx};

    wire signed [23:0] gy_ext =
        {{8{raw_gy[15]}}, raw_gy};

    wire signed [23:0] gz_ext =
        {{8{raw_gz[15]}}, raw_gz};

    // Include current sample in next accumulator value
    wire signed [23:0] gx_sum_next = accum_gx + gx_ext;
    wire signed [23:0] gy_sum_next = accum_gy + gy_ext;
    wire signed [23:0] gz_sum_next = accum_gz + gz_ext;

    // ------------------------------------------------
    // 4. GYRO BIAS CORRECTION
    // ------------------------------------------------

    // Calculate corrected gyro values using 17-bit subtraction
    wire signed [16:0] gx_diff =
        {raw_gx[15], raw_gx} -
        {gyro_bias_x_o[15], gyro_bias_x_o};

    wire signed [16:0] gy_diff =
        {raw_gy[15], raw_gy} -
        {gyro_bias_y_o[15], gyro_bias_y_o};

    wire signed [16:0] gz_diff =
        {raw_gz[15], raw_gz} -
        {gyro_bias_z_o[15], gyro_bias_z_o};

    // Saturate a signed 17-bit value to signed 16-bit range
    function signed [15:0] saturate_16;
        input signed [16:0] value;
        begin
            if (value > 17'sd32767)
                saturate_16 = 16'sh7FFF;
            else if (value < -17'sd32768)
                saturate_16 = 16'sh8000;
            else
                saturate_16 = value[15:0];
        end
    endfunction

    // ------------------------------------------------
    // 5. MAIN SEQUENTIAL LOGIC
    // ------------------------------------------------

    always @(posedge clk) begin

        if (!rst_n) begin

            // Byte assembly reset
            byte_count <= 4'd0;
            burst_bad <= 1'b0;

            ax_high <= 8'd0;
            ay_high <= 8'd0;
            az_high <= 8'd0;
            temp_high <= 8'd0;
            gx_high <= 8'd0;
            gy_high <= 8'd0;
            gz_high <= 8'd0;

            raw_ax <= 16'sd0;
            raw_ay <= 16'sd0;
            raw_az <= 16'sd0;
            raw_temp <= 16'sd0;
            raw_gx <= 16'sd0;
            raw_gy <= 16'sd0;
            raw_gz <= 16'sd0;

            // Calibration reset
            state <= IDLE;

            settle_count <= 7'd0;
            accum_count <= 9'd0;

            accum_gx <= 24'sd0;
            accum_gy <= 24'sd0;
            accum_gz <= 24'sd0;

            imu_init_done_d <= 1'b0;

            sample_valid_o <= 1'b0;

            ax_o <= 16'sd0;
            ay_o <= 16'sd0;
            az_o <= 16'sd0;

            gx_o <= 16'sd0;
            gy_o <= 16'sd0;
            gz_o <= 16'sd0;

            gyro_bias_x_o <= 16'sd0;
            gyro_bias_y_o <= 16'sd0;
            gyro_bias_z_o <= 16'sd0;

            calib_done_o <= 1'b0;
            seq_count_o <= 32'd0;

        end
        else begin

            // Remember previous initialization status
            imu_init_done_d <= imu_init_done_i;

            // Default: one-cycle pulse
            sample_valid_o <= 1'b0;

            // ----------------------------------------
            // BYTE RECEIVING AND ASSEMBLY
            // ----------------------------------------

            if (burst_error_i) begin

                // Discard failed burst
                byte_count <= 4'd0;
                burst_bad <= 1'b0;

            end
            else if (rx_valid_i) begin

                if (byte_count < 4'd14) begin

                    case (byte_count)

                        4'd0: ax_high <= rx_byte_i;
                        4'd1: raw_ax <= {ax_high, rx_byte_i};

                        4'd2: ay_high <= rx_byte_i;
                        4'd3: raw_ay <= {ay_high, rx_byte_i};

                        4'd4: az_high <= rx_byte_i;
                        4'd5: raw_az <= {az_high, rx_byte_i};

                        4'd6: temp_high <= rx_byte_i;
                        4'd7: raw_temp <= {temp_high, rx_byte_i};

                        4'd8: gx_high <= rx_byte_i;
                        4'd9: raw_gx <= {gx_high, rx_byte_i};

                        4'd10: gy_high <= rx_byte_i;
                        4'd11: raw_gy <= {gy_high, rx_byte_i};

                        4'd12: gz_high <= rx_byte_i;
                        4'd13: raw_gz <= {gz_high, rx_byte_i};

                        default: begin
                        end

                    endcase

                    byte_count <= byte_count + 1'b1;

                end
                else begin

                    // More than 14 bytes received
                    burst_bad <= 1'b1;

                end

            end

            // ----------------------------------------
            // BURST COMPLETION
            // ----------------------------------------

            if (burst_done_i) begin

                // Clear byte counter after each completed
                // or rejected burst
                byte_count <= 4'd0;
                burst_bad <= 1'b0;

                // If the burst was incomplete or invalid,
                // sample_accept remains LOW and no data is captured.

            end

            // ----------------------------------------
            // CAPTURE COMPLETE SENSOR SAMPLE
            // ----------------------------------------

            if (sample_accept) begin

                // Capture all six axes together
                ax_o <= raw_ax;
                ay_o <= raw_ay;
                az_o <= raw_az;

                sample_valid_o <= 1'b1;

                seq_count_o <= seq_count_o + 1'b1;

                // During calibration, gyro data remains uncorrected.
                // After calibration, subtract stored bias.
                if (calib_done_o) begin

                    gx_o <= saturate_16(gx_diff);
                    gy_o <= saturate_16(gy_diff);
                    gz_o <= saturate_16(gz_diff);

                end
                else begin

                    gx_o <= raw_gx;
                    gy_o <= raw_gy;
                    gz_o <= raw_gz;

                end

            end

            // ----------------------------------------
            // CALIBRATION STATE MACHINE
            // ----------------------------------------

            case (state)

                IDLE: begin

                    if (start_req) begin

                        settle_count <= 7'd0;
                        accum_count <= 9'd0;

                        accum_gx <= 24'sd0;
                        accum_gy <= 24'sd0;
                        accum_gz <= 24'sd0;

                        gyro_bias_x_o <= 16'sd0;
                        gyro_bias_y_o <= 16'sd0;
                        gyro_bias_z_o <= 16'sd0;

                        calib_done_o <= 1'b0;

                        state <= SETTLE;

                    end

                end

                SETTLE: begin

                    // Discard exactly 64 complete valid samples
                    if (sample_accept) begin

                        if (settle_count == 7'd63) begin

                            settle_count <= 7'd0;
                            accum_count <= 9'd0;

                            state <= ACCUM;

                        end
                        else begin

                            settle_count <= settle_count + 1'b1;

                        end

                    end

                end

                ACCUM: begin

                    // Accumulate exactly 256 complete gyro samples
                    if (sample_accept) begin

                        accum_gx <= gx_sum_next;
                        accum_gy <= gy_sum_next;
                        accum_gz <= gz_sum_next;

                        if (accum_count == 9'd255) begin

                            // Bias = accumulated sum / 256
                            gyro_bias_x_o <= gx_sum_next[23:8];
                            gyro_bias_y_o <= gy_sum_next[23:8];
                            gyro_bias_z_o <= gz_sum_next[23:8];

                            calib_done_o <= 1'b1;

                            state <= DONE;

                        end
                        else begin

                            accum_count <= accum_count + 1'b1;

                        end

                    end

                end

                DONE: begin

                    // Allow a new calibration request
                    if (start_req) begin

                        settle_count <= 7'd0;
                        accum_count <= 9'd0;

                        accum_gx <= 24'sd0;
                        accum_gy <= 24'sd0;
                        accum_gz <= 24'sd0;

                        gyro_bias_x_o <= 16'sd0;
                        gyro_bias_y_o <= 16'sd0;
                        gyro_bias_z_o <= 16'sd0;

                        calib_done_o <= 1'b0;

                        state <= SETTLE;

                    end

                end

                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule

`default_nettype wire





