"""Whole-SoC diagram (every block, every net group, board side). Terminal theme."""
import sys, os
sys.path.insert(0, '/tmp/diagrams'); sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dk import *
import arch_data as A
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'diagrams')
W, H = 3860, 2020
s = Svg(W, H, 'soc')
DX = 150
def blk(name, x, y, w, h, role, owner, bank=None, kind='card'):
    s.items.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{CARD}" stroke="{LIME if kind=="hi" else LINE}" stroke-width="{3 if kind=="hi" else 2}"/>')
    s.text(x + 18, y + 36, name, 26, 'SemiBold', TEXT, 'start')
    s.text(x + w - 18, y + 34, owner, 16, 'Regular', MUTED, 'end')
    for i, t in enumerate(role): s.text(x + 18, y + 68 + 24 * i, t, 17, 'Regular', MUTED, 'start')
    s.text(x + w - 14, y + h - 12, 'clk · rst_n', 14, 'Regular', '#5f6770', 'end')
    if bank:
        k, bx = bank
        s.items.append(f'<rect x="{bx-52}" y="{y+h-6}" width="104" height="26" rx="4" fill="#1d2418" stroke="{LIME}" stroke-width="1.8"/>')
        s.text(bx, y + h + 13, '▼ ' + k, 15, 'Medium', LIME, 'middle')
def L(pts, st='main', both=False, dash=False, lab=None, lp=None, ls=13, w=None):
    s.arrow(pts, 'ctl' if st == 'ctl' else 'main', both=both, dash=dash)
    if lab:
        x, y = lp if lp else ((pts[0][0] + pts[1][0]) / 2, pts[0][1] - 8)
        s.label(x, y, lab, ls, MUTED if st == 'ctl' else TEXT, 'middle', mf=BG)
# ---------------------------------------------------------------- frames
s.text(40, 52, 'ecu_soc_top  ·  WHOLE-SoC ARCHITECTURE v1.1', 36, 'SemiBold', TEXT, 'start')
s.text(40, 90, 'every block · every net group · who drives what · FPGA-only parts dashed · one clock (50 MHz) · Q16.16 data · pulses are 1 clk', 20, 'Regular', MUTED, 'start')
s.items.append(f'<rect x="20" y="130" width="{W-40}" height="{H-160}" rx="14" fill="none" stroke="{MUTED}" stroke-width="2" stroke-dasharray="14 8"/>')
s.text(46, 164, 'ecu_fpga_top  (FPGA-ONLY wrapper: pad logic · clock generator · constraints)  ·  NOT in the GDSII', 19, 'Medium', MUTED, 'start', 1)
IX0, IX1 = 520, 150 + 2150 + 440 + 70
s.items.append(f'<rect x="{IX0}" y="190" width="{IX1-IX0}" height="{H-260}" rx="12" fill="#101316" stroke="{LIME}" stroke-width="2.5"/>')
s.text(IX0 + 20, 224, 'ecu_soc_top  (the GDSII core)  ·  parameter HW_ONLY', 20, 'Medium', LIME, 'start', 2)
# ---------------------------------------------------------------- blocks (x shifted by DX)
BW, BH = 440, 232
def X(x): return x + DX
T = 270
i2c  = (X(500), T, BW, BH);  sens = (X(1050), T, BW, BH); pid = (X(1600), T, BW, BH); act = (X(2150), T, BW, BH)
M = 730
clk  = (X(500), M, 340, BH); tim = (X(1050), M, 340, BH); saf = (X(1600), M, 340, BH)
Bt = 1210
cpu  = (X(500), Bt, 320, BH); bus = (X(1080), Bt, 400, BH); rom = (X(1700), Bt, 340, BH); ram = (X(1700), Bt + 290, 340, BH)
blk('i2c_sensor_subsystem', *i2c, ['mpu6050_ctrl · i2c_master · i2c_regs', 'reads 14 bytes / tick ≈ 0.4 ms'], 'Kaushal', ('I2C 0x1000_1000', i2c[0] + BW - 55))
blk('sensor_pipeline', *sens, ['capture · calibration · angle_conv', 'filter · trim · error_calc · SENS regs'], 'Dipiksha', ('SENS 0x1000_2000', sens[0] + BW - 55))
blk('hw_pid_accel', *pid, ['P · I · D with one shared multiplier', 'Q16.16, ≤ 16 cycles · PID regs'], 'Conolas', ('PID 0x1000_3000', pid[0] + BW - 55), 'hi')
blk('actuation_subsystem', *act, ['bench mux · steer/gain · clamp · slew', '2× (dead-time FSM + PWM 20 kHz) · PWM regs'], 'Jaydev', ('PWM 0x1000_4000', act[0] + BW - 55))
blk('clk_rst_gen', *clk, ['async assert, sync release', 'power-on hold 255 cycles'], 'Vedam')
blk('timer_unit', *tim, ['control tick ≈ 512 Hz · 10 Hz IRQ', 'overrun detect · TMR regs'], 'Dipiksha', ('TMR 0x1000_0000', tim[0] + 285))
blk('safety_fault_monitor', *saf, ['faults · arm FSM · watchdog', 'pwm_enable (≤ 2 clk off) · SAFE regs'], 'Vedam', ('SAFE 0x1000_5000', saf[0] + 285), 'hi')
blk('cpu_subsystem  (Ibex)', *cpu, ['RV32IMC small · firmware in ROM', 'supervises; NOT in the loop'], 'Conolas', None)
blk('bus_interconnect', *bus, ['decode · gnt same cycle · rvalid +1', 'unmapped / ROM write ⇒ err'], 'Vedam', None, 'hi')
blk('rom_dp  8 KB', *rom, ['0x0000_0000 · 2 read ports', 'vectors 0x00–0x7F, reset 0x80'], 'Vedam', None)
blk('ram_sp  4 KB', *ram, ['0x2000_0000 · byte-writable', 'stack top 0x2000_1000'], 'Vedam', None)
def cx(b, f): return b[0] + b[2] * f
# ---------------------------------------------------------------- Wing A chain
y1 = T + 70
L([(i2c[0] + BW, y1), (sens[0], y1)], lab='imu_valid · imu_a*/g* [6×16]', lp=((i2c[0] + BW + sens[0]) / 2, y1 - 12), ls=12)
L([(i2c[0] + BW, y1 + 40), (sens[0], y1 + 40)], lab='imu_init_done', lp=((i2c[0] + BW + sens[0]) / 2, y1 + 28), ls=12)
for k, (n, lb) in enumerate([(0, 'pipe_valid'), (1, 'err[32]'), (2, 'rate[32]')]):
    L([(sens[0] + BW, y1 + 40 * k), (pid[0], y1 + 40 * k)], lab=lb, lp=((sens[0] + BW + pid[0]) / 2, y1 + 40 * k - 8), ls=12)
for k, lb in enumerate(['pwm_cmd_valid', 'pwm_cmd[32]']):
    L([(pid[0] + BW, y1 + 40 * k), (act[0], y1 + 40 * k)], lab=lb, lp=((pid[0] + BW + act[0]) / 2, y1 + 40 * k - 8), ls=12)
sy = T - 40
L([(pid[0] + 120, T), (pid[0] + 120, sy), (sens[0] + 220, sy), (sens[0] + 220, T)], lab='setpoint[32]  (PID SETPOINT register → error_calc)', lp=(cx(sens, 0.5) + 330, sy - 10), ls=13)
# ---------------------------------------------------------------- control_tick (timer top -> sens, i2c, safety)
tx = tim[0] + 100
L([(tx, M), (tx, T + BH)], lab='control_tick', lp=(tx + 62, T + BH + 28), ls=13)
L([(tx, T + BH + 90), (i2c[0] + 160, T + BH + 90), (i2c[0] + 160, T + BH)], dash=False)
L([(tx, T + BH + 120), (saf[0] + 60, T + BH + 120), (saf[0] + 60, M)])
s.text(saf[0] + 60, T + BH + 112, 'control_tick →', 13, 'Regular', TEXT, 'middle') if False else None
# imu_busy i2c -> timer
L([(i2c[0] + 270, T + BH), (i2c[0] + 270, T + BH + 150), (tim[0] + 200, T + BH + 150), (tim[0] + 200, M)], lab='imu_busy', lp=(tim[0] + 120, T + BH + 140), ls=13)
# i2c -> safety: imu_valid, imu_err, imu_init_done
L([(i2c[0] + 330, T + BH), (i2c[0] + 330, T + BH + 180), (saf[0] + 110, T + BH + 180), (saf[0] + 110, M)], lab='imu_valid · imu_err · imu_init_done', lp=(sens[0] + 150, T + BH + 170), ls=13)
# sens -> safety: pipe_valid, angle, calib_done
L([(sens[0] + 300, T + BH), (sens[0] + 300, T + BH + 215), (saf[0] + 160, T + BH + 215), (saf[0] + 160, M)], lab='pipe_valid · angle[32] · calib_done', lp=(sens[0] + 700, T + BH + 205), ls=13)
# pid_sat pid->safety ; pwm_enable safety->pid, act
L([(pid[0] + 210, T + BH), (pid[0] + 210, M)], lab='pid_sat', lp=(pid[0] + 250, T + BH + 235), ls=13)
L([(saf[0] + 300, M), (saf[0] + 300, T + BH)], lab='pwm_enable', lp=(saf[0] + 362, T + BH + 235), ls=13)
L([(saf[0] + 300, T + BH + 70), (act[0] + 140, T + BH + 70), (act[0] + 140, T + BH)], lab='pwm_enable → run_i / pwm_enable_i', lp=(pid[0] + 620, T + BH + 60), ls=13)
# ---------------------------------------------------------------- interrupts to CPU
bx = Bt
L([(saf[0] + 120, M + BH), (saf[0] + 120, bx - 200), (cpu[0] + 190, bx - 200), (cpu[0] + 190, bx)], lab='irq_fault', lp=(cpu[0] + 600, bx - 212), ls=13)
L([(tim[0] + 60, M + BH), (tim[0] + 60, bx - 170), (cpu[0] + 110, bx - 170), (cpu[0] + 110, bx)], lab='irq_timer', lp=(cpu[0] + 500, bx - 182), ls=13)
# ---------------------------------------------------------------- CPU <-> bus
for k, (a, b, lb) in enumerate([(0, 1, 'instr_req/addr[32] →'), (1, 0, '← instr_gnt/rvalid/rdata/err'), (0, 1, 'data_req/we/be/addr/wdata →'), (1, 0, '← data_gnt/rvalid/rdata/err')]):
    yy = bx + 118 + 34 * k
    L([(cpu[0] + 320, yy), (bus[0], yy)] if a == 0 else [(bus[0], yy), (cpu[0] + 320, yy)], lab=lb, lp=((cpu[0] + 320 + bus[0]) / 2, yy - 8), ls=11)
# bus <-> ROM
for k, (a, lb) in enumerate([(0, 'rom_ia_req/addr[13] →'), (1, '← rom_ia_rdata[32]'), (0, 'rom_sel/addr[13] →'), (1, '← rom_rdata[32]')]):
    yy = bx + 118 + 34 * k
    L([(bus[0] + 400, yy), (rom[0], yy)] if a == 0 else [(rom[0], yy), (bus[0] + 400, yy)], lab=lb, lp=((bus[0] + 400 + rom[0]) / 2, yy - 8), ls=11)
# bus <-> RAM
ry = ram[1] + 100
L([(bus[0] + 200, bx + BH), (bus[0] + 200, ry), (ram[0], ry)], both=True, lab='ram_sel/we/be/addr[12]/wdata →  ← ram_rdata[32]', lp=(bus[0] + 470, ry - 10), ls=12)
# bus trunk -> rail -> banks
RY = bx - 90
trunk = bus[0] + 90
L([(trunk, bx), (trunk, RY)], both=True)
s.text(trunk + 14, RY + 36, 'slave bus × 6 banks:  <b>_sel · we · be[4] · addr[12] · wdata[32] →   ← <b>_rdata[32]', 14, 'Medium', LIME, 'start')
rx0, rx1 = i2c[0] + BW - 55, act[0] + BW - 55
s.line([(rx0, RY), (rx1, RY)], 'main', width=4)
for bxp, ytop in ((i2c[0] + BW - 55, i2c[1] + BH + 26), (sens[0] + BW - 55, sens[1] + BH + 26), (pid[0] + BW - 55, pid[1] + BH + 26), (act[0] + BW - 55, act[1] + BH + 26),
                  (tim[0] + 285, tim[1] + BH + 26), (saf[0] + 285, saf[1] + BH + 26)):
    s.arrow([(bxp, RY), (bxp, ytop)], 'main', both=True)
s.line([(trunk, RY), (rx0, RY)], 'main', width=4)
# ---------------------------------------------------------------- board side (left, right) and FPGA-only parts
LX = 60
def ext(x, y, w, h, t, sub, dash=True):
    s.box(x, y, w, h, t, sub, 'ext', ts=18, ss=14)
ext(LX, T + 20, 220, 150, 'MPU-6050', 'GY-521\nI²C 0x68\n3.3 V', True)
ext(LX, M + 20, 220, 130, 'oscillator', '100 MHz board\nclock', True)
ext(LX, M + 190, 220, 110, 'reset button', 'async, bounces', True)
ext(LX, Bt - 110, 220, 90, 'E-stop (active-low)', '', True)
ext(LX, Bt - 10, 220, 90, 'arm switch', 'bring-up only', True)
ext(LX, Bt + 90, 220, 120, 'bench switches', 'bench_en · bench_sel[1:0]\nbring-up only', True)
# FPGA-only boxes
def fpga(x, y, w, h, t, sub):
    s.items.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="#14171a" stroke="{MUTED}" stroke-width="2" stroke-dasharray="9 6"/>')
    s.text(x + w / 2, y + 36, t, 18, 'Medium', TEXT, 'middle')
    for i, l in enumerate(sub.split('\n')): s.text(x + w / 2, y + 62 + 20 * i, l, 14, 'Regular', MUTED, 'middle')
    s.text(x + w / 2, y + h - 10, 'FPGA-ONLY', 12, 'Medium', '#7a828a', 'middle', 1)
fpga(300, T + 20, 190, 150, 'open-drain pads', 'pad = low ? 0 : Z\nscl_pad · sda_pad\npull-ups to 3.3 V')
fpga(300, M + 20, 190, 130, 'fpga_clk_gen', 'MMCM 100 → 50 MHz\n+ pll_locked')
L([(280, T + 70), (300, T + 70)], both=True); L([(280, T + 120), (300, T + 120)], both=True)
L([(490, T + 70), (i2c[0], T + 70)], lab='scl_i · sda_i', lp=(510 + 20, T + 56), ls=11)
L([(i2c[0], T + 125), (490, T + 125)], lab='scl/sda_drive_low_o', lp=(560, T + 140), ls=11)
L([(280, M + 80), (300, M + 80)])
L([(490, M + 60), (clk[0], M + 60)], lab='clk_in', lp=(540, M + 48), ls=11); L([(490, M + 100), (clk[0], M + 100)], lab='pll_locked_i', lp=(560, M + 114), ls=11)
L([(280, M + 245), (clk[0] - 60, M + 245), (clk[0] - 60, M + 140), (clk[0], M + 140)], lab='rst_n_in', lp=(350, M + 233), ls=11)
# clk_rst_gen outputs note
s.text(clk[0] + 18, M + 150, 'clk, rst_n → the other 10 blocks', 15, 'Medium', LIME, 'start'); s.text(clk[0] + 18, M + 172, '(Ibex rst_ni too)', 14, 'Regular', MUTED, 'start')
# board inputs lanes along y 1060..1100 to safety / act
ly1, ly2, ly3 = Bt - 60, Bt - 40, Bt - 20
L([(280, Bt - 65), (saf[0] + 40, Bt - 65), (saf[0] + 40, M + BH)], lab='estop_n_i  (raw → synchronised inside safety)', lp=(cx(clk, 0) + 560, Bt - 77), ls=12)
L([(280, Bt + 35), (312, Bt + 35), (312, Bt - 38), (saf[0] + 80, Bt - 38), (saf[0] + 80, M + BH)], lab='arm_sw_i  (raw, bring-up)', lp=(cx(clk, 0) + 700, Bt - 50), ls=12, dash=True)
L([(280, Bt + 150), (332, Bt + 150), (332, Bt - 14), (act[0] + 250, Bt - 14), (act[0] + 250, T + BH)], lab='bench_en_i · bench_sel_i[2]  (raw, synchronised inside actuation; bring-up)', lp=(act[0] - 250, Bt - 26), ls=12, dash=True)
# right side: motor drivers, LEDs
RXs = act[0] + BW + 120
s.box(RXs, T - 10, 420, 120, 'BTS7960 left', 'l_rpwm_o · l_lpwm_o · l_r_en_o · l_l_en_o', 'ext', ts=22, ss=15)
s.box(RXs, T + 130, 420, 120, 'BTS7960 right', 'r_rpwm_o · r_lpwm_o · r_r_en_o · r_l_en_o', 'ext', ts=22, ss=15)
L([(act[0] + BW, T + 40), (RXs, T + 40)], lab='4 pins', lp=(act[0] + BW + 70, T + 28), ls=12); L([(act[0] + BW, T + 180), (RXs, T + 180)], lab='4 pins', lp=(act[0] + BW + 70, T + 168), ls=12)
s.box(RXs + 460, T - 10, 260, 260, 'DC motors', 'left · right\n\nmotor battery\n(separate supply,\ncommon ground)', 'ext', ts=22, ss=15)
L([(RXs + 420, T + 50), (RXs + 460, T + 50)]); L([(RXs + 420, T + 190), (RXs + 460, T + 190)])
s.box(RXs, M + 60, 420, 120, 'LEDs / debug pins', 'dbg_o[7:0]  (FPGA/bring-up)', 'ext', ts=22, ss=15)
L([(saf[0] + 340, M + 120), (RXs, M + 120)], dash=True, st='ctl', lab='dbg_o[7:0]', lp=(saf[0] + 640, M + 108), ls=13)
# debug taps
s.text(act[0] + 20, M + 160, 'DEBUG TAPS (ILA probes; open in the ASIC)', 16, 'Medium', MUTED, 'start')
for i, t in enumerate(['duty_l_o[16] · duty_r_o[16]  (actuation)', 'core_sleep_o · double_fault_seen_o  (cpu_subsystem)']): s.text(act[0] + 20, M + 188 + 24 * i, t, 15, 'Regular', MUTED, 'start')
# software layer
s.items.append(f'<rect x="{cpu[0]-0}" y="{ram[1]+BH+70}" width="{rom[0]+rom[2]-cpu[0]}" height="150" rx="8" fill="#14171a" stroke="{MUTED}" stroke-width="1.8" stroke-dasharray="9 6"/>')
s.text(cpu[0] + 18, ram[1] + BH + 104, 'FIRMWARE (software, stored in ROM)', 18, 'Medium', LIME, 'start', 1)
s.text(cpu[0] + 18, ram[1] + BH + 134, 'startup.S (vectors 0x00–0x7F, reset 0x80) · link.ld · ecu_regs.h · main.c (boot tests, application, ISRs)  →  firmware.hex  →  ROM', 16, 'Regular', TEXT, 'start')
s.text(cpu[0] + 18, ram[1] + BH + 162, 'jobs: read IDs · configure TMR/I2C/SENS/PID/PWM/SAFE · calibrate · arm · kick watchdog · telemetry · handle irq_timer / irq_fault', 15, 'Regular', MUTED, 'start')
# legend
lx, ly = IX1 - 640, ram[1] + 20
s.text(lx, ly, 'LEGEND', 16, 'Medium', LIME, 'start', 2)
s.arrow([(lx, ly + 28), (lx + 70, ly + 28)], 'main'); s.text(lx + 84, ly + 34, 'signal / pulse / data net (1 driver → loads)', 14, 'Regular', TEXT, 'start')
s.arrow([(lx, ly + 58), (lx + 70, ly + 58)], 'main', dash=True); s.text(lx + 84, ly + 64, 'bring-up / debug only', 14, 'Regular', TEXT, 'start')
s.items.append(f'<rect x="{lx}" y="{ly+78}" width="70" height="22" rx="4" fill="#1d2418" stroke="{LIME}" stroke-width="1.8"/>'); s.text(lx + 84, ly + 94, '▼ bank tab: slave bus to bus_interconnect', 14, 'Regular', TEXT, 'start')
s.text(lx, ly + 126, 'clk · rst_n tag on every block = from clk_rst_gen', 14, 'Regular', MUTED, 'start')
s.save(os.path.join(OUT, 'soc_ecu_soc_top.svg'))
print('soc ok')
