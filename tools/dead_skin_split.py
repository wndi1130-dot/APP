"""Does the dead's skin stay apart from the living's (decision 432)? Body by body, kind by kind.

For each body the dead wear (dead_skin_mask.py SOURCES), the texels its skin mask holds are taken from its
colour picture and coloured twice, as the shaders colour them under the same light:
  the living: the model grade only (dead_vat.gdshaderinc without WEATHERED, tint 0.5);
  the dead:   worn_down's gone-off skin (SKIN_OFF by SKIN_GONE, the blotch at its middle), the grade, then
              the kind's tint as the skin takes it (no brighter than 1).
How far the skin has gone off is the kind's middle (dead_cast.gd TEAR, b) and its least. Blood, dirt and
tears are left out (they are judged on the pictures). The values are read from the shader and scripts, so
this follows them when they change.

Pass (coordinator, 10-31): (a) the dead's median saturation <= 0.6 x the living's; (b) the dead's median hue
at least 20 degrees towards green of the living's and between 60 and 160 (living 0..40 -> dead 60..160).
Checked: the dead (the crawlers and the corpses are the dead too). The other kinds are printed beside them:
the newly risen are meant to be near the living, the layered take their cold blue, the frozen their frost.

  python -X utf8 -I tools/dead_skin_split.py <repo>
"""
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dead_skin_mask import SOURCES  # noqa: E402

CHECKED = ("dead",)
SAT_RATIO = 0.6
HUE_TOWARDS_GREEN = 20.0
HUE_DEAD = (60.0, 160.0)
LUM = np.array([0.2126, 0.7152, 0.0722])


def vec3(text):
    return np.array([float(v) for v in text.split(",")], dtype=np.float64)


def read_values(repo):
    s2 = os.path.join(repo, "s2")
    inc = open(os.path.join(s2, "game/actors/dead_vat.gdshaderinc"), encoding="utf-8").read()
    skin_off = vec3(re.search(r"const vec3 SKIN_OFF = vec3\(([^)]*)\)", inc).group(1))
    blotch = float(re.search(r"off \* \(1\.0 - ([0-9.]+) \* n\)", inc).group(1))
    gone = vec3(re.search(r"const vec2 SKIN_GONE = vec2\(([^)]*)\)", inc).group(1))
    grade = {
        "sat": float(re.search(r"uniform float grade_saturation[^=]*= ([0-9.]+)", inc).group(1)),
        "val": float(re.search(r"uniform float grade_value[^=]*= ([0-9.]+)", inc).group(1)),
        "cool": vec3(re.search(r"uniform vec3 grade_cool[^=]*= vec3\(([^)]*)\)", inc).group(1)),
        "mix": float(re.search(r"uniform float grade_cool_mix[^=]*= ([0-9.]+)", inc).group(1)),
    }
    cast = open(os.path.join(s2, "game/actors/dead_cast.gd"), encoding="utf-8").read()
    tear = {}
    for kind, lo, hi in re.findall(r'"(\w+)": \[Vector3\(([^)]*)\), Vector3\(([^)]*)\)\]', cast):
        tear[kind] = (vec3(lo)[2], vec3(hi)[2])
    zomb = open(os.path.join(s2, "game/actors/zombies.gd"), encoding="utf-8").read()
    line = re.search(r"const TINTS: Dictionary = \{(.*)\}", zomb).group(1)
    tints = {k: vec3(v) for k, v in re.findall(r'"(\w+)": Color\(([^)]*)\)', line)}
    return skin_off, (blotch, gone), grade, tear, tints


def smoothstep(a, b, x):
    u = min(max((x - a) / (b - a), 0.0), 1.0)
    return u * u * (3.0 - 2.0 * u)


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1.0 / 2.4) - 0.055)


def model_grade(c, g):
    v = c.max(axis=1, keepdims=True)
    out = (v + (c - v) * g["sat"]) * g["val"]
    return out + (out * g["cool"] - out) * g["mix"]


def sat_hue(c):
    """HSV saturation and hue (degrees, reds above 300 read as below 0) of sRGB colours."""
    mx, mn = c.max(axis=1), c.min(axis=1)
    d = np.maximum(mx - mn, 1e-9)
    r, g, b = c[:, 0], c[:, 1], c[:, 2]
    h = np.where(mx == r, ((g - b) / d) % 6.0, np.where(mx == g, (b - r) / d + 2.0, (r - g) / d + 4.0)) * 60.0
    h = np.where(h > 300.0, h - 360.0, h)
    return (mx - mn) / np.maximum(mx, 1e-9), h


def main():
    repo = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
    skin_off, (blotch, gone), grade, tear, tints = read_values(repo)
    print("SKIN_OFF %s SKIN_GONE %s blotch %.2f grade sat %.2f val %.2f" % (np.round(skin_off, 3).tolist(), gone[:2].tolist(), blotch, grade["sat"], grade["val"]))
    failed = []
    for body in SOURCES:
        folder = os.path.join(repo, "s2/models/people", body)
        pic = np.asarray(Image.open(os.path.join(folder, "albedo.png")).convert("RGB"), dtype=np.float64) / 255.0
        mask = np.asarray(Image.open(os.path.join(folder, "skin_mask.png")).convert("L").resize(pic.shape[1::-1], Image.NEAREST)) > 127
        lin = to_linear(pic[mask])
        live_s, live_h = sat_hue(to_srgb(model_grade(lin, grade)))
        ls, lh = float(np.median(live_s)), float(np.median(live_h))
        light = (lin @ LUM)[:, None]
        cells = []
        for kind in ("dead", "clothed", "fresh", "frozen"):
            lo, hi = tear[kind]
            state = tints[kind] / 0.5
            on_skin = state / max(1.0, float(state @ LUM))
            for which, b in (("mid", (lo + hi) / 2.0), ("least", lo)):
                off = light * skin_off * (1.0 - blotch * 0.5)
                c = model_grade(lin + (off - lin) * smoothstep(gone[0], gone[1], b), grade) * on_skin
                s, h = sat_hue(to_srgb(c))
                ds, dh = float(np.median(s)), float(np.median(h))
                ok = ds <= ls * SAT_RATIO and dh - lh >= HUE_TOWARDS_GREEN and HUE_DEAD[0] <= dh <= HUE_DEAD[1]
                if kind in CHECKED and not ok:
                    failed.append("%s %s %s" % (body, kind, which))
                cells.append("%s/%s s%.2f h%.0f %s" % (kind, which, ds / max(ls, 1e-9), dh, "ok" if ok else ("FAIL" if kind in CHECKED else "-")))
        print("%-20s n=%5d living s%.3f h%5.1f | %s" % (body, int(mask.sum()), ls, lh, " | ".join(cells)))
    print("SPLIT %s" % ("PASS" if not failed else "FAIL " + ", ".join(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
