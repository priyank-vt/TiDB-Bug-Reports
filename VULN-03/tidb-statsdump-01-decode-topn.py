import json, base64, sys
d = json.load(open(sys.argv[1]))
def dec(b64):
    raw = base64.b64decode(b64)
    return raw[1:].replace(b'\xff', b'').rstrip(b'\x00\xfd\xfc\xfa\xf7')
for col, cd in d['columns'].items():
    tn = (cd.get('cm_sketch') or {}).get('top_n') or []
    for e in tn:
        print(col, '=', dec(e['data']))
