// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).
`default_nettype none
// Skeleton: outputs tied to safe constants. Owner: Vedam. Replace by the real RTL keeping the ports.
// verilator lint_off UNUSEDSIGNAL
// verilator lint_off UNUSEDPARAM
module bus_interconnect (
  input wire clk,
  input wire rst_n,
  input wire instr_req_i,
  input wire [31:0] instr_addr_i,
  output wire instr_gnt_o,
  output wire instr_rvalid_o,
  output wire [31:0] instr_rdata_o,
  output wire instr_err_o,
  input wire data_req_i,
  input wire data_we_i,
  input wire [3:0] data_be_i,
  input wire [31:0] data_addr_i,
  input wire [31:0] data_wdata_i,
  output wire data_gnt_o,
  output wire data_rvalid_o,
  output wire [31:0] data_rdata_o,
  output wire data_err_o,
  output wire rom_ia_req_o,
  output wire [12:0] rom_ia_addr_o,
  input wire [31:0] rom_ia_rdata_i,
  output wire rom_sel_o,
  output wire [12:0] rom_addr_o,
  input wire [31:0] rom_rdata_i,
  output wire ram_sel_o,
  output wire ram_we_o,
  output wire [3:0] ram_be_o,
  output wire [11:0] ram_addr_o,
  output wire [31:0] ram_wdata_o,
  input wire [31:0] ram_rdata_i,
  output wire tmr_sel_o,
  output wire tmr_we_o,
  output wire [3:0] tmr_be_o,
  output wire [11:0] tmr_addr_o,
  output wire [31:0] tmr_wdata_o,
  input wire [31:0] tmr_rdata_i,
  output wire i2c_sel_o,
  output wire i2c_we_o,
  output wire [3:0] i2c_be_o,
  output wire [11:0] i2c_addr_o,
  output wire [31:0] i2c_wdata_o,
  input wire [31:0] i2c_rdata_i,
  output wire sens_sel_o,
  output wire sens_we_o,
  output wire [3:0] sens_be_o,
  output wire [11:0] sens_addr_o,
  output wire [31:0] sens_wdata_o,
  input wire [31:0] sens_rdata_i,
  output wire pid_sel_o,
  output wire pid_we_o,
  output wire [3:0] pid_be_o,
  output wire [11:0] pid_addr_o,
  output wire [31:0] pid_wdata_o,
  input wire [31:0] pid_rdata_i,
  output wire pwm_sel_o,
  output wire pwm_we_o,
  output wire [3:0] pwm_be_o,
  output wire [11:0] pwm_addr_o,
  output wire [31:0] pwm_wdata_o,
  input wire [31:0] pwm_rdata_i,
  output wire saf_sel_o,
  output wire saf_we_o,
  output wire [3:0] saf_be_o,
  output wire [11:0] saf_addr_o,
  output wire [31:0] saf_wdata_o,
  input wire [31:0] saf_rdata_i
);
  assign instr_gnt_o = 1'd0;   // safe default
  assign instr_rvalid_o = 1'd0;   // safe default
  assign instr_rdata_o = 32'd0;   // safe default
  assign instr_err_o = 1'd0;   // safe default
  assign data_gnt_o = 1'd0;   // safe default
  assign data_rvalid_o = 1'd0;   // safe default
  assign data_rdata_o = 32'd0;   // safe default
  assign data_err_o = 1'd0;   // safe default
  assign rom_ia_req_o = 1'd0;   // safe default
  assign rom_ia_addr_o = 13'd0;   // safe default
  assign rom_sel_o = 1'd0;   // safe default
  assign rom_addr_o = 13'd0;   // safe default
  assign ram_sel_o = 1'd0;   // safe default
  assign ram_we_o = 1'd0;   // safe default
  assign ram_be_o = 4'd0;   // safe default
  assign ram_addr_o = 12'd0;   // safe default
  assign ram_wdata_o = 32'd0;   // safe default
  assign tmr_sel_o = 1'd0;   // safe default
  assign tmr_we_o = 1'd0;   // safe default
  assign tmr_be_o = 4'd0;   // safe default
  assign tmr_addr_o = 12'd0;   // safe default
  assign tmr_wdata_o = 32'd0;   // safe default
  assign i2c_sel_o = 1'd0;   // safe default
  assign i2c_we_o = 1'd0;   // safe default
  assign i2c_be_o = 4'd0;   // safe default
  assign i2c_addr_o = 12'd0;   // safe default
  assign i2c_wdata_o = 32'd0;   // safe default
  assign sens_sel_o = 1'd0;   // safe default
  assign sens_we_o = 1'd0;   // safe default
  assign sens_be_o = 4'd0;   // safe default
  assign sens_addr_o = 12'd0;   // safe default
  assign sens_wdata_o = 32'd0;   // safe default
  assign pid_sel_o = 1'd0;   // safe default
  assign pid_we_o = 1'd0;   // safe default
  assign pid_be_o = 4'd0;   // safe default
  assign pid_addr_o = 12'd0;   // safe default
  assign pid_wdata_o = 32'd0;   // safe default
  assign pwm_sel_o = 1'd0;   // safe default
  assign pwm_we_o = 1'd0;   // safe default
  assign pwm_be_o = 4'd0;   // safe default
  assign pwm_addr_o = 12'd0;   // safe default
  assign pwm_wdata_o = 32'd0;   // safe default
  assign saf_sel_o = 1'd0;   // safe default
  assign saf_we_o = 1'd0;   // safe default
  assign saf_be_o = 4'd0;   // safe default
  assign saf_addr_o = 12'd0;   // safe default
  assign saf_wdata_o = 32'd0;   // safe default
endmodule
`default_nettype wire
