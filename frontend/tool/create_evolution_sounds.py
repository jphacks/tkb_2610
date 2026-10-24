"""Create original, short bell chimes. Standard-library synthesis; no sampled media."""
import math, wave, struct
from pathlib import Path
RATE=44100
OUT=Path(__file__).resolve().parents[1]/'assets/audio'
OUT.mkdir(parents=True,exist_ok=True)
def render(name,seconds,notes):
    data=[]
    for i in range(int(seconds*RATE)):
        t=i/RATE;v=0.0
        for start,hz,gain,decay in notes:
            x=t-start
            if x<0:continue
            attack=min(1.0,x/.018)
            envelope=attack*math.exp(-x/decay)
            tone=(math.sin(2*math.pi*hz*x)+.22*math.sin(2*math.pi*hz*2.01*x)+.08*math.sin(2*math.pi*hz*3.98*x))/1.3
            v+=tone*envelope*gain
        v*=min(1.0,(seconds-t)/.18)
        data.append(v)
    peak=max(abs(v) for v in data)
    scale=min(1.0,.65/max(peak,.001))
    with wave.open(str(OUT/name),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h',round(v*scale*32767)) for v in data))
    print(name,'seconds=',seconds,'peak=',round(peak*scale,3))
render('evolution_charge.wav',1.8,[(0,523.25,.14,.48),(.24,659.25,.13,.5),(.48,783.99,.12,.52),(.78,1046.5,.1,.55)])
render('evolution_reveal.wav',2.3,[(0,523.25,.16,.8),(.06,659.25,.15,.75),(.12,783.99,.15,.8),(.19,1046.5,.18,.85),(.37,1567.98,.07,.65)])
