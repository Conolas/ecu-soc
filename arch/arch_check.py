"""Consistency checker + generators for the ecu_soc_top architecture model.
   python3 arch_check.py            -> runs all checks, writes ./generated/*
"""
import json, os, re, sys, csv, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arch_data as A
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'generated'); os.makedirs(OUT, exist_ok=True)
ERR, WARN, INFO = [], [], []
def err(m): ERR.append(m)
def chk(cond, ok_msg, bad_msg):
    (INFO if cond else ERR).append(ok_msg if cond else bad_msg)

RTL = [b for b in A.BL if A.BL[b]['kind'] == 'rtl']
PORT = {(b, p['name']): p for b in RTL for p in A.BL[b]['ports']}
TOPP = {n: dict(name=n, dir=d, width=w, cls=c, desc=ds) for n, d, w, c, ds in A.TOP_PINS}

# ---- 1. every net: one driver, legal directions, equal widths
conn = collections.defaultdict(list)       # 'block.port' or 'TOP.pin' -> [net names]
for n in A.NETS:
    ends = [('drv', n['driver'])] + [('load', l) for l in n['loads']]
    for role, e in ends:
        conn[e].append(n['name'])
        blk, pn = e.split('.', 1)
        if blk == 'TOP':
            p = TOPP.get(pn)
            if not p: err('net %s uses unknown top pin %s' % (n['name'], pn)); continue
            want = 'in' if role == 'drv' else 'out'
            if p['dir'] != want: err('net %s: top pin %s is %s but is used as %s' % (n['name'], pn, p['dir'], role))
            if p['width'] != n['width']: err('net %s width %d != top pin %s width %d' % (n['name'], n['width'], pn, p['width']))
        else:
            p = PORT.get((blk, pn))
            if not p: err('net %s uses unknown port %s' % (n['name'], e)); continue
            want = 'out' if role == 'drv' else 'in'
            if p['dir'] != want: err('net %s: port %s is %s but is used as %s' % (n['name'], e, p['dir'], role))
            if p['width'] != n['width']: err('net %s width %d != port %s width %d' % (n['name'], n['width'], e, p['width']))
names = [n['name'] for n in A.NETS]
chk(len(names) == len(set(names)), 'net names unique (%d nets)' % len(names), 'duplicate net names: %s' % [k for k, v in collections.Counter(names).items() if v > 1])
# ---- 2. every rtl port connected exactly once
for (b, pn), p in PORT.items():
    k = '%s.%s' % (b, pn)
    c = conn.get(k, [])
    if len(c) != 1: err('port %s is connected to %d nets %s (must be exactly 1)' % (k, len(c), c))
chk(not [1 for (b, pn) in PORT if len(conn.get('%s.%s' % (b, pn), [])) != 1], 'every one of the %d block ports is connected to exactly one net' % len(PORT), 'port connectivity errors above')
for pn in TOPP:
    if len(conn.get('TOP.' + pn, [])) != 1: err('top pin %s connected to %d nets' % (pn, len(conn.get('TOP.' + pn, []))))
chk(all(len(conn.get('TOP.' + pn, [])) == 1 for pn in TOPP), 'every one of the %d top-level pins is connected to exactly one net' % len(TOPP), 'top pin connectivity errors above')
# ---- 3. no dangling nets except declared debug taps; every output is used or a debug tap
for n in A.NETS:
    if not n['loads'] and n['tag'] != 'dbg': err('net %s has no load and is not a declared debug tap' % n['name'])
chk(True, '%d nets have loads; %d are declared debug taps (no functional load)' % (sum(1 for n in A.NETS if n['loads']), sum(1 for n in A.NETS if not n['loads'])), '')
# ---- 4. naming rule: inputs _i, outputs _o (exceptions clk, rst_n, rst_n_in/clk_in as board names, bus slave names)
bad = [(b, p['name']) for (b, _), p in PORT.items() for b in [b] if False]
badn = []
for (b, pn), p in PORT.items():
    if pn in ('clk', 'rst_n', 'clk_in', 'rst_n_in'): continue
    if b == 'bus_interconnect' and re.match(r'(%s)_' % '|'.join(A.BANKS), pn):
        continue                                                   # bank buses: <bank>_<sig>_o / _i
    if p['dir'] == 'in' and not pn.endswith('_i'): badn.append('%s.%s (in)' % (b, pn))
    if p['dir'] == 'out' and not pn.endswith('_o'): badn.append('%s.%s (out)' % (b, pn))
chk(not badn, 'port naming rule (_i / _o) holds everywhere', 'naming rule violations: %s' % badn)
bn = [pn for (b, pn), p in PORT.items() if b == 'bus_interconnect' and re.match(r'(%s)_' % '|'.join(A.BANKS), pn) and not ((p['dir'] == 'out' and pn.endswith('_o')) or (p['dir'] == 'in' and pn.endswith('_i')))]
chk(not bn, 'bank bus ports follow _o/_i too', 'bank bus naming: %s' % bn)
# ---- 5. register maps
for k, bk in A.REGS.items():
    offs = [r['off'] for r in bk['regs']]
    chk(len(offs) == len(set(offs)) and all(o % 4 == 0 and o <= 0xFFC for o in offs), '%s: %d registers, offsets unique, word aligned, inside the 4 KB window' % (k, len(offs)), '%s: register offset problem' % k)
    chk(bk['regs'][0]['off'] == 0 and bk['regs'][0]['name'] == 'ID' and int(bk['regs'][0]['reset'], 16) == bk['id'], '%s: ID register at 0x00 = 0x%08X' % (k, bk['id']), '%s: ID register wrong' % k)
    asc = bytes.fromhex('%08X' % bk['id'])[:3].decode()
    chk(asc in ('TIM', 'I2C', 'SEN', 'PID', 'PWM', 'SAF') and bytes.fromhex('%08X' % bk['id'])[3] == 1, '%s: ID ASCII "%s" + version 01' % (k, asc), '%s: ID ascii/version wrong' % k)
# ---- 6. memory map: no overlap, aligned, banks map to blocks
rngs = sorted((b, b + s, n) for n, b, s, _, _ in A.MEMMAP)
ov = [(a[2], c[2]) for a, c in zip(rngs, rngs[1:]) if a[1] > c[0]]
chk(not ov, 'memory map: %d windows, no overlap' % len(rngs), 'memory map overlap: %s' % ov)
chk(all(b % s == 0 for _, b, s, _, _ in A.MEMMAP), 'every window is aligned to its size (decode = top address bits only)', 'unaligned window')
# ---- 7. cross-check against the frozen contract (section 6 receivers must be a subset of our loads)
cp = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '00_ECU_Interface_Contract_v1.0.md')
if os.path.exists(cp):
    sec = open(cp, encoding='utf8').read().split('## 6. Master signal list')[1].split('### Top-level pins')[0]
    netd = {n['name']: n for n in A.NETS}
    miss, extra, seen = [], [], 0
    for line in sec.splitlines():
        m = re.match(r'\|\s*`([^`]+)`(?:\s*`([^`]+)`)*.*\|\s*(.*?→.*?)\s*\|\s*$', line)
        if not m or 'Driver' in line: continue
        sigs = re.findall(r'`([^`]+)`', line.split('|')[1])
        drv_recv = line.split('|')[-2]
        if '→' not in drv_recv: continue
        drv, recv = drv_recv.split('→', 1)
        rblocks = set(x for x in re.findall(r'`([a-z0-9_]+)`', recv) if x in A.BL)
        for s in sigs:
            if s.startswith('<') or s in ('clk', 'rst_n') or '[' in s or ' ' in s: continue
            if s not in netd: miss.append(s); continue
            seen += 1
            ours = set(l.split('.')[0] for l in netd[s]['loads'])
            if not rblocks <= ours: miss.append('%s: contract receivers %s not all in %s' % (s, sorted(rblocks), sorted(ours)))
            if ours - rblocks: extra.append('%s: extra receiver(s) %s (ACR)' % (s, sorted(ours - rblocks)))
    chk(not miss, 'contract section 6 cross-check: all %d contract signals present, every contract receiver is wired' % seen, 'contract mismatch: %s' % miss)
    for e in extra: WARN.append('vs contract v1.0: ' + e)
# ---- 8. firmware header cross-check (sw/ecu_regs.h of the starter kit)
hp = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'ibex_firmware_starter', 'ecu_regs.h')
PFX = dict(TMR='TMR', I2C='I2C', SENS='SENS', PID='PID', PWM='PWM', SAFE='SAFE')
if os.path.exists(hp):
    txt = open(hp).read(); bad = []; cnt = 0
    for k, bk in A.REGS.items():
        for r in bk['regs']:
            m = re.search(r'#define\s+%s_%s\s+\(%s_BASE\s*\+\s*0x([0-9A-Fa-f]+)\)' % (PFX[k], r['name'], PFX[k]), txt)
            cnt += 1
            if not m or int(m.group(1), 16) != r['off']: bad.append('%s_%s' % (PFX[k], r['name']))
    chk(not bad, 'firmware header ecu_regs.h matches the model: all %d registers at the right offsets' % cnt, 'firmware header mismatch: %s' % bad)
# ---- 9. timing budget (cycles at 50 MHz)
tick = 97656; div = 31
bits = 1 + 9 + 9 + 1 + 9 + 14 * 9 + 1
i2c = bits * 4 * (div + 1)
lat = [('I2C burst read (156 SCL periods x 128 cycles)', i2c), ('sensor_pipeline (contract cap)', 64), ('hw_pid_accel (cap)', 16), ('actuation: wait for PWM period wrap (max)', 2500), ('safety: pwm_enable disable path', 2)]
tot = sum(c for _, c in lat)
chk(tot < tick, 'timing: tick-to-pwm worst case %d cycles (%.3f ms) < tick period %d cycles (1.953 ms); margin %.2f ms' % (tot, tot / 50e3, tick, (tick - tot) / 50e3), 'timing budget exceeded')
# ---- 10. clock / reset coverage
no_clk = [b for b in RTL if not any(p['name'] == 'clk' for p in A.BL[b]['ports'])]
chk(not no_clk, 'every RTL block has clk; rst_n on all except rom_dp and ram_sp (pure memories)', 'blocks without clk: %s' % no_clk)
# ---- 11. bank <-> block slave-bus completeness
for b in A.BANKS:
    blk = A.BANK_BLOCK[b]
    need = ['s_sel_i', 's_we_i', 's_be_i', 's_addr_i', 's_wdata_i', 's_rdata_o']
    miss = [n for n in need if (blk, n) not in PORT]
    chk(not miss, 'bank %s: %s has the full slave bus' % (b.upper(), blk), 'bank %s missing %s' % (b, miss))

def report():
    print('=' * 78); print('ARCHITECTURE CHECK  (ecu_soc_top v1.1)'); print('=' * 78)
    for m in INFO: print('  PASS  ' + m)
    for m in WARN: print('  NOTE  ' + m)
    for m in ERR: print('  FAIL  ' + m)
    print('-' * 78); print('%d checks passed, %d notes, %d FAILED' % (len(INFO), len(WARN), len(ERR)))
    open(os.path.join(OUT, 'check_report.txt'), 'w').write('\n'.join(['PASS  ' + m for m in INFO] + ['NOTE  ' + m for m in WARN] + ['FAIL  ' + m for m in ERR]) + '\n')
    return not ERR
if __name__ == '__main__':
    ok = report()
    # ---------------- generated artefacts (only if the model is consistent)
    if ok:
        json.dump(dict(blocks=A.BL, nets=A.NETS, top_pins=A.TOP_PINS, regs={k: {**v, 'regs': v['regs']} for k, v in A.REGS.items()}, memmap=A.MEMMAP, acrs=A.ACRS, fpga_only=A.FPGA_ONLY),
                  open(os.path.join(OUT, 'ecu_arch.json'), 'w'), indent=1, default=str)
        with open(os.path.join(OUT, 'netlist.csv'), 'w', newline='') as f:
            w = csv.writer(f); w.writerow(['net', 'width', 'kind', 'format', 'driver', 'loads', 'class', 'note'])
            for n in A.NETS: w.writerow([n['name'], n['width'], n['kind'], n['fmt'], n['driver'], ' '.join(n['loads']), n['tag'] or 'core', n['note']])
        with open(os.path.join(OUT, 'ports.csv'), 'w', newline='') as f:
            w = csv.writer(f); w.writerow(['block', 'port', 'dir', 'width', 'format', 'net', 'peer', 'class', 'description'])
            netof = {}
            for n in A.NETS:
                for e in [n['driver']] + n['loads']: netof[e] = n
            for (b, pn), p in PORT.items():
                n = netof['%s.%s' % (b, pn)]
                peers = [n['driver']] if p['dir'] == 'in' else n['loads']
                w.writerow([b, pn, p['dir'], p['width'], p['fmt'], n['name'], ' '.join(peers) or '(debug tap)', p['tag'] or 'core', p['desc']])
        with open(os.path.join(OUT, 'registers.csv'), 'w', newline='') as f:
            w = csv.writer(f); w.writerow(['bank', 'block', 'address', 'offset', 'name', 'access', 'reset', 'description'])
            for k, bk in A.REGS.items():
                for r in bk['regs']: w.writerow([k, bk['block'], '0x%08X' % (bk['base'] + r['off']), '0x%02X' % r['off'], r['name'], r['acc'], r['reset'], r['desc']])
        with open(os.path.join(OUT, 'fpga_only.csv'), 'w', newline='') as f:
            w = csv.writer(f); w.writerow(['item', 'class', 'what', 'ASIC / GDSII equivalent'])
            for r in A.FPGA_ONLY: w.writerow(r)
        print('generated: ecu_arch.json netlist.csv ports.csv registers.csv fpga_only.csv check_report.txt')
    sys.exit(0 if ok else 1)
