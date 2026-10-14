"""Dependency-free WAV integrity, music loop, and optional Godot mix checks."""
from pathlib import Path
import array, math, sys, wave, json
root=Path(__file__).resolve().parents[1]
report={}
for path in sorted((root/'assets/audio').glob('*.wav')):
    with wave.open(str(path)) as wav:
        assert wav.getsampwidth()==2, path
        channels,rate,frames=wav.getnchannels(),wav.getframerate(),wav.getnframes()
        data=array.array('h',wav.readframes(frames))
    peak=max(abs(x) for x in data)/32768
    assert .01<peak<.99, (path,peak)
    item={'seconds':round(frames/rate,3),'channels':channels,'peak_dbfs':round(20*math.log10(peak),2)}
    if path.stem.startswith('music_') or path.stem=='wind':
        delta=max(abs(data[i]-data[-channels+i]) for i in range(channels))/32768
        assert frames/rate==24.0 and delta<.012,(path,delta)
        item['loop_boundary_step']=round(delta,6)
    report[path.name]=item
if len(sys.argv)>1:
    with wave.open(sys.argv[1]) as wav:
        assert wav.getnchannels()==2
        frames,rate=wav.getnframes(),wav.getframerate()
        assert frames/rate>=26
        raw=wav.readframes(frames)
        # Godot movie writer may output 32-bit PCM; ffmpeg conversion to s16 is supported.
        assert wav.getsampwidth()==2
        data=array.array('h',raw)
    peak=max(abs(x) for x in data)/32768
    clipped=sum(abs(x)>=32760 for x in data)
    assert 0.01<peak<.95 and clipped==0,(peak,clipped)
    report['godot_overlap_mix']={'seconds':round(frames/rate,3),'peak_dbfs':round(20*math.log10(peak),2),'clipped_samples':clipped}
print(json.dumps(report,indent=2))
print('AUDIO_OK sources, synchronized loops'+(', actual stereo overlap mix' if len(sys.argv)>1 else ''))
