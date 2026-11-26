`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.11.2026 16:45:01
// Design Name: 
// Module Name: bts7960_motor_if
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


module bts7960_motor_if (
    input  wire        clk,           // 50 MHz system clock
    input  wire        rst_n,         // Active-low reset

    // Inputs from pwm_generator
    input  wire        global_en_i,   // pwm_enable_i && CTRL.EN
    input  wire        pwm_i,         // Raw PWM pulse from pwm_generator
    input  wire        dir_i,         // 1 = Forward (+), 0 = Reverse (-)
    input  wire        zero_i,        // 1 = Duty is 0 (stop)
    input  wire        dir_inv_i,     // Wiring polarity swap bit (DIR_INV_L / DIR_INV_R)
    input  wire [15:0] deadtime_i,    // Dead-time in clk cycles (default 250 = 5 us)

    // Feedback to pwm_generator STATUS register
    output wire        in_deadtime_o, // 1 while dead-time pause is active

    // Physical Pins to BTS7960 H-Bridge Driver
    output wire        rpwm_o,        // Forward PWM pulses
    output wire        lpwm_o,        // Reverse PWM pulses
    output wire        r_en_o,        // Right half-bridge enable
    output wire        l_en_o         // Left half-bridge enable
);

    // -------------------------------------------------------------------------
    // Dead-Time FSM States (Shoot-Through Protection)
    // -------------------------------------------------------------------------
    localparam [1:0] ST_DEAD    = 2'b00,
                     ST_RUN_FWD = 2'b01,
                     ST_RUN_REV = 2'b10;

    reg [1:0]  state;
    reg [15:0] dt_cnt;

    // Absorb physical motor wire polarity differences before the direction FSM
    wire req_dir = dir_i ^ dir_inv_i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state  <= ST_DEAD;
            dt_cnt <= 16'd0;
        end else if (!global_en_i) begin
            // When disarmed, reset FSM and preload dead-time for safe startup
            state  <= ST_DEAD;
            dt_cnt <= deadtime_i;
        end else begin
            case (state)
                ST_DEAD: begin
                    if (dt_cnt > 16'd0) begin
                        // Hold both RPWM and LPWM low until dead-time expires
                        dt_cnt <= dt_cnt - 16'd1;
                    end else if (!zero_i) begin
                        // Safe to enter requested direction once command is non-zero
                        state <= req_dir ? ST_RUN_FWD : ST_RUN_REV;
                    end
                end

                ST_RUN_FWD: begin
                    if (!zero_i && !req_dir) begin
                        // Direction reversal (+ to -) detected: insert dead-time
                        state  <= ST_DEAD;
                        dt_cnt <= (deadtime_i > 16'd0) ? (deadtime_i - 16'd1) : 16'd0;
                    end
                end

                ST_RUN_REV: begin
                    if (!zero_i && req_dir) begin
                        // Direction reversal (- to +) detected: insert dead-time
                        state  <= ST_DEAD;
                        dt_cnt <= (deadtime_i > 16'd0) ? (deadtime_i - 16'd1) : 16'd0;
                    end
                end

                default: begin
                    state  <= ST_DEAD;
                    dt_cnt <= deadtime_i;
                end
            endcase
        end
    end

    // Status flag for STATUS register (b2 / b3)
    assign in_deadtime_o = (state == ST_DEAD) && (dt_cnt > 16'd0);

    // -------------------------------------------------------------------------
    // Hardware Shoot-Through Interlock & Pin Mapping
    // -------------------------------------------------------------------------
    // Mutually exclusive conditions guarantee !(rpwm_o && lpwm_o) at all times
    wire fwd_ok = global_en_i && (state == ST_RUN_FWD) &&  req_dir && !zero_i;
    wire rev_ok = global_en_i && (state == ST_RUN_REV) && !req_dir && !zero_i;

    assign rpwm_o = fwd_ok ? pwm_i : 1'b0;
    assign lpwm_o = rev_ok ? pwm_i : 1'b0;

    // Half-bridge power enables: drop immediately (within 1 clk) when disarmed
    assign r_en_o = global_en_i;
    assign l_en_o = global_en_i;

endmodule