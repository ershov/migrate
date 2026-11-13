#!/bin/bash
# Compare menu bar item keys with the old Mac's snapshot; --apply rewrites the ones that differ.
. "$(dirname "$0")/../conf/kit.conf"
python3 - "$STATE/statusitems.tsv" "${1:-}" <<'EOF'
import subprocess, sys, time
apply = sys.argv[2] == '--apply'
want = {}
for line in open(sys.argv[1]):
    dom, key, typ, val = line.rstrip('\n').split('\t')
    want.setdefault(dom, []).append((key, typ, val))

def num(s):
    return {'True': 1.0, 'False': 0.0}.get(s) if s in ('True', 'False') else float(s)

def current(dom, key):
    r = subprocess.run(['defaults', 'read', dom, key], capture_output=True, text=True)
    try:
        return float(r.stdout.strip()) if r.returncode == 0 else None
    except ValueError:
        return None

def osa(script):
    return subprocess.run(['osascript', '-e', script], capture_output=True, text=True).stdout.strip()

for dom, items in sorted(want.items()):
    diff = [(k, t, v, current(dom, k)) for k, t, v in items]
    diff = [x for x in diff if x[3] != num(x[2])]
    if not diff:
        continue
    print(dom)
    for k, t, v, c in diff:
        print(f'  {k}: {c} -> {v}')
    if not apply:
        continue
    cc = dom == 'com.apple.controlcenter'
    running = not cc and osa(f'application id "{dom}" is running') == 'true'
    if running:
        osa(f'tell application id "{dom}" to quit')
        time.sleep(3)
    for k, t, v, c in diff:
        flag = {'bool': '-bool', 'int': '-int', 'float': '-float'}[t]
        subprocess.run(['defaults', 'write', dom, k, flag, v.lower() if t == 'bool' else v])
    if cc:
        subprocess.run(['killall', 'ControlCenter'])
    elif running:
        subprocess.run(['open', '-b', dom])
if not apply:
    print('(dry run; pass --apply to write)')
EOF
