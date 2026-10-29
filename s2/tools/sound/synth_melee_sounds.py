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


# The blow's own layers (field_audio.gd BLOW_*): a body hit by the weapon's
# kind, and over it what came of it (head, the end, a thick coat, ice), the
# ground under one that is down, and a weapon about to give.

def tone(n, f, tau, rng, spread=0.02):
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * f * (1 + rng.uniform(-spread, spread)) * t) * np.exp(-t / tau)


def bursts(rng, n, count, f_lo, f_hi, within, tau):
    x = np.zeros(n)
    for _ in range(count):
        at = int(rng.uniform(0.0, within) * SR)
        m = n - at
        x[at:] += svf_bandpass(rng.standard_normal(m), np.full(m, rng.uniform(f_lo, f_hi)), 2.5) * env_ad(m, 0.0003, tau) * rng.uniform(0.4, 1.0)
    return x


def cut(rng):
    """A short edge (knife, broken bottle) going in: bright, quick, wet."""
    n = int(0.28 * SR)
    tick = svf_bandpass(rng.standard_normal(n), np.full(n, 4300.0 + rng.uniform(-400, 400)), 2.2) * env_ad(n, 0.0003, 0.003)
    t = np.arange(n) / SR
    squelch = svf_bandpass(rng.standard_normal(n), 900 + 300 * np.sin(2 * np.pi * rng.uniform(10, 14) * t), 3.0) * env_ad(n, 0.004, 0.045)
    body = onepole_lp(rng.standard_normal(n), 380) * env_ad(n, 0.002, 0.035)
    return finish(0.6 * tick + 1.0 * squelch + 0.9 * body)


def chop(rng):
    """A hatchet biting in: a heavy low chop, a crack and a deep wet tail."""
    n = int(0.45 * SR)
    chop_ = np.tanh(3.0 * sine_drop(n, 190 + rng.uniform(-20, 20), 70, 0.035)) * env_ad(n, 0.001, 0.07)
    crack = svf_bandpass(rng.standard_normal(n), np.full(n, 2200.0), 1.4) * env_ad(n, 0.0004, 0.007)
    wet = onepole_lp(rng.standard_normal(n), 420) * env_ad(n, 0.004, 0.09)
    return finish(1.0 * chop_ + 0.7 * crack + 1.0 * wet)


def clang(rng):
    """A frying pan on a head: a flat slap and a long bright pan ring."""
    n = int(0.6 * SR)
    slap = svf_bandpass(rng.standard_normal(n), np.full(n, 900.0), 1.5) * env_ad(n, 0.0005, 0.012)
    ring = sum(a * tone(n, f, 0.09 + 0.05 * a, rng) for f, a in [(640, 1.0), (1590, 0.7), (2870, 0.45), (4100, 0.25)])
    thump = np.tanh(2.0 * sine_drop(n, 160, 80, 0.03)) * env_ad(n, 0.001, 0.05)
    return finish(0.9 * slap + 0.5 * ring + 0.6 * thump)


def wood(rng):
    """A wooden stake: a dry hollow knock and a little crack."""
    n = int(0.3 * SR)
    knock = np.tanh(2.0 * sine_drop(n, 430 + rng.uniform(-40, 40), 300, 0.02)) * env_ad(n, 0.0005, 0.03)
    crack = svf_bandpass(rng.standard_normal(n), np.full(n, 1800.0 + rng.uniform(-200, 200)), 2.0) * env_ad(n, 0.0004, 0.006)
    flesh = onepole_lp(rng.standard_normal(n), 600) * env_ad(n, 0.003, 0.04)
    return finish(1.0 * knock + 0.7 * crack + 0.8 * flesh)


def shove(rng):
    """Hands (or a gun) shoving a body off: a soft thump and cloth."""
    n = int(0.32 * SR)
    thump = np.tanh(1.6 * sine_drop(n, 120 + rng.uniform(-10, 10), 70, 0.04)) * env_ad(n, 0.004, 0.06)
    cloth = svf_bandpass(rng.standard_normal(n), np.full(n, 1400.0 + rng.uniform(-300, 300)), 0.9) * env_ad(n, 0.01, 0.06)
    return finish(1.0 * thump + 0.8 * cloth, -6.0)


def head(rng):
    """A skull giving: a sharp crack with a crunch in it."""
    n = int(0.25 * SR)
    crack = svf_bandpass(rng.standard_normal(n), np.full(n, 3000.0 + rng.uniform(-300, 300)), 1.8) * env_ad(n, 0.0002, 0.005)
    return finish(1.0 * crack + 0.8 * bursts(rng, n, 7, 1200, 3200, 0.025, 0.006), -4.0)


def finish_layer(rng):
    """The end of one: a wet crunch and a heavy low give."""
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    squelch = svf_bandpass(rng.standard_normal(n), 600 + 250 * np.sin(2 * np.pi * rng.uniform(6, 9) * t), 2.5) * env_ad(n, 0.01, 0.11)
    give = np.tanh(2.6 * sine_drop(n, 110, 45, 0.06)) * env_ad(n, 0.003, 0.1)
    return finish(1.0 * squelch + 0.9 * bursts(rng, n, 9, 900, 2600, 0.06, 0.01) + 0.8 * give, -4.0)


def blocked(rng):
    """An edge stopped by a thick coat: a muffled thump, no flesh."""
    n = int(0.3 * SR)
    thump = onepole_lp(np.tanh(2.0 * sine_drop(n, 140, 90, 0.03)), 500) * env_ad(n, 0.002, 0.05)
    cloth = onepole_lp(rng.standard_normal(n), 900) * env_ad(n, 0.004, 0.03)
    return finish(1.0 * thump + 0.7 * cloth, -5.0)


def shatter(rng):
    """A body frozen in the snow breaking: a crack and ice pieces falling."""
    n = int(0.8 * SR)
    crack = svf_bandpass(rng.standard_normal(n), np.full(n, 2400.0), 1.2) * env_ad(n, 0.0003, 0.01)
    pieces = bursts(rng, n, 26, 2500, 7500, 0.45, 0.012)
    thud = np.tanh(2.0 * sine_drop(n, 130, 60, 0.05)) * env_ad(n, 0.002, 0.08)
    return finish(0.9 * crack + 0.8 * pieces + 0.6 * thud, -4.0)


def stuck(rng):
    """A knife into frozen flesh: a hard tink and a small crack."""
    n = int(0.35 * SR)
    tink = tone(n, 2300 + rng.uniform(-200, 200), 0.05, rng) + 0.5 * tone(n, 5100, 0.03, rng)
    crack = svf_bandpass(rng.standard_normal(n), np.full(n, 3400.0), 2.0) * env_ad(n, 0.0003, 0.006)
    return finish(0.6 * tink + 1.0 * crack, -5.0)


def miss(rng):
    """A blow that met nothing: the air going on past, falling away."""
    return whoosh(rng, 0.3, 0.06, 300, 1500 + rng.uniform(-200, 200), 1.6)


def ground(rng):
    """One that is down: the snow and the ground under it taking the blow."""
    n = int(0.35 * SR)
    thud = onepole_lp(np.tanh(2.4 * sine_drop(n, 95, 48, 0.05)), 350) * env_ad(n, 0.003, 0.07)
    snow = onepole_lp(rng.standard_normal(n), 1500) * env_ad(n, 0.005, 0.04)
    return finish(1.0 * thud + 0.5 * snow, -6.0)


def breaking(rng):
    """A weapon about to give: a loose rattle and a creak in the grip."""
    n = int(0.3 * SR)
    rattle = bursts(rng, n, 4, 1500, 3500, 0.06, 0.004)
    creak = svf_bandpass(rng.standard_normal(n) * (1 + np.sign(np.sin(2 * np.pi * rng.uniform(70, 110) * np.arange(n) / SR))), np.full(n, 700.0), 4.0) * env_ad(n, 0.02, 0.06)
    return finish(1.0 * rattle + 0.8 * creak, -7.0)


BLOW = {"blow_cut": cut, "blow_chop": chop, "blow_thud": lambda r: blunt(r, r.uniform(0.0, 0.6)),
        "blow_clang": clang, "blow_wood": wood, "blow_shove": shove, "blow_stomp": stomp,
        "blow_head": head, "blow_finish": finish_layer, "blow_blocked": blocked, "blow_shatter": shatter,
        "blow_stuck": stuck, "blow_miss": miss, "blow_ground": ground, "blow_breaking": breaking}


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
    # After the five above, so their files come out as they were.
    for group, make in BLOW.items():
        made[group] = [make(rng) for _ in range(4)]
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
