"""Generate the repo-level architecture document from the model.  python3 gen_md.py"""
import os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arch_data as A, arch_text as X
ROOT = os.path.dirname(os.path.abspath(__file__)); os.makedirs(os.path.join(ROOT, 'docs'), exist_ok=True)
NETOF = {}
for n in A.NETS:
    for e in [n['driver']] + n['loads']: NETOF[e] = n
def pw(p): return str(p['width'])
def peer(b, p):
    n = NETOF['%s.%s' % (b, p['name'])]; ps = [n['driver']] if p['dir'] == 'in' else n['loads']
    return ', '.join(x.replace('TOP.', 'pin ') for x in ps) or '(debug tap)'
out = []
w = out.append
w('# ecu_soc_top: Architecture Specification v1.1 (generated)\n')
w('GENERATED from `arch/arch_data.py` and `arch/arch_text.py` by `arch/gen_md.py`. Do not edit by hand: change the model, run `python3 arch_check.py && python3 gen_md.py`. The checker proves: every port is connected to exactly one net, widths match, directions match, every net has one driver, the memory map has no overlap, every register offset is unique, the firmware header matches the registers, and the contract signals are all present.\n')
w('## 1. Architecture change requests v1.0 -> v1.1\n'); w('| ID | Change | Why | Effect |\n|---|---|---|---|')
for a in A.ACRS: w('| %s | %s | %s | %s |' % a)
w('\n## 2. Block inventory\n'); w('| Block | Kind | Owner | Language | Ports | Parameters |\n|---|---|---|---|---|---|')
for b, B in A.BL.items(): w('| `%s` | %s | %s | %s | %d | %s |' % (b, B['kind'], B['owner'], B['lang'], len(B['ports']), ', '.join(B.get('params', [])) or '-'))
w('\n## 3. Memory map\n'); w('| Window | Base | Size | Block | Note |\n|---|---|---|---|---|')
for n, bs, sz, blk, nt in A.MEMMAP: w('| %s | `0x%08X` | 0x%X | `%s` | %s |' % (n, bs, sz, blk, nt))
w('\n## 4. Top-level pins of ecu_soc_top\n'); w('| Pin | Dir | Width | Class | Meaning |\n|---|---|---|---|---|')
for n, d, wd, c, ds in A.TOP_PINS: w('| `%s` | %s | %d | %s | %s |' % (n, d, wd, c, ds))
w('\n## 5. Master netlist (every net, one driver)\n'); w('| Net | Width | Kind | Format | Driver | Loads | Class |\n|---|---|---|---|---|---|---|')
for n in A.NETS: w('| `%s` | %d | %s | %s | `%s` | %s | %s |' % (n['name'], n['width'], n['kind'], n['fmt'], n['driver'].replace('TOP.', 'pin '), ', '.join('`%s`' % l.replace('TOP.', 'pin ') for l in n['loads']) or '(debug tap)', n['tag'] or 'core'))
w('\n## 6. Blocks\n')
for b in list(A.BL) + ['firmware']:
    t = X.T[b]; B = A.BL.get(b, dict(kind='sw', owner='Conolas', lang='C + RISC-V assembly', params=[], ports=[]))
    w('### 6.%s `%s`\n' % (list(A.BL).index(b) + 1 if b in A.BL else 14, b))
    w('Diagram: `diagrams/blk_%s.png`.  Kind %s, owner %s, %s. %s\n' % (b, B['kind'], B['owner'], B['lang'], t['purpose']))
    if B.get('params'): w('Parameters: ' + ', '.join('`%s`' % p for p in B['params']) + '\n')
    if B['ports']:
        w('**Ports** (comes from / goes to is taken from the netlist)\n'); w('| Port | Dir | Width | Format | Net | Comes from / goes to | Class | Meaning |\n|---|---|---|---|---|---|---|---|')
        for p in B['ports']:
            n = NETOF.get('%s.%s' % (b, p['name']))
            w('| `%s` | %s | %s | %s | %s | %s | %s | %s |' % (p['name'], p['dir'], pw(p), p['fmt'], ('`%s`' % n['name']) if n else '', peer(b, p) if n else '', p['tag'] or 'core', p['desc']))
        w('')
    k = next((k for k, v in A.REGS.items() if v['block'] == b), None)
    if k:
        bk = A.REGS[k]; w('**Register bank %s**, base `0x%08X` (reads are registered: valid the cycle after `s_sel_i`)\n' % (k, bk['base']))
        w('| Offset | Name | Access | Reset | Description |\n|---|---|---|---|---|')
        for r in bk['regs']: w('| 0x%02X | %s | %s | %s | %s |' % (r['off'], r['name'], r['acc'], r['reset'], r['desc']))
        w('')
    w('**How the data moves inside**\n')
    for i, s in enumerate(t['steps'], 1): w('%d. %s' % (i, s))
    w('\n**Timing and numbers:** %s\n' % t['timing']); w('**FPGA-only / bring-up / GDSII notes:** %s\n' % t['fpga']); w('**Verification:** %s\n' % t['verify'])
w('## 7. FPGA-only and bring-up items (not in the GDSII)\n'); w('| Item | Class | What | GDSII equivalent |\n|---|---|---|---|')
for r in A.FPGA_ONLY: w('| %s | %s | %s | %s |' % r)
w('\n## 8. Automated check result\n\n```\n' + open(os.path.join(ROOT, 'generated', 'check_report.txt')).read() + '```\n')
open(os.path.join(ROOT, 'docs', 'ECU_Architecture_v1.1.md'), 'w', encoding='utf8').write('\n'.join(out))
print('md written', sum(len(x) for x in out), 'chars')
