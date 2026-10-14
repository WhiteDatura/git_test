"""Original Hollow Ascent 0.4 procedural score and physical sound design.
Requires Python 3, NumPy and SciPy only when regenerating; Godot plays included WAVs.
No commercial samples, melodies, instruments or recordings are used.
"""
from pathlib import Path
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile
ROOT = Path(__file__).resolve().parent
RATE = 32000
rng = np.random.default_rng(48104)

def noise(n, lo=100, hi=10000):
    return sosfilt(butter(2, [lo, hi], btype='bandpass', fs=RATE, output='sos'), rng.normal(0, 1, n))

def write(name, y, level=.65, loop=False):
    y = np.asarray(y)
    if y.ndim == 1: y = y[:, None]
    if not loop:
        y[:32] *= np.linspace(0, 1, 32)[:, None]
        y[-320:] *= np.linspace(1, 0, 320)[:, None]
    y *= level / max(np.max(np.abs(y)), .0001)
    wavfile.write(ROOT / (name + '.wav'), RATE, (np.clip(y, -.98, .98)*32767).astype(np.int16))

def steel(duration, hard=False):
    t = np.arange(int(RATE*duration))/RATE
    # Strong damped contact and scrape, with a short inharmonic blade body.
    y = noise(len(t), 900, 12500)*np.exp(-t*(150 if hard else 125))*2.2
    y += noise(len(t), 1300, 9500)*np.exp(-((t-.027)/.022)**2)*.28
    for j, f in enumerate([627, 1083, 1847, 2761, 3943, 5339, 7283]):
        y += (.15/(1+j*.25))*np.sin(2*np.pi*f*t+rng.uniform(0, 6))*np.exp(-t*(13+j*3)*(0.72 if hard else 1))
    y += .3*np.sin(2*np.pi*(117*t-35*t*t))*np.exp(-t*65)
    y += noise(len(t), 180, 1500)*np.exp(-t*36)*.10
    return y
write('parry', steel(.34), .69)
write('perfect', steel(.46, True), .82)
for name, duration, lo, hi, level in [('draw',.23,1400,10000,.44),('sheath',.18,550,6200,.20),('sweep',.28,300,7000,.38),('lunge',.30,180,8500,.50),('flyby',.19,1800,11000,.20),('fall',.46,130,4500,.20)]:
    t = np.arange(int(RATE*duration))/RATE; x=t/duration
    y = noise(len(t),lo,hi)*np.sin(np.pi*x)**2
    if name in ['draw','sheath']: y += .23*np.sin(2*np.pi*287*t)*np.exp(-t*60)
    if name=='lunge': y += .3*noise(len(t),180,1400)*np.exp(-t*60)
    write(name,y,level)
for name, f, duration in [('warning',183,.40),('blade',119,.45),('arrow',223,.18),('land',74,.22),('miss',92,.27),('enemy_hit',103,.30),('rebound',146,.23)]:
    t=np.arange(int(RATE*duration))/RATE
    y=.6*np.sin(2*np.pi*(f*t-30*t*t))*np.exp(-t*30)
    y+=noise(len(t),200,5500)*np.exp(-t*45)*.7
    if name=='warning':
        y += .3*np.sin(2*np.pi*(520*t+80*t*t))*np.sin(np.pi*t/duration)*np.exp(-t*6)
    if name=='enemy_hit': y += noise(len(t),1200,9000)*np.exp(-t*24)*.55
    if name=='rebound': y += noise(len(t),900,7000)*np.sin(np.pi*t/duration)**2*.4
    if name=='miss': y += noise(len(t),160,1400)*np.exp(-((t-.07)/.05)**2)*.45
    write(name,y,.57 if name=='enemy_hit' else .43)
for name in ['spirit','paper_release']:
    duration=.40; t=np.arange(int(RATE*duration))/RATE
    y=noise(len(t),1000,10500)*(.2+np.sin(t*83)**6)*np.sin(np.pi*t/duration)
    write(name,y,.32)

# Original 32-beat pentatonic phrase at 80 BPM: 24 seconds, all stems phase-locked.
DURATION=24; N=RATE*DURATION; beat=.75

def add(track, y, at, pan=0):
    indices=(np.arange(len(y))+int(at*RATE)) % N
    track[indices,0]+=y*np.sqrt((1-pan)/2)
    track[indices,1]+=y*np.sqrt((1+pan)/2)

def pluck(f, duration=2):
    t=np.arange(int(RATE*duration))/RATE
    y=np.zeros_like(t)
    for h in range(1,8): y+=np.sin(2*np.pi*f*h*t)*np.exp(-t*(2.4+h*.7))/h**1.6
    return y*(1-np.exp(-t*600))

def flute(f):
    t=np.arange(RATE*3)/RATE
    env=np.minimum(t/.3,1)*np.minimum((3-t)/.65,1)
    phase=2*np.pi*f*t + .015*np.sin(2*np.pi*4.3*t)
    y=(np.sin(phase)*.3+np.sin(phase*2)*.025+noise(len(t),800,4000)*.035)*env
    return y
calm=np.zeros((N,2)); combat=np.zeros_like(calm); danger=np.zeros_like(calm)
notes=[146.832,164.814,195.998,220,246.942]
for at,k in [(0,0),(4,2),(9,3),(16,1),(20,0),(25,4),(29,2)]: add(calm, pluck(notes[k]), at*beat, -.35 if k%2 else .4)
for at,k in [(2,2),(11,1),(23,0)]: add(calm,flute(notes[k]*2)*.22,at*beat,.12)
t=np.arange(N)/RATE
# Integer-cycle quiet bowed harmonics retain seamless periodic phase.
calm[:,0]+=.018*np.sin(2*np.pi*147*t)*(1+.15*np.sin(2*np.pi*t/24))
calm[:,1]+=.018*np.sin(2*np.pi*147*t+.2)*(1+.15*np.sin(2*np.pi*t/24))
for i in range(32):
    if i%2==0: add(combat,pluck(notes[[0,2,1,3][(i//2)%4]],.8)*.22,i*beat,(-1)**i*.25)
    td=np.arange(int(RATE*.5))/RATE
    drum=(np.sin(2*np.pi*(62*td-18*td*td))*.45+noise(len(td),70,600)*.20)*np.exp(-td*14)
    if i%4==0: add(combat,drum,i*beat,-.1)
    add(danger,pluck(notes[(i//4)%5]*.5,.6)*.25,i*beat,(-1)**i*.3)
    if i%2==0: add(danger,drum*.7,i*beat,.1)
for name,y,level in [('music_calm',calm,.52),('music_combat',combat,.45),('music_danger',danger,.45)]:
    # Circular early reflections/reverb also wrap across the loop boundary.
    y=y+np.roll(y, int(.173*RATE),axis=0)*.16+np.roll(y,int(.347*RATE),axis=0)*.09
    write(name,y,level,loop=True)
wind=noise(N,70,1700)
# Crossfade matching end/start region, and enforce an exact continuous endpoint.
fade=RATE
wind[:fade]=wind[:fade]*np.linspace(0,1,fade)+wind[-fade:]*np.linspace(1,0,fade)
wind-=np.mean(wind)
wind[-256:]=wind[-256:]*np.linspace(1,0,256)+wind[0]*np.linspace(0,1,256)
write('wind',wind,.20,loop=True)
write('summit',flute(293.664)*.3,.26)
print('Generated 18 original effects, three synchronized 24s music stems, and wind.')
