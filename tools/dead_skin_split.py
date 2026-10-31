"""Does the dead's skin stay apart from the living's (decision 432)? Body by body, look by look.

For each body the dead wear (dead_skin_mask.py SOURCES), its colour picture is coloured twice, as the
shaders colour it under the same light:
  the living: the model grade only (dead_vat.gdshaderinc without WEATHERED, tint 0.5);
  the dead:   worn_down's gone-off skin (SKIN_OFF by SKIN_GONE from SKIN_GONE_LEAST, the blotch at its middle) by the skin mask
              as the GPU reads it (128 x 128, linear filter, repeat, through SKIN_EDGE), the grade, then the look's tint: on the
              skin its share of the colour (dead_cast.gd SKIN_TINT) and no brighter than 1, on the clothes by cloth_state.
The colours the shader declares source_color are made linear first, as the engine does. Counted: the
texels the mask reads 0.5 or more at (before SKIN_EDGE). How far the skin has gone off is the kind's middle (dead_cast.gd
TEAR, b) and its least. Blood, dirt and tears are left out (they are judged on the pictures). The values
are read from the shader and scripts (a value not found stops the tool), so this follows them.

Pass (coordinator, 10-31): the dead standing and lying (look "corpse", the dead's wear and tear; the
crawlers are the dead too): (a) median saturation <= 0.6 x the living's, or <= 0.04 (below it the eye sees
grey; the hooded and poncho bodies' living skin is already 0.027 and 0.047 after the grade), (b) median hue
at least 20 degrees towards green of the living's and between 60 and 160. The newly risen: no more
saturated than the living and at least 10 degrees greener (never more alive than the living). The
layered (their cold blue) and the frozen (their frost) are printed beside them, not checked.

--sat-floor S sets that floor (default 0.04, 0 for the ratio alone).

  python -X utf8 -I tools/dead_skin_split.py <repo> [--sat-floor S]
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dead_skin_mask import SOURCES  # noqa: E402

SAT_RATIO = 0.6
HUE_TOWARDS_GREEN = 20.0
HUE_DEAD = (60.0, 160.0)
SAT_FLOOR = 0.04
FRESH_SAT_RATIO = 1.0
FRESH_TOWARDS_GREEN = 10.0
LUM = np.array([0.2126, 0.7152, 0.0722])
# Look drawn -> (the kind whose wear and tear it has, its tint), checked or only printed.
LOOKS = [("dead", "dead", "dead", "dead"), ("corpse", "dead", "corpse", "dead"), ("fresh", "fresh", "fresh", "fresh"),
         ("clothed", "clothed", "clothed", ""), ("frozen", "frozen", "frozen", "")]


def vec3(text):
    return np.array([float(v) for v in text.split(",")], dtype=np.float64)


def found(pattern, text):
    got = re.search(pattern, text)
    if got is None:
        raise SystemExit("dead_skin_split: not found in the sources: " + pattern)
    return got


def read_values(repo):
    s2 = os.path.join(repo, "s2")
    inc = open(os.path.join(s2, "game/actors/dead_vat.gdshaderinc"), encoding="utf-8").read()
    cool = found(r"uniform vec3 grade_cool([^=]*)= vec3\(([^)]*)\)", inc)
    v = {
        "skin_off": vec3(found(r"const vec3 SKIN_OFF = vec3\(([^)]*)\)", inc).group(1)),
        "blotch": float(found(r"off \* \(1\.0 - ([0-9.]+) \* n\)", inc).group(1)),
        "gone": vec3(found(r"const vec2 SKIN_GONE = vec2\(([^)]*)\)", inc).group(1)),
        "gone_least": float(found(r"const float SKIN_GONE_LEAST = ([0-9.]+);", inc).group(1)),
        "edge": vec3(found(r"const vec2 SKIN_EDGE = vec2\(([^)]*)\)", inc).group(1)),
        "cloth_state": float(found(r"uniform float cloth_state[^=]*= ([0-9.]+)", inc).group(1)),
        "sat": float(found(r"uniform float grade_saturation[^=]*= ([0-9.]+)", inc).group(1)),
        "val": float(found(r"uniform float grade_value[^=]*= ([0-9.]+)", inc).group(1)),
        "cool": to_linear(vec3(cool.group(2))) if "source_color" in cool.group(1) else vec3(cool.group(2)),
        "mix": float(found(r"uniform float grade_cool_mix[^=]*= ([0-9.]+)", inc).group(1)),
    }
    cast = open(os.path.join(s2, "game/actors/dead_cast.gd"), encoding="utf-8").read()
    v["tear"] = {k: (vec3(lo)[2], vec3(hi)[2]) for k, lo, hi in
                 re.findall(r'"(\w+)": \[Vector3\(([^)]*)\), Vector3\(([^)]*)\)\]', cast)}
    zomb = open(os.path.join(s2, "game/actors/zombies.gd"), encoding="utf-8").read()
    line = found(r"const TINTS: Dictionary = \{(.*)\}", zomb).group(1)
    v["tints"] = {k: vec3(c) for k, c in re.findall(r'"(\w+)": Color\(([^)]*)\)', line)}
    shares = found(r"const SKIN_TINT: Dictionary = \{(.*)\}", cast).group(1)
    v["skin_tint"] = {k: float(x) for k, x in re.findall(r'"(\w+)": ([0-9.]+)', shares)}
    for kind, _tear, tint, _r in LOOKS:
        if _tear not in v["tear"] or tint not in v["tints"]:
            raise SystemExit("dead_skin_split: no wear and tear or tint for " + kind)
    return v


def smoothstep(a, b, x):
    u = min(max((x - a) / (b - a), 0.0), 1.0)
    return u * u * (3.0 - 2.0 * u)


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1.0 / 2.4) - 0.055)


def model_grade(c, v):
    top = c.max(axis=1, keepdims=True)
    out = (top + (c - top) * v["sat"]) * v["val"]
    return out + (out * v["cool"] - out) * v["mix"]


def sat_hue(c):
    """HSV saturation and hue (degrees, reds above 300 read as below 0) of sRGB colours."""
    mx, mn = c.max(axis=1), c.min(axis=1)
    d = np.maximum(mx - mn, 1e-9)
    r, g, b = c[:, 0], c[:, 1], c[:, 2]
    h = np.where(mx == r, ((g - b) / d) % 6.0, np.where(mx == g, (b - r) / d + 2.0, (r - g) / d + 4.0)) * 60.0
    h = np.where(h > 300.0, h - 360.0, h)
    return (mx - mn) / np.maximum(mx, 1e-9), h


def mask_as_read(mask_png, size):
    """The mask's red at each picture texel's centre: linear filter, repeat (the shader's skin_tex)."""
    m = np.asarray(Image.open(mask_png).convert("RGB"), dtype=np.float64)[..., 0] / 255.0
    n = m.shape[0]
    centres = (np.arange(size) + 0.5) / size * n - 0.5
    yy, xx = np.meshgrid(centres, centres, indexing="ij")
    return ndimage.map_coordinates(m, [yy, xx], order=1, mode="grid-wrap")


def measure(repo, v, sat_floor=SAT_FLOOR):
    rows, failed = [], []
    for body in SOURCES:
        folder = os.path.join(repo, "s2/models/people", body)
        pic = np.asarray(Image.open(os.path.join(folder, "albedo.png")).convert("RGB"), dtype=np.float64) / 255.0
        m_all = mask_as_read(os.path.join(folder, "skin_mask.png"), pic.shape[0])
        inside = m_all >= 0.5
        lin = to_linear(pic[inside])
        e0, e1 = v["edge"][0], v["edge"][1]
        u = np.clip((m_all[inside] - e0) / (e1 - e0), 0.0, 1.0)
        m = (u * u * (3.0 - 2.0 * u))[:, None]
        live_s, live_h = sat_hue(to_srgb(model_grade(lin, v)))
        ls, lh = float(np.median(live_s)), float(np.median(live_h))
        light = (lin @ LUM)[:, None]
        cells = []
        for look, kind, tint, rule in LOOKS:
            lo, hi = v["tear"][kind]
            state = v["tints"][tint] / 0.5
            light_of = float(state @ LUM)
            on_skin = (light_of + (state - light_of) * v["skin_tint"].get(look, 1.0)) / max(1.0, light_of)
            on_cloth = 1.0 + (state - 1.0) * v["cloth_state"]
            for which, b in (("mid", (lo + hi) / 2.0), ("least", lo)):
                off = light * v["skin_off"] * (1.0 - v["blotch"] * 0.5)
                gone = v["gone_least"] + (1.0 - v["gone_least"]) * smoothstep(v["gone"][0], v["gone"][1], b)
                worn = lin + (off - lin) * gone * m
                c = model_grade(worn, v) * (on_cloth + (on_skin - on_cloth) * m)
                s, h = sat_hue(to_srgb(c))
                ds, dh = float(np.median(s)), float(np.median(h))
                if rule == "fresh":
                    ok = ds <= ls * FRESH_SAT_RATIO and dh - lh >= FRESH_TOWARDS_GREEN
                else:
                    ok = ds <= max(ls * SAT_RATIO, sat_floor) and dh - lh >= HUE_TOWARDS_GREEN and HUE_DEAD[0] <= dh <= HUE_DEAD[1]
                checked = rule != ""
                if checked and not ok:
                    failed.append("%s %s %s" % (body, look, which))
                cells.append((look, which, ds / max(ls, 1e-9), dh, ok, checked, ds))
        rows.append((body, int(inside.sum()), float((m_all > 0.02).sum()), ls, lh, cells))
    return rows, failed


def main():
    repo = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else ".")
    v = read_values(repo)
    print("SKIN_OFF %s SKIN_GONE %s blotch %.2f grade sat %.2f val %.2f cool(linear) %s" % (
        np.round(v["skin_off"], 3).tolist(), v["gone"][:2].tolist(), v["blotch"], v["sat"], v["val"], np.round(v["cool"], 3).tolist()))
    floor = float(sys.argv[sys.argv.index("--sat-floor") + 1]) if "--sat-floor" in sys.argv else SAT_FLOOR
    rows, failed = measure(repo, v, floor)
    for body, n, touched, ls, lh, cells in rows:
        text = " | ".join("%s/%s s%.2f(%.3f) h%.0f %s" % (look, which, sr, ds, dh, "ok" if ok else ("FAIL" if checked else "-"))
                          for look, which, sr, dh, ok, checked, ds in cells)
        print("%-20s n=%5d (of %5d touched) living s%.3f h%5.1f | %s" % (body, n, touched, ls, lh, text))
    print("SPLIT %s%s" % ("PASS" if not failed else "FAIL " + ", ".join(failed), " (sat floor %.3f)" % floor if floor else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
