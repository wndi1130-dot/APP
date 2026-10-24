"""The wind's many sounds, made here from numbers (no recording, no file from
elsewhere; 결정 434 1절: 「바람코드 수정안됬어? 패턴 여러게 + 오프닝
달라지게 했으면 좋겠고」). The one shipped wind file sits almost all in one
band (500-1500 Hz), so every bed, gust and howl had the same grain. These
differ in band, motion and grain:

beds (s2/audio/wind/wind_<name>.wav, looped by field_audio.gd):
  breeze   soft and low, slow swells
  gusty    dark under, bright when it gusts, uneven gusts
  low      a low moan, two narrow bands wandering against each other
  whistle  thin whistles through gaps, coming and going over a soft floor
  forest   leaf hiss and rustle through trees, swelling
  blizzard dense roar, rumble and hiss, fast turbulence

gusts (s2/audio/wind_gust/gust_<name>.wav, a stretch of one laid over the bed):
  rise     an airy sweep up and down
  whistle  a sliding whistle
  low      a low howl

    python s2/tools/sound/synth_wind.py

Same numbers, same files (fixed seeds). Mono 16-bit 22.05 kHz (wind needs no
more; the build compresses wav). Each is as loud to the ear as the shipped
wind.ogg (RMS through a 200-6000 Hz band: REF_LOUD).
"""

import pathlib
import wave

import numpy as np
from scipy import signal

SR = 22050
ROOT = pathlib.Path(__file__).resolve().parents[2]
BED_LEN = 12.0
GUST_LEN = 9.0
XFADE = 0.6
# wind.ogg decoded as the game decodes it, RMS through 200-6000 Hz (2026-10-25).
REF_LOUD = 0.0131


def noise(n, seed):
    return np.random.default_rng(seed).standard_normal(n)


def pink(n, seed):
    spec = np.fft.rfft(noise(n, seed))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spec[1:] /= np.sqrt(f[1:])
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    return x / np.std(x)


def brown(n, seed):
    x = signal.lfilter([1.0], [1.0, -0.995], noise(n, seed))
    return x / np.std(x)


def slow(n, hz, seed, lo=-1.0, hi=1.0):
    """A smooth wandering curve, about `hz` turns a second."""
    rng = np.random.default_rng(seed)
    pts = max(4, int(n / SR * hz) + 4)
    knots = rng.uniform(lo, hi, pts)
    t = np.linspace(0, pts - 3, n)
    i = np.floor(t).astype(int)
    u = t - i
    # Catmull-Rom through the knots: smooth, no corners.
    p0, p1, p2, p3 = knots[i], knots[i + 1], knots[i + 2], knots[np.minimum(i + 3, pts - 1)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u ** 2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)


def band(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], "bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def low(x, hi, order=2):
    return signal.sosfilt(signal.butter(order, hi, "lowpass", fs=SR, output="sos"), x)


def high(x, lo, order=2):
    return signal.sosfilt(signal.butter(order, lo, "highpass", fs=SR, output="sos"), x)


def moving_band(x, fc, q, block=128):
    """A narrow band whose centre follows fc (Hz, per sample)."""
    out = np.zeros_like(x)
    zi = np.zeros(2)
    for s in range(0, len(x), block):
        f = float(np.clip(fc[min(s + block // 2, len(fc) - 1)], 40.0, SR * 0.45))
        w0 = 2 * np.pi * f / SR
        alpha = np.sin(w0) / (2 * q)
        b = np.array([alpha, 0.0, -alpha])
        a = np.array([1 + alpha, -2 * np.cos(w0), 1 - alpha])
        b, a = b / a[0], a / a[0]
        out[s:s + block], zi = signal.lfilter(b, a, x[s:s + block], zi=zi)
    return out


def gust_env(n, seed, base=0.25):
    """Uneven gusts: quick to rise, slow to die, at random gaps."""
    rng = np.random.default_rng(seed)
    env = np.full(n, base)
    t = rng.uniform(0.0, 1.5)
    while t < n / SR:
        rise, fall = rng.uniform(0.3, 1.0), rng.uniform(0.8, 2.6)
        peak = rng.uniform(0.5, 1.0)
        a, m, e = int(t * SR), int((t + rise) * SR), int((t + rise + fall) * SR)
        if m < n:
            env[a:m] = np.maximum(env[a:m], base + (peak - base) * np.sin(0.5 * np.pi * np.linspace(0, 1, m - a)))
        if m < n:
            seg = env[m:min(e, n)]
            env[m:min(e, n)] = np.maximum(seg, base + (peak - base) * np.cos(0.5 * np.pi * np.linspace(0, 1, e - m))[:len(seg)])
        t += rise + fall + rng.uniform(0.2, 2.5)
    return env


def loud(x):
    return float(np.sqrt(np.mean(band(x, 200, 6000, 1) ** 2)))


def loop_ready(x, n):
    """x is n + XFADE long: its tail laid over its head, so the end runs into the start."""
    xf = int(XFADE * SR)
    out = x[:n].copy()
    k = np.linspace(0, 1, xf)
    out[:xf] = x[:xf] * np.sin(0.5 * np.pi * k) + x[n:n + xf] * np.cos(0.5 * np.pi * k)
    return out


def save(path, x):
    x = x / max(loud(x), 1e-9) * REF_LOUD
    peak = np.max(np.abs(x))
    if peak > 0.89:
        x = x * 0.89 / peak
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print(f"{path.relative_to(ROOT)} {len(x) / SR:.1f}s loud {loud(x):.4f} peak {np.max(np.abs(x)):.3f}")


def bed(name, n):
    m = n + int(XFADE * SR)
    if name == "breeze":
        x = high(low(pink(m, 11), 900), 70)
        x *= 0.65 + 0.35 * slow(m, 0.15, 12)
        x += 0.4 * band(pink(m, 13), 300, 700) * np.clip(slow(m, 0.1, 14, 0.0, 1.0), 0, 1)
    elif name == "gusty":
        base = noise(m, 21)
        env = gust_env(m, 22)
        x = low(base, 700) * (0.6 + 0.4 * env) + 0.8 * band(base, 600, 3000) * env ** 1.5
    elif name == "low":
        f1 = 270 + 60 * slow(m, 0.12, 31)   # low, yet in a phone speaker's reach
        f2 = f1 * 1.47 + 18 * slow(m, 0.2, 32)
        x = 0.12 * low(brown(m, 33), 250)
        x += moving_band(noise(m, 34), f1, 10) * 3.0 + moving_band(noise(m, 35), f2, 12) * 1.8
        x *= 0.55 + 0.45 * np.clip(slow(m, 0.09, 36, 0.0, 1.0), 0, 1)
    elif name == "whistle":
        x = 0.35 * band(noise(m, 41), 400, 2500) * (0.7 + 0.3 * slow(m, 0.2, 42))
        gate = np.clip(slow(m, 0.25, 43, -0.6, 1.2), 0, 1) ** 2
        f = 1150 + 380 * slow(m, 0.18, 44)
        x += gate * (moving_band(noise(m, 45), f, 45) * 9.0 + moving_band(noise(m, 46), f * 1.62, 60) * 5.0)
    elif name == "forest":
        swell = np.clip(0.55 + 0.45 * slow(m, 0.12, 51), 0.1, 1.0)
        x = band(noise(m, 52), 1500, 7000) * (0.5 + 0.5 * swell)
        x += 0.4 * band(noise(m, 53), 200, 700) * swell
        rng = np.random.default_rng(54)
        rustle = np.zeros(m)
        src = band(noise(m, 55), 2000, 6000)
        t = 0
        while t < m:
            k = swell[t] ** 2
            t += int(SR * rng.uniform(0.004, 0.06) / max(k, 0.05))
            g = int(SR * rng.uniform(0.008, 0.04))
            if t + g < m:
                rustle[t:t + g] += src[t:t + g] * np.hanning(g) * rng.uniform(0.6, 2.0)
        x += rustle * 1.4
    elif name == "blizzard":
        turb = 0.6 + 0.4 * slow(m, 4.0, 61)
        swell = 0.7 + 0.3 * slow(m, 0.2, 62)
        x = low(noise(m, 63), 2500) + 0.9 * low(brown(m, 64), 180) + 0.5 * band(noise(m, 65), 3000, 8000)
        x += 0.8 * moving_band(noise(m, 66), 360 + 60 * slow(m, 0.15, 67), 8)
        x *= turb * swell
    else:
        raise ValueError(name)
    return loop_ready(x, n)


def gust(name, n):
    t = np.arange(n) / SR
    if name == "rise":
        fc = 800 + 500 * np.sin(2 * np.pi * t / 3.4) + 150 * slow(n, 0.6, 71)
        x = moving_band(noise(n, 72), fc, 3) * 1.5 + 0.3 * low(noise(n, 73), 500)
    elif name == "whistle":
        fc = 1250 + 520 * slow(n, 0.45, 81)
        x = moving_band(noise(n, 82), fc, 25) * 6.0 + 0.3 * band(noise(n, 83), 500, 2500)
    elif name == "low":
        fc = 320 + 100 * slow(n, 0.35, 91)
        x = moving_band(noise(n, 92), fc, 9) * 3.0 + 0.15 * low(brown(n, 93), 200)
    else:
        raise ValueError(name)
    return x


def main():
    for name in ["breeze", "gusty", "low", "whistle", "forest", "blizzard"]:
        save(ROOT / "audio" / "wind" / f"wind_{name}.wav", bed(name, int(BED_LEN * SR)))
    for name in ["rise", "whistle", "low"]:
        save(ROOT / "audio" / "wind_gust" / f"gust_{name}.wav", gust(name, int(GUST_LEN * SR)))


if __name__ == "__main__":
    main()
