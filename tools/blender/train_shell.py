"""내정 화면(train.tscn)의 칸 껍데기 다섯 벌. Blender 헤드리스, 외부 자원 없이 작은 색 그림 한 장.

blender -b --factory-startup -P tools/blender/train_shell.py -- --repo .

train_scene.gd가 상자로 짓던 바닥·뒷벽·끝벽·지붕·창틀·차대·대차를 low·top 두 메시로 바꾼다.
좌표는 칸 하나의 지역 좌표(train_scene.gd와 같다): X 0..16 길이, Y 위(바닥 윗면 0), Z 뒤벽 -1.4 .. 열린 앞 +1.4.
카메라는 +Z에서 본다. 그래서 앞에서 보이는 면만 짓는다(뒷벽 바깥, 끝벽 바깥은 없다).
창 구멍(x 2·6·10·14 가운데, 폭 1.6, 높이 1.3..2.2)은 코드의 창유리 셰이더 판이 채운다.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

SCRIPT_VERSION = 3   # 3: 바닥 위 2.2 m에서 low·top 분할
ATLAS = 256
CELL = 32
TRIANGLE_LIMIT = 3000
CUT_Y = 2.2
PALETTE = {
    "wall_green": (92, 100, 92), "plank": (104, 82, 60), "plank_dark": (70, 54, 40), "plank_worn": (122, 100, 76),
    "floor": (88, 70, 52), "floor_dark": (66, 52, 40),
    "varnish": (112, 76, 50), "varnish_dark": (76, 50, 34), "cream": (176, 166, 140),
    "walnut": (78, 52, 36), "walnut_light": (104, 72, 50), "gold": (150, 120, 62),
    "pale_green": (118, 132, 118), "white_dirty": (184, 182, 170), "grey_white": (148, 148, 142),
    "iron": (40, 40, 42), "iron_worn": (66, 64, 60), "steel": (90, 90, 92),
    "roof": (96, 96, 94), "roof_seam": (52, 52, 54), "bellows": (34, 32, 30), "black": (18, 18, 20),
    "brass": (150, 118, 60), "lamp_glass": (220, 190, 130), "curtain": (176, 170, 154), "curtain_red": (110, 56, 48),
}
NAMES = list(PALETTE)
assert len(NAMES) <= (ATLAS // CELL) ** 2

L = 16.0
BACK = -1.30        # 뒷벽 안쪽 면
BACK_OUT = -1.42    # 창 구멍 바깥 끝(유리는 코드가 -1.40에 둔다)
FRONT = 1.40
TOP = 2.95          # 벽 위
WIN_X = [2.0, 6.0, 10.0, 14.0]
WIN_W = 1.6
WIN_Y = (1.30, 2.20)
DOOR_Z = (0.2, 1.1)
DOOR_H = 2.0
WAINS = 0.95
RAIL_Y = -1.44      # 레일 윗면
WHEEL_R = 0.42
BOGIES = (2.9, 13.1)

# 칸 종류별 색: 아래 판(징두리), 위 벽, 창틀, 바닥 둘, 짐 선반(없으면 ""), 창가 커튼(없으면 "")
VARIANTS = {
    "plain": {"wains": "plank_dark", "wall": "wall_green", "frame": "plank", "floor": ("floor", "floor_dark"),
              "rack": "iron", "curtain": "", "note": "낡은 3등 객차(꼬리·경비·공방·화차 등)"},
    "clean": {"wains": "varnish", "wall": "cream", "frame": "varnish_dark", "floor": ("plank", "floor"),
              "rack": "brass", "curtain": "", "note": "칠이 남은 객차(앞칸·식당)"},
    "chief": {"wains": "walnut", "wall": "walnut_light", "frame": "walnut", "floor": ("varnish_dark", "walnut"),
              "rack": "brass", "curtain": "curtain_red", "note": "열차장실, 짙은 나무 판과 접힌 붉은 커튼"},
    "medic": {"wains": "pale_green", "wall": "white_dirty", "frame": "grey_white", "floor": ("plank_worn", "floor"),
              "rack": "", "curtain": "curtain", "note": "의무칸, 흰 벽과 반쯤 친 커튼. 붉은 십자 없음"},
    # 기관차·탄수차(사람 없는 칸): 객차 창·징두리 대신 쇠판 벽과 판 이음 띠, 운전실 쪽 창 하나.
    "engine": {"wains": "iron", "wall": "iron_worn", "frame": "steel", "floor": ("iron_worn", "iron"),
               "rack": "", "curtain": "", "win_x": [14.0], "plates": True, "note": "기관차·탄수차, 쇠판 벽과 운전실 창 하나"},
}


def uv_of(colour):
    i = NAMES.index(colour)
    cx = (i % (ATLAS // CELL)) * CELL + CELL / 2
    cy = (i // (ATLAS // CELL)) * CELL + CELL / 2
    return (cx / ATLAS, 1.0 - cy / ATLAS)


class Piece:
    def __init__(self, pid):
        self.pid = pid
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, pts, colour, outward):
        pts = [Vector((p[0], -p[2], p[1])) for p in pts]
        outward = Vector((outward[0], -outward[2], outward[1]))
        normal = Vector((0, 0, 0))
        for i, a in enumerate(pts):
            normal += a.cross(pts[(i + 1) % len(pts)])
        if normal.length < 1e-10:
            raise ValueError("넓이 없는 면: %s %s" % (self.pid, colour))
        if normal.dot(outward) < 0:
            pts.reverse()
        f = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        f.smooth = False
        u = uv_of(colour)
        for loop in f.loops:
            loop[self.uv].uv = u

    def box(self, x, y, z, colour, skip=()):
        x0, x1 = x
        y0, y1 = y
        z0, z1 = z
        if min(x1 - x0, y1 - y0, z1 - z0) <= 0:
            raise ValueError("빈 상자: %s" % self.pid)
        sides = (("-x", [(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)], (-1, 0, 0)),
                 ("+x", [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], (1, 0, 0)),
                 ("-y", [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0)),
                 ("+y", [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], (0, 1, 0)),
                 ("-z", [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], (0, 0, -1)),
                 ("+z", [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1)))
        for key, pts, out in sides:
            if key not in skip:
                self.face(pts, colour, out)

    def cyl(self, a, b, r, colour, sides=8, caps=True, cap_colour=None):
        a, b = Vector(a), Vector(b)
        axis = (b - a).normalized()
        guide = Vector((1, 0, 0)) if abs(axis.y) > .9 else Vector((0, 1, 0))
        u = axis.cross(guide).normalized()
        v = axis.cross(u).normalized()
        ring = [u * math.cos(i * math.tau / sides) + v * math.sin(i * math.tau / sides) for i in range(sides)]
        lo = [a + d * r for d in ring]
        hi = [b + d * r for d in ring]
        if caps:
            self.face(lo, cap_colour or colour, -axis)
            self.face(hi, cap_colour or colour, axis)
        for i in range(sides):
            j = (i + 1) % sides
            self.face([lo[i], lo[j], hi[j], hi[i]], colour, ring[i] + ring[j])

    def fin(self):
        bmesh.ops.triangulate(self.bm, faces=list(self.bm.faces))
        self.bm.normal_update()
        if any(f.calc_area() < 1e-11 for f in self.bm.faces):
            raise ValueError("퇴화 삼각형: " + self.pid)
        return len(self.bm.faces)

    def split(self):
        # Blender의 Z가 Godot의 +Y다. 절단면을 새로 막지 않는다.
        bmesh.ops.bisect_plane(self.bm,
            geom=list(self.bm.verts) + list(self.bm.edges) + list(self.bm.faces),
            dist=1e-7, plane_co=(0, 0, CUT_Y), plane_no=(0, 0, 1))
        pieces = {}
        for name in ("low", "top"):
            part = Piece(name)
            part.bm.free()
            part.bm = self.bm.copy()
            part.uv = part.bm.loops.layers.uv.active
            # 면 위에 놓인 수평 면은 low에만 둔다.
            discard = [f for f in part.bm.faces
                       if (f.calc_center_median().z <= CUT_Y + 1e-7) != (name == "low")]
            bmesh.ops.delete(part.bm, geom=discard, context="FACES")
            pieces[name] = part
        return pieces


def openings(v=None):
    return [(x - WIN_W / 2, x + WIN_W / 2) for x in (v or {}).get("win_x", WIN_X)]


def back_wall(p, v):
    z = BACK
    out = (0, 0, 1)
    # 징두리(아래 판)와 위 벽
    p.face([(0, 0, z), (L, 0, z), (L, WAINS, z), (0, WAINS, z)], v["wains"], out)
    ya, yb = WIN_Y
    p.face([(0, WAINS, z), (L, WAINS, z), (L, ya, z), (0, ya, z)], v["wall"], out)
    p.face([(0, yb, z), (L, yb, z), (L, TOP, z), (0, TOP, z)], v["wall"], out)
    cuts = [0.0]
    for a, b in openings(v):
        cuts += [a, b]
    cuts.append(L)
    for i in range(0, len(cuts), 2):
        p.face([(cuts[i], ya, z), (cuts[i + 1], ya, z), (cuts[i + 1], yb, z), (cuts[i], yb, z)], v["wall"], out)
    for a, b in openings(v):
        # 구멍 둘레(안으로 12cm)와 창틀(벽에서 3cm), 창턱(8cm)
        p.face([(a, ya, z), (b, ya, z), (b, ya, BACK_OUT), (a, ya, BACK_OUT)], v["frame"], (0, 1, 0))
        p.face([(a, yb, z), (b, yb, z), (b, yb, BACK_OUT), (a, yb, BACK_OUT)], v["frame"], (0, -1, 0))
        p.face([(a, ya, z), (a, yb, z), (a, yb, BACK_OUT), (a, ya, BACK_OUT)], v["frame"], (1, 0, 0))
        p.face([(b, ya, z), (b, yb, z), (b, yb, BACK_OUT), (b, ya, BACK_OUT)], v["frame"], (-1, 0, 0))
        f = (z, z + 0.03)
        p.box((a - 0.07, b + 0.07), (yb, yb + 0.07), f, v["frame"], skip=("-z",))
        p.box((a - 0.07, a), (ya, yb), f, v["frame"], skip=("-z", "-y", "+y"))
        p.box((b, b + 0.07), (ya, yb), f, v["frame"], skip=("-z", "-y", "+y"))
        p.box((a - 0.1, b + 0.1), (ya - 0.05, ya), (z, z + 0.08), v["frame"], skip=("-z",))
        # 가운데 창살 하나(창이 두 짝으로 읽힌다)
        m = (a + b) / 2
        p.box((m - 0.025, m + 0.025), (ya, yb), (BACK_OUT + 0.05, BACK_OUT + 0.07), v["frame"], skip=("-z", "-y", "+y"))
        if v["curtain"] == "curtain_red":
            for c0, c1 in ((a + 0.01, a + 0.24), (b - 0.24, b - 0.01)):
                p.box((c0, c1), (ya + 0.02, yb - 0.02), (BACK_OUT + 0.025, BACK_OUT + 0.04), "curtain_red", skip=("-z",))
        elif v["curtain"]:
            # 유리(-1.40)와 창살(-1.37) 사이
            p.box((a + 0.01, b - 0.01), (ya + 0.02, (ya + yb) / 2), (BACK_OUT + 0.025, BACK_OUT + 0.04), v["curtain"], skip=("-z",))
    # 징두리 위 띠와 세로 판 줄
    p.box((0.1, L - 0.1), (WAINS - 0.03, WAINS + 0.03), (z, z + 0.025), v["frame"], skip=("-z",))
    x = 1.0
    while x < L - 0.5:
        p.box((x - 0.012, x + 0.012), (0.05, WAINS - 0.03), (z, z + 0.01), v["frame"], skip=("-z", "-y", "+y"))
        x += 1.0
    if v.get("plates"):
        # 쇠판 벽: 2 m마다 세로 이음 띠(창 자리는 건너뜀)와 위쪽 가로 띠
        x = 2.0
        while x < L - 0.5:
            if not any(a - 0.1 < x < b + 0.1 for a, b in openings(v)):
                p.box((x - 0.03, x + 0.03), (WAINS + 0.03, TOP - 0.05), (z, z + 0.02), v["frame"], skip=("-z", "-y", "+y"))
            x += 2.0
        p.box((0.1, L - 0.1), (TOP - 0.40, TOP - 0.35), (z, z + 0.02), v["frame"], skip=("-z",))
    # 창 위 짐 선반(가로대 둘과 받침)
    if v["rack"]:
        for zz in (-1.12, -0.98):
            p.cyl((0.4, 2.42, zz), (L - 0.4, 2.42, zz), 0.018, v["rack"], 4, caps=False)
        for bx in (0.6, 4.0, 8.0, 12.0, 15.4):
            p.box((bx - 0.02, bx + 0.02), (2.36, 2.44), (z, -0.96), v["rack"], skip=("-z",))


def end_walls(p, v):
    for x0, x1, inner in ((0.0, 0.1, 1), (L - 0.1, L, -1)):
        x = x1 if inner > 0 else x0
        out = (inner, 0, 0)
        za, zb = DOOR_Z
        # 문 옆 두 판(뒤·앞), 문 위
        for (z0, z1) in ((BACK, za), (zb, FRONT)):
            p.face([(x, 0, z0), (x, 0, z1), (x, WAINS, z1), (x, WAINS, z0)], v["wains"], out)
            p.face([(x, WAINS, z0), (x, WAINS, z1), (x, TOP, z1), (x, TOP, z0)], v["wall"], out)
        p.face([(x, DOOR_H, za), (x, DOOR_H, zb), (x, TOP, zb), (x, TOP, za)], v["wall"], out)
        # 잘린 앞 끝(벽 두께)
        p.face([(x0, 0, FRONT), (x1, 0, FRONT), (x1, TOP, FRONT), (x0, TOP, FRONT)], "plank_dark", (0, 0, 1))
        # 문틀
        fx = (x, x + inner * 0.04)
        fx = tuple(sorted(fx))
        p.box(fx, (0, DOOR_H + 0.08), (za - 0.08, za), v["frame"], skip=("-y",))
        p.box(fx, (0, DOOR_H + 0.08), (zb, zb + 0.08), v["frame"], skip=("-y",))
        p.box(fx, (DOOR_H, DOOR_H + 0.08), (za, zb), v["frame"], skip=("-y",))


def floor(p, v):
    a, b = v["floor"]
    n = 9
    for i in range(n):
        z0 = BACK + (FRONT - BACK) * i / n
        z1 = BACK + (FRONT - BACK) * (i + 1) / n
        p.face([(0, 0, z0), (L, 0, z0), (L, 0, z1), (0, 0, z1)], a if i % 2 == 0 else b, (0, 1, 0))
    # 바닥 앞 끝(두께)과 옆 들보
    p.face([(0, -0.30, FRONT), (L, -0.30, FRONT), (L, 0, FRONT), (0, 0, FRONT)], "plank_dark", (0, 0, 1))
    p.box((0, L), (-0.46, -0.30), (FRONT - 0.16, FRONT), "iron", skip=("-z",))
    # 앞 아래 잘린 벽 밑동(낮게, 사람 발이 가리지 않게)
    p.box((0.1, L - 0.1), (0, 0.06), (FRONT - 0.08, FRONT), "plank_dark", skip=("-y",))


def roof(p):
    z_half, eave, peak = 1.52, TOP + 0.05, TOP + 0.30
    steps = 8
    prof = [(z_half * math.cos(i / steps * math.pi), eave + (peak - eave) * math.sin(i / steps * math.pi)) for i in range(steps + 1)]

    def strip(x0, x1, colour, lift=0.0):
        for (za, ya), (zb, yb) in zip(prof, prof[1:]):
            p.face([(x0, ya + lift, za), (x1, ya + lift, za), (x1, yb + lift, zb), (x0, yb + lift, zb)], colour, (0, (ya + yb) / 2 - eave + 0.01, (za + zb) / 2))

    strip(-0.05, L + 0.05, "roof")
    for xe, xs in ((-0.05, -1), (L + 0.05, 1)):
        ring = [(xe, eave - 0.1, z_half)] + [(xe, y, z) for z, y in prof] + [(xe, eave - 0.1, -z_half)]
        p.face(ring, "roof", (xs, 0, 0))
    # 잘린 앞쪽 처마 밑과 이음 띠
    p.face([(-0.05, eave - 0.1, z_half), (L + 0.05, eave - 0.1, z_half), (L + 0.05, eave, z_half), (-0.05, eave, z_half)], "roof_seam", (0, 0, 1))
    p.face([(-0.05, eave - 0.1, FRONT - 0.1), (L + 0.05, eave - 0.1, FRONT - 0.1), (L + 0.05, eave - 0.1, z_half), (-0.05, eave - 0.1, z_half)], "roof_seam", (0, -1, 0))
    for i in range(1, 8):
        x = L * i / 8
        strip(x - 0.03, x + 0.03, "roof_seam", 0.006)
    for x in (4.0, 12.0):
        p.cyl((x, peak - 0.03, 0), (x, peak + 0.06, 0), 0.18, "roof_seam", 8, caps=False)
        p.cyl((x, peak + 0.06, 0), (x, peak + 0.12, 0), 0.14, "iron", 8, cap_colour="roof_seam")


def ends(p):
    """칸 사이: 연결막(앞면과 위), 완충기, 연결기. 이웃 칸과 틈 가운데서 맞닿는다."""
    for x0, x1 in ((-0.5, 0.0), (L, L + 0.5)):
        p.box((x0, x1), (-0.05, 2.15), (0.05, 1.25), "bellows", skip=("-z", "-y", "-x", "+x"))
        for k in (1, 2):
            xr = x0 + (x1 - x0) * k / 3
            p.box((xr - 0.02, xr + 0.02), (-0.06, 2.16), (1.25, 1.27), "black", skip=("-z", "-y"))
        xo = x1 if x0 < 0 else x0
        sign = -1 if x0 < 0 else 1
        xb = tuple(sorted((xo + sign * 0.0, xo + sign * 0.42)))
        xh = tuple(sorted((xo + sign * 0.42, xo + sign * 0.5)))
        p.cyl((xb[0], -0.38, 0.95), (xb[1], -0.38, 0.95), 0.07, "iron", 6)
        p.cyl((xh[0], -0.38, 0.95), (xh[1], -0.38, 0.95), 0.17, "steel", 10, cap_colour="iron_worn")
        p.box(tuple(sorted((xo, xo + sign * 0.45))), (-0.45, -0.32), (0.18, 0.32), "iron")


def underframe(p):
    p.box((4.6, 11.4), (-0.80, -0.46), (-0.4, 0.95), "iron_worn", skip=("-z",))
    z = 1.22
    pts = [(3.9, -0.46, z), (5.6, -0.92, z), (10.4, -0.92, z), (12.1, -0.46, z)]
    for a, b in zip(pts, pts[1:]):
        p.cyl(a, b, 0.022, "iron", 4, caps=False)
    for x in (5.6, 10.4):
        p.cyl((x, -0.92, z), (x, -0.46, z), 0.028, "iron", 4, caps=False)


def bogie(p, cx):
    cy = RAIL_Y + WHEEL_R
    for ax in (cx - 0.75, cx + 0.75):
        p.cyl((ax, cy, 0.98), (ax, cy, 1.10), WHEEL_R, "iron", 16, cap_colour="iron_worn")
        p.cyl((ax, cy, 1.10), (ax, cy, 1.15), 0.11, "steel", 6)
        p.box((ax - 0.14, ax + 0.14), (cy - 0.12, cy + 0.16), (1.12, 1.26), "iron", skip=("-z",))
    p.box((cx - 1.15, cx + 1.15), (cy + 0.10, cy + 0.30), (1.12, 1.24), "iron_worn", skip=("-z",))
    p.box((cx - 0.5, cx + 0.5), (cy + 0.30, cy + 0.42), (1.10, 1.25), "steel", skip=("-z",))
    p.box((cx - 0.2, cx + 0.2), (cy + 0.30, -0.46), (-0.9, 1.15), "iron", skip=("-z",))


def lamp(p):
    # 난로 연통(x 7.85)과 겹치지 않게 등은 조금 앞쪽에 건다(빛은 코드가 x 8에 둔다).
    x, z = 9.3, 0.3
    p.cyl((x, TOP, z), (x, 2.62, z), 0.012, "iron", 4, caps=False)
    p.box((x - 0.09, x + 0.09), (2.38, 2.62), (z - 0.09, z + 0.09), "lamp_glass")
    p.box((x - 0.11, x + 0.11), (2.62, 2.66), (z - 0.11, z + 0.11), "brass")
    p.box((x - 0.11, x + 0.11), (2.34, 2.38), (z - 0.11, z + 0.11), "brass")


def build(p, v):
    floor(p, v)
    back_wall(p, v)
    end_walls(p, v)
    roof(p)
    ends(p)
    underframe(p)
    for cx in BOGIES:
        bogie(p, cx)
    lamp(p)


# ---------------------------------------------------------------- 내보내기
def atlas_image():
    img = bpy.data.images.new("train_shell_palette", ATLAS, ATLAS, alpha=False)
    px = [0.0] * (ATLAS * ATLAS * 4)
    per = ATLAS // CELL
    for i, name in enumerate(NAMES):
        r, g, b = (c / 255.0 for c in PALETTE[name])
        cx, cy = i % per, i // per
        for y in range(cy * CELL, (cy + 1) * CELL):
            row = ATLAS - 1 - y
            for x in range(cx * CELL, (cx + 1) * CELL):
                k = (row * ATLAS + x) * 4
                px[k:k + 4] = [r, g, b, 1.0]
    img.pixels = px
    img.file_format = "PNG"
    img.pack()
    return img


def material(img):
    mat = bpy.data.materials.new("train_shell")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def export(pieces, mat, path):
    meshes, objects = [], []
    try:
        for name, piece in pieces.items():
            mesh = bpy.data.meshes.new(name)
            meshes.append(mesh)
            piece.bm.to_mesh(mesh)
            mesh.materials.append(mat)
            obj = bpy.data.objects.new(name, mesh)
            objects.append(obj)
            bpy.context.scene.collection.objects.link(obj)
        for other in bpy.context.scene.objects:
            other.select_set(other in objects)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
            export_yup=True, export_apply=False, export_materials="EXPORT", export_texcoords=True,
            export_normals=True, export_tangents=False, export_vertex_color="NONE",
            export_extras=False, export_animations=False, export_image_format="AUTO")
    finally:
        for obj in objects:
            bpy.data.objects.remove(obj, do_unlink=True)
        for mesh in meshes:
            bpy.data.meshes.remove(mesh)


def glb_stats(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data)
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if (magic, version, length, chunk_type) != (b"glTF", 2, len(data), 0x4E4F534A):
        raise ValueError("GLB 머리 검사 실패")
    book = json.loads(data[20:20 + chunk_length])
    if len(book.get("images", [])) != 1 or len(book.get("materials", [])) != 1:
        raise ValueError("그림 하나·재질 하나 검사 실패")
    binary_length, binary_type = struct.unpack_from("<II", data, 20 + chunk_length)
    if binary_type != 0x004E4942 or 28 + chunk_length + binary_length != len(data):
        raise ValueError("GLB 바이너리 검사 실패")
    binary = data[28 + chunk_length:]

    def accessor(index):
        spec = book["accessors"][index]
        view = book["bufferViews"][spec["bufferView"]]
        count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[spec["type"]]
        fmt = "<" + {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[spec["componentType"]] * count
        stride = view.get("byteStride", struct.calcsize(fmt))
        offset = view.get("byteOffset", 0) + spec.get("byteOffset", 0)
        return [struct.unpack_from(fmt, binary, offset + i * stride) for i in range(spec["count"])]

    meshes, uv_areas, points = {}, {}, []
    for mesh in book["meshes"]:
        if len(mesh["primitives"]) != 1 or mesh["name"] in meshes:
            raise ValueError("메시 표면·이름 검사 실패")
        prim = mesh["primitives"][0]
        if prim.get("mode", 4) != 4 or prim.get("material") != 0:
            raise ValueError("삼각형·공유 재질 검사 실패")
        positions = accessor(prim["attributes"]["POSITION"])
        uvs = accessor(prim["attributes"]["TEXCOORD_0"])
        indices = [row[0] for row in accessor(prim["indices"])]
        if len(indices) % 3 != 0 or not positions:
            raise ValueError("삼각형 인덱스 검사 실패")
        area = 0.0
        for i in range(0, len(indices), 3):
            ids = indices[i:i + 3]
            colour_uv = tuple(round(v, 6) for v in uvs[ids[0]])
            if any(tuple(round(v, 6) for v in uvs[j]) != colour_uv for j in ids):
                raise ValueError("색 칸 UV 검사 실패")
            a, b, c = (Vector(positions[j]) for j in ids)
            triangle_area = (b - a).cross(c - a).length * 0.5
            if triangle_area < 1e-11:
                raise ValueError("GLB 퇴화 삼각형")
            area += triangle_area
            uv_areas[colour_uv] = uv_areas.get(colour_uv, 0.0) + triangle_area
        meshes[mesh["name"]] = {"tris": len(indices) // 3, "area": area,
                                "y_min": min(p[1] for p in positions), "y_max": max(p[1] for p in positions)}
        points.extend(positions)
    for node in book["nodes"]:
        if any(key in node for key in ("matrix", "translation", "rotation", "scale")):
            raise ValueError("GLB 지역 좌표 변환 검사 실패")
    image_view = book["bufferViews"][book["images"][0]["bufferView"]]
    image_offset = image_view.get("byteOffset", 0)
    image_data = binary[image_offset:image_offset + image_view["byteLength"]]
    return {"meshes": meshes, "uv_areas": uv_areas, "area": sum(m["area"] for m in meshes.values()),
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "image_sha256": hashlib.sha256(image_data).hexdigest(),
            "bounds_m": [[round(fn(p[i] for p in points), 4) for i in range(3)] for fn in (min, max)]}


def check_glb(path, tris, before):
    stats = glb_stats(path)
    if set(stats["meshes"]) != {"low", "top"}:
        raise ValueError("low·top 메시 둘 검사 실패")
    for name, count in tris.items():
        if stats["meshes"][name]["tris"] != count:
            raise ValueError("삼각형 수 검사 실패: " + name)
    if stats["meshes"]["low"]["y_max"] > CUT_Y + 0.0001 or stats["meshes"]["top"]["y_min"] < CUT_Y - 0.0001:
        raise ValueError("Godot +Y 절단 높이 검사 실패")
    if before is not None:
        if abs(stats["area"] / before["area"] - 1.0) > 0.001:
            raise ValueError("겉넓이 0.1% 검사 실패")
        if stats["image_sha256"] != before["image_sha256"] or stats["bounds_m"] != before["bounds_m"]:
            raise ValueError("색 그림·외곽 범위 보존 검사 실패")
        if stats["uv_areas"].keys() != before["uv_areas"].keys():
            raise ValueError("색 칸 목록 보존 검사 실패")
        for uv, area in before["uv_areas"].items():
            if abs(stats["uv_areas"][uv] / area - 1.0) > 0.001:
                raise ValueError("색 칸별 겉넓이 보존 검사 실패")
    return stats


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    repo = Path(args.repo).resolve()
    out_dir = repo / "s2/models/train_shell"
    out_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = material(atlas_image())
    rows = {}
    for name, v in VARIANTS.items():
        pid = "shell_" + name
        piece = Piece(pid)
        pieces = {}
        try:
            path = out_dir / (pid + ".glb")
            before = glb_stats(path) if path.exists() else None
            build(piece, v)
            pieces = piece.split()
            tris = {key: part.fin() for key, part in pieces.items()}
            total = sum(tris.values())
            if total > TRIANGLE_LIMIT:
                raise ValueError("삼각형 상한 초과 %d" % total)
            export(pieces, mat, path)
            stats = check_glb(path, tris, before)
            old_area = before["area"] if before is not None else stats["area"]
            change = (stats["area"] / old_area - 1.0) * 100.0
            rows[pid] = {"tris_low": tris["low"], "tris_top": tris["top"], "tris": total,
                         "bytes": stats["bytes"], "sha256": stats["sha256"], "bounds_m": stats["bounds_m"],
                         "surface_area_before_m2": old_area, "surface_area_m2": stats["area"],
                         "surface_area_delta_pct": change, "use": v["note"]}
            print("TRAIN_SHELL_READY %s tris_low=%d tris_top=%d tris=%d bytes=%d bounds=%s" %
                  (pid, tris["low"], tris["top"], total, stats["bytes"], stats["bounds_m"]), flush=True)
            print("TRAIN_SHELL_SURFACE %s before=%.9f after=%.9f delta_pct=%.9f uv=unchanged" %
                  (pid, old_area, stats["area"], change), flush=True)
        finally:
            for part in pieces.values():
                part.bm.free()
            piece.bm.free()
    book = {"version": 1, "script": "tools/blender/train_shell.py", "script_version": SCRIPT_VERSION,
            "blender": bpy.app.version_string, "axis": "X 칸 길이 0..16, +Y 위(바닥 윗면 0), +Z 열린 앞(카메라 쪽)",
            "texture": [ATLAS, ATLAS], "cut_y_m": CUT_Y, "triangle_limit": TRIANGLE_LIMIT, "assets": rows}
    (out_dir / "catalog.json").write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("TRAIN_SHELL %d ready" % len(rows), flush=True)


if __name__ == "__main__":
    main()
