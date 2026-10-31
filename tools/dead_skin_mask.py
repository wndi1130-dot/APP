"""Skin masks for the bodies the dead wear (s2/game/actors/dead_cast.gd BODIES).

The dead's look (dead_vat.gdshaderinc) turns the skin grey-green and puts the state's tint on it; the
clothes keep their own colour. Which texels are skin is not guessed in the shader (a warm-colour test
also takes a red tracksuit or a brown coat): it is this mask, one channel, beside each body's albedo.

How: from the body's rigged source (the glb its build folder was baked from, byte-checked when the
garment shells were baked), each triangle whose three corners are mostly the head or neck, the hands, or
the forearms is drawn into the texture's UV space; inside those, a texel is skin by its colour (a looser
test on the head and hands, where hair and hats are the only other things, a stricter one on the
forearms, where sleeves are). Softened by a 1-texel blur and written at 128 x 128
(models/people/<body>/skin_mask.png). The legs and body are never skin (the dead are dressed).

  python -X utf8 -I tools/dead_skin_mask.py <repo> --rigs <rig_try folder> [--sheet <review.jpg>]
"""
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

# Body folder -> its rigged source under the rig_try folder (the ones whose bake matched the build).
SOURCES = {
    "n3-body_tracksuit": "b0_1018/out/tracksuit_walker.glb",
    "n10-body_denim-m": "b1v2/out/n10-body-denim-m-c1.glb",
    "n10-body_sunday-m": "b2/out/n10-body-sunday-m-c4.glb",
    "n3-body_gilet": "b3/out/n3-body-gilet-c3.glb",
    "n3-body_hoodie": "b3/out/n3-body-hoodie-c2.glb",
    "n5-crew_carpenter": "b4/out/n5-crew-carpenter-c3.glb",
    "n5-crew_forewoman": "b5/out/n5-crew-forewoman-c2.glb",
    "n10-body_poncho-f": "b2/out/n10-body-poncho-f-c2.glb",
}
REGIONS = {"head": ("head", "neck"), "hand": ("hand.L", "hand.R"), "forearm": ("forearm.L", "forearm.R")}
TEX = 512
SIZE = 128
COMP = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    data = open(path, "rb").read()
    off, js, bin_ = 12, None, b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            bin_ = chunk
        off += 8 + clen
    return js, bin_


def accessor(js, bin_, i):
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    fmt, size = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    stride = bv.get("byteStride", size * n)
    base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    out = np.empty((a["count"], n), dtype=np.float64)
    for k in range(a["count"]):
        out[k] = struct.unpack_from("<" + fmt * n, bin_, base + k * stride)
    if a.get("normalized") and a["componentType"] in (5121, 5123):
        out /= 255.0 if a["componentType"] == 5121 else 65535.0
    return out


def regions_of(glb):
    js, bin_ = read_glb(glb)
    names = [js["nodes"][j]["name"] for j in js["skins"][0]["joints"]]
    prim = js["meshes"][0]["primitives"][0]
    at = prim["attributes"]
    uv = accessor(js, bin_, at["TEXCOORD_0"])
    joints = accessor(js, bin_, at["JOINTS_0"]).astype(int)
    weights = accessor(js, bin_, at["WEIGHTS_0"])
    idx = accessor(js, bin_, prim["indices"]).astype(int).ravel()
    main = np.array([names[joints[v][int(np.argmax(weights[v]))]] for v in range(len(uv))])
    image = None
    if js.get("images"):
        im = js["images"][0]
        bv = js["bufferViews"][im["bufferView"]]
        raw = bin_[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
        image = Image.open(io.BytesIO(raw)).convert("RGB").resize((TEX, TEX), Image.LANCZOS)
    masks = {}
    for name, bones in REGIONS.items():
        canvas = Image.new("L", (TEX, TEX), 0)
        d = ImageDraw.Draw(canvas)
        for t in range(0, len(idx) - 2, 3):
            tri = idx[t:t + 3]
            if sum(main[v] in bones for v in tri) >= 2:
                d.polygon([(uv[v][0] * TEX, uv[v][1] * TEX) for v in tri], fill=255)
        masks[name] = ndimage.binary_dilation(np.asarray(canvas) > 0, iterations=2)
    return masks, image


def skin_colour(rgb, strict):
    hsv = np.asarray(Image.fromarray(rgb).convert("HSV"), dtype=np.float32) / 255.0
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    if strict:
        return ((h <= 0.10) | (h >= 0.97)) & (s >= 0.15) & (s <= 0.55) & (v >= 0.40)
    return ((h <= 0.12) | (h >= 0.94)) & (s >= 0.08) & (s <= 0.70) & (v >= 0.25)


def main():
    repo = sys.argv[1]
    rigs = sys.argv[sys.argv.index("--rigs") + 1]
    sheet_path = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else ""
    report, tiles = {}, []
    for body, rel in SOURCES.items():
        d = os.path.join(repo, "s2", "models", "people", body)
        rgb = np.asarray(Image.open(os.path.join(d, "albedo.png")).convert("RGB").resize((TEX, TEX), Image.LANCZOS))
        masks, src = regions_of(os.path.join(rigs, rel))
        same = float(np.abs(np.asarray(src, dtype=np.float32) - rgb.astype(np.float32)).mean()) if src is not None else -1.0
        skin = (masks["head"] | masks["hand"]) & skin_colour(rgb, False) | masks["forearm"] & skin_colour(rgb, True)
        skin = ndimage.binary_opening(skin, iterations=1)
        small = Image.fromarray((skin * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.BILINEAR)
        soft = ndimage.uniform_filter(np.asarray(small, dtype=np.float32), size=3)
        out = Image.fromarray(np.clip(soft, 0, 255).astype(np.uint8), "L")
        out.save(os.path.join(d, "skin_mask.png"))
        report[body] = {"skin": round(float(skin.mean()), 4), "head": round(float(masks["head"].mean()), 4),
                        "hand": round(float(masks["hand"].mean()), 4), "picture_vs_rig": round(same, 2)}
        over = rgb.astype(np.float32)
        for name, colour in (("head", (255, 210, 0)), ("hand", (0, 160, 255)), ("forearm", (200, 0, 255))):
            edge = masks[name] & ~ndimage.binary_erosion(masks[name], iterations=2)
            over[edge] = colour
        over[skin] = over[skin] * 0.4 + np.array([40, 230, 40]) * 0.6
        tiles.append((body, Image.fromarray(over.astype(np.uint8))))
    if sheet_path:
        font = ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf", 16)
        sheet = Image.new("RGB", (TEX * 4, (TEX + 26) * 2), (255, 255, 255))
        for k, (body, im) in enumerate(tiles):
            x, y = (k % 4) * TEX, (k // 4) * (TEX + 26)
            sheet.paste(im, (x, y + 26))
            ImageDraw.Draw(sheet).text((x + 4, y + 4), body + "  skin %.1f%%" % (report[body]["skin"] * 100), font=font, fill=(0, 0, 0))
        sheet.save(sheet_path, quality=88)
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
