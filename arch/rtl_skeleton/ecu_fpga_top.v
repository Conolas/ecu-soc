// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// ecu_fpga_top: FPGA-ONLY board wrapper. Not part of the GDSII.
//   * clock generator (MMCM on the Arty A7: 100 MHz -> 50 MHz) -> clk_in, pll_locked_i
//   * open-drain pad logic for I2C (external pull-ups)
//   * NO synchronisers here (ACR-1): raw pins go straight into ecu_soc_top
// verilator lint_off UNUSEDSIGNAL
module fpga_clk_gen (input wire clk_board, output wire clk_50, output wire locked);
  // PLACEHOLDER for MMCME2_BASE (Vivado). Replace with the Clocking Wizard instance.
  assign clk_50 = clk_board;
  assign locked = 1'b1;
endmodule

module ecu_fpga_top #(
  parameter HW_ONLY = 1
) (
  input  wire        clk_board,
  input  wire        rst_n_in,
  input  wire        estop_n_i,
  input  wire        arm_sw_i,
  input  wire        bench_en_i,
  input  wire [1:0]  bench_sel_i,
  inout  wire        scl_pad,
  inout  wire        sda_pad,
  output wire        l_rpwm_o, l_lpwm_o, l_r_en_o, l_l_en_o,
  output wire        r_rpwm_o, r_lpwm_o, r_r_en_o, r_l_en_o,
  output wire [7:0]  dbg_o
);
  wire clk_50, pll_locked, scl_drive_low, sda_drive_low;
  fpga_clk_gen u_clk (.clk_board(clk_board), .clk_50(clk_50), .locked(pll_locked));
  assign scl_pad = scl_drive_low ? 1'b0 : 1'bz;   // open-drain: pull low or release
  assign sda_pad = sda_drive_low ? 1'b0 : 1'bz;
  ecu_soc_top #(.HW_ONLY(HW_ONLY)) u_soc (
    .clk_in(clk_50), .rst_n_in(rst_n_in), .pll_locked_i(pll_locked),
    .estop_n_i(estop_n_i), .arm_sw_i(arm_sw_i), .bench_en_i(bench_en_i), .bench_sel_i(bench_sel_i),
    .scl_i(scl_pad), .sda_i(sda_pad), .scl_drive_low_o(scl_drive_low), .sda_drive_low_o(sda_drive_low),
    .l_rpwm_o(l_rpwm_o), .l_lpwm_o(l_lpwm_o), .l_r_en_o(l_r_en_o), .l_l_en_o(l_l_en_o),
    .r_rpwm_o(r_rpwm_o), .r_lpwm_o(r_lpwm_o), .r_r_en_o(r_r_en_o), .r_l_en_o(r_l_en_o),
    .dbg_o(dbg_o));
endmodule
`default_nettype wire
