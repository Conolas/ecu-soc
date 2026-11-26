`timescale 1ns / 1ps

module tb_pwm_generator;

    // 50 MHz System Clock (20 ns period)
    reg clk = 0;
    always #10 clk = ~clk;

    // DUT Signals
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

    wire               pwm_l_o, dir_l_o, zero_l_o;
    wire               pwm_r_o, dir_r_o, zero_r_o;
    wire               dir_inv_l_o, dir_inv_r_o;
    wire [15:0]        deadtime_o;
    wire               global_en_o;
    wire [15:0]        duty_l_o, duty_r_o;

    // Instantiate PWM Generator
    pwm_generator #(
        .DEF_EN       (1'b0),
        .PERIOD_DEF   (16'd2500),
        .DEADTIME_DEF (16'd250)
    ) dut (
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
        .in_deadtime_l_i (1'b0),
        .in_deadtime_r_i (1'b0),
        .pwm_l_o         (pwm_l_o),
        .dir_l_o         (dir_l_o),
        .zero_l_o        (zero_l_o),
        .pwm_r_o         (pwm_r_o),
        .dir_r_o         (dir_r_o),
        .zero_r_o        (zero_r_o),
        .dir_inv_l_o     (dir_inv_l_o),
        .dir_inv_r_o     (dir_inv_r_o),
        .deadtime_o      (deadtime_o),
        .global_en_o     (global_en_o),
        .duty_l_o        (duty_l_o),
        .duty_r_o        (duty_r_o)
    );

    // Helper task: Write MMIO register
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

    // Helper task: Pulse a new PID command (Q16.16 format)
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
        // Initialize inputs
        rst_n        = 0;
        s_valid_i    = 0;
        s_we_i       = 0;
        s_addr_i     = 0;
        s_wdata_i    = 0;
        cmd_valid_i  = 0;
        cmd_i        = 0;
        pwm_enable_i = 0;
        bench_en_i   = 0;
        bench_sel_i  = 2'b00;

        #100;
        rst_n = 1;
        #40;

        // 1. Enable PWM module via CTRL register (0x04): EN=1, CLAMP_EN=1
        mmio_write(6'h04, 32'h0000_0011);
        // Set MAX_DUTY (0x0C) to 100% (0xFFFF) so duty counts are easy to read on waves
        mmio_write(6'h0C, 32'h0000_FFFF);
        pwm_enable_i = 1'b1;

        // 2. Test +0.50 command (+32768) -> Expect duty = 1250 (50% high), dir = 1
        send_pid_cmd(32'sd32768);
        #150000; // Wait 3 PWM cycles (150 us) to see clear waves

        // 3. Test -0.25 command (-16384) -> Expect duty = 625 (25% high), dir = 0
        send_pid_cmd(-32'sd16384);
        #150000;

        // 4. Test Steering (+0.1 = 6554) on +0.50 command -> Expect duty_l = 1500, duty_r = 999
        mmio_write(6'h18, 32'sd6554);
        send_pid_cmd(32'sd32768);
        #150000;
        mmio_write(6'h18, 32'sd0); // Reset steer

        // 5. Test Bench Switch Override (bench_en_i = 1, bench_sel_i = 2'b11 -> +0.50)
        bench_en_i  = 1'b1;
        bench_sel_i = 2'b11;
        send_pid_cmd(-32'sd65536); // Ignored while bench_en_i == 1
        #150000;
        bench_en_i  = 1'b0;

        // 6. Test Safety Disable (pwm_enable_i = 0 -> immediate low)
        pwm_enable_i = 1'b0;
        #50000;

        $display("Simulation finished! Inspect waveforms in Vivado.");
        $finish;
    end

endmodule