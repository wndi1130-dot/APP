"""Does the dead's skin stay apart from the living's (decision 432)? Body by body, look by look.

For each body the dead wear (dead_skin_mask.py SOURCES), its colour picture is coloured twice, as the
shaders colour it under the same light:
  the living: the model grade only (dead_vat.gdshaderinc without WEATHERED, tint 0.5);
  the dead:   the mask as the GPU reads it (128 x 128, linear filter, repeat; red through SKIN_EDGE, green
              the hood turned HEAD_CLOTH), the light cloth soiled, worn_down's gone-off skin (SKIN_OFF by
              SKIN_GONE from the look's SKIN_GONE_LEAST, the blotch at its middle), the grade, then the look's
              tint: on the skin its share of the colour (dead_cast.gd SKIN_TINT) and no brighter than 1, on the
              clothes by cloth_state.
The colours the shader declares source_color are made linear first, as the engine does. Counted: the
texels the mask's red reads 0.5 or more at. How far the skin has gone off is the kind's middle (dead_cast.gd
TEAR, b) and its least. Blood, dirt and tears are left out (they are judged on the pictures). The values are
read from the shader and scripts; one not found, or not a plain number, stops the tool.

Pass (coordinator, 10-31): the dead standing (look "dead") and every kind lying dead for good (look
"corpse", with that kind's wear and tear; the crawlers are the dead too): (a) median saturation <= 0.6 x
the living's, or <= 0.04 (below it the eye sees grey; the hooded and poncho bodies' living skin is already
0.021 and 0.025 after the grade), (b) median hue at least 20 degrees towards green of the living's and
between 60 and 160. The newly risen: no more saturated than the living and at least 10 degrees greener
(never more alive than the living). The layered (their cold blue) and the frozen (their frost) standing are
printed beside them, not checked.

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
NUMBER = r"(-?[0-9]+(?:\.[0-9]+)?)"
# (label, the kind whose wear and tear it has, the look drawn (its tint and shares), the rule).
LOOKS = [("dead", "dead", "dead", "dead"), ("corpse", "dead", "corpse", "dead"),
         ("corpse/fresh", "fresh", "corpse", "dead"), ("corpse/clothed", "clothed", "corpse", "dead"),
         ("corpse/frozen", "frozen", "corpse", "dead"), ("fresh", "fresh", "fresh", "fresh"),
         ("clothed", "clothed", "clothed", ""), ("frozen", "frozen", "frozen", "")]


def vec(text, n):
    parts = [p.strip() for p in text.split(",")]
    if len(parts) != n or not all(re.fullmatch(NUMBER, p) for p in parts):
        raise SystemExit("dead_skin_split: not %d plain numbers: %s" % (n, text))
    return np.array([float(p) for p in parts], dtype=np.float64)


def found(pattern, text):
    got = re.search(pattern, text)
    if got is None:
        raise SystemExit("dead_skin_split: not found in the sources: " + pattern)
    return got


def by_look(name, text):
    body = found(r"const " + name + r": Dictionary = \{([^}]*)\}", text).group(1)
    items = [i.strip() for i in body.split(",") if i.strip()]
    out = {}
    for item in items:
        got = re.fullmatch(r'"(\w+)": ' + NUMBER, item)
        if got is None:
            raise SystemExit("dead_skin_split: %s: not a look and a plain number: %s" % (name, item))
        out[got.group(1)] = float(got.group(2))
    return out


def read_values(repo):
    s2 = os.path.join(repo, "s2")
    inc = open(os.path.join(s2, "game/actors/dead_vat.gdshaderinc"), encoding="utf-8").read()
    cool = found(r"uniform vec3 grade_cool([^=]*)= vec3\(([^)]*)\);", inc)
    v = {
        "skin_off": vec(found(r"const vec3 SKIN_OFF = vec3\(([^)]*)\);", inc).group(1), 3),
        "blotch": float(found(r"off \* \(1\.0 - " + NUMBER + r" \* n\)", inc).group(1)),
        "gone": vec(found(r"const vec2 SKIN_GONE = vec2\(([^)]*)\);", inc).group(1), 2),
        "edge": vec(found(r"const vec2 SKIN_EDGE = vec2\(([^)]*)\);", inc).group(1), 2),
        "hood": vec(found(r"const vec3 HEAD_CLOTH = vec3\(([^)]*)\);", inc).group(1), 3),
        "hood_dim": float(found(r"const float HEAD_CLOTH_DIM = " + NUMBER + ";", inc).group(1)),
        "cloth_max": float(found(r"const float CLOTH_LIGHT_MAX = " + NUMBER + ";", inc).group(1)),
        "soil": vec(found(r"const vec3 CLOTH_SOIL = vec3\(([^)]*)\);", inc).group(1), 3),
        "cloth_state": float(found(r"uniform float cloth_state[^=]*= " + NUMBER + ";", inc).group(1)),
        "sat": float(found(r"uniform float grade_saturation[^=]*= " + NUMBER + ";", inc).group(1)),
        "val": float(found(r"uniform float grade_value[^=]*= " + NUMBER + ";", inc).group(1)),
        "mix": float(found(r"uniform float grade_cool_mix[^=]*= " + NUMBER + ";", inc).group(1)),
    }
    v["cool"] = vec(cool.group(2), 3)
    if "source_color" in cool.group(1):
        v["cool"] = to_linear(v["cool"])
    cast = open(os.path.join(s2, "game/actors/dead_cast.gd"), encoding="utf-8").read()
    v["tear"] = {k: (vec(lo, 3)[2], vec(hi, 3)[2]) for k, lo, hi in
                 re.findall(r'"(\w+)": \[Vector3\(([^)]*)\), Vector3\(([^)]*)\)\]', cast)}
    v["skin_tint"] = by_look("SKIN_TINT", cast)
    v["gone_least"] = by_look("SKIN_GONE_LEAST", cast)
    zomb = open(os.path.join(s2, "game/actors/zombies.gd"), encoding="utf-8").read()
    line = found(r"const TINTS: Dictionary = \{(.*)\}", zomb).group(1)
    v["tints"] = {k: vec(c, 3) for k, c in re.findall(r'"(\w+)": Color\(([^)]*)\)', line)}
    for label, kind, look, _rule in LOOKS:
        if kind not in v["tear"] or look not in v["tints"] or look not in v["skin_tint"] or look not in v["gone_least"]:
            raise SystemExit("dead_skin_split: no wear and tear, tint or skin share for " + label)
    return v


def smoothstep(a, b, x):
    u = np.clip((x - a) / (b - a), 0.0, 1.0)
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
    """The mask's red and green at each picture texel's centre: linear filter, repeat (the shader's skin_tex)."""
    m = np.asarray(Image.open(mask_png).convert("RGB"), dtype=np.float64) / 255.0
    n = m.shape[0]
    centres = (np.arange(size) + 0.5) / size * n - 0.5
    yy, xx = np.meshgrid(centres, centres, indexing="ij")
    return [ndimage.map_coordinates(m[..., c], [yy, xx], order=1, mode="grid-wrap") for c in (0, 1)]


def dead_picture(lin, red, green, v):
    """The shader's steps before worn_down: the hood, the light cloth soiled; returns the picture and the skin."""
    skin = smoothstep(v["edge"][0], v["edge"][1], red)[:, None]
    g = green[:, None]
    lin = lin + (v["hood"] * (lin @ LUM)[:, None] * v["hood_dim"] - lin) * g
    light = (lin @ LUM)[:, None]
    k = (1.0 - skin) * smoothstep(v["cloth_max"] * 0.6, v["cloth_max"], light)
    lin = lin + (lin * v["soil"] * np.minimum(1.0, v["cloth_max"] / np.maximum(light, 1e-4)) - lin) * k
    return lin, skin


def measure(repo, v, sat_floor=SAT_FLOOR):
    rows, failed = [], []
    for body in SOURCES:
        folder = os.path.join(repo, "s2/models/people", body)
        pic = np.asarray(Image.open(os.path.join(folder, "albedo.png")).convert("RGB"), dtype=np.float64) / 255.0
        red, green = mask_as_read(os.path.join(folder, "skin_mask.png"), pic.shape[0])
        inside = red >= 0.5
        lin0 = to_linear(pic[inside])
        live_s, live_h = sat_hue(to_srgb(model_grade(lin0, v)))
        ls, lh = float(np.median(live_s)), float(np.median(live_h))
        lin, m = dead_picture(lin0, red[inside], green[inside], v)
        light = (lin @ LUM)[:, None]
        cells = []
        for label, kind, look, rule in LOOKS:
            lo, hi = v["tear"][kind]
            state = v["tints"][look] / 0.5
            light_of = float(state @ LUM)
            on_skin = (light_of + (state - light_of) * v["skin_tint"][look]) / max(1.0, light_of)
            on_cloth = 1.0 + (state - 1.0) * v["cloth_state"]
            least = v["gone_least"][look]
            for which, b in (("mid", (lo + hi) / 2.0), ("least", lo)):
                off = light * v["skin_off"] * (1.0 - v["blotch"] * 0.5)
                gone = least + (1.0 - least) * float(smoothstep(v["gone"][0], v["gone"][1], b))
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
                    failed.append("%s %s %s" % (body, label, which))
                cells.append((label, which, ds / max(ls, 1e-9), dh, ok, checked, ds))
        rows.append((body, int(inside.sum()), float((red > 0.02).sum()), ls, lh, cells))
    return rows, failed


def main():
    repo = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else ".")
    v = read_values(repo)
    print("SKIN_OFF %s SKIN_GONE %s least %s blotch %.2f grade sat %.2f val %.2f cool(linear) %s" % (
        np.round(v["skin_off"], 3).tolist(), v["gone"].tolist(), v["gone_least"], v["blotch"], v["sat"], v["val"],
        np.round(v["cool"], 3).tolist()))
    floor = float(sys.argv[sys.argv.index("--sat-floor") + 1]) if "--sat-floor" in sys.argv else SAT_FLOOR
    rows, failed = measure(repo, v, floor)
    for body, n, touched, ls, lh, cells in rows:
        text = " | ".join("%s/%s s%.2f(%.3f) h%.0f %s" % (label, which, sr, ds, dh, "ok" if ok else ("FAIL" if checked else "-"))
                          for label, which, sr, dh, ok, checked, ds in cells)
        print("%-20s n=%5d (of %5d touched) living s%.3f h%5.1f | %s" % (body, n, touched, ls, lh, text))
    print("SPLIT %s%s" % ("PASS" if not failed else "FAIL " + ", ".join(failed), " (sat floor %.3f)" % floor if floor else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
