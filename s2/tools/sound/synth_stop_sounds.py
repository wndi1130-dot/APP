"""The stop's sounds, made here from numbers (no recording, no file from
elsewhere): the steam train's brakes as it comes to its stand, and the paper
of the stop card unfolding and folding away (정차 연출, 결정 421-3).

The brakes are four layers, as a steam train braking hard sounds:
  1. the wheels over the rail joints, da-dum, slower and slower;
  2. the brake squeal, high and metallic, trembling and growing, bending
     down as the train stands;
  3. the couplers running in when it stops, a few clunks;
  4. steam and air let out after, a hiss.
The train stands STOP_AT seconds into the file (field_audio.gd
BRAKE_STAND_AT; the stop scene and the field's arrival both start the sound
so its stand falls where the train's does).

    python s2/tools/sound/synth_stop_sounds.py

Same numbers, same files (fixed seeds). Writes mono 16-bit 44.1 kHz wav:
  s2/audio/train_brake/brake.wav
  s2/audio/paper/paper_open.wav, s2/audio/paper/paper_fold.wav
"""

import pathlib
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = pathlib.Path(__file__).resolve().parents[2]

BRAKE_LEN = 4.6
STOP_AT = 2.4
# The loudest sample, the same as the brake sound it replaces (0.708, −3 dB),
# so the field's BRAKE_LOUD stays the loudness it was set for.
BRAKE_PEAK = 0.708
PAPER_PEAK = 0.35


def _t(seconds):
    return np.arange(int(seconds * SR)) / SR


def _band(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def _high(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, btype="highpass", fs=SR, output="sos"), x)


def _low(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, btype="lowpass", fs=SR, output="sos"), x)


def _wander(rng, n, rate_hz):
    """A slow random line, about -1..1, changing at about rate_hz."""
    raw = rng.standard_normal(n)
    smooth = _low(raw, rate_hz, order=2)
    return smooth / (np.abs(smooth).max() + 1e-9)


def _add(out, at, piece):
    i = int(at * SR)
    if i >= len(out):
        return
    j = min(len(out), i + len(piece))
    out[i:j] += piece[: j - i]


def _speed(t):
    """The train's speed, 1 at the start of the file, 0 at the stand."""
    return np.clip(1.0 - t / STOP_AT, 0.0, 1.0) ** 0.7


def _wheel_click(rng, gain):
    t = _t(0.11)
    f1 = 95.0 * rng.uniform(0.9, 1.1)
    thump = np.sin(2 * np.pi * f1 * t) * np.exp(-t / 0.02)
    ring = sum(a * np.sin(2 * np.pi * f * rng.uniform(0.97, 1.03) * t) * np.exp(-t / tau)
               for f, a, tau in [(430, 0.5, 0.013), (1030, 0.35, 0.009), (2150, 0.2, 0.006)])
    tick = _high(rng.standard_normal(len(t)), 2500) * np.exp(-t / 0.0025)
    return gain * (0.9 * thump + 0.6 * ring + 0.35 * tick)


def _clunk(rng, gain):
    t = _t(0.4)
    thud = np.sin(2 * np.pi * 62 * t) * np.exp(-t / 0.07) + 0.5 * np.sin(2 * np.pi * 118 * t) * np.exp(-t / 0.05)
    clank = sum(a * np.sin(2 * np.pi * f * rng.uniform(0.98, 1.02) * t) * np.exp(-t / tau)
                for f, a, tau in [(610, 0.5, 0.05), (940, 0.4, 0.04), (1480, 0.3, 0.03), (2230, 0.2, 0.02)])
    click = _high(rng.standard_normal(len(t)), 1500) * np.exp(-t / 0.003)
    return gain * (1.0 * thud + 0.55 * clank + 0.3 * click)


def brake():
    rng = np.random.default_rng(416)
    n = int(BRAKE_LEN * SR)
    t = np.arange(n) / SR
    v = _speed(t)

    # 1. Wheels over the joints: a near bogie's da-dum and a far one's, the
    #    beat stretching as the train slows.
    wheels = np.zeros(n)
    at = 0.06
    while at < STOP_AT - 0.12:
        sp = float(_speed(np.array([at]))[0])
        if sp < 0.1:
            break
        period = 0.30 / sp
        gap = 0.085 / sp
        loud = 0.45 + 0.55 * sp
        _add(wheels, at, _wheel_click(rng, loud))
        _add(wheels, at + gap, _wheel_click(rng, loud * 0.85))
        _add(wheels, at + period * 0.5, _wheel_click(rng, loud * 0.4))
        _add(wheels, at + period * 0.5 + gap, _wheel_click(rng, loud * 0.35))
        at += period

    # 2. The squeal: two wheels' voices, trembling, growing to the stand and
    #    bending down as it comes, then choked off.
    rise = np.clip((t - 0.2) / (STOP_AT - 0.35), 0.0, 1.0) ** 1.6
    choke = np.clip(1.0 - (t - STOP_AT) / 0.09, 0.0, 1.0)
    env = rise * choke
    bend = np.where(t > STOP_AT - 0.2, 1.0 - 0.18 * (1.0 - np.exp(-np.clip(t - (STOP_AT - 0.2), 0, None) / 0.08)), 1.0)
    squeal = np.zeros(n)
    for base, start, am_hz, amp, seed_off in [(2380.0, 0.2, 13.5, 1.0, 0), (3170.0, 0.9, 19.0, 0.55, 1)]:
        jitter = _wander(rng, n, 9.0)
        f = base * (1.0 + 0.03 * t / STOP_AT) * (1.0 + 0.009 * np.sin(2 * np.pi * 6.2 * t + seed_off) + 0.005 * jitter) * bend
        phase = 2 * np.pi * np.cumsum(f) / SR
        voice = sum(a * np.sin(k * phase + rng.uniform(0, 2 * np.pi))
                    for k, a in [(1.0, 1.0), (1.503, 0.5), (2.012, 0.3), (2.66, 0.16), (3.31, 0.08)])
        tremble = 1.0 + 0.45 * np.sin(2 * np.pi * am_hz * t + 0.9 * np.sin(2 * np.pi * 0.7 * t)) * (0.6 + 0.4 * _wander(rng, n, 3.0))
        gate = np.clip((t - start) / 0.4, 0.0, 1.0)
        squeal += amp * voice * tremble * gate
    scrape = _band(rng.standard_normal(n), 1800, 6000) * 0.9
    squeal = (squeal / 2.2 + scrape) * env

    # 3. The couplers running in as the train stands.
    clunks = np.zeros(n)
    for dt, g in [(0.03, 1.0), (0.19, 0.7), (0.33, 0.45), (0.45, 0.28)]:
        _add(clunks, STOP_AT + dt, _clunk(rng, g))

    # 4. Steam and air let out, after.
    hiss = _low(_high(rng.standard_normal(n), 1200, order=3), 8000)
    h0 = STOP_AT + 0.32
    attack = np.clip((t - h0) / 0.05, 0.0, 1.0)
    release = np.where(t > h0 + 1.3, np.exp(-(t - h0 - 1.3) / 0.45), 1.0)
    flutter = 1.0 + 0.15 * np.sin(2 * np.pi * 7.0 * t) * (0.5 + 0.5 * _wander(rng, n, 2.0))
    hiss = hiss / (np.abs(hiss).max() + 1e-9) * attack * release * flutter
    puff = _low(rng.standard_normal(n), 500) * np.exp(-np.clip(t - h0, 0, None) / 0.06) * (t >= h0)

    mix = 0.5 * wheels / (np.abs(wheels).max() + 1e-9) \
        + 0.82 * squeal / (np.abs(squeal).max() + 1e-9) \
        + 0.75 * clunks / (np.abs(clunks).max() + 1e-9) \
        + 0.28 * hiss \
        + 0.12 * puff / (np.abs(puff).max() + 1e-9)
    return _finish(mix, BRAKE_PEAK)


def _crackle(rng, seconds, density, lo=1500, hi=7500):
    """Paper: many tiny dry clicks."""
    n = int(seconds * SR)
    out = np.zeros(n)
    count = int(density * seconds)
    for _ in range(count):
        i = rng.integers(0, max(1, n - 200))
        k = rng.integers(20, 160)
        out[i:i + k] += rng.uniform(-1, 1) * np.exp(-np.arange(k) / (k / 4.0))
    return _band(out, lo, hi)


def _scuff(rng, seconds):
    n = int(seconds * SR)
    return _band(rng.standard_normal(n), 600, 4000)


def paper_open():
    """The sheet slides in folded, unfolds with a flap, and is laid down."""
    rng = np.random.default_rng(4211)
    n = int(0.62 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    slide = _scuff(rng, 0.62) * np.clip(t / 0.06, 0, 1) * np.clip((0.32 - t) / 0.1, 0, 1) * 0.35
    out += slide + _crackle(rng, 0.62, 260) * np.clip((0.3 - t) / 0.3, 0, 1) * 0.4
    flap = _crackle(rng, 0.12, 1800, 2000, 8000) * np.exp(-_t(0.12) / 0.04)
    _add(out, 0.27, flap * 1.2)
    thump = _band(rng.standard_normal(int(0.06 * SR)), 120, 420) * np.exp(-_t(0.06) / 0.015)
    _add(out, 0.30, thump * 0.9)
    tap = _band(rng.standard_normal(int(0.05 * SR)), 300, 2500) * np.exp(-_t(0.05) / 0.01)
    _add(out, 0.50, tap * 0.5)
    return _finish(out, PAPER_PEAK)


def paper_fold():
    """The sheet is creased shut and slid away."""
    rng = np.random.default_rng(4212)
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    crease = _crackle(rng, 0.09, 2200, 2500, 9000) * np.exp(-_t(0.09) / 0.025)
    _add(out, 0.01, crease * 1.3)
    slide = _scuff(rng, 0.45) * np.clip((t - 0.08) / 0.05, 0, 1) * np.clip((0.42 - t) / 0.2, 0, 1) * 0.3
    out += slide + _crackle(rng, 0.45, 200) * np.clip((t - 0.08) / 0.1, 0, 1) * np.clip((0.4 - t) / 0.3, 0, 1) * 0.3
    return _finish(out, PAPER_PEAK)


def _finish(x, peak):
    # A soft knee so nothing clips, a few ms up and down at the ends, then the peak.
    x = np.tanh(1.2 * x / (np.abs(x).max() + 1e-9)) / np.tanh(1.2)
    fade = int(0.006 * SR)
    x[:fade] *= np.linspace(0.0, 1.0, fade)
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    return x / (np.abs(x).max() + 1e-9) * peak


def _write(path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(path.relative_to(ROOT), f"{len(x) / SR:.2f}s", f"peak {np.abs(x).max():.3f}", f"rms {np.sqrt((x ** 2).mean()):.4f}")


if __name__ == "__main__":
    _write(ROOT / "audio/train_brake/brake.wav", brake())
    _write(ROOT / "audio/paper/paper_open.wav", paper_open())
    _write(ROOT / "audio/paper/paper_fold.wav", paper_fold())
