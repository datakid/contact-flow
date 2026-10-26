import os,re,sys
files=[]
for r in ['lib','test']:
    for dp,_,fs in os.walk(r):
        for f in fs:
            if f.endswith('.dart'): files.append(os.path.join(dp,f).replace('\\','/'))
src={f:open(f,encoding='utf8').read() for f in files}
def strip(s):
    s=re.sub(r"//[^\n]*",'',s)
    s=re.sub(r"r?'''.*?'''|r?\"\"\".*?\"\"\"",'""',s,flags=re.S)
    s=re.sub(r"r?'(?:[^'\\\n]|\\.)*'",'""',s)
    s=re.sub(r'r?"(?:[^"\\\n]|\\.)*"','""',s)
    return s
defre=re.compile(r'^\s*(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+)*(?:class|enum|mixin|extension type|typedef)\s+([A-Z]\w*)',re.M)
extre=re.compile(r'^\s*extension\s+([A-Z]\w*)\s+on',re.M)
defs={}
for f in files:
    if not f.startswith('lib/'): continue
    for m in defre.finditer(strip(src[f])): defs.setdefault(m.group(1),set()).add(f)
    for m in extre.finditer(strip(src[f])): defs.setdefault(m.group(1),set()).add(f)
topvar=re.compile(r'^(?:const|final|bool|int|String|double)\s+(?:\w+\s+)?([a-z]\w*)\s*[=;]',re.M)
imp=re.compile(r"^\s*(import|export)\s+'([^']+)'(.*?);",re.M|re.S)
def resolve(frm,t):
    if t.startswith('package:contact_flow/'): return 'lib/'+t[len('package:contact_flow/'):]
    if t.startswith('package:') or t.startswith('dart:'): return None
    return os.path.normpath(os.path.join(os.path.dirname(frm),t)).replace('\\','/')
graph={}
for f in files:
    out=[]
    for m in imp.finditer(src[f]):
        kind,t,rest=m.groups()
        # conditional export: take all quoted paths
        paths=[t]+re.findall(r"'([^']+)'",rest)
        for pth in paths:
            r=resolve(f,pth)
            if r and r in src: out.append((kind,r))
    graph[f]=out
def provides(f,seen=None):
    seen=seen or set()
    res={f}
    for kind,r in graph.get(f,[]):
        if kind=='export' and r not in seen:
            seen.add(r); res|=provides(r,seen)
    return res
problems=0
for f in files:
    s=strip(src[f])
    own=set(defre.findall(s))|set(extre.findall(s))
    imported=set()
    for kind,r in graph[f]:
        if kind=='import': imported|=provides(r)
    imported.add(f)
    # part of: skip
    for name,ds in defs.items():
        if name in own: continue
        if re.search(r'\b'+name+r'\b',s):
            if not (ds & imported):
                problems+=1
                print('MISSING IMPORT',f,'uses',name,'defined in',sorted(ds)[0])
print('missing-import problems:',problems)

print('--- unused import check')
topfn=re.compile(r'^(?:[A-Za-z_][\w<>?,\[\] ()]*\s+)?([a-z_]\w*)\s*(?:<[^>]*>)?\(',re.M)
topvar2=re.compile(r'^(?:const|final|late|var|bool|int|String|double)\s+(?:[\w<>?, ]+\s+)?([a-z_]\w*)\s*(?:=|;)',re.M)
names={}
for f in files:
    if not f.startswith('lib/'): continue
    s=strip(src[f]); n=set(defre.findall(s))|set(extre.findall(s))
    for m in topvar2.finditer(s): n.add(m.group(1))
    for line in s.split('\n'):
        if line and not line[0].isspace() and not line.startswith(('import','export','class','enum','//','}','@','const','final','abstract','sealed','mixin','extension','typedef','part','library','void main')) :
            m=re.match(r'[\w<>?,\[\]() ]*?\b([a-z_]\w*)\s*(?:<[^>]*>)?\(',line)
            if m: n.add(m.group(1))
        m=re.match(r'(?:Future<[^>]*>|Future|void|bool|int|String|double|List<[^>]*>|Widget|Map<[^>]*>)\??\s+([a-z_]\w*)\s*(?:<[^>]*>)?\(',line)
        if m: n.add(m.group(1))
    names[f]=n
bad=0
for f in files:
    s=strip(src[f])
    for m in imp.finditer(src[f]):
        kind,t,rest=m.groups()
        if kind!='import': continue
        r=resolve(f,t)
        if r and r in src:
            prov=set()
            for q in provides(r): prov|=names.get(q,set())
            if not any(re.search(r'\b'+re.escape(n)+r'\b',s) for n in prov):
                bad+=1; print('UNUSED IMPORT?',f,'->',t)
print('possibly unused project imports:',bad)
