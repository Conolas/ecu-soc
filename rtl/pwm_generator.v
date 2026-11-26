`timescale 1ns / 1ps

module pwm_generator #(
    parameter [0:0]  DEF_EN       = 1'b0,
    parameter [15:0] PERIOD_DEF   = 16'd2500, // 50 MHz / 2500 = 20 kHz
    parameter [15:0] DEADTIME_DEF = 16'd250   // 250 cycles = 5 us @ 50 MHz
)(
    input  wire               clk,            // 50 MHz system clock
    input  wire               rst_n,          // Active-low reset

    // MMIO Slave Bus (Base 0x1000_4000, word-aligned offsets 0x00..0x2C)
    input  wire               s_valid_i,
    input  wire               s_we_i,
    input  wire [5:0]         s_addr_i,
    input  wire [31:0]        s_wdata_i,
    output reg  [31:0]        s_rdata_o,
    output reg                s_ready_o,

    // Inputs from PID Controller / Safety / Switches (Frozen Contract)
    input  wire               cmd_valid_i,    // ~512 Hz pulse from PID
    input  wire signed [31:0] cmd_i,          // Q16.16 [-1.0, +1.0]
    input  wire               pwm_enable_i,   // From safety monitor (0 = all off)
    input  wire               bench_en_i,     // 1 = use bench switch table
    input  wire [1:0]         bench_sel_i,    // 00:0, 01:+0.25, 10:-0.25, 11:+0.5

    // Status Feedback from Motor Interface (tie to 0 in standalone sim)
    input  wire               in_deadtime_l_i,
    input  wire               in_deadtime_r_i,

    // Outputs to Motor Interface (BTS7960 driver block)
    output wire               pwm_l_o,        // Un-routed PWM pulse for Left
    output wire               dir_l_o,        // 1 = Forward (+), 0 = Reverse (-)
    output wire               zero_l_o,       // 1 = Duty is 0
    output wire               pwm_r_o,        // Un-routed PWM pulse for Right
    output wire               dir_r_o,        // 1 = Forward (+), 0 = Reverse (-)
    output wire               zero_r_o,       // 1 = Duty is 0
    output wire               dir_inv_l_o,    // Wiring inversion bit L
    output wire               dir_inv_r_o,    // Wiring inversion bit R
    output wire [15:0]        deadtime_o,     // Dead-time cycles to Motor IF
    output wire               global_en_o,    // pwm_enable_i && CTRL.EN

    // Debug Duty Counts
    output wire [15:0]        duty_l_o,
    output wire [15:0]        duty_r_o
);

    // -------------------------------------------------------------------------
    // Register Map (Base 0x1000_4000)
    // -------------------------------------------------------------------------
    localparam [31:0] ID_VAL = 32'h5057_4D01;

    reg        ctrl_en;
    reg        ctrl_slew_en;
    reg        ctrl_dir_inv_l;
    reg        ctrl_dir_inv_r;
    reg        ctrl_clamp_en;

    reg [15:0]        reg_period;
    reg [15:0]        reg_max_duty;
    reg [15:0]        reg_deadtime;
    reg signed [31:0] reg_slew_step;
    reg signed [31:0] reg_steer;
    reg signed [31:0] reg_gain_l;
    reg signed [31:0] reg_gain_r;
    reg               status_clamped; // Sticky W1C

    wire global_en = pwm_enable_i & ctrl_en;
    assign global_en_o = global_en;
    assign dir_inv_l_o = ctrl_dir_inv_l;
    assign dir_inv_r_o = ctrl_dir_inv_r;
    assign deadtime_o  = reg_deadtime;

    // -------------------------------------------------------------------------
    // Stage 1: Bench MUX
    // -------------------------------------------------------------------------
    reg signed [31:0] bench_cmd;
    always @(*) begin
        case (bench_sel_i)
            2'b00: bench_cmd = 32'sd0;
            2'b01: bench_cmd = 32'sd16384;   // +0.25 (Q16.16)
            2'b10: bench_cmd = -32'sd16384;  // -0.25 (Q16.16)
            2'b11: bench_cmd = 32'sd32768;   // +0.50 (Q16.16)
        endcase
    end

    wire signed [31:0] selected_cmd = bench_en_i ? bench_cmd : cmd_i;

    // -------------------------------------------------------------------------
    // Stage 2: Steer & Gain
    // -------------------------------------------------------------------------
    wire signed [32:0] left_raw  = $signed(selected_cmd) + $signed(reg_steer);
    wire signed [32:0] right_raw = $signed(selected_cmd) - $signed(reg_steer);

    wire signed [64:0] left_prod    = left_raw  * $signed(reg_gain_l);
    wire signed [64:0] right_prod   = right_raw * $signed(reg_gain_r);
    wire signed [32:0] left_gained  = left_prod[48:16];  // >>> 16
    wire signed [32:0] right_gained = right_prod[48:16]; // >>> 16

    // -------------------------------------------------------------------------
    // Stage 3: Clamp to +/- 1.0 (+/- 65536)
    // -------------------------------------------------------------------------
    localparam signed [32:0] POS_ONE = 33'sd65536;
    localparam signed [32:0] NEG_ONE = -33'sd65536;

    reg signed [31:0] target_l, target_r;
    reg               clamp_hit_l, clamp_hit_r;

    always @(*) begin
        clamp_hit_l = 1'b0;
        if (ctrl_clamp_en && (left_gained > POS_ONE)) begin
            target_l    = 32'sd65536;
            clamp_hit_l = 1'b1;
        end else if (ctrl_clamp_en && (left_gained < NEG_ONE)) begin
            target_l    = -32'sd65536;
            clamp_hit_l = 1'b1;
        end else begin
            target_l    = left_gained[31:0];
        end

        clamp_hit_r = 1'b0;
        if (ctrl_clamp_en && (right_gained > POS_ONE)) begin
            target_r    = 32'sd65536;
            clamp_hit_r = 1'b1;
        end else if (ctrl_clamp_en && (right_gained < NEG_ONE)) begin
            target_r    = -32'sd65536;
            clamp_hit_r = 1'b1;
        end else begin
            target_r    = right_gained[31:0];
        end
    end

    // -------------------------------------------------------------------------
    // Stage 4: Slew-Rate Limiter (Ramps from 0 on re-enable)
    // -------------------------------------------------------------------------
    reg signed [31:0] slew_l, slew_r;
    wire signed [32:0] diff_l   = $signed(target_l) - $signed(slew_l);
    wire signed [32:0] diff_r   = $signed(target_r) - $signed(slew_r);
    wire signed [32:0] step_ext = {reg_slew_step[31], reg_slew_step};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slew_l <= 32'sd0;
            slew_r <= 32'sd0;
        end else if (!global_en) begin
            slew_l <= 32'sd0;
            slew_r <= 32'sd0;
        end else if (cmd_valid_i) begin
            // Left channel slew
            if (!ctrl_slew_en)
                slew_l <= target_l;
            else if (diff_l > step_ext)
                slew_l <= slew_l + reg_slew_step;
            else if (diff_l < -step_ext)
                slew_l <= slew_l - reg_slew_step;
            else
                slew_l <= target_l;

            // Right channel slew
            if (!ctrl_slew_en)
                slew_r <= target_r;
            else if (diff_r > step_ext)
                slew_r <= slew_r + reg_slew_step;
            else if (diff_r < -step_ext)
                slew_r <= slew_r - reg_slew_step;
            else
                slew_r <= target_r;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 5: MMIO Register Read / Write
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_en        <= DEF_EN;
            ctrl_slew_en   <= 1'b0;
            ctrl_dir_inv_l <= 1'b0;
            ctrl_dir_inv_r <= 1'b0;
            ctrl_clamp_en  <= 1'b1;
            reg_period     <= PERIOD_DEF;
            reg_max_duty   <= 16'hE666;
            reg_deadtime   <= DEADTIME_DEF;
            reg_slew_step  <= 32'sd6554;
            reg_steer      <= 32'sd0;
            reg_gain_l     <= 32'sd65536;
            reg_gain_r     <= 32'sd65536;
            status_clamped <= 1'b0;
            s_ready_o      <= 1'b0;
            s_rdata_o      <= 32'd0;
        end else begin
            s_ready_o <= s_valid_i;

            if (global_en && cmd_valid_i && (clamp_hit_l || clamp_hit_r))
                status_clamped <= 1'b1;

            if (s_valid_i) begin
                if (s_we_i) begin
                    case (s_addr_i[5:2])
                        4'h1: begin // 0x04 CTRL
                            ctrl_en        <= s_wdata_i[0];
                            ctrl_slew_en   <= s_wdata_i[1];
                            ctrl_dir_inv_l <= s_wdata_i[2];
                            ctrl_dir_inv_r <= s_wdata_i[3];
                            ctrl_clamp_en  <= s_wdata_i[4];
                        end
                        4'h2: reg_period    <= s_wdata_i[15:0]; // 0x08 PERIOD
                        4'h3: reg_max_duty  <= s_wdata_i[15:0]; // 0x0C MAX_DUTY
                        4'h4: reg_deadtime  <= s_wdata_i[15:0]; // 0x10 DEADTIME
                        4'h5: reg_slew_step <= s_wdata_i;       // 0x14 SLEW_STEP
                        4'h6: reg_steer     <= s_wdata_i;       // 0x18 STEER
                        4'h7: reg_gain_l    <= s_wdata_i;       // 0x1C GAIN_L
                        4'h8: reg_gain_r    <= s_wdata_i;       // 0x20 GAIN_R
                        4'h9: if (s_wdata_i[1]) status_clamped <= 1'b0; // 0x24 STATUS W1C
                        default: ;
                    endcase
                end else begin
                    case (s_addr_i[5:2])
                        4'h0: s_rdata_o <= ID_VAL;
                        4'h1: s_rdata_o <= {27'd0, ctrl_clamp_en, ctrl_dir_inv_r, ctrl_dir_inv_l, ctrl_slew_en, ctrl_en};
                        4'h2: s_rdata_o <= {16'd0, reg_period};
                        4'h3: s_rdata_o <= {16'd0, reg_max_duty};
                        4'h4: s_rdata_o <= {16'd0, reg_deadtime};
                        4'h5: s_rdata_o <= reg_slew_step;
                        4'h6: s_rdata_o <= reg_steer;
                        4'h7: s_rdata_o <= reg_gain_l;
                        4'h8: s_rdata_o <= reg_gain_r;
                        4'h9: s_rdata_o <= {28'd0, in_deadtime_r_i, in_deadtime_l_i, status_clamped, global_en};
                        4'hA: s_rdata_o <= {16'd0, duty_l_o};
                        4'hB: s_rdata_o <= {16'd0, duty_r_o};
                        default: s_rdata_o <= 32'd0;
                    endcase
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Stage 6: |cmd| -> Duty Counts & Double-Buffered 20 kHz PWM Counter
    // -------------------------------------------------------------------------
    wire [31:0] abs_l = slew_l[31] ? (~slew_l + 32'd1) : slew_l;
    wire [31:0] abs_r = slew_r[31] ? (~slew_r + 32'd1) : slew_r;

    wire [15:0] sat16_l = (abs_l >= 32'd65535) ? 16'hFFFF : abs_l[15:0];
    wire [15:0] sat16_r = (abs_r >= 32'd65535) ? 16'hFFFF : abs_r[15:0];

    wire [15:0] mag16_l = (sat16_l > reg_max_duty) ? reg_max_duty : sat16_l;
    wire [15:0] mag16_r = (sat16_r > reg_max_duty) ? reg_max_duty : sat16_r;

    reg [15:0] pwm_cnt;
    reg [15:0] active_period;
    reg [15:0] active_duty_l, active_duty_r;
    reg        active_dir_l, active_dir_r;
    reg        active_zero_l, active_zero_r;

    wire [15:0] effective_period = (pwm_cnt >= active_period - 16'd1 || !global_en) ? reg_period : active_period;
    wire [31:0] prod_duty_l = mag16_l * effective_period;
    wire [31:0] prod_duty_r = mag16_r * effective_period;

    wire [15:0] next_duty_l = prod_duty_l[31:16];
    wire [15:0] next_duty_r = prod_duty_r[31:16];
    wire        next_dir_l  = (slew_l >= 32'sd0);
    wire        next_dir_r  = (slew_r >= 32'sd0);
    wire        next_zero_l = (slew_l == 32'sd0) || (next_duty_l == 16'd0);
    wire        next_zero_r = (slew_r == 32'sd0) || (next_duty_r == 16'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_cnt       <= 16'd0;
            active_period <= PERIOD_DEF;
            active_duty_l <= 16'd0;
            active_duty_r <= 16'd0;
            active_dir_l  <= 1'b1;
            active_dir_r  <= 1'b1;
            active_zero_l <= 1'b1;
            active_zero_r <= 1'b1;
        end else if (!global_en) begin
            pwm_cnt       <= 16'd0;
            active_period <= reg_period;
            active_duty_l <= 16'd0;
            active_duty_r <= 16'd0;
            active_dir_l  <= 1'b1;
            active_dir_r  <= 1'b1;
            active_zero_l <= 1'b1;
            active_zero_r <= 1'b1;
        end else begin
            if (pwm_cnt >= (active_period - 16'd1)) begin
                pwm_cnt       <= 16'd0;
                active_period <= (reg_period == 16'd0) ? 16'd1 : reg_period;
                active_duty_l <= next_duty_l;
                active_duty_r <= next_duty_r;
                active_dir_l  <= next_dir_l;
                active_dir_r  <= next_dir_r;
                active_zero_l <= next_zero_l;
                active_zero_r <= next_zero_r;
            end else begin
                pwm_cnt <= pwm_cnt + 16'd1;
            end
        end
    end

    assign pwm_l_o  = global_en && !active_zero_l && (pwm_cnt < active_duty_l);
    assign pwm_r_o  = global_en && !active_zero_r && (pwm_cnt < active_duty_r);
    assign dir_l_o  = active_dir_l;
    assign dir_r_o  = active_dir_r;
    assign zero_l_o = active_zero_l;
    assign zero_r_o = active_zero_r;

    assign duty_l_o = active_duty_l;
    assign duty_r_o = active_duty_r;

endmodule