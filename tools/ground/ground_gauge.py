"""Floor gauges on a straight-down ground shot (_ground_shots.gd top24*.png + *_cells.json), 결정 496.

  python ground_gauge.py seams  <shot.png> <cells.json>   cell lines: brightness step on cell edges between two
                                                          cells of the same floor kind, against mid-cell lines
  python ground_gauge.py repeat <shot.png> <cells.json>   pattern repeats: autocorrelation peaks of the
                                                          high-passed open ground
  python ground_gauge.py phase  <shot.png> <cells.json>   cell-edge strength on grass: the brightness gradient
                                                          by position across the cell, at the edge (+-1/26 cell)
                                                          over the cell's mean, along x and z (1.0 = no line)

The cells json comes from a straight-down shot (orthographic, zoom 24, 780 px tall): "centre" (world x, z of the
image centre), "zoom", "size", and "cells" [x, y, floor kind, building (-1 outdoors), ground code], the ground code
being MapView.ground_details' cell value (open ground: 0 grass, below -0.5 pavement). Without the code, open ground
stays one kind. seams and repeat also count the photo slabs' joints on pavement and roads (a 0.625 m and 0.75 m
lattice), so read them by kind; phase reads grass only.
"""
import json
import sys

import numpy as np
from PIL import Image, ImageFilter

KINDS = ["SNOW", "ROAD", "PLATFORM", "WOOD", "RAIL", "DEEP_SNOW", "ICE", "GRAVEL"]


def kind_of(c):
    """Floor kind name of a cell [x, y, floor, building(, ground code)]. Open ground splits into grass and
    pavement when the shot carries MapView.ground_details' code (pavement below -0.5): their edges differ."""
    k = c[2]
    name = KINDS[k] if k < len(KINDS) else str(k)
    if k == 0 and len(c) > 4:
        name = "PAVE" if c[4] < -0.5 else "GRASS"
    return name


def load(png, cj):
    img = Image.open(png).convert("RGB")
    grey = np.asarray(img, dtype=np.float32).mean(axis=2) / 255.0
    meta = json.load(open(cj, encoding="utf-8"))
    h, w = grey.shape
    p = h / float(meta["zoom"])
    cx, cz = meta["centre"]
    cells = {(c[0], c[1]): (kind_of(c), c[3]) for c in meta["cells"]}

    def u_of(x):
        return w / 2.0 + (x - cx) * p

    def v_of(z):
        return h / 2.0 + (z - cz) * p

    return img, grey, p, cells, u_of, v_of


def seams(png, cj):
    _, grey, p, cells, u_of, v_of = load(png, cj)
    h, w = grey.shape
    gx = np.abs(np.roll(grey, -1, 1) - np.roll(grey, 1, 1))
    gy = np.abs(np.roll(grey, -1, 0) - np.roll(grey, 1, 0))
    def line(grad, along_x, at, a0, a1):
        """Mean gradient over a 2 px band at `at` (metres), from a0 to a1 along the line."""
        if along_x:
            c, r0, r1 = u_of(at), v_of(a0), v_of(a1)
            if not (2 <= c < w - 2 and 0 <= r0 and r1 < h):
                return None
            return grad[int(r0):int(r1), int(round(c)) - 1:int(round(c)) + 1].mean()
        c, r0, r1 = v_of(at), u_of(a0), u_of(a1)
        if not (2 <= c < h - 2 and 0 <= r0 and r1 < w):
            return None
        return grad[int(round(c)) - 1:int(round(c)) + 1, int(r0):int(r1)].mean()

    # For each pair of same-kind open cells: the shared edge against the two mid lines (offset 0), and the same
    # test shifted a quarter cell (offset 0.25) as the chance level. Lines = edges over 1.5 beyond chance.
    per_kind = {}
    for (x, y), (k, b) in cells.items():
        if b >= 0:
            continue
        for dx, dy, grad in ((1, 0, gx), (0, 1, gy)):
            n = cells.get((x + dx, y + dy))
            if n is None or n[0] != k or n[1] >= 0:
                continue
            base, a0, a1 = (x, y + 0.2, y + 0.8) if dx else (y, x + 0.2, x + 0.8)
            got = []
            for o in (0.0, 0.25):
                e = line(grad, bool(dx), base + 1 + o, a0, a1)
                m1 = line(grad, bool(dx), base + 0.5 + o, a0, a1)
                m2 = line(grad, bool(dx), base + 1.5 + o, a0, a1)
                if e is None or m1 is None or m2 is None:
                    break
                got.append(e / max(0.5 * (m1 + m2), 1e-4))
            if len(got) == 2:
                per_kind.setdefault(k, []).append(got)
    total_lines = 0
    out = {}
    for kind, r in sorted(per_kind.items()):
        r = np.array(r)
        over, chance = int((r[:, 0] > 1.5).sum()), int((r[:, 1] > 1.5).sum())
        lines = max(0, over - chance)
        total_lines += lines
        out[kind] = {"edges": int(len(r)), "edge_median": round(float(np.median(r[:, 0])), 3),
                     "chance_median": round(float(np.median(r[:, 1])), 3), "over_1_5": over, "chance_over_1_5": chance,
                     "lines": lines}
    print(json.dumps({"shot": png, "seam_lines": total_lines, "by_kind": out}, ensure_ascii=False))


def repeat(png, cj):
    img, grey, p, cells, u_of, v_of = load(png, cj)
    h, w = grey.shape
    ground = np.zeros_like(grey, dtype=bool)
    for (x, y), (k, b) in cells.items():
        if b >= 0:
            continue
        if any(cells.get((x + dx, y + dy), (-1, 0)) != (k, b) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            continue
        u0, u1, v0, v1 = int(u_of(x + 0.15)), int(u_of(x + 0.85)), int(v_of(y + 0.15)), int(v_of(y + 0.85))
        ground[max(v0, 0):max(min(v1, h), 0), max(u0, 0):max(min(u1, w), 0)] = True
    blur = np.asarray(Image.fromarray((grey * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(p)), dtype=np.float32) / 255.0
    hp = np.where(ground, grey - blur, 0.0)
    hp -= hp[ground].mean() * ground
    f = np.fft.rfft2(hp, s=(2 * h, 2 * w))
    ac = np.fft.irfft2(f * np.conj(f), s=(2 * h, 2 * w))
    ac = np.fft.fftshift(ac)
    # normalise by overlap so far lags are not starved
    m = np.fft.rfft2(ground.astype(np.float32), s=(2 * h, 2 * w))
    ov = np.fft.fftshift(np.fft.irfft2(m * np.conj(m), s=(2 * h, 2 * w)))
    ok = ov > 0.25 * ov.max()
    ac = np.where(ok, ac / np.maximum(ov, 1.0), 0.0)
    ac /= ac[h, w]
    yy, xx = np.mgrid[0:2 * h, 0:2 * w]
    r = np.hypot(yy - h, xx - w)
    ac[r < 0.6 * p] = 0.0
    peaks = []
    a = ac.copy()
    for _ in range(40):
        i = np.unravel_index(np.argmax(a), a.shape)
        if a[i] < 0.3:
            break
        peaks.append((round(float(a[i]), 3), round(float((i[1] - w) / p), 2), round(float((i[0] - h) / p), 2)))
        y0, x0 = i
        a[max(y0 - int(p), 0):y0 + int(p), max(x0 - int(p), 0):x0 + int(p)] = 0.0
    # each lag and its mirror are the same repeat: count half
    print(json.dumps({"shot": png, "ground_share": round(float(ground.mean()), 3), "repeat_peaks_over_0_3": len(peaks) // 2,
                      "strongest": peaks[:6]}, ensure_ascii=False))


def phase(png, cj, bins=13):
    _, grey, p, cells, u_of, v_of = load(png, cj)
    h, w = grey.shape
    meta = json.load(open(cj, encoding="utf-8"))
    cx, cz = meta["centre"]
    gx = np.abs(np.roll(grey, -1, 1) - np.roll(grey, 1, 1))
    gy = np.abs(np.roll(grey, -1, 0) - np.roll(grey, 1, 0))
    uu, vv = np.meshgrid(np.arange(w), np.arange(h))
    mx = (uu - w / 2.0) / p + cx
    mz = (vv - h / 2.0) / p + cz
    ix, iz = np.floor(mx).astype(int), np.floor(mz).astype(int)
    grass = np.zeros_like(grey, dtype=bool)
    for (x, y), (k, b) in cells.items():
        if k == "GRASS" and b < 0:
            grass |= (ix == x) & (iz == y)
    if not grass.any():
        print(json.dumps({"shot": png, "grass_px": 0}, ensure_ascii=False))
        return
    out = {}
    for name, g, frac in (("x", gx, mx - ix), ("z", gy, mz - iz)):
        b = np.minimum((((frac + 0.5 / bins) % 1.0) * bins).astype(int), bins - 1)
        prof = np.array([g[grass & (b == k)].mean() for k in range(bins)])
        out[name] = round(float(prof[0] / prof.mean()), 3)
    print(json.dumps({"shot": png, "grass_px": int(grass.sum()), "edge_x": out["x"], "edge_z": out["z"]},
                     ensure_ascii=False))


if __name__ == "__main__":
    {"seams": seams, "repeat": repeat, "phase": phase}[sys.argv[1]](sys.argv[2], sys.argv[3])
