`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.11.2026 21:44:52
// Design Name: 
// Module Name: angle_conv
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

module angle_conv (

    input  wire clk,
    input  wire rst_n,

    // Input valid signal
    input  wire sample_valid_i,

    // Accelerometer inputs
    input  wire signed [15:0] ax_i,
    input  wire signed [15:0] ay_i,
    input  wire signed [15:0] az_i,

    // Gyroscope inputs
    input  wire signed [15:0] gx_i,
    input  wire signed [15:0] gy_i,
    input  wire signed [15:0] gz_i,

    // Configuration inputs
    input  wire axis_sel_i,
    input  wire inv_angle_i,
    input  wire inv_rate_i,

    // Converted outputs
    output reg angle_valid_o,
    output reg signed [31:0] angle_o,
    output reg signed [31:0] rate_o

);

    // -----------------------------------------
    // AXIS SELECTION
    // -----------------------------------------

    reg signed [15:0] accel_sel;
    reg signed [15:0] gyro_sel;

    always @(*) begin

        if (axis_sel_i == 1'b0) begin

            // AXIS_SEL = 0
            // Accelerometer X and Gyroscope Y

            accel_sel = ax_i;
            gyro_sel  = gy_i;

        end
        else begin

            // AXIS_SEL = 1
            // Accelerometer Y and Gyroscope X

            accel_sel = ay_i;
            gyro_sel  = gx_i;

        end

    end


    // -----------------------------------------
    // SIGN EXTENSION
    // -----------------------------------------

    wire signed [31:0] accel_ext;
    wire signed [31:0] gyro_ext;

    assign accel_ext = {{16{accel_sel[15]}}, accel_sel};
    assign gyro_ext  = {{16{gyro_sel[15]}}, gyro_sel};


    // -----------------------------------------
    // ACCELEROMETER CONVERSION
    // angle = accel * 4
    // -----------------------------------------

    wire signed [31:0] angle_calc;

    assign angle_calc = accel_ext <<< 2;


    // -----------------------------------------
    // GYROSCOPE CONVERSION
    // rate = (g << 3) + (g >>> 1) + (g >>> 2)
    // rate = g * 8.75
    // -----------------------------------------

    wire signed [31:0] rate_calc;

    assign rate_calc =
            (gyro_ext <<< 3)
          + (gyro_ext >>> 1)
          + (gyro_ext >>> 2);


    // -----------------------------------------
    // SIGN INVERSION
    // -----------------------------------------

    wire signed [31:0] angle_final;
    wire signed [31:0] rate_final;

    assign angle_final = inv_angle_i ? -angle_calc : angle_calc;

    assign rate_final  = inv_rate_i  ? -rate_calc  : rate_calc;


    // -----------------------------------------
    // REGISTERED OUTPUTS
    // ONE-CYCLE LATENCY
    // -----------------------------------------

    always @(posedge clk) begin

        if (!rst_n) begin

            angle_valid_o <= 1'b0;
            angle_o       <= 32'sd0;
            rate_o        <= 32'sd0;

        end
        else begin

            angle_valid_o <= sample_valid_i;

            if (sample_valid_i) begin

                angle_o <= angle_final;
                rate_o  <= rate_final;

            end

        end

    end

endmodule

`default_nettype wire


