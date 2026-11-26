`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.11.2026 16:46:50
// Design Name: 
// Module Name: tb_motor_interface
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
module tb_motor_interface;

    // 50 MHz System Clock (20 ns period)
    reg clk = 0;
    always #10 clk = ~clk;

    reg                rst_n;
    reg                s_valid_i;
    reg                s_we_i;
    reg  [5:0]         s_addr_i;
    reg  [31:0]        s_wdata_i;
    wire [31:0]        s_rdata_o;
    wire               s_ready_o;

    reg                cmd_valid_i;
    reg  signed [31:0] cmd_i;
    reg                pwm_enable_i;
    reg                bench_en_i;
    reg  [1:0]         bench_sel_i;

    wire               l_rpwm_o, l_lpwm_o, l_r_en_o, l_l_en_o;
    wire               r_rpwm_o, r_lpwm_o, r_r_en_o, r_l_en_o;
    wire [15:0]        duty_l_o, duty_r_o;

    actuation_subsystem #(
        .DEF_EN       (1'b0),
        .PERIOD_DEF   (16'd2500),
        .DEADTIME_DEF (16'd250)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_valid_i    (s_valid_i),
        .s_we_i       (s_we_i),
        .s_addr_i     (s_addr_i),
        .s_wdata_i    (s_wdata_i),
        .s_rdata_o    (s_rdata_o),
        .s_ready_o    (s_ready_o),
        .cmd_valid_i  (cmd_valid_i),
        .cmd_i        (cmd_i),
        .pwm_enable_i (pwm_enable_i),
        .bench_en_i   (bench_en_i),
        .bench_sel_i  (bench_sel_i),
        .l_rpwm_o     (l_rpwm_o),
        .l_lpwm_o     (l_lpwm_o),
        .l_r_en_o     (l_r_en_o),
        .l_l_en_o     (l_l_en_o),
        .r_rpwm_o     (r_rpwm_o),
        .r_lpwm_o     (r_lpwm_o),
        .r_r_en_o     (r_r_en_o),
        .r_l_en_o     (r_l_en_o),
        .duty_l_o     (duty_l_o),
        .duty_r_o     (duty_r_o)
    );

    // Hard Shoot-Through Safety Monitor (runs every clock edge)
    always @(posedge clk) begin
        if (l_rpwm_o && l_lpwm_o) begin
            $display("[ERROR] Shoot-through detected on LEFT motor at %0t!", $time);
            $finish;
        end
        if (r_rpwm_o && r_lpwm_o) begin
            $display("[ERROR] Shoot-through detected on RIGHT motor at %0t!", $time);
            $finish;
        end
    end

    task mmio_write(input [5:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            s_valid_i <= 1'b1;
            s_we_i    <= 1'b1;
            s_addr_i  <= addr;
            s_wdata_i <= data;
            @(posedge clk);
            s_valid_i <= 1'b0;
            s_we_i    <= 1'b0;
        end
    endtask

    task send_pid_cmd(input signed [31:0] q16_cmd);
        begin
            @(posedge clk);
            cmd_i       <= q16_cmd;
            cmd_valid_i <= 1'b1;
            @(posedge clk);
            cmd_valid_i <= 1'b0;
        end
    endtask

    initial begin
        rst_n = 0; s_valid_i = 0; s_we_i = 0; s_addr_i = 0; s_wdata_i = 0;
        cmd_valid_i = 0; cmd_i = 0; pwm_enable_i = 0; bench_en_i = 0; bench_sel_i = 0;

        #100;
        rst_n = 1;
        #40;

        // Enable module (CTRL.EN=1, CLAMP_EN=1) and set MAX_DUTY=100%
        mmio_write(6'h04, 32'h0000_0011);
        mmio_write(6'h0C, 32'h0000_FFFF);
        pwm_enable_i = 1'b1;

        // 1. Forward +0.5 (+32768) -> RPWM pulses, LPWM stays 0, R_EN/L_EN = 1
        send_pid_cmd(32'sd32768);
        #150000;

        // 2. Sudden Reverse -0.5 (-32768) -> Watch 5 us (250 clk) dead-time gap before LPWM starts!
        send_pid_cmd(-32'sd32768);
        #150000;

        // 3. Test DIR_INV_L = 1 (CTRL = 0x15) -> Left swaps back to RPWM, Right stays on LPWM
        mmio_write(6'h04, 32'h0000_0015);
        #150000;

        // 4. Emergency Stop (pwm_enable_i = 0) -> All RPWM, LPWM, R_EN, L_EN drop immediately
        pwm_enable_i = 1'b0;
        #50000;

        $display("Motor Interface simulation complete - zero shoot-through events!");
        $finish;
    end

endmodule