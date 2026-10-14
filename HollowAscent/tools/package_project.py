"""Build and verify a Godot Project Manager compatible editable source ZIP.
python tools/package_project.py /output/HollowAscent.zip [godot executable]
"""
from pathlib import Path, PurePosixPath
import hashlib, os, shutil, subprocess, sys, tempfile, zipfile
root=Path(__file__).resolve().parents[1]
output=Path(sys.argv[1]).resolve()
godot=sys.argv[2] if len(sys.argv)>2 else 'godot'
assert not output.is_relative_to(root), 'Write the distribution outside the source project'
excluded={'.godot','.git','__pycache__','export'}
paths=[p for p in root.rglob('*') if not any(x in excluded for x in p.relative_to(root).parts) and p.suffix not in {'.pyc','.tmp'}]
assert not any(p.is_symlink() for p in paths), 'Symlinks require separate packaging review'
directories=sorted([root]+[p for p in paths if p.is_dir()],key=lambda p:(len(p.relative_to(root.parent).parts),str(p)))
files=sorted(p for p in paths if p.is_file())
output.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    # All directory records precede all file records, including the top-level root.
    for path in directories:
        archive.write(path,path.relative_to(root.parent).as_posix()+'/')
    for path in files:
        archive.write(path,path.relative_to(root.parent).as_posix())
with tempfile.TemporaryDirectory(prefix='hollow-zip-') as temporary:
    destination=Path(temporary)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None, 'CRC failure'
        names=archive.namelist()
        assert len(names)==len(set(names))
        assert names[0]=='HollowAscent/'
        assert all(PurePosixPath(n).parts[0]=='HollowAscent' for n in names)
        wrote_file=False
        failures=[]
        for info in archive.infolist():
            path=PurePosixPath(info.filename)
            assert not path.is_absolute() and '..' not in path.parts
            target=destination.joinpath(*path.parts)
            try:
                if info.is_dir():
                    assert not wrote_file, 'Directory appeared after a file'
                    target.mkdir(exist_ok=True) # deliberately no automatic parent creation
                else:
                    wrote_file=True
                    with target.open('wb') as stream: # faithful directory-record dependency
                        stream.write(archive.read(info))
            except Exception as error:
                failures.append((info.filename,str(error)))
        assert not failures, failures
    assert (destination/'HollowAscent/project.godot').is_file()
    assert not (destination/'HollowAscent/.godot').exists()
    print(f'EXTRACT_OK {len(files)} files, {len(directories)} explicit directories, zero extraction failures',flush=True)
    result=subprocess.run([sys.executable,str(destination/'HollowAscent/tests/run_checks.py'),godot],capture_output=True,text=True,timeout=150)
    transcript=result.stdout+result.stderr
    output.with_suffix('.fresh-checks.txt').write_text(transcript)
    assert result.returncode==0 and 'ALL CHECKS PASSED' in transcript, transcript
    for line in transcript.splitlines():
        if any(marker in line for marker in ['COMBAT_OK','ENCOUNTER_OK','AUDIO_OK','ALL CHECKS']): print(line)
    print('FRESH_IMPORT_OK fresh extracted project import, combat, five encounter samples and source audio checks')
print('SHA256 '+hashlib.sha256(output.read_bytes()).hexdigest())
print(f'PACKAGE_OK {output} ({output.stat().st_size} bytes)')
