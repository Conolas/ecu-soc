"""
ecu_soc_top  -  SINGLE SOURCE OF TRUTH for the architecture (v1.1).
Everything else (netlist, Verilog skeleton, register header, diagrams, documents) is GENERATED from this file
and checked by arch_check.py.  Edit here, regenerate, re-check.  Do not edit generated files by hand.
Port naming rule (contract s.3): inputs end _i, outputs end _o; exceptions: clk, rst_n.
"""
CLK_MHZ = 50
# ------------------------------------------------------------------ helpers
def P(name, d, w, fmt, desc, tag=''):
    """port: d = 'in'|'out'; tag '' | 'dbg' (debug tap, FPGA/bring-up only) | 'bringup' | 'fpga'"""
    return dict(name=name, dir=d, width=w, fmt=fmt, desc=desc, tag=tag)

def SLAVE(addr_w=12, we=True, be=True):
    L = [P('s_sel_i', 'in', 1, 'pulse', 'access this cycle (exactly one cycle per access)')]
    if we: L.append(P('s_we_i', 'in', 1, 'level', '1 = write, 0 = read'))
    if be: L.append(P('s_be_i', 'in', 4, 'mask', 'byte enables (register banks may ignore; RAM must honour)'))
    L += [P('s_addr_i', 'in', addr_w, 'byte offset', 'byte offset inside the region; word aligned, use [%d:2]' % (addr_w - 1)),
          P('s_wdata_i', 'in', 32, 'word', 'write data')]
    return L
def SRDATA(): return [P('s_rdata_o', 'out', 32, 'word', 'read data, REGISTERED: valid the cycle after s_sel_i')]
CKRS = [P('clk', 'in', 1, 'clock', '50 MHz system clock'), P('rst_n', 'in', 1, 'level', 'active-low reset, synchronous release')]

# ------------------------------------------------------------------ register banks (from the owner sheets; Q16.16 unless noted)
def R(off, name, acc, rst, desc): return dict(off=off, name=name, acc=acc, reset=rst, desc=desc)
REGS = {
 'TMR': dict(base=0x10000000, id=0x54494D01, block='timer_unit', regs=[
  R(0x00,'ID','RO','0x54494D01','"TIM" + version 01'),
  R(0x04,'CTRL','RW','b0=DEF_EN','b0 EN (ticks run); b1 IRQ_EN; b2 CNT_CLR (SC) restart counters'),
  R(0x08,'TICK_PERIOD','RW','97656','clk cycles per tick (min 1000); new value applies at next reload'),
  R(0x0C,'IRQ_DIV','RW','51','ticks per timer interrupt (about 10 Hz)'),
  R(0x10,'STATUS','RO/W1C','0','b0 IRQ_PENDING (W1C); b1 OVERRUN (W1C)'),
  R(0x14,'TICK_COUNT','RO','0','ticks since enable'),
  R(0x18,'FREE_CNT','RO','0','free-running clk counter (timestamp)')]),
 'I2C': dict(base=0x10001000, id=0x49324301, block='i2c_sensor_subsystem', regs=[
  R(0x00,'ID','RO','0x49324301','"I2C" + version 01'),
  R(0x04,'CTRL','RW','b0=DEF_EN','b0 EN; b1 REINIT (SC); b2 SOFT_TRIG (SC)'),
  R(0x08,'CLK_DIV','RW','31','f_scl = f_clk / (4*(CLK_DIV+1)) = 390.6 kHz'),
  R(0x0C,'STATUS','RO/W1C','0','b0 INIT_DONE; b1 BUSY; b2 ERR_STICKY (W1C); b3 TIMEOUT_STICKY (W1C)'),
  R(0x10,'ERR_COUNT','RO','0','saturating count of failed transactions'),
  R(0x14,'SAMPLE_COUNT','RO','0','good samples since reset'),
  R(0x18,'DEV_ADDR','RW','0x68','7-bit device address'),
  R(0x20,'AX','RO','0','raw, sign-extended'), R(0x24,'AY','RO','0','raw'), R(0x28,'AZ','RO','0','raw'),
  R(0x2C,'GX','RO','0','raw'), R(0x30,'GY','RO','0','raw'), R(0x34,'GZ','RO','0','raw')]),
 'SENS': dict(base=0x10002000, id=0x53454E01, block='sensor_pipeline', regs=[
  R(0x00,'ID','RO','0x53454E01','"SEN" + version 01'),
  R(0x04,'CTRL','RW','0','b0 CAL_START (SC); b1 AXIS_SEL; b2 INV_ANGLE; b3 INV_RATE; b4 FILT_MODE (1 = complementary)'),
  R(0x08,'FILT_SHIFT','RW','0x22','[2:0] angle log2 N (0-4); [6:4] rate log2 N'),
  R(0x0C,'ANGLE_TRIM','RW','0','Q16.16, subtracted from the filtered angle'),
  R(0x10,'STATUS','RO','0','b0 CAL_BUSY; b1 CAL_DONE; b2 DATA_FRESH (a sample arrived within the last 2 ticks)'),
  R(0x14,'GYRO_BIAS_X','RO','0','signed'), R(0x18,'GYRO_BIAS_Y','RO','0','signed'), R(0x1C,'GYRO_BIAS_Z','RO','0','signed'),
  R(0x20,'ANGLE_RAW','RO','0','after conversion, before filter'), R(0x24,'ANGLE_FILT','RO','0','after filter and trim'),
  R(0x28,'RATE_FILT','RO','0','filtered rate'), R(0x2C,'ERROR','RO','0','setpoint - angle'), R(0x30,'SEQ_COUNT','RO','0','samples processed')]),
 'PID': dict(base=0x10003000, id=0x50494401, block='hw_pid_accel', regs=[
  R(0x00,'ID','RO','0x50494401','"PID" + version 01'),
  R(0x04,'CTRL','RW','b0=DEF_EN, b2=1','b0 EN; b1 CLR_INT (SC); b2 D_SRC (1 = D from gyro rate)'),
  R(0x08,'KP','RW','DEF_KP','Q16.16'), R(0x0C,'KI','RW','DEF_KI','Q16.16, pre-multiplied by Ts (Ki*Ts)'),
  R(0x10,'KD','RW','DEF_KD','Q16.16 (rad/s when D_SRC=1)'), R(0x14,'SETPOINT','RW','DEF_SETPOINT','Q16.16 rad'),
  R(0x18,'INT_LIMIT','RW','19661','max |integrator| (0.3)'), R(0x1C,'OUT_LIMIT','RW','DEF_OUT_LIMIT (16384)','output clamp, max 65536'),
  R(0x20,'STATUS','RO/W1C','0','b0 SAT (live); b1 SAT_STICKY (W1C); b2 ACTIVE'),
  R(0x24,'P_TERM','RO','0','last P term'), R(0x28,'I_TERM','RO','0','integrator'), R(0x2C,'D_TERM','RO','0','last D term'), R(0x30,'U_OUT','RO','0','last output')]),
 'PWM': dict(base=0x10004000, id=0x50574D01, block='actuation_subsystem', regs=[
  R(0x00,'ID','RO','0x50574D01','"PWM" + version 01'),
  R(0x04,'CTRL','RW','b0=DEF_EN, b4=1','b0 EN; b1 SLEW_EN; b2 DIR_INV_L; b3 DIR_INV_R; b4 CLAMP_EN'),
  R(0x08,'PERIOD','RW','2500','PWM period in clk cycles (20 kHz); applies at the period wrap'),
  R(0x0C,'MAX_DUTY','RW','0xE666','Q0.16 max duty (0.9)'), R(0x10,'DEADTIME','RW','250','clk cycles, both outputs low on reversal (5 us)'),
  R(0x14,'SLEW_STEP','RW','6554','max command change per update, Q16.16 (0.1)'), R(0x18,'STEER','RW','0','Q16.16: left = cmd + steer, right = cmd - steer'),
  R(0x1C,'GAIN_L','RW','65536','Q16.16 left gain'), R(0x20,'GAIN_R','RW','65536','Q16.16 right gain'),
  R(0x24,'STATUS','RO','0','b0 ENABLED; b1 CLAMPED (sticky, W1C); b2 IN_DEADTIME_L; b3 IN_DEADTIME_R'),
  R(0x28,'DUTY_L','RO','0','current duty counts'), R(0x2C,'DUTY_R','RO','0','current duty counts')]),
 'SAFE': dict(base=0x10005000, id=0x53414601, block='safety_fault_monitor', regs=[
  R(0x00,'ID','RO','0x53414601','"SAF" + version 01'),
  R(0x04,'CTRL','RW','0x04 | DEF_WD_EN<<1 | DEF_EN','b0 ARM; b1 WD_EN; b2 TILT_EN (reset 1); b3 FAULT_CLR (SC); b4 IRQ_EN'),
  R(0x08,'WD_KICK','WO','-','any write restarts the watchdog'),
  R(0x0C,'TILT_LIMIT','RW','39322','Q16.16 rad (0.6), compared with |angle|'), R(0x10,'SENSOR_TIMEOUT','RW','8','control ticks without imu_valid'),
  R(0x14,'SAT_LIMIT','RW','256','consecutive saturated samples'), R(0x18,'WD_TIMEOUT','RW','100','ticks (195 ms) without a kick'),
  R(0x1C,'FAULT_STATUS','RO','0','sticky: b0 TILT, b1 SENSOR_TIMEOUT, b2 I2C_ERR, b3 PID_SAT, b4 WATCHDOG, b5 ESTOP'),
  R(0x20,'FAULT_LIVE','RO','0','same bits, live'), R(0x24,'STATE','RO','0','0 DISARMED, 1 ARMED, 2 FAULT'),
  R(0x28,'DBG_OUT','RW','0','firmware LED bits -> dbg_o[7:4]')]),
}
BANKS = ['tmr', 'i2c', 'sens', 'pid', 'pwm', 'saf']
BANK_BLOCK = dict(tmr='timer_unit', i2c='i2c_sensor_subsystem', sens='sensor_pipeline', pid='hw_pid_accel', pwm='actuation_subsystem', saf='safety_fault_monitor')
BANK_REGKEY = dict(tmr='TMR', i2c='I2C', sens='SENS', pid='PID', pwm='PWM', saf='SAFE')
MEMMAP = [('ROM', 0x00000000, 0x2000, 'rom_dp', '8 KB, firmware (read-only)')] + \
         [(k, v['base'], 0x1000, v['block'], 'register bank') for k, v in REGS.items()] + \
         [('RAM', 0x20000000, 0x1000, 'ram_sp', '4 KB, data + stack')]

# ------------------------------------------------------------------ blocks (ports are exactly the frozen ones; ACR = architecture change request, see ACRS)
IMU = ['ax', 'ay', 'az', 'gx', 'gy', 'gz']
BL = {}
def block(name, **kw): BL[name] = dict(name=name, **kw)

block('clk_rst_gen', kind='rtl', owner='Vedam', lang='Verilog-2001', ports=[
  P('clk_in','in',1,'clock','board clock, already 50 MHz'), P('rst_n_in','in',1,'level','external reset button, active-low, ASYNC, may bounce'),
  P('pll_locked_i','in',1,'level','clock-generator lock (tie 1 if none)', 'fpga'),
  P('clk','out',1,'clock','= clk_in'), P('rst_n','out',1,'level','active-low; asserted asynchronously, released synchronously')])
block('timer_unit', kind='rtl', owner='Dipiksha', lang='Verilog-2001', params=['DEF_EN=0','TICK_PERIOD_DEF=97656','IRQ_DIV_DEF=51'],
  ports=CKRS + SLAVE() + SRDATA() + [P('sched_busy_i','in',1,'level','imu_busy: still reading when the next tick fires => overrun'),
  P('control_tick_o','out',1,'pulse','one clk cycle every TICK_PERIOD cycles (about 512 Hz)'), P('irq_timer_o','out',1,'level','set every IRQ_DIV ticks; cleared by W1C')])
block('i2c_sensor_subsystem', kind='rtl', owner='Kaushal', lang='Verilog-2001', params=['DEF_EN=0','CLK_DIV_DEF=31',"DEV_ADDR_DEF=7'h68"],
  ports=CKRS + SLAVE() + SRDATA() + [P('control_tick_i','in',1,'pulse','start a sample read'),
  P('scl_i','in',1,'level','raw SCL pin (2-FF synchronised inside)'), P('sda_i','in',1,'level','raw SDA pin (2-FF synchronised inside)'),
  P('scl_drive_low_o','out',1,'level','1 = pull SCL low, 0 = release (open-drain)'), P('sda_drive_low_o','out',1,'level','1 = pull SDA low, 0 = release'),
  P('imu_valid_o','out',1,'pulse','complete 14-byte sample ready')] +
  [P('imu_%s_o' % a,'out',16,'int16','signed raw %s, stable after imu_valid_o' % a) for a in IMU] +
  [P('imu_busy_o','out',1,'level','high from tick until imu_valid_o or imu_err_o'), P('imu_err_o','out',1,'pulse','transaction failed (NACK / timeout)'),
   P('imu_init_done_o','out',1,'level','MPU-6050 configured')])
block('sensor_pipeline', kind='rtl', owner='Dipiksha', lang='Verilog-2001', params=['DEF_EN=0'],
  ports=CKRS + SLAVE() + SRDATA() + [P('control_tick_i','in',1,'pulse','ACR-2: time base for DATA_FRESH (sample within last 2 ticks)'),
  P('imu_valid_i','in',1,'pulse','sample ready')] + [P('imu_%s_i' % a,'in',16,'int16','signed raw %s' % a) for a in IMU] +
  [P('imu_init_done_i','in',1,'level','calibration waits for this'), P('setpoint_i','in',32,'Q16.16 rad','balance setpoint from PID bank'),
   P('pipe_valid_o','out',1,'pulse','angle_o, err_o, rate_o valid together'), P('angle_o','out',32,'Q16.16 rad','filtered + trimmed; + = leaning forward'),
   P('err_o','out',32,'Q16.16','setpoint_i - angle'), P('rate_o','out',32,'Q16.16 rad/s','filtered, bias-corrected'), P('calib_done_o','out',1,'level','gyro bias captured')])
block('hw_pid_accel', kind='rtl', owner='Conolas', lang='Verilog-2001', params=['DEF_EN=0','DEF_KP=0','DEF_KI=0','DEF_KD=0','DEF_SETPOINT=0','DEF_OUT_LIMIT=16384'],
  ports=CKRS + SLAVE() + SRDATA() + [P('err_valid_i','in',1,'pulse','pipe_valid'), P('err_i','in',32,'Q16.16','setpoint - angle'), P('rate_i','in',32,'Q16.16 rad/s','filtered rate'),
  P('run_i','in',1,'level','pwm_enable: 0 => output 0, integrator cleared'), P('pwm_cmd_o','out',32,'Q16.16 [-1,+1]','clamped to +-OUT_LIMIT'),
  P('pwm_cmd_valid_o','out',1,'pulse','new command (also pulses with 0 when not running)'), P('pid_sat_o','out',1,'level','last output was clamped'),
  P('setpoint_o','out',32,'Q16.16 rad','SETPOINT register -> sensor_pipeline')])
block('actuation_subsystem', kind='rtl', owner='Jaydev', lang='Verilog-2001', params=['DEF_EN=0','PERIOD_DEF=2500','DEADTIME_DEF=250'],
  ports=CKRS + SLAVE() + SRDATA() + [P('cmd_valid_i','in',1,'pulse','new command (about 512 Hz)'), P('cmd_i','in',32,'Q16.16 [-1,+1]','balance command from PID'),
  P('pwm_enable_i','in',1,'level','from safety: 0 => everything off'), P('bench_en_i','in',1,'level','1 = ignore cmd_i, use bench table','bringup'),
  P('bench_sel_i','in',2,'code','00 -> 0, 01 -> +0.25, 10 -> -0.25, 11 -> +0.5','bringup')] +
  [P('%s_%s_o' % (s, n),'out',1,'level','%s BTS7960 %s' % ({'l':'left','r':'right'}[s], n.upper())) for s in 'lr' for n in ('rpwm','lpwm','r_en','l_en')] +
  [P('duty_l_o','out',16,'counts','current left duty counts (debug)','dbg'), P('duty_r_o','out',16,'counts','current right duty counts (debug)','dbg')])
block('safety_fault_monitor', kind='rtl', owner='Vedam', lang='Verilog-2001', params=['DEF_EN=0','DEF_WD_EN=0'],
  ports=CKRS + SLAVE() + SRDATA() + [P('control_tick_i','in',1,'pulse','time base for time-outs and watchdog'), P('imu_valid_i','in',1,'pulse','sample received'),
  P('imu_err_i','in',1,'pulse','I2C transaction failed'), P('imu_init_done_i','in',1,'level','sensor configured'), P('calib_done_i','in',1,'level','gyro bias captured'),
  P('pipe_valid_i','in',1,'pulse','angle_i valid'), P('angle_i','in',32,'Q16.16 rad','filtered angle'), P('pid_sat_i','in',1,'level','PID output clamped'),
  P('estop_n_i','in',1,'level','hardware E-stop, active-low, raw (synchronised inside)'), P('arm_sw_i','in',1,'level','arm switch, raw (synchronised inside); tie 0 in final SoC','bringup'),
  P('pwm_enable_o','out',1,'level','1 = motors allowed; default 0; registered'), P('irq_fault_o','out',1,'level','IRQ_EN & any sticky fault'),
  P('dbg_o','out',8,'LED bits','[3:0]={calib_done,init_done,fault_any,pwm_enable}, [7:4]=DBG_OUT[7:4]','dbg')])
block('rom_dp', kind='rtl', owner='Vedam', lang='Verilog-2001', params=['ROM_WORDS=2048','INIT_FILE="firmware.hex"'], ports=[
  P('clk','in',1,'clock','50 MHz'), P('ia_req_i','in',1,'pulse','instruction fetch request'), P('ia_addr_i','in',13,'byte addr','use [12:2] as word index'),
  P('ia_rdata_o','out',32,'word','registered: valid the cycle after ia_req_i'), P('s_sel_i','in',1,'pulse','data-side read request'),
  P('s_addr_i','in',13,'byte addr','data-side address'), P('s_rdata_o','out',32,'word','registered')])
block('ram_sp', kind='rtl', owner='Vedam', lang='Verilog-2001', params=['RAM_WORDS=1024'], ports=[P('clk','in',1,'clock','50 MHz')] + SLAVE() + SRDATA())
block('bus_interconnect', kind='rtl', owner='Vedam', lang='Verilog-2001', params=['ROM_BASE','ROM_MASK','RAM_BASE','BANK_BASE (localparams)'], ports=CKRS + [
  P('instr_req_i','in',1,'level','from Ibex'), P('instr_addr_i','in',32,'byte addr','from Ibex'),
  P('instr_gnt_o','out',1,'level','= instr_req_i (same cycle)'), P('instr_rvalid_o','out',1,'pulse','one cycle after the request'),
  P('instr_rdata_o','out',32,'word','ROM word'), P('instr_err_o','out',1,'level','fetch outside ROM'),
  P('data_req_i','in',1,'level','from Ibex'), P('data_we_i','in',1,'level','1 = store'), P('data_be_i','in',4,'mask','byte enables'),
  P('data_addr_i','in',32,'byte addr','from Ibex'), P('data_wdata_i','in',32,'word','from Ibex'),
  P('data_gnt_o','out',1,'level','= data_req_i (same cycle)'), P('data_rvalid_o','out',1,'pulse','one cycle later, reads AND writes'),
  P('data_rdata_o','out',32,'word','registered read mux'), P('data_err_o','out',1,'level','unmapped address or write to ROM'),
  P('rom_ia_req_o','out',1,'pulse','ROM instruction port request'), P('rom_ia_addr_o','out',13,'byte addr','ROM instruction address'), P('rom_ia_rdata_i','in',32,'word','ROM instruction data'),
  P('rom_sel_o','out',1,'pulse','ROM data-read select'), P('rom_addr_o','out',13,'byte addr','ROM data address'), P('rom_rdata_i','in',32,'word','ROM data'),
  P('ram_sel_o','out',1,'pulse','RAM select'), P('ram_we_o','out',1,'level','RAM write'), P('ram_be_o','out',4,'mask','RAM byte enables'),
  P('ram_addr_o','out',12,'byte offset','RAM address'), P('ram_wdata_o','out',32,'word','RAM write data'), P('ram_rdata_i','in',32,'word','RAM read data')] +
  [P('%s_%s' % (b, s), d, w, f, '%s bank slave bus' % b.upper()) for b in BANKS for s, d, w, f in
   [('sel_o','out',1,'pulse'), ('we_o','out',1,'level'), ('be_o','out',4,'mask'), ('addr_o','out',12,'byte offset'), ('wdata_o','out',32,'word'), ('rdata_i','in',32,'word')]])
block('cpu_subsystem', kind='rtl', owner='Conolas', lang='SystemVerilog (Ibex)', params=["BOOT_ADDR=32'h0000_0000"], ports=CKRS + [
  P('instr_req_o','out',1,'level','instruction request'), P('instr_gnt_i','in',1,'level','granted'), P('instr_rvalid_i','in',1,'pulse','response valid'),
  P('instr_addr_o','out',32,'byte addr','fetch address'), P('instr_rdata_i','in',32,'word','instruction'), P('instr_err_i','in',1,'level','bus error'),
  P('data_req_o','out',1,'level','data request'), P('data_gnt_i','in',1,'level','granted'), P('data_rvalid_i','in',1,'pulse','response valid'),
  P('data_we_o','out',1,'level','store'), P('data_be_o','out',4,'mask','byte enables'), P('data_addr_o','out',32,'byte addr','address'),
  P('data_wdata_o','out',32,'word','write data'), P('data_rdata_i','in',32,'word','read data'), P('data_err_i','in',1,'level','bus error'),
  P('irq_timer_i','in',1,'level','machine timer interrupt (mcause 7, vector 0x1C)'), P('irq_fault_i','in',1,'level','machine external interrupt (mcause 11, vector 0x2C)'),
  P('core_sleep_o','out',1,'level','high while the core sleeps (wfi)','dbg'), P('double_fault_seen_o','out',1,'level','exception inside an exception handler','dbg')])
block('ecu_soc_top', kind='top', owner='Conolas', lang='Verilog-2001', params=['HW_ONLY=0 (1 = Wing A runs without CPU; FPGA phase 1 only)'], ports=[])
block('ecu_fpga_top', kind='fpga', owner='Jaydev', lang='Verilog-2001 + FPGA primitives', params=['HW_ONLY (passed to ecu_soc_top)'], ports=[])

# ------------------------------------------------------------------ top-level pins of ecu_soc_top  (class: core | bringup | fpga)
TOP_PINS = [
 ('clk_in','in',1,'core','50 MHz clock (from the FPGA clock generator or the ASIC clock pad)'),
 ('rst_n_in','in',1,'core','external reset, active-low, async'),
 ('pll_locked_i','in',1,'fpga','clock-generator lock; tie 1 if none'),
 ('estop_n_i','in',1,'core','hardware E-stop, active-low'),
 ('arm_sw_i','in',1,'bringup','arm switch (phase 1 only; tie 0 in the final SoC)'),
 ('bench_en_i','in',1,'bringup','open-loop motor bench mode'),
 ('bench_sel_i','in',2,'bringup','bench command select'),
 ('scl_i','in',1,'core','I2C SCL input'), ('sda_i','in',1,'core','I2C SDA input'),
 ('scl_drive_low_o','out',1,'core','1 = pull SCL low'), ('sda_drive_low_o','out',1,'core','1 = pull SDA low'),
 ('l_rpwm_o','out',1,'core','left BTS7960 RPWM'), ('l_lpwm_o','out',1,'core','left BTS7960 LPWM'), ('l_r_en_o','out',1,'core','left R_EN'), ('l_l_en_o','out',1,'core','left L_EN'),
 ('r_rpwm_o','out',1,'core','right BTS7960 RPWM'), ('r_lpwm_o','out',1,'core','right BTS7960 LPWM'), ('r_r_en_o','out',1,'core','right R_EN'), ('r_l_en_o','out',1,'core','right L_EN'),
 ('dbg_o','out',8,'dbg','LEDs / debug pins')]

# ------------------------------------------------------------------ nets: the complete netlist of ecu_soc_top
NETS = []
def net(name, w, drv, loads, kind, fmt, note='', tag=''): NETS.append(dict(name=name, width=w, driver=drv, loads=loads, kind=kind, fmt=fmt, note=note, tag=tag))
ALLCLK = [b for b in BL if BL[b]['kind'] == 'rtl']
net('clk', 1, 'clk_rst_gen.clk', [b + '.clk' for b in ALLCLK if any(p['name'] == 'clk' and p['dir'] == 'in' for p in BL[b]['ports'])], 'clock', 'clock', 'one 50 MHz clock for everything, including Ibex')
net('rst_n', 1, 'clk_rst_gen.rst_n', [b + '.rst_n' for b in ALLCLK if any(p['name'] == 'rst_n' and p['dir'] == 'in' for p in BL[b]['ports'])], 'level', 'level', 'async assert, sync release')
net('clk_in', 1, 'TOP.clk_in', ['clk_rst_gen.clk_in'], 'clock', 'clock', 'board clock'); net('rst_n_in', 1, 'TOP.rst_n_in', ['clk_rst_gen.rst_n_in'], 'level', 'level', 'external reset')
net('pll_locked_i', 1, 'TOP.pll_locked_i', ['clk_rst_gen.pll_locked_i'], 'level', 'level', 'FPGA clock generator lock', 'fpga')
net('control_tick', 1, 'timer_unit.control_tick_o', ['i2c_sensor_subsystem.control_tick_i', 'sensor_pipeline.control_tick_i', 'safety_fault_monitor.control_tick_i'], 'pulse', 'pulse', 'about 512 Hz sample trigger; sensor_pipeline input added by ACR-2')
net('imu_valid', 1, 'i2c_sensor_subsystem.imu_valid_o', ['sensor_pipeline.imu_valid_i', 'safety_fault_monitor.imu_valid_i'], 'pulse', 'pulse', 'a full 14-byte sample was read')
for a in IMU:
    net('imu_' + a, 16, 'i2c_sensor_subsystem.imu_%s_o' % a, ['sensor_pipeline.imu_%s_i' % a], 'data', 'int16', 'raw IMU value')
net('imu_busy', 1, 'i2c_sensor_subsystem.imu_busy_o', ['timer_unit.sched_busy_i'], 'level', 'level', 'overrun detection')
net('imu_err', 1, 'i2c_sensor_subsystem.imu_err_o', ['safety_fault_monitor.imu_err_i'], 'pulse', 'pulse', 'failed transaction')
net('imu_init_done', 1, 'i2c_sensor_subsystem.imu_init_done_o', ['sensor_pipeline.imu_init_done_i', 'safety_fault_monitor.imu_init_done_i'], 'level', 'level', 'MPU-6050 configured')
net('setpoint', 32, 'hw_pid_accel.setpoint_o', ['sensor_pipeline.setpoint_i'], 'data', 'Q16.16 rad', 'from the PID SETPOINT register')
net('pipe_valid', 1, 'sensor_pipeline.pipe_valid_o', ['hw_pid_accel.err_valid_i', 'safety_fault_monitor.pipe_valid_i'], 'pulse', 'pulse', 'angle, err, rate valid together')
net('angle', 32, 'sensor_pipeline.angle_o', ['safety_fault_monitor.angle_i'], 'data', 'Q16.16 rad', 'filtered, trimmed')
net('err', 32, 'sensor_pipeline.err_o', ['hw_pid_accel.err_i'], 'data', 'Q16.16', 'setpoint - angle')
net('rate', 32, 'sensor_pipeline.rate_o', ['hw_pid_accel.rate_i'], 'data', 'Q16.16 rad/s', 'filtered, bias-corrected')
net('calib_done', 1, 'sensor_pipeline.calib_done_o', ['safety_fault_monitor.calib_done_i'], 'level', 'level', 'arming precondition')
net('pwm_cmd_valid', 1, 'hw_pid_accel.pwm_cmd_valid_o', ['actuation_subsystem.cmd_valid_i'], 'pulse', 'pulse', 'new motor command')
net('pwm_cmd', 32, 'hw_pid_accel.pwm_cmd_o', ['actuation_subsystem.cmd_i'], 'data', 'Q16.16 [-1,+1]', 'balance command')
net('pid_sat', 1, 'hw_pid_accel.pid_sat_o', ['safety_fault_monitor.pid_sat_i'], 'level', 'level', 'saturation monitor')
net('pwm_enable', 1, 'safety_fault_monitor.pwm_enable_o', ['hw_pid_accel.run_i', 'actuation_subsystem.pwm_enable_i'], 'level', 'level', 'motors allowed (the only authority over the motors)')
net('irq_timer', 1, 'timer_unit.irq_timer_o', ['cpu_subsystem.irq_timer_i'], 'level', 'level', 'housekeeping interrupt, W1C in TMR')
net('irq_fault', 1, 'safety_fault_monitor.irq_fault_o', ['cpu_subsystem.irq_fault_i'], 'level', 'level', 'fault interrupt, cleared through SAFE regs')
# top-level pin nets
net('estop_n_i', 1, 'TOP.estop_n_i', ['safety_fault_monitor.estop_n_i'], 'level', 'level', 'raw pin; synchronised inside safety (ACR-1)')
net('arm_sw_i', 1, 'TOP.arm_sw_i', ['safety_fault_monitor.arm_sw_i'], 'level', 'level', 'raw pin; synchronised inside safety (ACR-1)', 'bringup')
net('bench_en_i', 1, 'TOP.bench_en_i', ['actuation_subsystem.bench_en_i'], 'level', 'level', 'raw pin; synchronised inside actuation (ACR-1)', 'bringup')
net('bench_sel_i', 2, 'TOP.bench_sel_i', ['actuation_subsystem.bench_sel_i'], 'data', 'code', 'raw pins; synchronised inside actuation (ACR-1)', 'bringup')
net('scl_i', 1, 'TOP.scl_i', ['i2c_sensor_subsystem.scl_i'], 'level', 'level', 'raw; 2-FF inside i2c'); net('sda_i', 1, 'TOP.sda_i', ['i2c_sensor_subsystem.sda_i'], 'level', 'level', 'raw; 2-FF inside i2c')
net('scl_drive_low_o', 1, 'i2c_sensor_subsystem.scl_drive_low_o', ['TOP.scl_drive_low_o'], 'level', 'level', 'open-drain drive'); net('sda_drive_low_o', 1, 'i2c_sensor_subsystem.sda_drive_low_o', ['TOP.sda_drive_low_o'], 'level', 'level', 'open-drain drive')
for s in 'lr':
    for n in ('rpwm', 'lpwm', 'r_en', 'l_en'):
        net('%s_%s_o' % (s, n), 1, 'actuation_subsystem.%s_%s_o' % (s, n), ['TOP.%s_%s_o' % (s, n)], 'level', 'level', 'motor driver pin')
net('dbg_o', 8, 'safety_fault_monitor.dbg_o', ['TOP.dbg_o'], 'data', 'LED bits', 'LEDs / debug pins', 'dbg')
# debug taps (outputs with no functional load): kept as named nets for ILA probing on FPGA; unconnected in the ASIC
net('duty_l', 16, 'actuation_subsystem.duty_l_o', [], 'data', 'counts', 'debug tap: ILA probe', 'dbg'); net('duty_r', 16, 'actuation_subsystem.duty_r_o', [], 'data', 'counts', 'debug tap: ILA probe', 'dbg')
net('cpu_core_sleep', 1, 'cpu_subsystem.core_sleep_o', [], 'level', 'level', 'debug tap: ILA probe', 'dbg'); net('cpu_double_fault', 1, 'cpu_subsystem.double_fault_seen_o', [], 'level', 'level', 'debug tap: ILA probe', 'dbg')
# CPU <-> bus
for s, dn in (('instr', 'instr'), ('data', 'data')):
    pass
net('instr_req', 1, 'cpu_subsystem.instr_req_o', ['bus_interconnect.instr_req_i'], 'bus', 'level', 'Ibex instruction port'); net('instr_addr', 32, 'cpu_subsystem.instr_addr_o', ['bus_interconnect.instr_addr_i'], 'bus', 'byte addr', 'Ibex instruction port')
net('instr_gnt', 1, 'bus_interconnect.instr_gnt_o', ['cpu_subsystem.instr_gnt_i'], 'bus', 'level', 'grant = request, same cycle'); net('instr_rvalid', 1, 'bus_interconnect.instr_rvalid_o', ['cpu_subsystem.instr_rvalid_i'], 'bus', 'pulse', 'response, next cycle')
net('instr_rdata', 32, 'bus_interconnect.instr_rdata_o', ['cpu_subsystem.instr_rdata_i'], 'bus', 'word', 'instruction word'); net('instr_err', 1, 'bus_interconnect.instr_err_o', ['cpu_subsystem.instr_err_i'], 'bus', 'level', 'fetch error')
net('data_req', 1, 'cpu_subsystem.data_req_o', ['bus_interconnect.data_req_i'], 'bus', 'level', 'Ibex data port'); net('data_we', 1, 'cpu_subsystem.data_we_o', ['bus_interconnect.data_we_i'], 'bus', 'level', 'store')
net('data_be', 4, 'cpu_subsystem.data_be_o', ['bus_interconnect.data_be_i'], 'bus', 'mask', 'byte enables'); net('data_addr', 32, 'cpu_subsystem.data_addr_o', ['bus_interconnect.data_addr_i'], 'bus', 'byte addr', 'address')
net('data_wdata', 32, 'cpu_subsystem.data_wdata_o', ['bus_interconnect.data_wdata_i'], 'bus', 'word', 'write data')
net('data_gnt', 1, 'bus_interconnect.data_gnt_o', ['cpu_subsystem.data_gnt_i'], 'bus', 'level', 'grant'); net('data_rvalid', 1, 'bus_interconnect.data_rvalid_o', ['cpu_subsystem.data_rvalid_i'], 'bus', 'pulse', 'response')
net('data_rdata', 32, 'bus_interconnect.data_rdata_o', ['cpu_subsystem.data_rdata_i'], 'bus', 'word', 'read data'); net('data_err', 1, 'bus_interconnect.data_err_o', ['cpu_subsystem.data_err_i'], 'bus', 'level', 'bus error')
# bus <-> memories
net('rom_ia_req', 1, 'bus_interconnect.rom_ia_req_o', ['rom_dp.ia_req_i'], 'bus', 'pulse', ''); net('rom_ia_addr', 13, 'bus_interconnect.rom_ia_addr_o', ['rom_dp.ia_addr_i'], 'bus', 'byte addr', '')
net('rom_ia_rdata', 32, 'rom_dp.ia_rdata_o', ['bus_interconnect.rom_ia_rdata_i'], 'bus', 'word', '')
net('rom_sel', 1, 'bus_interconnect.rom_sel_o', ['rom_dp.s_sel_i'], 'bus', 'pulse', ''); net('rom_addr', 13, 'bus_interconnect.rom_addr_o', ['rom_dp.s_addr_i'], 'bus', 'byte addr', '')
net('rom_rdata', 32, 'rom_dp.s_rdata_o', ['bus_interconnect.rom_rdata_i'], 'bus', 'word', '')
for s, w, f in (('sel', 1, 'pulse'), ('we', 1, 'level'), ('be', 4, 'mask'), ('addr', 12, 'byte offset'), ('wdata', 32, 'word')):
    net('ram_' + s, w, 'bus_interconnect.ram_%s_o' % s, ['ram_sp.s_%s_i' % s], 'bus', f, '')
net('ram_rdata', 32, 'ram_sp.s_rdata_o', ['bus_interconnect.ram_rdata_i'], 'bus', 'word', '')
for b in BANKS:
    blk = BANK_BLOCK[b]
    for s, w, f in (('sel', 1, 'pulse'), ('we', 1, 'level'), ('be', 4, 'mask'), ('addr', 12, 'byte offset'), ('wdata', 32, 'word')):
        net('%s_%s' % (b, s), w, 'bus_interconnect.%s_%s_o' % (b, s), ['%s.s_%s_i' % (blk, s)], 'bus', f, '%s bank slave bus' % b.upper())
    net('%s_rdata' % b, 32, '%s.s_rdata_o' % blk, ['bus_interconnect.%s_rdata_i' % b], 'bus', 'word', '%s bank read data' % b.upper())

# ------------------------------------------------------------------ architecture change requests (v1.0 -> v1.1)
ACRS = [
 ('ACR-1','Input synchronisers live INSIDE ecu_soc_top','v1.0 had the board wrapper synchronise estop/arm/bench AND safety synchronise estop/arm again (double sync, wrong for the ASIC where there is no wrapper). Now: raw pins enter the SoC; safety_fault_monitor synchronises estop_n_i and arm_sw_i; actuation_subsystem synchronises bench_en_i and bench_sel_i (2-FF each); i2c already synchronises scl_i/sda_i; clk_rst_gen handles rst_n_in and pll_locked_i. ecu_fpga_top does NO synchronisation.','internal to safety and actuation; no port change; removes logic from the FPGA-only wrapper'),
 ('ACR-2','sensor_pipeline gets control_tick_i (1 bit)','The SENS STATUS bit DATA_FRESH ("a sample arrived in the last 2 ticks") needs a time base, but sensor_pipeline had no tick input. Add control_tick_i from timer_unit.','one new input port on sensor_pipeline; one more load on net control_tick'),
 ('ACR-3','SAFE.CTRL reset value made unambiguous','v1.0 said "reset 0" and "TILT_EN reset 1". Now: reset = 0x04 | (DEF_WD_EN<<1) | DEF_EN, i.e. TILT_EN=1, ARM=DEF_EN.','documentation only'),
 ('ACR-4','Debug taps declared','duty_l_o, duty_r_o (actuation), core_sleep_o, double_fault_seen_o (cpu) and dbg_o are debug/bring-up taps: they drive named nets with no functional load. FPGA: ILA probes / LEDs. ASIC: left unconnected (dbg_o may become spare pins).','no port change; classification only'),
 ('ACR-5','Reset-assertion rule for testbenches and Ibex','Ibex flops reset on the FALLING EDGE of rst_ni (asynchronous). Every testbench must start rst_n high and pull it low after time 0. Our blocks keep synchronous resets; only clk_rst_gen uses async assert.','verification rule'),
 ('ACR-7','imu_init_done_o is low during (re-)initialisation','The sheet did not say what imu_init_done_o does when the sequencer re-runs init after 3 consecutive errors. Now: it goes low when init starts and high when init completes. Arming needs calib_done_i, which is reachable only after init; imu_init_done_i is also shown on dbg_o[2].','behaviour clarification inside i2c_sensor_subsystem; no port change'),
 ('ACR-6','Ibex port list updated to the pinned commit af456e2','The v1.0 sheet listed an older Ibex port set. cpu_subsystem (starter kit, lint-clean) now ties every port; its external interface is unchanged.','internal to cpu_subsystem')]

# ------------------------------------------------------------------ FPGA-only / bring-up-only items (not in the GDSII)
FPGA_ONLY = [
 ('ecu_fpga_top (entire wrapper)','FPGA','board wrapper: pin buffers, clock generator, open-drain pad logic, LED drivers, constraints','replaced by the pad ring / ecu_asic_top'),
 ('fpga_clk_gen (MMCM/PLL)','FPGA','board oscillator (100 MHz on the Arty A7) -> exactly 50 MHz; produces pll_locked','external 50 MHz clock pad (or an ASIC PLL macro)'),
 ('pll_locked_i','FPGA/ASIC','lock status of the clock generator; holds reset','real PLL lock if a PLL macro is used, else tie 1'),
 ('IOBUF / tri-state for scl_pad, sda_pad','FPGA','assign pad = drive_low ? 1b0 : 1bz (open-drain)','library open-drain I/O pad cell'),
 ('arm_sw_i','bring-up','arm switch used when no CPU exists (phase 1)','tie 0; firmware arms through SAFE.CTRL'),
 ('bench_en_i, bench_sel_i[1:0]','bring-up','open-loop motor bench table in actuation_subsystem','tie 0 (logic is optimised away) or keep as test-mode pins'),
 ('HW_ONLY parameter and the DEF_EN plumbing','FPGA','phase-1 mode: Wing A runs with no CPU (blocks reset to enabled)','HW_ONLY = 0; DEF_EN constants removed or left at 0'),
 ('dbg_o[7:0] LEDs','FPGA/ASIC','status LEDs: fault, armed, calibrated','spare debug pins or removed'),
 ('duty_l_o, duty_r_o, core_sleep_o, double_fault_seen_o','FPGA','debug taps probed by the ILA','unconnected'),
 ('Vivado ILA / VIO cores and mark_debug attributes','FPGA','on-chip logic analyser','none'),
 ('$readmemh ROM initialisation (rom_dp INIT_FILE)','FPGA/sim','ROM contents loaded at configuration/simulation start','ROM macro or mask ROM; firmware.hex becomes the programming file'),
 ('BRAM inference for rom_dp / ram_sp','FPGA','block RAM','SRAM macros or flop arrays (area decision in the layout phase)'),
 ('prim_clock_gating pass-through','FPGA','Ibex clock gate replaced by a wire','library clock-gating cell, or keep the wire'),
 ('RegFile = RegFileFF / RegFileFPGA','FPGA','Ibex register file in flip-flops / distributed RAM','RegFileLatch (needs clock gating) or keep flip-flops'),
 ('test_en_i, scan_rst_ni on ibex_top','DFT','tied 0 / 1 in FPGA','scan chain connections in the layout flow'),
 ('rst_n_in button debounce by hold counter','FPGA/ASIC','the 255-cycle hold in clk_rst_gen','kept (power-on reset)')]
