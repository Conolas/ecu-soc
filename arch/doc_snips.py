import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arch_data as A, arch_specs as S
NETOF = {}
for n in A.NETS:
    for e in [n['driver']] + n['loads']: NETOF[e] = n
PORT = {(b, p['name']): p for b in A.BL for p in A.BL[b]['ports']}
def pn(b, n): p = PORT[(b, n)]; return n + ('' if p['width'] == 1 else '[%d]' % p['width'])
def grp_table(b):
    spec = S.SPEC[b]; ins, outs = spec['ins'], spec['outs']
    seen = [p for g in ins + outs for p in g['ports']]
    auto = [p for p in ('clk', 'rst_n') if (b, p) in PORT and p not in seen]
    rows = []
    if auto: rows.append(('in', auto, 'clk_rst_gen', 'clock / reset'))
    for d, G in (('in', ins), ('out', outs)):
        for g in G:
            ps = []
            for p in g['ports']:
                n = NETOF['%s.%s' % (b, p)]; x = [n['driver']] if d == 'in' else n['loads']
                for e in x:
                    e = e.replace('TOP.', 'pin ').split('.')[0] if not e.startswith('TOP.') else e.replace('TOP.', 'pin ')
                    if e not in ps: ps.append(e)
            rows.append((d, g['ports'], ', '.join(ps) or '(debug tap)', g.get('title', '').lower()))
    s = '| Dir | Ports | Comes from / goes to | Group |\n|---|---|---|---|\n'
    for d, ports, pe, t in rows:
        s += '| %s | %s | %s | %s |\n' % (d, ' · '.join('`%s`' % pn(b, p) for p in ports), pe, t)
    return s
def reg_table(b):
    k = next((k for k, v in A.REGS.items() if v['block'] == b), None)
    if not k: return ''
    bk = A.REGS[k]; s = 'Register bank **%s**, base `0x%08X`, reads registered (valid next cycle):\n\n| Off | Name | Acc | Reset | Meaning |\n|---|---|---|---|---|\n' % (k, bk['base'])
    for r in bk['regs']: s += '| %02X | %s | %s | %s | %s |\n' % (r['off'], r['name'], r['acc'], r['reset'], r['desc'])
    return s
if __name__ == '__main__':
    for b in sys.argv[1:]:
        print('#### PORTS', b); print(grp_table(b)); print(reg_table(b))
