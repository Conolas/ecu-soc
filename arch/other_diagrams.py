"""ecu_fpga_top and firmware diagrams (custom, terminal theme)."""
import sys, os
sys.path.insert(0, '/tmp/diagrams'); sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dk import *
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'diagrams')
# ===================================================================== ecu_fpga_top
s = Svg(2500, 1200, 'fpga')
s.text(40, 52, 'ecu_fpga_top  ·  FPGA-ONLY WRAPPER', 34, 'SemiBold', TEXT, 'start')
s.text(40, 90, 'owner Jaydev · Verilog-2001 + FPGA primitives · parameter HW_ONLY (1 for the phase-1 bitstream) · NOT part of the GDSII', 19, 'Regular', MUTED, 'start')
s.text(40, 122, 'Connects the real board (clock, buttons, switches, LEDs, I²C pads, motor-driver header) to ecu_soc_top. It does NOT synchronise inputs (ACR-1): raw pins go straight in.', 20, 'Regular', LIME, 'start')
# board side
s.lane(30, 160, 560, 940, 'BOARD  (Arty A7-100T  +  external hardware)', fill='#101316')
items = [('clk_board','100 MHz oscillator'),('rst_n_in','reset push-button (async)'),('estop_n_i','E-stop, active-low'),('arm_sw_i','arm slide switch (bring-up)'),
         ('bench_en_i','bench slide switch (bring-up)'),('bench_sel_i[1:0]','2 slide switches (bring-up)'),('scl_pad / sda_pad','inout → GY-521 (MPU-6050), 4.7 k pull-ups to 3.3 V'),
         ('dbg_o[7:0]','8 LEDs'),('l_rpwm_o l_lpwm_o l_r_en_o l_l_en_o','left BTS7960 module'),('r_rpwm_o r_lpwm_o r_r_en_o r_l_en_o','right BTS7960 module')]
for i, (a, b) in enumerate(items):
    y = 200 + i * 88
    s.box(60, y, 500, 74, a, b, 'ext', ts=19, ss=15)
# wrapper
s.lane(690, 160, 1100, 940, 'ecu_fpga_top', fill='#101316')
s.box(730, 200, 400, 120, 'fpga_clk_gen', 'MMCM: 100 MHz → exactly 50 MHz\noutputs clk_50 and locked', 'card', ts=22, ss=16)
s.box(730, 640, 400, 150, 'open-drain pad logic', 'scl_pad = scl_drive_low ? 0 : Z\nsda_pad = sda_drive_low ? 0 : Z\ninputs: scl_i = scl_pad, sda_i = sda_pad', 'card', ts=22, ss=16)
s.box(730, 850, 400, 110, 'pin / LED buffers', 'IBUF / OBUF, LVCMOS33\npin table + XDC constraints', 'card', ts=22, ss=16)
s.box(1230, 330, 520, 430, 'ecu_soc_top', 'the GDSII core\n\nparameter HW_ONLY = 1\n(blocks reset to enabled → Wing A\nruns with no CPU)\n\nports = the 20 top-level pins', 'hi', ts=30, ss=18)
# lines wrapper
L = lambda pts, **k: s.arrow(pts, k.get('st', 'main'), both=k.get('both', False), dash=k.get('dash', False))
lab = lambda x, y, t, sz=13: s.label(x, y, t, sz, TEXT, 'middle', mf='#101316')
ymid = lambda i: 200 + i * 88 + 37
L([(560, ymid(0)), (730, ymid(0))]); lab(645, ymid(0) - 12, 'clk_board', 12)
L([(1130, 240), (1230, 380)]); lab(1195, 285, 'clk_in', 12)
L([(1130, 290), (1230, 420)]); lab(1160, 345, 'pll_locked_i', 12)
for k, (idx, nm, dash) in enumerate([(1, 'rst_n_in', False), (2, 'estop_n_i  (raw)', False), (3, 'arm_sw_i  (raw, bring-up)', True), (4, 'bench_en_i  (raw, bring-up)', True), (5, 'bench_sel_i[1:0]  (raw, bring-up)', True)]):
    ye = 420 + k * 30; lx = 590 + 14 * k
    L([(560, ymid(idx)), (lx, ymid(idx)), (lx, ye), (1230, ye)], dash=dash)
    lab(1015, ye - 9, nm, 12)
L([(560, ymid(6)), (640, ymid(6)), (640, 690), (730, 690)], both=True); lab(600, ymid(6) - 12, 'scl_pad / sda_pad', 12)
L([(1130, 680), (1230, 680)]); lab(1180, 668, 'scl_i · sda_i', 12)
L([(1230, 725), (1130, 725)]); lab(1180, 743, 'drive_low ×2', 12)
L([(1400, 760), (1400, 905), (1130, 905)]); lab(1270, 893, 'dbg_o[7:0]', 12)
L([(730, 905), (560, ymid(7))]); 
L([(1560, 760), (1560, 1000), (610, 1000), (610, ymid(8)), (560, ymid(8))]); L([(610, 1000), (610, ymid(9)), (560, ymid(9))])
lab(1090, 988, 'l_rpwm/lpwm/r_en/l_en ×4  ·  r_rpwm/lpwm/r_en/l_en ×4   (8 motor-driver pins)', 12)
# FPGA-only inventory
s.lane(1830, 160, 640, 330, 'WHAT IS FPGA-ONLY HERE', fill='#101316')
for i, t in enumerate(['fpga_clk_gen (MMCM / Clocking Wizard)', 'pad logic for open-drain I²C (IOBUF)', 'LED and pin buffers, I/O standards, XDC', 'Vivado ILA / VIO cores, mark_debug', 'parameter HW_ONLY plumbing']):
    s.text(1860, 232 + 36 * i, '▸ ' + t, 17, 'Regular', TEXT, 'start')
s.text(1860, 440, 'ASIC: pad ring + clock pad / PLL macro replace this file.', 16, 'Regular', MUTED, 'start')
s.text(730, 1070, 'Pin table (fill in for your board, LVCMOS33): every port above gets one pin; clock constraint 20 ns on the 50 MHz clock. Never connect 5 V to FPGA pins.', 16, 'Regular', MUTED, 'start')
s.text(730, 1100, 'Phase-1 bitstream: HW_ONLY = 1.  Final: HW_ONLY = 0 and the CPU configures everything.', 16, 'Regular', MUTED, 'start')
s.save(os.path.join(OUT, 'blk_ecu_fpga_top.svg'))
# ===================================================================== firmware
s = Svg(2500, 1100, 'fw')
s.text(40, 52, 'firmware  ·  SOFTWARE BLOCK  (runs on cpu_subsystem)', 34, 'SemiBold', TEXT, 'start')
s.text(40, 90, 'owner Conolas · C + RISC-V assembly · rv32imc_zicsr · stored in rom_dp, uses ram_sp for data and stack', 19, 'Regular', MUTED, 'start')
s.text(40, 122, 'Configures and supervises the hardware through the register banks. Never in the real-time loop.', 20, 'Regular', LIME, 'start')
srcs = [('startup.S','vector table 0x00–0x7F\nreset 0x80, stack, .data, .bss'),('link.ld','ROM 0x0 / 8 KB\nRAM 0x2000_0000 / 4 KB'),('ecu_regs.h','every register address and bit\n(generated check vs the model)'),('main.c','tests 0–4, application, ISRs')]
for i, (a, b) in enumerate(srcs): s.box(40 + i * 330, 170, 300, 130, a, b, 'card', ts=22, ss=15)
s.box(1400, 170, 330, 130, 'riscv-gcc + ld', '-march=rv32imc_zicsr\n-mabi=ilp32 -Os', 'card', ts=22, ss=15)
s.box(1780, 170, 330, 130, 'firmware.elf → .bin', 'objcopy -O binary', 'card', ts=22, ss=15)
s.box(2150, 170, 310, 130, 'bin2hex.py', 'one 32-bit word per line', 'card', ts=22, ss=15)
for x in (340, 670, 1000, 1330): pass
s.arrow([(1330, 235), (1400, 235)], 'main'); s.arrow([(1730, 235), (1780, 235)], 'main'); s.arrow([(2110, 235), (2150, 235)], 'main')
s.box(2150, 360, 310, 100, 'firmware.hex', 'ROM initialisation file', 'hi', ts=22, ss=15); s.arrow([(2305, 300), (2305, 360)], 'main')
s.box(2150, 520, 310, 100, 'rom_dp', '$readmemh at configuration', 'ext', ts=22, ss=15); s.arrow([(2305, 460), (2305, 520)], 'main')
s.lane(40, 340, 1980, 700, 'WHAT THE PROGRAM DOES  (jobs, in order)', fill='#101316')
jobs = [('1 boot','read the six ID words\nFAIL code on mismatch'),('2 timer','TICK_PERIOD, IRQ_DIV, EN\n→ control tick, 10 Hz irq'),('3 sensor','I2C CLK_DIV, EN\nwait INIT_DONE (time-out)'),('4 pipeline','axis/sign/filter bits\nCAL_START, wait CAL_DONE'),
        ('5 PID','Kp, Ki·Ts, Kd, setpoint,\nlimits, CTRL'),('6 PWM','period, dead-time, MAX_DUTY,\ngains, CTRL'),('7 safety','TILT_LIMIT, time-outs,\nWD_EN, IRQ_EN, then ARM'),('8 supervise','loop: kick watchdog on heartbeat,\ntelemetry, fault policy')]
for i, (a, b) in enumerate(jobs):
    x = 70 + (i % 4) * 485; y = 390 + (i // 4) * 170
    s.box(x, y, 450, 140, a, b, 'hi' if i in (0, 7) else 'card', ts=22, ss=16)
    if i % 4 < 3: s.arrow([(x + 450, y + 70), (x + 485, y + 70)], 'main')
s.arrow([(70 + 3 * 485 + 225, 530), (70 + 3 * 485 + 225, 555), (295, 555), (295, 560)], 'main')
s.text(70, 760, 'INTERRUPTS (vector table in startup.S)', 18, 'Medium', LIME, 'start', 1)
s.text(70, 796, 'timer_isr  (mcause 7, vector 0x1C):  write 1 to TMR STATUS.IRQ_PENDING, set heartbeat flag', 17, 'Regular', TEXT, 'start')
s.text(70, 826, 'external_isr  (mcause 11, vector 0x2C):  read SAFE FAULT_STATUS, set fault flag, mask the interrupt in mie', 17, 'Regular', TEXT, 'start')
s.text(70, 856, 'exc_handler  (offset 0x00):  save mcause / mepc / mtval, set FAIL code, stop', 17, 'Regular', TEXT, 'start')
s.text(70, 906, 'RULES', 18, 'Medium', LIME, 'start', 1)
s.text(70, 940, 'volatile 32-bit register access · time-out on every wait · interrupt handlers never read-modify-write peripheral registers · no printf, no floating point at run time', 17, 'Regular', TEXT, 'start')
s.text(70, 970, 'ARM last; the hardware decides whether arming is allowed; after a fault the CPU never re-arms by itself.', 17, 'Regular', MUTED, 'start')
s.text(2090, 700, 'Telemetry reads:', 16, 'Medium', LIME, 'start'); s.text(2090, 726, 'SENS ANGLE_FILT, RATE_FILT', 15, 'Regular', MUTED, 'start'); s.text(2090, 750, 'PID U_OUT, P/I/D terms', 15, 'Regular', MUTED, 'start'); s.text(2090, 774, 'SAFE STATE, FAULT_STATUS', 15, 'Regular', MUTED, 'start')
s.save(os.path.join(OUT, 'blk_firmware.svg'))
print('other ok')
