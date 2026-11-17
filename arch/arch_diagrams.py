"""Block diagrams generated from the architecture model (terminal theme).  python3 arch_diagrams.py [block ...]"""
import os, sys, re, textwrap
sys.path.insert(0, '/tmp/diagrams'); sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dk import *
import arch_data as A
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'diagrams'); os.makedirs(OUT, exist_ok=True)
PORT = {(b, p['name']): p for b in A.BL for p in A.BL[b]['ports']}
NETOF = {}
for n in A.NETS:
    for e in [n['driver']] + n['loads']: NETOF[e] = n
NW, NH, PX, PY = 290, 146, 350, 215          # node size and grid pitch
LCOL, RCOL, GW = 40, None, 560                # left group column x and width
def pn(b, name): 
    p = PORT[(b, name)]; return name + ('' if p['width'] == 1 else '[%d:0]' % (p['width'] - 1))
def peers(b, names, direction):
    s = []
    for n in names:
        e = NETOF['%s.%s' % (b, n)]
        ps = [e['driver']] if direction == 'in' else e['loads']
        for x in ps:
            blk = x.split('.')[0]; s.append(('pin' if blk == 'TOP' else blk) if blk != 'TOP' else 'pin ' + x.split('.')[1])
    out = []
    for x in s:
        if x not in out: out.append(x)
    return out or ['(debug tap, no load)']
def wrap(text, n): return textwrap.wrap(text, n) or ['']

def render(blk, spec):
    B = A.BL[blk]
    ins, outs, nodes, edges = spec['ins'], spec['outs'], spec['nodes'], spec['edges']
    seen0 = [p for g in ins + outs for p in g['ports']]
    auto = [p for p in ('clk', 'rst_n') if (blk, p) in PORT and p not in seen0]
    if auto: ins = [dict(ports=auto, node=None, title='CLOCK / RESET')] + ins
    # ---- coverage check: every port appears in exactly one group
    seen = [p for g in ins + outs for p in g['ports']]
    allp = [p['name'] for p in B['ports']]
    miss = [p for p in allp if p not in seen]; dup = [p for p in set(seen) if seen.count(p) > 1]
    assert not miss and not dup, '%s: ports missing %s duplicated %s' % (blk, miss, dup)
    ncol = max(n[3] for n in nodes) + 1; nrow = max(n[4] for n in nodes) + 1
    cw = ncol * PX - (PX - NW); ch = nrow * PY - (PY - NH)
    X0 = LCOL + GW + 90; Y0 = 210
    RX = X0 + cw + 90
    W = RX + GW + 40
    # ---- group box heights
    def gh(g, d):
        names = ' · '.join(pn(blk, p) for p in g['ports'])
        L = wrap(names, 54); P = wrap(('← ' if d == 'in' else '→ ') + ', '.join(peers(blk, g['ports'], d)), 54)
        return L, P, 34 + 22 * (len(L) + len(P)) + 14
    GI = [(g,) + gh(g, 'in') for g in ins]; GO = [(g,) + gh(g, 'out') for g in outs]
    colh = lambda G: sum(x[3] for x in G) + 14 * (len(G) - 1)
    regs = A.REGS.get(next((k for k, v in A.REGS.items() if v['block'] == blk), ''), None)
    regh = 0
    if regs:
        regh = 70 + 26 * ((len(regs['regs']) + 3) // 4)
    H = max(colh(GI), colh(GO), Y0 + ch + 120 + regh + 150) + 120
    s = Svg(W, int(H), 'blk_' + blk)
    # title
    kind = {'rtl': 'RTL BLOCK', 'top': 'TOP LEVEL', 'fpga': 'FPGA-ONLY WRAPPER', 'sw': 'SOFTWARE'}[B['kind']]
    s.text(40, 52, '%s  ·  %s' % (blk, kind), 34, 'SemiBold', TEXT, 'start')
    s.text(40, 90, 'owner %s  ·  %s  ·  %s' % (B['owner'], B['lang'], ('parameters: ' + ', '.join(B.get('params', []))) if B.get('params') else 'no parameters'), 19, 'Regular', MUTED, 'start')
    s.text(40, 122, spec['title'], 21, 'Regular', LIME, 'start')
    # internal frame
    s.lane(X0 - 40, Y0 - 50, cw + 80, ch + 100, 'INSIDE ' + blk.upper(), fill='#101316')
    pos = {}
    for nid, label, sub, c, r, *rest in nodes:
        kindn = rest[0] if rest else 'card'
        x = X0 + c * PX; y = Y0 + r * PY
        pos[nid] = (x, y, NW, NH)
        subw = '\n'.join(textwrap.wrap(sub, 29)[:4])
        s.box(x, y, NW, NH, label, subw, kindn, ts=21 if len(label) < 24 else 18, ss=15)
    def mid(n, side, k=0):
        x, y, w, h = pos[n]
        return {'l': (x, y + h / 2 + k), 'r': (x + w, y + h / 2 + k), 't': (x + w / 2 + k, y), 'b': (x + w / 2 + k, y + h)}[side]
    ncount = {}
    # ---- internal edges
    GAP = PX - NW; lastrow = nrow - 1
    def rowof(n): return round((pos[n][1] - Y0) / PY)
    for i, e in enumerate(edges):
        a, b2, lab = e[0], e[1], e[2]; sty = e[3] if len(e) > 3 else 'main'; route = e[4] if len(e) > 4 else 'auto'
        xa, ya, wa, ha = pos[a]; xb, yb, wb, hb = pos[b2]; k = (i % 4) * 7
        if route == 'auto' and xb > xa + 1 and abs(yb - ya) < 2: pts = [mid(a, 'r'), mid(b2, 'l')]; lp = ((pts[0][0] + pts[1][0]) / 2, pts[0][1] - 12)
        elif route == 'auto' and xb > xa + 1:
            mx = xa + wa + GAP / 2 + k - 10; p0 = mid(a, 'r'); p1 = mid(b2, 'l'); pts = [p0, (mx, p0[1]), (mx, p1[1]), p1]; lp = (mx, (p0[1] + p1[1]) / 2)
        elif route == 'auto' and abs(xb - xa) < 2 and yb > ya: pts = [mid(a, 'b'), mid(b2, 't')]; lp = (xa + wa / 2 + 6, (ya + ha + yb) / 2)
        elif route == 'auto' and abs(xb - xa) < 2: pts = [mid(a, 't'), mid(b2, 'b')]; lp = (xa + wa / 2 + 6, (yb + hb + ya) / 2)
        else:
            if route == 'auto': route = 'bottom'
            if route == 'bottom':
                ly = Y0 + ch + 20 + k
                if rowof(a) == lastrow: p0 = mid(a, 'b', -20 + k); seg = [p0, (p0[0], ly)]
                else: p0 = mid(a, 'r'); gx = xa + wa + GAP / 2 + k - 10; seg = [p0, (gx, p0[1]), (gx, ly)]
                if rowof(b2) == lastrow: p1 = mid(b2, 'b', 20 - k); end = [(p1[0], ly), p1]
                else: p1 = mid(b2, 'l'); gx2 = xb - GAP / 2 + k - 4; end = [(gx2, ly), (gx2, p1[1]), p1]
                pts = seg + end; lp = ((seg[-1][0] + end[0][0]) / 2, ly - 9)
            else:   # top lane
                ly = Y0 - 24 - k
                if rowof(a) == 0: p0 = mid(a, 't', 20 - k); seg = [p0, (p0[0], ly)]
                else: p0 = mid(a, 'r'); gx = xa + wa + GAP / 2 + k - 10; seg = [p0, (gx, p0[1]), (gx, ly)]
                if rowof(b2) == 0: p1 = mid(b2, 't', -20 + k); end = [(p1[0], ly), p1]
                else: p1 = mid(b2, 'l'); gx2 = xb - GAP / 2 + k - 4; end = [(gx2, ly), (gx2, p1[1]), p1]
                pts = seg + end; lp = ((seg[-1][0] + end[0][0]) / 2, ly - 9)
        s.arrow(pts, 'ctl' if sty == 'ctl' else 'main', dash=(sty == 'dash'))
        if lab: s.label(lp[0], lp[1], lab, 14, MUTED, 'middle', mf='#101316')
    # ---- input groups (left)
    y = 160
    k_in = {}
    for gi, (g, L, P, h) in enumerate(GI):
        nid = g['node']
        s.items.append(f'<rect x="{LCOL}" y="{y}" width="{GW}" height="{h}" rx="6" fill="{CARD}" stroke="{LIME if g.get("hi") else LINE}" stroke-width="2"/>')
        s.text(LCOL + 16, y + 28, g.get('title', 'INPUTS'), 16, 'Medium', LIME, 'start', 2)
        for j, t in enumerate(L): s.text(LCOL + 16, y + 54 + 22 * j, t, 17, 'Medium', TEXT, 'start')
        for j, t in enumerate(P): s.text(LCOL + 16, y + 54 + 22 * len(L) + 22 * j, t, 16, 'Regular', MUTED, 'start')
        if nid is None:
            y += h + 14; continue
        nx, ny, nw, nh = pos[nid]
        gy = y + h / 2; gx = LCOL + GW
        k = k_in.get(nid, 0); k_in[nid] = k + 1
        xm = gx + 18 + 8 * (gi % 6)
        if nx <= X0 + 1 or g.get('side') == 'left':
            ty = ny + 24 + 22 * k; pts = [(gx, gy), (xm, gy), (xm, ty), (nx, ty)]
        else:
            lane = Y0 - 24 - 12 * (gi % 4); tx = nx + 40 + 36 * k
            pts = [(gx, gy), (xm, gy), (xm, lane), (tx, lane), (tx, ny)]
        s.arrow(pts, 'main', dash=g.get('dash', False))
        y += h + 14
    # ---- output groups (right)
    y = 160; k_out = {}
    for gi, (g, L, P, h) in enumerate(GO):
        nid = g['node']; nx, ny, nw, nh = pos[nid]
        s.items.append(f'<rect x="{RX}" y="{y}" width="{GW}" height="{h}" rx="6" fill="{CARD}" stroke="{LIME if g.get("hi") else LINE}" stroke-width="2"/>')
        s.text(RX + 16, y + 28, g.get('title', 'OUTPUTS'), 16, 'Medium', LIME, 'start', 2)
        for j, t in enumerate(L): s.text(RX + 16, y + 54 + 22 * j, t, 17, 'Medium', TEXT, 'start')
        for j, t in enumerate(P): s.text(RX + 16, y + 54 + 22 * len(L) + 22 * j, t, 16, 'Regular', MUTED, 'start')
        gy = y + h / 2; gx = RX
        k = k_out.get(nid, 0); k_out[nid] = k + 1
        xm = gx - 18 - 8 * (gi % 6)
        if nx + nw >= X0 + cw - 1 or g.get('side') == 'right':
            sy = ny + 24 + 22 * k; pts = [(nx + nw, sy), (xm, sy), (xm, gy), (gx, gy)]
        else:
            lane = Y0 + ch + 36 + 12 * (gi % 6); sx = nx + 40 + 36 * k
            pts = [(sx, ny + nh), (sx, lane), (xm, lane), (xm, gy), (gx, gy)]
        s.arrow(pts, 'main', dash=g.get('dash', False))
        y += h + 14
    # ---- register panel and notes under the internal frame
    yy = Y0 + ch + 100 + 70
    if regs:
        s.lane(X0 - 40, yy - 40, cw + 80, regh + 20, 'REGISTER BANK  ·  base 0x%08X  ·  ID 0x%08X  ·  reads are registered (valid next cycle)' % (regs['base'], regs['id']), fill='#101316')
        cols = 4; per = (len(regs['regs']) + cols - 1) // cols
        for i, r in enumerate(regs['regs']):
            cx = X0 - 20 + (i // per) * ((cw + 40) / cols); cy = yy + 22 + (i % per) * 26
            s.text(cx, cy, '0x%02X  %s  %s' % (r['off'], r['name'], r['acc']), 16, 'Regular', TEXT if r['acc'] != 'RO' else MUTED, 'start')
        yy += regh + 20
    for t in spec.get('notes', []):
        s.text(X0 - 40, yy + 30, t, 17, 'Regular', MUTED, 'start'); yy += 26
    s.save(os.path.join(OUT, 'blk_%s.svg' % blk))
    return W, H
