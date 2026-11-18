"""占位 BGM 生成器（numpy + ffmpeg）。正式音乐到了直接覆盖同名 .ogg。

python3 tools/gen_placeholder_music.py
"""
import numpy as np, subprocess, os, tempfile, wave

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music")

def midi(n): return 440.0 * 2 ** ((n - 69) / 12)

def env(n, a=0.01, r=0.25):
    t = np.arange(n) / SR
    e = np.minimum(1, t / a) * np.exp(-t / r)
    return e

def tone(freq, dur, kind="sine", a=0.01, r=0.3, vol=0.3):
    n = int(dur * SR); t = np.arange(n) / SR
    if kind == "sine": w = np.sin(2*np.pi*freq*t)
    elif kind == "square": w = np.sign(np.sin(2*np.pi*freq*t)) * 0.5
    elif kind == "tri": w = 2*np.abs(2*((freq*t) % 1) - 1) - 1
    elif kind == "pluck":
        w = np.sin(2*np.pi*freq*t) + 0.5*np.sin(4*np.pi*freq*t) + 0.25*np.sin(6*np.pi*freq*t)
        w /= 1.75
    elif kind == "pad":
        w = sum(np.sin(2*np.pi*freq*(1+d)*t) for d in (-0.004, 0, 0.004)) / 3
    return w * env(n, a, r) * vol

def noise(dur, r=0.05, vol=0.3, lp=False):
    n = int(dur*SR); w = np.random.uniform(-1, 1, n)
    if lp: w = np.convolve(w, np.ones(8)/8, "same")
    return w * env(n, 0.001, r) * vol

def kick(dur=0.3):
    n = int(dur*SR); t = np.arange(n)/SR
    f = 120*np.exp(-t*25) + 40
    return np.sin(2*np.pi*np.cumsum(f)/SR) * env(n, 0.001, 0.12) * 0.7

def put(buf, start, sig):
    i = int(start*SR); j = min(len(buf), i+len(sig))
    buf[i:j] += sig[:j-i]

def song(name, bpm, bars, melody_fn, length=None):
    beat = 60.0/bpm
    total = length or bars*4*beat
    buf = np.zeros(int(total*SR) + SR)
    melody_fn(buf, beat, bars)
    buf = buf[:int(total*SR)]
    # 首尾 10ms 淡入淡出，循环不爆音
    f = int(0.01*SR); buf[:f] *= np.linspace(0,1,f); buf[-f:] *= np.linspace(1,0,f)
    buf /= max(1e-6, np.max(np.abs(buf))) / 0.8
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(tempfile.gettempdir(), name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((buf*32767).astype(np.int16).tobytes())
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg","-y","-loglevel","error","-i",wav,"-c:a","libvorbis","-q:a","3",out], check=True)
    os.remove(wav)
    print(name, f"{total:.1f}s")

# 和弦进行（MIDI 根音 + 三和弦）
def chord(root, minor=False): return [root, root+(3 if minor else 4), root+7]

def camp(buf, beat, bars):   # 营地：慢，暖，琶音
    prog = [(57,True),(53,False),(48,False),(55,False)]
    for b in range(bars):
        r, m = prog[b % 4]
        for i, n in enumerate(chord(r, m) + [chord(r, m)[1]+12]):
            put(buf, (b*4 + i)*beat, tone(midi(n), beat*2, "pluck", r=0.9, vol=0.25))
        put(buf, b*4*beat, tone(midi(r-12), beat*4, "pad", a=0.4, r=2.5, vol=0.25))

def village(buf, beat, bars):   # 村庄：田园，鲁特琴拨弦
    prog = [(60,False),(65,False),(67,False),(60,False)]
    mel = [72,74,76,79, 77,76,74,72, 74,76,77,79, 76,74,72,72]
    for b in range(bars):
        r, m = prog[b % 4]
        for i in range(4):
            put(buf, (b*4+i)*beat, tone(midi(chord(r)[i % 3]), beat, "pluck", r=0.4, vol=0.18))
        for i in range(4):
            put(buf, (b*4+i)*beat, tone(midi(mel[(b*4+i) % 16]), beat*0.9, "tri", r=0.5, vol=0.2))
        put(buf, b*4*beat, tone(midi(r-24), beat*4, "sine", r=1.5, vol=0.25))

def field(buf, beat, bars):   # 野外：氛围垫 + 稀疏音
    prog = [(50,True),(46,False),(53,False),(48,False)]
    rng = np.random.default_rng(3)
    for b in range(bars):
        r, m = prog[b % 4]
        for n in chord(r, m):
            put(buf, b*4*beat, tone(midi(n), beat*4.5, "pad", a=1.0, r=3.0, vol=0.15))
        if b % 2 == 0:
            put(buf, (b*4 + rng.integers(0,4))*beat, tone(midi(chord(r,m)[rng.integers(0,3)]+24), beat*2, "sine", r=1.2, vol=0.18))

def combat(buf, beat, bars):   # 战斗：小调，快，鼓
    prog = [(57,True),(57,True),(53,False),(55,False)]
    riff = [69,69,72,69, 74,72,69,67]
    for b in range(bars):
        r, m = prog[b % 4]
        for i in range(8):
            put(buf, (b*4 + i*0.5)*beat, tone(midi(r-12 if i % 2 == 0 else r), beat*0.45, "square", r=0.12, vol=0.15))
            put(buf, (b*4 + i*0.5)*beat, tone(midi(riff[i] + (0 if b % 4 < 2 else -2)), beat*0.4, "tri", r=0.15, vol=0.12))
        for i in range(4):
            put(buf, (b*4+i)*beat, kick())
            if i % 2 == 1: put(buf, (b*4+i)*beat, noise(0.2, 0.08, 0.35))
            put(buf, (b*4+i+0.5)*beat, noise(0.05, 0.02, 0.12))

def shop(buf, beat, bars):   # 商店：30 秒洗脑循环，蹦跳大调
    mel = [72,76,79,76, 77,76,74,72, 74,77,81,77, 79,77,76,74,
           72,76,79,84, 83,79,76,74, 72,74,76,77, 76,74,72,72]
    prog = [(60,False),(65,False),(67,False),(60,False)]
    for b in range(bars):
        r, m = prog[b % 4]
        for i in range(4):
            put(buf, (b*4+i)*beat, tone(midi(r-12 if i % 2 == 0 else r-5), beat*0.5, "square", r=0.1, vol=0.13))
            put(buf, (b*4+i+0.5)*beat, tone(midi(chord(r)[1]), beat*0.4, "pluck", r=0.15, vol=0.12))
        for i in range(8):
            n = mel[(b*8 + i) % 32]
            put(buf, (b*4 + i*0.5)*beat, tone(midi(n), beat*0.45, "square", r=0.2, vol=0.12))

def boss(buf, beat, bars):   # 魔王：庄严，小调，合唱垫 + 定音鼓
    prog = [(50,True),(46,False),(48,False),(45,False)]
    for b in range(bars):
        r, m = prog[b % 4]
        for n in chord(r, m) + [r+12]:
            put(buf, b*4*beat, tone(midi(n), beat*4.2, "pad", a=0.3, r=3.0, vol=0.16))
        for i in (0, 1.5, 2, 3):
            put(buf, (b*4+i)*beat, kick(0.5))
        put(buf, (b*4+3)*beat, tone(midi(r+24), beat, "tri", r=0.6, vol=0.15))

def dragon(buf, beat, bars):   # 龙：只有找到白模区的人会听到
    prog = [(52,True),(48,False),(50,False),(47,False)]
    mel = [76,79,83,81, 79,76,74,76, 79,83,86,84, 83,79,76,71]
    for b in range(bars):
        r, m = prog[b % 4]
        for n in chord(r, m):
            put(buf, b*4*beat, tone(midi(n), beat*4.2, "pad", a=0.2, r=2.5, vol=0.14))
        for i in range(4):
            put(buf, (b*4+i)*beat, tone(midi(mel[(b*4+i) % 16]), beat*0.95, "tri", r=0.7, vol=0.18))
            put(buf, (b*4+i)*beat, kick(0.4) * (1.0 if i % 2 == 0 else 0.5))

def ending(buf, beat, bars):   # 结局：干净、温暖、一个 bug 没有
    prog = [(48,False),(55,False),(57,True),(53,False)]
    mel = [72,76,79,76, 74,79,83,79, 76,81,84,81, 77,81,84,88]
    for b in range(bars):
        r, m = prog[b % 4]
        for n in chord(r, m) + [r-12]:
            put(buf, b*4*beat, tone(midi(n), beat*4.4, "pad", a=0.4, r=3.5, vol=0.13))
        for i in range(4):
            put(buf, (b*4+i)*beat, tone(midi(mel[(b*4+i) % 16]), beat*1.6, "pluck", r=1.2, vol=0.16))

np.random.seed(1)
song("camp", 70, 12, camp)
song("village", 100, 16, village)
song("field", 60, 12, field)
song("combat", 140, 16, combat)
song("shop", 128, 16, shop, length=30.0)
song("boss", 84, 16, boss)
song("dragon", 92, 16, dragon)
song("ending", 66, 16, ending)
