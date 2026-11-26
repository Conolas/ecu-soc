`timescale 1ns / 1ps

`default_nettype none

module i2c_sensor_subsystem #(
    parameter DEF_EN = 0,
    parameter CLK_DIV_DEF = 31,
    parameter DEV_ADDR_DEF = 7'h68
    )(
        input wire clk, rst_n, s_sel_i, s_we_i, control_tick_i, scl_i, sda_i,
        input wire [3:0] s_be_i,
        input wire [11:0] s_addr_i,
        input wire [31:0] s_wdata_i,
        output reg scl_drive_low_o, sda_drive_low_o, imu_valid_o, imu_busy_o, imu_err_o, imu_init_done_o,
        output reg [15:0] imu_ax_o,
        output reg [15:0] imu_ay_o,
        output reg [15:0] imu_az_o,
        output reg [15:0] imu_gx_o,
        output reg [15:0] imu_gy_o,
        output reg [15:0] imu_gz_o,
        output reg [31:0] s_rdata_o
      );
      
   localparam [31:0] REG_ID_VAL = 32'h49324301;
  `ifdef SIMULATION
   localparam [21:0] BOOT_WAIT_CYCLES = 22'd50;
  `else
   localparam [21:0] BOOT_WAIT_CYCLES = 22'd2500000;
  `endif
   localparam [16:0] TIMEOUT_CYCLES = 17'd75000;
      
  // MPU-6050 Register Addresses & Expected Values
  localparam [7:0] MPU_REG_SMPLRT_DIV   = 8'h19;
  localparam [7:0] MPU_REG_CONFIG       = 8'h1A;
  localparam [7:0] MPU_REG_GYRO_CONFIG  = 8'h1B;
  localparam [7:0] MPU_REG_ACCEL_CONFIG = 8'h1C;
  localparam [7:0] MPU_REG_ACCEL_XOUT_H = 8'h3B;
  localparam [7:0] MPU_REG_PWR_MGMT_1   = 8'h6B;
  localparam [7:0] MPU_REG_WHO_AM_I     = 8'h75;
  localparam [7:0] MPU_WHO_AM_I_VAL     = 8'h68;
  
  // Low-Level I2C Byte Engine Commands
  localparam [2:0] CMD_NOP = 3'd0;
  localparam [2:0] CMD_START = 3'd1;
  localparam [2:0] CMD_REP_START = 3'd2;
  localparam [2:0] CMD_STOP = 3'd3;
  localparam [2:0] CMD_WRITE = 3'd4;
  localparam [2:0] CMD_READ = 3'd5;
  localparam [2:0] CMD_RECOVER = 3'd6;
  
  // Sequence FSM States
  localparam [3:0] SEQ_IDLE = 4'd0;
  localparam [3:0] SEQ_BOOT_WAIT = 4'd1;
  localparam [3:0] SEQ_INIT_START = 4'd2;
  localparam [3:0] SEQ_INIT_STEP = 4'd3;
  localparam [3:0] SEQ_READY = 4'd4;
  localparam [3:0] SEQ_READ_START = 4'd5;
  localparam [3:0] SEQ_READ_ADDR_W = 4'd6;
  localparam [3:0] SEQ_READ_REG = 4'd7;
  localparam [3:0] SEQ_READ_RSTART = 4'd8;
  localparam [3:0] SEQ_READ_ADDR_R = 4'd9;
  localparam [3:0] SEQ_READ_BYTES = 4'd10;
  localparam [3:0] SEQ_READ_STOP = 4'd11;
  localparam [3:0] SEQ_ERR_ABORT = 4'd12;
  localparam [3:0] SEQ_BUS_RECOVER = 4'd13;
  
  // 2-FF Input Synchronisers for SCL/SDA
  reg scl_ff1, scl_sync;
  reg sda_ff1, sda_sync;
  
  always@(posedge clk)begin
    if(!rst_n)
        begin
            scl_ff1 <= 1'b1;
            scl_sync <= 1'b1;
            sda_ff1 <= 1'b1;
            sda_sync <= 1'b1;
        end
    else begin
        scl_ff1 <= scl_i;
        scl_sync <= scl_ff1;
        sda_ff1 <= sda_i;
        sda_sync <= sda_ff1;
    end
  end

// Register Bank
    reg ctrl_en, ctrl_reinit_req, ctrl_soft_trig, stat_err_sticky, stat_timeout_sticky;
    reg [15:0] reg_clk_div;
    reg [6:0] reg_dev_addr;
    reg [31:0] reg_err_count;
    reg [31:0] reg_sample_count;
    
    wire unused_ok = &{1'b0, s_be_i, s_addr_i[1:0]};
    reg ev_err_pulse, ev_timeout_pulse, ev_sample_done, clear_reinit_req, clear_soft_trig;
    
    always@(posedge clk) begin
    if(!rst_n)
        begin
            ctrl_en <= (DEF_EN != 0) ? 1'b1 : 1'b0;
            ctrl_reinit_req <= 1'b0;
            ctrl_soft_trig <= 1'b0;
            reg_clk_div <= CLK_DIV_DEF [15:0];
            reg_dev_addr <= DEV_ADDR_DEF [6:0];
            stat_err_sticky <= 1'b0;
            stat_timeout_sticky <=1'b0;
            reg_err_count <= 32'd0;
            reg_sample_count <= 32'd0;
            s_rdata_o <= 32'd0;
        end
    else begin
        //Self Clearing Control Requests
        if(clear_reinit_req) clear_reinit_req <= 1'b0;
        if(clear_soft_trig) clear_soft_trig <= 1'b0;
        
        // Status and Counter Updates (h/w)
        if (ev_err_pulse) begin
        stat_err_sticky <= 1'b1;
        if (reg_err_count != 32'hFFFF_FFFF)
          reg_err_count <= reg_err_count + 32'd1;
      end
      if (ev_timeout_pulse) begin
        stat_timeout_sticky <= 1'b1;
      end
      if (ev_sample_done) begin
        reg_sample_count <= reg_sample_count + 32'd1;
      end
    end
    
    // Bus Write
      if (s_sel_i && s_we_i) begin
        case (s_addr_i[11:2])
          10'h01: begin // 0x04 CTRL
            ctrl_en <= s_wdata_i[0];
            if (s_wdata_i[1]) ctrl_reinit_req <= 1'b1;
            if (s_wdata_i[2]) ctrl_soft_trig  <= 1'b1;
          end
          10'h02: begin // 0x08 CLK_DIV
            reg_clk_div <= s_wdata_i[15:0];
          end
          10'h03: begin // 0x0C STATUS (W1C)
            if (s_wdata_i[2]) stat_err_sticky     <= 1'b0;
            if (s_wdata_i[3]) stat_timeout_sticky <= 1'b0;
          end
          10'h06: begin // 0x18 DEV_ADDR
            reg_dev_addr <= s_wdata_i[6:0];
          end
          default: ;
        endcase
      end
      
    // Bus Read (Registered: valid 1 cycle after s_sel_i)
      if (s_sel_i && !s_we_i) begin
        case (s_addr_i[11:2])
          10'h00: s_rdata_o <= REG_ID_VAL;                                 // 0x00 ID
          10'h01: s_rdata_o <= {29'd0, 2'b00, ctrl_en};                    // 0x04 CTRL
          10'h02: s_rdata_o <= {16'd0, reg_clk_div};                       // 0x08 CLK_DIV
          10'h03: s_rdata_o <= {28'd0, stat_timeout_sticky, stat_err_sticky,
                                imu_busy_o, imu_init_done_o};              // 0x0C STATUS
          10'h04: s_rdata_o <= reg_err_count;                              // 0x10 ERR_COUNT
          10'h05: s_rdata_o <= reg_sample_count;                           // 0x14 SAMPLE_COUNT
          10'h06: s_rdata_o <= {25'd0, reg_dev_addr};                      // 0x18 DEV_ADDR
          10'h08: s_rdata_o <= {{16{imu_ax_o[15]}}, imu_ax_o};             // 0x20 AX
          10'h09: s_rdata_o <= {{16{imu_ay_o[15]}}, imu_ay_o};             // 0x24 AY
          10'h0A: s_rdata_o <= {{16{imu_az_o[15]}}, imu_az_o};             // 0x28 AZ
          10'h0B: s_rdata_o <= {{16{imu_gx_o[15]}}, imu_gx_o};             // 0x2C GX
          10'h0C: s_rdata_o <= {{16{imu_gy_o[15]}}, imu_gy_o};             // 0x30 GY
          10'h0D: s_rdata_o <= {{16{imu_gz_o[15]}}, imu_gz_o};             // 0x34 GZ
          default: s_rdata_o <= 32'd0;
        endcase
      end
    end
    
  //Low-Level 4-Phase I2C Byte Engine (with Clock Stretching)
   reg eng_start, eng_done, eng_busy, eng_nack_lat;
   reg eng_ack_err;      // 1 = NACK received on write
   reg eng_rx_nack;     // 0 = send ACK, 1 = send NACK after read byte
   reg [1:0] eng_phase;
   reg [2:0] eng_cmd, eng_active_cmd;
   reg [3:0] eng_bit_idx;       // 0..8 (8 data bits + 1 ACK bit, or 9 recovery clocks)
   reg [7:0] eng_tx_byte, eng_rx_byte, eng_shift;
   reg [15:0] div_cnt;
   
  // Clock stretching check: when we release SCL (scl_drive_low_o == 0) in
  // phase 1 or 2, wait until external scl_sync actually rises.
  wire scl_stretched = (!scl_drive_low_o) && (!scl_sync) && ((eng_phase == 2'd1) || (eng_phase == 2'd2));

 always @(posedge clk) begin
    if (!rst_n) begin
      scl_drive_low_o <= 1'b0;
      sda_drive_low_o <= 1'b0;
      div_cnt         <= 16'd0;
      eng_busy        <= 1'b0;
      eng_done        <= 1'b0;
      eng_ack_err     <= 1'b0;
      eng_rx_byte     <= 8'd0;
      eng_active_cmd  <= CMD_NOP;
      eng_phase       <= 2'd0;
      eng_bit_idx     <= 4'd0;
      eng_shift       <= 8'd0;
      eng_nack_lat    <= 1'b0;
    end else begin
      eng_done <= 1'b0;

      if (!eng_busy) begin
        if (eng_start && (eng_cmd != CMD_NOP)) begin
          eng_busy       <= 1'b1;
          eng_active_cmd <= eng_cmd;
          eng_shift      <= eng_tx_byte;
          eng_nack_lat   <= eng_rx_nack;
          eng_phase      <= 2'd0;
          eng_bit_idx    <= 4'd0;
          eng_ack_err    <= 1'b0;
          div_cnt        <= 16'd0;
        end
      end else begin
        // Pause divider if slave is stretching SCL
        if (!scl_stretched) begin
          if (div_cnt == reg_clk_div) begin
            div_cnt <= 16'd0;

            case (eng_active_cmd)
              // -------------------------------------------------------------
              CMD_START: begin
                case (eng_phase)
                  2'd0: begin scl_drive_low_o <= 1'b0; sda_drive_low_o <= 1'b0; eng_phase <= 2'd1; end
                  2'd1: begin scl_drive_low_o <= 1'b0; sda_drive_low_o <= 1'b1; eng_phase <= 2'd2; end
                  2'd2: begin scl_drive_low_o <= 1'b1; sda_drive_low_o <= 1'b1; eng_phase <= 2'd3; end
                  2'd3: begin eng_busy <= 1'b0; eng_done <= 1'b1; end
                endcase
              end

              // -------------------------------------------------------------
              CMD_REP_START: begin
                case (eng_phase)
                  2'd0: begin scl_drive_low_o <= 1'b1; sda_drive_low_o <= 1'b0; eng_phase <= 2'd1; end
                  2'd1: begin scl_drive_low_o <= 1'b0; sda_drive_low_o <= 1'b0; eng_phase <= 2'd2; end
                  2'd2: begin scl_drive_low_o <= 1'b0; sda_drive_low_o <= 1'b1; eng_phase <= 2'd3; end
                  2'd3: begin scl_drive_low_o <= 1'b1; sda_drive_low_o <= 1'b1; eng_busy <= 1'b0; eng_done <= 1'b1; end
                endcase
              end

              // -------------------------------------------------------------
              CMD_STOP: begin
                case (eng_phase)
                  2'd0: begin scl_drive_low_o <= 1'b1; sda_drive_low_o <= 1'b1; eng_phase <= 2'd1; end
                  2'd1: begin scl_drive_low_o <= 1'b0; sda_drive_low_o <= 1'b1; eng_phase <= 2'd2; end
                  2'd2: begin scl_drive_low_o <= 1'b0; sda_drive_low_o <= 1'b0; eng_phase <= 2'd3; end
                  2'd3: begin eng_busy <= 1'b0; eng_done <= 1'b1; end
                endcase
              end

              // -------------------------------------------------------------
              CMD_WRITE: begin
                case (eng_phase)
                  2'd0: begin
                    scl_drive_low_o <= 1'b1;
                    if (eng_bit_idx < 4'd8)
                      sda_drive_low_o <= ~eng_shift[7];
                    else
                      sda_drive_low_o <= 1'b0; // Release SDA for slave ACK
                    eng_phase <= 2'd1;
                  end
                  2'd1: begin
                    scl_drive_low_o <= 1'b0; // Raise SCL
                    eng_phase <= 2'd2;
                  end
                  2'd2: begin
                    if (eng_bit_idx == 4'd8)
                      eng_ack_err <= sda_sync; // 0=ACK, 1=NACK
                    eng_phase <= 2'd3;
                  end
                  2'd3: begin
                    scl_drive_low_o <= 1'b1; // Pull SCL low
                    if (eng_bit_idx < 4'd8) begin
                      eng_shift   <= {eng_shift[6:0], 1'b0};
                      eng_bit_idx <= eng_bit_idx + 4'd1;
                      eng_phase   <= 2'd0;
                    end else begin
                      eng_busy <= 1'b0;
                      eng_done <= 1'b1;
                    end
                  end
                endcase
              end

              // -------------------------------------------------------------
              CMD_READ: begin
                case (eng_phase)
                  2'd0: begin
                    scl_drive_low_o <= 1'b1;
                    if (eng_bit_idx < 4'd8)
                      sda_drive_low_o <= 1'b0; // Release SDA to read
                    else
                      sda_drive_low_o <= ~eng_nack_lat; // 0->drive low (ACK), 1->release (NACK)
                    eng_phase <= 2'd1;
                  end
                  2'd1: begin
                    scl_drive_low_o <= 1'b0; // Raise SCL
                    eng_phase <= 2'd2;
                  end
                  2'd2: begin
                    if (eng_bit_idx < 4'd8)
                      eng_rx_byte <= {eng_rx_byte[6:0], sda_sync};
                    eng_phase <= 2'd3;
                  end
                  2'd3: begin
                    scl_drive_low_o <= 1'b1; // Pull SCL low
                    if (eng_bit_idx < 4'd8) begin
                      eng_bit_idx <= eng_bit_idx + 4'd1;
                      eng_phase   <= 2'd0;
                    end else begin
                      eng_busy <= 1'b0;
                      eng_done <= 1'b1;
                    end
                  end
                endcase
              end

              // -------------------------------------------------------------
              CMD_RECOVER: begin
                // 9 SCL pulses with SDA released to clear stuck slave
                case (eng_phase)
                  2'd0: begin scl_drive_low_o <= 1'b1; sda_drive_low_o <= 1'b0; eng_phase <= 2'd1; end
                  2'd1: begin scl_drive_low_o <= 1'b0; eng_phase <= 2'd2; end
                  2'd2: begin eng_phase <= 2'd3; end
                  2'd3: begin
                    scl_drive_low_o <= 1'b1;
                    if (eng_bit_idx < 4'd8) begin
                      eng_bit_idx <= eng_bit_idx + 4'd1;
                      eng_phase   <= 2'd0;
                    end else begin
                      eng_busy <= 1'b0;
                      eng_done <= 1'b1;
                    end
                  end
                endcase
              end

              default: begin
                eng_busy <= 1'b0;
                eng_done <= 1'b1;
              end
            endcase
          end else begin
            div_cnt <= div_cnt + 16'd1;
          end
        end
      end
    end
  end
   
 // MPU-6050 Sequencer and Coherent Sample Assembler
    reg  [3:0] seq_state;
  reg  [2:0] init_idx;      // 0: WHO_AM_I, 1..5: Config writes
  reg  [2:0] sub_step;      // Sub-step inside init transactions
  reg  [3:0] byte_idx;      // 0..13 for 14-byte burst
  reg [21:0] wait_cnt;
  reg [16:0] timeout_cnt;
  reg  [1:0] consec_err_cnt;

  // Staging registers for atomic update after STOP
  reg [7:0]  b_ax_h, b_ax_l;
  reg [7:0]  b_ay_h, b_ay_l;
  reg [7:0]  b_az_h, b_az_l;
  reg [7:0]  b_gx_h, b_gx_l;
  reg [7:0]  b_gy_h, b_gy_l;
  reg [7:0]  b_gz_h, b_gz_l;

  // Init ROM lookup for config writes (init_idx 1..5)
  reg [7:0] init_reg_addr;
  reg [7:0] init_reg_val;
    
    always @(*) begin
    case (init_idx)
      3'd1: begin init_reg_addr = MPU_REG_PWR_MGMT_1;   init_reg_val = 8'h01; end
      3'd2: begin init_reg_addr = MPU_REG_SMPLRT_DIV;   init_reg_val = 8'h00; end
      3'd3: begin init_reg_addr = MPU_REG_CONFIG;       init_reg_val = 8'h02; end
      3'd4: begin init_reg_addr = MPU_REG_GYRO_CONFIG;  init_reg_val = 8'h00; end
      3'd5: begin init_reg_addr = MPU_REG_ACCEL_CONFIG; init_reg_val = 8'h00; end
      default: begin init_reg_addr = MPU_REG_PWR_MGMT_1; init_reg_val = 8'h01; end
    endcase
  end

  wire tx_active = (seq_state != SEQ_IDLE) && (seq_state != SEQ_BOOT_WAIT) &&
                   (seq_state != SEQ_READY) && (seq_state != SEQ_ERR_ABORT) &&
                   (seq_state != SEQ_BUS_RECOVER);

  always @(posedge clk) begin
    if (!rst_n) begin
      seq_state        <= SEQ_IDLE;
      init_idx         <= 3'd0;
      sub_step         <= 3'd0;
      byte_idx         <= 4'd0;
      wait_cnt         <= 22'd0;
      timeout_cnt      <= 17'd0;
      consec_err_cnt   <= 2'd0;

      eng_start        <= 1'b0;
      eng_cmd          <= CMD_NOP;
      eng_tx_byte      <= 8'd0;
      eng_rx_nack      <= 1'b0;

      imu_valid_o      <= 1'b0;
      imu_busy_o       <= 1'b0;
      imu_err_o        <= 1'b0;
      imu_init_done_o  <= 1'b0;
      imu_ax_o         <= 16'd0;
      imu_ay_o         <= 16'd0;
      imu_az_o         <= 16'd0;
      imu_gx_o         <= 16'd0;
      imu_gy_o         <= 16'd0;
      imu_gz_o         <= 16'd0;

      b_ax_h <= 8'd0; b_ax_l <= 8'd0;
      b_ay_h <= 8'd0; b_ay_l <= 8'd0;
      b_az_h <= 8'd0; b_az_l <= 8'd0;
      b_gx_h <= 8'd0; b_gx_l <= 8'd0;
      b_gy_h <= 8'd0; b_gy_l <= 8'd0;
      b_gz_h <= 8'd0; b_gz_l <= 8'd0;

      ev_err_pulse     <= 1'b0;
      ev_timeout_pulse <= 1'b0;
      ev_sample_done   <= 1'b0;
      clear_reinit_req <= 1'b0;
      clear_soft_trig  <= 1'b0;
    end else begin
      // Default single-cycle pulses
      eng_start        <= 1'b0;
      imu_valid_o      <= 1'b0;
      imu_err_o        <= 1'b0;
      ev_err_pulse     <= 1'b0;
      ev_timeout_pulse <= 1'b0;
      ev_sample_done   <= 1'b0;
      clear_reinit_req <= 1'b0;
      clear_soft_trig  <= 1'b0;

      // Transaction 1.5 ms timeout monitor
      if (tx_active) begin
        if (timeout_cnt >= TIMEOUT_CYCLES) begin
          ev_timeout_pulse <= 1'b1;
          ev_err_pulse     <= 1'b1;
          imu_err_o        <= 1'b1;
          timeout_cnt      <= 17'd0;
          seq_state        <= SEQ_ERR_ABORT;
        end else begin
          timeout_cnt <= timeout_cnt + 17'd1;
        end
      end else begin
        timeout_cnt <= 17'd0;
      end

      // Main Sequencer FSM
      case (seq_state)
        // -------------------------------------------------------------------
        SEQ_IDLE: begin
          imu_busy_o      <= 1'b0;
          imu_init_done_o <= 1'b0;
          if (ctrl_en) begin
            wait_cnt  <= 22'd0;
            seq_state <= SEQ_BOOT_WAIT;
          end
        end

        // -------------------------------------------------------------------
        SEQ_BOOT_WAIT: begin
          imu_init_done_o <= 1'b0; // ACR-7: low during (re-)init
          imu_busy_o      <= 1'b1;
          if (!ctrl_en) begin
            seq_state <= SEQ_IDLE;
          end else if (wait_cnt >= BOOT_WAIT_CYCLES) begin
            init_idx  <= 3'd0;
            sub_step  <= 3'd0;
            if (!sda_sync) begin
              // Stuck SDA recovery before init
              eng_cmd   <= CMD_RECOVER;
              eng_start <= 1'b1;
              seq_state <= SEQ_BUS_RECOVER;
            end else begin
              seq_state <= SEQ_INIT_START;
            end
          end else begin
            wait_cnt <= wait_cnt + 22'd1;
          end
        end

        // -------------------------------------------------------------------
        SEQ_INIT_START: begin
          if (!eng_busy && !eng_start) begin
            eng_cmd   <= CMD_START;
            eng_start <= 1'b1;
            sub_step  <= 3'd0;
            seq_state <= SEQ_INIT_STEP;
          end
        end

        // -------------------------------------------------------------------
        SEQ_INIT_STEP: begin
          if (eng_done) begin
            if (init_idx == 3'd0) begin
              // WHO_AM_I read sequence
              case (sub_step)
                3'd0: begin // After START -> send DEV_ADDR + W
                  eng_cmd     <= CMD_WRITE;
                  eng_tx_byte <= {reg_dev_addr, 1'b0};
                  eng_start   <= 1'b1;
                  sub_step    <= 3'd1;
                end
                3'd1: begin // After ADDR+W -> send WHO_AM_I reg
                  if (eng_ack_err) begin
                    ev_err_pulse <= 1'b1; imu_err_o <= 1'b1; seq_state <= SEQ_ERR_ABORT;
                  end else begin
                    eng_cmd     <= CMD_WRITE;
                    eng_tx_byte <= MPU_REG_WHO_AM_I;
                    eng_start   <= 1'b1;
                    sub_step    <= 3'd2;
                  end
                end
                3'd2: begin // After reg -> Repeated START
                  if (eng_ack_err) begin
                    ev_err_pulse <= 1'b1; imu_err_o <= 1'b1; seq_state <= SEQ_ERR_ABORT;
                  end else begin
                    eng_cmd   <= CMD_REP_START;
                    eng_start <= 1'b1;
                    sub_step  <= 3'd3;
                  end
                end
                3'd3: begin // After REP_START -> send DEV_ADDR + R
                  eng_cmd     <= CMD_WRITE;
                  eng_tx_byte <= {reg_dev_addr, 1'b1};
                  eng_start   <= 1'b1;
                  sub_step    <= 3'd4;
                end
                3'd4: begin // After ADDR+R -> Read 1 byte with NACK
                  if (eng_ack_err) begin
                    ev_err_pulse <= 1'b1; imu_err_o <= 1'b1; seq_state <= SEQ_ERR_ABORT;
                  end else begin
                    eng_cmd     <= CMD_READ;
                    eng_rx_nack <= 1'b1;
                    eng_start   <= 1'b1;
                    sub_step    <= 3'd5;
                  end
                end
                3'd5: begin // After Read -> Check WHO_AM_I and STOP
                  if (eng_rx_byte != MPU_WHO_AM_I_VAL) begin
                    ev_err_pulse <= 1'b1; imu_err_o <= 1'b1; seq_state <= SEQ_ERR_ABORT;
                  end else begin
                    eng_cmd   <= CMD_STOP;
                    eng_start <= 1'b1;
                    sub_step  <= 3'd6;
                  end
                end
                3'd6: begin // After STOP -> Next init step
                  init_idx  <= 3'd1;
                  seq_state <= SEQ_INIT_START;
                end
                default: seq_state <= SEQ_ERR_ABORT;
              endcase
            end else begin
              // Config register write sequence (init_idx 1..5)
              case (sub_step)
                3'd0: begin // After START -> send DEV_ADDR + W
                  eng_cmd     <= CMD_WRITE;
                  eng_tx_byte <= {reg_dev_addr, 1'b0};
                  eng_start   <= 1'b1;
                  sub_step    <= 3'd1;
                end
                3'd1: begin // After ADDR+W -> send Reg Address
                  if (eng_ack_err) begin
                    ev_err_pulse <= 1'b1; imu_err_o <= 1'b1; seq_state <= SEQ_ERR_ABORT;
                  end else begin
                    eng_cmd     <= CMD_WRITE;
                    eng_tx_byte <= init_reg_addr;
                    eng_start   <= 1'b1;
                    sub_step    <= 3'd2;
                  end
                end
                3'd2: begin // After Reg Address -> send Reg Value
                  if (eng_ack_err) begin
                    ev_err_pulse <= 1'b1; imu_err_o <= 1'b1; seq_state <= SEQ_ERR_ABORT;
                  end else begin
                    eng_cmd     <= CMD_WRITE;
                    eng_tx_byte <= init_reg_val;
                    eng_start   <= 1'b1;
                    sub_step    <= 3'd3;
                  end
                end
                3'd3: begin // After Reg Value -> STOP
                  if (eng_ack_err) begin
                    ev_err_pulse <= 1'b1; imu_err_o <= 1'b1; seq_state <= SEQ_ERR_ABORT;
                  end else begin
                    eng_cmd   <= CMD_STOP;
                    eng_start <= 1'b1;
                    sub_step  <= 3'd4;
                  end
                end
                3'd4: begin // After STOP -> Next config reg or DONE
                  if (init_idx == 3'd5) begin
                    imu_init_done_o <= 1'b1;
                    imu_busy_o      <= 1'b0;
                    consec_err_cnt  <= 2'd0;
                    seq_state       <= SEQ_READY;
                  end else begin
                    init_idx  <= init_idx + 3'd1;
                    seq_state <= SEQ_INIT_START;
                  end
                end
                default: seq_state <= SEQ_ERR_ABORT;
              endcase
            end
          end
        end

        // -------------------------------------------------------------------
        SEQ_READY: begin
          imu_busy_o <= 1'b0;
          if (!ctrl_en) begin
            seq_state <= SEQ_IDLE;
          end else if (ctrl_reinit_req) begin
            clear_reinit_req <= 1'b1;
            imu_init_done_o  <= 1'b0;
            wait_cnt         <= 22'd0;
            seq_state        <= SEQ_BOOT_WAIT;
          end else if (control_tick_i || ctrl_soft_trig) begin
            clear_soft_trig <= 1'b1;
            imu_busy_o      <= 1'b1;
            byte_idx        <= 4'd0;
            seq_state       <= SEQ_READ_START;
          end
        end

        // 14-Byte Burst Read (0x3B..0x48)
        SEQ_READ_START: begin
          eng_cmd   <= CMD_START;
          eng_start <= 1'b1;
          seq_state <= SEQ_READ_ADDR_W;
        end

        SEQ_READ_ADDR_W: begin
          if (eng_done) begin
            eng_cmd     <= CMD_WRITE;
            eng_tx_byte <= {reg_dev_addr, 1'b0};
            eng_start   <= 1'b1;
            seq_state   <= SEQ_READ_REG;
          end
        end

        SEQ_READ_REG: begin
          if (eng_done) begin
            if (eng_ack_err) begin
              ev_err_pulse <= 1'b1; imu_err_o <= 1'b1; seq_state <= SEQ_ERR_ABORT;
            end else begin
              eng_cmd     <= CMD_WRITE;
              eng_tx_byte <= MPU_REG_ACCEL_XOUT_H;
              eng_start   <= 1'b1;
              seq_state   <= SEQ_READ_RSTART;
            end
          end
        end

        SEQ_READ_RSTART: begin
          if (eng_done) begin
            if (eng_ack_err) begin
              ev_err_pulse <= 1'b1; imu_err_o <= 1'b1; seq_state <= SEQ_ERR_ABORT;
            end else begin
              eng_cmd   <= CMD_REP_START;
              eng_start <= 1'b1;
              seq_state <= SEQ_READ_ADDR_R;
            end
          end
        end

        SEQ_READ_ADDR_R: begin
          if (eng_done) begin
            eng_cmd     <= CMD_WRITE;
            eng_tx_byte <= {reg_dev_addr, 1'b1};
            eng_start   <= 1'b1;
            seq_state   <= SEQ_READ_BYTES;
          end
        end

        SEQ_READ_BYTES: begin
          if (eng_done) begin
            if (byte_idx == 4'd0 && eng_ack_err) begin
              // NACK on ADDR+R
              ev_err_pulse <= 1'b1; imu_err_o <= 1'b1; seq_state <= SEQ_ERR_ABORT;
            end else begin
              // Capture previous byte if we just finished a CMD_READ
              if (eng_active_cmd == CMD_READ) begin
                case (byte_idx)
                  4'd0:  b_ax_h <= eng_rx_byte;
                  4'd1:  b_ax_l <= eng_rx_byte;
                  4'd2:  b_ay_h <= eng_rx_byte;
                  4'd3:  b_ay_l <= eng_rx_byte;
                  4'd4:  b_az_h <= eng_rx_byte;
                  4'd5:  b_az_l <= eng_rx_byte;
                  // bytes 6, 7 (temp) discarded
                  4'd8:  b_gx_h <= eng_rx_byte;
                  4'd9:  b_gx_l <= eng_rx_byte;
                  4'd10: b_gy_h <= eng_rx_byte;
                  4'd11: b_gy_l <= eng_rx_byte;
                  4'd12: b_gz_h <= eng_rx_byte;
                  4'd13: b_gz_l <= eng_rx_byte;
                  default: ;
                endcase

                if (byte_idx == 4'd13) begin
                  eng_cmd   <= CMD_STOP;
                  eng_start <= 1'b1;
                  seq_state <= SEQ_READ_STOP;
                end else begin
                  byte_idx    <= byte_idx + 4'd1;
                  eng_cmd     <= CMD_READ;
                  eng_rx_nack <= (byte_idx == 4'd12) ? 1'b1 : 1'b0; // NACK 14th byte
                  eng_start   <= 1'b1;
                end
              end else begin
                // Just finished ADDR+R, issue first byte read (byte 0)
                eng_cmd     <= CMD_READ;
                eng_rx_nack <= 1'b0;
                eng_start   <= 1'b1;
              end
            end
          end
        end

        SEQ_READ_STOP: begin
          if (eng_done) begin
            // Atomic publish of all 6 axes after STOP
            imu_ax_o       <= {b_ax_h, b_ax_l};
            imu_ay_o       <= {b_ay_h, b_ay_l};
            imu_az_o       <= {b_az_h, b_az_l};
            imu_gx_o       <= {b_gx_h, b_gx_l};
            imu_gy_o       <= {b_gy_h, b_gy_l};
            imu_gz_o       <= {b_gz_h, b_gz_l};
            imu_valid_o    <= 1'b1;
            ev_sample_done <= 1'b1;
            imu_busy_o     <= 1'b0;
            consec_err_cnt <= 2'd0;
            seq_state      <= SEQ_READY;
          end
        end
     // Error Recovery & Stuck-Bus Handling
     
     SEQ_ERR_ABORT: begin
          if (!eng_busy && !eng_start) begin
            if (!sda_sync) begin
              eng_cmd   <= CMD_RECOVER;
              eng_start <= 1'b1;
              seq_state <= SEQ_BUS_RECOVER;
            end else begin
              eng_cmd   <= CMD_STOP;
              eng_start <= 1'b1;
              seq_state <= SEQ_BUS_RECOVER;
            end
          end
        end

        SEQ_BUS_RECOVER: begin
          if (eng_done) begin
            if (eng_active_cmd == CMD_RECOVER) begin
              // Follow 9 SCL pulses with a clean STOP
              eng_cmd   <= CMD_STOP;
              eng_start <= 1'b1;
            end else begin
              imu_busy_o <= 1'b0;
              if (!imu_init_done_o || (consec_err_cnt >= 2'd2)) begin
                // 3 consecutive errors (or init failure) -> re-run init
                imu_init_done_o <= 1'b0;
                consec_err_cnt  <= 2'd0;
                wait_cnt        <= 22'd0;
                seq_state       <= SEQ_BOOT_WAIT;
              end else begin
                consec_err_cnt <= consec_err_cnt + 2'd1;
                seq_state      <= SEQ_READY;
              end
            end
          end
        end

        default: seq_state <= SEQ_IDLE;
      endcase
    end
  end
endmodule

`default_nettype wire