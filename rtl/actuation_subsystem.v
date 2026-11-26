`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.11.2026 16:45:48
// Design Name: 
// Module Name: actuation_subsystem
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


module actuation_subsystem #(
    parameter [0:0]  DEF_EN       = 1'b0,
    parameter [15:0] PERIOD_DEF   = 16'd2500,
    parameter [15:0] DEADTIME_DEF = 16'd250
)(
    input  wire               clk,
    input  wire               rst_n,

    // MMIO Slave Bus (Base 0x1000_4000)
    input  wire               s_valid_i,
    input  wire               s_we_i,
    input  wire [5:0]         s_addr_i,
    input  wire [31:0]        s_wdata_i,
    output wire [31:0]        s_rdata_o,
    output wire               s_ready_o,

    // Control & Safety Inputs
    input  wire               cmd_valid_i,
    input  wire signed [31:0] cmd_i,
    input  wire               pwm_enable_i,
    input  wire               bench_en_i,
    input  wire [1:0]         bench_sel_i,

    // Left BTS7960 Driver Pins
    output wire               l_rpwm_o,
    output wire               l_lpwm_o,
    output wire               l_r_en_o,
    output wire               l_l_en_o,

    // Right BTS7960 Driver Pins
    output wire               r_rpwm_o,
    output wire               r_lpwm_o,
    output wire               r_r_en_o,
    output wire               r_l_en_o,

    // Debug Duty Counts
    output wire [15:0]        duty_l_o,
    output wire [15:0]        duty_r_o
);

    // Internal Interconnection Wires
    wire        pwm_l, dir_l, zero_l;
    wire        pwm_r, dir_r, zero_r;
    wire        dir_inv_l, dir_inv_r;
    wire [15:0] deadtime;
    wire        global_en;
    wire        in_deadtime_l, in_deadtime_r;

    // 1. Command Shaping & 20 kHz PWM Generator
    pwm_generator #(
        .DEF_EN       (DEF_EN),
        .PERIOD_DEF   (PERIOD_DEF),
        .DEADTIME_DEF (DEADTIME_DEF)
    ) u_pwm_gen (
        .clk             (clk),
        .rst_n           (rst_n),
        .s_valid_i       (s_valid_i),
        .s_we_i          (s_we_i),
        .s_addr_i        (s_addr_i),
        .s_wdata_i       (s_wdata_i),
        .s_rdata_o       (s_rdata_o),
        .s_ready_o       (s_ready_o),
        .cmd_valid_i     (cmd_valid_i),
        .cmd_i           (cmd_i),
        .pwm_enable_i    (pwm_enable_i),
        .bench_en_i      (bench_en_i),
        .bench_sel_i     (bench_sel_i),
        .in_deadtime_l_i (in_deadtime_l),
        .in_deadtime_r_i (in_deadtime_r),
        .pwm_l_o         (pwm_l),
        .dir_l_o         (dir_l),
        .zero_l_o        (zero_l),
        .pwm_r_o         (pwm_r),
        .dir_r_o         (dir_r),
        .zero_r_o        (zero_r),
        .dir_inv_l_o     (dir_inv_l),
        .dir_inv_r_o     (dir_inv_r),
        .deadtime_o      (deadtime),
        .global_en_o     (global_en),
        .duty_l_o        (duty_l_o),
        .duty_r_o        (duty_r_o)
    );

    // 2. Left Motor BTS7960 Interface
    bts7960_motor_if u_left_motor_if (
        .clk           (clk),
        .rst_n         (rst_n),
        .global_en_i   (global_en),
        .pwm_i         (pwm_l),
        .dir_i         (dir_l),
        .zero_i        (zero_l),
        .dir_inv_i     (dir_inv_l),
        .deadtime_i    (deadtime),
        .in_deadtime_o (in_deadtime_l),
        .rpwm_o        (l_rpwm_o),
        .lpwm_o        (l_lpwm_o),
        .r_en_o        (l_r_en_o),
        .l_en_o        (l_l_en_o)
    );

    // 3. Right Motor BTS7960 Interface
    bts7960_motor_if u_right_motor_if (
        .clk           (clk),
        .rst_n         (rst_n),
        .global_en_i   (global_en),
        .pwm_i         (pwm_r),
        .dir_i         (dir_r),
        .zero_i        (zero_r),
        .dir_inv_i     (dir_inv_r),
        .deadtime_i    (deadtime),
        .in_deadtime_o (in_deadtime_r),
        .rpwm_o        (r_rpwm_o),
        .lpwm_o        (r_lpwm_o),
        .r_en_o        (r_r_en_o),
        .l_en_o        (r_l_en_o)
    );

endmodule