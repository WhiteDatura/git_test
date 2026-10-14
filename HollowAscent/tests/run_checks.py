"""python tests/run_checks.py [godot executable] [--full]
Runs in isolated user-data directories so tests never alter a player's save.
"""
from pathlib import Path
import os, subprocess, sys, tempfile
root=Path(__file__).resolve().parents[1]
godot=next((x for x in sys.argv[1:] if not x.startswith('--')), 'godot')
checks=[('import',['--editor','--quit'],None),('combat',['--script','res://tests/combat.gd'],'COMBAT_OK')]
for row in (0,30,60,90,120):
    checks.append((f'encounter_{row}',['--','--autoplay','--normal-only','--section-test',f'--test-row={row}'],'ENCOUNTER_OK'))
checks.append(('audio_sources',None,'AUDIO_OK'))
if '--full' in sys.argv:
    checks.append(('full_traversal',['--','--autoplay','--normal-only'],'TRAVERSAL_OK'))
with tempfile.TemporaryDirectory(prefix='hollow-tests-') as temporary:
    environment=os.environ.copy()
    for key,sub in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
        path=Path(temporary)/sub; path.mkdir(); environment[key]=str(path)
    for name,args,marker in checks:
        command=([sys.executable,str(root/'tests/audio_checks.py')] if args is None else [godot,'--headless','--path',str(root),*args])
        result=subprocess.run(command,text=True,capture_output=True,timeout=90,env=environment)
        output=result.stdout+result.stderr
        print(name+'\n'+output,flush=True)
        if result.returncode!=0 or 'ERROR:' in output or (marker and marker not in output):
            raise SystemExit(f'FAILED {name} (exit {result.returncode})')
print('ALL CHECKS PASSED',flush=True)
