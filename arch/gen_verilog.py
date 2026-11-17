"""Generate the Verilog-2001 skeleton (Week-1 deliverable) from the architecture model."""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arch_data as A
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rtl_skeleton'); os.makedirs(OUT, exist_ok=True)
def rng(w): return '' if w == 1 else '[%d:0] ' % (w - 1)
def params(b):
    L = []
    for p in A.BL[b].get('params', []):
        m = re.match(r'^([A-Z0-9_]+)=(.+)$', p)
        if m and not p.startswith('HW_ONLY') and '(localparams)' not in p: L.append((m.group(1), m.group(2).split(' ')[0]))
    return L
HDR = "// GENERATED from arch_data.py - do not edit by hand. Port list is the frozen contract (v1.1).\n`default_nettype none\n"
def stub(b):
    B = A.BL[b]; ps = params(b)
    s = HDR + "// Skeleton: outputs tied to safe constants. Owner: %s. Replace by the real RTL keeping the ports.\n// verilator lint_off UNUSEDSIGNAL\n// verilator lint_off UNUSEDPARAM\n" % B['owner']
    s += "module %s" % b
    if ps: s += " #(\n" + ",\n".join("  parameter %s = %s" % (n, v) for n, v in ps) + "\n)"
    s += " (\n" + ",\n".join("  %s wire %s%s" % ('input' if p['dir'] == 'in' else 'output', rng(p['width']), p['name']) for p in B['ports']) + "\n);\n"
    for p in B['ports']:
        if p['dir'] == 'out': s += "  assign %s = %d'd0;   // safe default\n" % (p['name'], p['width'])
    return s + "endmodule\n`default_nettype wire\n"
for b in A.BL:
    if A.BL[b]['kind'] == 'rtl':
        open(os.path.join(OUT, b + '.v'), 'w').write(stub(b))
# ------------------------------------------------------------------ ecu_soc_top.v
PIN = {n: (d, w) for n, d, w, c, ds in A.TOP_PINS}
def netsig(n): return n['name']
s = HDR + "// ecu_soc_top: wires every block. HW_ONLY=1 -> blocks reset to enabled so Wing A runs with NO CPU (FPGA phase 1). Final SoC: HW_ONLY=0.\n// verilator lint_off UNUSEDSIGNAL\nmodule ecu_soc_top #(\n  parameter HW_ONLY = 0\n) (\n"
s += ",\n".join("  %s wire %s%s" % ('input' if d == 'in' else 'output', rng(w), n) for n, d, w, c, ds in A.TOP_PINS) + "\n);\n\n"
pinnames = set(PIN)
for n in A.NETS:
    if n['name'] not in pinnames: s += "  wire %s%s;   // %s\n" % (rng(n['width']), n['name'], n['note'] or n['kind'])
s += "\n"
DEF = {'DEF_EN': 'HW_ONLY', 'DEF_WD_EN': "1'b0"}
signal_of = {}
for n in A.NETS:
    for e in [n['driver']] + n['loads']:
        if not e.startswith('TOP.'): signal_of[e] = n['name']
for b in A.BL:
    B = A.BL[b]
    if B['kind'] != 'rtl': continue
    ps = [(n, DEF[n] if n in DEF else v) for n, v in params(b)]
    s += "  %s" % b
    if ps: s += " #(\n" + ",\n".join("    .%s(%s)" % (n, v) for n, v in ps) + "\n  )"
    s += " u_%s (\n" % b
    s += ",\n".join("    .%s(%s)" % (p['name'], signal_of['%s.%s' % (b, p['name'])]) for p in B['ports']) + "\n  );\n\n"
s += "endmodule\n`default_nettype wire\n"
open(os.path.join(OUT, 'ecu_soc_top.v'), 'w').write(s)
# ------------------------------------------------------------------ ecu_fpga_top.v  (FPGA-only wrapper; NO synchronisers: ACR-1)
f = HDR + """// ecu_fpga_top: FPGA-ONLY board wrapper. Not part of the GDSII.
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
"""
open(os.path.join(OUT, 'ecu_fpga_top.v'), 'w').write(f)
print('generated', len(os.listdir(OUT)), 'files in rtl_skeleton/')
