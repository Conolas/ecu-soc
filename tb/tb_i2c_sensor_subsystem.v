`timescale 1ns / 1ps
`define SIMULATION
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.11.2026 23:31:53
// Design Name: 
// Module Name: tb_i2c_sensor_subsystem
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


module tb_i2c_sensor_subsystem;
  reg clk;
  reg rst_n;
  reg s_sel_i;
  reg s_we_i;
  reg  [3:0]  s_be_i;
  reg  [11:0] s_addr_i;
  reg  [31:0] s_wdata_i;
  wire [31:0] s_rdata_o;

  reg  control_tick_i;
  wire scl_drive_low_o;
  wire sda_drive_low_o;

  wire imu_valid_o;
  wire [15:0] imu_ax_o, imu_ay_o, imu_az_o;
  wire [15:0] imu_gx_o, imu_gy_o, imu_gz_o;
  wire imu_busy_o;
  wire imu_err_o;
  wire imu_init_done_o;

  // Open-drain I2C bus model (pull-up = 1 when neither master nor slave drives low)
  reg  slave_scl_low;
  reg  slave_sda_low;
  reg  force_sda_stuck_low;

  wire scl_bus = !(scl_drive_low_o || slave_scl_low);
  wire sda_bus = !(sda_drive_low_o || slave_sda_low || force_sda_stuck_low);
  
  i2c_sensor_subsystem #(
    .DEF_EN       (0),
    .CLK_DIV_DEF  (31),
    .DEV_ADDR_DEF (7'h68)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .s_sel_i(s_sel_i),
    .s_we_i(s_we_i),
    .s_be_i(s_be_i),
    .s_addr_i(s_addr_i),
    .s_wdata_i(s_wdata_i),
    .s_rdata_o(s_rdata_o),
    .control_tick_i(control_tick_i),
    .scl_i(scl_bus),
    .sda_i(sda_bus),
    .scl_drive_low_o(scl_drive_low_o),
    .sda_drive_low_o(sda_drive_low_o),
    .imu_valid_o(imu_valid_o),
    .imu_ax_o(imu_ax_o),
    .imu_ay_o(imu_ay_o),
    .imu_az_o(imu_az_o),
    .imu_gx_o(imu_gx_o),
    .imu_gy_o(imu_gy_o),
    .imu_gz_o(imu_gz_o),
    .imu_busy_o(imu_busy_o),
    .imu_err_o(imu_err_o),
    .imu_init_done_o(imu_init_done_o)
  );

  initial clk = 1'b0;
  always #10 clk = ~clk;
  
  reg [7:0] mpu_regs [0:127];
  reg [6:0] mpu_ptr;
  reg       inject_nack;
  reg       inject_stretch;
  reg [7:0] stretch_cnt;

  localparam [2:0] SLV_IDLE       = 3'd0;
  localparam [2:0] SLV_ADDR       = 3'd1;
  localparam [2:0] SLV_ACK_ADDR   = 3'd2;
  localparam [2:0] SLV_REG_PTR    = 3'd3;
  localparam [2:0] SLV_WRITE_DATA = 3'd4;
  localparam [2:0] SLV_ACK_WRITE  = 3'd5;
  localparam [2:0] SLV_READ_DATA  = 3'd6;
  localparam [2:0] SLV_MASTER_ACK = 3'd7;

  reg [2:0] slv_state;
  reg [3:0] slv_bit;
  reg [7:0] slv_shift;
  reg       slv_rw;
  reg       slv_master_nack;
  reg       slv_next_is_data;

  integer i;
  task init_mpu_model;
    begin
      for (i = 0; i < 128; i = i + 1) mpu_regs[i] = 8'h00;
      mpu_regs[7'h6B] = 8'h40; // Power-up asleep (SLEEP bit = 1)
      mpu_regs[7'h75] = 8'h68; // WHO_AM_I = 0x68

      // Spec Section 6.3 model values:
      // ax=0x1000, ay=0xF000, az=0x4000, gx=0x0083, gy=0xFF00, gz=0x0000
      mpu_regs[7'h3B] = 8'h10; mpu_regs[7'h3C] = 8'h00; // AX =  4096
      mpu_regs[7'h3D] = 8'hF0; mpu_regs[7'h3E] = 8'h00; // AY = -4096
      mpu_regs[7'h3F] = 8'h40; mpu_regs[7'h40] = 8'h00; // AZ = 16384
      mpu_regs[7'h41] = 8'hAA; mpu_regs[7'h42] = 8'h55; // TEMP (discarded)
      mpu_regs[7'h43] = 8'h00; mpu_regs[7'h44] = 8'h83; // GX =   131
      mpu_regs[7'h45] = 8'hFF; mpu_regs[7'h46] = 8'h00; // GY =  -256
      mpu_regs[7'h47] = 8'h00; mpu_regs[7'h48] = 8'h00; // GZ =     0

      slv_state           = SLV_IDLE;
      slv_bit             = 4'd0;
      slave_sda_low       = 1'b0;
      slave_scl_low       = 1'b0;
      force_sda_stuck_low = 1'b0;
      inject_nack         = 1'b0;
      inject_stretch      = 1'b0;
      stretch_cnt         = 8'd0;
    end
  endtask

  // START / Repeated START detection
  always @(negedge sda_bus) begin
    if (scl_bus) begin
      slv_state        <= SLV_ADDR;
      slv_bit          <= 4'd0;
      slv_next_is_data <= 1'b0;
      slave_sda_low    <= 1'b0;
    end
  end

  // STOP detection
  always @(posedge sda_bus) begin
    if (scl_bus) begin
      slv_state     <= SLV_IDLE;
      slave_sda_low <= 1'b0;
    end
  end

  // Sample SDA on rising edge of SCL
  always @(posedge scl_bus) begin
    case (slv_state)
      SLV_ADDR, SLV_REG_PTR, SLV_WRITE_DATA: begin
        slv_shift <= {slv_shift[6:0], sda_bus};
        slv_bit   <= slv_bit + 4'd1;
      end
      SLV_READ_DATA: begin
        slv_bit <= slv_bit + 4'd1;
      end
      SLV_MASTER_ACK: begin
        slv_master_nack <= sda_bus;
      end
      default: ;
    endcase
  end

  // Drive SDA on falling edge of SCL
  always @(negedge scl_bus) begin
    case (slv_state)
      SLV_ADDR: begin
        if (slv_bit == 4'd8) begin
          if ((slv_shift[7:1] == 7'h68) && !inject_nack) begin
            slv_rw        <= slv_shift[0];
            slave_sda_low <= 1'b1; // ACK
            slv_state     <= SLV_ACK_ADDR;
          end else begin
            slave_sda_low <= 1'b0; // NACK
            slv_state     <= SLV_IDLE;
          end
        end
      end

      SLV_ACK_ADDR: begin
        slv_bit <= 4'd0;
        if (slv_rw == 1'b0) begin
          slave_sda_low <= 1'b0;
          slv_state     <= SLV_REG_PTR;
        end else begin
          // Prepare first read byte
          slv_shift     <= mpu_regs[mpu_ptr];
          slave_sda_low <= ~mpu_regs[mpu_ptr][7];
          slv_state     <= SLV_READ_DATA;
        end
      end

      SLV_REG_PTR: begin
        if (slv_bit == 4'd8) begin
          mpu_ptr          <= slv_shift[6:0];
          slv_next_is_data <= 1'b1;
          slave_sda_low    <= inject_nack ? 1'b0 : 1'b1;
          slv_state        <= SLV_ACK_WRITE;
        end
      end

      SLV_WRITE_DATA: begin
        if (slv_bit == 4'd8) begin
          mpu_regs[mpu_ptr] <= slv_shift;
          mpu_ptr           <= mpu_ptr + 7'd1;
          slave_sda_low     <= inject_nack ? 1'b0 : 1'b1;
          slv_state         <= SLV_ACK_WRITE;
        end
      end

      SLV_ACK_WRITE: begin
        slave_sda_low <= 1'b0;
        slv_bit       <= 4'd0;
        slv_state     <= slv_next_is_data ? SLV_WRITE_DATA : SLV_REG_PTR;
      end

      SLV_READ_DATA: begin
        if (slv_bit < 4'd8) begin
          slave_sda_low <= ~slv_shift[7 - slv_bit];
        end else begin
          slave_sda_low <= 1'b0; // Release SDA for master ACK/NACK
          slv_state     <= SLV_MASTER_ACK;
        end
      end

      SLV_MASTER_ACK: begin
        if (!slv_master_nack) begin
          mpu_ptr       <= mpu_ptr + 7'd1;
          slv_shift     <= mpu_regs[mpu_ptr + 7'd1];
          slave_sda_low <= ~mpu_regs[mpu_ptr + 7'd1][7];
          slv_bit       <= 4'd0;
          slv_state     <= SLV_READ_DATA;
        end else begin
          slave_sda_low <= 1'b0;
          slv_state     <= SLV_IDLE;
        end
      end

      default: slave_sda_low <= 1'b0;
    endcase
  end

  // Clock-stretch injector (holds SCL low for 200 system clocks once)
  always @(posedge clk) begin
    if (inject_stretch && (slv_state == SLV_READ_DATA) && scl_drive_low_o) begin
      slave_scl_low  <= 1'b1;
      stretch_cnt    <= 8'd200;
      inject_stretch <= 1'b0;
    end else if (stretch_cnt != 8'd0) begin
      stretch_cnt <= stretch_cnt - 8'd1;
      if (stretch_cnt == 8'd1) slave_scl_low <= 1'b0;
    end
  end

  // =========================================================================
  // 3. Bus Helper Tasks
  // =========================================================================
  integer err_count_tb;
  reg [31:0] rdata;

  task bus_write(input [11:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      s_sel_i   <= 1'b1;
      s_we_i    <= 1'b1;
      s_be_i    <= 4'hF;
      s_addr_i  <= addr;
      s_wdata_i <= data;
      @(posedge clk);
      s_sel_i   <= 1'b0;
      s_we_i    <= 1'b0;
    end
  endtask

  task bus_read(input [11:0] addr, output [31:0] data);
    begin
      @(posedge clk);
      s_sel_i  <= 1'b1;
      s_we_i   <= 1'b0;
      s_be_i   <= 4'hF;
      s_addr_i <= addr;
      @(posedge clk);
      s_sel_i  <= 1'b0;
      @(posedge clk); // Registered read: valid 1 cycle after s_sel_i
      data = s_rdata_o;
    end
  endtask

  task pulse_tick;
    begin
      @(posedge clk);
      control_tick_i <= 1'b1;
      @(posedge clk);
      control_tick_i <= 1'b0;
    end
  endtask

  task check_eq(input [31:0] actual, input [31:0] expected, input [255:0] msg);
    begin
      if (actual !== expected) begin
        $display("[FAIL] %0s: got 0x%08x, expected 0x%08x", msg, actual, expected);
        err_count_tb = err_count_tb + 1;
      end else begin
        $display("[PASS] %0s: 0x%08x", msg, actual);
      end
    end
  endtask

  // =========================================================================
  // 4. Test Sequence
  // =========================================================================
  time t_start, t_end;
  real latency_us;

  initial begin
    err_count_tb   = 0;
    s_sel_i        = 1'b0;
    s_we_i         = 1'b0;
    s_be_i         = 4'h0;
    s_addr_i       = 12'd0;
    s_wdata_i      = 32'd0;
    control_tick_i = 1'b0;

    init_mpu_model();

    // ACR-5: Start rst_n HIGH, then pull LOW after time 0
    rst_n = 1'b1;
    #30;
    rst_n = 1'b0;
    #100;
    rst_n = 1'b1;
    #40;

    // --- TEST 1: Register Bank ID ---
    $display("\n--- TEST 1: Register Bank ID ---");
    bus_read(12'h000, rdata);
    check_eq(rdata, 32'h49324301, "I2C.ID");

    // --- TEST 2: Autonomous MPU-6050 Init ---
    $display("\n--- TEST 2: MPU-6050 Initialization ---");
    bus_write(12'h004, 32'h0000_0001); // CTRL.EN = 1
    wait (imu_init_done_o == 1'b1);
    check_eq({24'd0, mpu_regs[7'h6B]}, 32'h01, "MPU PWR_MGMT_1 woke up");
    check_eq({24'd0, mpu_regs[7'h1A]}, 32'h02, "MPU CONFIG = 0x02");

    // --- TEST 3: 14-Byte Burst Read & Latency Window ---
    $display("\n--- TEST 3: 14-Byte Burst Read & Latency ---");
    t_start = $time;
    pulse_tick();
    wait (imu_valid_o == 1'b1);
    t_end = $time;
    latency_us = (t_end - t_start) / 1000.0;
    $display("[INFO] Tick-to-valid latency = %0.2f us", latency_us);
    if (latency_us < 380.0 || latency_us > 440.0) begin
      $display("[FAIL] Latency outside 380-440 us window!");
      err_count_tb = err_count_tb + 1;
    end else begin
      $display("[PASS] Latency within 380-440 us window");
    end

    check_eq({16'd0, imu_ax_o}, 32'h0000_1000, "imu_ax_o (4096)");
    check_eq({16'd0, imu_ay_o}, 32'h0000_F000, "imu_ay_o (-4096)");
    check_eq({16'd0, imu_az_o}, 32'h0000_4000, "imu_az_o (16384)");
    check_eq({16'd0, imu_gx_o}, 32'h0000_0083, "imu_gx_o (131)");
    check_eq({16'd0, imu_gy_o}, 32'h0000_FF00, "imu_gy_o (-256)");
    check_eq({16'd0, imu_gz_o}, 32'h0000_0000, "imu_gz_o (0)");

    bus_read(12'h024, rdata); // AY sign-extended
    check_eq(rdata, 32'hFFFF_F000, "Reg AY sign-extended");
    bus_read(12'h014, rdata);
    check_eq(rdata, 32'd1, "SAMPLE_COUNT == 1");

    // --- TEST 4: Clock Stretching ---
    $display("\n--- TEST 4: Clock Stretching ---");
    inject_stretch = 1'b1;
    pulse_tick();
    wait (imu_valid_o == 1'b1);
    bus_read(12'h014, rdata);
    check_eq(rdata, 32'd2, "SAMPLE_COUNT == 2 after stretch");

    // --- TEST 5: NACK Injection & 3-Error Reinit (ACR-7) ---
    $display("\n--- TEST 5: NACK & 3-Error Reinit ---");
    inject_nack = 1'b1;
    repeat (3) begin
      pulse_tick();
      wait (imu_err_o == 1'b1);
      wait (imu_busy_o == 1'b0);
      #200;
    end
    // After 3rd error, imu_init_done_o must drop low and re-run init
    if (imu_init_done_o !== 1'b0) begin
      $display("[FAIL] imu_init_done_o did not drop on 3rd error (ACR-7)");
      err_count_tb = err_count_tb + 1;
    end else begin
      $display("[PASS] imu_init_done_o dropped on 3rd error (ACR-7)");
    end
    inject_nack = 1'b0;
    wait (imu_init_done_o == 1'b1);
    $display("[PASS] Re-init completed after errors cleared");

    bus_read(12'h010, rdata);
    check_eq(rdata, 32'd3, "ERR_COUNT == 3");

    // Clear ERR_STICKY (W1C)
    bus_write(12'h00C, 32'h0000_0004);
    bus_read(12'h00C, rdata);
    check_eq(rdata & 32'h4, 32'd0, "STATUS.ERR_STICKY cleared");

    // --- TEST 6: Manual REINIT ---
    $display("\n--- TEST 6: CTRL.REINIT ---");
    bus_write(12'h004, 32'h0000_0003); // EN=1, REINIT=1
    wait (imu_init_done_o == 1'b0);
    wait (imu_init_done_o == 1'b1);
    $display("[PASS] Manual REINIT completed");

    // --- Summary ---
    #500;
    if (err_count_tb == 0)
      $display("\n=== ALL TESTS PASSED ===");
    else
      $display("\n=== FAILED WITH %0d ERRORS ===", err_count_tb);
    $finish;
  end

endmodule
