import re,sys,json
def add(strings):
    p='lib/l10n_more.dart'
    s=open(p).read()
    for lang in ['en','ar','zh','es','fr']:
        start=s.index(f"  '{lang}': {{\n")
        end=s.index("\n  },\n",start)
        existing=s[start:end]
        add=''
        for k,v in strings.items():
            if f"    '{k}':" in existing: continue
            val=v[lang]
            val=val.replace("\\","\\\\").replace("'","\\'")
            line=f"    '{k}': '{val}',"
            if len(line)>80: line=f"    '{k}':\n        '{val}',"
            add+="\n"+line
        s=s[:end]+add+s[end:]
    open(p,'w').write(s)
if __name__=='__main__':
    add(json.load(open(sys.argv[1])))
