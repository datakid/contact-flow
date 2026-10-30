import sys,subprocess,os
import tree_sitter_dart as d
from tree_sitter import Language, Parser
P=Parser(Language(d.language()))
def errors(src):
    t=P.parse(src)
    out=[]
    def walk(n):
        if n.type=='ERROR' or n.is_missing:
            out.append((n.start_point[0]+1,n.type,src.split(b'\n')[n.start_point[0]][:90].decode('utf8','replace')))
            return
        for c in n.children: walk(c)
    if t.root_node.has_error: walk(t.root_node)
    return out
mode=sys.argv[1]
files=[]
for r in ['lib','test']:
    for dp,_,fs in os.walk(r):
        for f in fs:
            if f.endswith('.dart'): files.append(os.path.join(dp,f))
base_err={}
if mode=='compare':
    for f in files:
        try: old=subprocess.check_output(['git','show','2c38c77:'+f],stderr=subprocess.DEVNULL)
        except: continue
        base_err[f]=len(errors(old))
tot=0;bad=0
for f in sorted(files):
    e=errors(open(f,'rb').read())
    b=base_err.get(f,0) if mode=='compare' else 0
    if len(e)>b:
        bad+=1; print('\n',f,'errors',len(e),'baseline',b)
        for x in e[:3]: print('   line',x[0],x[1],'|',x[2])
print('\nfiles',len(files),'with new errors',bad)
