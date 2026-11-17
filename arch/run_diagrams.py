import sys, os, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arch_specs as S, arch_diagrams as D
only = sys.argv[1:]
for b, spec in S.SPEC.items():
    if only and b not in only: continue
    spec.setdefault('pos', {})
    try: D.render(b, spec)
    except Exception as e: print('ERR', b, type(e).__name__, e)
print('rendered svgs')
