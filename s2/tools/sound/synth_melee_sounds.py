"""Melee swing and blow sounds, made from noise and sine waves (no recording,
no downloaded file). Mono 22050 Hz 16-bit like the other field sounds.

python -X utf8 -I s2/tools/sound/synth_melee_sounds.py s2/audio [preview.wav]
The seed is fixed: run again, the same files come out.
"""
import os
import sys
import wave

import numpy as np

SR = 22050


def svf_bandpass(x, f_c, q):
    """State-variable band-pass with a per-sample centre frequency (Hz array)."""
    y = np.zeros_like(x)
    low = band = 0.0
    damp = 1.0 / q
    for i in range(len(x)):
        f = 2.0 * np.sin(np.pi * min(f_c[i], SR * 0.45) / SR)
        high = x[i] - low - damp * band
        band += f * high
        low += f * band
        y[i] = band
    return y


def onepole_lp(x, f):
    a = np.exp(-2.0 * np.pi * f / SR)
    y = np.zeros_like(x)
    s = 0.0
    for i in range(len(x)):
        s = (1 - a) * x[i] + a * s
        y[i] = s
    return y


def env_ad(n, attack, decay_tau):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / decay_tau)
    return a * d


def sine_drop(n, f0, f1, tau):
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / tau)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


def finish(x, peak_db=-3.0):
    x = x - np.mean(x)
    fade_in = min(len(x), int(0.002 * SR))
    x[:fade_in] *= np.linspace(0, 1, fade_in)
    fade_out = min(len(x), int(0.012 * SR))
    x[-fade_out:] *= np.linspace(1, 0, fade_out)
    peak = np.max(np.abs(x)) + 1e-9
    return x * (10 ** (peak_db / 20) / peak)


def whoosh(rng, length, peak_at, f_lo, f_hi, q):
    """Air past a moving weapon: noise through a band that rises to the
    fastest point of the arc and falls after it."""
    n = int(length * SR)
    t = np.arange(n) / SR
    k = np.exp(-((t - peak_at) / (length * 0.28)) ** 2)
    f_c = f_lo + (f_hi - f_lo) * k
    x = svf_bandpass(rng.standard_normal(n), f_c, q)
    amp = k ** 1.4
    return finish(x * amp, -6.0)


def blunt(rng, ring):
    """A stick on a head: a crack, a low thump that drops in pitch, a dull
    slap, and for steel a short dark ring."""
    n = int(0.42 * SR)
    crack = svf_bandpass(rng.standard_normal(n), np.full(n, 2600.0), 1.2) * env_ad(n, 0.0005, 0.006)
    # Driven into tanh so the thump has harmonics a phone speaker can play
    # (they give little below some 200 Hz).
    thump = np.tanh(2.8 * sine_drop(n, 170 + rng.uniform(-15, 15), 72, 0.03)) * env_ad(n, 0.001, 0.06)
    slap = svf_bandpass(rng.standard_normal(n), np.full(n, 520.0 + rng.uniform(-60, 60)), 1.6) * env_ad(n, 0.001, 0.035)
    flesh = onepole_lp(rng.standard_normal(n), 650) * env_ad(n, 0.004, 0.05)
    x = 0.7 * crack + 0.6 * thump + 1.2 * slap + 1.0 * flesh
    if ring > 0:
        t = np.arange(n) / SR
        partials = [(1180, 1.0), (2830, 0.6), (4310, 0.35)]
        r = sum(a * np.sin(2 * np.pi * f * (1 + rng.uniform(-0.02, 0.02)) * t) for f, a in partials)
        x += ring * 0.13 * r * env_ad(n, 0.001, 0.06)
    return finish(x)


def blade(rng):
    """An edge going in: a short bright tick, a wet chop lower down and a
    squelch that tails off."""
    n = int(0.36 * SR)
    tick = svf_bandpass(rng.standard_normal(n), np.full(n, 3800.0), 2.0) * env_ad(n, 0.0004, 0.004)
    chop = np.tanh(2.2 * sine_drop(n, 230 + rng.uniform(-20, 20), 110, 0.02)) * env_ad(n, 0.001, 0.04)
    t = np.arange(n) / SR
    wobble = 700 + 350 * np.sin(2 * np.pi * (9 + rng.uniform(-2, 2)) * t)
    squelch = svf_bandpass(rng.standard_normal(n), wobble, 3.0) * env_ad(n, 0.006, 0.07)
    body = onepole_lp(rng.standard_normal(n), 300) * env_ad(n, 0.003, 0.05)
    return finish(0.5 * tick + 0.9 * chop + 0.9 * squelch + 1.1 * body)


def stomp(rng):
    """A boot coming down on a body on the ground: a heavy low thud with a
    crunch in it."""
    n = int(0.45 * SR)
    thud = np.tanh(3.2 * sine_drop(n, 150 + rng.uniform(-10, 10), 58, 0.04)) * env_ad(n, 0.002, 0.075)
    crunch = np.zeros(n)
    for _ in range(6):
        at = int(rng.uniform(0.002, 0.03) * SR)
        m = n - at
        crunch[at:] += svf_bandpass(rng.standard_normal(m), np.full(m, rng.uniform(1200, 2400)), 2.5) * env_ad(m, 0.0003, 0.008) * rng.uniform(0.4, 1.0)
    wet = onepole_lp(rng.standard_normal(n), 520) * env_ad(n, 0.005, 0.07)
    return finish(0.7 * thud + 0.9 * crunch + 1.0 * wet)


def write(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = np.clip(x * 32767, -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    out = sys.argv[1]
    rng = np.random.default_rng(20261026)
    made = {}
    made["swing_light"] = [whoosh(rng, 0.22, 0.08, 500, 2600 + 300 * i, 2.2) for i in range(3)]
    made["swing_heavy"] = [whoosh(rng, 0.36, 0.19, 260, 1300 + 200 * i, 1.8) for i in range(3)]
    made["hit_blunt"] = [blunt(rng, ring) for ring in (1.0, 0.6, 0.0)]
    made["hit_blade"] = [blade(rng) for _ in range(3)]
    made["hit_stomp"] = [stomp(rng) for _ in range(2)]
    for group, clips in made.items():
        for i, x in enumerate(clips):
            p = os.path.join(out, group, "%s_%02d.wav" % (group, i + 1))
            write(p, x)
            print(p, "%.3fs" % (len(x) / SR), "peak %.2f" % np.max(np.abs(x)))
    if len(sys.argv) > 2:
        gap = np.zeros(int(0.35 * SR))
        seq = []
        for group in ["swing_light", "hit_blade", "swing_heavy", "hit_blunt", "hit_stomp"]:
            for x in made[group]:
                seq += [x, gap]
        write(sys.argv[2], np.concatenate(seq))


if __name__ == "__main__":
    main()
